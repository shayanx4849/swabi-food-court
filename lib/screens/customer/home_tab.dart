import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../models/business.dart';
import '../../models/app_user.dart';
import '../../models/deal.dart';
import '../../models/listing.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/star_rating.dart';
import 'restaurant_menu_screen.dart';
import 'restaurants_search_screen.dart';
import 'menu_category_screen.dart';
import 'deal_detail_screen.dart';
import 'listing_detail_screen.dart';
import 'all_deals_screen.dart';
import 'all_surprise_bags_screen.dart';

/// The Home tab — a slim top bar (Cart/Notifications), a "Deliver to"
/// location line of its own underneath, a functional search bar, food
/// category tiles, a "Deals near you" hero carousel (business-managed
/// Deals — NOT the time-limited Surprise Bag surplus listings), and a
/// Popular Restaurants section sorted by rating.
class HomeTab extends StatefulWidget {
  final VoidCallback onSeeAllTap;
  const HomeTab({super.key, required this.onSeeAllTap});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _authService = AuthService();
  final _databaseService = DatabaseService();
  final _locationService = LocationService();
  final _searchCtrl = TextEditingController();
  final _dealsPageController = PageController(viewportFraction: 0.88);
  final _surpriseBagsPageController = PageController(viewportFraction: 0.88);

  double? _lat;
  double? _lng;
  String? _addressLabel; // reverse-geocoded "Deliver to" text
  bool _locating = true;
  AppUser? _profile;
  Map<String, Business> _businessesById = {};
  int _dealsPage = 0;
  int _surpriseBagsPage = 0;

