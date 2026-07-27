/// A regular, always-available menu item a business sells — separate from
/// the time-limited, discounted "Surprise Bag" surplus listings. No pickup
/// window or expiry; customers can order it any time the business marks it
/// available.
class MenuItem {
  final String id;
  final String businessId;
  final String businessName;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final bool available;

  MenuItem({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    this.available = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'businessName': businessName,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'available': available,
    };
  }

  factory MenuItem.fromMap(String id, Map<dynamic, dynamic> map) {
    return MenuItem(
      id: id,
      businessId: map['businessId'] ?? '',
      businessName: map['businessName'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'],
      available: map['available'] ?? true,
    );
  }
}
