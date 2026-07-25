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
              final showRateButton = order.status == 'completed' && !order.reviewed;

              return OrderCard(
                order: order,
                onTap: order.status == 'pending'
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => QrDisplayScreen(order: order),
                          ),
                        );
                      }
                    : null,
                footer: showRateButton
                    ? OutlinedButton.icon(
                        icon: const Icon(Icons.star_outline, size: 18),
                        label: const Text('Rate this order'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RateOrderScreen(order: order),
                            ),
                          );
                        },
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
