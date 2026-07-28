import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/business.dart';
import '../../models/listing.dart';
import '../../models/order.dart';
import '../../models/menu_item.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/menu_item_card.dart';
import '../../widgets/order_card.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/star_rating.dart';
import '../auth/login_screen.dart';
import 'add_listing_screen.dart';
import 'add_menu_item_screen.dart';
import 'edit_listing_screen.dart';
import 'qr_scan_screen.dart';

/// Home screen for a business user: two tabs — "My listings" and "Orders",
/// plus a floating button to create a new surplus food listing and an
/// app-bar action to scan customer QR codes for pickup verification.
class BusinessHomeScreen extends StatefulWidget {
  const BusinessHomeScreen({super.key});

  @override
  State<BusinessHomeScreen> createState() => _BusinessHomeScreenState();
}

class _BusinessHomeScreenState extends State<BusinessHomeScreen> {
  final _authService = AuthService();
  final _databaseService = DatabaseService();
  Business? _business;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    try {
      final uid = _authService.currentUser!.uid;
      final business = await _databaseService.getBusinessByOwner(uid);
      if (mounted) {
        setState(() {
          _business = business;
          _error = business == null
              ? 'No business profile found for this account.'
              : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load business: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _loadBusiness();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_business == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);
          return AnimatedBuilder(
            animation: tabController,
            builder: (context, _) =>
                _buildScaffold(context, tabController.index),
          );
        },
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, int currentTabIndex) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_business!.name),
            if (_business!.ratingCount > 0)
              Row(
                children: [
                  StarRating(
                      rating: _business!.averageRating.round(), size: 12),
                  const SizedBox(width: 4),
                  Text(
                    '${_business!.averageRating.toStringAsFixed(1)} (${_business!.ratingCount})',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.normal),
                  ),
                ],
              )
            else
              const Text(
                'No ratings yet',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan pickup QR',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QrScanScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Surprise Bags'),
            Tab(text: 'Menu'),
            Tab(text: 'Orders'),
          ],
        ),
      ),
      // FAB changes with the selected tab: "New listing" on Surprise Bags,
      // "Add menu item" on Menu, and hidden on Orders (nothing to create there).
      floatingActionButton: currentTabIndex == 0
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('New listing'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddListingScreen(business: _business!),
                  ),
                );
              },
            )
          : currentTabIndex == 1
              ? FloatingActionButton.extended(
                  icon: const Icon(Icons.add),
                  label: const Text('Add menu item'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddMenuItemScreen(business: _business!),
                      ),
                    );
                  },
                )
              : null,
      body: Column(
        children: [
          if (!_business!.verified)
            Container(
              width: double.infinity,
              color: Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.hourglass_empty,
                      size: 18, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pending admin approval — your listings and menu won\'t '
                      'appear to customers until your account is verified.',
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
          // Keys force Flutter to treat these as stable, distinct tab pages
          // (see _BusinessListingsTab / _BusinessMenuTab / _BusinessOrdersTab
          // below for why each one owns and caches its own stream instead
          // of recreating it).
          Expanded(
            child: TabBarView(
              children: [
                _BusinessListingsTab(
                  key: ValueKey('listings-${_business!.id}'),
                  databaseService: _databaseService,
                  businessId: _business!.id,
                ),
                _BusinessMenuTab(
                  key: ValueKey('menu-${_business!.id}'),
                  databaseService: _databaseService,
                  business: _business!,
                ),
                _BusinessOrdersTab(
                  key: ValueKey('orders-${_business!.id}'),
                  databaseService: _databaseService,
                  businessId: _business!.id,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "My listings" tab content as its own StatefulWidget.
///
/// Why this is a separate widget instead of a method that returns a
/// StreamBuilder: when it was just a method called from build(), Flutter's
/// TabBarView (built on PageView) can dispose and recreate the tab's
/// element when switching away and back, which recreated the Stream from
/// scratch each time via a fresh call to streamBusinessListings(...). This
/// widget uses AutomaticKeepAliveClientMixin so Flutter keeps its State
/// alive for the lifetime of the TabBarView, and the Stream is created
/// exactly once in initState() and cached — so switching tabs never loses
/// or re-triggers the subscription.
class _BusinessListingsTab extends StatefulWidget {
  final DatabaseService databaseService;
  final String businessId;

  const _BusinessListingsTab({
    super.key,
    required this.databaseService,
    required this.businessId,
  });

  @override
  State<_BusinessListingsTab> createState() => _BusinessListingsTabState();
}

class _BusinessListingsTabState extends State<_BusinessListingsTab>
    with AutomaticKeepAliveClientMixin {
  late final Stream<List<FoodListing>> _stream =
      widget.databaseService.streamBusinessListings(widget.businessId);

  @override
  bool get wantKeepAlive => true;

  Future<void> _confirmDelete(
      BuildContext context, String listingId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this listing?'),
        content: Text(
            '"$title" will be permanently removed. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.databaseService.deleteListing(listingId);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return StreamBuilder<List<FoodListing>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Failed to load listings:\n${snapshot.error}',
                  textAlign: TextAlign.center),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final listings = snapshot.data!;
        if (listings.isEmpty) {
          return const Center(
              child: Text('No listings yet. Tap + to add one.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: listings.length,
          itemBuilder: (context, i) {
            final listing = listings[i];
            return ListingCard(
              listing: listing,
              businessActions: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EditListingScreen(listing: listing),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      label: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                      onPressed: () =>
                          _confirmDelete(context, listing.id, listing.title),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// "Menu" tab content — a business's regular, always-available items,
/// separate from their time-limited surplus listings. Same keep-alive
/// pattern as the other tabs.
class _BusinessMenuTab extends StatefulWidget {
  final DatabaseService databaseService;
  final Business business;

  const _BusinessMenuTab({
    super.key,
    required this.databaseService,
    required this.business,
  });

  @override
  State<_BusinessMenuTab> createState() => _BusinessMenuTabState();
}

class _BusinessMenuTabState extends State<_BusinessMenuTab>
    with AutomaticKeepAliveClientMixin {
  late final Stream<List<MenuItem>> _stream =
      widget.databaseService.streamBusinessMenuItems(widget.business.id);

  @override
  bool get wantKeepAlive => true;

  Future<void> _confirmDelete(
      BuildContext context, String itemId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove this item?'),
        content: Text('"$name" will be permanently removed from your menu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.databaseService.deleteMenuItem(itemId);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<MenuItem>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Failed to load menu:\n${snapshot.error}',
                  textAlign: TextAlign.center),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No menu items yet. Tap + to add your everyday menu — '
                'no expiry, always orderable.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return MenuItemCard(
              item: item,
              businessActions: Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddMenuItemScreen(
                              business: widget.business,
                              existingItem: item,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      label: const Text('Delete',
                          style: TextStyle(color: Colors.red)),
                      onPressed: () =>
                          _confirmDelete(context, item.id, item.name),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// "Orders" tab content — same reasoning as _BusinessListingsTab above.
class _BusinessOrdersTab extends StatefulWidget {
  final DatabaseService databaseService;
  final String businessId;

  const _BusinessOrdersTab({
    super.key,
    required this.databaseService,
    required this.businessId,
  });

  @override
  State<_BusinessOrdersTab> createState() => _BusinessOrdersTabState();
}

class _BusinessOrdersTabState extends State<_BusinessOrdersTab>
    with AutomaticKeepAliveClientMixin {
  late final Stream<List<FoodOrder>> _stream =
      widget.databaseService.streamBusinessOrders(widget.businessId);

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    return StreamBuilder<List<FoodOrder>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Failed to load orders:\n${snapshot.error}',
                  textAlign: TextAlign.center),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snapshot.data!;
        if (orders.isEmpty) {
          return const Center(child: Text('No orders yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          itemBuilder: (context, i) {
            final order = orders[i];
            final showAcceptButton =
                order.isMenuOrder && order.status == 'pending';
            final showDeliverButton = order.isDelivery &&
                (order.status == 'pending' || order.status == 'confirmed');

            Widget? footer;
            if (showAcceptButton) {
              footer = FilledButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Accept order — start preparing'),
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700),
                onPressed: () async {
                  await widget.databaseService.confirmOrder(order.id);
                },
              );
            } else if (showDeliverButton) {
              footer = OutlinedButton.icon(
                icon: const Icon(Icons.delivery_dining, size: 18),
                label: const Text('Mark as delivered'),
                onPressed: () async {
                  await widget.databaseService.markAsDelivered(order.id);
                },
              );
            }

            return OrderCard(order: order, footer: footer);
          },
        );
      },
    );
  }
}
