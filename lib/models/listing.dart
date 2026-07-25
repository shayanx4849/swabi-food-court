class FoodListing {
  final String id;
  final String businessId;
  final String businessName;
  final String title;
  final String description;
  final double price;
  final double originalPrice;
  final int quantityAvailable;
  final DateTime pickupStart;
  final DateTime pickupEnd;
  final String status; // active, sold_out, expired
  final double lat;
  final double lng;
  final String? imageUrl; // Cloudinary URL, nullable

  /// True once the pickup window has passed, even if `status` in the
  /// database still says "active" (there's no server-side scheduler to
  /// flip it automatically, so this is computed on the client instead).
  bool get isExpired => DateTime.now().isAfter(pickupEnd);

  FoodListing({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.title,
    required this.description,
    required this.price,
    required this.originalPrice,
    required this.quantityAvailable,
    required this.pickupStart,
    required this.pickupEnd,
    required this.status,
    required this.lat,
    required this.lng,
    this.imageUrl,
  });

  // Realtime Database has no native Timestamp type — store dates as
  // milliseconds-since-epoch integers instead.
  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'businessName': businessName,
      'title': title,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'quantityAvailable': quantityAvailable,
      'pickupStart': pickupStart.millisecondsSinceEpoch,
      'pickupEnd': pickupEnd.millisecondsSinceEpoch,
      'status': status,
      'lat': lat,
      'lng': lng,
      'imageUrl': imageUrl,
    };
  }

  factory FoodListing.fromMap(String id, Map<dynamic, dynamic> map) {
    return FoodListing(
      id: id,
      businessId: map['businessId'] ?? '',
      businessName: map['businessName'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      originalPrice: (map['originalPrice'] ?? 0).toDouble(),
      quantityAvailable: map['quantityAvailable'] ?? 0,
      pickupStart: DateTime.fromMillisecondsSinceEpoch(map['pickupStart'] ?? 0),
      pickupEnd: DateTime.fromMillisecondsSinceEpoch(map['pickupEnd'] ?? 0),
      status: map['status'] ?? 'active',
      lat: (map['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'],
    );
  }
}
