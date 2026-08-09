import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/cart_service.dart';
import '../../models/menu_item.dart';
import '../../models/cart_item.dart';
import '../../widgets/cart_button.dart';
import '../shared/location_picker_screen.dart';
import '../shared/saved_address_picker.dart';
import 'qr_display_screen.dart';
import 'cart_screen.dart';

/// Ordering screen for a regular menu item — no expiry, no stock limit,
/// customer can order any time. Same Pickup/Delivery choice as surplus
/// listings, and a quantity stepper since menu items aren't one-off bags.
class MenuItemDetailScreen extends StatefulWidget {
  final MenuItem item;
  const MenuItemDetailScreen({super.key, required this.item});

  @override
  State<MenuItemDetailScreen> createState() => _MenuItemDetailScreenState();
}

class _MenuItemDetailScreenState extends State<MenuItemDetailScreen> {
  final _authService = AuthService();
  final _databaseService = DatabaseService();
  final _cart = CartService.instance;
  final _phoneCtrl = TextEditingController();

  int _quantity = 1;
  String _orderType = 'pickup';
  bool _ordering = false;

  // Delivery destination — set ONLY via the map picker, since most
  // addresses here don't have house numbers for a delivery person to go by.
  PickedLocation? _pickedLocation;

  Future<void> _pickDeliveryLocation() async {
    final result = await showSavedAddressPicker(context);
    if (result != null) setState(() => _pickedLocation = result);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  static const double deliveryFee = 100;

  double get _totalPrice =>
      (widget.item.price * _quantity) +
      (_orderType == 'delivery' ? deliveryFee : 0);

  void _addToCart() {
    final item = widget.item;
    _cart.addItem(CartItem(
      sourceType: 'menu',
      itemId: item.id,
      businessId: item.businessId,
      businessName: item.businessName,
      name: item.name,
      price: item.price,
      imageUrl: item.imageUrl,
      quantity: _quantity,
      maxQuantity: 999, // menu items have no stock cap in this MVP
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added $_quantity × ${item.name} to cart'),
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

  Future<void> _placeOrder() async {
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

    setState(() => _ordering = true);
    try {
      final firebaseUser = _authService.currentUser!;
      final profile = await _authService.getUserProfile(firebaseUser.uid);

      // MVP note: quantity > 1 is priced correctly via item.price * quantity
      // above for display, but createMenuOrder() (matching the surplus-order
      // pattern) creates a single order record per tap — placing N separate
      // single-item orders keeps the existing order/QR model unchanged.
      var lastOrder;
      for (var i = 0; i < _quantity; i++) {
        lastOrder = await _databaseService.createMenuOrder(
          item: widget.item,
          customerId: firebaseUser.uid,
          customerName: profile?.name ?? 'Customer',
          orderType: _orderType,
          deliveryAddress:
              _orderType == 'delivery' ? _pickedLocation!.address : null,
          deliveryFee: _orderType == 'delivery' ? deliveryFee / _quantity : 0,
          customerPhone:
              _orderType == 'delivery' ? _phoneCtrl.text.trim() : null,
          deliveryLat: _orderType == 'delivery' ? _pickedLocation!.lat : null,
          deliveryLng: _orderType == 'delivery' ? _pickedLocation!.lng : null,
        );
      }

      if (!mounted || lastOrder == null) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => QrDisplayScreen(order: lastOrder)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not place order: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar:
          AppBar(title: Text(item.businessName), actions: const [CartButton()]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (item.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                item.imageUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 16),
          Text(item.name,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(item.description,
                style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
          ],
          const SizedBox(height: 10),
          Text(
            'Rs. ${item.price.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700),
          ),
          const SizedBox(height: 20),

          // ---- Quantity ----
          Row(
            children: [
              const Text('Quantity',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed:
                    _quantity > 1 ? () => setState(() => _quantity--) : null,
              ),
              Text('$_quantity',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => _quantity++),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),

          // ---- Pickup vs Delivery ----
          const Text('How would you like to get it?',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _orderTypeCard(
                  icon: Icons.storefront,
                  label: 'Pickup',
                  subtitle: 'Free',
                  selected: _orderType == 'pickup',
                  onTap: () => setState(() => _orderType = 'pickup'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _orderTypeCard(
                  icon: Icons.delivery_dining,
                  label: 'Delivery',
                  subtitle: 'Rs. ${deliveryFee.toStringAsFixed(0)}',
                  selected: _orderType == 'delivery',
                  onTap: () => setState(() => _orderType = 'delivery'),
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
                  ? 'Choose delivery location'
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
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade900),
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
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'No time limit — order whenever you like. The business will '
                  'confirm once they start preparing it.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 90), // room above the sticky bar
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rs. ${_totalPrice.toStringAsFixed(0)}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (item.available) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: const Text('Add to Cart'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green.shade700,
                          side: BorderSide(color: Colors.green.shade700),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _addToCart,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed:
                          (item.available && !_ordering) ? _placeOrder : null,
                      child: _ordering
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(item.available ? 'Order Now' : 'Unavailable'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
              width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 22,
                color: selected ? Colors.green.shade700 : Colors.grey.shade600),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: selected
                        ? Colors.green.shade800
                        : Colors.grey.shade800)),
            Text(subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
