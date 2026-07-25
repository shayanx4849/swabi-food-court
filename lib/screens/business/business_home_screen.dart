import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/business.dart';
import '../../models/listing.dart';
import '../../models/order.dart';
import '../../widgets/listing_card.dart';
import '../../widgets/order_card.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/star_rating.dart';
import '../auth/login_screen.dart';
import 'add_listing_screen.dart';
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
      length: 2,
      child: Scaffold(
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
              Tab(text: 'My listings'),
              Tab(text: 'Orders'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('New listing'),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddListingScreen(business: _business!),
              ),
            );
          },
        ),
        body: Column(
          children: [
            if (!_business!.verified)
              Container(
                width: double.infinity,
                color: Colors.orange.shade50,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.hourglass_empty,
                        size: 18, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pending admin approval — your listings won\'t appear '
                        'to customers until your account is verified.',
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            // Keys force Flutter to treat these as stable, distinct tab pages
            // (see _BusinessListingsTab / _BusinessOrdersTab below for why
            // each one owns and caches its own stream instead of recreating
            // it).
            Expanded(
              child: TabBarView(
                children: [
                  _BusinessListingsTab(
                    key: ValueKey('listings-${_business!.id}'),
                    databaseService: _databaseService,
                    businessId: _business!.id,
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
            final showDeliverButton =
                order.isDelivery && order.status == 'pending';
            return OrderCard(
              order: order,
              footer: showDeliverButton
                  ? OutlinedButton.icon(
                      icon: const Icon(Icons.delivery_dining, size: 18),
                      label: const Text('Mark as delivered'),
                      onPressed: () async {
                        await widget.databaseService.markAsDelivered(order.id);
                      },
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}
