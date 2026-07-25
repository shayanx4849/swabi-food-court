import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/database_service.dart';

/// Business staff use this screen to scan a customer's QR code at pickup
/// time. On a successful scan, the matching order is marked as completed.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _databaseService = DatabaseService();
  bool _processing = false;

  Future<void> _handleScan(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null) return;

    setState(() => _processing = true);

    final success = await _databaseService.verifyPickup(code);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(success ? 'Pickup confirmed' : 'Invalid or already used'),
        content: Text(success
            ? 'Order marked as completed. Hand over the food to the customer.'
            : 'This QR code does not match a pending order.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              setState(() => _processing = false); // allow next scan
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan pickup QR code')),
      body: MobileScanner(
        onDetect: _handleScan,
      ),
    );
  }
}
