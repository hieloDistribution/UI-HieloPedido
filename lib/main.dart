import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'providers/order_provider.dart';
import 'core/theme/theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  // Ensure Flutter binding is initialized (needed for native plugins / SQLite)
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase Cloud config
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  
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
    final provider = context.watch<OrderProvider>();
    final user = provider.currentUser;

    return MaterialApp(
      title: 'Hielo Distribution',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: user == null ? const LoginScreen() : const MainNavigationScreen(),
    );
  }
}
