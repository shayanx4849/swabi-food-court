import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/notification_item.dart';

/// Shared in-app notification feed for both business and customer users.
/// Backed by a Realtime Database stream so new entries appear instantly
/// while the app is open (see database_service.dart for why this replaces
/// true background push notifications).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final databaseService = DatabaseService();
    final uid = authService.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<NotificationItem>>(
        stream: databaseService.streamNotifications(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return ListTile(
                leading: Icon(
                  Icons.notifications,
                  color: item.read ? Colors.grey : Colors.green,
                ),
                title: Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: item.read ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${item.body}\n${DateFormat('d MMM, h:mm a').format(item.createdAt)}',
                ),
                isThreeLine: true,
                onTap: () {
                  if (!item.read) {
                    databaseService.markNotificationRead(uid, item.id);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
