import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/business.dart';
import '../../models/listing.dart';
import '../../models/menu_item.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/favorite_button.dart';
import '../../widgets/star_rating.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/menu_item_grid_card.dart';
import 'restaurant_menu_screen.dart';
import 'listing_detail_screen.dart';
import 'menu_item_detail_screen.dart';

/// The Favorites tab — live lists of everything the customer has favorited
/// via any heart icon in the app: whole restaurants (business-level
/// favorite), individual Surprise Bag deals, and individual menu items.
/// Each section only renders if it actually has content, and a single
/// combined empty-state shows only once all three sources have loaded and
/// are confirmed empty.
class FavoritesTab extends StatefulWidget {
  const FavoritesTab({super.key});

  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab> {
  final _authService = AuthService();
  final _databaseService = DatabaseService();

  List<Business>? _businesses;
  List<FoodListing>? _listings;
  List<MenuItem>? _menuItems;

  @override
  void initState() {
    super.initState();
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    _databaseService.streamFavoriteBusinesses(uid).listen((v) {
      if (mounted) setState(() => _businesses = v);
    });
    _databaseService.streamFavoriteListings(uid).listen((v) {
      if (mounted) setState(() => _listings = v);
    });
    _databaseService.streamFavoriteMenuItems(uid).listen((v) {
      if (mounted) setState(() => _menuItems = v);
    });
  }

  bool get _stillLoading =>
      _businesses == null || _listings == null || _menuItems == null;

  bool get _isCompletelyEmpty =>
      !_stillLoading &&
      _businesses!.isEmpty &&
      _listings!.isEmpty &&
      _menuItems!.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: const [NotificationBell()],
      ),
      body: _stillLoading
          ? const Center(child: CircularProgressIndicator())
          : _isCompletelyEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    if (_businesses!.isNotEmpty) ..._buildRestaurantsSection(),
                    if (_listings!.isNotEmpty) ..._buildListingsSection(),
                    if (_menuItems!.isNotEmpty) ..._buildMenuItemsSection(),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No favorites yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the ♡ on any restaurant, deal, or menu item\nto save it here for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  List<Widget> _buildRestaurantsSection() {
    return [
      _sectionHeader('Restaurants'),
      ..._businesses!.map((business) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: Icon(Icons.storefront, color: Colors.green.shade700),
                ),
                title: Text(business.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Row(
                  children: [
                    Text(business.category,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    if (business.ratingCount > 0) ...[
                      const SizedBox(width: 8),
                      StarRating(
                          rating: business.averageRating.round(), size: 12),
                      const SizedBox(width: 3),
                      Text(business.averageRating.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
                trailing: FavoriteButton(businessId: business.id),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            RestaurantMenuScreen(business: business)),
                  );
                },
              ),
            ),
          )),
    ];
  }

  List<Widget> _buildListingsSection() {
    return [
      _sectionHeader('Favorite Deals'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: _listings!
              .map((listing) => ListingCard(
                    listing: listing,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) =>
                                ListingDetailScreen(listing: listing)),
                      );
                    },
                  ))
              .toList(),
        ),
      ),
    ];
  }

  List<Widget> _buildMenuItemsSection() {
    return [
      _sectionHeader('Favorite Menu Items'),
      SizedBox(
        height: 235,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _menuItems!.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final item = _menuItems![i];
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 16 * 2 - 12) / 2,
              child: MenuItemGridCard(
                item: item,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => MenuItemDetailScreen(item: item)),
                  );
                },
              ),
            );
          },
        ),
      ),
    ];
  }
}
