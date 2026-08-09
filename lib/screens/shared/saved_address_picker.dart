import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/saved_address.dart';
import 'location_picker_screen.dart';

/// Internal sentinel — tells the outer function the sheet was dismissed
/// because the user chose "Pin a new location", as opposed to picking a
/// saved address or just swiping the sheet away with nothing selected.
class _PinNewLocationRequested {
  const _PinNewLocationRequested();
}

/// Shows a bottom sheet listing the customer's saved addresses (Home,
/// Work, etc.) plus a "Pin a new location" option that falls through to
/// the full map picker. Used from every delivery checkout screen so
/// customers don't have to re-pin their location every single order.
///
/// IMPORTANT: the sheet is always fully closed before the full-screen map
/// picker is ever pushed — the two are never on screen/in the widget tree
/// at the same time. Pushing a heavy map route while a modal bottom sheet
/// route is still active (animating out underneath it) was causing an
/// intermittent native crash on some devices, since both routes' surfaces
/// were briefly alive together.
///
/// Returns the chosen [PickedLocation], or null if dismissed without a
/// selection.
Future<PickedLocation?> showSavedAddressPicker(BuildContext context) async {
  final authService = AuthService();
  final databaseService = DatabaseService();
  final uid = authService.currentUser?.uid;

  // Not signed in (shouldn't normally happen on a checkout screen) — just
  // fall through to the plain map picker.
  if (uid == null) {
    return Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
  }

  final sheetResult = await showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text('Deliver to',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<SavedAddress>>(
                  stream: databaseService.streamSavedAddresses(uid),
                  builder: (context, snapshot) {
                    final addresses = snapshot.data ?? [];
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final address in addresses)
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.shade50,
                              child: Icon(
                                address.label.toLowerCase() == 'home'
                                    ? Icons.home_outlined
                                    : address.label.toLowerCase() == 'work'
                                        ? Icons.work_outline
                                        : Icons.location_on_outlined,
                                color: Colors.green.shade700,
                              ),
                            ),
                            title: Text(address.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              address.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                            onTap: () =>
                                Navigator.of(sheetContext).pop(PickedLocation(
                              lat: address.lat,
                              lng: address.lng,
                              address: address.address,
                            )),
                          ),
                        if (addresses.isEmpty && snapshot.hasData)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'No saved addresses yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        const Divider(height: 24),
                        ListTile(
                          leading: Icon(Icons.add_location_alt_outlined,
                              color: Colors.green.shade700),
                          title: Text('Pin a new location',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700)),
                          // Just close the sheet with a sentinel — do NOT
                          // push the map screen from here. The sheet must
                          // be fully gone before that heavier route opens.
                          onTap: () => Navigator.of(sheetContext)
                              .pop(const _PinNewLocationRequested()),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );

  if (sheetResult is PickedLocation) {
    return sheetResult;
  }

  if (sheetResult is _PinNewLocationRequested) {
    // The sheet has fully closed and its route is gone by this point
    // (showModalBottomSheet's Future only completes after that), so it's
    // now safe to push the map screen using the original screen's context.
    if (!context.mounted) return null;
    return Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
  }

  return null; // sheet dismissed (swiped away / tapped outside) with no selection
}
