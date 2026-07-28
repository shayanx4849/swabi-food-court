import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/cart_service.dart';
import '../../models/order.dart';

/// Shown right after a cart checkout. Unlike the single-item QrDisplayScreen,
/// a cart checkout can produce several orders at once (multiple items,
/// possibly across multiple businesses), so this lists all of them —
/// each pickup order gets its own small QR code to show at that business,
/// and delivery orders show a confirmation instead, same as the direct
/// single-item flow.
class CartCheckoutSummaryScreen extends StatelessWidget {
  final CartCheckoutResult result;
  const CartCheckoutSummaryScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final byBusiness = <String, List<FoodOrder>>{};
    for (final order in result.orders) {
      byBusiness.putIfAbsent(order.businessId, () => []).add(order);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Order confirmed'), automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 56),
              const SizedBox(height: 10),
              Text(
                '${result.orders.length} order${result.orders.length == 1 ? '' : 's'} placed',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              Text(
                'from ${byBusiness.length} business${byBusiness.length == 1 ? '' : 'es'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),

          if (result.hasFailures) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, size: 18, color: Colors.orange.shade800),
                      const SizedBox(width: 6),
                      Text('Some items couldn\'t be ordered',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${result.failedItemNames.join(', ')} — no longer available. '
                    'They were left in your cart.',
                    style: TextStyle(fontSize: 12.5, color: Colors.orange.shade900, height: 1.4),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          for (final entry in byBusiness.entries) _businessOrders(context, entry.value),

          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Back to home'),
          ),
        ],
      ),
    );
  }

  Widget _businessOrders(BuildContext context, List<FoodOrder> orders) {
    final businessName = orders.first.businessName;
    final total = orders.fold<double>(0, (sum, o) => sum + o.totalPrice);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront, size: 18, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(child: Text(businessName, style: const TextStyle(fontWeight: FontWeight.bold))),
                Text('Rs. ${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            for (final order in orders) _orderRow(order),
          ],
        ),
      ),
    );
  }

  Widget _orderRow(FoodOrder order) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.listingTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text('Rs. ${order.totalPrice.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                if (order.isDelivery) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.delivery_dining, size: 13, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.deliveryAddress ?? 'Delivery',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!order.isDelivery)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(6),
              ),
              child: QrImageView(data: order.qrCode, size: 56),
            ),
        ],
      ),
    );
  }
}
