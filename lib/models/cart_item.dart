/// One line in the customer's shopping cart.
///
/// A cart can hold items from multiple businesses and mix both kinds of
/// products the app sells:
///  - 'menu'    -> a regular MenuItem (no stock cap, always available)
///  - 'surplus' -> a discounted FoodListing "Surprise Bag" (capped by
///                 [maxQuantity], and carries a pickup window so a reminder
///                 can still be scheduled after checkout)
///
/// This lives only in memory on the device (see CartService) — it is not
/// itself written to Realtime Database. Only the FoodOrder documents that
/// checkout eventually creates are persisted.
class CartItem {
  final String sourceType; // 'menu' or 'surplus'
  final String itemId; // menuItemId or listingId
  final String businessId;
  final String businessName;
  final String name;
  final double price;
  final String? imageUrl;
  int quantity;

  /// Upper bound on quantity. For menu items this is a large effectively
  /// "unlimited" number; for surplus bags it mirrors the listing's
  /// quantityAvailable at the time it was added (best-effort — checkout
  /// re-validates against the live value before actually placing orders).
  final int maxQuantity;

  // Only meaningful for surplus items — used to schedule a pickup reminder
  // after checkout, same as the direct-reserve flow does.
  final DateTime? pickupStart;
  final DateTime? pickupEnd;

  CartItem({
    required this.sourceType,
    required this.itemId,
    required this.businessId,
    required this.businessName,
    required this.name,
    required this.price,
    required this.maxQuantity,
    this.imageUrl,
    this.quantity = 1,
    this.pickupStart,
    this.pickupEnd,
  });

  bool get isSurplus => sourceType == 'surplus';
  bool get isMenu => sourceType == 'menu';
  double get subtotal => price * quantity;

  /// Unique key within the cart — same product from the same business can
  /// only ever appear as a single line with a quantity, never duplicated.
  String get key => '$sourceType:$itemId';
}
