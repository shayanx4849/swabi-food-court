import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A small, non-interactive OpenStreetMap preview centered on one point —
/// used to show a business's pickup location on detail screens without the
/// weight of a fully interactive map.
class MiniMapView extends StatelessWidget {
  final double lat;
  final double lng;
  final double height;
  final double borderRadius;

  const MiniMapView({
    super.key,
    required this.lat,
    required this.lng,
    this.height = 140,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        height: height,
        child: IgnorePointer(
          // Read-only preview — taps/drags are swallowed so it doesn't
          // fight with the scroll view it usually sits inside.
          child: FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 15.5,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.bachaokhana.app',
              ),
              MarkerLayer(markers: [
                Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_pin, size: 36, color: Colors.red),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
