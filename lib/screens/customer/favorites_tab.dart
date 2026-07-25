import 'package:flutter/material.dart';
import '../../widgets/notification_bell.dart';

/// Placeholder for the Favorites tab — full save/unsave functionality is
/// planned as a future phase. Kept as its own file so it's a clean drop-in
/// once that feature is built.
class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: const [NotificationBell()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Favorites coming soon',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 6),
              Text(
                'Soon you\'ll be able to save your favorite\nbusinesses for quick access.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
