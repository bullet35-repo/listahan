import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import '../widgets/order_card.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<OrderProvider>().searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMonthPicker(BuildContext context, OrderProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Month & Year'),
        content: SizedBox(
          height: 300,
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: 24,
            itemBuilder: (context, index) {
              final date = DateTime(
                DateTime.now().year,
                DateTime.now().month - index,
                1,
              );
              final month = date.month;
              final year = date.year;
              final isSelected =
                  provider.selectedMonth == month && provider.selectedYear == year;
              return ListTile(
                title: Text(DateFormat.yMMMM().format(date)),
                selected: isSelected,
                onTap: () {
                  provider.setMonthYear(month, year);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    int orderId,
    OrderProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Order'),
        content: const Text('Are you sure you want to delete this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteOrder(orderId);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Orders'),
            Consumer<OrderProvider>(
              builder: (context, p, _) => Text(
                DateFormat.yMMMM().format(
                  DateTime(p.selectedYear, p.selectedMonth, 1),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Consumer<OrderProvider>(
            builder: (context, provider, _) => IconButton(
              icon: const Icon(Icons.calendar_month_rounded),
              onPressed: () => _showMonthPicker(context, provider),
              tooltip: 'Change month',
            ),
          ),
        ],
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, _) {
          final orders = orderProvider.filteredOrders;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: orderProvider.setSearchQuery,
                      decoration: InputDecoration(
                        hintText: 'Search by customer or item...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('All'),
                            selected: orderProvider.paymentFilter == null,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              orderProvider.setPaymentFilter(null);
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Paid'),
                            selected: orderProvider.paymentFilter == PaymentStatus.paid,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              orderProvider.setPaymentFilter(PaymentStatus.paid);
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Unpaid'),
                            selected: orderProvider.paymentFilter == PaymentStatus.unpaid,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              orderProvider.setPaymentFilter(PaymentStatus.unpaid);
                            },
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Partial'),
                            selected: orderProvider.paymentFilter == PaymentStatus.partial,
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              orderProvider.setPaymentFilter(PaymentStatus.partial);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: orders.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          return Dismissible(
                            key: Key('order_${order.id}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Order'),
                                  content: const Text(
                                    'Are you sure you want to delete this order?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            onDismissed: (_) {
                              orderProvider.deleteOrder(order.id!);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Order deleted')),
                              );
                            },
                            child: OrderCard(
                              order: order,
                              onEdit: () {
                                Navigator.pushNamed(
                                  context,
                                  '/edit_order',
                                  arguments: order,
                                );
                              },
                              onDelete: () => _showDeleteConfirmation(
                                context,
                                order.id!,
                                orderProvider,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 80,
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No orders for this month',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different month or add new orders.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
