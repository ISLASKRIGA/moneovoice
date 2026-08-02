import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import 'package:drift/drift.dart' as drift;
import '../../data/database/app_database.dart';
import '../../nlp/smart_category_matcher.dart';

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/categories/category_provider.dart';

// ── Bancos y wallets soportados ──────────────────────────────────────────────
const _validPackages = {
  // Google / Samsung Pay
  'com.google.android.apps.walletnfcrel',
  'com.google.android.apps.nbu.paisa.user',
  'com.samsung.android.spay',
  // Nu / Nubank
  'com.nu.production',
  'com.nubank.app',
  // BBVA
  'com.bbva.bancomer',
  'com.bbvamx.bbva',
  // Banamex / Citibanamex
  'com.banamex.banamexmovil',
  'com.citibanamex.banamexmovil',
  // Santander
  'com.santander.app',
  'com.santander.mx',
  // HSBC
  'com.hsbc.hsbcnet',
  'com.hsbc.mexico',
  // Banorte
  'com.banorte.wellact',
  'com.banortemovil.banorte',
  // Scotiabank
  'com.scotiabank.mobile',
  // Hey Banco / BanBajio
  'com.heybanco.android',
  // Clip / Mercado Pago
  'com.clip.app',
  'com.mercadopago.wallet',
  // Spin by OXXO
  'com.oxxo.spin',
};

// ── Palabras que indican pago/cargo ──────────────────────────────────────────
const _paymentKeywords = [
  'pagaste', 'pago', 'pagado', 'cargo', 'cobro', 'compra', 'compras',
  'retiro', 'aprobada', 'aprobado', 'transaccion', 'transacción',
  'movimiento', 'debito', 'débito', 'cargado', 'procesado',
  'se cobro', 'se cobró', 'debitamos', 'consumo',
];

@pragma('vm:entry-point')
void paymentNotificationCallback(NotificationEvent evt) async {
  if (evt.packageName == null) return;

  final pkg = evt.packageName!.toLowerCase();

  // Filtrar: solo apps de banca/pagos conocidas
  final isKnownApp = _validPackages.any((p) => pkg.contains(p) || p.contains(pkg));
  if (!isKnownApp) return;

  // Combinar TODOS los campos disponibles de la notificación
  final fullText = [
    evt.title ?? '',
    evt.text ?? '',
  ].join(' ').trim();

  if (fullText.isEmpty) return;

  final normalizedText = fullText.toLowerCase();

  // Verificar que sea una notificación de pago
  final isPayment = _paymentKeywords.any((kw) => normalizedText.contains(kw));
  if (!isPayment) return;

  // ── Extraer monto ────────────────────────────────────────────────────────
  final amount = _extractAmount(fullText);
  if (amount == null || amount <= 0) return;

  // ── Extraer nombre del comercio ──────────────────────────────────────────
  // Usamos el texto original (no lowercased) para preservar mayúsculas del merchant
  final merchant = _extractMerchant(fullText, evt.title ?? '');

  // ── Categorizar usando el texto COMPLETO ─────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  final jsonStr = prefs.getString('settings_categories');
  List<CategoryItem> cats = [];
  if (jsonStr != null) {
    try {
      cats = (jsonDecode(jsonStr) as List)
          .map((e) => CategoryItem.fromJson(e))
          .toList();
    } catch (_) {}
  }
  if (cats.isEmpty) {
    cats = const [
      CategoryItem(name: 'Comida', emoji: '🍔'),
      CategoryItem(name: 'Transporte', emoji: '🚗'),
      CategoryItem(name: 'Ropa', emoji: '👕'),
      CategoryItem(name: 'Juegos', emoji: '🎮'),
      CategoryItem(name: 'Salud', emoji: '💊'),
      CategoryItem(name: 'Super', emoji: '🥬'),
      CategoryItem(name: 'Casa', emoji: '🏠'),
      CategoryItem(name: 'Entretenimiento', emoji: '🎬'),
    ];
  }

  final matcher = SmartCategoryMatcher(cats);
  // Pasar el texto COMPLETO de la notificación para mejor categorización
  final resolvedCat = matcher.match(normalizedText, null);
  final categoryName = resolvedCat?.name ?? 'General';

  // ── Guardar en DB ────────────────────────────────────────────────────────
  final db = AppDatabase();
  try {
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        amount: amount,
        date: DateTime.now(),
        type: 0,
        categoryName: drift.Value(categoryName),
        description: merchant,
      ),
    );
    print('Auto-guardado: \$$amount · $merchant · $categoryName ($pkg)');
  } catch (e) {
    print('Error al guardar notificación: $e');
  } finally {
    await db.close();
  }
}

