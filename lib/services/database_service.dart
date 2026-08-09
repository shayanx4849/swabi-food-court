import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import '../models/business.dart';
import '../models/listing.dart';
import '../models/order.dart';
import '../models/review.dart';
import '../models/notification_item.dart';
import '../models/menu_item.dart';
import '../models/cart_item.dart';
import '../models/deal.dart';
import '../models/saved_address.dart';
import 'cart_service.dart';

/// All app data lives in Firebase Realtime Database instead of Cloud
/// Firestore, since Realtime Database is fully usable on Firebase's free
/// Spark plan with no billing account required.
///
/// Roughly one estimated-CO2-saved figure is used for the impact counter:
/// ~2.5 kg of CO2-equivalent avoided per rescued meal, a commonly cited
/// rough estimate for food waste's carbon footprint. This is an
/// approximation for the impact dashboard, not a precise measurement.
class DatabaseService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final _uuid = const Uuid();

  static const double kgCo2PerMeal = 2.5;

  // ---------------- BUSINESS ----------------

  Future<void> createBusiness(Business business) async {
    await _db.child('businesses').child(business.id).set(business.toMap());
  }

  Future<Business?> getBusinessByOwner(String ownerId) async {
    final snap = await _db
        .child('businesses')
        .orderByChild('ownerId')
        .equalTo(ownerId)
        .limitToFirst(1)
        .get();

    if (!snap.exists || snap.value == null) return null;

    final map = Map<dynamic, dynamic>.from(snap.value as Map);
    final entry = map.entries.first;
    return Business.fromMap(entry.key, Map<dynamic, dynamic>.from(entry.value));
  }

  Future<Business?> getBusinessById(String businessId) async {
    final snap = await _db.child('businesses').child(businessId).get();
    if (!snap.exists || snap.value == null) return null;
    final map = Map<dynamic, dynamic>.from(snap.value as Map);
    return Business.fromMap(businessId, map);
  }

  /// All businesses — used to plot markers on the customer map view.
  Stream<List<Business>> streamAllBusinesses() {
    return _db.child('businesses').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <Business>[];
      final map = Map<dynamic, dynamic>.from(data as Map);
      return map.entries
          .map((e) =>
              Business.fromMap(e.key, Map<dynamic, dynamic>.from(e.value)))
          .toList();
    }).asBroadcastStream();
  }

  /// Admin: businesses awaiting verification.
  Stream<List<Business>> streamPendingBusinesses() {
    return streamAllBusinesses()
        .map((list) => list.where((b) => !b.verified).toList())
        .asBroadcastStream();
  }

  Future<void> setBusinessVerified(String businessId, bool verified) async {
    await _db
        .child('businesses')
        .child(businessId)
        .child('verified')
        .set(verified);
  }

  /// Business toggles this themselves from their own app — whether they're
  /// currently accepting regular menu orders. Deliberately separate from
  /// [setBusinessVerified] (admin-only) and from Surprise Bag listings,
  /// which already have their own time-based expiry and aren't affected.
  Future<void> setBusinessOpen(String businessId, bool isOpen) async {
    await _db.child('businesses').child(businessId).child('isOpen').set(isOpen);
  }

  Future<void> deleteBusiness(String businessId) async {
    await _db.child('businesses').child(businessId).remove();
  }

  // ---------------- LISTINGS ----------------

  Future<void> createListing(FoodListing listing) async {
    await _db.child('listings').child(listing.id).set(listing.toMap());
  }

  /// Fetches a single listing by id — used by cart checkout to re-validate
  /// a Surprise Bag's current stock/status right before placing the order,
  /// since the value cached on the CartItem may be stale by then.
  Future<FoodListing?> getListingById(String listingId) async {
    final snap = await _db.child('listings').child(listingId).get();
    if (!snap.exists || snap.value == null) return null;
    final map = Map<dynamic, dynamic>.from(snap.value as Map);
    return FoodListing.fromMap(listingId, map);
  }

  Stream<List<FoodListing>> streamActiveListings() {
    return _db.child('listings').onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <FoodListing>[];
      final map = Map<dynamic, dynamic>.from(data as Map);
      return map.entries
          .map((e) =>
              FoodListing.fromMap(e.key, Map<dynamic, dynamic>.from(e.value)))
          // Customers should never see sold-out, cancelled, OR expired
          // listings — even though "expired" isn't a status stored in the
          // database, isExpired is computed live from pickupEnd.
          .where((l) => l.status == 'active' && !l.isExpired)
          .toList();
    }).asBroadcastStream();
  }

  /// What the customer discovery feed should actually use instead of
  /// streamActiveListings() directly.
  ///
  /// Realtime Database has no server-side "join", so this combines two
  /// separate live streams client-side: active listings, and the current
  /// set of verified business IDs. A listing only appears once BOTH its
  /// own status is active AND its business has been approved by an admin.
  /// Whenever either stream updates (a new listing is posted, or an admin
  /// approves/revokes a business), the combined result recomputes and
  /// re-emits automatically.
  Stream<List<FoodListing>> streamVerifiedActiveListings() {
    final controller = StreamController<List<FoodListing>>.broadcast();
    List<FoodListing>? latestListings;
    Set<String>? verifiedBusinessIds;
    StreamSubscription? listingsSub;
    StreamSubscription? businessesSub;

    void emitIfReady() {
      if (latestListings != null && verifiedBusinessIds != null) {
        controller.add(
          latestListings!
              .where((l) => verifiedBusinessIds!.contains(l.businessId))
              .toList(),
        );
      }
    }

    controller.onListen = () {
      listingsSub = streamActiveListings().listen((listings) {
        latestListings = listings;
        emitIfReady();
      }, onError: controller.addError);

      businessesSub = streamAllBusinesses().listen((businesses) {
        verifiedBusinessIds =
            businesses.where((b) => b.verified).map((b) => b.id).toSet();
        emitIfReady();
      }, onError: controller.addError);
    };

    controller.onCancel = () {
      listingsSub?.cancel();
      businessesSub?.cancel();
    };

    return controller.stream;
  }

  /// Business edits an existing listing (title, price, quantity, pickup
  /// window, photo, etc). Only the fields present in [listing] are written.
  Future<void> updateListing(FoodListing listing) async {
    await _db.child('listings').child(listing.id).update(listing.toMap());
  }

  /// Business permanently removes a listing (e.g. posted by mistake, or an
  /// old expired one they want to clear out).
  Future<void> deleteListing(String listingId) async {
    await _db.child('listings').child(listingId).remove();
  }

  Stream<List<FoodListing>> streamBusinessListings(String businessId) {
    return _db
        .child('listings')
        .orderByChild('businessId')
        .equalTo(businessId)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return <FoodListing>[];
      final map = Map<dynamic, dynamic>.from(data as Map);
      final listings = map.entries
          .map((e) =>
              FoodListing.fromMap(e.key, Map<dynamic, dynamic>.from(e.value)))
          .toList();
      listings.sort((a, b) => b.pickupStart.compareTo(a.pickupStart));
      return listings;
    }).asBroadcastStream();
  }

  Future<void> decrementListingQuantity(String listingId) async {
    final ref = _db.child('listings').child(listingId);

    await ref.child('quantityAvailable').runTransaction((currentValue) {
      final current = (currentValue as int?) ?? 0;
      final updated = current - 1;
      return Transaction.success(updated < 0 ? 0 : updated);
    });

    final snap = await ref.child('quantityAvailable').get();
    final remaining = (snap.value as int?) ?? 0;
    if (remaining <= 0) {
      await ref.child('status').set('sold_out');
    }
  }

  // ---------------- ORDERS ----------------

  /// Customer reserves a listing: decrements stock, creates an order with
  /// a unique QR code, and notifies the business of the new order.
  ///
  /// [orderType] is 'pickup' (default) or 'delivery'. Delivery orders carry
  /// a [deliveryAddress] and flat [deliveryFee] — there is no rider/tracking
  /// in this MVP, the business fulfils delivery themselves and marks it
  /// delivered manually (see markAsDelivered below).
  Future<FoodOrder> createOrder({
    required FoodListing listing,
    required String customerId,
    required String customerName,
    String orderType = 'pickup',
    String? deliveryAddress,
    double deliveryFee = 0,
    String? customerPhone,
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    final orderId = _uuid.v4();
    final order = FoodOrder(
      id: orderId,
      listingId: listing.id,
      businessId: listing.businessId,
      businessName: listing.businessName,
      listingTitle: listing.title,
      customerId: customerId,
      customerName: customerName,
      price: listing.price,
      qrCode: orderId,
      status: 'pending',
      createdAt: DateTime.now(),
      orderType: orderType,
      deliveryAddress: orderType == 'delivery' ? deliveryAddress : null,
      deliveryFee: orderType == 'delivery' ? deliveryFee : 0,
      customerPhone: orderType == 'delivery' ? customerPhone : null,
      deliveryLat: orderType == 'delivery' ? deliveryLat : null,
      deliveryLng: orderType == 'delivery' ? deliveryLng : null,
    );

    await _db.child('orders').child(orderId).set(order.toMap());
    await decrementListingQuantity(listing.id);

    // Notify the business owner in-app that a new order came in.
    final business = await getBusinessById(listing.businessId);
    if (business != null) {
      await addNotification(
        uid: business.ownerId,
        title: 'New order received',
        body: orderType == 'delivery'
            ? '$customerName requested delivery for "${listing.title}".'
            : '$customerName reserved "${listing.title}".',
      );
    }

    return order;
  }

  /// Business marks a delivery order as fulfilled once it's been dropped
  /// off. Delivery orders skip QR-scan verification since there's no
  /// in-person handoff at the business location to scan at.
  Future<void> markAsDelivered(String orderId) async {
    final ref = _db.child('orders').child(orderId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    // Surplus orders complete straight from "pending"; menu orders will
    // usually have been moved to "confirmed" first via confirmOrder().
    if (data['status'] != 'pending' && data['status'] != 'confirmed') return;

    await ref.child('status').set('completed');
    await _incrementImpactStats();

    await addNotification(
      uid: data['customerId'],
      title: 'Order delivered',
      body:
          'Your "${data['listingTitle']}" from ${data['businessName']} has been delivered!',
    );
  }

  /// Business explicitly confirms a menu order — e.g. "we've started
  /// preparing your order". Surplus (Surprise Bag) orders don't use this
  /// step since the pickup window already coordinates timing implicitly.
  Future<void> confirmOrder(String orderId) async {
    final ref = _db.child('orders').child(orderId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    if (data['status'] != 'pending') return;

    await ref.child('status').set('confirmed');

    await addNotification(
      uid: data['customerId'],
      title: 'Order confirmed',
      body:
          '${data['businessName']} has started working on your order "${data['listingTitle']}".',
    );
  }

  /// Customer cancels their own order — only allowed while it is still
  /// "pending" (i.e. the business hasn't accepted/started it yet). If the
  /// order was for a Surprise Bag listing, the unit it reserved is put
  /// back into that listing's available stock, and the listing is
  /// reopened from "sold_out" back to "active" if this was the unit that
  /// had sold it out. The order record itself is deleted, not just marked
  /// cancelled, so it doesn't linger in either party's order history.
  Future<void> cancelOrder(String orderId) async {
    final ref = _db.child('orders').child(orderId);
    final snap = await ref.get();
    if (!snap.exists) return;

    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    if (data['status'] != 'pending') return;

    final listingId = data['listingId'] as String?;
    if (data['orderSource'] == 'surplus' && listingId != null && listingId.isNotEmpty) {
      await _restoreListingQuantity(listingId);
    }

    final businessId = data['businessId'] as String?;
    if (businessId != null) {
      final business = await getBusinessById(businessId);
      if (business != null) {
        await addNotification(
          uid: business.ownerId,
          title: 'Order cancelled',
          body: '${data['customerName']} cancelled their order for "${data['listingTitle']}".',
        );
      }
    }

    await ref.remove();
  }

  /// Undoes one unit of [decrementListingQuantity] — used when a Surprise
  /// Bag order is cancelled while still pending, so the unit it reserved
  /// becomes available to other customers again.
  Future<void> _restoreListingQuantity(String listingId) async {
    final ref = _db.child('listings').child(listingId);

    await ref.child('quantityAvailable').runTransaction((currentValue) {
      final current = (currentValue as int?) ?? 0;
      return Transaction.success(current + 1);
    });

    final statusSnap = await ref.child('status').get();
    if (statusSnap.value == 'sold_out') {
      await ref.child('status').set('active');
    }
  }

  /// Business scans the customer's QR code at pickup time. Marks the order
  /// completed, bumps the global impact counters, and notifies the customer.
  Future<bool> verifyPickup(String scannedOrderId) async {
    final ref = _db.child('orders').child(scannedOrderId);
    final snap = await ref.get();
    if (!snap.exists) return false;

    final data = Map<dynamic, dynamic>.from(snap.value as Map);
    if (data['status'] != 'pending' && data['status'] != 'confirmed') {
      return false;
    }

    await ref.child('status').set('completed');
    await _incrementImpactStats();

    await addNotification(
      uid: data['customerId'],
      title: 'Order picked up',
      body:
          'Enjoy your "${data['listingTitle']}" from ${data['businessName']}!',
    );

    return true;
  }

  // ---------------- MENU ITEMS (regular, always-available items) ----------------
  //
  // Distinct from FoodListing: no pickup window, no stock/quantity limit,
  // no expiry. A business's normal, everyday menu, separate from their
  // time-limited surplus "Surprise Bag" listings.

  Future<void> createMenuItem(MenuItem item) async {
    await _db.child('menu_items').child(item.id).set(item.toMap());
  }

  /// Fetches a single menu item by id — used by cart checkout to
  /// re-validate it's still available right before placing the order.
  Future<MenuItem?> getMenuItemById(String itemId) async {
    final snap = await _db.child('menu_items').child(itemId).get();
    if (!snap.exists || snap.value == null) return null;
    final map = Map<dynamic, dynamic>.from(snap.value as Map);
    return MenuItem.fromMap(itemId, map);
  }

  Future<void> updateMenuItem(MenuItem item) async {
    await _db.child('menu_items').child(item.id).update(item.toMap());
  }

  Future<void> deleteMenuItem(String itemId) async {
    await _db.child('menu_items').child(itemId).remove();
  }

  Stream<List<MenuItem>> streamBusinessMenuItems(String businessId) {
    return _db
        .child('menu_items')
        .orderByChild('businessId')
        .equalTo(businessId)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return <MenuItem>[];
      final map = Map<dynamic, dynamic>.from(data as Map);
      return map.entries
          .map((e) =>
              MenuItem.fromMap(e.key, Map<dynamic, dynamic>.from(e.value)))
          .toList();
    }).asBroadcastStream();
  }

  /// All menu items from verified businesses only — same trust-gating
  /// principle as streamVerifiedActiveListings(), implemented the same way
  /// (client-side join of two live streams, since Realtime Database has no
  /// server-side join).
  Stream<List<MenuItem>> streamVerifiedMenuItems({String? businessId}) {
    final controller = StreamController<List<MenuItem>>.broadcast();
    List<MenuItem>? latestItems;
    Set<String>? eligibleBusinessIds; // verified AND currently open

    void emitIfReady() {
      if (latestItems != null && eligibleBusinessIds != null) {
        controller.add(
          latestItems!
              .where((i) =>
                  i.available && eligibleBusinessIds!.contains(i.businessId))
              .toList(),
        );
      }
    }

    controller.onListen = () {
      final itemsStream = businessId != null
          ? streamBusinessMenuItems(businessId)
          : _db.child('menu_items').onValue.map((event) {
              final data = event.snapshot.value;
              if (data == null) return <MenuItem>[];
              final map = Map<dynamic, dynamic>.from(data as Map);
              return map.entries
                  .map((e) => MenuItem.fromMap(
                      e.key, Map<dynamic, dynamic>.from(e.value)))
                  .toList();
            });

      itemsStream.listen((items) {
        latestItems = items;
        emitIfReady();
      }, onError: controller.addError);

      streamAllBusinesses().listen((businesses) {
        eligibleBusinessIds = businesses
            .where((b) => b.verified && b.isOpen)
            .map((b) => b.id)
            .toSet();
        emitIfReady();
      }, onError: controller.addError);
    };

    return controller.stream;
  }

  /// Customer orders a regular menu item. Unlike createOrder() for surplus
  /// listings, this does NOT touch any stock/quantity field (menu items
  /// have no limited quantity) and starts at "pending", awaiting the
  /// business's explicit confirmOrder() before moving to "confirmed".
  Future<FoodOrder> createMenuOrder({
    required MenuItem item,
    required String customerId,
    required String customerName,
    String orderType = 'pickup',
    String? deliveryAddress,
    double deliveryFee = 0,
    String? customerPhone,
    double? deliveryLat,
    double? deliveryLng,
    // Set when ordering through a business Deal — uses the deal's
    // discounted price instead of the menu item's normal price, and tags
    // the order so it's traceable back to that deal.
    double? priceOverride,
    String? dealId,
  }) async {
    final orderId = _uuid.v4();
    final order = FoodOrder(
      id: orderId,
      listingId: '',
      businessId: item.businessId,
      businessName: item.businessName,
      listingTitle: item.name,
      customerId: customerId,
      customerName: customerName,
      price: priceOverride ?? item.price,
      qrCode: orderId,
      status: 'pending',
      createdAt: DateTime.now(),
      orderType: orderType,
      deliveryAddress: orderType == 'delivery' ? deliveryAddress : null,
      deliveryFee: orderType == 'delivery' ? deliveryFee : 0,
      customerPhone: orderType == 'delivery' ? customerPhone : null,
      deliveryLat: orderType == 'delivery' ? deliveryLat : null,
      deliveryLng: orderType == 'delivery' ? deliveryLng : null,
      orderSource: 'menu',
      menuItemId: item.id,
      dealId: dealId,
    );

    await _db.child('orders').child(orderId).set(order.toMap());

    final business = await getBusinessById(item.businessId);
    if (business != null) {
      await addNotification(
        uid: business.ownerId,
        title: 'New menu order',
        body: '$customerName ordered "${item.name}".',
      );
    }

    return order;
  }

  Stream<List<FoodOrder>> streamCustomerOrders(String customerId) {
    return _db
        .child('orders')
        .orderByChild('customerId')
        .equalTo(customerId)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return <FoodOrder>[];
      final map = Map<dynamic, dynamic>.from(data as Map);
      final orders = map.entries
          .map((e) =>
              FoodOrder.fromMap(e.key, Map<dynamic, dynamic>.from(e.value)))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    }).asBroadcastStream();
  }

  Stream<List<FoodOrder>> streamBusinessOrders(String businessId) {
    return _db
        .child('orders')
        .orderByChild('businessId')
        .equalTo(businessId)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return <FoodOrder>[];
      final map = Map<dynamic, dynamic>.from(data as Map);
      final orders = map.entries
          .map((e) =>
              FoodOrder.fromMap(e.key, Map<dynamic, dynamic>.from(e.value)))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    }).asBroadcastStream();
  }

  // ---------------- DEALS ----------------
  //
  // Business-managed promotional discounts on existing menu items —
  // distinct from the surplus-listing (Surprise Bag) system above. A deal
  // has no forced pickup window; the business sets its own expiry date and
  // can edit/pause/delete it manually at any time via the business app.

  Future<void> createDeal(Deal deal) async {
    await _db.child('deals').child(deal.id).set(deal.toMap());
  }

  Future<void> updateDeal(Deal deal) async {
    await _db.child('deals').child(deal.id).set(deal.toMap());
  }

  Future<void> deleteDeal(String dealId) async {
    await _db.child('deals').child(dealId).remove();
  }

  Future<void> setDealActive(String dealId, bool active) async {
    await _db.child('deals').child(dealId).child('active').set(active);
  }

  Future<Deal?> getDealById(String dealId) async {
    final snap = await _db.child('deals').child(dealId).get();
    if (!snap.exists || snap.value == null) return null;
    final map = Map<dynamic, dynamic>.from(snap.value as Map);
    return Deal.fromMap(dealId, map);
  }

  /// All deals belonging to one business — including expired/paused ones,
  /// since the business needs to see and manage those too.
  Stream<List<Deal>> streamBusinessDeals(String businessId) {
    return _db
        .child('deals')
        .orderByChild('businessId')
        .equalTo(businessId)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return <Deal>[];
      final map = Map<dynamic, dynamic>.from(data as Map);
      final deals = map.entries
          .map((e) => Deal.fromMap(e.key, Map<dynamic, dynamic>.from(e.value)))
          .toList();
      deals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return deals;
    }).asBroadcastStream();
  }

  /// Every currently-live deal (active, not expired, from a verified
  /// business) across the whole platform — powers the Home tab's "Deals
  /// near you" carousel and any cross-restaurant deals browsing.
  Stream<List<Deal>> streamActiveDeals() {
    final controller = StreamController<List<Deal>>.broadcast();
    List<Deal>? latestDeals;
    Set<String>? eligibleBusinessIds; // verified AND currently open

    void emitIfReady() {
      if (latestDeals != null && eligibleBusinessIds != null) {
        controller.add(
          latestDeals!
              .where((d) => d.isLive && eligibleBusinessIds!.contains(d.businessId))
              .toList(),
        );
      }
    }

    controller.onListen = () {
      _db.child('deals').onValue.map((event) {
        final data = event.snapshot.value;
        if (data == null) return <Deal>[];
        final map = Map<dynamic, dynamic>.from(data as Map);
        return map.entries
            .map((e) => Deal.fromMap(e.key, Map<dynamic, dynamic>.from(e.value)))
            .toList();
      }).listen((deals) {
        latestDeals = deals;
        emitIfReady();
      }, onError: controller.addError);

      streamAllBusinesses().listen((businesses) {
        eligibleBusinessIds = businesses
            .where((b) => b.verified && b.isOpen)
            .map((b) => b.id)
            .toSet();
        emitIfReady();
      }, onError: controller.addError);
    };

    return controller.stream;
  }

  // ---------------- SAVED ADDRESSES ----------------
  //
  // A customer's saved delivery addresses (Home, Work, etc.) — stored per
  // user, always map-pinned via LocationPickerScreen rather than typed.

  Future<void> addSavedAddress(String uid, SavedAddress address) async {
    await _db
        .child('saved_addresses')
        .child(uid)
        .child(address.id)
        .set(address.toMap());
  }

  Future<void> deleteSavedAddress(String uid, String addressId) async {
    await _db.child('saved_addresses').child(uid).child(addressId).remove();
  }

  Stream<List<SavedAddress>> streamSavedAddresses(String uid) {
    return _db.child('saved_addresses').child(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <SavedAddress>[];
      final map = Map<dynamic, dynamic>.from(data as Map);
      final addresses = map.entries
          .map((e) =>
              SavedAddress.fromMap(e.key, Map<dynamic, dynamic>.from(e.value)))
          .toList();
      addresses.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return addresses;
    }).asBroadcastStream();
  }

  // ---------------- REVIEWS & RATINGS ----------------

  /// Customer rates a completed order. Updates the business's running
  /// rating total/count via a transaction so concurrent reviews don't race.
  Future<void> submitReview({
    required String businessId,
    required String customerId,
    required String customerName,
    required String orderId,
    required int rating,
    required String comment,
  }) async {
    final reviewId = _uuid.v4();
    final review = Review(
      id: reviewId,
      businessId: businessId,
      customerId: customerId,
      customerName: customerName,
      orderId: orderId,
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
    );

    await _db.child('reviews').child(reviewId).set(review.toMap());
    await _db.child('orders').child(orderId).child('reviewed').set(true);

    final businessRef = _db.child('businesses').child(businessId);
    await businessRef.child('ratingSum').runTransaction((current) {
      final sum = (current as num?)?.toDouble() ?? 0;
      return Transaction.success(sum + rating);
    });
    await businessRef.child('ratingCount').runTransaction((current) {
      final count = (current as int?) ?? 0;
      return Transaction.success(count + 1);
    });
  }

  Stream<List<Review>> streamBusinessReviews(String businessId) {
    return _db
        .child('reviews')
        .orderByChild('businessId')
        .equalTo(businessId)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data == null) return <Review>[];
      final map = Map<dynamic, dynamic>.from(data as Map);
      final reviews = map.entries
          .map(
              (e) => Review.fromMap(e.key, Map<dynamic, dynamic>.from(e.value)))
          .toList();
      reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews;
    }).asBroadcastStream();
  }

  // ---------------- NOTIFICATIONS (in-app) ----------------
  //
  // True background push notifications require a server-side trigger
  // (e.g. a Cloud Function watching the database), which needs the paid
  // Blaze plan. As a no-card alternative, this app writes notification
  // entries directly to the relevant user's node whenever a relevant event
  // happens, and the app shows a bell icon + badge that live-updates via
  // a Realtime Database stream. Pickup-time reminders are handled locally
  // on-device instead (see notification_service.dart).

  Future<void> addNotification({
    required String uid,
    required String title,
    required String body,
  }) async {
    final id = _uuid.v4();
    final notification = NotificationItem(
      id: id,
      title: title,
      body: body,
      createdAt: DateTime.now(),
    );
    await _db
        .child('notifications')
        .child(uid)
        .child(id)
        .set(notification.toMap());
  }

  Stream<List<NotificationItem>> streamNotifications(String uid) {
    return _db.child('notifications').child(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <NotificationItem>[];
      final map = Map<dynamic, dynamic>.from(data as Map);
      final items = map.entries
          .map((e) => NotificationItem.fromMap(
              e.key, Map<dynamic, dynamic>.from(e.value)))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    }).asBroadcastStream();
  }

  Future<void> markNotificationRead(String uid, String notificationId) async {
    await _db
        .child('notifications')
        .child(uid)
        .child(notificationId)
        .child('read')
        .set(true);
  }

  // ---------------- IMPACT STATS ----------------

  Future<void> _incrementImpactStats() async {
    final ref = _db.child('stats').child('global').child('mealsRescued');
    await ref.runTransaction((current) {
      final count = (current as int?) ?? 0;
      return Transaction.success(count + 1);
    });
  }

  /// Emits {mealsRescued, kgCo2Saved} every time the global counter changes.
  Stream<Map<String, num>> streamGlobalImpact() {
    return _db
        .child('stats')
        .child('global')
        .child('mealsRescued')
        .onValue
        .map((event) {
      final meals = (event.snapshot.value as int?) ?? 0;
      return {
        'mealsRescued': meals,
        'kgCo2Saved': meals * kgCo2PerMeal,
      };
    }).asBroadcastStream();
  }

  // ---------------- CART CHECKOUT ----------------
  //
  // The cart itself (CartService) only lives in memory on the device — it
  // is never written to the database. Checking out walks the cart and
  // creates the same FoodOrder documents the existing single-item
  // reserve/order flows already create (via createOrder / createMenuOrder),
  // so every other screen (My Orders, business Orders tab, QR pickup scan,
  // ratings, notifications) works with cart-originated orders exactly as it
  // already does — nothing downstream needed to change.
  //
  // Cart can mix items from multiple businesses in one checkout. Since each
  // business fulfils pickup/delivery independently, one flat delivery fee
  // is charged PER BUSINESS (not per item, not per cart) when orderType is
  // 'delivery' — that per-business fee is then split evenly across that
  // business's order records purely so each individual order's totalPrice
  // is still meaningful on its own, matching how MenuItemDetailScreen
  // already spreads a flat fee across quantity > 1 today.
  //
  // Surprise Bag stock is re-checked against the live database immediately
  // before each unit is ordered (the CartItem's cached maxQuantity can be
  // stale if someone else bought bags in the meantime), so checkout can
  // partially succeed. Anything that couldn't be ordered is reported back
  // via CartCheckoutResult.failedItemNames instead of throwing.
  Future<CartCheckoutResult> checkoutCart({
    required List<CartItem> items,
    required String customerId,
    required String customerName,
    required String orderType,
    String? deliveryAddress,
    double deliveryFeePerBusiness = 100,
    String? customerPhone,
    double? deliveryLat,
    double? deliveryLng,
  }) async {
    final createdOrders = <FoodOrder>[];
    final failedItemNames = <String>[];

    final byBusiness = <String, List<CartItem>>{};
    for (final item in items) {
      byBusiness.putIfAbsent(item.businessId, () => []).add(item);
    }

    for (final businessItems in byBusiness.values) {
      final totalUnits =
          businessItems.fold<int>(0, (sum, i) => sum + i.quantity);
      if (totalUnits == 0) continue;

      // Spread this business's one flat delivery fee evenly across every
      // unit ordered from them in this checkout.
      final perUnitDeliveryFee =
          orderType == 'delivery' ? deliveryFeePerBusiness / totalUnits : 0.0;

      for (final cartItem in businessItems) {
        for (var i = 0; i < cartItem.quantity; i++) {
          try {
            if (cartItem.isSurplus) {
              final listing = await getListingById(cartItem.itemId);
              if (listing == null ||
                  listing.status != 'active' ||
                  listing.quantityAvailable <= 0 ||
                  listing.isExpired) {
                failedItemNames.add(cartItem.name);
                break; // don't keep trying further units of a sold-out bag
              }

              final order = await createOrder(
                listing: listing,
                customerId: customerId,
                customerName: customerName,
                orderType: orderType,
                deliveryAddress:
                    orderType == 'delivery' ? deliveryAddress : null,
                deliveryFee: perUnitDeliveryFee,
                customerPhone: customerPhone,
                deliveryLat: deliveryLat,
                deliveryLng: deliveryLng,
              );
              createdOrders.add(order);
            } else {
              final menuItem = await getMenuItemById(cartItem.itemId);
              if (menuItem == null || !menuItem.available) {
                failedItemNames.add(cartItem.name);
                break;
              }

              final order = await createMenuOrder(
                item: menuItem,
                customerId: customerId,
                customerName: customerName,
                orderType: orderType,
                deliveryAddress:
                    orderType == 'delivery' ? deliveryAddress : null,
                deliveryFee: perUnitDeliveryFee,
                customerPhone: customerPhone,
                deliveryLat: deliveryLat,
                deliveryLng: deliveryLng,
              );
              createdOrders.add(order);
            }
          } catch (_) {
            failedItemNames.add(cartItem.name);
            break;
          }
        }
      }
    }

    return CartCheckoutResult(
        orders: createdOrders, failedItemNames: failedItemNames);
  }

