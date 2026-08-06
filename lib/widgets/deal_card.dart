import 'package:flutter/material.dart';
import '../models/deal.dart';

/// Row card shown in the business's "Deals" tab for managing one deal —
/// edit the discount/expiry, pause it without deleting, or remove it
/// entirely. Distinct from any customer-facing deal display.
class DealCard extends StatelessWidget {
  final Deal deal;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleActive;
  final VoidCallback? onDelete;

  const DealCard({
    super.key,
    required this.deal,
    this.onEdit,
    this.onToggleActive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final expired = deal.isExpired;
    final statusColor = expired
        ? Colors.red
        : (deal.active ? Colors.green : Colors.grey);
    final statusLabel = expired ? 'Expired' : (deal.active ? 'Live' : 'Paused');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(deal.menuItemName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('Rs. ${deal.originalPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey.shade600,
                        fontSize: 12.5)),
                const SizedBox(width: 6),
                Text('Rs. ${deal.discountedPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 14)),
                const SizedBox(width: 6),
                Text('(${deal.discountPercent.round()}% off)',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.event, size: 13, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('Until ${deal.expiryDate.day}/${deal.expiryDate.month}/${deal.expiryDate.year}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: onEdit,
                    child: const Text('Edit', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: onToggleActive,
                    child: Text(deal.active ? 'Pause' : 'Resume', style: const TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
