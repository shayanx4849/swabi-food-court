import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../models/saved_address.dart';
import '../shared/location_picker_screen.dart';

/// Manage saved delivery addresses (Home, Work, etc.) — each one is always
/// captured via the map picker, never typed, same reasoning as everywhere
/// else location gets set in this app: most addresses here don't have
/// house numbers, so a real pin is what actually gets someone there.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final _authService = AuthService();
  final _databaseService = DatabaseService();

  static const _suggestedLabels = ['Home', 'Work', 'Other'];

  Future<void> _addAddress() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (picked == null || !mounted) return;

    final label = await _pickLabel();
    if (label == null || !mounted) return;

    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    final address = SavedAddress(
      id: const Uuid().v4(),
      label: label,
      address: picked.address,
      lat: picked.lat,
      lng: picked.lng,
      createdAt: DateTime.now(),
    );
    await _databaseService.addSavedAddress(uid, address);
  }

  Future<String?> _pickLabel() async {
    final customCtrl = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Label this address',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: _suggestedLabels.map((label) {
                  return ActionChip(
                    label: Text(label),
                    onPressed: () => Navigator.of(context).pop(label),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: customCtrl,
                decoration: InputDecoration(
                  hintText: 'Or type a custom label…',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) Navigator.of(context).pop(v.trim());
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700),
                  onPressed: () {
                    final custom = customCtrl.text.trim();
                    Navigator.of(context)
                        .pop(custom.isNotEmpty ? custom : 'Address');
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(SavedAddress address) async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove this address?'),
        content: Text(
            '"${address.label}" will be removed from your saved addresses.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _databaseService.deleteSavedAddress(uid, address.id);
    }
  }

  IconData _iconFor(String label) {
    switch (label.toLowerCase()) {
      case 'home':
        return Icons.home_outlined;
      case 'work':
        return Icons.work_outline;
      default:
        return Icons.location_on_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Addresses')),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<SavedAddress>>(
              stream: _databaseService.streamSavedAddresses(uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final addresses = snapshot.data!;
                if (addresses.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(
                            'No saved addresses yet.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add one to speed up checkout next time.',
                            style: TextStyle(
                                fontSize: 12.5, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: addresses.length,
                  itemBuilder: (context, i) {
                    final address = addresses[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade50,
                          child: Icon(_iconFor(address.label),
                              color: Colors.green.shade700),
                        ),
                        title: Text(address.label,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          address.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5, color: Colors.grey.shade600),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => _delete(address),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green.shade700,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
        onPressed: _addAddress,
      ),
    );
  }
}
