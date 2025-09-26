// lib/services/pdf_export.dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../core/models.dart';
import '../core/repository.dart';

class DeliveryPdfService {
  DeliveryPdfService._();
  static final DeliveryPdfService instance = DeliveryPdfService._();

  String _fmtNum(num n) => (n % 1 == 0)
      ? n.toInt().toString()
      : n.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

  String _shortId(String id) =>
      id.length <= 8 ? id : id.substring(0, 8);

  /// Builds and saves the PDF. Returns the saved file path.
  Future<String> exportDeliveryPdf(
    String deliveryId, {
    String shopHeader = 'Dilankara Enterprise',
  }) async {
    final repo = Repository.instance;

    // Load header
    final deliveries = await repo.getDeliveries();
    final delivery = deliveries.firstWhere((d) => d.id == deliveryId);

    // Load groups+widths and aggregate by thickness -> length rows
    final groups = await repo.getGroups(deliveryId);

    // thickness -> list of rows
    final Map<double, List<_LenRow>> byThickness = {};

    for (final g in groups) {
      final widths = await repo.getWidths(g.id); // list of WoodWidth
      final widthValues = widths.map((w) => w.width).toList();

      final totalWidth = widthValues.fold(0.0, (sum, width) => sum + width);
      final totalTrenches = (totalWidth * g.length) / 12 * g.thickness;

      final row = _LenRow(
        length: g.length,
        widths: widthValues,
        totalWidth: totalWidth,
        totalTrenches: totalTrenches,
      );

      byThickness.putIfAbsent(g.thickness, () => []).add(row);
    }

    // Sort thickness asc; and lengths asc inside
    final sortedThickness = byThickness.keys.toList()..sort();
    for (final t in sortedThickness) {
      byThickness[t]!.sort((a, b) => a.length.compareTo(b.length));
    }

    // Calculate grand totals
    double grandTotalTrenches = 0;
    for (final thickness in sortedThickness) {
      for (final row in byThickness[thickness]!) {
        grandTotalTrenches += row.totalTrenches;
      }
    }

    // ---- Brand colors (brown + amber) ----
    final cPrimary = PdfColor.fromInt(0xFF5D4037); // deep brown
    final cOnPrimary = PdfColor.fromInt(0xFFFFFFFF);
    final cPrimaryContainer = PdfColor.fromInt(0xFFD7CCC8); // light brown
    final cAccent = PdfColor.fromInt(0xFFFFC107); // amber
    final cAccentContainer = PdfColor.fromInt(0xFFFFE082); // light amber
    final cSurface = PdfColor.fromInt(0xFFFFFBF2); // warm off-white
    final cOnSurface = PdfColor.fromInt(0xFF3E2723); // text on paper
    final cOutline = PdfColor.fromInt(0xFFBCAAA4); // subtle line

    // Build the PDF
    final pdf = pw.Document();

    final dateStr =
        DateFormat('dd-MM-yyyy HH:mm').format(delivery.date.toLocal());
    final idShort = _shortId(delivery.id);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin:
              const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
            italic: pw.Font.helveticaOblique(),
          ),
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: cSurface),
          ),
        ),
        build: (context) => [
          // ======= Branded Header =======
          pw.Container(
            decoration: pw.BoxDecoration(
              color: cPrimary,
              borderRadius: pw.BorderRadius.circular(10),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            shopHeader,
                            style: pw.TextStyle(
                              fontSize: 24,
                              fontWeight: pw.FontWeight.bold,
                              color: cOnPrimary,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'WOOD DELIVERY REPORT',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              letterSpacing: 1.2,
                              color: cAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: cAccent,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(
                        'ID: $idShort',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFF1A1400),
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Container(height: 2, color: cAccent),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Lorry: ${delivery.lorryName}',
                            style: pw.TextStyle(
                                fontSize: 11, color: cOnPrimary)),
                        pw.Text('Date : $dateStr',
                            style: pw.TextStyle(
                                fontSize: 11, color: cOnPrimary)),
                      ],
                    ),
                    if ((delivery.notes ?? '').trim().isNotEmpty)
                      pw.Text('Notes: ${delivery.notes}',
                          style: pw.TextStyle(
                              fontSize: 10, color: cOnPrimary)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // ======= Section: Thickness blocks =======
          ...sortedThickness.expand((t) {
            final rows = byThickness[t]!;
            double thicknessTotalTrenches = 0;
            for (final row in rows) {
              thicknessTotalTrenches += row.totalTrenches;
            }

            return [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    vertical: 8, horizontal: 12),
                decoration: pw.BoxDecoration(
                  color: cPrimaryContainer,
                  border: pw.Border.all(width: 0.6, color: cOutline),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'Thickness: ${_fmtNum(t)}"',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: cOnSurface,
                      ),
                    ),
                    pw.Spacer(),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: cAccentContainer,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: cAccent, width: 0.7),
                      ),
                      child: pw.Text(
                        'Total: ${_fmtNum(thicknessTotalTrenches)} ft',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFF3E2723),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              // Each length row
              ...rows.map((r) {
                final widthsStr = r.widths.map(_fmtNum).join(', ');
                final totalWidthStr = _fmtNum(r.totalWidth);
                final lengthStr = _fmtNum(r.length);
                final trenchesStr = _fmtNum(r.totalTrenches);

                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFFFFFF),
                    border:
                        pw.Border.all(width: 0.35, color: cOutline),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Length: $lengthStr ft',
                            style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: cOnSurface),
                          ),
                          pw.SizedBox(width: 16),
                          pw.Expanded(
                            child: pw.Text(
                              'Widths: ($widthsStr)',
                              style: pw.TextStyle(
                                  fontSize: 12, color: cOnSurface),
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Total width = $widthsStr = $totalWidthStr',
                        style: pw.TextStyle(
                            fontSize: 11, color: cOnSurface),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Total (ft) = ($totalWidthStr × $lengthStr) ÷ 12 × ${_fmtNum(t)} = $trenchesStr ft',
                        style: pw.TextStyle(
                            fontSize: 11, color: cOnSurface),
                      ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 16),
            ];
          }),

          // ======= Grand Total =======
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 8),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: cAccentContainer,
              border: pw.Border.all(width: 1, color: cAccent),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Center(
              child: pw.Text(
                'GRAND TOTAL: ${_fmtNum(grandTotalTrenches)} ft',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF3E2723),
                ),
              ),
            ),
          ),
        ],
        footer: (context) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 14),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '$shopHeader • Wood Logger',
                style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromInt(0xFF6D4C41)),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount} • ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromInt(0xFF6D4C41)),
              ),
            ],
          ),
        ),
      ),
    );

    // Save file
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'delivery_${idShort}.pdf';
    final path = p.join(dir.path, fileName);
    final file = File(path);
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }
}

class _LenRow {
  final double length;
  final List<double> widths;
  final double totalWidth;
  final double totalTrenches;

  _LenRow({
    required this.length,
    required this.widths,
    required this.totalWidth,
    required this.totalTrenches,
  });
}
