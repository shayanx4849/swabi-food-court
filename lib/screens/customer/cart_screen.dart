import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../services/cart_service.dart';
import '../../models/cart_item.dart';
import '../shared/location_picker_screen.dart';
import 'cart_checkout_summary_screen.dart';

/// Lets the customer review everything they've added to the cart — possibly
/// spanning multiple businesses and mixing regular menu items with
/// Surprise Bags — adjust quantities, pick Pickup or Delivery for the whole
/// order, and check out.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _cart = CartService.instance;
  final _authService = AuthService();
  final _databaseService = DatabaseService();
  final _phoneCtrl = TextEditingController();

  String _orderType = 'pickup';
  bool _checkingOut = false;

  // Delivery destination — set ONLY via the map picker, same reasoning as
  // business signup: most addresses here don't have house numbers, so a
  // real GPS pin (not a typed guess) is what actually gets someone there.
  PickedLocation? _pickedLocation;

  static const double deliveryFeePerBusiness = 100;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeliveryLocation() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null) setState(() => _pickedLocation = result);
  }

  double get _deliveryTotal => _orderType == 'delivery'
      ? deliveryFeePerBusiness * _cart.businessCount
      : 0;

  double get _grandTotal => _cart.subtotal + _deliveryTotal;

  Future<void> _checkout() async {
    if (_orderType == 'delivery') {
      if (_pickedLocation == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please pin your delivery location on the map.')),
        );
        return;
      }
      if (_phoneCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a phone number so the business can reach you.')),
        );
        return;
      }
    }

    setState(() => _checkingOut = true);
    try {
      final firebaseUser = _authService.currentUser!;
      final profile = await _authService.getUserProfile(firebaseUser.uid);
      final cartItemsSnapshot = List<CartItem>.from(_cart.items);

      final result = await _databaseService.checkoutCart(
        items: cartItemsSnapshot,
        customerId: firebaseUser.uid,
        customerName: profile?.name ?? 'Customer',
        orderType: _orderType,
        deliveryAddress: _orderType == 'delivery' ? _pickedLocation!.address : null,
        deliveryFeePerBusiness: deliveryFeePerBusiness,
        customerPhone: _orderType == 'delivery' ? _phoneCtrl.text.trim() : null,
        deliveryLat: _orderType == 'delivery' ? _pickedLocation!.lat : null,
        deliveryLng: _orderType == 'delivery' ? _pickedLocation!.lng : null,
      );

      // Schedule pickup reminders for whichever surplus/pickup orders were
      // actually created — same behaviour as the direct single-item
      // reserve flow in ListingDetailScreen.
      if (_orderType == 'pickup') {
        for (final cartItem in cartItemsSnapshot) {
          if (!cartItem.isSurplus || cartItem.pickupEnd == null) continue;
          final matchingOrder = result.orders
              .where((o) => o.listingId == cartItem.itemId)
              .toList();
          for (final order in matchingOrder) {
            await NotificationService.schedulePickupReminder(
              notificationId: order.id.hashCode,
              listingTitle: cartItem.name,
              businessName: cartItem.businessName,
              pickupEnd: cartItem.pickupEnd!,
            );
          }
        }
      }

      // Only clear items that actually succeeded — leave failed ones in the
      // cart so the customer can see and deal with them.
      final failedKeys = <String>{};
      for (final name in result.failedItemNames) {
        final match = cartItemsSnapshot.where((c) => c.name == name);
        if (match.isNotEmpty) failedKeys.add(match.first.key);
      }
      for (final item in cartItemsSnapshot) {
        if (!failedKeys.contains(item.key)) _cart.removeItem(item.key);
      }

      if (!mounted) return;

      if (result.orders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Checkout failed — those items are no longer available.')),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => CartCheckoutSummaryScreen(result: result)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not check out: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _cart,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Your cart'),
            actions: [
              if (_cart.isNotEmpty)
                TextButton(
                  onPressed: () => _cart.clear(),
                  child: const Text('Clear',
                      style: TextStyle(color: Colors.white)),
                ),
            ],
          ),
          body: _cart.isEmpty
              ? _emptyState(context)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 220),
                  children: [
                    for (final entry in _cart.itemsByBusiness.entries)
                      _businessGroup(entry.key, entry.value),
                  ],
                ),
          bottomNavigationBar: _cart.isEmpty ? null : _checkoutBar(),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Your cart is empty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Add a menu item or Surprise Bag to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Browse food'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _businessGroup(String businessId, List<CartItem> items) {
    final businessName = items.first.businessName;
    final businessSubtotal =
        items.fold<double>(0, (sum, i) => sum + i.subtotal);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.storefront, size: 18, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(businessName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 20),
            for (final item in items) _cartItemRow(item),
            const Divider(height: 20),
            Row(
              children: [
                const Text('Subtotal', style: TextStyle(color: Colors.grey)),
                const Spacer(),
                Text('Rs. ${businessSubtotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            if (_orderType == 'delivery') ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Text('Delivery fee',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12.5)),
                  const Spacer(),
                  Text('Rs. ${deliveryFeePerBusiness.toStringAsFixed(0)}',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12.5)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cartItemRow(CartItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.imageUrl != null
                ? Image.network(item.imageUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _itemPlaceholder(item))
                : _itemPlaceholder(item),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('Rs. ${item.price.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600)),
                    if (item.isSurplus) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Surprise Bag',
                            style: TextStyle(
                                fontSize: 9.5, color: Colors.orange.shade800)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          _quantityStepper(item),
        ],
      ),
    );
  }

  Widget _quantityStepper(CartItem item) {
    final atMax = item.maxQuantity > 0 && item.quantity >= item.maxQuantity;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(
              item.quantity <= 1
                  ? Icons.delete_outline
                  : Icons.remove_circle_outline,
              size: 20,
              color: item.quantity <= 1 ? Colors.red.shade400 : null),
          onPressed: () => _cart.decrementQuantity(item.key),
        ),
        Text('${item.quantity}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: atMax ? null : () => _cart.incrementQuantity(item.key),
        ),
      ],
    );
  }

  Widget _itemPlaceholder(CartItem item) {
    return Container(
      width: 48,
      height: 48,
      color: item.isSurplus ? Colors.orange.shade50 : Colors.green.shade50,
      child: Icon(item.isSurplus ? Icons.eco : Icons.restaurant_menu,
          size: 20,
          color:
              item.isSurplus ? Colors.orange.shade300 : Colors.green.shade300),
    );
  }

  Widget _checkoutBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, -3))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- Pickup vs Delivery ----
            Row(
              children: [
                Expanded(
                  child: _orderTypeChip(
                    icon: Icons.storefront,
                    label: 'Pickup',
                    selected: _orderType == 'pickup',
                    onTap: () => setState(() => _orderType = 'pickup'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _orderTypeChip(
                    icon: Icons.delivery_dining,
                    label: 'Delivery',
                    selected: _orderType == 'delivery',
                    onTap: () => setState(() => _orderType = 'delivery'),
                  ),
                ),
              ],
            ),
            if (_orderType == 'delivery') ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: Icon(_pickedLocation == null
                    ? Icons.map_outlined
                    : Icons.edit_location_alt),
                label: Text(_pickedLocation == null
                    ? 'Pin delivery location on map'
                    : 'Change delivery location'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                      Icon(Icons.place, size: 15, color: Colors.green.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _pickedLocation!.address,
                          style: TextStyle(fontSize: 12, color: Colors.green.shade900),
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
                  prefixIcon: const Icon(Icons.call_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'So the business can reach you if they can\'t find the pin.',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 6),
              Text(
                '${_cart.businessCount} business${_cart.businessCount == 1 ? '' : 'es'} × '
                'Rs. ${deliveryFeePerBusiness.toStringAsFixed(0)} delivery fee',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${_cart.totalItemCount} item${_cart.totalItemCount == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.grey.shade600)),
                    Text('Rs. ${_grandTotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                  ),
                  onPressed: _checkingOut ? null : _checkout,
                  child: _checkingOut
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Checkout'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderTypeChip({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.green.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? Colors.green.shade700 : Colors.transparent,
              width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? Colors.green.shade700 : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? Colors.green.shade800
                        : Colors.grey.shade800)),
          ],
        ),
      ),
    );
  }
}
