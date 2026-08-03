import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../services/cart_service.dart';
import '../../models/listing.dart';
import '../../models/business.dart';
import '../../models/cart_item.dart';
import '../../widgets/star_rating.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/mini_map_view.dart';
import '../shared/location_picker_screen.dart';
import 'qr_display_screen.dart';
import 'cart_screen.dart';

/// Shows full details of a single surplus food listing and lets the
/// customer reserve it. On success, navigates to the QR display screen.
class ListingDetailScreen extends StatefulWidget {
  final FoodListing listing;
  const ListingDetailScreen({super.key, required this.listing});

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final _authService = AuthService();
  final _databaseService = DatabaseService();
  final _cart = CartService.instance;
  final _phoneCtrl = TextEditingController();
  bool _reserving = false;
  Business? _business;
  String _orderType = 'pickup'; // 'pickup' or 'delivery'

  // Delivery destination — set ONLY via the map picker, since most
  // addresses here don't have house numbers for a delivery person to go by.
  PickedLocation? _pickedLocation;

  static const double deliveryFee =
      100; // flat fee — no distance-based pricing in this MVP

  Future<void> _pickDeliveryLocation() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null) setState(() => _pickedLocation = result);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _addToCart() {
    final l = widget.listing;
    final addedQty = _cart.addItem(CartItem(
      sourceType: 'surplus',
      itemId: l.id,
      businessId: l.businessId,
      businessName: l.businessName,
      name: l.title,
      price: l.price,
      imageUrl: l.imageUrl,
      quantity: 1,
      maxQuantity: l.quantityAvailable,
      pickupStart: l.pickupStart,
      pickupEnd: l.pickupEnd,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          addedQty > 0
              ? 'Added "${l.title}" to cart'
              : 'Only ${l.quantityAvailable} left — already in your cart',
        ),
        action: SnackBarAction(
          label: 'View cart',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CartScreen()),
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadBusiness();
  }

  Future<void> _loadBusiness() async {
    final business =
        await _databaseService.getBusinessById(widget.listing.businessId);
    if (mounted) setState(() => _business = business);
  }

  Future<void> _reserve() async {
    if (_orderType == 'delivery') {
      if (_pickedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please pin your delivery location on the map.')),
        );
        return;
      }
      if (_phoneCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Please enter a phone number so the business can reach you.')),
        );
        return;
      }
    }

    setState(() => _reserving = true);
    try {
      final firebaseUser = _authService.currentUser!;
      final profile = await _authService.getUserProfile(firebaseUser.uid);

      final order = await _databaseService.createOrder(
        listing: widget.listing,
        customerId: firebaseUser.uid,
        customerName: profile?.name ?? 'Customer',
        orderType: _orderType,
        deliveryAddress:
            _orderType == 'delivery' ? _pickedLocation!.address : null,
        deliveryFee: _orderType == 'delivery' ? deliveryFee : 0,
        customerPhone: _orderType == 'delivery' ? _phoneCtrl.text.trim() : null,
        deliveryLat: _orderType == 'delivery' ? _pickedLocation!.lat : null,
        deliveryLng: _orderType == 'delivery' ? _pickedLocation!.lng : null,
      );

      // Pickup reminders only make sense for pickup orders — a delivery
      // order has no pickup window for the customer to show up for.
      if (_orderType == 'pickup') {
        await NotificationService.schedulePickupReminder(
          notificationId: order.id.hashCode,
          listingTitle: widget.listing.title,
          businessName: widget.listing.businessName,
          pickupEnd: widget.listing.pickupEnd,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => QrDisplayScreen(order: order)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not reserve — it may be sold out.')),
        );
      }
    } finally {
      if (mounted) setState(() => _reserving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('EEEE, d MMMM');
    final soldOut = l.quantityAvailable <= 0 || l.status != 'active';
    final discountPercent = l.originalPrice > 0
        ? (((l.originalPrice - l.price) / l.originalPrice) * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ---- Hero image ----
              SliverAppBar(
                pinned: false,
                stretch: true,
                expandedHeight: 280,
                backgroundColor: Colors.green.shade50,
                automaticallyImplyLeading: false,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      l.imageUrl != null
                          ? Image.network(
                              l.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholderImage(),
                            )
                          : _placeholderImage(),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black26, Colors.transparent],
                            stops: [0, 0.3],
                          ),
                        ),
                      ),
                      if (soldOut)
                        Container(
                          color: Colors.black45,
                          alignment: Alignment.center,
                          child: const Text(
                            'SOLD OUT',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 26,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // ---- Content sheet ----
              SliverToBoxAdapter(
                child: Container(
                  transform: Matrix4.translationValues(0, -20, 0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Business row
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.green.shade50,
                            child: Icon(Icons.storefront,
                                size: 18, color: Colors.green.shade700),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.businessName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          if (!soldOut && discountPercent > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$discountPercent% OFF',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),

                      // Rating row (only shows once the business loads)
                      if (_business != null && _business!.ratingCount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            StarRating(
                                rating: _business!.averageRating.round(),
                                size: 15),
                            const SizedBox(width: 6),
                            Text(
                              '${_business!.averageRating.toStringAsFixed(1)} '
                              '(${_business!.ratingCount} review${_business!.ratingCount == 1 ? '' : 's'})',
                              style: TextStyle(
                                  fontSize: 12.5, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),

                      Text(
                        l.title,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),

                      if (l.description.isNotEmpty) ...[
                        Text(
                          l.description,
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              height: 1.4),
                        ),
                        const SizedBox(height: 20),
                      ] else
                        const SizedBox(height: 6),

                      // Info chips
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _infoChip(
                            icon: Icons.calendar_today_outlined,
                            label: dateFormat.format(l.pickupStart),
                          ),
                          _infoChip(
                            icon: Icons.access_time,
                            label:
                                '${timeFormat.format(l.pickupStart)} - ${timeFormat.format(l.pickupEnd)}',
                          ),
                          _infoChip(
                            icon: Icons.inventory_2_outlined,
                            label: soldOut
                                ? 'Sold out'
                                : '${l.quantityAvailable} bag${l.quantityAvailable == 1 ? '' : 's'} left',
                            highlight: !soldOut && l.quantityAvailable <= 2,
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // ---- Pickup vs Delivery ----
                      if (!soldOut) ...[
                        _sectionLabel('How would you like to get it?'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _orderTypeCard(
                                icon: Icons.storefront,
                                label: 'Pickup',
                                subtitle: 'Free',
                                selected: _orderType == 'pickup',
                                onTap: () =>
                                    setState(() => _orderType = 'pickup'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _orderTypeCard(
                                icon: Icons.delivery_dining,
                                label: 'Delivery',
                                subtitle:
                                    'Rs. ${deliveryFee.toStringAsFixed(0)}',
                                selected: _orderType == 'delivery',
                                onTap: () =>
                                    setState(() => _orderType = 'delivery'),
                              ),
                            ),
                          ],
                        ),
                        if (_orderType == 'delivery') ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: Icon(_pickedLocation == null
                                ? Icons.map_outlined
                                : Icons.edit_location_alt),
                            label: Text(_pickedLocation == null
                                ? 'Pin delivery location on map'
                                : 'Change delivery location'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 50),
                              foregroundColor: Colors.green.shade700,
                              side: BorderSide(color: Colors.green.shade700),
                            ),
                            onPressed: _pickDeliveryLocation,
                          ),
                          if (_pickedLocation != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.place,
                                      size: 15, color: Colors.green.shade700),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _pickedLocation!.address,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green.shade900),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone number',
                              hintText: '03xx-xxxxxxx',
                              prefixIcon:
                                  const Icon(Icons.call_outlined, size: 20),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'No live tracking yet — the business will contact you to arrange drop-off.',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey.shade500),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 22),
                      ],

                      // ---- Pickup location ----
                      if (_business != null &&
                          _business!.address.isNotEmpty) ...[
                        _sectionLabel('Pickup location'),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _business!.address,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.grey.shade700,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                        if (_business!.lat != 0 || _business!.lng != 0) ...[
                          const SizedBox(height: 10),
                          MiniMapView(
                              lat: _business!.lat,
                              lng: _business!.lng,
                              height: 130),
                        ],
                        const SizedBox(height: 22),
                      ],

                      // ---- Environmental impact of this order ----
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.green.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.eco,
                                color: Colors.green.shade700, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Reserving this bag rescues one meal and saves '
                                '≈${DatabaseService.kgCo2PerMeal.toStringAsFixed(1)} kg of CO₂ from going to waste.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.green.shade800,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'This is a "Surprise Bag" — exact contents may vary based on '
                              'what surplus food is available at pickup time.',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade600,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ---- Floating back button ----
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: _circleButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          // ---- Floating cart button ----
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: Container(
              decoration: const BoxDecoration(
                  color: Colors.black38, shape: BoxShape.circle),
              child: Theme(
                data: Theme.of(context).copyWith(
                    iconTheme: const IconThemeData(color: Colors.white)),
                child: const CartButton(),
              ),
            ),
          ),

          // ---- Sticky bottom price + reserve bar ----
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!soldOut)
                        Text(
                          'Rs. ${l.originalPrice.toStringAsFixed(0)}',
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      Text(
                        soldOut
                            ? 'Sold out'
                            : 'Rs. ${(_orderType == 'delivery' ? l.price + deliveryFee : l.price).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: soldOut ? Colors.grey : Colors.green.shade700,
                        ),
                      ),
                      if (!soldOut && _orderType == 'delivery')
                        Text(
                          'incl. Rs. ${deliveryFee.toStringAsFixed(0)} delivery',
                          style: TextStyle(
                              fontSize: 10.5, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                  const Spacer(),
                  if (!soldOut) ...[
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(color: Colors.green.shade700),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _addToCart,
                        child: const Icon(Icons.add_shopping_cart, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: (soldOut || _reserving) ? null : _reserve,
                      child: _reserving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              soldOut ? 'Sold out' : 'Reserve bag',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: Colors.green.shade50,
      alignment: Alignment.center,
      child: Icon(Icons.eco, size: 64, color: Colors.green.shade300),
    );
  }

  Widget _orderTypeCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.green.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.green.shade700 : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22,
                color: selected ? Colors.green.shade700 : Colors.grey.shade600),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.green.shade800 : Colors.grey.shade800,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.6,
        color: Colors.grey.shade500,
      ),
    );
  }

  Widget _infoChip(
      {required IconData icon, required String label, bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? Colors.orange.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: highlight ? Border.all(color: Colors.orange.shade200) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 15,
              color: highlight ? Colors.orange.shade800 : Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.orange.shade800 : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
