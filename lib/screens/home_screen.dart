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
  static const String _allTypes = 'All types';
  static const String _addType = 'Add type...';
  static const String _manageTypes = 'Manage types...';

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

  Future<void> _showAddTypeDialog(OrderProvider provider) async {
    final type = await showDialog<String>(
      context: context,
      builder: (context) => _TypeNameDialog(
        title: 'Add Type',
        actionLabel: 'Add',
        actionIcon: Icons.add_rounded,
        existingTypes: provider.orderTypes,
      ),
    );

    if (type == null || type.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.addOrderType(type);
    });
  }

  Future<void> _showEditTypeDialog(
    OrderProvider provider,
    String currentType,
  ) async {
    final newType = await showDialog<String>(
      context: context,
      builder: (context) => _TypeNameDialog(
        title: 'Edit Type',
        actionLabel: 'Save',
        actionIcon: Icons.check_rounded,
        initialValue: currentType,
        existingTypes: provider.orderTypes,
        ignoredDuplicate: currentType,
      ),
    );

    if (newType == null || newType.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.renameOrderType(currentType, newType);
    });
  }

  Future<void> _confirmDeleteType(OrderProvider provider, String type) async {
    final orderCount = provider.orderCountForType(type);
    final fallbackType = provider.orderTypes.firstWhere(
      (orderType) => orderType != type,
      orElse: () => 'another type',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $type?'),
        content: Text(
          orderCount == 0
              ? 'This removes the type from your list.'
              : '$orderCount entr${orderCount == 1 ? 'y' : 'ies'} will move to $fallbackType.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_rounded),
            label: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.deleteOrderType(type);
    });
  }

  Future<void> _showManageTypesDialog(OrderProvider provider) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Consumer<OrderProvider>(
        builder: (context, provider, child) {
          final types = provider.orderTypes;
          return AlertDialog(
            title: const Text('Manage Types'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: types.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final type = types[index];
                  final count = provider.orderCountForType(type);
                  final isLastType = types.length == 1;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(type),
                    subtitle: Text(
                      '${provider.isDefaultType(type) ? 'Default type • ' : ''}'
                      '$count entr${count == 1 ? 'y' : 'ies'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded),
                          tooltip: 'Edit',
                          onPressed: () => _showEditTypeDialog(provider, type),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_rounded),
                          tooltip: isLastType
                              ? 'At least one type is required'
                              : 'Delete',
                          onPressed: isLastType
                              ? null
                              : () => _confirmDeleteType(provider, type),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () => _showAddTypeDialog(provider),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Type'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleTypeMenuSelection(OrderProvider provider, String type) {
    HapticFeedback.selectionClick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (type == _addType) {
        _showAddTypeDialog(provider);
        return;
      }
      if (type == _manageTypes) {
        _showManageTypesDialog(provider);
        return;
      }
      provider.setTypeFilter(type == _allTypes ? null : type);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 400;
    return Scaffold(
      appBar: AppBar(
        leading: Consumer<OrderProvider>(
          builder: (context, provider, child) {
            final selectedType = provider.typeFilter ?? _allTypes;
            return PopupMenuButton<String>(
              tooltip: 'Select type',
              initialValue: selectedType,
              onSelected: (type) => _handleTypeMenuSelection(provider, type),
              itemBuilder: (context) => [
                CheckedPopupMenuItem<String>(
                  value: _allTypes,
                  checked: provider.typeFilter == null,
                  child: const Text(_allTypes),
                ),
                for (final type in provider.orderTypes)
                  CheckedPopupMenuItem<String>(
                    value: type,
                    checked: provider.typeFilter == type,
                    child: Text(type),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: _addType,
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded),
                      SizedBox(width: 12),
                      Text(_addType),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: _manageTypes,
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded),
                      SizedBox(width: 12),
                      Text(_manageTypes),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.checklist_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        leadingWidth: 56,
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
                'List tracker${p.filteredOrders.isNotEmpty ? ' • ${p.filteredOrders.length} entries' : ''}',
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
                          '${orderProvider.typeFilter ?? 'All types'} summary for ${DateFormat.yMMMM().format(currentFilterDate)}',
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
                                        title: 'Total Entries',
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
                        const SizedBox(height: 16),
                        _buildTypeDashboard(context, orderProvider),
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
                              label: const Text('Today'),
                              selected:
                                  orderProvider.dateFilter ==
                                  EntryDateFilter.today,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                orderProvider.setDateFilter(
                                  EntryDateFilter.today,
                                );
                              },
                            ),
                            FilterChip(
                              label: const Text('Week'),
                              selected:
                                  orderProvider.dateFilter ==
                                  EntryDateFilter.week,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                orderProvider.setDateFilter(
                                  EntryDateFilter.week,
                                );
                              },
                            ),
                            FilterChip(
                              label: const Text('Month'),
                              selected:
                                  orderProvider.dateFilter ==
                                  EntryDateFilter.month,
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                orderProvider.setDateFilter(
                                  EntryDateFilter.month,
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                              'Recent Entries',
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
                                  title: const Text('Delete Entry'),
                                  content: const Text(
                                    'Are you sure you want to delete this entry?',
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
                                const SnackBar(content: Text('Entry deleted')),
                              );
                            },
                            child: OrderCard(
                              order: order,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/entry_detail',
                                  arguments: order,
                                );
                              },
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
              'No entries yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add an entry.',
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
    final prevSales = provider.salesForMonth(
      prev.month,
      prev.year,
      type: provider.typeFilter,
    );
    final currComm = provider.totalIncomeThisMonth;
    final prevComm = provider.commissionForMonth(
      prev.month,
      prev.year,
      type: provider.typeFilter,
    );
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

  Widget _buildTypeDashboard(BuildContext context, OrderProvider provider) {
    final types = provider.orderTypes;
    final monthEntries = provider.ordersForMonth(
      provider.selectedMonth,
      provider.selectedYear,
    );
    final cards = types
        .map((type) {
          final entries = monthEntries
              .where((entry) => entry.type == type)
              .toList();
          final sales = entries.fold<double>(
            0,
            (sum, entry) => sum + entry.price,
          );
          final balance = entries.fold<double>(
            0,
            (sum, entry) => sum + entry.balance,
          );
          return _TypeSummary(
            type: type,
            count: entries.length,
            sales: sales,
            balance: balance,
          );
        })
        .where((summary) => summary.count > 0)
        .toList();

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Types',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final summary in cards)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: const Icon(Icons.category_rounded, size: 16),
                    label: Text(
                      '${summary.type} • ${summary.count} • ₱${summary.sales.toStringAsFixed(0)}',
                    ),
                    onPressed: () => provider.setTypeFilter(summary.type),
                  ),
                ),
            ],
          ),
        ),
      ],
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
                              ? 'No unpaid entries.'
                              : 'No entries with due dates.',
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
          title: const Text('Delete Entry'),
          content: const Text('Are you sure you want to delete this entry?'),
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
                ).showSnackBar(const SnackBar(content: Text('Entry deleted')));
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

