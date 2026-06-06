import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import '../widgets/order_card.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      body: Consumer<OrderProvider>(
        builder: (context, provider, child) {
          final customerMap = <String, List<OrderItem>>{};
          for (final order in provider.orders) {
            customerMap.putIfAbsent(order.customerName, () => []).add(order);
          }
          final customers = customerMap.entries.toList()
            ..sort((a, b) => b.value.length.compareTo(a.value.length));

          if (customers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 80,
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No customers yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: customers.length,
            itemBuilder: (context, index) {
              final entry = customers[index];
              final name = entry.key;
              final orders = entry.value;
              final totalPrice = orders.fold<double>(0, (s, o) => s + o.price);
              final totalCommission = orders.fold<double>(
                0,
                (s, o) => s + o.commission,
              );

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _openCustomerDetail(context, name, orders),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${orders.length} order${orders.length == 1 ? '' : 's'} • ₱${totalPrice.toStringAsFixed(0)} total',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₱${totalCommission.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'commission',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openCustomerDetail(
    BuildContext context,
    String customerName,
    List<OrderItem> orders,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerDetailScreen(customerName: customerName),
      ),
    );
  }
}

class CustomerDetailScreen extends StatelessWidget {
  final String customerName;

  const CustomerDetailScreen({super.key, required this.customerName});

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, provider, child) {
        final orders =
            provider.orders
                .where((o) => o.customerName == customerName)
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));
        final totalPrice = orders.fold<double>(0, (s, o) => s + o.price);
        final totalCommission = orders.fold<double>(
          0,
          (s, o) => s + o.commission,
        );
        final balance = provider.customerBalance(customerName);

        return Scaffold(
          appBar: AppBar(
            title: Text(customerName),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      alignment: WrapAlignment.spaceAround,
                      spacing: 24,
                      runSpacing: 16,
                      children: [
                        _buildStat(
                          context,
                          'Orders',
                          '${orders.length}',
                          Icons.receipt_long_rounded,
                        ),
                        _buildStat(
                          context,
                          'Sales',
                          '₱${totalPrice.toStringAsFixed(0)}',
                          Icons.point_of_sale_rounded,
                        ),
                        _buildStat(
                          context,
                          'Commission',
                          '₱${totalCommission.toStringAsFixed(0)}',
                          Icons.account_balance_wallet_rounded,
                        ),
                        _buildStat(
                          context,
                          'Balance',
                          '₱${balance.toStringAsFixed(0)}',
                          Icons.balance_rounded,
                          isBalance: balance > 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Order history',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return OrderCard(
                      order: order,
                      onEdit: () {
                        Navigator.pushNamed(
                          context,
                          '/edit_order',
                          arguments: order,
                        );
                      },
                      onDelete: () =>
                          _showDeleteOrder(context, order, provider),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteOrder(
    BuildContext context,
    OrderItem order,
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
              provider.deleteOrder(order.id!);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Order deleted')));
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool isBalance = false,
  }) {
    final color = isBalance
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
