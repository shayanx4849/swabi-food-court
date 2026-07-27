import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/order.dart';

/// Shown right after a successful reservation.
///
/// For pickup orders, this displays the QR code the customer presents at
/// the store for staff to scan. For delivery orders there's no in-person
/// handoff to scan, so this instead confirms the delivery address and
/// explains that the business will contact the customer to arrange
/// drop-off (this MVP has no rider assignment or live tracking).
class QrDisplayScreen extends StatelessWidget {
  final FoodOrder order;
  const QrDisplayScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking confirmed')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 56),
            const SizedBox(height: 12),
            Text(order.listingTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center),
            Text('from ${order.businessName}',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),
            if (order.isDelivery) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.delivery_dining, color: Colors.green.shade700),
                        const SizedBox(width: 8),
                        const Text('Delivery requested',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_on_outlined, size: 18, color: Colors.grey.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.deliveryAddress ?? '',
                            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade800),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The business will contact you to arrange drop-off. '
                'There is no live delivery tracking yet — check "My Orders" '
                'for status updates.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.4),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: order.qrCode,
                  size: 220,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Show this code at the store to collect your order.',
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}
