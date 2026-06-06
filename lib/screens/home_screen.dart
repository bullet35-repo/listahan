import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../providers/order_provider.dart';
import '../utils/format_utils.dart';
import '../widgets/order_card.dart';
import '../widgets/shimmer_loading.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      Provider.of<OrderProvider>(context, listen: false).fetchOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh(OrderProvider provider) async {
    await provider.fetchOrders();
  }

  void _showMonthPicker(BuildContext context, OrderProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Month & Year'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 300,
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: 24, // Past 24 months
                  itemBuilder: (context, index) {
                    final date = DateTime(
                      DateTime.now().year,
                      DateTime.now().month - index,
                      1,
                    );
                    final month = date.month;
                    final year = date.year;
                    final isSelected =
                        provider.selectedMonth == month &&
                        provider.selectedYear == year;
                    return ListTile(
                      title: Text(DateFormat.yMMMM().format(date)),
                      selected: isSelected,
                      onTap: () {
                        provider.setMonthYear(month, year);
                        Navigator.of(context).pop();
                      },
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 400;
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Icon(
            Icons.checklist_rounded,
            color: theme.colorScheme.primary,
            size: 28,
          ),
        ),
        leadingWidth: 44,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Botoy's Listahan",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Consumer<OrderProvider>(
              builder: (context, p, _) => Text(
                'Order tracker${p.filteredOrders.isNotEmpty ? ' • ${p.filteredOrders.length} orders' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Consumer<OrderProvider>(
            builder: (context, provider, child) {
              final currentMonth = DateFormat.MMM().format(
                DateTime(provider.selectedYear, provider.selectedMonth),
              );
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isNarrow)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 8,
                        top: 4,
                        bottom: 4,
                      ),
                      child: Material(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () => _showMonthPicker(context, provider),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$currentMonth ${provider.selectedYear}',
                                  style: theme.textTheme.labelLarge,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.calendar_month_rounded),
                      tooltip: 'Select month & year',
                      onPressed: () => _showMonthPicker(context, provider),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<OrderProvider>(
        builder: (context, orderProvider, child) {
          if (orderProvider.isLoading && orderProvider.orders.isEmpty) {
            return const ShimmerLoading();
          }

          final orders = orderProvider.filteredOrders;
          final currentFilterDate = DateTime(
            orderProvider.selectedYear,
            orderProvider.selectedMonth,
          );

          return RefreshIndicator(
            onRefresh: () => _onRefresh(orderProvider),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Summary for ${DateFormat.yMMMM().format(currentFilterDate)}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryCard(
                                        title: 'Total Orders',
                                        value:
                                            '${orderProvider.totalOrdersThisMonth}',
                                        color: Colors.blueAccent,
                                        icon: Icons.list_alt,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildSummaryCard(
                                        title: 'Sales',
                                        value: formatCurrency(
                                          orderProvider.totalSalesThisMonth,
                                          compact: true,
                                        ),
                                        color: Colors.orangeAccent,
                                        icon: Icons.point_of_sale,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildSummaryCard(
                                  title: 'Income',
                                  value: formatCurrency(
                                    orderProvider.totalIncomeThisMonth,
                                    compact: true,
                                  ),
                                  color: Colors.green,
                                  icon: Icons.account_balance_wallet,
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildPeriodComparison(context, orderProvider),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider()),
                SliverToBoxAdapter(
                  child: _buildRemindersSection(context, orderProvider),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, child) {
                        return TextField(
                          controller: _searchController,
                          onChanged: orderProvider.setSearchQuery,
                          decoration: InputDecoration(
                            hintText: 'Search by customer or item...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: value.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchController.clear();
                                      orderProvider.setSearchQuery('');
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            isDense: true,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            FilterChip(
                              label: const Text('All'),
                              selected: orderProvider.paymentFilter == null,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                orderProvider.setPaymentFilter(null);
                              },
                            ),
                            FilterChip(
                              label: const Text('Paid'),
                              selected:
                                  orderProvider.paymentFilter ==
                                  PaymentStatus.paid,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                orderProvider.setPaymentFilter(
                                  PaymentStatus.paid,
                                );
                              },
                            ),
                            FilterChip(
                              label: const Text('Unpaid'),
                              selected:
                                  orderProvider.paymentFilter ==
                                  PaymentStatus.unpaid,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                orderProvider.setPaymentFilter(
                                  PaymentStatus.unpaid,
                                );
                              },
                            ),
                            FilterChip(
                              label: const Text('Partial'),
                              selected:
                                  orderProvider.paymentFilter ==
                                  PaymentStatus.partial,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                orderProvider.setPaymentFilter(
                                  PaymentStatus.partial,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Orders',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.pushNamed(context, '/orders_list');
                              },
                              icon: const Icon(Icons.list_rounded, size: 20),
                              label: const Text('View all'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                orders.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(context),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
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
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
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
                              onDelete: () {
                                _showDeleteConfirmation(
                                  context,
                                  order.id!,
                                  orderProvider,
                                );
                              },
                            ),
                          );
                        }, childCount: orders.length),
                      ),
              ],
            ),
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
              size: 100,
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No orders yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add an order.',
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

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.25)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodComparison(BuildContext context, OrderProvider provider) {
    final prev = DateTime(provider.selectedYear, provider.selectedMonth, 0);
    final currSales = provider.totalSalesThisMonth;
    final prevSales = provider.salesForMonth(prev.month, prev.year);
    final currComm = provider.totalIncomeThisMonth;
    final prevComm = provider.commissionForMonth(prev.month, prev.year);
    final salesDiff = currSales - prevSales;
    final commDiff = currComm - prevComm;
    final salesUp = salesDiff >= 0;
    final commUp = commDiff >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.compare_arrows_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'vs ${DateFormat.MMM().format(prev)} ${prev.year}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${salesUp ? '+' : ''}₱${salesDiff.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: salesUp ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Commission',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${commUp ? '+' : ''}₱${commDiff.abs().toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: commUp ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersSection(BuildContext context, OrderProvider provider) {
    final upcoming = provider.upcomingOrOverdueOrders;
    final unpaidCount = provider.unpaidOrders.length;
    final now = DateTime.now();
    final overdue = upcoming.where((o) => o.dueDate!.isBefore(now)).toList();
    final dueSoon = upcoming.where((o) {
      final d = o.dueDate!;
      final diff = d.difference(now).inDays;
      return diff >= 0 && diff <= 7;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reminders',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All caught up!',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          unpaidCount == 0
                              ? 'No unpaid orders.'
                              : 'No orders with due dates.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (overdue.isNotEmpty) ...[
              _reminderChip(context, 'Overdue (${overdue.length})', Colors.red),
              const SizedBox(height: 4),
              ...overdue
                  .take(3)
                  .map(
                    (o) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                        title: Text(o.customerName),
                        subtitle: Text(
                          '${formatCurrency(o.balance, compact: true)} • Due ${DateFormat.yMMMd().format(o.dueDate!)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/edit_order',
                          arguments: o,
                        ),
                      ),
                    ),
                  ),
              if (overdue.length > 3)
                TextButton(
                  onPressed: () {},
                  child: Text('View all ${overdue.length}'),
                ),
              const SizedBox(height: 8),
            ],
            if (dueSoon.isNotEmpty) ...[
              _reminderChip(
                context,
                'Due in 7 days (${dueSoon.length})',
                Colors.orange,
              ),
              const SizedBox(height: 4),
              ...dueSoon
                  .take(2)
                  .map(
                    (o) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.event_rounded,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        title: Text(o.customerName),
                        subtitle: Text(
                          '${formatCurrency(o.balance, compact: true)} • ${DateFormat.yMMMd().format(o.dueDate!)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/edit_order',
                          arguments: o,
                        ),
                      ),
                    ),
                  ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _reminderChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
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
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Delete Order'),
          content: const Text('Are you sure you want to delete this order?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                provider.deleteOrder(orderId);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Order deleted')));
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
