import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/listing.dart';

/// Rich, visual card for a surplus food listing — large photo on top (like
/// Too Good To Go / Karma's "Surprise Bag" cards), a discount-percent badge,
/// business name with a category icon, pickup time chip, and price.
class ListingCard extends StatelessWidget {
  final FoodListing listing;
  final String? distanceLabel;
  final VoidCallback? onTap;
  final Widget? businessActions; // optional Edit/Delete row, business view only
  final double? rating; // business's average rating, if known
  final int? ratingCount;

  const ListingCard({
    super.key,
    required this.listing,
    this.distanceLabel,
    this.onTap,
    this.businessActions,
    this.rating,
    this.ratingCount,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('h:mm a');
    final expired = listing.isExpired;
    final soldOut = listing.quantityAvailable <= 0 || listing.status != 'active' || expired;
    final discountPercent = listing.originalPrice > 0
        ? (((listing.originalPrice - listing.price) / listing.originalPrice) * 100)
            .round()
        : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Photo header ----
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: listing.imageUrl != null
                      ? Image.network(
                          listing.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderImage(),
                        )
                      : _placeholderImage(),
                ),
                if (soldOut)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: Text(
                        expired ? 'EXPIRED' : 'SOLD OUT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                if (!soldOut && discountPercent > 0)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$discountPercent% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                if (distanceLabel != null)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place, color: Colors.white, size: 12),
                          const SizedBox(width: 3),
                          Text(distanceLabel!,
                              style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // ---- Details ----
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_categoryIcon(), size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          listing.businessName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (rating != null && (ratingCount ?? 0) > 0) ...[
                        Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                        const SizedBox(width: 2),
                        Text(
                          '${rating!.toStringAsFixed(1)} ($ratingCount)',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time, size: 13, color: Colors.orange.shade800),
                            const SizedBox(width: 4),
                            Text(
                              '${timeFormat.format(listing.pickupStart)} - ${timeFormat.format(listing.pickupEnd)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (!soldOut)
                        Text(
                          'Rs. ${listing.originalPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      const SizedBox(width: 6),
                      Text(
                        soldOut ? 'Sold out' : 'Rs. ${listing.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: soldOut ? Colors.grey : Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  if (!soldOut) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${listing.quantityAvailable} bag${listing.quantityAvailable == 1 ? '' : 's'} left',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                  if (businessActions != null) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    businessActions!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: Colors.green.shade50,
      alignment: Alignment.center,
      child: Icon(Icons.eco, size: 42, color: Colors.green.shade300),
    );
  }

  IconData _categoryIcon() {
    switch (listing.title.toLowerCase().contains('bakery')) {
      case true:
        return Icons.bakery_dining;
      default:
        return Icons.storefront;
    }
  }
}
