import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

/// A heart icon that live-reflects and toggles whether the current
/// customer has favorited [businessId]. Drop into an AppBar or a list
/// tile's trailing slot.
class FavoriteButton extends StatelessWidget {
  final String businessId;
  final Color? activeColor;
  final Color? inactiveColor;

  const FavoriteButton({
    super.key,
    required this.businessId,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final databaseService = DatabaseService();
    final uid = authService.currentUser?.uid;

    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<Set<String>>(
      stream: databaseService.streamFavoriteBusinessIds(uid),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data?.contains(businessId) ?? false;
        return IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? (activeColor ?? Colors.red) : (inactiveColor ?? Colors.grey.shade600),
          ),
          onPressed: () {
            databaseService.setFavorite(uid, businessId, !isFavorite);
          },
        );
      },
    );
  }
}
