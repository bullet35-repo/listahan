import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/order.dart';

class ExportService {
  static Future<void> exportToCsv(List<OrderItem> orders) async {
    final buffer = StringBuffer();
    buffer.writeln('Date,Customer,Item,Type,Price (₱),Commission (₱)');
    final dateFormat = DateFormat('yyyy-MM-dd');
    for (final o in orders) {
      buffer.writeln(
        '"${dateFormat.format(o.date)}","${o.customerName}","${o.itemName}","${o.type}",${o.price},${o.commission}',
      );
    }
    final bytes = utf8.encode(buffer.toString());
    final file = XFile.fromData(
      bytes,
      mimeType: 'text/csv',
      name: 'orders_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );
    await Share.shareXFiles([
      file,
    ], text: 'Order export from Botoy\'s Listahan');
  }

  static Future<void> exportToPdf(List<OrderItem> orders) async {
    final dateFormat = DateFormat('MMM d, yyyy');
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 16),
          child: pw.Text(
            "Botoy's Listahan - Order Report",
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
        build: (context) => [
          pw.Text(
            'Generated ${dateFormat.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2.5),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _cell('Date', isHeader: true),
                  _cell('Customer', isHeader: true),
                  _cell('Item', isHeader: true),
                  _cell('Type', isHeader: true),
                  _cell('Price', isHeader: true),
                  _cell('Commission', isHeader: true),
                ],
              ),
              ...orders.map(
                (o) => pw.TableRow(
                  children: [
                    _cell(dateFormat.format(o.date)),
                    _cell(o.customerName),
                    _cell(o.itemName),
                    _cell(o.type),
                    _cell('₱${o.price.toStringAsFixed(2)}'),
                    _cell('₱${o.commission.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'Total: ₱${orders.fold<double>(0, (s, o) => s + o.price).toStringAsFixed(2)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final file = XFile.fromData(
      bytes,
      mimeType: 'application/pdf',
      name: 'orders_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
    await Share.shareXFiles([
      file,
    ], text: 'Order export from Botoy\'s Listahan');
  }

  static pw.Widget _cell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        maxLines: 2,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }
}
