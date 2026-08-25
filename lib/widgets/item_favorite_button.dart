import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

/// A small circular heart button meant to sit as an overlay on top of a
/// product card's photo (top-right corner) — favorites the specific
/// listing/menu item itself, not the business. Self-contained: it reads
/// and writes its own favorite state, so it can just be dropped into any
/// card's Stack without the parent needing to manage favorite state.
class ItemFavoriteButton extends StatelessWidget {
  final String itemId;
  const ItemFavoriteButton({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final databaseService = DatabaseService();
    final uid = authService.currentUser?.uid;

    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<Set<String>>(
      stream: databaseService.streamFavoriteItemIds(uid),
      builder: (context, snapshot) {
        final isFavorite = snapshot.data?.contains(itemId) ?? false;
        return Material(
          color: Colors.black.withValues(alpha: 0.35),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              databaseService.setItemFavorite(uid, itemId, !isFavorite);
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red.shade400 : Colors.white,
                size: 18,
              ),
            ),
          ),
        );
      },
    );
  }
}
