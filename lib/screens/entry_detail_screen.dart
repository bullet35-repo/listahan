import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../models/payment.dart';
import '../providers/order_provider.dart';
import '../services/export_service.dart';
import '../utils/format_utils.dart';
import '../widgets/payment_dialog.dart';

class EntryDetailScreen extends StatelessWidget {
  final OrderItem order;

  const EntryDetailScreen({super.key, required this.order});

  Future<void> _addPayment(BuildContext context, OrderProvider provider) async {
    final current = _currentOrder(provider);
    final balance = provider.balanceForOrder(current);
    final draft = await showDialog<PaymentDraft>(
      context: context,
      builder: (context) => PaymentDialog(maxAmount: balance),
    );
    if (draft == null || !context.mounted) return;
    try {
      await provider.addPayment(
        order: current,
        amount: draft.amount,
        date: draft.date,
        note: draft.note,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment added')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
    }
  }

  Future<void> _editPayment(
    BuildContext context,
    OrderProvider provider,
    PaymentRecord payment,
  ) async {
    final current = _currentOrder(provider);
    final maxAmount = provider.balanceForOrder(current) + payment.amount;
    final draft = await showDialog<PaymentDraft>(
      context: context,
      builder: (context) =>
          PaymentDialog(payment: payment, maxAmount: maxAmount),
    );
    if (draft == null || !context.mounted) return;
    await provider.updatePayment(
      payment: payment,
      amount: draft.amount,
      date: draft.date,
      note: draft.note,
    );
  }

  OrderItem _currentOrder(OrderProvider provider) {
    return provider.orders.firstWhere(
      (entry) => entry.id == order.id,
      orElse: () => order,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        final current = _currentOrder(provider);
        final payments = current.id == null
            ? <PaymentRecord>[]
            : provider.paymentsForOrder(current.id!);
        final paid = current.id == null
            ? current.paidAmount
            : provider.paidTotalForOrder(current.id!);
        final balance = provider.balanceForOrder(current);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Entry Detail'),
            actions: [
              IconButton(
                icon: const Icon(Icons.receipt_long_rounded),
                tooltip: 'Share receipt',
                onPressed: () => ExportService.shareReceipt(
                  order: current,
                  payments: payments,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Edit',
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/edit_order',
                  arguments: current,
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        current.itemName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(label: Text(current.type)),
                          Chip(label: Text(current.paymentStatus.name)),
                          Chip(
                            label: Text(
                              DateFormat.yMMMd().format(current.date),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _row('Customer', current.customerName),
                      _row('Price', formatCurrency(current.price)),
                      _row('Commission', formatCurrency(current.commission)),
                      _row('Paid', formatCurrency(paid)),
                      _row('Balance', formatCurrency(balance)),
                      if (current.dueDate != null)
                        _row(
                          'Due',
                          DateFormat.yMMMd().format(current.dueDate!),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Payments',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: balance <= 0
                                ? null
                                : () => _addPayment(context, provider),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Payment'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (payments.isEmpty)
                        const Text('No payment records yet.')
                      else
                        ...payments.map(
                          (payment) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(formatCurrency(payment.amount)),
                            subtitle: Text(
                              [
                                DateFormat.yMMMd().format(payment.date),
                                if (payment.note.trim().isNotEmpty)
                                  payment.note,
                              ].join(' • '),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editPayment(context, provider, payment);
                                } else if (value == 'delete') {
                                  provider.deletePayment(payment);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
