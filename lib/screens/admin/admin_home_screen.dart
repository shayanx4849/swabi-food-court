import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/business.dart';
import '../auth/login_screen.dart';

/// Admin dashboard: two tabs — "Pending" (businesses awaiting verification,
/// with Approve/Reject actions) and "All businesses" (every business on the
/// platform, with the option to revoke verification or remove a business).
///
/// There is no public sign-up path for the admin role — admin accounts are
/// created by manually setting a user's `role` field to "admin" in the
/// Firebase Console (Realtime Database → users → {uid} → role). See the
/// README for exact steps.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin dashboard'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await authService.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'All businesses'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PendingBusinessesTab(),
            _AllBusinessesTab(),
          ],
        ),
      ),
    );
  }
}

/// Businesses awaiting verification (verified == false).
class _PendingBusinessesTab extends StatelessWidget {
  const _PendingBusinessesTab();

  @override
  Widget build(BuildContext context) {
    final databaseService = DatabaseService();

    return StreamBuilder<List<Business>>(
      stream: databaseService.streamPendingBusinesses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pending = snapshot.data!;
        if (pending.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No businesses waiting for approval.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: pending.length,
          itemBuilder: (context, i) {
            final business = pending[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange.shade50,
                          child: Icon(Icons.storefront, color: Colors.orange.shade700),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(business.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text(business.category,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(business.address, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.close, size: 18, color: Colors.red),
                            label: const Text('Reject', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                            onPressed: () => _rejectBusiness(context, business),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Approve'),
                            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                            onPressed: () async {
                              await databaseService.setBusinessVerified(business.id, true);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _rejectBusiness(BuildContext context, Business business) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject this business?'),
        content: Text(
            '"${business.name}" will be permanently removed from the platform. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await DatabaseService().deleteBusiness(business.id);
    }
  }
}

/// Every business on the platform, verified or not — lets admin revoke
/// verification or remove a business entirely.
class _AllBusinessesTab extends StatelessWidget {
  const _AllBusinessesTab();

  @override
  Widget build(BuildContext context) {
    final databaseService = DatabaseService();

    return StreamBuilder<List<Business>>(
      stream: databaseService.streamAllBusinesses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final businesses = snapshot.data!;
        if (businesses.isEmpty) {
          return const Center(child: Text('No businesses registered yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: businesses.length,
          itemBuilder: (context, i) {
            final business = businesses[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      business.verified ? Colors.green.shade50 : Colors.orange.shade50,
                  child: Icon(
                    business.verified ? Icons.verified : Icons.hourglass_empty,
                    color: business.verified ? Colors.green.shade700 : Colors.orange.shade700,
                    size: 20,
                  ),
                ),
                title: Text(business.name),
                subtitle: Text(
                  business.verified
                      ? 'Verified · ${business.category}'
                      : 'Pending · ${business.category}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'toggle') {
                      await databaseService.setBusinessVerified(
                          business.id, !business.verified);
                    } else if (value == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Remove this business?'),
                          content: Text('"${business.name}" and its data will remain, '
                              'but it will no longer appear on the platform unless '
                              're-verified.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Remove', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await databaseService.deleteBusiness(business.id);
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(business.verified ? 'Revoke verification' : 'Verify'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Remove', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
