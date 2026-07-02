import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/order_provider.dart';
import 'core/theme/theme.dart';
import 'screens/home_screen.dart';

void main() {
  // Ensure Flutter binding is initialized (needed for native plugins / SQLite)
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => OrderProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OrderFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
