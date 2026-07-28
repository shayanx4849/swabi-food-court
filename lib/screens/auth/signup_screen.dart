import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/business.dart';
import '../business/business_home_screen.dart';
import '../customer/customer_shell_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _databaseService = DatabaseService();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _addressCtrl = TextEditingController(); // used only if role == business

  String _role = 'customer';
  String _businessCategory = 'restaurant';
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await _authService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        role: _role,
      );

      // If registering as a business, also create a Business profile.
      // NOTE: lat/lng are placeholders here (0,0) — in the full app,
      // capture these from the device's location or an address picker
      // during onboarding, then update the business document.
      if (_role == 'business') {
        await _databaseService.createBusiness(
          Business(
            id: const Uuid().v4(),
            ownerId: user.uid,
            name: _nameCtrl.text.trim(),
            category: _businessCategory,
            address: _addressCtrl.text.trim(),
            lat: 0,
            lng: 0,
            verified: false, // admin approves later
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _role == 'business'
              ? const BusinessHomeScreen()
              : const CustomerShellScreen(),
        ),
      );
    } catch (e) {
      setState(() => _error = 'Sign up failed. Try a different email.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'customer', label: Text('Customer')),
                    ButtonSegment(value: 'business', label: Text('Business')),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText:
                        _role == 'business' ? 'Business name' : 'Full name',
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
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
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 6) ? 'Min 6 characters' : null,
                ),
                if (_role == 'business') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _businessCategory,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(
                          value: 'restaurant',
                          child: Text('Restaurant / Meals')),
                      DropdownMenuItem(value: 'bakery', child: Text('Bakery')),
                      DropdownMenuItem(
                          value: 'mart', child: Text('Mart / Groceries')),
                    ],
                    onChanged: (v) =>
                        setState(() => _businessCategory = v ?? 'restaurant'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Business address'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ],
                const SizedBox(height: 20),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _loading ? null : _signup,
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
