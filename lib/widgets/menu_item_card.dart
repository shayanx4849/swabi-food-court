import 'package:flutter/material.dart';
import '../models/menu_item.dart';

/// Reusable card for a regular menu item — used on both the business's
/// "My Menu" tab and the customer's restaurant-menu browsing screen.
class MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback? onTap;
  final Widget? businessActions; // Edit/Delete row, business view only

  /// When set, shows a small "+" cart icon on the customer-facing card so
  /// an item can be added straight from the list without opening its
  /// detail screen — handy for quickly building a multi-item order.
  final VoidCallback? onAddToCart;

  const MenuItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.businessActions,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            onTap: onTap,
            contentPadding: const EdgeInsets.all(10),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.imageUrl != null
                  ? Image.network(item.imageUrl!, width: 56, height: 56, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
            title: Text(
              item.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: item.available ? Colors.black87 : Colors.grey,
              ),
            ),
            subtitle: Text(
              item.available ? 'Rs. ${item.price.toStringAsFixed(0)}' : 'Currently unavailable',
              style: TextStyle(
                color: item.available ? Colors.green.shade700 : Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            trailing: (onAddToCart != null && item.available)
                ? IconButton(
                    icon: Icon(Icons.add_circle, color: Colors.green.shade700),
                    tooltip: 'Add to cart',
                    onPressed: onAddToCart,
                  )
                : null,
          ),
          if (businessActions != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: businessActions!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56,
      height: 56,
      color: Colors.green.shade50,
      child: Icon(Icons.restaurant_menu, color: Colors.green.shade300),
    );
  }
}
