import 'dart:io';
import 'package:flutter/material.dart' hide Border, BorderStyle;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/di/dependency_injection.dart';
import '../categories/category_editor_modal.dart';
import '../recurring/recurring_modal.dart';
import '../lists/user_lists_modal.dart';
import '../lists/lists_provider.dart';
import '../tags/tag_editor_modal.dart';
import 'settings_provider.dart';
import 'widgets/settings_widgets.dart';
import 'widgets/picker_sheet.dart';
import 'widgets/currency_converter_modal.dart';
import 'widgets/settings_additional_modals.dart';
import '../../core/utils/finance_report_generator.dart';
import '../../core/services/payment_notification_service.dart';
import '../premium/premium_paywall.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constantes de la app
// ─────────────────────────────────────────────────────────────────────────────
const _appVersion = '1.7.0';
const _buildNumber = '121';

const _voiceLanguages = [
  // ── Español ──────────────────────────────────────────────
  {'code': 'es-AR', 'label': 'Español (Argentina)',          'flag': '🇦🇷'},
  {'code': 'es-BO', 'label': 'Español (Bolivia)',            'flag': '🇧🇴'},
  {'code': 'es-CL', 'label': 'Español (Chile)',              'flag': '🇨🇱'},
  {'code': 'es-CO', 'label': 'Español (Colombia)',           'flag': '🇨🇴'},
  {'code': 'es-CR', 'label': 'Español (Costa Rica)',         'flag': '🇨🇷'},
  {'code': 'es-CU', 'label': 'Español (Cuba)',               'flag': '🇨🇺'},
  {'code': 'es-DO', 'label': 'Español (Rep. Dominicana)',    'flag': '🇩🇴'},
  {'code': 'es-EC', 'label': 'Español (Ecuador)',            'flag': '🇪🇨'},
  {'code': 'es-SV', 'label': 'Español (El Salvador)',        'flag': '🇸🇻'},
  {'code': 'es-ES', 'label': 'Español (España)',             'flag': '🇪🇸'},
  {'code': 'es-GT', 'label': 'Español (Guatemala)',          'flag': '🇬🇹'},
  {'code': 'es-HN', 'label': 'Español (Honduras)',           'flag': '🇭🇳'},
  {'code': 'es-MX', 'label': 'Español (México)',             'flag': '🇲🇽'},
  {'code': 'es-NI', 'label': 'Español (Nicaragua)',          'flag': '🇳🇮'},
  {'code': 'es-PA', 'label': 'Español (Panamá)',             'flag': '🇵🇦'},
  {'code': 'es-PY', 'label': 'Español (Paraguay)',           'flag': '🇵🇾'},
  {'code': 'es-PE', 'label': 'Español (Perú)',               'flag': '🇵🇪'},
  {'code': 'es-PR', 'label': 'Español (Puerto Rico)',        'flag': '🇵🇷'},
  {'code': 'es-UY', 'label': 'Español (Uruguay)',            'flag': '🇺🇾'},
  {'code': 'es-VE', 'label': 'Español (Venezuela)',          'flag': '🇻🇪'},
  {'code': 'es-US', 'label': 'Español (Estados Unidos)',     'flag': '🇺🇸'},
  // ── English ───────────────────────────────────────────────
  {'code': 'en-US', 'label': 'English (United States)',      'flag': '🇺🇸'},
  {'code': 'en-GB', 'label': 'English (United Kingdom)',     'flag': '🇬🇧'},
  {'code': 'en-AU', 'label': 'English (Australia)',          'flag': '🇦🇺'},
  {'code': 'en-CA', 'label': 'English (Canada)',             'flag': '🇨🇦'},
  {'code': 'en-IN', 'label': 'English (India)',              'flag': '🇮🇳'},
  {'code': 'en-IE', 'label': 'English (Ireland)',            'flag': '🇮🇪'},
  {'code': 'en-NZ', 'label': 'English (New Zealand)',        'flag': '🇳🇿'},
  {'code': 'en-PH', 'label': 'English (Philippines)',        'flag': '🇵🇭'},
  {'code': 'en-SG', 'label': 'English (Singapore)',          'flag': '🇸🇬'},
  {'code': 'en-ZA', 'label': 'English (South Africa)',       'flag': '🇿🇦'},
  // ── Português ─────────────────────────────────────────────
  {'code': 'pt-BR', 'label': 'Português (Brasil)',           'flag': '🇧🇷'},
  {'code': 'pt-PT', 'label': 'Português (Portugal)',         'flag': '🇵🇹'},
  // ── Français ──────────────────────────────────────────────
  {'code': 'fr-FR', 'label': 'Français (France)',            'flag': '🇫🇷'},
  {'code': 'fr-BE', 'label': 'Français (Belgique)',          'flag': '🇧🇪'},
  {'code': 'fr-CA', 'label': 'Français (Canada)',            'flag': '🇨🇦'},
  {'code': 'fr-CH', 'label': 'Français (Suisse)',            'flag': '🇨🇭'},
  // ── Deutsch ───────────────────────────────────────────────
  {'code': 'de-DE', 'label': 'Deutsch (Deutschland)',        'flag': '🇩🇪'},
  {'code': 'de-AT', 'label': 'Deutsch (Österreich)',         'flag': '🇦🇹'},
  {'code': 'de-CH', 'label': 'Deutsch (Schweiz)',            'flag': '🇨🇭'},
  // ── Italiano ──────────────────────────────────────────────
  {'code': 'it-IT', 'label': 'Italiano (Italia)',            'flag': '🇮🇹'},
  {'code': 'it-CH', 'label': 'Italiano (Svizzera)',          'flag': '🇨🇭'},
  // ── 中文 ──────────────────────────────────────────────────
  {'code': 'zh-CN', 'label': '中文 (中国大陆)',               'flag': '🇨🇳'},
  {'code': 'zh-TW', 'label': '中文 (台灣)',                   'flag': '🇹🇼'},
  {'code': 'zh-HK', 'label': '中文 (香港)',                   'flag': '🇭🇰'},
  // ── 日本語 ─────────────────────────────────────────────────
  {'code': 'ja-JP', 'label': '日本語 (日本)',                 'flag': '🇯🇵'},
  // ── 한국어 ─────────────────────────────────────────────────
  {'code': 'ko-KR', 'label': '한국어 (대한민국)',              'flag': '🇰🇷'},
  // ── Русский ───────────────────────────────────────────────
  {'code': 'ru-RU', 'label': 'Русский (Россия)',             'flag': '🇷🇺'},
  // ── العربية ───────────────────────────────────────────────
  {'code': 'ar-SA', 'label': 'العربية (السعودية)',           'flag': '🇸🇦'},
  {'code': 'ar-EG', 'label': 'العربية (مصر)',                'flag': '🇪🇬'},
  {'code': 'ar-AE', 'label': 'العربية (الإمارات)',           'flag': '🇦🇪'},
  {'code': 'ar-MA', 'label': 'العربية (المغرب)',             'flag': '🇲🇦'},
  // ── हिन्दी ─────────────────────────────────────────────────
  {'code': 'hi-IN', 'label': 'हिन्दी (भारत)',                'flag': '🇮🇳'},
  // ── Bahasa ────────────────────────────────────────────────
  {'code': 'id-ID', 'label': 'Bahasa Indonesia',             'flag': '🇮🇩'},
  {'code': 'ms-MY', 'label': 'Bahasa Melayu (Malaysia)',     'flag': '🇲🇾'},
  // ── Türkçe ────────────────────────────────────────────────
  {'code': 'tr-TR', 'label': 'Türkçe (Türkiye)',             'flag': '🇹🇷'},
  // ── Polski ────────────────────────────────────────────────
  {'code': 'pl-PL', 'label': 'Polski (Polska)',              'flag': '🇵🇱'},
  // ── Nederlands ────────────────────────────────────────────
  {'code': 'nl-NL', 'label': 'Nederlands (Nederland)',       'flag': '🇳🇱'},
  {'code': 'nl-BE', 'label': 'Nederlands (België)',          'flag': '🇧🇪'},
  // ── Svenska ───────────────────────────────────────────────
  {'code': 'sv-SE', 'label': 'Svenska (Sverige)',            'flag': '🇸🇪'},
  // ── Norsk ─────────────────────────────────────────────────
  {'code': 'nb-NO', 'label': 'Norsk bokmål (Norge)',         'flag': '🇳🇴'},
  // ── Dansk ─────────────────────────────────────────────────
  {'code': 'da-DK', 'label': 'Dansk (Danmark)',              'flag': '🇩🇰'},
  // ── Suomi ─────────────────────────────────────────────────
  {'code': 'fi-FI', 'label': 'Suomi (Suomi)',                'flag': '🇫🇮'},
  // ── Ελληνικά ──────────────────────────────────────────────
  {'code': 'el-GR', 'label': 'Ελληνικά (Ελλάδα)',           'flag': '🇬🇷'},
  // ── Čeština ───────────────────────────────────────────────
  {'code': 'cs-CZ', 'label': 'Čeština (Česko)',              'flag': '🇨🇿'},
  // ── Slovenčina ────────────────────────────────────────────
  {'code': 'sk-SK', 'label': 'Slovenčina (Slovensko)',       'flag': '🇸🇰'},
  // ── Magyar ────────────────────────────────────────────────
  {'code': 'hu-HU', 'label': 'Magyar (Magyarország)',        'flag': '🇭🇺'},
  // ── Română ────────────────────────────────────────────────
  {'code': 'ro-RO', 'label': 'Română (România)',             'flag': '🇷🇴'},
  // ── Български ─────────────────────────────────────────────
  {'code': 'bg-BG', 'label': 'Български (България)',         'flag': '🇧🇬'},
  // ── Hrvatski ──────────────────────────────────────────────
  {'code': 'hr-HR', 'label': 'Hrvatski (Hrvatska)',          'flag': '🇭🇷'},
  // ── Srpski ────────────────────────────────────────────────
  {'code': 'sr-RS', 'label': 'Srpski (Srbija)',              'flag': '🇷🇸'},
  // ── Slovenščina ───────────────────────────────────────────
  {'code': 'sl-SI', 'label': 'Slovenščina (Slovenija)',      'flag': '🇸🇮'},
  // ── Català ────────────────────────────────────────────────
  {'code': 'ca-ES', 'label': 'Català (Catalunya)',           'flag': '🇪🇸'},
  // ── Galego ────────────────────────────────────────────────
  {'code': 'gl-ES', 'label': 'Galego (Galicia)',             'flag': '🇪🇸'},
  // ── Euskara ───────────────────────────────────────────────
  {'code': 'eu-ES', 'label': 'Euskara (Euskadi)',            'flag': '🇪🇸'},
  // ── Українська ────────────────────────────────────────────
  {'code': 'uk-UA', 'label': 'Українська (Україна)',         'flag': '🇺🇦'},
  // ── ภาษาไทย ───────────────────────────────────────────────
  {'code': 'th-TH', 'label': 'ภาษาไทย (ประเทศไทย)',         'flag': '🇹🇭'},
  // ── Tiếng Việt ────────────────────────────────────────────
  {'code': 'vi-VN', 'label': 'Tiếng Việt (Việt Nam)',        'flag': '🇻🇳'},
  // ── Filipino ──────────────────────────────────────────────
  {'code': 'fil-PH', 'label': 'Filipino (Pilipinas)',        'flag': '🇵🇭'},
  // ── Afrikaans ─────────────────────────────────────────────
  {'code': 'af-ZA', 'label': 'Afrikaans (Suid-Afrika)',      'flag': '🇿🇦'},
  // ── Swahili ───────────────────────────────────────────────
  {'code': 'sw-TZ', 'label': 'Kiswahili (Tanzania)',         'flag': '🇹🇿'},
  {'code': 'sw-KE', 'label': 'Kiswahili (Kenya)',            'flag': '🇰🇪'},
  // ── বাংলা ──────────────────────────────────────────────────
  {'code': 'bn-IN', 'label': 'বাংলা (ভারত)',                 'flag': '🇮🇳'},
  {'code': 'bn-BD', 'label': 'বাংলা (বাংলাদেশ)',             'flag': '🇧🇩'},
  // ── தமிழ் ──────────────────────────────────────────────────
  {'code': 'ta-IN', 'label': 'தமிழ் (இந்தியா)',              'flag': '🇮🇳'},
  // ── తెలుగు ─────────────────────────────────────────────────
  {'code': 'te-IN', 'label': 'తెలుగు (భారతదేశం)',            'flag': '🇮🇳'},
  // ── मराठी ──────────────────────────────────────────────────
  {'code': 'mr-IN', 'label': 'मराठी (भारत)',                 'flag': '🇮🇳'},
  // ── ગુજરાતી ────────────────────────────────────────────────
  {'code': 'gu-IN', 'label': 'ગુજરાતી (ભારત)',               'flag': '🇮🇳'},
  // ── ਪੰਜਾਬੀ ─────────────────────────────────────────────────
  {'code': 'pa-IN', 'label': 'ਪੰਜਾਬੀ (ਭਾਰਤ)',                'flag': '🇮🇳'},
  // ── فارسی ──────────────────────────────────────────────────
  {'code': 'fa-IR', 'label': 'فارسی (ایران)',                'flag': '🇮🇷'},
  // ── Íslenska ──────────────────────────────────────────────
  {'code': 'is-IS', 'label': 'Íslenska (Ísland)',            'flag': '🇮🇸'},
  // ── Latviešu ──────────────────────────────────────────────
  {'code': 'lv-LV', 'label': 'Latviešu (Latvija)',           'flag': '🇱🇻'},
  // ── Lietuvių ──────────────────────────────────────────────
  {'code': 'lt-LT', 'label': 'Lietuvių (Lietuva)',           'flag': '🇱🇹'},
  // ── Eesti ─────────────────────────────────────────────────
  {'code': 'et-EE', 'label': 'Eesti (Eesti)',                'flag': '🇪🇪'},
];

