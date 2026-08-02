import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../categories/category_provider.dart';
import 'recurring_provider.dart';

class RecurringTransactionsModal extends ConsumerStatefulWidget {
  const RecurringTransactionsModal({Key? key}) : super(key: key);

  @override
  ConsumerState<RecurringTransactionsModal> createState() =>
      _RecurringTransactionsModalState();
}

class _RecurringTransactionsModalState
    extends ConsumerState<RecurringTransactionsModal> {
  bool _showForm = false;

  // Form state
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isIncome = false;
  String _frequency = 'monthly';
  int _dayOfPeriod = 1;
  String? _selectedCategory;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Utilidades de presentación ───────────────────────────
  String _freqLabel(String f) {
    switch (f) {
      case 'daily': return 'Diario';
      case 'weekly': return 'Semanal';
      case 'biweekly': return 'Quincenal';
      case 'monthly': return 'Mensual';
      case 'bimonthly': return 'Bimensual';
      case 'quarterly': return 'Trimestral';
      case 'annually': return 'Anual';
      default: return 'Recurrente';
    }
  }

  String _dayLabel(String freq, int day) {
    if (freq == 'daily') return 'Cada día';
    if (freq == 'weekly') {
      const days = ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
      return 'Cada ${days[day]}';
    }
    if (freq == 'monthly' || freq == 'biweekly' || freq == 'bimonthly' || freq == 'quarterly' || freq == 'annually') {
      return 'Día $day de cada periodo';
    }
    return '';
  }

  IconData _freqIcon(String f) {
    switch (f) {
      case 'daily': return Icons.today;
      case 'weekly': return Icons.calendar_view_week;
      case 'monthly': return Icons.calendar_month;
      default: return Icons.repeat;
    }
  }

  // ── Guardar nueva recurrente ─────────────────────────────
  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      _showSnack('Ingresa un monto válido');
      return;
    }
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      _showSnack('Escribe una descripción');
      return;
    }

    await ref.read(recurringNotifierProvider.notifier).add(
      amount: amount,
      description: desc,
      categoryName: _selectedCategory,
      isIncome: _isIncome,
      frequency: _frequency,
      dayOfPeriod: _dayOfPeriod,
    );

    _amountCtrl.clear();
    _descCtrl.clear();
    setState(() {
      _showForm = false;
      _selectedCategory = null;
      _isIncome = false;
      _frequency = 'monthly';
      _dayOfPeriod = 1;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final recState = ref.watch(recurringNotifierProvider);
    final categories = ref.watch(categoryProvider);
    final topPad = MediaQuery.of(context).padding.top;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      snap: true,
      snapSizes: const [0.92],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recurrentes',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                    ),
                    Row(children: [
                      // Botón agregar
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _showForm
                            ? const SizedBox.shrink()
                            : Container(
                                key: const ValueKey('add_btn'),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: TextButton.icon(
                                  onPressed: () => setState(() => _showForm = true),
                                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                                  label: const Text('Nueva', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),

              // Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    // ── Formulario de nueva recurrente ───────
                    AnimatedSize(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOutCubic,
                      child: _showForm ? _buildForm(categories) : const SizedBox.shrink(),
                    ),

                    // ── Lista de recurrentes ─────────────────
                    recState.when(
                      loading: () => const Center(child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      )),
                      error: (e, _) => Text('Error: $e'),
                      data: (list) {
                        if (list.isEmpty && !_showForm) {
                          return _buildEmptyState();
                        }
                        return Column(
                          children: list.map((r) => _buildRecurringCard(r)).toList(),
                        );
                      },
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

  // ── Empty state ──────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Text('🔄', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            'Sin transacciones recurrentes',
            style: TextStyle(fontSize: 16, color: Colors.grey[400], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Añade gastos o ingresos que se\nrepiten mes a mes o semana a semana.',
            style: TextStyle(fontSize: 13, color: Colors.grey[400], height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => setState(() => _showForm = true),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar primera recurrente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Formulario ───────────────────────────────────────────
  Widget _buildForm(List categories) {
    final monthDays = List.generate(28, (i) => i + 1);
    const weekDays = [
      MapEntry(1, 'Lunes'), MapEntry(2, 'Martes'), MapEntry(3, 'Miércoles'),
      MapEntry(4, 'Jueves'), MapEntry(5, 'Viernes'), MapEntry(6, 'Sábado'), MapEntry(7, 'Domingo'),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nueva transacción recurrente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Tipo: Gasto / Ingreso
          Row(children: [
            _typeChip('Gasto', false, Icons.arrow_downward),
            const SizedBox(width: 10),
            _typeChip('Ingreso', true, Icons.arrow_upward),
          ]),
          const SizedBox(height: 14),

          // Monto
          _field(
            controller: _amountCtrl,
            label: 'Monto',
            prefix: '\$',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),

          // Descripción
          _field(controller: _descCtrl, label: 'Descripción'),
          const SizedBox(height: 12),

          // Categoría
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: _inputDecoration('Categoría (opcional)'),
            hint: const Text('Sin categoría'),
            items: categories.map<DropdownMenuItem<String>>((c) {
              return DropdownMenuItem(value: c.name, child: Text('${c.emoji} ${c.name}'));
            }).toList(),
            onChanged: (v) => setState(() => _selectedCategory = v),
          ),
          const SizedBox(height: 12),

          // Frecuencia
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _frequency,
                decoration: _inputDecoration('Frecuencia'),
                items: const [
                  DropdownMenuItem(value: 'monthly', child: Text('📅 Mensual')),
                  DropdownMenuItem(value: 'weekly', child: Text('🗓 Semanal')),
                ],
                onChanged: (v) => setState(() {
                  _frequency = v!;
                  _dayOfPeriod = 1;
                }),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Día específico
          if (_frequency == 'monthly')
            DropdownButtonFormField<int>(
              value: _dayOfPeriod,
              decoration: _inputDecoration('Día del mes'),
              items: monthDays.map((d) => DropdownMenuItem(value: d, child: Text('Día $d'))).toList(),
              onChanged: (v) => setState(() => _dayOfPeriod = v!),
            )
          else
            DropdownButtonFormField<int>(
              value: _dayOfPeriod,
              decoration: _inputDecoration('Día de la semana'),
              items: weekDays.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
              onChanged: (v) => setState(() => _dayOfPeriod = v!),
            ),

          const SizedBox(height: 20),

          // Botones
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _showForm = false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _typeChip(String label, bool value, IconData icon) {
    final selected = _isIncome == value;
    final color = value ? Colors.green : Colors.red;
    return GestureDetector(
      onTap: () => setState(() => _isIncome = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? color : Colors.grey),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: selected ? color : Colors.grey,
          )),
        ]),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? prefix,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label).copyWith(
        prefixText: prefix,
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  // ── Card de transacción recurrente ───────────────────────
  Widget _buildRecurringCard(RecurringTransaction r) {
    final isIncome = r.type == 1;
    final color = isIncome ? Colors.green : Colors.red;
    final sign = isIncome ? '+' : '-';
    final freq = _freqLabel(r.frequency);
    final dayLabel = _dayLabel(r.frequency, r.dayOfPeriod);

    return Dismissible(
      key: ValueKey(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('¿Eliminar recurrente?'),
            content: Text('Se eliminará "${r.description}" permanentemente.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => ref.read(recurringNotifierProvider.notifier).delete(r.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          // Icono frecuencia
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_freqIcon(r.frequency), color: color, size: 22),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.description, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 3),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[100], borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(freq, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 6),
                Text(dayLabel, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ]),
              if (r.categoryName != null) ...[
                const SizedBox(height: 4),
                Text(r.categoryName!, style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              ],
            ],
          )),

          // Monto + toggle
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign\$${r.amount % 1 == 0 ? r.amount.toInt() : r.amount.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => ref.read(recurringNotifierProvider.notifier).toggleActive(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38, height: 22,
                  decoration: BoxDecoration(
                    color: r.isActive ? Colors.green : Colors.grey[300],
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: r.isActive ? Alignment.centerRight : Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        width: 18, height: 18,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}
