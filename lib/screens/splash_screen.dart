import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'business/business_home_screen.dart';
import 'customer/customer_shell_screen.dart';
import 'admin/admin_home_screen.dart';

/// Checks whether a user is already logged in and routes them straight
/// to their role-specific home screen. Otherwise shows the login screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Navigating during initState() itself crashes with "setState() or
    // markNeedsBuild() called during build" because the widget tree
    // (including the Navigator) is still being built for the first time.
    // Waiting for the first frame to finish makes it safe to navigate.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLoginState();
    });
  }

  Future<void> _checkLoginState() async {
    final firebaseUser = _authService.currentUser;

    if (firebaseUser == null) {
      _goTo(const LoginScreen());
      return;
    }

    final profile = await _authService.getUserProfile(firebaseUser.uid);
    if (profile == null) {
      _goTo(const LoginScreen());
      return;
    }

    if (profile.role == 'admin') {
      _goTo(const AdminHomeScreen());
    } else if (profile.role == 'business') {
      _goTo(const BusinessHomeScreen());
    } else {
      _goTo(const CustomerShellScreen());
    }
  }

  void _goTo(Widget screen) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.eco, size: 72, color: Colors.green),
            SizedBox(height: 16),
            Text('BachaoKhana', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
