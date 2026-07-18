import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/order_provider.dart';
import 'core/theme/theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
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
    final provider = context.watch<OrderProvider>();
    final user = provider.currentUser;

    return MaterialApp(
      title: 'Hielo Distribution',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: user == null ? const AuthFlowWrapper() : const MainNavigationScreen(),
    );
  }
}

class AuthFlowWrapper extends StatefulWidget {
  const AuthFlowWrapper({super.key});

  @override
  State<AuthFlowWrapper> createState() => _AuthFlowWrapperState();
}

class _AuthFlowWrapperState extends State<AuthFlowWrapper> {
  bool _showLogin = false;

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      return LoginScreen(onBack: () => setState(() => _showLogin = false));
    } else {
      return WelcomeScreen(onComenzar: () => setState(() => _showLogin = true));
    }
  }
}
