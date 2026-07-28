import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import '../screens/customer/cart_screen.dart';

/// A shopping-bag icon for the app bar that shows a small badge with the
/// number of items currently in the cart, live-updating from CartService.
///
/// Mirrors NotificationBell's structure, but listens to the in-memory
/// CartService (a ChangeNotifier) via ListenableBuilder instead of a
/// Realtime Database stream.
class CartButton extends StatelessWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = CartService.instance;

    return ListenableBuilder(
      listenable: cart,
      builder: (context, _) {
        final count = cart.totalItemCount;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_bag_outlined),
              tooltip: 'Cart',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
