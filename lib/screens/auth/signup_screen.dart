import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/business.dart';
import '../business/business_home_screen.dart';
import '../customer/customer_shell_screen.dart';
import '../shared/location_picker_screen.dart';

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
  String _role = 'customer';
  String _businessCategory = 'restaurant';
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  // Business location — set ONLY via the map picker (LocationPickerScreen),
  // never typed. That's what guarantees a business can't be registered
  // with a fake or nonexistent address: the pin has to sit on an actual
  // point on the map, and lat/lng always match whatever address gets
  // shown, because the address IS derived from the pin.
  PickedLocation? _pickedLocation;

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null) setState(() => _pickedLocation = result);
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == 'business' && _pickedLocation == null) {
      setState(() => _error = 'Please pin your business location on the map.');
      return;
    }
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

      if (_role == 'business') {
        final location = _pickedLocation!;
        await _databaseService.createBusiness(
          Business(
            id: const Uuid().v4(),
            ownerId: user.uid,
            name: _nameCtrl.text.trim(),
            category: _businessCategory,
            address: location.address,
            lat: location.lat,
            lng: location.lng,
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
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
                  OutlinedButton.icon(
                    icon: Icon(_pickedLocation == null
                        ? Icons.map_outlined
                        : Icons.edit_location_alt),
                    label: Text(_pickedLocation == null
                        ? 'Pin business location on map'
                        : 'Change pinned location'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade700),
                    ),
                    onPressed: _pickLocation,
                  ),
                  if (_pickedLocation != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.place,
                              size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pickedLocation!.address,
                              style: TextStyle(
                                  fontSize: 12.5, color: Colors.green.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 20),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
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
