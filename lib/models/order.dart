class FoodOrder {
  final String id;
  final String listingId; // empty for menu orders (see menuItemId instead)
  final String businessId;
  final String businessName;
  final String listingTitle;
  final String customerId;
  final String customerName;
  final double price;
  final String qrCode; // encodes the order id
  final String status; // pending, confirmed, completed, cancelled
  final DateTime createdAt;
  final bool reviewed;

  /// "pickup" (default) or "delivery". Delivery has no rider/tracking in
  /// this MVP — the business arranges delivery themselves (in person or via
  /// their own courier) and marks the order delivered manually from their
  /// Orders tab, since there's no QR handoff to scan for an off-site drop.
  final String orderType;
  final String? deliveryAddress; // only set when orderType == 'delivery'
  final double deliveryFee;

  // Delivery contact info — captured at checkout so the business (or their
  // delivery person) can actually reach the customer and find them, since
  // most addresses here don't have house numbers to go by. Only set when
  // orderType == 'delivery'.
  final String? customerPhone;
  final double? deliveryLat;
  final double? deliveryLng;

  /// "surplus" (default) — a discounted Surprise Bag from FoodListing — or
  /// "menu" — a regular, always-available item ordered from a business's
  /// normal menu (no expiry/pickup-window, no stock limit). Menu orders go
  /// through an extra "confirmed" status: the business explicitly confirms
  /// they've started preparing it, distinct from a surplus order's implicit
  /// pickup-window coordination.
  final String orderSource;
  final String? menuItemId; // set when orderSource == 'menu'
  final String? dealId; // set when this order was placed via a business Deal

  FoodOrder({
    required this.id,
    required this.listingId,
    required this.businessId,
    required this.businessName,
    required this.listingTitle,
    required this.customerId,
    required this.customerName,
    required this.price,
    required this.qrCode,
    required this.status,
    required this.createdAt,
    this.reviewed = false,
    this.orderType = 'pickup',
    this.deliveryAddress,
    this.deliveryFee = 0,
    this.customerPhone,
    this.deliveryLat,
    this.deliveryLng,
    this.orderSource = 'surplus',
    this.menuItemId,
    this.dealId,
  });

  bool get hasDeliveryPin => deliveryLat != null && deliveryLng != null;

  bool get isDelivery => orderType == 'delivery';
  bool get isMenuOrder => orderSource == 'menu';
  double get totalPrice => price + deliveryFee;

  Map<String, dynamic> toMap() {
    return {
      'listingId': listingId,
      'businessId': businessId,
      'businessName': businessName,
      'listingTitle': listingTitle,
      'customerId': customerId,
      'customerName': customerName,
      'price': price,
      'qrCode': qrCode,
      'status': status,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'reviewed': reviewed,
      'orderType': orderType,
      'deliveryAddress': deliveryAddress,
      'deliveryFee': deliveryFee,
      'customerPhone': customerPhone,
      'deliveryLat': deliveryLat,
      'deliveryLng': deliveryLng,
      'orderSource': orderSource,
      'menuItemId': menuItemId,
      'dealId': dealId,
    };
  }

  factory FoodOrder.fromMap(String id, Map<dynamic, dynamic> map) {
    return FoodOrder(
      id: id,
      listingId: map['listingId'] ?? '',
      businessId: map['businessId'] ?? '',
      businessName: map['businessName'] ?? '',
      listingTitle: map['listingTitle'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      qrCode: map['qrCode'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      reviewed: map['reviewed'] ?? false,
      orderType: map['orderType'] ?? 'pickup',
      deliveryAddress: map['deliveryAddress'],
      deliveryFee: (map['deliveryFee'] ?? 0).toDouble(),
      customerPhone: map['customerPhone'],
      deliveryLat: map['deliveryLat'] == null ? null : (map['deliveryLat'] as num).toDouble(),
      deliveryLng: map['deliveryLng'] == null ? null : (map['deliveryLng'] as num).toDouble(),
      orderSource: map['orderSource'] ?? 'surplus',
      menuItemId: map['menuItemId'],
      dealId: map['dealId'],
    );
  }
}
