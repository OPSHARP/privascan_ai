import 'dart:io';
import 'package:path_provider/path_provider.dart';

class TableDetectionResult {
  final bool hasTable;
  final List<String> headers;
  final List<List<String>> rows;
  final String csvContent;

  const TableDetectionResult({
    required this.hasTable,
    required this.headers,
    required this.rows,
    required this.csvContent,
  });
}

class TableDetectionService {
  /// Checks whether the extracted OCR text appears to contain tabular or structured columnar data.
  bool hasTable(String text) {
    final result = detectTable(text);
    return result.hasTable;
  }

  /// Parses OCR text and extracts structured tabular rows, converting them to CSV.
  TableDetectionResult detectTable(String text) {
    if (text.trim().isEmpty) {
      return const TableDetectionResult(
        hasTable: false,
        headers: [],
        rows: [],
        csvContent: '',
      );
    }

    final rawLines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final List<List<String>> candidateRows = [];

    for (final line in rawLines) {
      List<String> cells = [];

      // 1. Delimiter: pipe '|'
      if (line.contains('|')) {
        cells = line
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
      }
      // 2. Delimiter: tab '\t'
      else if (line.contains('\t')) {
        cells = line
            .split('\t')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
      }
      // 3. Delimiter: 2 or more spaces
      else if (RegExp(r'\s{2,}').hasMatch(line)) {
        cells = line
            .split(RegExp(r'\s{2,}'))
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty)
            .toList();
      }
      // 4. Receipt/Invoice pattern: Item Name followed by amount at end (e.g., "Cappuccino 4.50" or "Service Fee $120.00")
      else {
        final priceMatch = RegExp(r'^(.*?)\s+([\$€₹£]?\s*[\d,]+\.\d{2}|\d+[\d,]*\s*[\$€₹£]?)$').firstMatch(line);
        if (priceMatch != null) {
          final item = priceMatch.group(1)?.trim() ?? '';
          final amount = priceMatch.group(2)?.trim() ?? '';
          if (item.isNotEmpty && amount.isNotEmpty) {
            cells = [item, amount];
          }
        }
      }

      if (cells.length >= 2) {
        candidateRows.add(cells);
      }
    }

    if (candidateRows.length < 2) {
      // If less than 2 structured rows, still provide line-by-line fallback CSV if user explicitly exports
      final fallbackRows = rawLines.map((l) => [l]).toList();
      return TableDetectionResult(
        hasTable: false,
        headers: ['Line Content'],
        rows: fallbackRows,
        csvContent: _formatToCsv(['Line Content'], fallbackRows),
      );
    }

    // Determine max column count
    int maxCols = 0;
    for (final r in candidateRows) {
      if (r.length > maxCols) maxCols = r.length;
    }

    // Check if the first row is a header
    final firstRow = candidateRows.first;
    final headerKeywords = [
      'item',
      'description',
      'desc',
      'qty',
      'quantity',
      'price',
      'rate',
      'amount',
      'total',
      'date',
      'particulars',
      'sr',
      'no',
      'unit',
      'tax',
      'subtotal'
    ];
    final bool firstRowIsHeader = firstRow.any(
      (cell) => headerKeywords.any((kw) => cell.toLowerCase().contains(kw)),
    );

    List<String> headers;
    List<List<String>> dataRows;

    if (firstRowIsHeader) {
      headers = _padRow(firstRow, maxCols, 'Column');
      dataRows = candidateRows.sublist(1).map((r) => _padRow(r, maxCols, '')).toList();
    } else {
      headers = List.generate(maxCols, (i) => 'Column ${i + 1}');
      dataRows = candidateRows.map((r) => _padRow(r, maxCols, '')).toList();
    }

    final csv = _formatToCsv(headers, dataRows);

    return TableDetectionResult(
      hasTable: true,
      headers: headers,
      rows: dataRows,
      csvContent: csv,
    );
  }

  List<String> _padRow(List<String> row, int length, String padPrefix) {
    final result = List<String>.from(row);
    while (result.length < length) {
      result.add(padPrefix.isEmpty ? '' : '$padPrefix ${result.length + 1}');
    }
    return result;
  }

  /// Formats headers and rows into RFC 4180 CSV standard string.
  String _formatToCsv(List<String> headers, List<List<String>> rows) {
    final buffer = StringBuffer();

    String escapeCsvCell(String cell) {
      final trimmed = cell.trim();
      if (trimmed.contains(',') ||
          trimmed.contains('"') ||
          trimmed.contains('\n') ||
          trimmed.contains('\r')) {
        return '"${trimmed.replaceAll('"', '""')}"';
      }
      return trimmed;
    }

    // Write headers
    buffer.writeln(headers.map(escapeCsvCell).join(','));

    // Write data rows
    for (final row in rows) {
      buffer.writeln(row.map(escapeCsvCell).join(','));
    }

    return buffer.toString().trim();
  }

  /// Exports CSV content to a temporary local file on-device for sharing or opening.
  Future<File> exportToCsvFile(String csvContent, {String? fileName}) async {
    final tempDir = await getTemporaryDirectory();
    final safeName = (fileName ?? 'table_export')
        .replaceAll(RegExp(r'[^\w\s\.-]'), '_')
        .replaceAll(' ', '_');
    final file = File('${tempDir.path}/$safeName.csv');
    await file.writeAsString(csvContent);
    return file;
  }
}
