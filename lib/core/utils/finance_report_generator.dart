import 'dart:io';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/database/app_database.dart';

class FinanceReportGenerator {
  // Dark blue #1A237E
  static const _darkBlue = PdfColor(0.102, 0.137, 0.494);
  // Slightly lighter #3949AB
  static const _accentBlue = PdfColor(0.224, 0.286, 0.671);

  static const _palette = [
    PdfColor(0.129, 0.588, 0.953), // blue
    PdfColor(0.957, 0.263, 0.212), // red
    PdfColor(0.298, 0.686, 0.314), // green
    PdfColor(1.000, 0.596, 0.000), // orange
    PdfColor(0.612, 0.153, 0.690), // purple
    PdfColor(0.000, 0.737, 0.831), // teal
    PdfColor(0.914, 0.118, 0.388), // pink
    PdfColor(1.000, 0.757, 0.027), // amber
  ];

  static Future<void> generateAndShare(List<Transaction> transactions) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFmt = DateFormat('dd/MM/yyyy');
    final moneyFmt = NumberFormat('#,##0.00');
    final compactFmt = NumberFormat.compact();

    // ── Procesamiento de datos ────────────────────────────────
    double totalIncome = 0, totalExpenses = 0;
    final Map<String, double> byCat = {};
    final Map<String, double> monthInc = {};
    final Map<String, double> monthExp = {};
    final Map<String, String> monthLabel = {};

    for (final tx in transactions) {
      final mKey =
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      monthLabel[mKey] = DateFormat('MMM/yy').format(tx.date);
      if (tx.type == 1) {
        totalIncome += tx.amount;
        monthInc[mKey] = (monthInc[mKey] ?? 0) + tx.amount;
      } else {
        totalExpenses += tx.amount;
        final cat = tx.categoryName ?? 'Otros';
        byCat[cat] = (byCat[cat] ?? 0) + tx.amount;
        monthExp[mKey] = (monthExp[mKey] ?? 0) + tx.amount;
      }
    }

    final netBalance = totalIncome - totalExpenses;
    final savingsRate =
        totalIncome > 0 ? (netBalance / totalIncome) * 100 : 0.0;
    final topCats =
        (byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(8)
            .toList();

    final allMonthKeys =
        {...monthInc.keys, ...monthExp.keys}.toList()..sort();
    final last6Keys = allMonthKeys.length > 6
        ? allMonthKeys.sublist(allMonthKeys.length - 6)
        : allMonthKeys;
    final last6Labels =
        last6Keys.map((k) => monthLabel[k] ?? k).toList();

    final expTxCount = transactions.where((t) => t.type != 1).length;
    final avgExpense = expTxCount > 0 ? totalExpenses / expTxCount : 0.0;

    // ── Construcción del PDF ──────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 0),
        header: (ctx) => _buildHeader(dateFmt, now, transactions.length),
        footer: (ctx) => _buildFooter(dateFmt, now, ctx),
        build: (ctx) => [
          pw.SizedBox(height: 20),

          // ── KPIs ─────────────────────────────────────────────
          _sectionTitle('RESUMEN EJECUTIVO'),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              _kpi('Ingresos Totales', '\$${moneyFmt.format(totalIncome)}',
                  const PdfColor(0.180, 0.490, 0.196), PdfColors.green50),
              pw.SizedBox(width: 8),
              _kpi('Gastos Totales', '\$${moneyFmt.format(totalExpenses)}',
                  PdfColors.red800, PdfColors.red50),
              pw.SizedBox(width: 8),
              _kpi(
                  'Balance Neto',
                  '\$${moneyFmt.format(netBalance)}',
                  netBalance >= 0 ? _darkBlue : PdfColors.red800,
                  netBalance >= 0 ? PdfColors.blue50 : PdfColors.red50),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _kpi(
                  'Tasa de Ahorro',
                  '${savingsRate.toStringAsFixed(1)}%',
                  savingsRate >= 20
                      ? const PdfColor(0.180, 0.490, 0.196)
                      : savingsRate >= 10
                          ? PdfColors.orange800
                          : PdfColors.red800,
                  PdfColors.grey100),
              pw.SizedBox(width: 8),
              _kpi('N° Transacciones', '${transactions.length}',
                  _accentBlue, PdfColors.grey100),
              pw.SizedBox(width: 8),
              _kpi('Gasto Promedio', '\$${moneyFmt.format(avgExpense)}',
                  const PdfColor(0.494, 0.110, 0.612), PdfColors.grey100),
            ],
          ),
          pw.SizedBox(height: 28),

