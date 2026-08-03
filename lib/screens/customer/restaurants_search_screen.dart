import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/database_service.dart';
import '../../services/location_service.dart';
import '../../models/business.dart';
import '../../widgets/star_rating.dart';
import '../../widgets/favorite_button.dart';
import 'restaurant_menu_screen.dart';

/// Search/browse screen listing every verified business on the platform —
/// tapping one opens their regular menu (RestaurantMenuScreen). This is the
/// entry point for ordering from a business's everyday menu, separate from
/// browsing discounted Surprise Bag deals.
class RestaurantsSearchScreen extends StatefulWidget {
  const RestaurantsSearchScreen({super.key});

  @override
  State<RestaurantsSearchScreen> createState() => _RestaurantsSearchScreenState();
}

class _RestaurantsSearchScreenState extends State<RestaurantsSearchScreen> {
  final _databaseService = DatabaseService();
  final _locationService = LocationService();
  final _searchCtrl = TextEditingController();
  final _mapController = MapController();

  String _query = '';
  String _categoryFilter = 'all';
  bool _showMap = false;
  LatLng? _myLocation;
  Business? _selectedBusiness;

  static const _fallbackCenter = LatLng(34.1200, 72.4700); // Swabi, KP

  static const _categories = [
    {'key': 'all', 'label': 'All'},
    {'key': 'restaurant', 'label': 'Meals'},
    {'key': 'bakery', 'label': 'Bakery'},
    {'key': 'mart', 'label': 'Groceries'},
  ];

  @override
  void initState() {
    super.initState();
    _loadMyLocation();
  }

  Future<void> _loadMyLocation() async {
    try {
      final pos = await _locationService.getCurrentLocation();
      if (mounted) setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      // No GPS fix — map just falls back to a default center, same as
      // elsewhere in the app when location is unavailable.
    }
  }

  List<Business> _filter(List<Business> businesses) {
    var result = businesses.where((b) => b.verified).toList();
    if (_categoryFilter != 'all') {
      result = result.where((b) => b.category == _categoryFilter).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      result = result.where((b) => b.name.toLowerCase().contains(q)).toList();
    }

    // Nearest-first once we know where the customer actually is — pinless
    // businesses (0,0) sink to the bottom since a "0 km" reading for them
    // would be misleading.
    if (_myLocation != null) {
      result.sort((a, b) {
        final aPinned = a.lat != 0 || a.lng != 0;
        final bPinned = b.lat != 0 || b.lng != 0;
        if (aPinned != bPinned) return aPinned ? -1 : 1;
        if (!aPinned) return 0;
        return _distanceKm(a)!.compareTo(_distanceKm(b)!);
      });
    }

    return result;
  }

  /// Straight-line distance from the customer to [business], or null if
  /// either point is unknown.
  double? _distanceKm(Business business) {
    if (_myLocation == null) return null;
    if (business.lat == 0 && business.lng == 0) return null;
    return _locationService.distanceInKm(
      _myLocation!.latitude, _myLocation!.longitude, business.lat, business.lng);
  }

  String? _distanceLabel(Business business) {
    final km = _distanceKm(business);
    if (km == null) return null;
    return km < 1 ? '${(km * 1000).round()} m away' : '${km.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurants'),
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map_outlined),
            tooltip: _showMap ? 'List view' : 'Map view',
            onPressed: () => setState(() {
              _showMap = !_showMap;
              _selectedBusiness = null;
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search for restaurants or stores',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final selected = _categoryFilter == cat['key'];
                return ChoiceChip(
                  label: Text(cat['label']!),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    _categoryFilter = cat['key']!;
                    _selectedBusiness = null;
                  }),
                  selectedColor: Colors.green.shade700,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<Business>>(
              stream: _databaseService.streamAllBusinesses(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Failed to load: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final businesses = _filter(snapshot.data!);
                if (businesses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No restaurants found.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  );
                }
                return _showMap ? _mapView(businesses) : _listView(businesses);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _listView(List<Business> businesses) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: businesses.length,
      itemBuilder: (context, i) {
        final business = businesses[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade50,
              child: Icon(Icons.storefront, color: Colors.green.shade700),
            ),
            title: Text(business.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Row(
              children: [
                Text(business.category,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                if (business.ratingCount > 0) ...[
                  const SizedBox(width: 8),
                  StarRating(rating: business.averageRating.round(), size: 12),
                  const SizedBox(width: 3),
                  Text(business.averageRating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12)),
                ],
                if (_distanceLabel(business) != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.near_me, size: 11, color: Colors.green.shade700),
                  const SizedBox(width: 2),
                  Text(_distanceLabel(business)!,
                      style: TextStyle(fontSize: 11.5, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FavoriteButton(businessId: business.id),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _openMenu(business),
          ),
        );
      },
    );
  }

  Widget _mapView(List<Business> businesses) {
    // Businesses that were never geo-pinned sit at (0,0) — filter those
    // out of the map (they'd otherwise all stack in the Gulf of Guinea)
    // but they still show up fine in List view.
    final pinned = businesses.where((b) => b.lat != 0 || b.lng != 0).toList();
    final center = _myLocation ??
        (pinned.isNotEmpty ? LatLng(pinned.first.lat, pinned.first.lng) : _fallbackCenter);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            onTap: (_, __) => setState(() => _selectedBusiness = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.bachaokhana.app',
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
                TextSourceAttribution('CARTO'),
              ],
            ),
            MarkerLayer(markers: [
              if (_myLocation != null)
                Marker(
                  point: _myLocation!,
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                ),
              for (final business in pinned)
                Marker(
                  point: LatLng(business.lat, business.lng),
                  width: 42,
                  height: 42,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedBusiness = business),
                    child: Icon(
                      Icons.location_pin,
                      size: 42,
                      color: _selectedBusiness?.id == business.id
                          ? Colors.green.shade900
                          : Colors.green.shade700,
                    ),
                  ),
                ),
            ]),
          ],
        ),
        if (pinned.length < businesses.length)
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  '${businesses.length - pinned.length} business(es) without a pinned location aren\'t shown on the map.',
                  style: TextStyle(fontSize: 11.5, color: Colors.orange.shade900),
                ),
              ),
            ),
          ),
        if (_selectedBusiness != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: _businessPreviewCard(_selectedBusiness!),
          ),
      ],
    );
  }

  Widget _businessPreviewCard(Business business) {
    return Card(
      elevation: 4,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: Icon(Icons.storefront, color: Colors.green.shade700),
        ),
        title: Text(business.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          _distanceLabel(business) != null
              ? '${_distanceLabel(business)} \u2022 ${business.address}'
              : business.address,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
          onPressed: () => _openMenu(business),
          child: const Text('View menu'),
        ),
      ),
    );
  }

  void _openMenu(Business business) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RestaurantMenuScreen(business: business)),
    );
  }
}
