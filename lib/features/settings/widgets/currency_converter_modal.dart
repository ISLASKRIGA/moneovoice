import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../settings_provider.dart';
import '../../../core/di/dependency_injection.dart';

class CurrencyConverterModal extends StatefulWidget {
  final SettingsState settings;
  final WidgetRef ref;
  final List<Map<String, String>> currencies;

  const CurrencyConverterModal({
    super.key,
    required this.settings,
    required this.ref,
    required this.currencies,
  });

  @override
  State<CurrencyConverterModal> createState() => _CurrencyConverterModalState();
}

class _CurrencyConverterModalState extends State<CurrencyConverterModal> {
  late String _from;
  late String _to;
  final _amountCtrl = TextEditingController(text: '1');
  double _result = 0;

  static const Map<String, double> _ratesUSD = {
    'USD': 1.0, 'EUR': 0.92, 'COP': 4050.0, 'MXN': 17.5,
    'GBP': 0.79, 'BRL': 5.1, 'ARS': 890.0, 'CLP': 920.0,
    'PEN': 3.75, 'JPY': 150.0,
  };

  @override
  void initState() {
    super.initState();
    _from = widget.settings.convertFrom;
    _to = widget.settings.convertTo;
    _calculate();
  }

  void _calculate() {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final fromRate = _ratesUSD[_from] ?? 1;
    final toRate = _ratesUSD[_to] ?? 1;
    setState(() {
      _result = amount / fromRate * toRate;
    });
  }

  void _save() {
    widget.ref.read(settingsProvider.notifier).setConvertFrom(_from);
    widget.ref.read(settingsProvider.notifier).setConvertTo(_to);
  }

  String _flagFor(String code) {
    return widget.currencies.firstWhere((c) => c['code'] == code, orElse: () => widget.currencies.first)['flag']!;
  }

  @override
  Widget build(BuildContext context) {
    final resultFormatted = NumberFormat('#,##0.00', 'en_US').format(_result);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24, right: 24, top: 12,
      ),
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
          const Text('Convertidor de moneda', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '0',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
            onChanged: (_) => _calculate(),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(child: _CurrencyDropdown(
                label: 'De', value: _from, flag: _flagFor(_from), currencies: widget.currencies,
                onChanged: (v) { setState(() { _from = v; _calculate(); }); },
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() { final tmp = _from; _from = _to; _to = tmp; _calculate(); });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                    child: const Icon(Icons.swap_horiz, color: Colors.black54),
                  ),
                ),
              ),
              Expanded(child: _CurrencyDropdown(
                label: 'A', value: _to, flag: _flagFor(_to), currencies: widget.currencies,
                onChanged: (v) { setState(() { _to = v; _calculate(); }); },
              )),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE8F5E9), Color(0xFFF1F8E9)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  '$resultFormatted $_to',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text('Tasa aproximada (referencia)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () { _save(); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Guardar configuración', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyDropdown extends StatelessWidget {
  final String label;
  final String value;
  final String flag;
  final List<Map<String, String>> currencies;
  final void Function(String) onChanged;

  const _CurrencyDropdown({
    required this.label, required this.value, required this.flag, 
    required this.currencies, required this.onChanged
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value, isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              items: currencies.map((c) => DropdownMenuItem(
                value: c['code']!,
                child: Row(
                  children: [
                    Text(c['flag']!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(c['code']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              )).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ),
      ],
    );
  }
}
