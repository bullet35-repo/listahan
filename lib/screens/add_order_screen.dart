import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import '../widgets/order_type_field.dart';
import 'package:intl/intl.dart';

void _hapticSuccess() => HapticFeedback.mediumImpact();

class AddOrderScreen extends StatefulWidget {
  const AddOrderScreen({super.key});

  @override
  State<AddOrderScreen> createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _itemNameController = TextEditingController();
  final _typeController = TextEditingController(text: 'Bugasan');
  final _priceController = TextEditingController();
  final _commissionController = TextEditingController();
  final _paidAmountController = TextEditingController(text: '0');

  DateTime _selectedDate = DateTime.now();
  PaymentStatus _paymentStatus = PaymentStatus.unpaid;
  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _itemNameController.dispose();
    _typeController.dispose();
    _priceController.dispose();
    _commissionController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.parse(_priceController.text);
    double paid = 0;
    if (_paymentStatus == PaymentStatus.partial) {
      paid = double.tryParse(_paidAmountController.text) ?? 0;
    } else if (_paymentStatus == PaymentStatus.paid) {
      paid = price;
    }
    final order = OrderItem(
      customerName: _customerNameController.text,
      itemName: _itemNameController.text,
      type: _typeController.text.trim(),
      price: price,
      commission: double.parse(_commissionController.text),
      date: _selectedDate,
      paymentStatus: _paymentStatus,
      dueDate: _dueDate,
      paidAmount: paid,
    );

    setState(() => _isSaving = true);
    try {
      await Provider.of<OrderProvider>(context, listen: false).addOrder(order);
      if (!mounted) return;
      _hapticSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry saved successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save entry: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Entry'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _customerNameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter customer name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _itemNameController,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter item name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              OrderTypeField(controller: _typeController),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments),
                  prefixText: '₱ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter price';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _commissionController,
                decoration: const InputDecoration(
                  labelText: 'Commission',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_wallet),
                  prefixText: '₱ ',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter commission';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SegmentedButton<PaymentStatus>(
                segments: const [
                  ButtonSegment(
                    value: PaymentStatus.unpaid,
                    label: Text('Unpaid'),
                  ),
                  ButtonSegment(
                    value: PaymentStatus.partial,
                    label: Text('Partial'),
                  ),
                  ButtonSegment(value: PaymentStatus.paid, label: Text('Paid')),
                ],
                selected: {_paymentStatus},
                onSelectionChanged: (s) =>
                    setState(() => _paymentStatus = s.first),
              ),
              if (_paymentStatus == PaymentStatus.partial) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _paidAmountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount Paid',
                    border: OutlineInputBorder(),
                    prefixText: '₱ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  validator: (v) {
                    if (_paymentStatus != PaymentStatus.partial) return null;
                    final paid = double.tryParse(v ?? '') ?? 0;
                    if (paid < 0) return 'Invalid amount';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDueDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due Date (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.event_rounded),
                  ),
                  child: Text(
                    _dueDate != null
                        ? DateFormat.yMMMd().format(_dueDate!)
                        : 'None',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              if (_dueDate != null)
                TextButton(
                  onPressed: () => setState(() => _dueDate = null),
                  child: const Text('Clear due date'),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Today'),
                    selected: _isSameDay(_selectedDate, DateTime.now()),
                    onSelected: (_) =>
                        setState(() => _selectedDate = DateTime.now()),
                  ),
                  FilterChip(
                    label: const Text('Yesterday'),
                    selected: _isSameDay(
                      _selectedDate,
                      DateTime.now().subtract(const Duration(days: 1)),
                    ),
                    onSelected: (_) => setState(
                      () => _selectedDate = DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat.yMMMd().format(_selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveOrder,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : const Text(
                          'Save Entry',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
