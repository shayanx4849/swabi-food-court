import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/database_service.dart';
import '../../models/order.dart';
import '../../widgets/mini_map_view.dart';

/// A focused, single-purpose screen for actually doing a delivery run:
/// where to go, how to call the customer if needed, and a scanner to
/// confirm the hand-off once there — nothing else. Reached from a specific
/// delivery order in the business's Orders tab, so it already knows
/// exactly which order it's delivering; scanning only completes THIS
/// order, never any other one, even if a different valid QR gets scanned
/// by mistake.
class DeliveryRunScreen extends StatefulWidget {
  final FoodOrder order;
  const DeliveryRunScreen({super.key, required this.order});

  @override
  State<DeliveryRunScreen> createState() => _DeliveryRunScreenState();
}

class _DeliveryRunScreenState extends State<DeliveryRunScreen> {
  final _databaseService = DatabaseService();
  bool _scanning = false;
  bool _processing = false;

  Future<void> _navigate() async {
    final order = widget.order;
    if (!order.hasDeliveryPin) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${order.deliveryLat},${order.deliveryLng}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps.')),
        );
      }
    }
  }

  Future<void> _call() async {
    final phone = widget.order.customerPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the phone dialer.')),
        );
      }
    }
  }

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;

    // This screen is scoped to one specific order — a scan only counts if
    // it actually matches the order being delivered right now.
    if (code != widget.order.qrCode) {
      setState(() => _processing = true);
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Wrong QR code'),
          content: const Text('That code doesn\'t match this delivery. Ask the customer to show the code from their order confirmation screen.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );
      if (mounted) setState(() => _processing = false);
      return;
    }

    setState(() => _processing = true);
    final success = await _databaseService.verifyPickup(code);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true); // tell the Orders tab it's done
    } else {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This order was already completed or cancelled.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    if (_scanning) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scan customer\'s QR code'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(() => _scanning = false),
          ),
        ),
        body: Stack(
          children: [
            MobileScanner(onDetect: _handleScan),
            if (_processing)
              Container(
                color: Colors.black45,
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Deliver order')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(order.listingTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('for ${order.customerName}',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),

          // ---- Where to go ----
          if (order.hasDeliveryPin) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: MiniMapView(
                lat: order.deliveryLat!,
                lng: order.deliveryLng!,
                height: 200,
                borderRadius: 0,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (order.deliveryAddress != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(order.deliveryAddress!,
                      style: TextStyle(fontSize: 13.5, color: Colors.grey.shade700, height: 1.4)),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          Row(
            children: [
              if (order.hasDeliveryPin)
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Navigate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      side: BorderSide(color: Colors.blue.shade700),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _navigate,
                  ),
                ),
              if (order.hasDeliveryPin &&
                  order.customerPhone != null &&
                  order.customerPhone!.isNotEmpty)
                const SizedBox(width: 10),
              if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                      side: BorderSide(color: Colors.green.shade700),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _call,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),

          Row(
            children: [
              Icon(Icons.qr_code_scanner, size: 18, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              const Text('Confirm hand-off', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Once you\'ve reached the customer, scan the QR code shown on '
            'their order confirmation screen to mark it delivered.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan to complete delivery'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => setState(() => _scanning = true),
            ),
          ),
        ],
      ),
    );
  }
}
