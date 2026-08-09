import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/app_user.dart';
import '../auth/login_screen.dart';
import '../shared/notifications_screen.dart';
import 'addresses_screen.dart';
import 'favorites_tab.dart' show FavoritesTab;

/// The Profile tab — shows the logged-in customer's name/email and gives
/// access to notifications, saved addresses, and logout. "Payment methods"
/// and "Help & Support" are still listed but disabled since those aren't
/// built yet (payments are noted as future work in the FYP proposal).
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
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddressesScreen()),
              );
            },
          ),
          _tile(
              icon: Icons.favorite_outline_sharp,
              label: 'Favorites',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FavoritesTab()),
                );
              }

              // enabled: false,
              ),
          _tile(
            icon: Icons.help,
            label: 'Help & Support',
            subtitle: "Coming soon",
            enabled: false,
          ),
          const Divider(height: 24),
          _tile(
            icon: Icons.logout,
            label: 'Log out',
            iconColor: Colors.red,
            labelColor: Colors.red,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Log out?'),
                  content: const Text('Are you sure you want to logout'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Log out',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
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
