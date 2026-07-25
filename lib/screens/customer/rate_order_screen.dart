import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/order.dart';
import '../../widgets/star_rating.dart';

/// Lets the customer rate a completed order — updates the business's
/// average rating (shown across the app) via DatabaseService.submitReview.
class RateOrderScreen extends StatefulWidget {
  final FoodOrder order;
  const RateOrderScreen({super.key, required this.order});

  @override
  State<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends State<RateOrderScreen> {
  final _authService = AuthService();
  final _databaseService = DatabaseService();
  final _commentCtrl = TextEditingController();

  int _rating = 5;
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final firebaseUser = _authService.currentUser!;
      final profile = await _authService.getUserProfile(firebaseUser.uid);

      await _databaseService.submitReview(
        businessId: widget.order.businessId,
        customerId: firebaseUser.uid,
        customerName: profile?.name ?? 'Customer',
        orderId: widget.order.id,
        rating: _rating,
        comment: _commentCtrl.text.trim(),
      );

      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rate your order')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.order.listingTitle,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            Text(
              'from ${widget.order.businessName}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Center(
              child: StarRating(
                rating: _rating,
                size: 40,
                onChanged: (r) => setState(() => _rating = r),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit rating'),
            ),
          ],
        ),
      ),
    );
  }
}