  // Food-category tiles (browse by dish across every restaurant), not a
  // business-type filter. Each category shows a small food emoji as its
  // "thumbnail" — no app assets or hotlinked photos needed, so nothing to
  // license or bundle, while still reading as a picture rather than a
  // plain icon.
  static const _categoryThumbnails = <String, String>{
    'All': '🍽️',
    'Starters': '🥗',
    'Main Course': '🍛',
    'Chicken': '🍗',
    'Beef & Mutton': '🥩',
    'Rice & Biryani': '🍚',
    'Bread': '🍞',
    'Sides': '🍟',
    'Drinks': '🥤',
    'Desserts': '🍰',
    'Other': '🍴',
  };

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _loadProfile();
    _databaseService.streamAllBusinesses().listen((businesses) {
      if (!mounted) return;
      setState(() => _businessesById = {for (final b in businesses) b.id: b});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _dealsPageController.dispose();
    _surpriseBagsPageController.dispose();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    try {
      final pos = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
      });
      final address =
          await _locationService.reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _addressLabel = address;
          _locating = false;
        });
      }
    } catch (e) {
      // Common cause: device Location (GPS) service is turned off entirely
      // at the OS level — in that case Geolocator throws before the app
      // even gets a chance to show its own permission dialog.
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _loadProfile() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final profile = await _authService.getUserProfile(uid);
    if (mounted) setState(() => _profile = profile);
  }

  void _runSearch(String query) {
    if (query.trim().isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RestaurantsSearchScreen(initialQuery: query.trim()),
      ),
    );
  }

  /// Nearest-first once we know the customer's location — distance is
  /// looked up via the deal's own business (Deal itself doesn't carry
  /// lat/lng, only the business does).
  List<Deal> _sortDealsByDistance(List<Deal> deals) {
    if (_lat == null || _lng == null) return deals;
    return [...deals]..sort((a, b) {
        final ba = _businessesById[a.businessId];
        final bb = _businessesById[b.businessId];
        final da = ba == null
            ? double.infinity
            : _locationService.distanceInKm(_lat!, _lng!, ba.lat, ba.lng);
        final db = bb == null
            ? double.infinity
            : _locationService.distanceInKm(_lat!, _lng!, bb.lat, bb.lng);
        return da.compareTo(db);
      });
  }

  /// Nearest-first for Surprise Bag listings — unlike Deal, a FoodListing
  /// carries its own lat/lng directly, so no business lookup is needed.
  List<FoodListing> _sortListingsByDistance(List<FoodListing> listings) {
    if (_lat == null || _lng == null) return listings;
    return [...listings]..sort((a, b) {
        final da = _locationService.distanceInKm(_lat!, _lng!, a.lat, a.lng);
        final db = _locationService.distanceInKm(_lat!, _lng!, b.lat, b.lng);
        return da.compareTo(db);
      });
  }

  List<Business> _popularRestaurants() {
    final result = _businessesById.values.where((b) => b.verified).toList();
    result.sort((a, b) => b.averageRating.compareTo(a.averageRating));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Deal>>(
          stream: _databaseService.streamActiveDeals(),
          builder: (context, snapshot) {
            final deals = _sortDealsByDistance(snapshot.data ?? []);
            final restaurants = _popularRestaurants();

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _topBar(),
                _locationRow(),
                _searchBar(),
                const SizedBox(height: 8),
                _categoriesRow(),
                _dealsHeader(),
                if (!snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (deals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    child: Text(
                      'No deals right now — check back soon!',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                else
                  _dealsCarousel(deals),
                const SizedBox(height: 24),
                _surpriseBagsHeader(),
                StreamBuilder<List<FoodListing>>(
                  stream: _databaseService.streamVerifiedActiveListings(),
                  builder: (context, listingSnapshot) {
                    final bags =
                        _sortListingsByDistance(listingSnapshot.data ?? []);
                    if (!listingSnapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (bags.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                        child: Text(
                          'No Surprise Bags nearby right now — check back soon!',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      );
                    }
                    return _surpriseBagsCarousel(bags);
                  },
                ),
                const SizedBox(height: 24),
                _popularRestaurantsHeader(),
                if (restaurants.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                    child: Text(
                      'No restaurants in this category yet.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                else
                  _popularRestaurantsList(restaurants),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------- Top bar: Cart + Notifications ----------------

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        children: [
          const Spacer(),
          const CartButton(),
          const NotificationBell(),
        ],
      ),
    );
  }

  // ---------------- "Deliver to" location — its own row, below the top bar ----------------

  Widget _locationRow() {
    final firstName = (_profile?.name.isNotEmpty == true)
        ? _profile!.name.split(' ').first
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.location_on, color: Colors.green.shade700, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstName != null
                      ? 'Deliver to, Hi $firstName 👋'
                      : 'Deliver to',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                Text(
                  _locating
                      ? 'Locating…'
                      : (_addressLabel ?? 'Location unavailable'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Search bar ----------------

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: _runSearch,
                decoration: InputDecoration(
                  hintText: 'Search for food, restaurants…',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade500, fontSize: 13.5),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.green.shade700,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const RestaurantsSearchScreen()),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Icon(Icons.tune, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Category chips ----------------

  Widget _categoriesRow() {
    final labels = _categoryThumbnails.keys.toList();
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final label = labels[i];
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MenuCategoryScreen(initialCategory: label),
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _categoryThumbnails[label]!,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10.5, color: Colors.grey.shade700),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- Deals near you (business-managed Deals, no forced time limit) ----------------

  Widget _dealsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text("Today's Deal",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AllDealsScreen()),
              );
            },
            child: const Text('See all'),
          ),
        ],
      ),
    );
  }

  Widget _dealsCarousel(List<Deal> deals) {
    final shown = deals.take(6).toList();
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _dealsPageController,
            itemCount: shown.length,
            onPageChanged: (i) => setState(() => _dealsPage = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _dealCard(shown[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(shown.length, (i) {
            final active = i == _dealsPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? Colors.green.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _dealCard(Deal deal) {
    final pctOff = deal.discountPercent.round();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DealDetailScreen(deal: deal)),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (deal.imageUrl != null)
              Image.network(deal.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.green.shade900))
            else
              Container(color: Colors.green.shade900),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.75)
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (pctOff > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$pctOff% OFF',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(deal.menuItemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(deal.businessName,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                            'Rs. ${deal.discountedPrice.toStringAsFixed(0)} • View deal',
                            style: TextStyle(
                                color: Colors.green.shade800,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Surprise Bags (time-limited surplus listings) ----------------

  Widget _surpriseBagsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text('Surprise Bags',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AllSurpriseBagsScreen()),
              );
            },
            child: const Text('See all'),
          ),
        ],
      ),
    );
  }

  Widget _surpriseBagsCarousel(List<FoodListing> listings) {
    final shown = listings.take(6).toList();
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _surpriseBagsPageController,
            itemCount: shown.length,
            onPageChanged: (i) => setState(() => _surpriseBagsPage = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _surpriseBagCard(shown[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(shown.length, (i) {
            final active = i == _surpriseBagsPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? Colors.orange.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _surpriseBagCard(FoodListing listing) {
    final pctOff = listing.originalPrice > 0
        ? (((listing.originalPrice - listing.price) / listing.originalPrice) *
                100)
            .round()
        : 0;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => ListingDetailScreen(listing: listing)),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (listing.imageUrl != null)
              Image.network(listing.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.orange.shade900))
            else
              Container(color: Colors.orange.shade900),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.05),
                    Colors.black.withOpacity(0.75)
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (pctOff > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$pctOff% OFF',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(listing.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(listing.businessName,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                            'Rs. ${listing.price.toStringAsFixed(0)} • View bag',
                            style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Popular Restaurants ----------------

  Widget _popularRestaurantsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text('Popular Restaurants',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const RestaurantsSearchScreen()),
              );
            },
            child: const Text('See all'),
          ),
        ],
      ),
    );
  }

  Widget _popularRestaurantsList(List<Business> restaurants) {
    return Column(
      children: restaurants.take(6).map((business) {
        final distanceLabel = (_lat != null &&
                _lng != null &&
                (business.lat != 0 || business.lng != 0))
            ? '${_locationService.distanceInKm(_lat!, _lng!, business.lat, business.lng).toStringAsFixed(1)} km'
            : null;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => RestaurantMenuScreen(business: business)),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.storefront,
                        color: Colors.green.shade700, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(business.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14.5)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (business.ratingCount > 0) ...[
                              StarRating(
                                  rating: business.averageRating.round(),
                                  size: 12),
                              const SizedBox(width: 4),
                              Text(business.averageRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              distanceLabel != null
                                  ? '$distanceLabel • ${business.category}'
                                  : business.category,
                              style: TextStyle(
                                  fontSize: 11.5, color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