const _currencies = [
  {'code': 'COP', 'label': 'Peso colombiano',  'symbol': '\$', 'flag': '🇨🇴'},
  {'code': 'USD', 'label': 'Dólar americano',  'symbol': '\$', 'flag': '🇺🇸'},
  {'code': 'EUR', 'label': 'Euro',             'symbol': '€', 'flag': '🇪🇺'},
  {'code': 'MXN', 'label': 'Peso mexicano',   'symbol': '\$', 'flag': '🇲🇽'},
  {'code': 'GBP', 'label': 'Libra esterlina', 'symbol': '£', 'flag': '🇬🇧'},
  {'code': 'BRL', 'label': 'Real brasileño',  'symbol': 'R\$','flag': '🇧🇷'},
  {'code': 'ARS', 'label': 'Peso argentino',  'symbol': '\$', 'flag': '🇦🇷'},
  {'code': 'CLP', 'label': 'Peso chileno',    'symbol': '\$', 'flag': '🇨🇱'},
  {'code': 'PEN', 'label': 'Sol peruano',     'symbol': 'S/.','flag': '🇵🇪'},
  {'code': 'JPY', 'label': 'Yen japonés',     'symbol': '¥', 'flag': '🇯🇵'},
];

class SettingsModal extends ConsumerStatefulWidget {
  const SettingsModal({super.key});

