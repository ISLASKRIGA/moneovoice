import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BalanceHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double balance;
  final double totalIncome;
  final double totalExpense;
  final VoidCallback onSettingsPressed;
  final double topPadding;
  final bool showIncome;
  final bool accumulated;
  final int? selectedTypeFilter;
  final ValueChanged<int> onTypeFilterChanged;
  final bool isDark;

  const BalanceHeaderDelegate({
    required this.balance,
    required this.totalIncome,
    required this.totalExpense,
    required this.onSettingsPressed,
    required this.topPadding,
    required this.showIncome,
    required this.accumulated,
    required this.selectedTypeFilter,
    required this.onTypeFilterChanged,
    required this.isDark,
  });

  @override
  double get maxExtent => 260.0 + topPadding;

  @override
  double get minExtent => 260.0 + topPadding;

  @override
  bool shouldRebuild(BalanceHeaderDelegate old) =>
      old.balance != balance ||
      old.totalIncome != totalIncome ||
      old.totalExpense != totalExpense ||
      old.topPadding != topPadding ||
      old.showIncome != showIncome ||
      old.accumulated != accumulated ||
      old.selectedTypeFilter != selectedTypeFilter ||
      old.isDark != isDark;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFF6F6F9);
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            bgColor,
            bgColor,
            bgColor.withValues(alpha: 0.0),
            bgColor.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.78, 0.92, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Botón de configuración
          Positioned(
            top: topPadding + 64,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: surfaceColor,
                boxShadow: isDark ? [] : [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                ]
              ),
              child: IconButton(
                icon: Icon(Icons.settings_outlined, color: textColor),
                onPressed: onSettingsPressed,
              ),
            ),
          ),
          
          // Contenido Central
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 25.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    accumulated ? 'TOTAL ACUMULADO' : 'TOTAL',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.4,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Balance con resplandor sutil
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        child: Container(
                          width: 140,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: isDark ? [] : [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.9),
                                blurRadius: 40,
                                spreadRadius: 30,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, right: 4.0),
                            child: Text(
                              '\$',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: balance),
                            duration: const Duration(milliseconds: 1500),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) {
                              return AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: TextStyle(
                                    fontSize: 58,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                    letterSpacing: -1.0,
                                    height: 1.1,
                                  ),
                                child: Text(
                                  NumberFormat('#,##0.00', 'en_US').format(value),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Pastillas de Ingresos/Egresos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildPill(totalExpense, false, selectedTypeFilter == 0, () => onTypeFilterChanged(0), context),
                      if (showIncome) ...[
                        const SizedBox(width: 12),
                        _buildPill(totalIncome, true, selectedTypeFilter == 1, () => onTypeFilterChanged(1), context),
                      ]
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPill(double amount, bool isIncome, bool isSelected, VoidCallback onTap, BuildContext context) {
    final color = isIncome ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amtString = NumberFormat('#,##0.00', 'en_US').format(amount);
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : (isDark ? const Color(0xFF1C1C1E) : Colors.white),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color, width: isSelected ? 0 : (isDark ? 0.3 : 1.5)),
          boxShadow: isSelected 
              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: isSelected ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              '\$$amtString',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.white : color),
            ),
          ],
        ),
      ),
    );
  }
}
