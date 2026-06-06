import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/order.dart';
import '../models/payment.dart';

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
    ], text: 'Entry export from Botoy\'s Listahan');
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
            "Botoy's Listahan - Entry Report",
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
    ], text: 'Entry export from Botoy\'s Listahan');
  }

  static Future<void> exportBackup({
    required List<OrderItem> orders,
    required List<PaymentRecord> payments,
  }) async {
    final payload = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'orders': orders.map((order) => order.toMap()).toList(),
      'payments': payments.map((payment) => payment.toMap()).toList(),
    };
    final bytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    final file = XFile.fromData(
      bytes,
      mimeType: 'application/json',
      name:
          'botoys_backup_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.json',
    );
    await Share.shareXFiles([file], text: 'Botoy\'s Listahan backup');
  }

  static Future<void> shareReceipt({
    required OrderItem order,
    required List<PaymentRecord> payments,
  }) async {
    final dateFormat = DateFormat('MMM d, yyyy');
    final paid = payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );
    final balance = (order.price - paid).clamp(0, order.price);
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "Botoy's Listahan",
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Entry Receipt', style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 16),
            _receiptRow('Customer', order.customerName),
            _receiptRow('Item', order.itemName),
            _receiptRow('Type', order.type),
            _receiptRow('Status', order.paymentStatus.name),
            _receiptRow('Date', dateFormat.format(order.date)),
            if (order.dueDate != null)
              _receiptRow('Due', dateFormat.format(order.dueDate!)),
            pw.Divider(),
            _receiptRow('Price', '₱${order.price.toStringAsFixed(2)}'),
            _receiptRow('Paid', '₱${paid.toStringAsFixed(2)}'),
            _receiptRow('Balance', '₱${balance.toStringAsFixed(2)}'),
            if (payments.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text(
                'Payments',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              ...payments.map(
                (payment) => _receiptRow(
                  dateFormat.format(payment.date),
                  [
                    '₱${payment.amount.toStringAsFixed(2)}',
                    if (payment.note.trim().isNotEmpty) payment.note,
                  ].join(' • '),
                ),
              ),
            ],
            pw.Spacer(),
            pw.Text(
              'Generated ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
      ),
    );

    final file = XFile.fromData(
      await pdf.save(),
      mimeType: 'application/pdf',
      name:
          'receipt_${order.customerName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
    await Share.shareXFiles([file], text: 'Entry receipt');
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

  static pw.Widget _receiptRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
