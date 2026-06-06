import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../services/export_service.dart';
import 'home_screen.dart';
import 'customers_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _screens = const [HomeScreen(), CustomersScreen(), SettingsScreen()];

  int get _screenIndex => _currentIndex > 2 ? _currentIndex - 1 : _currentIndex;

  void _onAddPressed(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.pushNamed(context, '/add_order');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _screenIndex, children: _screens),
      bottomNavigationBar: BottomAppBar(
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                0,
                Icons.home_outlined,
                Icons.home_rounded,
                'Home',
              ),
              _buildNavItem(
                context,
                1,
                Icons.people_outline_rounded,
                Icons.people_rounded,
                'Customers',
              ),
              _buildAddItem(context),
              _buildNavItem(
                context,
                2,
                Icons.download_outlined,
                Icons.download_rounded,
                'Export',
                isAction: true,
              ),
              _buildNavItem(
                context,
                3,
                Icons.settings_outlined,
                Icons.settings_rounded,
                'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddItem(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onAddPressed(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 24),
              const SizedBox(height: 4),
              Text('Add', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    bool isAction = false,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isAction) {
              _showExportSheet(context);
            } else {
              setState(() => _currentIndex = index);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isSelected ? activeIcon : icon, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportSheet(BuildContext context) {
    final provider = context.read<OrderProvider>();
    final orders = provider.filteredOrders;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Export Orders',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${orders.length} orders (current month filter)',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ExportService.exportToCsv(orders);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Export started')),
                        );
                      },
                      icon: const Icon(Icons.table_chart_rounded),
                      label: const Text('CSV'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ExportService.exportToPdf(orders);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Export started')),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('PDF'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
