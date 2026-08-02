import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/database/app_database.dart';

class MonthPickerModal extends StatefulWidget {
  final DateTime? initialSelectedMonth;
  final List<Transaction> allTransactions;
  final ValueChanged<DateTime?> onApply;

  const MonthPickerModal({
    super.key,
    required this.initialSelectedMonth,
    required this.allTransactions,
    required this.onApply,
  });

  @override
  State<MonthPickerModal> createState() => _MonthPickerModalState();
}

class _MonthPickerModalState extends State<MonthPickerModal> {
  DateTime? _selectedMonth;
  int _currentYear = DateTime.now().year;

  final List<String> _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sept', 'oct', 'nov', 'dic'
  ];

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.initialSelectedMonth;
    if (_selectedMonth != null) {
      _currentYear = _selectedMonth!.year;
    }
  }

  double _calculateBalanceForMonth(int month) {
    double inc = 0, exp = 0;
    for (var t in widget.allTransactions) {
      if (t.date.year == _currentYear && t.date.month == month) {
        if (t.type == 1) {
          inc += t.amount;
        } else {
          exp += t.amount;
        }
      }
    }
    return inc - exp;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 24,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mes',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 20, color: Colors.black),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Toggles
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_selectedMonth == null) return; // ya está en 'Todo el tiempo'
                  setState(() {
                    _selectedMonth = null;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedMonth == null ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedMonth == null ? Colors.grey[300]! : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    'Todo el tiempo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _selectedMonth == null ? Colors.black : Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMonth ??= DateTime(_currentYear, DateTime.now().month);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedMonth != null ? Colors.black : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedMonth != null ? Colors.black : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    '$_currentYear',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _selectedMonth != null ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final monthNumber = index + 1;
                final isSelected = _selectedMonth != null && _selectedMonth!.month == monthNumber;
                final balance = _calculateBalanceForMonth(monthNumber);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMonth = DateTime(_currentYear, monthNumber);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFF05252) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFF05252).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _months[index],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (balance != 0 || isSelected) ...[
                          const SizedBox(height: 2),
                          Text(
                            balance < 0
                                ? '-\$${NumberFormat('#,##0', 'en_US').format(balance.abs())}'
                                : '\$${NumberFormat('#,##0', 'en_US').format(balance)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white70 : Colors.grey[500],
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Apply Button
          ElevatedButton.icon(
            onPressed: () {
              widget.onApply(_selectedMonth);
            },
            icon: const Icon(Icons.check, color: Colors.white, size: 18),
            label: const Text(
              'Aplicar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF05252),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
