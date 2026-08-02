import 'package:flutter/material.dart';

class AIImprovementsModal extends StatelessWidget {
  const AIImprovementsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Mejoras de IA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
               color: Colors.green.withValues(alpha: 0.15),
               borderRadius: BorderRadius.circular(12)
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text('Habilitado permanentemente', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 12)),
              ]
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tu motor de Inteligencia Artificial siempre está activo analizando tus descripciones, montos y patrones para hacer el trabajo sucio por ti.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const _AIFeatureTile(icon: Icons.trending_down, color: Colors.red, title: 'Detección de gastos inusuales', subtitle: 'La IA notará variaciones en tu promedio'),
          const _AIFeatureTile(icon: Icons.lightbulb_outline, color: Colors.amber, title: 'Reconocimiento avanzado', subtitle: 'Extrae fechas, precios, categorías y etiquetas'),
          const _AIFeatureTile(icon: Icons.category_outlined, color: Colors.blue, title: 'Categorización automática', subtitle: 'Auto-asigna clases a tus ítems por contexto'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Entendido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AIFeatureTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _AIFeatureTile({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChangelogModal extends StatelessWidget {
  final String version;
  const ChangelogModal({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 24),
                const Expanded(child: Text('Novedades', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
                  child: Text('v$version', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                children: const [
                  _ChangelogEntry(
                    version: '1.7.0',
                    date: 'Marzo 2026',
                    changes: [
                      '🎙️ Nueva entrada de voz en línea con transcripción en tiempo real',
                      '🌍 Selección de idioma de entrada de voz',
                      '💱 Convertidor de moneda integrado',
                      '🎨 Selector de apariencia: claro, oscuro y sistema',
                      '🤖 Mejoras de IA para categorización automática',
                      '📊 Exportación Excel mejorada con estilos profesionales',
                    ],
                  ),
                  SizedBox(height: 16),
                  _ChangelogEntry(
                    version: '1.6.0',
                    date: 'Febrero 2026',
                    changes: [
                      '🗂️ Editor de categorías con emojis personalizados',
                      '🔄 Transacciones recurrentes',
                      '📝 Gestión de listas múltiples',
                      '💡 Sugerencias de funciones por votación',
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangelogEntry extends StatelessWidget {
  final String version;
  final String date;
  final List<String> changes;

  const _ChangelogEntry({required this.version, required this.date, required this.changes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(20)),
              child: Text('v$version', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Text(date, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ],
        ),
        const SizedBox(height: 12),
        ...changes.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(c, style: const TextStyle(fontSize: 14, height: 1.4)),
        )),
      ],
    );
  }
}
