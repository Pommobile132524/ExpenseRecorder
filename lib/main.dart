import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  runApp(const GoldPurchaseApp());
}

final supa = Supabase.instance.client;

class GoldPurchaseApp extends StatelessWidget {
  const GoldPurchaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ระบบรับซื้อ',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const _AuthGate(),
    );
  }
}

/// เลือกหน้าแรกตามสถานะล็อกอิน และเปลี่ยนหน้าอัตโนมัติเมื่อ login/logout
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supa.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supa.auth.currentSession;
        if (session == null) return const LoginScreen();
        return const DashboardScreen();
      },
    );
  }
}