  @override
  ConsumerState<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends ConsumerState<SettingsModal> {
  bool _notifEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkNotifPermission();
  }

  Future<void> _checkNotifPermission() async {
    final status = await Permission.notification.status;
    if (mounted) setState(() => _notifEnabled = status.isGranted);
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      final status = await Permission.notification.request();
      if (mounted) setState(() => _notifEnabled = status.isGranted);
    } else {
      await openAppSettings();
      await _checkNotifPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final topPad = MediaQuery.of(context).padding.top;

    final voiceFlag = _voiceLanguages.firstWhere(
      (l) => l['code'] == settings.voiceLanguage,
      orElse: () => _voiceLanguages.first,
    )['flag']!;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      snap: true,
      builder: (context, scrollController) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              _buildHeader(context),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  children: [
                    sectionLabel('Contenido', context),
                    const SizedBox(height: 12),
                    buildSettingsItem(
                      context: context,
                      emoji: '🥑',
                      title: 'Editar categorías',
                      subtitle: 'Agrega o elimina categorías',
                      onTap: () => _showModal(context, const CategoryEditorModal()),
                    ),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.tag,
                      iconColor: Colors.blueGrey,
                      title: 'Editar etiquetas',
                      subtitle: 'En tu lista actual "${ref.watch(activeListProvider)?.name ?? 'Lista por defecto'}"',
                      onTap: () => _showModal(context, const TagEditorModal()),
                    ),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.repeat,
                      iconColor: Colors.blueGrey,
                      title: 'Lista de transacciones recurrentes',
                      onTap: () => _showModal(context, const RecurringTransactionsModal()),
                    ),
                    _buildUserListsItem(ref, context),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.upload,
                      iconColor: Colors.blue,
                      title: 'Compartir lista',
                      subtitle: 'Lista por defecto',
                      onTap: () => _comingSoon(context),
                    ),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.bar_chart,
                      iconColor: Colors.green,
                      title: 'Exportar CSV',
                      onTap: () => _exportCsv(context, ref),
                    ),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.grid_on,
                      iconColor: Colors.green[800],
                      title: 'Exportar Excel',
                      subtitle: ref.watch(premiumProvider) ? 'Con formato y diseño profesional' : '🔒 Premium · Con formato y diseño profesional',
                      onTap: () async {
                        if (!ref.read(premiumProvider)) {
                          await showPremiumPaywall(context);
                          return;
                        }
                        _exportExcel(context, ref);
                      },
                    ),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.analytics_outlined,
                      iconColor: Colors.purple[800],
                      title: 'Análisis de finanzas (PDF)',
                      subtitle: ref.watch(premiumProvider) ? 'Análisis experto de tus hábitos financieros' : '🔒 Premium · Análisis experto de tus hábitos financieros',
                      onTap: () async {
                        if (!ref.read(premiumProvider)) {
                          await showPremiumPaywall(context);
                          return;
                        }
                        _generateExpertAnalysisPdf(context, ref);
                      },
                    ),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.download,
                      iconColor: Colors.blue,
                      title: 'Importar CSV',
                      subtitle: 'Pega un CSV exportado anteriormente',
                      onTap: () => _importCsv(context, ref),
                    ),
                    buildSettingsToggle(
                      context: context,
                      icon: Icons.add,
                      title: 'Mostrar ingresos',
                      value: settings.showIncome,
                      onChanged: (val) => settingsNotifier.toggleShowIncome(val),
                    ),
                    buildSettingsToggle(
                      context: context,
                      icon: Icons.turn_left,
                      title: 'Acumulado',
                      subtitle: 'Mostrar el total de todos los meses en lugar del mes actual solamente',
                      value: settings.accumulated,
                      onChanged: (val) => settingsNotifier.toggleAccumulated(val),
                    ),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.build,
                      iconColor: Colors.grey,
                      title: 'Funciones solicitadas',
                      subtitle: 'Vota y sugiere: sé parte de la evolución de la app',
                      onTap: () => _showFeedbackModal(context),
                    ),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.auto_awesome,
                      iconColor: Colors.deepPurple,
                      title: 'Mejoras de IA',
                      subtitle: 'En tu lista actual "${ref.watch(activeListProvider)?.name ?? 'Lista por defecto'}"',
                      onTap: () => _showModal(context, const AIImprovementsModal()),
                    ),
                    const SizedBox(height: 24),
                    _divider(isDark),
                    const SizedBox(height: 8),
                    sectionLabel('Idioma y región', context),
                    const SizedBox(height: 12),
                    buildSettingsItem(
                      context: context,
                      emoji: voiceFlag,
                      title: 'Idioma de entrada de voz',
                      onTap: () => _showVoiceLanguagePicker(context, ref, settings),
                    ),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.attach_money,
                      iconColor: Colors.blueGrey,
                      title: 'Moneda',
                      subtitle: settings.currency,
                      onTap: () => _showCurrencyPicker(context, ref, settings),
                    ),
                    buildSettingsItem(
                      context: context,
                      emoji: '💱',
                      title: 'Convertidor de moneda',
                      subtitle: 'Convirtiendo de ${settings.convertFrom} a ${settings.convertTo} ahora',
                      onTap: () => _showModal(context, CurrencyConverterModal(settings: settings, ref: ref, currencies: _currencies)),
                    ),
                    const SizedBox(height: 24),
                    _divider(isDark),
                    const SizedBox(height: 8),
                    sectionLabel('Más', context),
                    const SizedBox(height: 12),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.diamond_outlined,
                      iconColor: const Color(0xFF6C63FF),
                      title: 'Premium',
                      subtitle: ref.watch(premiumProvider) ? '✅ Activa' : 'Suscríbete y desbloquea todo',
                      onTap: () async {
                        if (ref.read(premiumProvider)) {
                          _showPremiumModal(context);
                        } else {
                          await showPremiumPaywall(context);
                        }
                      },
                    ),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.brightness_4_outlined,
                      iconColor: isDark ? Colors.white : Colors.black87,
                      title: 'Apariencia',
                      subtitle: _themeModeLabel(settings.themeMode),
                      onTap: () => _showAppearancePicker(context, ref, settings),
                    ),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.new_releases_outlined,
                      iconColor: Colors.redAccent,
                      title: 'Novedades',
                      subtitle: '$_appVersion ($_buildNumber)',
                      onTap: () => _showModal(context, const ChangelogModal(version: _appVersion)),
                    ),
                    buildSettingsItem(
                      context: context,
                      emoji: '⭐',
                      title: '¿Te gusta MoneoVoice?',
                      subtitle: '¿Nos dejarías una reseña?',
                      onTap: () => _openPlayStore(),
                    ),
                    buildSettingsToggle(
                      context: context,
                      icon: Icons.notifications_outlined,
                      title: 'Permitir notificaciones',
                      subtitle: 'Garantizado sin spam',
                      value: _notifEnabled,
                      onChanged: _toggleNotifications,
                    ),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.track_changes_outlined,
                      iconColor: Colors.teal,
                      title: 'Seguimiento automático de transacciones',
                      subtitle: 'Detecta gastos de tu banco automáticamente',
                      onTap: () => _showTransactionTrackingInfo(context),
                    ),
                    buildSettingsItem(
                      context: context,
                      emoji: '𝕏',
                      title: 'Conecta conmigo en Twitter/X',
                      subtitle: '@AbrahamUnLegado',
                      onTap: () => _openUrl('https://x.com/AbrahamUnLegado'),
                    ),
                    buildSettingsItem(
                      context: context,
                      icon: Icons.gavel_outlined,
                      iconColor: Colors.brown,
                      title: 'Legal',
                      subtitle: 'Política de Privacidad y Términos de Servicio',
                      onTap: () => _showLegalModal(context),
                    ),
                    SizedBox(height: topPad + 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  
  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 4, bottom: 8, left: 24, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Configuración', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
          IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _buildUserListsItem(WidgetRef ref, BuildContext context) {
    final listsAsync = ref.watch(listsNotifierProvider);
    final count = listsAsync.valueOrNull?.length ?? 0;
    return buildSettingsItem(
      context: context,
      emoji: '📝', title: 'Tus listas', badge: count > 0 ? '$count' : null,
      onTap: () => _showModal(context, const UserListsModal()),
    );
  }

  Widget _divider(bool isDark) => Container(height: 1, color: isDark ? const Color(0xFF3A3A3C) : Colors.grey[200]);

  String _themeModeLabel(String mode) {
    if (mode == 'light') return 'Claro';
    if (mode == 'dark') return 'Oscuro';
    return 'Sistema';
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  Future<void> _openPlayStore() async {
    final market = Uri.parse('market://details?id=com.moneovoice.app');
    final web = Uri.parse('https://play.google.com/store/apps/details?id=com.moneovoice.app');
    if (!await launchUrl(market, mode: LaunchMode.externalApplication)) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  static const _notifChannel = MethodChannel('com.moneovoice.app/notifications');

  Future<bool> _isListenerEnabled() async {
    try {
      return await _notifChannel.invokeMethod<bool>('isListenerEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openListenerSettings() async {
    try {
      await _notifChannel.invokeMethod('openListenerSettings');
    } catch (_) {}
  }

  void _showTransactionTrackingInfo(BuildContext context) async {
    final enabled = await _isListenerEnabled();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (sheetCtx) => _TrackingOnboardingSheet(
        enabled: enabled,
        onContinue: () async {
          Navigator.pop(sheetCtx);
          if (!enabled) await PaymentNotificationService.requestAndStart();
        },
      ),
    );
  }

  Widget _trackingRow(String emoji, String title, String desc) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(emoji, style: const TextStyle(fontSize: 26)),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 2),
          Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      )),
    ],
  );

  void _showLegalModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, sc) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 4, 24, 16),
                child: Align(alignment: Alignment.centerLeft, child: Text('Legal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
              ),
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  children: [
                    _legalSection('Política de Privacidad', 'MoneoVoice no vende ni comparte tus datos personales con terceros. Los datos financieros que registras se almacenan localmente en tu dispositivo.\n\nUsamos Firebase Crashlytics únicamente para detectar errores técnicos de forma anónima, sin información personal identificable.\n\nPuedes eliminar todos tus datos desinstalando la aplicación.'),
                    const SizedBox(height: 24),
                    _legalSection('Términos de Servicio', 'MoneoVoice es una herramienta de registro personal de finanzas. No somos una institución financiera ni ofrecemos asesoría financiera.\n\nEl usuario es responsable de la precisión de los datos ingresados. No nos hacemos responsables por decisiones financieras tomadas con base en la información mostrada en la app.\n\nNos reservamos el derecho de actualizar estos términos con previo aviso.'),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () => _openUrl('https://moneovoice.app/privacy'),
                      child: const Text('Ver política completa en línea'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legalSection(String title, String body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(body, style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5)),
    ],
  );

  void _showModal(BuildContext context, Widget modal) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => modal);
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Función próximamente')));
  }

  // ── Pickers ────────────────────────────────────────────────────────────────
  
  void _showVoiceLanguagePicker(BuildContext context, WidgetRef ref, SettingsState settings) {
    _showPicker(context, 'Idioma de entrada de voz', _voiceLanguages.map((l) => PickerItem(
      leading: Text(l['flag']!, style: const TextStyle(fontSize: 24)),
      label: l['label']!, value: l['code']!, selected: l['code'] == settings.voiceLanguage,
    )).toList(), (code) => ref.read(settingsProvider.notifier).setVoiceLanguage(code));
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref, SettingsState settings) {
    _showPicker(context, 'Moneda principal', _currencies.map((c) => PickerItem(
      leading: Text(c['flag']!, style: const TextStyle(fontSize: 24)),
      label: '${c['label']} (${c['code']})', value: c['code']!, selected: c['code'] == settings.currency,
    )).toList(), (code) => ref.read(settingsProvider.notifier).setCurrency(code));
  }

  void _showAppearancePicker(BuildContext context, WidgetRef ref, SettingsState settings) {
    _showPicker(context, 'Apariencia', [
      PickerItem(leading: const Icon(Icons.phone_android), label: 'Sistema', value: 'system', selected: settings.themeMode == 'system'),
      PickerItem(leading: const Icon(Icons.light_mode, color: Colors.orange), label: 'Claro', value: 'light', selected: settings.themeMode == 'light'),
      PickerItem(leading: const Icon(Icons.dark_mode, color: Colors.indigo), label: 'Oscuro', value: 'dark', selected: settings.themeMode == 'dark'),
    ], (mode) => ref.read(settingsProvider.notifier).setThemeMode(mode));
  }

  void _showPicker(BuildContext context, String title, List<PickerItem> items, void Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PickerSheet(title: title, items: items, onSelect: onSelect),
    );
  }

  // ── Lógica de Exportación ─────────────────────────────────────────────────
  
  void _exportCsv(BuildContext context, WidgetRef ref) async {
    final transactions = await ref.read(transactionRepositoryProvider).getAllTransactions();
    if (transactions.isEmpty) { _msg(context, 'No hay transacciones'); return; }
    
    _msg(context, 'Generando CSV...');
    
    final buffer = StringBuffer()..writeln('ID,Monto,Tipo,Fecha,Categoria,Descripcion');
    for (var t in transactions) {
      buffer.writeln('${t.id},${t.amount},${t.type == 1 ? 'Ingreso' : 'Gasto'},${t.date.toIso8601String()},${t.categoryName},"${t.description.replaceAll('"', '""')}"');
    }
    
    final now = DateTime.now();
    final tag = '${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
    final path = '${(await getTemporaryDirectory()).path}/MoneoVoice_Transacciones_$tag.csv';
    await File(path).writeAsString(buffer.toString());
    
    if (context.mounted) {
      await Share.shareXFiles([XFile(path)], text: 'Tus transacciones en CSV');
    }
  }

  void _exportExcel(BuildContext context, WidgetRef ref) async {
    final transactions = await ref.read(transactionRepositoryProvider).getAllTransactions();
    if (transactions.isEmpty) { _msg(context, 'No hay transacciones'); return; }
    _msg(context, 'Generando reporte con Gráficos...');

    // Crear Workbook
    final xlsio.Workbook workbook = xlsio.Workbook(0); 
    
    // Configurar Hojas
    final xlsio.Worksheet dashSheet = workbook.worksheets.addWithName('Dashboard Analítico');
    dashSheet.showGridlines = false;
    
    // Anchos de columna para evitar los ##### (1-based index)
    dashSheet.setColumnWidthInPixels(1, 40);  // Col A
    dashSheet.setColumnWidthInPixels(2, 180); // Col B (Etiquetas)
    dashSheet.setColumnWidthInPixels(3, 160); // Col C (Valores - ¡AQUÍ ESTABA EL ERROR!)
    dashSheet.setColumnWidthInPixels(4, 50);  // Col D
    dashSheet.setColumnWidthInPixels(6, 180); // Col F (Categoría)
    dashSheet.setColumnWidthInPixels(7, 120); // Col G (Monto)
    dashSheet.setColumnWidthInPixels(8, 220); // Col H (Visual)
    
    final xlsio.Worksheet transSheet = workbook.worksheets.addWithName('Transacciones completas');

    // Cálculos
    double totalIncome = 0;
    double totalExpense = 0;
    Map<String, double> expensesByCategory = {};
    
    for (var t in transactions) {
      if (t.type == 1) {
        totalIncome += t.amount;
      } else {
        totalExpense += t.amount;
        expensesByCategory[t.categoryName ?? 'Otros'] = (expensesByCategory[t.categoryName ?? 'Otros'] ?? 0) + t.amount;
      }
    }
    double balance = totalIncome - totalExpense;

    // --- Dashboard Sheet Design ---
    // Estilo Título Principal (Banner)
    final xlsio.Style titleStyle = workbook.styles.add('titleStyle');
    titleStyle.fontSize = 26; // Un poco más grande
    titleStyle.fontColor = '#FFFFFF';
    titleStyle.backColor = '#1F2937';
    titleStyle.bold = true;
    titleStyle.hAlign = xlsio.HAlignType.center;
    titleStyle.vAlign = xlsio.VAlignType.center;

    // Aumentar la altura de las filas del título para que no se corte
    dashSheet.getRangeByIndex(2, 2, 4, 8).rowHeight = 25; // Filas 2, 3, 4

    // Título y unión de celdas (Amplio y centrado)
    dashSheet.getRangeByName('B2:H4').merge();
    dashSheet.getRangeByName('B2').text = '📊  MoneoVoice - Dashboard Inteligente  📊';
    dashSheet.getRangeByName('B2').cellStyle = titleStyle;

    // Diseño de indicadores principales
    final xlsio.Style labelStyle = workbook.styles.add('labelStyle');
    labelStyle.fontSize = 13;
    labelStyle.bold = true;
    labelStyle.fontColor = '#4B5563';
    
    dashSheet.getRangeByName('B6:D6').merge();
    dashSheet.getRangeByName('B6').text = 'Resumen Ejecutivo';
    dashSheet.getRangeByName('B6').cellStyle.fontSize = 16;
    dashSheet.getRangeByName('B6').cellStyle.bold = true;
    dashSheet.getRangeByName('B6').cellStyle.fontColor = '#1e293b';

    dashSheet.getRangeByName('B8').text = 'Ingresos Totales:';
    dashSheet.getRangeByName('B8').cellStyle = labelStyle;
    dashSheet.getRangeByName('C8').number = totalIncome;
    dashSheet.getRangeByName('C8').cellStyle.fontColor = '#10B981';
    dashSheet.getRangeByName('C8').cellStyle.bold = true;
    dashSheet.getRangeByName('C8').cellStyle.hAlign = xlsio.HAlignType.right;
    dashSheet.getRangeByName('C8').numberFormat = '\$#,##0.00';

    dashSheet.getRangeByName('B9').text = 'Gastos Totales:';
    dashSheet.getRangeByName('B9').cellStyle = labelStyle;
    dashSheet.getRangeByName('C9').number = totalExpense;
    dashSheet.getRangeByName('C9').cellStyle.fontColor = '#EF4444';
    dashSheet.getRangeByName('C9').cellStyle.bold = true;
    dashSheet.getRangeByName('C9').cellStyle.hAlign = xlsio.HAlignType.right;
    dashSheet.getRangeByName('C9').numberFormat = '\$#,##0.00';

    dashSheet.getRangeByName('B11').text = 'Balance Neto:';
    dashSheet.getRangeByName('B11').cellStyle = labelStyle;
    dashSheet.getRangeByName('C11').number = balance;
    dashSheet.getRangeByName('C11').cellStyle.fontColor = balance >= 0 ? '#10B981' : '#EF4444';
    dashSheet.getRangeByName('C11').cellStyle.bold = true;
    dashSheet.getRangeByName('C11').cellStyle.fontSize = 15;
    dashSheet.getRangeByName('C11').cellStyle.hAlign = xlsio.HAlignType.right;
    dashSheet.getRangeByName('C11').numberFormat = '\$#,##0.00';

    // Análisis por Categoría (Gráfico Integrado)
    dashSheet.getRangeByName('F6:H6').merge();
    dashSheet.getRangeByName('F6').text = 'Desglose de Gastos';
    dashSheet.getRangeByName('F6').cellStyle.fontSize = 16;
    dashSheet.getRangeByName('F6').cellStyle.bold = true;
    dashSheet.getRangeByName('F6').cellStyle.fontColor = '#1e293b';
    
    final xlsio.Style headerStyle = workbook.styles.add('headerStyle');
    headerStyle.bold = true;
    headerStyle.fontColor = '#FFFFFF';
    headerStyle.backColor = '#3B82F6';
    headerStyle.hAlign = xlsio.HAlignType.center;

    dashSheet.getRangeByName('F8').text = 'Categoría';
    dashSheet.getRangeByName('G8').text = 'Monto';
    dashSheet.getRangeByName('H8').text = 'Análisis Visual (%)';
    dashSheet.getRangeByName('F8:H8').cellStyle = headerStyle;

    var sortedExpenses = expensesByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    double maxExpense = sortedExpenses.isNotEmpty ? sortedExpenses.first.value : 1;
    if (maxExpense == 0) maxExpense = 1;

    int row = 9;
    for (var entry in sortedExpenses.take(10)) {
      dashSheet.getRangeByIndex(row, 6).text = entry.key; // Col F
      dashSheet.getRangeByIndex(row, 7).number = entry.value; // Col G
      dashSheet.getRangeByIndex(row, 7).numberFormat = '\$#,##0.00';
      
      // --- Gráfico de Barras Textual (Pie Replacement) ---
      // Usamos una combinación de caracteres que emulan una barra de carga premium
      double percentage = (entry.value / maxExpense) * 100;
      int bars = (percentage / 5).round(); // Cada bloque representa 5%
      if (bars == 0 && entry.value > 0) bars = 1;
      
      String barText = '█' * bars;
      dashSheet.getRangeByIndex(row, 8).text = '$barText ${percentage.toStringAsFixed(1)}%'; // Col H
      dashSheet.getRangeByIndex(row, 8).cellStyle.fontColor = (percentage > 50) ? '#EF4444' : '#F59E0B';
      dashSheet.getRangeByIndex(row, 8).cellStyle.fontSize = 10;
      row++;
    }
    
    // Mensaje de análisis general
    String analysisMessage = balance > 0 
        ? '¡Excelente! Mantienes una salud financiera positiva con un nivel de ahorro saludable.' 
        : 'Atención: Tus niveles de gastos superan tus entradas. Te recomendamos reducir gastos en las categorías más altas mostradas arriba.';
    dashSheet.getRangeByName('B14:D16').merge();
    dashSheet.getRangeByName('B14').text = analysisMessage;
    dashSheet.getRangeByName('B14').cellStyle.wrapText = true;
    dashSheet.getRangeByName('B14').cellStyle.hAlign = xlsio.HAlignType.center;
    dashSheet.getRangeByName('B14').cellStyle.vAlign = xlsio.VAlignType.center;
    dashSheet.getRangeByName('B14').cellStyle.fontColor = balance > 0 ? '#10B981' : '#EF4444';
    dashSheet.getRangeByName('B14').cellStyle.backColor = '#F3F4F6';
    dashSheet.getRangeByName('B14').cellStyle.bold = true;

    // --- 2. Hoja de Transacciones ---
    final xlsio.Style tHeaderStyle = workbook.styles.add('tHeaderStyle');
    tHeaderStyle.backColor = '#334155';
    tHeaderStyle.fontColor = '#FFFFFF';
    tHeaderStyle.bold = true;
    tHeaderStyle.hAlign = xlsio.HAlignType.center;

    transSheet.getRangeByName('A1:F1').cellStyle = tHeaderStyle;
    transSheet.getRangeByName('A1').text = 'ID';
    transSheet.getRangeByName('B1').text = 'Fecha';
    transSheet.getRangeByName('C1').text = 'Tipo';
    transSheet.getRangeByName('D1').text = 'Categoría';
    transSheet.getRangeByName('E1').text = 'Descripción';
    transSheet.getRangeByName('F1').text = 'Monto';

    transSheet.setColumnWidthInPixels(1, 60);
    transSheet.setColumnWidthInPixels(2, 120);
    transSheet.setColumnWidthInPixels(3, 80);
    transSheet.setColumnWidthInPixels(4, 120);
    transSheet.setColumnWidthInPixels(5, 250);
    transSheet.setColumnWidthInPixels(6, 100);

    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    int tRow = 2;
    for (var t in transactions) {
      transSheet.getRangeByIndex(tRow, 1).number = (t.id ?? 0).toDouble();
      transSheet.getRangeByIndex(tRow, 2).text = dateFormat.format(t.date);
      transSheet.getRangeByIndex(tRow, 3).text = t.type == 1 ? 'Ingreso' : 'Gasto';
      transSheet.getRangeByIndex(tRow, 3).cellStyle.fontColor = t.type == 1 ? '#10B981' : '#EF4444';
      transSheet.getRangeByIndex(tRow, 3).cellStyle.bold = true;

      transSheet.getRangeByIndex(tRow, 4).text = t.categoryName ?? '';
      transSheet.getRangeByIndex(tRow, 5).text = t.description;
      transSheet.getRangeByIndex(tRow, 6).number = t.amount;
      transSheet.getRangeByIndex(tRow, 6).cellStyle.fontColor = t.type == 1 ? '#10B981' : '#EF4444';
      transSheet.getRangeByIndex(tRow, 6).cellStyle.bold = true;
      transSheet.getRangeByIndex(tRow, 6).numberFormat = '\$#,##0.00';
      tRow++;
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final now2 = DateTime.now();
    final tag2 = '${now2.year}${now2.month.toString().padLeft(2, '0')}${now2.day.toString().padLeft(2, '0')}';
    final fileName = 'Reporte_MoneoVoice_$tag2.xlsx';
    final path = '${(await getTemporaryDirectory()).path}/$fileName';
    await File(path).writeAsBytes(bytes);
    
    await Share.shareXFiles(
      [XFile(path, name: fileName)], 
      subject: 'Reporte Financiero MoneoVoice - Dashboard',
      text: '¡Hola! Te comparto mi reporte financiero profesional generado con MoneoVoice.',
    );
  }

  void _importCsv(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (context) {
      final ctrl = TextEditingController();
      return AlertDialog(title: const Text('Importar CSV'), content: TextField(controller: ctrl, maxLines: 5, decoration: const InputDecoration(hintText: 'Pega todo el texto del CSV aquí...')), actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () async {
          final lines = ctrl.text.split('\n'); 
          int count = 0;
          final activeList = ref.read(activeListProvider);
          final listId = activeList?.id;
          
          for (var line in lines) {
            if (line.trim().isEmpty || line.startsWith('ID')) continue;
            
            // Parsear respetando las comillas ("...")
            final RegExp csvRegex = RegExp(r',(?=(?:[^"]*"[^"]*")*[^"]*$)');
            final p = line.split(csvRegex);
            
            if (p.length >= 6) {
              final amt = double.tryParse(p[1]) ?? 0;
              final isInc = p[2].trim().toLowerCase() == 'ingreso';
              final dt = DateTime.tryParse(p[3]) ?? DateTime.now();
              final cat = p[4];
              // Quitar comillas iniciales y finales, y dobles comillas a comilla simple
              var desc = p[5].trim();
              if (desc.startsWith('"') && desc.endsWith('"')) {
                desc = desc.substring(1, desc.length - 1);
              }
              desc = desc.replaceAll('""', '"');

              await ref.read(transactionRepositoryProvider).addTransaction(
                amount: amt, 
                category: cat, 
                description: desc, 
                date: dt, 
                isIncome: isInc,
                listId: listId,
              );
              count++;
            }
          }
          Navigator.pop(context); 
          _msg(context, 'Importadas $count transacciones exitosamente');
        }, child: const Text('Importar'))
      ]);
    });
  }

  void _showFeedbackModal(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) {
      final ctrl = TextEditingController();
      return Container(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))), child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Solicitar función', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        TextField(controller: ctrl, maxLines: 4, decoration: InputDecoration(hintText: 'Ej. Sincronización...', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: () async { 
          if (ctrl.text.isNotEmpty) { 
            final ctx = context;
            
            final Uri emailLaunchUri = Uri(
              scheme: 'mailto',
              path: 'abrahamuvul@gmail.com',
              query: 'subject=Sugerencia para iMony&body=${Uri.encodeComponent(ctrl.text)}',
            );
            
            bool launched = false;
            try {
              launched = await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
            } catch (e) {
              launched = false;
            }
            
            if (!launched) {
              // Si falla el lanzador de URL nativo (por falta de permisos en Android 11+ o sin app nativa configurada)
              // entonces usamos Share que nunca falla
              await Share.share('Para abrahamuvul@gmail.com:\n\nSugerencia: ${ctrl.text}');
            }
            
            if (ctx.mounted) {
              Navigator.pop(ctx); 
              _msg(ctx, '¡Gracias por sugerir y ayudarnos!'); 
            }
          } 
        }, style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('Enviar')),
      ])));
    });
  }

  void _showPremiumModal(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => Container(padding: const EdgeInsets.all(28), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]), borderRadius: BorderRadius.vertical(top: Radius.circular(28))), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.diamond, color: Color(0xFFFFD700), size: 48),
      const Text('Premium Activo', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
      const SizedBox(height: 24),
      const Text('✅ Sin anuncios\n✅ Exportación Excel\n✅ Mejoras de IA', style: TextStyle(color: Colors.white, fontSize: 16)),
      const SizedBox(height: 28),
      ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD700), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: const Text('Cerrar')),
    ])));
  }

  Future<void> _generateExpertAnalysisPdf(BuildContext context, WidgetRef ref) async {
    final transactions = await ref.read(transactionRepositoryProvider).getAllTransactions();
    if (transactions.isEmpty) { _msg(context, 'No hay transacciones para analizar'); return; }
    
    _msg(context, 'Realizando análisis financiero...');
    await FinanceReportGenerator.generateAndShare(transactions);
  }

  void _msg(BuildContext context, String txt) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)));
  }
}

