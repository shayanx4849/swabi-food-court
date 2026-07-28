import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';

/// Reusable card showing an order summary — used in both the customer's
/// "my orders" screen and the business's "orders" tab.
class OrderCard extends StatelessWidget {
  final FoodOrder order;
  final VoidCallback? onTap;
  final Widget?
      footer; // optional extra row below the main tile (e.g. Rate button)

  const OrderCard({super.key, required this.order, this.onTap, this.footer});

  Color _statusColor() {
    switch (order.status) {
      case 'completed':
        return Colors.green;
      case 'confirmed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM, h:mm a');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            onTap: onTap,
            contentPadding: const EdgeInsets.all(12),
            title: Row(
              children: [
                Expanded(
                  child: Text(order.listingTitle,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (order.isDelivery)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delivery_dining,
                            size: 12, color: Colors.blue.shade700),
                        const SizedBox(width: 3),
                        Text('Delivery',
                            style: TextStyle(
                                fontSize: 10, color: Colors.blue.shade700)),
                      ],
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              order.isDelivery
                  ? '${order.businessName}\n${dateFormat.format(order.createdAt)}\n${order.deliveryAddress ?? ''}'
                  : '${order.businessName}\n${dateFormat.format(order.createdAt)}',
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Rs. ${order.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.status,
                    style: TextStyle(fontSize: 11, color: _statusColor()),
                  ),
                ),
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: footer!,
            ),
        ],
      ),
    );
  }
}
