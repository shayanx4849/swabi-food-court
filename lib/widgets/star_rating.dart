import 'package:flutter/material.dart';

/// Simple 1-5 tappable star rating widget, and a read-only display mode
/// for showing a business's average rating elsewhere in the app.
class StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int>? onChanged; // null = read-only display mode
  final double size;

  const StarRating({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        return GestureDetector(
          onTap: onChanged == null ? null : () => onChanged!(i + 1),
          child: Icon(
            filled ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: size,
          ),
        );
      }),
    );
  }
}
