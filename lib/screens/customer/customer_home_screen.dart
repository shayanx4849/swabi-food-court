import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../models/listing.dart';
import '../../models/business.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/notification_bell.dart';
import 'listing_detail_screen.dart';

/// Customer's main discovery screen — a real-time list of active nearby
/// surplus food listings, sorted by distance from the device's location.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _databaseService = DatabaseService();
  final _locationService = LocationService();

  double? _lat;
  double? _lng;

  // businessId -> Business, kept live so each listing card can show that
  // business's current rating without a separate fetch per card.
  Map<String, Business> _businessesById = {};

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _databaseService.streamAllBusinesses().listen((businesses) {
      if (!mounted) return;
      setState(() {
        _businessesById = {for (final b in businesses) b.id: b};
      });
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
      // Location permission denied or unavailable — listings will show
      // without distance sorting/filtering as a fallback.
    }
  }

  List<FoodListing> _sortByDistance(List<FoodListing> listings) {
    if (_lat == null || _lng == null) return listings;
    final sorted = [...listings];
    sorted.sort((a, b) {
      final da = _locationService.distanceInKm(_lat!, _lng!, a.lat, a.lng);
      final db = _locationService.distanceInKm(_lat!, _lng!, b.lat, b.lng);
      return da.compareTo(db);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse'),
        actions: const [NotificationBell()],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<FoodListing>>(
              stream: _databaseService.streamVerifiedActiveListings(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          Text('Failed to load listings:\n${snapshot.error}',
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final listings = _sortByDistance(snapshot.data!);
                if (listings.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.ramen_dining_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'No surprise bags nearby right now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Check back later — businesses usually post\nsurplus bags in the evening.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: listings.length,
                  itemBuilder: (context, i) {
                    final listing = listings[i];
                    final distanceLabel = (_lat != null && _lng != null)
                        ? '${_locationService.distanceInKm(_lat!, _lng!, listing.lat, listing.lng).toStringAsFixed(1)} km'
                        : null;
                    final business = _businessesById[listing.businessId];
                    return ListingCard(
                      listing: listing,
                      distanceLabel: distanceLabel,
                      rating: business?.averageRating,
                      ratingCount: business?.ratingCount,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ListingDetailScreen(listing: listing),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
