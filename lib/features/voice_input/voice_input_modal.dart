import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/dependency_injection.dart';
import '../../core/utils/top_notification.dart';
import '../premium/premium_paywall.dart';
import '../../features/categories/category_provider.dart';
import '../../features/settings/settings_provider.dart';
import '../../nlp/intent_parser.dart';
import '../../nlp/smart_category_matcher.dart';
import '../../voice/voice_service.dart';

class VoiceInputModal extends ConsumerStatefulWidget {
  const VoiceInputModal({super.key});

  @override
  ConsumerState<VoiceInputModal> createState() => _VoiceInputModalState();
}

class _VoiceInputModalState extends ConsumerState<VoiceInputModal>
    with TickerProviderStateMixin {

  // ── Estado ──────────────────────────────────────────────────
  String _currentText = '';
  String _partialText = '';
  FinanceIntent? _intent;
  bool _isListening = true;
  double _aiConfidence = 0.0;
  bool _isVoiceDetected = false;
  CategoryItem? _resolvedCategory;
  bool _saveAsSingle = true;

  // ── Suscripciones (CRÍTICO: guardarlas para cancelar en dispose) ─
  StreamSubscription<VoiceAIResult>? _resultSub;
  StreamSubscription<VoiceStatus>?   _statusSub;

  // ── Cursor parpadeante ──────────────────────────────────────
  late final AnimationController _cursorCtrl;
  late final Animation<double>   _cursorAnim;

  // ── Animaciones ─────────────────────────────────────────────
  late final AnimationController _breathCtrl;
  late final Animation<double>   _breathAnim;
  late final AnimationController _r1, _r2, _r3;
  late final AnimationController _gradCtrl;
  late final AnimationController _cardCtrl;
  late final Animation<double>   _cardScale;
  late final Animation<double>   _cardFade;
  late final AnimationController _textCtrl;
  late final Animation<Offset>   _textSlide;
  late final Animation<double>   _textFade;
  late final AnimationController _catCtrl;
  late final Animation<double>   _catScale;

  static const _rippleDuration = Duration(milliseconds: 2400);
  static const _rippleStagger  = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _breathCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _breathAnim = Tween<double>(begin: 0.92, end: 1.08)
        .animate(CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut));

    _r1 = AnimationController(vsync: this, duration: _rippleDuration)..repeat();
    _r2 = AnimationController(vsync: this, duration: _rippleDuration);
    _r3 = AnimationController(vsync: this, duration: _rippleDuration);
    Future.delayed(_rippleStagger,     () { if (mounted) _r2.repeat(); });
    Future.delayed(_rippleStagger * 2, () { if (mounted) _r3.repeat(); });

    _gradCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();

    _cardCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _cardScale = CurvedAnimation(parent: _cardCtrl, curve: Curves.elasticOut);
    _cardFade  = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeIn);

    _textCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _textFade  = CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn);

    _catCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _catScale = CurvedAnimation(parent: _catCtrl, curve: Curves.elasticOut);

    _cursorCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 530))
      ..repeat(reverse: true);
    _cursorAnim = CurvedAnimation(parent: _cursorCtrl, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) => _startVoice());
  }

  @override
  void dispose() {
    // Cancelar suscripciones ANTES de disponer animaciones
    _resultSub?.cancel();
    _statusSub?.cancel();
    ref.read(voiceServiceProvider).stopListening();

    _breathCtrl.dispose();
    _r1.dispose(); _r2.dispose(); _r3.dispose();
    _gradCtrl.dispose();
    _cardCtrl.dispose();
    _textCtrl.dispose();
    _catCtrl.dispose();
    _cursorCtrl.dispose();
    super.dispose();
  }

  // ── Lógica de voz ───────────────────────────────────────────
  void _startVoice() {
    final svc  = ref.read(voiceServiceProvider);
    final lang = ref.read(settingsProvider).voiceLanguage;

    // Guardar suscripciones para cancelarlas en dispose()
    _resultSub = svc.aiResultStream.listen((result) {
      if (!mounted) return;
      setState(() {
        _isVoiceDetected = result.text.isNotEmpty;
        _aiConfidence    = result.confidence;
        if (result.isFinal) {
          _currentText = result.text;
          _partialText = '';
        } else {
          _partialText = result.text;
          if (_currentText.isEmpty) _currentText = result.text;
        }
      });
      if (result.text.isNotEmpty) _textCtrl.forward();
      _tryParse(result.isFinal ? result.text : (_currentText.isNotEmpty ? _currentText : result.text));
    });

    _statusSub = svc.statusStream.listen((status) {
      if (!mounted) return;
      setState(() => _isListening = status == VoiceStatus.listening);
    });

    svc.startListening(locale: lang);
  }

  // ── NLP: detectar tipo e ingreso/egreso + categoría ─────────
  void _tryParse(String text) {
    if (text.isEmpty) return;
    final intent = ref.read(intentParserProvider).parse(text);
    if (intent.action == IntentAction.unknown || intent.amount == null) return;

    final matcher = ref.read(smartCategoryMatcherProvider);
    final norm    = _normalize(text);
    final resolved = matcher.match(norm, intent.category);

    if (intent != _intent || resolved?.name != _resolvedCategory?.name) {
      setState(() {
        _intent          = intent;
        _resolvedCategory = resolved;
      });
      _cardCtrl.forward(from: 0);
      _catCtrl.forward(from: 0);
    }
  }

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll('á','a').replaceAll('é','e').replaceAll('í','i')
      .replaceAll('ó','o').replaceAll('ú','u').replaceAll('ü','u')
      .replaceAll('ñ','n');

  // ── Guardar transacción ─────────────────────────────────────
  Future<void> _confirm() async {
    if (_intent == null) return;

    // Apagar el micrófono INMEDIATAMENTE al presionar la palomita
    ref.read(voiceServiceProvider).stopListening();

    // ── Verificar límite freemium (voz siempre avanzada, pero límite de guardado) ──
    final isPremium = ref.read(premiumProvider);
    if (!isPremium) {
      final repo = ref.read(transactionRepositoryProvider);
      final count = await repo.getTransactionCount();
      if (count >= kFreeTransactionLimit) {
        if (mounted) await showPremiumPaywall(context);
        return;
      }
    }

    final repo     = ref.read(transactionRepositoryProvider);
    final matcher  = ref.read(smartCategoryMatcherProvider);
    final isIncome = _intent!.action == IntentAction.create_income;
    final catName  = _resolvedCategory?.name ?? _intent!.category ?? 'General';
    final isMulti  = _intent!.isMultiItem && !_saveAsSingle;
    final intent   = _intent!;

    // 1. Notificación flotante con retraso para que aparezca tras el cierre
    showTopNotification(
      context,
      isMulti ? '${intent.lineItems.length} transacciones guardadas' : 'Guardado en $catName',
      delay: const Duration(milliseconds: 300),
    );

    // 2. Cerrar el modal
    Navigator.pop(context);

    // 3. Escribir a DB (await garantiza que los errores no se pierdan)
    try {
      if (isMulti) {
        for (final item in intent.lineItems) {
          final itemCat = matcher.match(item.description.toLowerCase(), item.category);
          await repo.addTransaction(
            amount: item.amount, category: itemCat?.name ?? item.category,
            description: item.description, date: intent.date ?? DateTime.now(),
            isIncome: isIncome,
          );
        }
      } else {
        await repo.addTransaction(
          amount: intent.amount ?? 0, category: catName,
          description: intent.description ?? (isIncome ? 'Ingreso' : 'Gasto'),
          date: intent.date ?? DateTime.now(), isIncome: isIncome,
        );
      }
    } catch (e) {
      debugPrint('Error guardando transacción: $e');
    }
  }

  Color get _primaryColor {
    if (_intent?.amount != null) {
      return _intent!.action == IntentAction.create_income
          ? const Color(0xFF00C853)
          : const Color(0xFFFF5252);
    }
    return const Color(0xFF7C4DFF);
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasIntent = _intent != null && _intent!.amount != null;
    final isExpense = _intent?.action != IntentAction.create_income;
    final color     = _primaryColor;
    final isMulti   = _intent?.isMultiItem ?? false;
    final catEmoji  = _resolvedCategory?.emoji ?? '📦';
    final catName   = _resolvedCategory?.name ?? _intent?.category ?? 'General';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 28),

          // Orb + Ripples
          SizedBox(
            height: 180, width: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _RippleRing(controller: _r1, color: color),
                _RippleRing(controller: _r2, color: color),
                _RippleRing(controller: _r3, color: color),
                AnimatedBuilder(
                  animation: Listenable.merge([_breathAnim, _gradCtrl]),
                  builder: (context, _) {
                    final angle = _gradCtrl.value * 2 * pi;
                    return Transform.scale(
                      scale: _isListening && !hasIntent ? _breathAnim.value : 1.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeInOutCubic,
                        width: 110, height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            startAngle: angle, endAngle: angle + 2 * pi,
                            colors: hasIntent
                                ? [color, color.withValues(alpha: 0.7), color]
                                : [
                                    const Color(0xFF7C4DFF), const Color(0xFF651FFF),
                                    const Color(0xFF9C27B0), const Color(0xFF7C4DFF),
                                  ],
                          ),
                          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 32, spreadRadius: 4)],
                        ),
                        child: Icon(
                          hasIntent ? Icons.check_rounded : Icons.mic_rounded,
                          color: Colors.white, size: 46,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Status
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Column(
              key: ValueKey(hasIntent ? 'done$isMulti' : _isListening.toString()),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasIntent
                      ? (isMulti ? '${_intent!.lineItems.length} ítems detectados' : '¡Detectado!')
                      : (_isListening ? 'Escuchando...' : 'Iniciando...'),
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: hasIntent ? color : Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
                if (_isListening && _isVoiceDetected) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green[50], borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6,
                          decoration: BoxDecoration(color: Colors.green[500], shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text('Voz detectada',
                          style: TextStyle(fontSize: 11, color: Colors.green[700], fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Confianza IA
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _aiConfidence > 0 ? 1.0 : 0.0,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _aiConfidence >= 0.8 ? Icons.psychology
                        : _aiConfidence >= 0.6 ? Icons.auto_awesome : Icons.tune,
                    size: 16,
                    color: _aiConfidence >= 0.7 ? Colors.green[600]
                        : _aiConfidence >= 0.5 ? Colors.orange[600] : Colors.grey[400],
                  ),
                  const SizedBox(width: 6),
                  Text('IA: ${(_aiConfidence * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: _aiConfidence >= 0.7 ? Colors.green[700]
                          : _aiConfidence >= 0.5 ? Colors.orange[700] : Colors.grey[500],
                    )),
                ],
              ),
            ),
          ),

          // Chip categoría
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: hasIntent && _resolvedCategory != null
                ? ScaleTransition(
                    scale: _catScale,
                    child: _buildCategoryChip(catEmoji, catName, color),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),

          // Transcript en tiempo real
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: (_isListening || _currentText.isNotEmpty)
                ? Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F6F9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _isListening
                            ? _primaryColor.withValues(alpha: 0.25)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: AnimatedBuilder(
                      animation: _cursorAnim,
                      builder: (_, __) {
                        final liveText = _partialText.isNotEmpty ? _partialText : _currentText;
                        final showCursor = _isListening;
                        return RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              if (liveText.isEmpty)
                                TextSpan(
                                  text: 'Di algo...',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[400],
                                    fontStyle: FontStyle.italic,
                                    height: 1.5,
                                  ),
                                )
                              else
                                TextSpan(
                                  text: liveText,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _partialText.isNotEmpty
                                        ? Colors.grey[600]
                                        : Colors.grey[800],
                                    fontStyle: FontStyle.italic,
                                    height: 1.5,
                                  ),
                                ),
                              if (showCursor)
                                TextSpan(
                                  text: '|',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: _primaryColor.withValues(
                                      alpha: _cursorAnim.value,
                                    ),
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Result card
          AnimatedSize(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
            child: hasIntent
                ? ScaleTransition(
                    scale: _cardScale,
                    child: FadeTransition(
                      opacity: _cardFade,
                      child: isMulti
                          ? _buildMultiCard(isExpense, color)
                          : _buildSingleCard(catEmoji, catName, isExpense, color),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),

          // Botones
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: hasIntent
                ? Column(
                    key: const ValueKey('buttons'),
                    children: [
                      if (isMulti) ...[_buildSaveToggle(color), const SizedBox(height: 12)],
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: Colors.grey[200]!),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              foregroundColor: Colors.grey[600],
                            ),
                            child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _confirm,
                            icon: const Icon(Icons.check_rounded, size: 20),
                            label: const Text('Confirmar',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            style: FilledButton.styleFrom(
                              backgroundColor: color,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ]),
                    ],
                  )
                : TextButton.icon(
                    key: const ValueKey('close'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.keyboard_arrow_down),
                    label: const Text('Cerrar'),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Widgets auxiliares ──────────────────────────────────────
  Widget _buildCategoryChip(String emoji, String name, Color color) {
    final cats = ref.read(categoryProvider);
    const palette = [
      Color(0xFFF8BBD0), Color(0xFFFFCC80), Color(0xFFDCEDC8),
      Color(0xFFE8EAF6), Color(0xFFB3E5FC), Color(0xFFEFEBE9),
      Color(0xFFCFD8DC), Color(0xFFC5CAE9),
    ];
    final idx   = cats.indexWhere((c) => c.name == name);
    final bg    = idx >= 0 ? palette[idx % palette.length] : color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87)),
        const SizedBox(width: 6),
        Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
      ]),
    );
  }

  Widget _buildSingleCard(String emoji, String catName, bool isExpense, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Row(children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20),
              ),
              child: Text(catName,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ),
            const SizedBox(width: 8),
            Text(isExpense ? '· Egreso' : '· Ingreso',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ]),
          const SizedBox(height: 6),
          Text(_intent!.description ?? '',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(_formatDate(_intent!.date),
              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            '${isExpense ? "−" : "+"}\$${_intent!.amount?.toStringAsFixed(0) ?? "0"}',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color),
          ),
          Text('${(_intent!.confidence * 100).toInt()}% conf.',
              style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        ]),
      ]),
    );
  }

  Widget _buildMultiCard(bool isExpense, Color color) {
    final total   = _intent!.amount ?? 0;
    final matcher = ref.read(smartCategoryMatcherProvider);
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20),
            ),
            child: Text(isExpense ? 'Egreso múltiple' : 'Ingreso múltiple',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ),
          const Spacer(),
          Text(
            '${isExpense ? "−" : "+"}\$${total.toStringAsFixed(total % 1 == 0 ? 0 : 2)}',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
          ),
        ]),
        const SizedBox(height: 2),
        Text(_formatDate(_intent!.date),
            style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 8),
        ...List.generate(_intent!.lineItems.length, (i) {
          final item     = _intent!.lineItems[i];
          final resolved = matcher.match(item.description.toLowerCase(), item.category);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Text(resolved?.emoji ?? '📦', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.description,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(resolved?.name ?? item.category,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ])),
              Text('\$${item.amount.toStringAsFixed(item.amount % 1 == 0 ? 0 : 2)}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
            ]),
          );
        }),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total (${_intent!.lineItems.length} ítems)',
              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          Row(children: [
            Text('\$${total.toStringAsFixed(total % 1 == 0 ? 0 : 2)}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
              child: Text('${(_intent!.confidence * 100).toInt()}%',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ),
          ]),
        ]),
      ]),
    );
  }

  Widget _buildSaveToggle(Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        _ToggleChip(label: 'Una sola',  icon: Icons.merge_type,  selected: _saveAsSingle,
            color: color, onTap: () => setState(() => _saveAsSingle = true)),
        _ToggleChip(label: 'Separadas', icon: Icons.call_split,  selected: !_saveAsSingle,
            color: color, onTap: () => setState(() => _saveAsSingle = false)),
      ]),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Hoy';
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ── Toggle chip ────────────────────────────────────────────────
class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.icon,
      required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: selected ? Colors.white : Colors.grey[500]),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey[500],
            )),
          ]),
        ),
      ),
    );
  }
}

// ── Ripple ring ────────────────────────────────────────────────
class _RippleRing extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  const _RippleRing({required this.controller, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t       = controller.value;
        final scale   = 0.5 + (t * 1.1);
        final opacity = t < 0.3 ? (t / 0.3) * 0.5 : (1.0 - t) * 0.5;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: opacity.clamp(0.0, 1.0)),
                width: 2.5,
              ),
            ),
          ),
        );
      },
    );
  }
}