// ── Extrae el monto del texto ────────────────────────────────────────────────
double? _extractAmount(String text) {
  // Patrones ordenados de más específico a más general
  final patterns = [
    // $1,234.56 o $1234.56
    RegExp(r'\$\s*([\d]{1,3}(?:,\d{3})*(?:\.\d{1,2})?)'),
    // 1234.56 MXN / pesos
    RegExp(
        r'([\d]{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\s*(?:mxn|pesos?|cop|usd)',
        caseSensitive: false),
    // $1234 sin decimales
    RegExp(r'\$\s*(\d{1,7})'),
    // número puro (último recurso)
    RegExp(r'\b(\d{1,7}(?:\.\d{1,2})?)\b'),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      final raw = match.group(1)!.replaceAll(',', '');
      final val = double.tryParse(raw);
      if (val != null && val > 0 && val < 1000000) return val;
    }
  }
  return null;
}

// ── Extrae el nombre del comercio ────────────────────────────────────────────
String _extractMerchant(String text, String title) {
  // Patrones de merchant (orden: más específico primero)
  final patterns = [
    // "en COMERCIO*COD" o "en COMERCIO" — ignora el código alfanumérico tras *
    RegExp(r"\ben\s+([A-Za-záéíóúÁÉÍÓÚñÑ0-9][A-Za-záéíóúÁÉÍÓÚñÑ0-9\s&\-'\.]{1,35}?)(?:\*\w+)?\s*(?:\$|por|de|con|\d|,|$)",
        caseSensitive: false),
    // "en [Comercio]" sin límite posterior
    RegExp(r"\ben\s+([A-Za-záéíóúÁÉÍÓÚñÑ0-9][A-Za-záéíóúÁÉÍÓÚñÑ0-9\s&\-'\.]{1,30})",
        caseSensitive: false),
    // "Comercio por $X"
    RegExp(r"([A-Za-záéíóúÁÉÍÓÚñÑ][A-Za-záéíóúÁÉÍÓÚñÑ\s&]{2,25})\s+por\s+\$",
        caseSensitive: false),
    // "Compra: COMERCIO"
    RegExp(r"(?:compra|cargo|cobro)[:\s]+([A-Za-záéíóúÁÉÍÓÚñÑ][A-Za-záéíóúÁÉÍÓÚñÑ\s&\-]{2,25})",
        caseSensitive: false),
    // "a [Comercio]" — menor prioridad
    RegExp(r"\ba\s+([A-Za-záéíóúÁÉÍÓÚñÑ][A-Za-záéíóúÁÉÍÓÚñÑ\s]{2,20})",
        caseSensitive: false),
  ];

  const bankTitles = {
    'google pay', 'google wallet', 'bbva', 'santander', 'banamex',
    'citibanamex', 'nubank', 'nu', 'hsbc', 'banorte', 'scotiabank',
    'hey banco', 'mercado pago', 'clip', 'spin',
  };

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match != null) {
      var candidate = match.group(1)?.trim() ?? '';
      // Limpiar código de terminal al final (ej. "OXXO*MX0001" → "OXXO")
      candidate = candidate.replaceAll(RegExp(r'\*\w+$'), '').trim();
      // Eliminar palabras de cierre que no son el nombre
      candidate = candidate
          .replaceAll(
              RegExp(r'\s*(?:por|de|con|aprobad[oa]|declin[ado]+)\s*$',
                  caseSensitive: false),
              '')
          .trim();
      if (candidate.length >= 2 && !_isBankName(candidate.toLowerCase(), bankTitles)) {
        return _toTitleCase(candidate);
      }
    }
  }

  // Fallback: usar título si no es el nombre del banco
  final titleLower = title.toLowerCase();
  if (title.isNotEmpty && !_isBankName(titleLower, bankTitles)) {
    return _toTitleCase(title);
  }

  return 'Cargo';
}

bool _isBankName(String s, Set<String> bankTitles) {
  return bankTitles.any((b) => s.contains(b) || b.contains(s));
}

String _toTitleCase(String s) {
  if (s.isEmpty) return s;
  return s
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

// ── Servicio ─────────────────────────────────────────────────────────────────

class PaymentNotificationService {
  static Future<void> init() async {
    try {
      NotificationsListener.initialize(
          callbackHandle: paymentNotificationCallback);
      final hasPermission = await NotificationsListener.hasPermission ?? false;
      if (!hasPermission) return;
      final isRunning = await NotificationsListener.isRunning ?? false;
      if (!isRunning) {
        await NotificationsListener.startService(
          foreground: false,
          title: 'MoneoVoice',
          description: 'Seguimiento automático de transacciones activo',
        );
      }
    } catch (e) {
      debugPrint('Error al iniciar PaymentNotificationService: $e');
    }
  }

  static Future<void> requestAndStart() async {
    try {
      NotificationsListener.initialize(
          callbackHandle: paymentNotificationCallback);
      NotificationsListener.openPermissionSettings();
    } catch (e) {
      debugPrint('Error al solicitar permiso: $e');
    }
  }

  static Future<void> startIfPermitted() async {
    try {
      final hasPermission = await NotificationsListener.hasPermission ?? false;
      if (!hasPermission) return;
      final isRunning = await NotificationsListener.isRunning ?? false;
      if (!isRunning) {
        await NotificationsListener.startService(
          foreground: false,
          title: 'MoneoVoice',
          description: 'Seguimiento automático de transacciones activo',
        );
      }
    } catch (e) {
      debugPrint('Error al iniciar servicio: $e');
    }
  }
}
