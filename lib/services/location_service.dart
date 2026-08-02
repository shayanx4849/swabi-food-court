import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  /// Requests permission and returns the device's current position.
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied.');
    }

    return await Geolocator.getCurrentPosition();
  }

  /// Haversine formula — distance in kilometers between two points.
  double distanceInKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Turns a lat/lng into a human-readable address using the device's
  /// native geocoder (Android/iOS built-in — free, no API key, no Google
  /// Cloud billing account required, unlike the Maps/Places APIs).
  ///
  /// This is what lets LocationPickerScreen show "House 12, Street 4,
  /// Swabi" instead of raw coordinates after the user drops a pin, and —
  /// just as importantly — it's derived FROM the pin, so nobody can type a
  /// fake address that doesn't match where the pin actually is.
  ///
  /// NOTE: uses the geocoding ^5.0.0 instance API (Geocoding().method(...))
  /// rather than the older top-level function style — make sure pubspec.yaml
  /// has `geocoding: ^5.0.0`, not an older 3.x/4.x constraint.
  Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = [p.street, p.subLocality, p.locality, p.administrativeArea]
          .where((s) => s != null && s.trim().isNotEmpty)
          .toSet() // drop accidental duplicates (e.g. street == subLocality)
          .toList();
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      // Native geocoder can fail (no network, no geocoder service on the
      // device/emulator) — caller falls back to showing raw coordinates.
      return null;
    }
  }

  /// Forward geocoding — turns a typed place/address into a lat/lng, using
  /// the same free native device geocoder as [reverseGeocode]. Powers the
  /// search bar on LocationPickerScreen so someone can type "Swabi Bazaar"
  /// and jump straight there instead of only panning the map by hand.
  Future<GeocodedPlace?> forwardGeocode(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;
    try {
      final locations = await Geocoding().locationFromAddress(trimmed);
      if (locations.isEmpty) return null;
      final loc = locations.first;
      return GeocodedPlace(lat: loc.latitude, lng: loc.longitude);
    } catch (_) {
      // No match, no network, or geocoder unavailable on this device.
      return null;
    }
  }

  double _degToRad(double deg) => deg * (pi / 180);
}

/// Minimal result of a forward-geocoding search (just the coordinates —
/// the caller re-derives a clean address label via [LocationService.reverseGeocode]
/// once the map settles there, keeping one single source of truth for "what
/// address does this pin represent").
class GeocodedPlace {
  final double lat;
  final double lng;
  const GeocodedPlace({required this.lat, required this.lng});
}
