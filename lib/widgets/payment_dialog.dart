import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/payment.dart';

class PaymentDraft {
  final double amount;
  final DateTime date;
  final String note;

  const PaymentDraft({
    required this.amount,
    required this.date,
    required this.note,
  });
}

class PaymentDialog extends StatefulWidget {
  final PaymentRecord? payment;
  final double maxAmount;

  const PaymentDialog({super.key, this.payment, required this.maxAmount});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.payment?.amount.toString() ?? '',
    );
    _noteController = TextEditingController(text: widget.payment?.note ?? '');
    _date = widget.payment?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      PaymentDraft(
        amount: double.parse(_amountController.text),
        date: _date,
        note: _noteController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.payment != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Payment' : 'Add Payment'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Amount',
                helperText: 'Max ₱${widget.maxAmount.toStringAsFixed(2)}',
                border: const OutlineInputBorder(),
                prefixText: '₱ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                if (amount == null || amount <= 0) return 'Enter amount';
                if (amount > widget.maxAmount) {
                  return 'Amount exceeds remaining balance';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
                child: Text(DateFormat.yMMMd().format(_date)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: Icon(isEdit ? Icons.check_rounded : Icons.add_rounded),
          label: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
