import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../utils/file_downloader.dart';

class ExcelService {
  /// Builds clean standardized filename: [Nama_Quiz_Atau_Ujian]_[Nama_Kelas].xlsx
  static String buildExcelFileName({
    required String title,
    required List<String> classes,
  }) {
    final cleanTitle = title
        .replaceAll(RegExp(r'[^\w\s\-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final cleanClass = classes.isEmpty
        ? 'Semua_Kelas'
        : classes
            .map((c) => c.replaceAll(RegExp(r'[^\w\s\-]'), '').trim().replaceAll(RegExp(r'\s+'), '_'))
            .join('-');
    return '${cleanTitle}_$cleanClass.xlsx';
  }

  /// Triggers instant file download on Web / saves on Mobile & Desktop
  static Future<void> downloadExcel({
    required Uint8List bytes,
    required String fileName,
  }) async {
    await saveAndDownloadFile(bytes: bytes, fileName: fileName);
  }
  /// Generates clean Excel bytes containing ONLY NIS and Nilai columns
  static Uint8List generateNisAndScoreExcel({
    required String sheetTitle,
    required List<Map<String, dynamic>> records, // [{ 'nis': '12345', 'score': 95.0 }]
  }) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    final Sheet sheet = excel[defaultSheet];

    // Header styling
    final headerCellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#4F46E5'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    // Write Header Row: strictly NIS and NILAI
    final cellNis = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    cellNis.value = TextCellValue('NIS');
    cellNis.cellStyle = headerCellStyle;

    final cellNilai = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0));
    cellNilai.value = TextCellValue('NILAI');
    cellNilai.cellStyle = headerCellStyle;

    // Set column widths
    sheet.setColumnWidth(0, 20.0);
    sheet.setColumnWidth(1, 15.0);

    // Write Data Rows
    for (int i = 0; i < records.length; i++) {
      final rowIndex = i + 1;
      final record = records[i];

      final nisValue = record['nis']?.toString() ?? '-';
      final scoreVal = record['score'];
      final scoreText = scoreVal != null ? scoreVal.toString() : '0';

      final dataCellNis = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      dataCellNis.value = TextCellValue(nisValue);
      dataCellNis.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);

      final dataCellScore = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      dataCellScore.value = TextCellValue(scoreText);
      dataCellScore.cellStyle = CellStyle(horizontalAlign: HorizontalAlign.Center);
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? []);
  }

  /// Generates comprehensive Excel with full columns:
  /// Nama Siswa, Kelas, Nama Kelompok, Nilai, Feedback, Dikumpulkan Oleh
  static Uint8List generateDetailedGradeExcel({
    required String sheetTitle,
    required List<List<dynamic>> rows,
  }) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
    final Sheet sheet = excel[defaultSheet];

    final headerCellStyle = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#4F46E5'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    for (int r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (int c = 0; c < row.length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r));
        cell.value = TextCellValue(row[c]?.toString() ?? '');
        if (r == 0) {
          cell.cellStyle = headerCellStyle;
        } else {
          cell.cellStyle = CellStyle(
            horizontalAlign: c == 0 || c == 4 ? HorizontalAlign.Left : HorizontalAlign.Center,
          );
        }
      }
    }

    sheet.setColumnWidth(0, 26.0); // Nama Siswa
    sheet.setColumnWidth(1, 14.0); // Kelas
    sheet.setColumnWidth(2, 20.0); // Nama Kelompok
    sheet.setColumnWidth(3, 14.0); // Nilai
    sheet.setColumnWidth(4, 30.0); // Feedback
    sheet.setColumnWidth(5, 22.0); // Dikumpulkan Oleh

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? []);
  }
}
