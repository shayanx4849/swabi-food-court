import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/deal.dart';
import '../../models/order.dart';
import '../shared/location_picker_screen.dart';
import '../shared/saved_address_picker.dart';
import 'qr_display_screen.dart';

/// Ordering screen for a business Deal — a discounted price on one of
/// their existing menu items. Unlike Surprise Bags, there's no pickup
/// window; the deal simply stops being orderable once the business's own
/// chosen expiry date passes or they pause/delete it.
class DealDetailScreen extends StatefulWidget {
  final Deal deal;
  const DealDetailScreen({super.key, required this.deal});

  @override
  State<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends State<DealDetailScreen> {
  final _authService = AuthService();
  final _databaseService = DatabaseService();
  final _phoneCtrl = TextEditingController();

  int _quantity = 1;
  String _orderType = 'pickup';
  bool _ordering = false;

  // Delivery destination — set ONLY via the map picker, since most
  // addresses here don't have house numbers for a delivery person to go by.
  PickedLocation? _pickedLocation;

  static const double deliveryFee = 100;

  double get _totalPrice =>
      (widget.deal.discountedPrice * _quantity) +
      (_orderType == 'delivery' ? deliveryFee : 0);

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDeliveryLocation() async {
    final result = await showSavedAddressPicker(context);
    if (result != null) setState(() => _pickedLocation = result);
  }

  Future<void> _placeOrder() async {
    final deal = widget.deal;

    if (deal.isExpired || !deal.active) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This deal is no longer available.')),
      );
      return;
    }

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
      // Re-check the underlying menu item is still there and available —
      // the deal's cached name/price can be stale if the business edited
      // the item since creating the deal.
      final menuItem = await _databaseService.getMenuItemById(deal.menuItemId);
      if (menuItem == null || !menuItem.available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This item is no longer available.')),
          );
        }
        return;
      }

      final business = await _databaseService.getBusinessById(deal.businessId);
      if (business == null || !business.isOpen) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This business is currently closed.')),
          );
        }
        return;
      }

      final firebaseUser = _authService.currentUser!;
      final profile = await _authService.getUserProfile(firebaseUser.uid);

      FoodOrder? placedOrder;
      for (var i = 0; i < _quantity; i++) {
        placedOrder = await _databaseService.createMenuOrder(
          item: menuItem,
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
          priceOverride: deal.discountedPrice,
          dealId: deal.id,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => QrDisplayScreen(order: placedOrder!)),
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
    final deal = widget.deal;
    final canOrder = deal.isLive;

    return Scaffold(
      appBar: AppBar(title: Text(deal.businessName)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (deal.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(deal.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(height: 180, color: Colors.green.shade50)),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(deal.menuItemName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${deal.discountPercent.round()}% OFF',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(deal.businessName,
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Rs. ${deal.originalPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey.shade500,
                      fontSize: 15)),
              const SizedBox(width: 8),
              Text('Rs. ${deal.discountedPrice.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.green.shade700)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.event, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                  'Deal runs until ${deal.expiryDate.day}/${deal.expiryDate.month}/${deal.expiryDate.year}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
          if (!canOrder) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                deal.isExpired
                    ? 'This deal has expired.'
                    : 'This deal is currently paused.',
                style: TextStyle(color: Colors.red.shade800, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          if (canOrder) ...[
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

            // ---- Pickup / Delivery ----
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Pickup'),
                    selected: _orderType == 'pickup',
                    onSelected: (_) => setState(() => _orderType = 'pickup'),
                    backgroundColor: Colors.grey.shade200,
                    selectedColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                            color: _orderType == 'pickup'
                                ? Colors.green.shade700
                                : Colors.grey.shade300)),
                    labelStyle: TextStyle(
                        color: _orderType == 'pickup'
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Delivery'),
                    selected: _orderType == 'delivery',
                    onSelected: (_) => setState(() => _orderType = 'delivery'),
                    backgroundColor: Colors.grey.shade200,
                    selectedColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                            color: _orderType == 'delivery'
                                ? Colors.green.shade700
                                : Colors.grey.shade300)),
                    labelStyle: TextStyle(
                        color: _orderType == 'delivery'
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            if (_orderType == 'delivery') ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: Icon(
                  _pickedLocation == null
                      ? Icons.map_outlined
                      : Icons.edit_location_alt,
                  color: Colors.white,
                ),
                label: Text(
                  _pickedLocation == null
                      ? 'Choose delivery location'
                      : 'Change delivery location',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
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
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
            ],

            const SizedBox(height: 28),
            Row(
              children: [
                Text('Rs. ${_totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                  ),
                  onPressed: _ordering ? null : _placeOrder,
                  child: _ordering
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Order Now'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
