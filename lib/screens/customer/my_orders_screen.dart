import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/order.dart';
import '../../widgets/order_card.dart';
import 'qr_display_screen.dart';
import 'rate_order_screen.dart';

/// Lists all of the current customer's past and pending orders.
/// Tapping a pending order re-opens its QR code for pickup. Completed
/// orders that haven't been reviewed yet show a "Rate this order" button.
class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  Future<void> _confirmCancel(BuildContext context,
      DatabaseService databaseService, FoodOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
            '"${order.listingTitle}" from ${order.businessName} will be cancelled. This can\'t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep order')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Cancel order', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await databaseService.cancelOrder(order.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final databaseService = DatabaseService();
    final uid = authService.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: StreamBuilder<List<FoodOrder>>(
        stream: databaseService.streamCustomerOrders(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(child: Text('No orders yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (context, i) {
              final order = orders[i];
              final showRateButton =
                  order.status == 'completed' && !order.reviewed;
              final showCancelButton = order.status == 'pending';

              Widget? footer;
              if (showRateButton) {
                footer = OutlinedButton.icon(
                  icon: const Icon(Icons.star_outline, size: 18),
                  label: const Text('Rate this order'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RateOrderScreen(order: order),
                      ),
                    );
                  },
                );
              } else if (showCancelButton) {
                footer = OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancel order'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  onPressed: () =>
                      _confirmCancel(context, databaseService, order),
                );
              }

              return OrderCard(
                order: order,
                onTap:
                    (order.status == 'pending' || order.status == 'confirmed')
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => QrDisplayScreen(order: order),
                              ),
                            );
                          }
                        : null,
                footer: footer,
              );
            },
          );
        },
      ),
    );
  }
}
