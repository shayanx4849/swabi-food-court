import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../business/business_home_screen.dart';
import '../customer/customer_shell_screen.dart';
import '../admin/admin_home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailCtrl.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Enter your account email — we\'ll send a link to reset your password.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Email', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Send link'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty || !email.contains('@')) return;

    try {
      await _authService.resetPassword(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Could not send reset link. Check the email and try again.')),
      );
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _authService.signIn(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      if (!mounted || user == null) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => user.role == 'admin'
              ? const AdminHomeScreen()
              : user.role == 'business'
                  ? const BusinessHomeScreen()
                  : const CustomerShellScreen(),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Login failed. Check your email/password.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.vertical -
                    48,
              ),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.eco, size: 64, color: Colors.green),
                      const SizedBox(height: 8),
                      const Text(
                        'Food Delivery Court',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: _togglePasswordVisibility,
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Min 6 characters'
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_error != null)
                        Text(_error!,
                            style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Log in'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () async {
                          FocusScope.of(context).unfocus();
                          // A real (short) delay — more reliable than
                          // addPostFrameCallback on Flutter Web, where the
                          // browser's own focus/blur event queue needs time to
                          // finish before Navigator can safely start a transition.
                          await Future.delayed(
                              const Duration(milliseconds: 50));
                          if (!mounted) return;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SignupScreen()),
                          );
                        },
                        child: const Text("Don't have an account? Sign up"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
