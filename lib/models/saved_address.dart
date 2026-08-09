/// One of a customer's saved delivery addresses — e.g. "Home" or "Work".
/// Always captured via the map picker (same LocationPickerScreen used
/// everywhere else in the app), never typed, so it's always a real,
/// navigable point.
class SavedAddress {
  final String id;
  final String label; // e.g. "Home", "Work", "Other"
  final String address;
  final double lat;
  final double lng;
  final DateTime createdAt;

  SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    required this.lat,
    required this.lng,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'address': address,
      'lat': lat,
      'lng': lng,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavedAddress.fromMap(String id, Map<dynamic, dynamic> map) {
    return SavedAddress(
      id: id,
      label: map['label'] ?? 'Address',
      address: map['address'] ?? '',
      lat: (map['lat'] ?? 0).toDouble(),
      lng: (map['lng'] ?? 0).toDouble(),
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
