import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../providers/order_provider.dart';
import '../services/export_service.dart';
import '../widgets/order_type_field.dart';
import '../widgets/payment_dialog.dart';
import 'package:intl/intl.dart';

void _hapticSuccess() => HapticFeedback.mediumImpact();

class EditOrderScreen extends StatefulWidget {
  final OrderItem order;

  const EditOrderScreen({super.key, required this.order});

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _customerNameController;
  late TextEditingController _itemNameController;
  late TextEditingController _typeController;
  late TextEditingController _priceController;
  late TextEditingController _commissionController;
  late TextEditingController _paidAmountController;

  late DateTime _selectedDate;
  late PaymentStatus _paymentStatus;
  DateTime? _dueDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _customerNameController = TextEditingController(
      text: widget.order.customerName,
    );
    _itemNameController = TextEditingController(text: widget.order.itemName);
    _typeController = TextEditingController(text: widget.order.type);
    _priceController = TextEditingController(
      text: widget.order.price.toString(),
    );
    _commissionController = TextEditingController(
      text: widget.order.commission.toString(),
    );
    _paidAmountController = TextEditingController(
      text: widget.order.paidAmount.toString(),
    );
    _selectedDate = widget.order.date;
    _paymentStatus = widget.order.paymentStatus;
    _dueDate = widget.order.dueDate;
  }

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

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _dueDate = picked);
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

  Future<void> _updateOrder() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.parse(_priceController.text);
    double paid = 0;
    if (_paymentStatus == PaymentStatus.partial) {
      paid = double.tryParse(_paidAmountController.text) ?? 0;
    } else if (_paymentStatus == PaymentStatus.paid) {
      paid = price;
    }
    final updatedOrder = widget.order.copyWith(
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
      await Provider.of<OrderProvider>(
        context,
        listen: false,
      ).updateOrder(updatedOrder);
      if (!mounted) return;
      _hapticSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry updated successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showAddPaymentDialog(OrderProvider provider) async {
    final order = provider.orders.firstWhere(
      (item) => item.id == widget.order.id,
      orElse: () => widget.order,
    );
    final balance = provider.balanceForOrder(order);
    final payment = await showDialog<PaymentDraft>(
      context: context,
      builder: (context) => PaymentDialog(maxAmount: balance),
    );
    if (payment == null) return;
    try {
      await provider.addPayment(
        order: order,
        amount: payment.amount,
        date: payment.date,
        note: payment.note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment added')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
    }
  }

  Future<void> _showEditPaymentDialog(
    OrderProvider provider,
    PaymentRecord payment,
  ) async {
    final order = provider.orders.firstWhere(
      (item) => item.id == payment.orderId,
    );
    final maxAmount = provider.balanceForOrder(order) + payment.amount;
    final draft = await showDialog<PaymentDraft>(
      context: context,
      builder: (context) =>
          PaymentDialog(payment: payment, maxAmount: maxAmount),
    );
    if (draft == null) return;
    try {
      await provider.updatePayment(
        payment: payment,
        amount: draft.amount,
        date: draft.date,
        note: draft.note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Entry'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<OrderProvider>(
            builder: (context, provider, child) {
              final order = provider.orders.firstWhere(
                (item) => item.id == widget.order.id,
                orElse: () => widget.order,
              );
              final payments = order.id == null
                  ? <PaymentRecord>[]
                  : provider.paymentsForOrder(order.id!);
              return IconButton(
                icon: const Icon(Icons.receipt_long_rounded),
                tooltip: 'Share receipt',
                onPressed: () => ExportService.shareReceipt(
                  order: order,
                  payments: payments,
                ),
              );
            },
          ),
        ],
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
              const SizedBox(height: 16),
              Consumer<OrderProvider>(
                builder: (context, provider, child) {
                  final order = provider.orders.firstWhere(
                    (item) => item.id == widget.order.id,
                    orElse: () => widget.order,
                  );
                  final payments = order.id == null
                      ? const []
                      : provider.paymentsForOrder(order.id!);
                  final paid = order.id == null
                      ? order.paidAmount
                      : provider.paidTotalForOrder(order.id!);
                  final balance = (order.price - paid).clamp(0, order.price);

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Payment History',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () =>
                                    _showAddPaymentDialog(provider),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Payment'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Paid ₱${paid.toStringAsFixed(2)} • Balance ₱${balance.toStringAsFixed(2)}',
                          ),
                          const Divider(height: 24),
                          if (payments.isEmpty)
                            const Text('No payment records yet.')
                          else
                            ...payments.map(
                              (payment) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '₱${payment.amount.toStringAsFixed(2)}',
                                ),
                                subtitle: Text(
                                  [
                                    DateFormat.yMMMd().format(payment.date),
                                    if (payment.note.trim().isNotEmpty)
                                      payment.note,
                                  ].join(' • '),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  tooltip: 'Payment actions',
                                  onPressed: payment.id == null
                                      ? null
                                      : () => showModalBottomSheet(
                                          context: context,
                                          builder: (context) => SafeArea(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.edit_rounded,
                                                  ),
                                                  title: const Text('Edit'),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    _showEditPaymentDialog(
                                                      provider,
                                                      payment,
                                                    );
                                                  },
                                                ),
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.delete_rounded,
                                                  ),
                                                  title: const Text('Delete'),
                                                  onTap: () {
                                                    Navigator.pop(context);
                                                    provider.deletePayment(
                                                      payment,
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _updateOrder,
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
                          'Update Entry',
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
