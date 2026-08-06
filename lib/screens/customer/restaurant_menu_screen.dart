import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/business.dart';
import '../../models/menu_item.dart';
import '../../widgets/menu_item_grid_card.dart';
import '../../widgets/star_rating.dart';
import '../../widgets/favorite_button.dart';
import 'menu_item_detail_screen.dart';

/// A single restaurant's regular menu — tapping a business from the
/// Restaurants search list opens this screen. Shows the business's info
/// (rating, address) and their full always-available menu; tapping an item
/// opens MenuItemDetailScreen to actually place an order.
class RestaurantMenuScreen extends StatelessWidget {
  final Business business;
  const RestaurantMenuScreen({super.key, required this.business});

  @override
  Widget build(BuildContext context) {
    final databaseService = DatabaseService();

    return Scaffold(
      appBar: AppBar(
        title: Text(business.name),
        actions: [FavoriteButton(businessId: business.id)],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.green.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child:
                          Icon(Icons.storefront, color: Colors.green.shade700),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(business.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(business.category,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    if (business.ratingCount > 0)
                      Row(
                        children: [
                          StarRating(
                              rating: business.averageRating.round(), size: 14),
                          const SizedBox(width: 4),
                          Text('${business.averageRating.toStringAsFixed(1)}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                  ],
                ),
                if (business.address.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(business.address,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade700)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: !business.isOpen
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront_outlined,
                              size: 56, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            '${business.name} is currently closed',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Their menu isn\'t available for ordering right now.\nCheck back later.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : StreamBuilder<List<MenuItem>>(
                    stream:
                        databaseService.streamBusinessMenuItems(business.id),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                            child:
                                Text('Failed to load menu: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final items =
                          snapshot.data!.where((i) => i.available).toList();
                      if (items.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'This business hasn\'t added their regular menu yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        );
                      }
                      // Group items by category, preserving the fixed category
                      // order (kMenuItemCategories) and skipping empty ones —
                      // matches how a real restaurant menu is organized
                      // (Starters, Main Course, Chicken, Drinks, ...).
                      final Map<String, List<MenuItem>> byCategory = {};
                      for (final item in items) {
                        byCategory
                            .putIfAbsent(item.category, () => [])
                            .add(item);
                      }
                      final orderedCategories = [
                        ...kMenuItemCategories.where(byCategory.containsKey),
                        ...byCategory.keys
                            .where((c) => !kMenuItemCategories.contains(c)),
                      ];

                      return ListView(
                        padding: const EdgeInsets.only(bottom: 16),
                        children: [
                          for (final category in orderedCategories) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                              child: Text(
                                category,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: byCategory[category]!.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.72,
                              ),
                              itemBuilder: (context, i) {
                                final item = byCategory[category]![i];
                                return MenuItemGridCard(
                                  item: item,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              MenuItemDetailScreen(item: item)),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
