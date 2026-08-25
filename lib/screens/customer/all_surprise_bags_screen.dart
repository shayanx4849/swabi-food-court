import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../models/listing.dart';
import 'listing_detail_screen.dart';

/// Full list of every currently active Surprise Bag listing across all
/// businesses — reached from the Home tab's "Surprise Bags" carousel via
/// "See all". Distinct from the business-managed Deals shown in a
/// separate carousel and screen.
class AllSurpriseBagsScreen extends StatefulWidget {
  const AllSurpriseBagsScreen({super.key});

  @override
  State<AllSurpriseBagsScreen> createState() => _AllSurpriseBagsScreenState();
}

class _AllSurpriseBagsScreenState extends State<AllSurpriseBagsScreen> {
  final _databaseService = DatabaseService();
  final _locationService = LocationService();
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _loadLocation();
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
    } catch (_) {
      // No GPS fix — listings just show unsorted by distance.
    }
  }

  List<FoodListing> _sortByDistance(List<FoodListing> listings) {
    if (_lat == null || _lng == null) return listings;
    return [...listings]..sort((a, b) {
        final da = _locationService.distanceInKm(_lat!, _lng!, a.lat, a.lng);
        final db = _locationService.distanceInKm(_lat!, _lng!, b.lat, b.lng);
        return da.compareTo(db);
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Surprise Bags')),
      body: StreamBuilder<List<FoodListing>>(
        stream: _databaseService.streamVerifiedActiveListings(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final listings = _sortByDistance(snapshot.data!);
          if (listings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No Surprise Bags nearby right now — check back soon!',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: listings.length,
            itemBuilder: (context, i) {
              final listing = listings[i];
              final pctOff = listing.originalPrice > 0
                  ? (((listing.originalPrice - listing.price) / listing.originalPrice) * 100).round()
                  : 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: listing.imageUrl != null
                        ? Image.network(listing.imageUrl!, width: 56, height: 56, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder())
                        : _placeholder(),
                  ),
                  title: Text(listing.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${listing.businessName}${pctOff > 0 ? ' \u2022 $pctOff% off' : ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Rs. ${listing.price.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                      if (listing.originalPrice > listing.price)
                        Text('Rs. ${listing.originalPrice.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 11, decoration: TextDecoration.lineThrough, color: Colors.grey.shade500)),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: listing)),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 56, height: 56,
      color: Colors.orange.shade50,
      child: Icon(Icons.eco_outlined, color: Colors.orange.shade300),
    );
  }
}