// ── Onboarding de seguimiento automático ─────────────────────────────────────

class _TrackingOnboardingSheet extends StatelessWidget {
  final bool enabled;
  final VoidCallback onContinue;

  const _TrackingOnboardingSheet({required this.enabled, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(child: _buildContent(context)),
    );
  }

  Widget _reassureRow(IconData icon, Color color, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.3)),
          ],
        )),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        ),
        // ── Header con X ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  enabled
                      ? 'Seguimiento activo'
                      : 'Seguimiento automático\nde transacciones',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // ── Mockup del teléfono ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: Stack(
              children: [
                // Barra de estado simulada
                Positioned(
                  top: 16, left: 20, right: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('9:41', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)),
                      Row(children: [
                        Icon(Icons.signal_cellular_alt, color: Colors.white.withOpacity(0.8), size: 14),
                        const SizedBox(width: 4),
                        Icon(Icons.wifi, color: Colors.white.withOpacity(0.8), size: 14),
                        const SizedBox(width: 4),
                        Icon(Icons.battery_full, color: Colors.white.withOpacity(0.8), size: 14),
                      ]),
                    ],
                  ),
                ),
                // Notificación simulada
                Positioned(
                  top: 48, left: 16, right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
                          child: const Center(child: Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nueva transacción detectada', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text('\$150.00 en Oxxo · ahora', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Indicador de permiso activo
                if (enabled)
                  Positioned(
                    bottom: 16, right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green[400], borderRadius: BorderRadius.circular(20)),
                      child: const Text('● Activo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Texto inferior ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                enabled ? '✅ Seguimiento activo' : 'Permitir notificaciones',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                enabled
                    ? 'MoneoVoice ya detecta transacciones de tus apps bancarias automáticamente.'
                    : 'Android mostrará una pantalla de permiso. Aquí te explicamos exactamente para qué lo usamos:',
                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
              ),
              if (!enabled) ...[
                const SizedBox(height: 16),
                _reassureRow(Icons.visibility_outlined, Colors.blue,
                  'Solo leemos el texto',
                  'Únicamente detectamos el monto y el comercio de notificaciones de tus apps bancarias. Nada más.'),
                const SizedBox(height: 12),
                _reassureRow(Icons.phone_android_outlined, Colors.green,
                  'Todo queda en tu celular',
                  'No enviamos tus notificaciones a ningún servidor. Los datos se guardan solo en tu dispositivo.'),
                const SizedBox(height: 12),
                _reassureRow(Icons.lock_outlined, Colors.orange,
                  'Sin acceso a tu cuenta',
                  'No podemos ver saldos, contraseñas ni hacer movimientos. Solo leemos el texto de la notificación.'),
                const SizedBox(height: 12),
                _reassureRow(Icons.notifications_off_outlined, Colors.grey,
                  'Puedes desactivarlo cuando quieras',
                  'En Configuración → Seguimiento automático puedes revocar el acceso en cualquier momento.'),
              ],
            ],
          ),
        ),

        // ── Botón ───────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    enabled ? 'Entendido' : 'Continuar',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  if (!enabled) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 18),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
