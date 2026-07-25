import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../models/listing.dart';
import '../../models/business.dart';
import '../../models/app_user.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/impact_banner.dart';
import 'listing_detail_screen.dart';

/// The Home tab — a lightweight dashboard: personal greeting, the app-wide
/// impact banner, category filter chips, and a horizontally-scrolling
/// preview of nearby offers with a "See all" link to the full Browse tab.
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

  double? _lat;
  double? _lng;
  AppUser? _profile;
  Map<String, Business> _businessesById = {};
  String _selectedCategory = 'all';

  static const _categories = [
    {'key': 'all', 'label': 'All', 'icon': Icons.apps},
    {'key': 'restaurant', 'label': 'Meals', 'icon': Icons.restaurant},
    {'key': 'bakery', 'label': 'Bakery', 'icon': Icons.bakery_dining},
    {'key': 'mart', 'label': 'Groceries', 'icon': Icons.local_grocery_store},
  ];

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

  Future<void> _loadLocation() async {
    try {
      final pos = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Location] Could not get location: $e');
      // Common cause: device Location (GPS) service is turned off entirely
      // at the OS level — in that case Geolocator throws before the app
      // even gets a chance to show its own permission dialog.
    }
  }

  Future<void> _loadProfile() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final profile = await _authService.getUserProfile(uid);
    if (mounted) setState(() => _profile = profile);
  }

  List<FoodListing> _filterAndSort(List<FoodListing> listings) {
    var result = listings;
    if (_selectedCategory != 'all') {
      result = result.where((l) {
        final business = _businessesById[l.businessId];
        return business?.category == _selectedCategory;
      }).toList();
    }
    if (_lat != null && _lng != null) {
      result = [...result]..sort((a, b) {
          final da = _locationService.distanceInKm(_lat!, _lng!, a.lat, a.lng);
          final db = _locationService.distanceInKm(_lat!, _lng!, b.lat, b.lng);
          return da.compareTo(db);
        });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (_profile?.name.isNotEmpty == true)
        ? _profile!.name.split(' ').first
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('BachaoKhana'),
        actions: const [NotificationBell()],
      ),
      body: StreamBuilder<List<FoodListing>>(
        stream: _databaseService.streamVerifiedActiveListings(),
        builder: (context, snapshot) {
          final listings = _filterAndSort(snapshot.data ?? []);

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // ---- Greeting ----
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  firstName != null ? 'Hello, $firstName! 👋' : 'Hello! 👋',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  'Great to see you again.',
                  style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
                ),
              ),

              // ---- Impact banner ----
              const ImpactBanner(),

              // ---- Category chips ----
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 20),
                  itemBuilder: (context, i) {
                    final cat = _categories[i];
                    final selected = _selectedCategory == cat['key'];
                    return GestureDetector(
                      onTap: () => setState(
                          () => _selectedCategory = cat['key'] as String),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.green.shade700
                                  : Colors.green.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              cat['icon'] as IconData,
                              color: selected
                                  ? Colors.white
                                  : Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cat['label'] as String,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: selected
                                  ? Colors.green.shade800
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ---- Nearby offers header ----
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Nearby offers',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                    TextButton(
                      onPressed: widget.onSeeAllTap,
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),

              // ---- Nearby offers carousel ----
              if (!snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (listings.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Text(
                    'No surprise bags in this category right now.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              else
                SizedBox(
                  height: 310,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: listings.take(8).length,
                    itemBuilder: (context, i) {
                      final listing = listings[i];
                      final business = _businessesById[listing.businessId];
                      final distanceLabel = (_lat != null && _lng != null)
                          ? '${_locationService.distanceInKm(_lat!, _lng!, listing.lat, listing.lng).toStringAsFixed(1)} km'
                          : null;
                      return SizedBox(
                        width: 285,
                        child: ListingCard(
                          listing: listing,
                          distanceLabel: distanceLabel,
                          rating: business?.averageRating,
                          ratingCount: business?.ratingCount,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ListingDetailScreen(listing: listing),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
