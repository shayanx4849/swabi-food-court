import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';

/// Result returned by [LocationPickerScreen].
class PickedLocation {
  final double lat;
  final double lng;
  final String address;
  const PickedLocation(
      {required this.lat, required this.lng, required this.address});
}

/// A full-screen map picker (via flutter_map — free, no API key, no Google
/// Cloud billing account) using the standard "fixed center pin, drag the
/// map underneath it" pattern, plus a search bar to jump straight to a
/// typed place instead of only panning by hand.
///
/// This is the ONLY way lat/lng + address get set anywhere in the app now.
/// There is deliberately no free-text address field here: the address
/// shown is always reverse-geocoded from wherever the pin currently sits —
/// even after a search — so what gets saved always matches a real point on
/// the map, and nobody can type a made-up address that doesn't correspond
/// to an actual place.
class LocationPickerScreen extends StatefulWidget {
  /// Optional starting point (e.g. editing an existing business's
  /// location). If omitted, the picker centers on the device's current GPS
  /// position.
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({super.key, this.initialLat, this.initialLng});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _mapController = MapController();
  final _locationService = LocationService();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();

  // Default center: roughly Swabi, Khyber Pakhtunkhwa — used only until we
  // get a real GPS fix or the caller passes an initial point.
  static const _fallbackCenter = LatLng(34.1200, 72.4700);

  late LatLng _center;
  String? _address;
  bool _resolvingAddress = false;
  bool _locating = false;
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
      _resolveAddress(_center);
    } else {
      _center = _fallbackCenter;
      _useCurrentLocation(recenter: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation({bool recenter = false}) async {
    setState(() => _locating = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      final point = LatLng(pos.latitude, pos.longitude);
      _center = point;
      if (recenter && mounted) {
        _mapController.move(point, 16);
      } else if (mounted) {
        _mapController.move(point, _mapController.camera.zoom);
      }
      _resolveAddress(point);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get current location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _searchLocation() async {
    final query = _searchCtrl.text;
    if (query.trim().isEmpty) return;

    _searchFocus.unfocus();
    setState(() => _searching = true);
    try {
      final result = await _locationService.forwardGeocode(query);
      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Couldn\'t find "$query" — try a more specific name')),
        );
        return;
      }

      final point = LatLng(result.lat, result.lng);
      _center = point;
      _mapController.move(point, 16);
      // Re-derive the address from the pin's actual landing spot, same as
      // every other way the pin can move — search is just a faster way to
      // get the pin near the right place, not a substitute for the pin.
      _resolveAddress(point);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _onMapEvent(MapEvent event) {
    // Only care about the map settling after a pan/zoom, not every frame.
    if (event is MapEventMoveEnd || event is MapEventFlingAnimationEnd) {
      final point = event.camera.center;
      setState(() => _center = point);
      _debounce?.cancel();
      _debounce = Timer(
          const Duration(milliseconds: 500), () => _resolveAddress(point));
    }
  }

  Future<void> _resolveAddress(LatLng point) async {
    setState(() {
      _resolvingAddress = true;
      _address = null;
    });
    final address =
        await _locationService.reverseGeocode(point.latitude, point.longitude);
    if (!mounted) return;
    setState(() {
      _address = address;
      _resolvingAddress = false;
    });
  }

  void _confirm() {
    final address = _address ??
        '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}';
    Navigator.of(context).pop(PickedLocation(
      lat: _center.latitude,
      lng: _center.longitude,
      address: address,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pin your exact location')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              onMapEvent: _onMapEvent,
            ),
            children: [
              // CARTO Voyager — a cleaner, more modern-looking basemap than
              // plain OpenStreetMap tiles, still completely free with no
              // API key/billing account (just needs attribution, below).
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.bachaokhana.app',
                retinaMode: RetinaMode.isHighDensity(context),
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                  TextSourceAttribution('CARTO'),
                ],
              ),
            ],
          ),

          // Fixed center pin — the map pans underneath it, so the pin is
          // always exactly where the address gets resolved from.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(
                    bottom: 36), // anchor pin tip to true center
                child: Icon(Icons.location_pin, size: 44, color: Colors.red),
              ),
            ),
          ),

          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            focusNode: _searchFocus,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _searchLocation(),
                            decoration: const InputDecoration(
                              hintText: 'Search area, market, landmark…',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _searching ? null : _searchLocation,
                          icon: _searching
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.search),
                          color: Colors.green.shade700,
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 15, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Or drag the map so the pin sits exactly on your location',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            right: 12,
            bottom: 160,
            child: FloatingActionButton.small(
              heroTag: 'locate_me',
              backgroundColor: Colors.white,
              onPressed:
                  _locating ? null : () => _useCurrentLocation(recenter: true),
              child: _locating
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.12), blurRadius: 14),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.place,
                            size: 16, color: Colors.green.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _resolvingAddress
                              ? Text('Locating address…',
                                  style: TextStyle(color: Colors.grey.shade600))
                              : Text(
                                  _address ??
                                      '${_center.latitude.toStringAsFixed(5)}, '
                                          '${_center.longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade700),
                        onPressed: _confirm,
                        child: const Text('Confirm this location'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
