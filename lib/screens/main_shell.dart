import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import '../services/backup_import_service.dart';
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
    final parentContext = context;
    final provider = context.read<OrderProvider>();
    final orders = provider.filteredOrders;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Export Entries',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${orders.length} entries (current month filter)',
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    sheetContext,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        ExportService.exportToCsv(orders);
                        ScaffoldMessenger.of(parentContext).showSnackBar(
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
                        Navigator.pop(sheetContext);
                        ExportService.exportToPdf(orders);
                        ScaffoldMessenger.of(parentContext).showSnackBar(
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    ExportService.exportBackup(
                      orders: provider.orders,
                      payments: provider.payments,
                    );
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(content: Text('Backup export started')),
                    );
                  },
                  icon: const Icon(Icons.backup_rounded),
                  label: const Text('Backup JSON'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _restoreFromFile(parentContext, provider);
                  },
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Upload Backup JSON'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restoreFromFile(
    BuildContext context,
    OrderProvider provider,
  ) async {
    final backup = await pickBackupJson();
    if (backup == null || backup.trim().isEmpty || !context.mounted) return;

    try {
      final preview = provider.previewBackupJson(backup);
      if (!context.mounted) return;
      final action = await showDialog<_RestoreAction>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Restore'),
          content: Text(
            'Backup contains ${preview.entries} entries, '
            '${preview.payments} payments, and ${preview.types} types.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context, _RestoreAction.merge),
              icon: const Icon(Icons.call_merge_rounded),
              label: const Text('Merge'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, _RestoreAction.replace),
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Replace'),
            ),
          ],
        ),
      );
      if (action == null || !context.mounted) return;
      if (action == _RestoreAction.merge) {
        await provider.mergeBackupJson(backup);
      } else {
        await provider.restoreBackupJson(backup);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup ${action.label}d')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }
}

enum _RestoreAction {
  merge('merge'),
  replace('replace');

  final String label;

  const _RestoreAction(this.label);
}
