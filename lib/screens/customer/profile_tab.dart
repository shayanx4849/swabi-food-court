import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/app_user.dart';
import '../auth/login_screen.dart';
import '../shared/notifications_screen.dart';

/// The Profile tab — shows the logged-in customer's name/email and gives
/// access to notifications and logout. Kept intentionally simple for now;
/// items like "Payment methods" and "Addresses" are listed but disabled
/// since those features aren't built yet (payments are noted as future
/// work in the FYP proposal).
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _authService = AuthService();
  AppUser? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final profile = await _authService.getUserProfile(uid);
    if (mounted) setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.green.shade100,
                  child: Text(
                    (_profile?.name.isNotEmpty == true)
                        ? _profile!.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _profile?.name ?? '...',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _profile?.email ?? '',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _tile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          _tile(
            icon: Icons.payment_outlined,
            label: 'Payment methods',
            subtitle: 'Coming soon',
            enabled: false,
          ),
          _tile(
            icon: Icons.location_on_outlined,
            label: 'Addresses',
            subtitle: 'Coming soon',
            enabled: false,
          ),
          _tile(
            icon: Icons.help_outline,
            label: 'Help & Support',
            subtitle: 'Coming soon',
            enabled: false,
          ),
          const Divider(height: 24),
          _tile(
            icon: Icons.logout,
            label: 'Log out',
            iconColor: Colors.red,
            labelColor: Colors.red,
            onTap: () async {
              // show confirmation dialog before logging out
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm '),
                  titleTextStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  content: const Text('Are you sure you want to log out?'),
                  contentTextStyle: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('No'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Yes'),
                    ),
                  ],
                ),
              );

              if (shouldLogout != true) return;
              await _authService.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String label,
    String? subtitle,
    VoidCallback? onTap,
    bool enabled = true,
    Color? iconColor,
    Color? labelColor,
  }) {
    return ListTile(
      leading: Icon(icon,
          color: enabled
              ? (iconColor ?? Colors.grey.shade700)
              : Colors.grey.shade400),
      title: Text(
        label,
        style: TextStyle(
          color:
              enabled ? (labelColor ?? Colors.black87) : Colors.grey.shade400,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 12))
          : null,
      trailing: enabled ? const Icon(Icons.chevron_right, size: 20) : null,
      onTap: enabled ? onTap : null,
    );
  }
}
