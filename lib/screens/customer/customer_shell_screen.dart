import 'package:flutter/material.dart';
import 'home_tab.dart';
import 'favorites_tab.dart';
import 'my_orders_screen.dart';
import 'profile_tab.dart';
import 'restaurants_search_screen.dart';

/// The customer's main shell: a persistent bottom navigation bar with five
/// destinations (Home, Browse, Favorites, Orders, Profile), matching the
/// standard layout used by apps like Too Good To Go.
///
/// Uses an IndexedStack rather than swapping widgets in and out, so each
/// tab's scroll position, StreamBuilder subscriptions, and form state stay
/// alive when switching tabs instead of resetting every time (the same
/// principle as the AutomaticKeepAliveClientMixin fix used for the business
/// dashboard's tabs).
class CustomerShellScreen extends StatefulWidget {
  const CustomerShellScreen({super.key});

  @override
  State<CustomerShellScreen> createState() => _CustomerShellScreenState();
}

class _CustomerShellScreenState extends State<CustomerShellScreen> {
  int _index = 0;

  void _goToBrowseTab() => setState(() => _index = 1);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeTab(onSeeAllTap: _goToBrowseTab),
      const RestaurantsSearchScreen(), // "Browse" — full list
      const FavoritesTab(),
      const MyOrdersScreen(), // "Orders"`
      const ProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: 'Browse'),
          NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: 'Favorites'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Orders'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}