// ---------------- FAVORITES ----------------
  //
  // Customers can favorite businesses (not individual listings/menu items)
  // for quick access later — stored as a simple uid -> {businessId: true}
  // map, kept separate from the businesses collection itself.

  Future<void> setFavorite(
      String uid, String businessId, bool isFavorite) async {
    final ref = _db.child('favorites').child(uid).child(businessId);
    if (isFavorite) {
      await ref.set(true);
    } else {
      await ref.remove();
    }
  }

  /// Live set of business IDs the given user has favorited — cheap to use
  /// for showing a filled/outline heart icon anywhere in the UI.
  Stream<Set<String>> streamFavoriteBusinessIds(String uid) {
    return _db.child('favorites').child(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <String>{};
      final map = Map<dynamic, dynamic>.from(data as Map);
      return map.keys.map((k) => k.toString()).toSet();
    }).asBroadcastStream();
  }

  /// Full Business objects for everything the user has favorited, live —
  /// combines the favorite-IDs stream with the all-businesses stream
  /// client-side, same join pattern used by streamVerifiedActiveListings.
  Stream<List<Business>> streamFavoriteBusinesses(String uid) {
    final controller = StreamController<List<Business>>.broadcast();
    Set<String>? favoriteIds;
    List<Business>? allBusinesses;
    StreamSubscription? favSub;
    StreamSubscription? businessesSub;

    void emitIfReady() {
      if (favoriteIds != null && allBusinesses != null) {
        controller.add(
          allBusinesses!.where((b) => favoriteIds!.contains(b.id)).toList(),
        );
      }
    }

    controller.onListen = () {
      favSub = streamFavoriteBusinessIds(uid).listen((ids) {
        favoriteIds = ids;
        emitIfReady();
      }, onError: controller.addError);

      businessesSub = streamAllBusinesses().listen((businesses) {
        allBusinesses = businesses;
        emitIfReady();
      }, onError: controller.addError);
    };

    controller.onCancel = () {
      favSub?.cancel();
      businessesSub?.cancel();
    };

    return controller.stream;
  }

  // ---------------- ITEM FAVORITES (product-level) ----------------
  //
  // Separate from business favorites above — this lets a customer favorite
  // a specific product card (a Surprise Bag listing or a regular menu
  // item), shown as a heart on the card itself. Both listing IDs and menu
  // item IDs are stored in the same 'itemFavorites' node since UUIDs don't
  // collide between the two collections.

  Future<void> setItemFavorite(
      String uid, String itemId, bool isFavorite) async {
    final ref = _db.child('itemFavorites').child(uid).child(itemId);
    if (isFavorite) {
      await ref.set(true);
    } else {
      await ref.remove();
    }
  }

  /// Live set of item IDs (listings or menu items) the user has favorited —
  /// used to show a filled/outline heart on any product card.
  Stream<Set<String>> streamFavoriteItemIds(String uid) {
    return _db.child('itemFavorites').child(uid).onValue.map((event) {
      final data = event.snapshot.value;
      if (data == null) return <String>{};
      final map = Map<dynamic, dynamic>.from(data as Map);
      return map.keys.map((k) => k.toString()).toSet();
    }).asBroadcastStream();
  }

  /// Full FoodListing objects the user has favorited that are still active —
  /// a favorited bag that sold out or expired quietly drops off the list.
  Stream<List<FoodListing>> streamFavoriteListings(String uid) {
    final controller = StreamController<List<FoodListing>>.broadcast();
    Set<String>? favoriteIds;
    List<FoodListing>? allListings;
    StreamSubscription? favSub;
    StreamSubscription? listingsSub;

    void emitIfReady() {
      if (favoriteIds != null && allListings != null) {
        controller.add(
            allListings!.where((l) => favoriteIds!.contains(l.id)).toList());
      }
    }

    controller.onListen = () {
      favSub = streamFavoriteItemIds(uid).listen((ids) {
        favoriteIds = ids;
        emitIfReady();
      }, onError: controller.addError);
      listingsSub = streamActiveListings().listen((listings) {
        allListings = listings;
        emitIfReady();
      }, onError: controller.addError);
    };

    controller.onCancel = () {
      favSub?.cancel();
      listingsSub?.cancel();
    };

    return controller.stream;
  }

  /// Full MenuItem objects the user has favorited (from verified businesses,
  /// still marked available).
  Stream<List<MenuItem>> streamFavoriteMenuItems(String uid) {
    final controller = StreamController<List<MenuItem>>.broadcast();
    Set<String>? favoriteIds;
    List<MenuItem>? allItems;
    StreamSubscription? favSub;
    StreamSubscription? itemsSub;

    void emitIfReady() {
      if (favoriteIds != null && allItems != null) {
        controller
            .add(allItems!.where((i) => favoriteIds!.contains(i.id)).toList());
      }
    }

    controller.onListen = () {
      favSub = streamFavoriteItemIds(uid).listen((ids) {
        favoriteIds = ids;
        emitIfReady();
      }, onError: controller.addError);
      itemsSub = streamVerifiedMenuItems().listen((items) {
        allItems = items;
        emitIfReady();
      }, onError: controller.addError);
    };

    controller.onCancel = () {
      favSub?.cancel();
      itemsSub?.cancel();
    };

    return controller.stream;
  }
}