class _TypeSummary {
  final String type;
  final int count;
  final double sales;
  final double balance;

  const _TypeSummary({
    required this.type,
    required this.count,
    required this.sales,
    required this.balance,
  });
}

class _TypeNameDialog extends StatefulWidget {
  final String title;
  final String actionLabel;
  final IconData actionIcon;
  final List<String> existingTypes;
  final String? initialValue;
  final String? ignoredDuplicate;

  const _TypeNameDialog({
    required this.title,
    required this.actionLabel,
    required this.actionIcon,
    required this.existingTypes,
    this.initialValue,
    this.ignoredDuplicate,
  });

  @override
  State<_TypeNameDialog> createState() => _TypeNameDialogState();
}

class _TypeNameDialogState extends State<_TypeNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Type name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category_rounded),
          ),
          validator: (value) {
            final type = value?.trim() ?? '';
            if (type.isEmpty) return 'Please enter type name';

            final ignored = widget.ignoredDuplicate?.toLowerCase();
            final exists = widget.existingTypes.any((existingType) {
              final normalized = existingType.toLowerCase();
              return normalized == type.toLowerCase() && normalized != ignored;
            });
            if (exists) return 'Type already exists';
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: Icon(widget.actionIcon),
          label: Text(widget.actionLabel),
        ),
      ],
    );
  }
}
