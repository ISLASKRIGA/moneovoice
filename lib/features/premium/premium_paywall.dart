import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'premium_provider.dart';

Future<void> showPremiumPaywall(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PremiumPaywallSheet(),
  );
}

class _PremiumPaywallSheet extends ConsumerStatefulWidget {
  const _PremiumPaywallSheet();

  @override
  ConsumerState<_PremiumPaywallSheet> createState() => _PremiumPaywallSheetState();
}

class _PremiumPaywallSheetState extends ConsumerState<_PremiumPaywallSheet> {
  bool _loading = false;
  String? _error;
  bool _yearlySelected = true; // Anual seleccionado por defecto

  Future<void> _buy() async {
    setState(() { _loading = true; _error = null; });
    final productId = _yearlySelected ? kPremiumYearlyId : kPremiumMonthlyId;
    final err = await ref.read(premiumProvider.notifier).purchase(productId);
    if (mounted) setState(() { _loading = false; _error = err; });
    if (err == null && mounted) Navigator.pop(context);
  }

  Future<void> _restore() async {
    setState(() { _loading = true; _error = null; });
    await ref.read(premiumProvider.notifier).restore();
    if (mounted) {
      setState(() { _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compras restauradas')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A2E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A237E);

    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize: 0.6,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          controller: scrollCtrl,
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 44, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF3949AB), Color(0xFF5C6BC0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('👑', style: TextStyle(fontSize: 36)),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'MoneoVoice Premium',
                      style: TextStyle(color: Colors.white, fontSize: 24,
                          fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Control financiero total, sin límites',
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14),
                    ),
                  ],
                ),
              ),

              // ── Selector de plan ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Row(
                  children: [
                    // Mensual
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _yearlySelected = false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: !_yearlySelected
                                ? (isDark ? const Color(0xFF1A237E) : const Color(0xFFE8EAF6))
                                : (isDark ? const Color(0xFF2A2A3E) : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: !_yearlySelected
                                  ? const Color(0xFF3949AB)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text('Mensual',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15,
                                  color: !_yearlySelected ? textColor
                                      : (isDark ? Colors.white54 : Colors.grey[500]),
                                )),
                              const SizedBox(height: 4),
                              Text('\$60',
                                style: TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w900,
                                  color: !_yearlySelected ? textColor
                                      : (isDark ? Colors.white38 : Colors.grey[400]),
                                )),
                              Text('/ mes',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white38 : Colors.grey[400],
                                )),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Anual — destacado
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _yearlySelected = true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: _yearlySelected
                                ? (isDark ? const Color(0xFF1A237E) : const Color(0xFFE8EAF6))
                                : (isDark ? const Color(0xFF2A2A3E) : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _yearlySelected
                                  ? const Color(0xFF3949AB)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Badge "Ahorra $220"
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C853),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('Ahorra \$220',
                                  style: TextStyle(color: Colors.white,
                                      fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(height: 4),
                              Text('Anual',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15,
                                  color: _yearlySelected ? textColor
                                      : (isDark ? Colors.white54 : Colors.grey[500]),
                                )),
                              const SizedBox(height: 4),
                              Text('\$500',
                                style: TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w900,
                                  color: _yearlySelected ? textColor
                                      : (isDark ? Colors.white38 : Colors.grey[400]),
                                )),
                              Text('/ año  ·  \$41.6/mes',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.grey[500],
                                )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Features
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Todo lo que obtienes:',
                      style: TextStyle(color: textColor, fontSize: 16,
                          fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    _Feature(emoji: '🎙️', title: 'Voz avanzada — siempre gratis',
                      desc: 'NLP de alta precisión sin restricciones', highlight: true),
                    _Feature(emoji: '♾️', title: 'Transacciones ilimitadas',
                      desc: 'Sin el límite de $kFreeTransactionLimit del plan gratuito'),
                    _Feature(emoji: '📊', title: 'Exportar a Excel y PDF',
                      desc: 'Reportes profesionales con análisis avanzado'),
                    _Feature(emoji: '🔔', title: 'Detección automática de pagos',
                      desc: 'Registra gastos leyendo notificaciones de tu banco'),
                    _Feature(emoji: '📂', title: 'Listas ilimitadas',
                      desc: 'Organiza gastos por proyecto, persona o categoría'),
                    _Feature(emoji: '🔄', title: 'Transacciones recurrentes',
                      desc: 'Automatiza pagos fijos como renta, suscripciones, etc.'),
                  ],
                ),
              ),

              // Error
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center),
                ),

              // CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _buy,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                    child: _loading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text(
                            _yearlySelected
                                ? 'Suscribirse · \$500 / año'
                                : 'Suscribirse · \$60 / mes',
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),

              // Restore
              TextButton(
                onPressed: _loading ? null : _restore,
                child: Text('Ya soy suscriptor · Restaurar acceso',
                  style: TextStyle(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                    fontSize: 13,
                  )),
              ),

              // Terms
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Text(
                  'Al suscribirte aceptas los términos de Google Play.\nSe renueva automáticamente. Cancela cuando quieras desde la Play Store.',
                  style: TextStyle(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.35),
                    fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;
  final bool highlight;

  const _Feature({required this.emoji, required this.title,
      required this.desc, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14,
                    color: highlight ? const Color(0xFF00C853)
                        : (isDark ? Colors.white : const Color(0xFF1A237E)),
                  )),
                const SizedBox(height: 2),
                Text(desc,
                  style: TextStyle(fontSize: 12,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.55))),
              ],
            ),
          ),
          Icon(Icons.check_circle, size: 18,
            color: highlight ? const Color(0xFF00C853) : const Color(0xFF3949AB)),
        ],
      ),
    );
  }
}
