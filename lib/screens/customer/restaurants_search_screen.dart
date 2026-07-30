import 'package:flutter/material.dart';
import '../../services/database_service.dart';
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
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _categoryFilter = 'all';

  static const _categories = [
    {'key': 'all', 'label': 'All'},
    {'key': 'restaurant', 'label': 'Meals'},
    {'key': 'bakery', 'label': 'Bakery'},
    {'key': 'mart', 'label': 'Groceries'},
  ];

  List<Business> _filter(List<Business> businesses) {
    var result = businesses.where((b) => b.verified).toList();
    if (_categoryFilter != 'all') {
      result = result.where((b) => b.category == _categoryFilter).toList();
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      result = result.where((b) => b.name.toLowerCase().contains(q)).toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurants')),
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
                  onSelected: (_) => setState(() => _categoryFilter = cat['key']!),
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
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FavoriteButton(businessId: business.id),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RestaurantMenuScreen(business: business),
                            ),
                          );
                        },
                      ),
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
