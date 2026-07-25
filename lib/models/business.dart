class Business {
  final String id;
  final String ownerId;
  final String name;
  final String category; // restaurant, bakery, mart
  final String address;
  final double lat;
  final double lng;
  final bool verified;
  final double ratingSum; // sum of all star ratings received
  final int ratingCount; // number of reviews received

  Business({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.category,
    required this.address,
    required this.lat,
    required this.lng,
    this.verified = false,
    this.ratingSum = 0,
    this.ratingCount = 0,
  });

  double get averageRating => ratingCount == 0 ? 0 : ratingSum / ratingCount;

  Map<String, dynamic> toMap() {
    return {
      'ownerId': ownerId,
      'name': name,
      'category': category,
      'address': address,
      'lat': lat,
      'lng': lng,
      'verified': verified,
      'ratingSum': ratingSum,
      'ratingCount': ratingCount,
    };
  }

  factory Business.fromMap(String id, Map<dynamic, dynamic> map) {
    return Business(
      id: id,
      ownerId: map['ownerId'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      address: map['address'] ?? '',
      lat: (map['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? 0).toDouble(),
      verified: map['verified'] ?? false,
      ratingSum: (map['ratingSum'] ?? 0).toDouble(),
      ratingCount: map['ratingCount'] ?? 0,
    );
  }
}
