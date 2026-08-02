import 'package:flutter/material.dart';
import '../../categories/category_provider.dart';
import '../../../core/utils/category_utils.dart';
import '../../../data/database/app_database.dart';

class CategoryBarChart extends StatelessWidget {
  final List<Transaction> data;
  final List<CategoryItem> savedCategories;
  final AnimationController entranceCtrl;
  final double scrollOffset;
  final String? selectedCategoryFilter;
  final Function(String?) onCategoryToggle;
  final VoidCallback? onAddCategory;

  const CategoryBarChart({
    super.key,
    required this.data,
    required this.savedCategories,
    required this.entranceCtrl,
    required this.scrollOffset,
    required this.selectedCategoryFilter,
    required this.onCategoryToggle,
    this.onAddCategory,
  });

  @override
  Widget build(BuildContext context) {
    final expenses = data.where((t) => t.type == 0).toList();

    // 1. Todas las categorías del usuario excepto ingresos, inicializadas en 0
    final expenseCategories = savedCategories
        .where((c) => c.name.toLowerCase() != 'ingresos')
        .toList();
    final Map<String, double> categorySums = {};
    for (final cat in expenseCategories) {
      categorySums[cat.name] = 0.0;
    }

    // 2. Acumular gastos reales
    for (var t in expenses) {
      final key = (t.categoryName ?? 'Otros').trim();
      categorySums[key] = (categorySums[key] ?? 0.0) + t.amount;
    }

    // 3. Ordenar: con monto (desc) + sin monto (alfabético)
    final withAmount = categorySums.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final withoutAmount = categorySums.entries.where((e) => e.value == 0).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final sortedKeys = [
      ...withAmount.map((e) => e.key),
      ...withoutAmount.map((e) => e.key),
    ];

    final maxAmount = withAmount.isNotEmpty ? withAmount.first.value : 0.0;

    final palette = [
      const Color(0xFFB4AEE8), const Color(0xFF90CAF9),
      const Color(0xFFFFCC80), const Color(0xFFB3E5FC),
      const Color(0xFFFFCDD2), const Color(0xFF81C784),
      const Color(0xFFF48FB1), const Color(0xFFCE93D8),
      const Color(0xFFA5D6A7), const Color(0xFFFFE082),
      const Color(0xFF80DEEA), const Color(0xFFEF9A9A),
    ];

    final actualMaxBarHeight = maxAmount > 0 ? 190.0 : 60.0;
    
    // El choque ocurre exactamente cuando la punta de la barra más alta alcanza
    // el borde inferior del header.
    final touchOffset = 24.0 + (220.0 - actualMaxBarHeight);
    final overlap = scrollOffset > touchOffset ? (scrollOffset - touchOffset) : 0.0;
    
    double scale = (actualMaxBarHeight - overlap) / actualMaxBarHeight;
    if (scale < 0) scale = 0.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: sortedKeys.length < 5 ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: <Widget>[
          ...sortedKeys.asMap().entries.map((entry) {
          final i = entry.key;
          final cat = entry.value;
          final amt = categorySums[cat]!;
          final isEmpty = amt == 0;

          final emoji = expenseCategories.firstWhere(
            (c) => c.name == cat,
            orElse: () => CategoryItem(name: '', emoji: CategoryUtils.getEmoji(cat)),
          ).emoji;

          final heightRatio = maxAmount > 0 ? amt / maxAmount : 0.0;
          final baseBarHeight = isEmpty ? 36.0 : 50.0 + (140.0 * heightRatio);
          final scaledHeight = baseBarHeight * scale;

          String textAmt;
          if (isEmpty) {
            textAmt = '0';
          } else if (amt >= 1000) {
            textAmt = '${(amt / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
          } else {
            textAmt = amt.toInt().toString();
          }

          final isSelected = selectedCategoryFilter == cat;
          final opacity = selectedCategoryFilter == null
              ? (isEmpty ? 0.38 : 1.0)
              : (isSelected ? 1.0 : 0.3);

          // Animación escalonada
          final startT = (i * 0.055).clamp(0.0, 0.6);
          final endT = (startT + 0.38).clamp(0.0, 1.0);
          final barAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: entranceCtrl,
              curve: Interval(startT, endT, curve: Curves.elasticOut),
            ),
          );

          return AnimatedBuilder(
            animation: barAnim,
            builder: (context, child) {
              final v = barAnim.value.clamp(0.0, 1.0);
              return Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, (1.0 - v) * 55),
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onTap: () => onCategoryToggle(cat),
              child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      textAmt,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isEmpty ? FontWeight.w400 : FontWeight.bold,
                        color: isEmpty ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: opacity,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      width: 54,
                      height: scaledHeight.clamp(36.0, 190.0),
                      decoration: BoxDecoration(
                        color: palette[i % palette.length],
                        borderRadius: BorderRadius.circular(27),
                        border: isSelected
                            ? Border.all(color: Colors.black87, width: 2)
                            : isEmpty
                                ? Border.all(color: Colors.grey[300]!, width: 1.5)
                                : null,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            emoji,
                            style: TextStyle(fontSize: isEmpty ? 14 : 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    width: 60,
                    child: Text(
                      cat,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.black87 : Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          );
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onAddCategory,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(27),
                      border: Border.all(color: Colors.grey[500]!, width: 2),
                    ),
                    child: Icon(Icons.add, color: Colors.grey[800], size: 26),
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: 60,
                  child: Text(
                    'Nueva',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