          // ── Gráfica de barras: Top categorías ─────────────────
          if (topCats.isNotEmpty) ...[
            _sectionTitle('TOP CATEGORIAS DE GASTO'),
            pw.SizedBox(height: 10),
            pw.SizedBox(
              height: 155,
              child: pw.Chart(
                grid: pw.CartesianGrid(
                  xAxis: pw.FixedAxis.fromStrings(
                    topCats
                        .map((e) => e.key.length > 8
                            ? '${e.key.substring(0, 7)}.'
                            : e.key)
                        .toList(),
                    marginStart: 15,
                    marginEnd: 15,
                    ticks: true,
                  ),
                  yAxis: pw.FixedAxis(
                    _yTicks(topCats.first.value),
                    format: (v) => '\$${compactFmt.format(v)}',
                    divisions: true,
                  ),
                ),
                datasets: [
                  pw.BarDataSet(
                    color: _darkBlue,
                    width: 20,
                    data: List<pw.PointChartValue>.generate(
                      topCats.length,
                      (i) => pw.PointChartValue(
                          i.toDouble(), topCats[i].value),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
          ],

          // ── Distribucion de gastos (barras de progreso) ───────
          if (topCats.isNotEmpty && totalExpenses > 0) ...[
            _sectionTitle('DISTRIBUCION DE GASTOS'),
            pw.SizedBox(height: 10),
            ...topCats.take(6).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final e = entry.value;
              final pct =
                  (e.value / totalExpenses * 100).clamp(0.0, 100.0);
              final pctInt = pct.round().clamp(1, 99);
              final color = _palette[i % _palette.length];
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 9),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Row(children: [
                          pw.Container(
                              width: 9,
                              height: 9,
                              decoration: pw.BoxDecoration(
                                  color: color,
                                  borderRadius:
                                      pw.BorderRadius.circular(2))),
                          pw.SizedBox(width: 5),
                          pw.Text(e.key,
                              style: const pw.TextStyle(fontSize: 8)),
                        ]),
                        pw.Text(
                          '${pct.toStringAsFixed(1)}%   \$${moneyFmt.format(e.value)}',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(children: [
                      pw.Expanded(
                          flex: pctInt,
                          child: pw.Container(height: 7, color: color)),
                      pw.Expanded(
                          flex: 100 - pctInt,
                          child: pw.Container(
                              height: 7, color: PdfColors.grey200)),
                    ]),
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 24),
          ],

          // ── Grafica mensual: Ingresos vs Gastos ───────────────
          if (last6Keys.length > 1) ...[
            _sectionTitle(
                'INGRESOS VS GASTOS — ULTIMOS ${last6Keys.length} MESES'),
            pw.SizedBox(height: 10),
            pw.SizedBox(
              height: 155,
              child: pw.Chart(
                grid: pw.CartesianGrid(
                  xAxis: pw.FixedAxis.fromStrings(
                    last6Labels,
                    marginStart: 20,
                    marginEnd: 20,
                    ticks: true,
                  ),
                  yAxis: pw.FixedAxis(
                    _yTicks(last6Keys
                        .map((k) => math.max(
                            monthInc[k] ?? 0, monthExp[k] ?? 0))
                        .reduce(math.max)),
                    format: (v) => '\$${compactFmt.format(v)}',
                    divisions: true,
                  ),
                ),
                datasets: [
                  pw.BarDataSet(
                    color: const PdfColor(0.180, 0.490, 0.196),
                    width: 13,
                    offset: -8,
                    data: List<pw.PointChartValue>.generate(
                      last6Keys.length,
                      (i) => pw.PointChartValue(
                          i.toDouble(), monthInc[last6Keys[i]] ?? 0),
                    ),
                  ),
                  pw.BarDataSet(
                    color: const PdfColor(0.957, 0.263, 0.212),
                    width: 13,
                    offset: 8,
                    data: List<pw.PointChartValue>.generate(
                      last6Keys.length,
                      (i) => pw.PointChartValue(
                          i.toDouble(), monthExp[last6Keys[i]] ?? 0),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Row(children: [
              pw.Container(
                  width: 10,
                  height: 10,
                  color: const PdfColor(0.180, 0.490, 0.196)),
              pw.SizedBox(width: 5),
              pw.Text('Ingresos', style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(width: 18),
              pw.Container(
                  width: 10,
                  height: 10,
                  color: const PdfColor(0.957, 0.263, 0.212)),
              pw.SizedBox(width: 5),
              pw.Text('Gastos', style: const pw.TextStyle(fontSize: 8)),
            ]),
            pw.SizedBox(height: 24),
          ],

          // ── Tabla mensual ─────────────────────────────────────
          if (last6Keys.isNotEmpty) ...[
            _sectionTitle('DETALLE MENSUAL'),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: _darkBlue),
                  children: [
                    _th('Mes'),
                    _th('Ingresos'),
                    _th('Gastos'),
                    _th('Balance')
                  ],
                ),
                ...last6Keys.asMap().entries.map((entry) {
                  final k = entry.key;
                  final mKey = last6Keys[k];
                  final inc = monthInc[mKey] ?? 0;
                  final exp = monthExp[mKey] ?? 0;
                  final bal = inc - exp;
                  final isEven = k % 2 == 0;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: isEven
                            ? PdfColors.grey50
                            : PdfColors.white),
                    children: [
                      _td(last6Labels[k]),
                      _td('\$${moneyFmt.format(inc)}',
                          color:
                              const PdfColor(0.180, 0.490, 0.196)),
                      _td('\$${moneyFmt.format(exp)}',
                          color: PdfColors.red800),
                      _td('\$${moneyFmt.format(bal)}',
                          color: bal >= 0 ? _darkBlue : PdfColors.red800,
                          bold: true),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 24),
          ],

          // ── Recomendaciones ───────────────────────────────────
          _sectionTitle('RECOMENDACIONES DEL EXPERTO'),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(
                  color: PdfColors.grey200, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _rec(
                  netBalance >= 0
                      ? 'Flujo de caja positivo'
                      : 'Flujo de caja negativo',
                  netBalance >= 0
                      ? 'Tu balance es positivo. Considera invertir el excedente en un fondo de emergencia o instrumento financiero de bajo riesgo.'
                      : 'Tus gastos superan tus ingresos. Identifica gastos hormiga y suscripciones no utilizadas en tus categorias top.',
                  netBalance >= 0
                      ? const PdfColor(0.180, 0.490, 0.196)
                      : PdfColors.red800,
                ),
                if (topCats.isNotEmpty && totalExpenses > 0) ...[
                  pw.SizedBox(height: 10),
                  _rec(
                    'Mayor categoria: ${topCats.first.key}',
                    'Representa el ${(topCats.first.value / totalExpenses * 100).toStringAsFixed(1)}% de tus gastos. Reducir un 10% generaria un ahorro de \$${moneyFmt.format(topCats.first.value * 0.1)} en este periodo.',
                    PdfColors.orange800,
                  ),
                ],
                pw.SizedBox(height: 10),
                _rec(
                  'Regla 50/30/20',
                  'Necesidades 50% · Deseos 30% · Ahorro 20%. Tu tasa de ahorro actual es ${savingsRate.toStringAsFixed(1)}%. ${savingsRate >= 20 ? "Excelente nivel, estas construyendo patrimonio." : savingsRate >= 10 ? "Buen ritmo. Intenta incrementarlo gradualmente." : "Hay oportunidad de mejorar. Pequeños ajustes hacen grandes diferencias."}',
                  _accentBlue,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),
        ],
      ),
    );

    try {
      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'MoneoVoice_AnalisisFinanciero_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.pdf',
      );
    } catch (e) {
      print('Error generando PDF: $e');
    }
  }

  // ── Helpers de layout ─────────────────────────────────────────

  static pw.Widget _buildHeader(
      DateFormat fmt, DateTime now, int txCount) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          decoration: const pw.BoxDecoration(color: _darkBlue),
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('MoneoVoice',
                      style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white)),
                  pw.Text('Reporte Financiero Profesional',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.blue100)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(fmt.format(now),
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.white)),
                  pw.Text('$txCount transacciones analizadas',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.blue100)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 18),
      ],
    );
  }

  static pw.Widget _buildFooter(
      DateFormat fmt, DateTime now, pw.Context ctx) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
                'MoneoVoice Premium · Generado el ${fmt.format(now)}',
                style: const pw.TextStyle(
                    fontSize: 7, color: PdfColors.grey400)),
            pw.Text(
                'Pagina ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: const pw.TextStyle(
                    fontSize: 7, color: PdfColors.grey400)),
          ],
        ),
        pw.SizedBox(height: 8),
      ],
    );
  }

  static pw.Widget _sectionTitle(String text) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(text,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
                letterSpacing: 1.5)),
        pw.SizedBox(height: 4),
        pw.Container(height: 2, color: _darkBlue),
      ],
    );
  }

  static pw.Widget _kpi(
      String label, String value, PdfColor valColor, PdfColor bg) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(6),
          border:
              pw.Border.all(color: PdfColors.grey200, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: const pw.TextStyle(
                    fontSize: 7, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: valColor)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _th(String text) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)),
    );
  }

  static pw.Widget _td(String text,
      {PdfColor? color, bool bold = false}) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 8,
              color: color ?? PdfColors.black,
              fontWeight:
                  bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  static pw.Widget _rec(
      String title, String body, PdfColor color) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(width: 3, color: color,
            child: pw.SizedBox(height: 38)),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: color)),
              pw.SizedBox(height: 2),
              pw.Text(body,
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey700)),
            ],
          ),
        ),
      ],
    );
  }

  static List<num> _yTicks(double max) {
    if (max <= 0) return [0, 100, 200, 300, 400, 500];
    final raw = max / 4;
    final mag =
        math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final step = ((raw / mag).ceil() * mag).toDouble();
    return [0, step, step * 2, step * 3, step * 4];
  }
}
