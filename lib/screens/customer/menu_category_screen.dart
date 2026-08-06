import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/menu_item.dart';
import '../../widgets/menu_item_grid_card.dart';
import 'menu_item_detail_screen.dart';

/// Browse menu items by food category across every restaurant on the
/// platform — e.g. tapping "Drinks" here shows drinks from every business,
/// not just one. Distinct from RestaurantsSearchScreen, which browses by
/// business rather than by dish.
class MenuCategoryScreen extends StatefulWidget {
  /// Which category chip starts selected — pass one of [kMenuItemCategories]
  /// or 'All'.
  final String initialCategory;

  const MenuCategoryScreen({super.key, required this.initialCategory});

  @override
  State<MenuCategoryScreen> createState() => _MenuCategoryScreenState();
}

class _MenuCategoryScreenState extends State<MenuCategoryScreen> {
  final _databaseService = DatabaseService();
  late String _selectedCategory = widget.initialCategory;

  static const _all = 'All';

  List<MenuItem> _filter(List<MenuItem> items) {
    if (_selectedCategory == _all) return items;
    return items.where((i) => i.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse by category')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: kMenuItemCategories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final label = i == 0 ? _all : kMenuItemCategories[i - 1];
                final selected = _selectedCategory == label;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = label),
                  selectedColor: Colors.green.shade700,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: StreamBuilder<List<MenuItem>>(
              stream: _databaseService.streamVerifiedMenuItems(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Failed to load: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = _filter(snapshot.data!);
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No items in "$_selectedCategory" right now.',
                        style: TextStyle(color: Colors.grey.shade600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return MenuItemGridCard(
                      item: item,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => MenuItemDetailScreen(item: item)),
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
