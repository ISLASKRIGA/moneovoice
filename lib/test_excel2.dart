import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

void main() {
  final xlsio.Workbook workbook = xlsio.Workbook();
  final xlsio.Worksheet worksheet = workbook.worksheets[0];
  // Provocamos un error para ver si Chart es reconocido
  print(xlsio.ExcelChartType.pie);
  final xlsio.Chart chart = worksheet.charts.add();
  print(chart.chartType);
}
