import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import '../../data/database/app_database.dart';
import '../../core/di/dependency_injection.dart';
import '../../data/repositories/transaction_repository.dart';
import '../categories/category_provider.dart';
import '../categories/category_picker_modal.dart';
import '../lists/lists_provider.dart';
import '../../core/utils/top_notification.dart';
import '../recurring/recurring_provider.dart';
import '../premium/premium_paywall.dart';

class ManualTransactionModal extends ConsumerStatefulWidget {
  final Transaction? transaction;
  const ManualTransactionModal({Key? key, this.transaction}) : super(key: key);

  @override
  _ManualTransactionModalState createState() => _ManualTransactionModalState();
}

class _ManualTransactionModalState extends ConsumerState<ManualTransactionModal> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _tagController = TextEditingController();
  final List<String> _tags = [];
  
  String _selectedCategory = 'Comida'; // Default
  DateTime _selectedDate = DateTime.now();
  bool _isIncome = false;
  String _selectedFrequency = 'once'; // 'once' | 'daily' | 'weekly' | 'biweekly' | 'monthly' | 'bimonthly' | 'quarterly' | 'annually'

  static const _frequencies = [
    ('once',       'Una vez'),
    ('daily',      'Diariamente'),
    ('weekly',     'Semanalmente'),
    ('biweekly',   'Quincenalmente'),
    ('monthly',    'Mensualmente'),
    ('bimonthly',  'Bimensualmente'),
    ('quarterly',  'Trimestralmente'),
    ('annually',   'Anualmente'),
  ];
  
  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final desc = widget.transaction!.description;
      final descParts = desc.split(' ');
      List<String> validWords = [];
      for (var word in descParts) {
        if (word.startsWith('#') && word.length > 1) {
          _tags.add(word.substring(1));
        } else {
          validWords.add(word);
        }
      }
      _descriptionController.text = validWords.join(' ').trim();

      _amountController.text = widget.transaction!.amount.toString();
      _selectedCategory = widget.transaction?.categoryName ?? 'Comida';
      _selectedDate = widget.transaction!.date;
      _isIncome = widget.transaction!.type == 1;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _saveTransaction() async {
    final rawDescription = _descriptionController.text.trim();
    
    // Si dejaron algo escrito sin dar espacio, lo agregamos a tags
    if (_tagController.text.trim().isNotEmpty) {
      _tags.add(_tagController.text.trim().replaceAll('#', ''));
    }

    String finalTagsStr = _tags.map((t) => '#$t').join(' ');
    final description = finalTagsStr.isNotEmpty ? '$rawDescription $finalTagsStr'.trim() : rawDescription;
    final amountText = _amountController.text.trim();

    if (description.isEmpty || amountText.isEmpty) {
      _showSnackBar('Ingresa descripción y monto');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null) {
      _showSnackBar('Monto inválido');
      return;
    }

    // Lista activa (null = Lista por defecto)
    final activeList = ref.read(activeListProvider);
    final listId = activeList?.id;

    final repo = ref.read(transactionRepositoryProvider);
    final db   = ref.read(databaseProvider);
    final isUpdate = widget.transaction != null;

    // ── Verificar límite freemium ──────────────────────────────
    if (!isUpdate) {
      final isPremium = ref.read(premiumProvider);
      if (!isPremium) {
        final count = await repo.getTransactionCount();
        if (count >= kFreeTransactionLimit) {
          if (mounted) await showPremiumPaywall(context);
          return;
        }
      }
    }

    try {
      showTopNotification(
        context, 
        isUpdate ? 'Transacción actualizada' : 'Transacción guardada',
        delay: const Duration(milliseconds: 300),
      );
      Navigator.pop(context);

      if (isUpdate) {
        await repo.updateTransaction(
          id: widget.transaction!.id,
          amount: amount,
          category: _selectedCategory,
          description: description,
          date: _selectedDate,
          isIncome: _isIncome,
          listId: listId,
        );
      } else {
        await repo.addTransaction(
          amount: amount,
          category: _selectedCategory,
          description: description,
          date: _selectedDate,
          isIncome: _isIncome,
          listId: listId,
        );
      }

      // Si es recurrente, también registramos en la tabla de recurrentes
      if (_selectedFrequency != 'once') {
        int dayOfPeriod = _selectedDate.day;
        if (_selectedFrequency == 'weekly') {
          dayOfPeriod = _selectedDate.weekday;
        } else if (_selectedFrequency == 'daily') {
          dayOfPeriod = 0;
        }

        await ref.read(recurringNotifierProvider.notifier).add(
          amount: amount,
          description: description,
          categoryName: _selectedCategory,
          isIncome: _isIncome,
          frequency: _selectedFrequency,
          dayOfPeriod: dayOfPeriod,
        );
      }
    } catch (e) {
      debugPrint('Error al guardar: \$e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _categories = ref.watch(categoryProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9, // Almost full screen
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header Actions
          Padding(
            padding: const EdgeInsets.only(top: 16, right: 16, left: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Date & Frequency Pills
                Row(
                  children: [
                    _buildPillDropdown(
                      label: _isToday(_selectedDate) ? 'hoy' : DateFormat('dd MMM').format(_selectedDate),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context, 
                          initialDate: _selectedDate, 
                          firstDate: DateTime(2020), 
                          lastDate: DateTime(2100)
                        );
                        if (date != null) setState(() => _selectedDate = date);
                      }
                    ),
                    SizedBox(width: 8),
                    _buildFrequencyPill(),
                  ],
                ),
                // Close button
                IconButton(
                  icon: Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(backgroundColor: Colors.grey[100]),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Inputs
                  TextField(
                    controller: _descriptionController,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
                    decoration: InputDecoration(
                      hintText: 'Descripción',
                      hintStyle: TextStyle(color: Colors.grey[300]),
                      border: InputBorder.none,
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Row for Toggle and Amount
                  Row(
                    children: [
                      // Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() {
                                _isIncome = false;
                                if (_selectedCategory == 'Ingresos') {
                                  _selectedCategory = 'Comida'; // Go back to a common expense category
                                }
                              }),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: !_isIncome ? Colors.red : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text('-', style: TextStyle(color: !_isIncome ? Colors.white : Colors.grey, fontSize: 24, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() {
                                _isIncome = true;
                                _selectedCategory = 'Ingresos';
                              }),
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: _isIncome ? Colors.green : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text('+', style: TextStyle(color: _isIncome ? Colors.white : Colors.grey, fontSize: 22, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(width: 16),
                      
                      // Amount
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _isIncome ? Colors.green : Colors.red),
                          decoration: InputDecoration(
                            hintText: 'Monto',
                            hintStyle: TextStyle(color: Colors.grey[300]),
                            border: InputBorder.none,
                            prefixText: '\$ ',
                            prefixStyle: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _isIncome ? Colors.green : Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Category Scroll
                  SizedBox(
                    height: 50,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length + 1, // +1 for Add button
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // Add Category Button
                          return GestureDetector(
                            onTap: () async {
                              final selected = await showModalBottomSheet<String>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => CategoryPickerModal(initialCategory: _selectedCategory),
                              );
                              if (selected != null) {
                                setState(() => _selectedCategory = selected);
                              }
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: const Icon(Icons.add, color: Colors.black54),
                            ),
                          );
                        }
                        
                        final cat = _categories[index - 1];
                        final isSelected = cat.name == _selectedCategory;
                        
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategory = cat.name),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.grey[200] : Colors.white, // Selected turns greyish/active
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[100]!),
                              boxShadow: isSelected ? [] : [
                                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
                              ],
                            ),
                            child: Row(
                              children: [
                                Text(cat.emoji, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Text(
                                  cat.name, 
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600, 
                                    color: Colors.black87
                                  )
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  SizedBox(height: 40),
                  
                  // Bottom Row: Tag + Save Button
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerLeft,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                ..._tags.map((tag) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(12)
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('#$tag', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () => setState(() => _tags.remove(tag)),
                                          child: const Icon(Icons.close, size: 16, color: Colors.white70)
                                        )
                                      ]
                                    )
                                  ),
                                )),
                                SizedBox(
                                  width: 120, // Ancho fijo para escribir
                                  child: TextField(
                                    controller: _tagController,
                                    textInputAction: TextInputAction.done,
                                    onChanged: (val) {
                                      if (val.endsWith(' ')) {
                                        final newTag = val.trim().replaceAll('#', '');
                                        if (newTag.isNotEmpty) {
                                          setState(() {
                                            _tags.add(newTag);
                                            _tagController.clear();
                                          });
                                        } else {
                                          _tagController.clear();
                                        }
                                      }
                                    },
                                    onSubmitted: (val) {
                                      final newTag = val.trim().replaceAll('#', '');
                                      if (newTag.isNotEmpty) {
                                        setState(() {
                                          _tags.add(newTag);
                                          _tagController.clear();
                                        });
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      hintText: '#Etiqueta',
                                      hintStyle: TextStyle(color: Colors.black38, fontWeight: FontWeight.normal),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      if (widget.transaction != null) ...[
                        SizedBox(width: 12),
                        GestureDetector(
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text("Confirmar"),
                                  content: const Text("¿Estás seguro de que deseas eliminar esta transacción?"),
                                  actions: <Widget>[
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text("Cancelar"),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              final repo = ref.read(transactionRepositoryProvider);
                              try {
                                await repo.deleteTransaction(widget.transaction!.id);
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
                                }
                              }
                            }
                          },
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black, width: 2),
                            ),
                            child: Icon(Icons.delete_outline, color: Colors.black, size: 30),
                          ),
                        ),
                      ],
                      SizedBox(width: 12),
                      
                      // Save Button (Black Square)
                      GestureDetector(
                        onTap: _saveTransaction,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.check, color: Colors.white, size: 30),
                        ),
                      ),
                    ],
                  ),
                  
                  // Spacer for keyboard
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyPill() {
    final selectedLabel = _frequencies.firstWhere((f) => f.$1 == _selectedFrequency).$2;
    final isRecurring = _selectedFrequency != 'once';

    return PopupMenuButton<String>(
      onSelected: (value) => setState(() => _selectedFrequency = value),
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 8,
      itemBuilder: (context) => _frequencies.map((f) {
        final isSelected = f.$1 == _selectedFrequency;
        return PopupMenuItem<String>(
          value: f.$1,
          child: Row(
            children: [
              SizedBox(width: 4),
              Icon(
                isSelected ? Icons.check : null,
                size: 16,
                color: Colors.black87,
              ),
              SizedBox(width: isSelected ? 8 : 24),
              Text(
                f.$2,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: Colors.black87,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isRecurring ? Colors.black : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (isRecurring)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Icon(Icons.repeat, size: 13, color: Colors.white),
              ),
            Text(
              selectedLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isRecurring ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16,
                color: isRecurring ? Colors.white : Colors.black87),
          ],
        ),
      ),
    );
  }

  Widget _buildPillDropdown({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
            SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black87),
          ],
        ),
      ),
    );
  }
  
  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

}
