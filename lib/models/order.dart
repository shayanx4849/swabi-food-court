class FoodOrder {
  final String id;
  final String listingId;
  final String businessId;
  final String businessName;
  final String listingTitle;
  final String customerId;
  final String customerName;
  final double price;
  final String qrCode; // encodes the order id
  final String status; // pending, completed, cancelled
  final DateTime createdAt;
  final bool reviewed;

  /// "pickup" (default) or "delivery". Delivery has no rider/tracking in
  /// this MVP — the business arranges delivery themselves (in person or via
  /// their own courier) and marks the order delivered manually from their
  /// Orders tab, since there's no QR handoff to scan for an off-site drop.
  final String orderType;
  final String? deliveryAddress; // only set when orderType == 'delivery'
  final double deliveryFee;

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
  });

  bool get isDelivery => orderType == 'delivery';
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
    );
  }
}
