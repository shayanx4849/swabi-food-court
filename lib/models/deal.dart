/// A business-managed promotional discount on one of their existing menu
/// items — e.g. "50% off Zinger Burger until March 20". Distinct from the
/// Surprise Bag / surplus-listing system (which exists specifically for
/// food-waste reduction, with a strict pickup window): a Deal is a normal
/// marketing promotion the business creates, edits, and deletes manually
/// whenever they like. The only date involved is the expiry the business
/// themselves picks — there's no forced pickup window and no automatic
/// "surplus" framing.
class Deal {
  final String id;
  final String businessId;
  final String businessName;
  final String menuItemId;
  final String menuItemName;
  final String? imageUrl;
  final double originalPrice;
  final double discountPercent; // 0-100
  final DateTime expiryDate;
  final bool active; // lets the business pause a deal without deleting it
  final DateTime createdAt;

  Deal({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.menuItemId,
    required this.menuItemName,
    required this.originalPrice,
    required this.discountPercent,
    required this.expiryDate,
    required this.createdAt,
    this.imageUrl,
    this.active = true,
  });

  double get discountedPrice =>
      (originalPrice * (1 - discountPercent / 100)).clamp(0, originalPrice).toDouble();

  bool get isExpired => DateTime.now().isAfter(expiryDate);

  /// Whether this deal should actually be shown/orderable right now.
  bool get isLive => active && !isExpired;

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'businessName': businessName,
      'menuItemId': menuItemId,
      'menuItemName': menuItemName,
      'imageUrl': imageUrl,
      'originalPrice': originalPrice,
      'discountPercent': discountPercent,
      'expiryDate': expiryDate.toIso8601String(),
      'active': active,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Deal.fromMap(String id, Map<dynamic, dynamic> map) {
    return Deal(
      id: id,
      businessId: map['businessId'] ?? '',
      businessName: map['businessName'] ?? '',
      menuItemId: map['menuItemId'] ?? '',
      menuItemName: map['menuItemName'] ?? '',
      imageUrl: map['imageUrl'],
      originalPrice: (map['originalPrice'] ?? 0).toDouble(),
      discountPercent: (map['discountPercent'] ?? 0).toDouble(),
      expiryDate: DateTime.tryParse(map['expiryDate'] ?? '') ?? DateTime.now(),
      active: map['active'] ?? true,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Deal copyWith({
    double? discountPercent,
    DateTime? expiryDate,
    bool? active,
  }) {
    return Deal(
      id: id,
      businessId: businessId,
      businessName: businessName,
      menuItemId: menuItemId,
      menuItemName: menuItemName,
      imageUrl: imageUrl,
      originalPrice: originalPrice,
      discountPercent: discountPercent ?? this.discountPercent,
      expiryDate: expiryDate ?? this.expiryDate,
      active: active ?? this.active,
      createdAt: createdAt,
    );
  }
}
