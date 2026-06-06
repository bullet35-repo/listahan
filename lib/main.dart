import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/order_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/add_order_screen.dart';
import 'screens/edit_order_screen.dart';
import 'screens/entry_detail_screen.dart';
import 'screens/main_shell.dart';
import 'screens/orders_list_screen.dart';
import 'screens/reports_screen.dart';
import 'models/order.dart';

import 'database/database_init_stub.dart'
    if (dart.library.html) 'database/database_init_web.dart'
    if (dart.library.io) 'database/database_init_io.dart'
    as db_init;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  db_init.initDatabase();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OrderProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const BotoysListahanApp(),
    ),
  );
}

class BotoysListahanApp extends StatelessWidget {
  const BotoysListahanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: "Botoy's Listahan",
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: themeProvider.themeMode,
          initialRoute: '/',
          routes: {
            '/': (context) => const MainShell(),
            '/add_order': (context) => const AddOrderScreen(),
            '/orders_list': (context) => const OrdersListScreen(),
            '/reports': (context) => const ReportsScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/edit_order') {
              final order = settings.arguments as OrderItem;
              return MaterialPageRoute(
                builder: (context) => EditOrderScreen(order: order),
              );
            }
            if (settings.name == '/entry_detail') {
              final order = settings.arguments as OrderItem;
              return MaterialPageRoute(
                builder: (context) => EntryDetailScreen(order: order),
              );
            }
            return null; // fallback
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1976D2),
      brightness: brightness,
      primary: const Color(0xFF1976D2),
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      cardTheme: CardThemeData(
        color: isDark ? colorScheme.surfaceContainerHigh : Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 3,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
