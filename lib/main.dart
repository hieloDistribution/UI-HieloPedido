import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/auth/token_storage.dart';
import 'core/theme/theme.dart';
import 'providers/order_provider.dart';
import 'screens/welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final hasSession = await TokenStorage.instance.isAuthenticated();

  runApp(
    ChangeNotifierProvider(
      create: (_) => OrderProvider(),
      child: MyApp(initialAuthenticated: hasSession),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool initialAuthenticated;
  const MyApp({super.key, required this.initialAuthenticated});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final user = provider.currentUser;
    final isAuthed = provider.isHydrated ? (user != null) : initialAuthenticated;

    return MaterialApp(
      title: 'Hielo Distribution',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: isAuthed ? const MainNavigationScreen() : const AuthFlowWrapper(),
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