import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';
import '../../models/menu_item.dart';
import '../../models/deal.dart';

/// Create or edit a Deal. Deals are always tied to one of the business's
/// own menu items (so ordering reuses the normal menu-item order flow at a
/// discounted price) — there's no separate deal image/description to
/// manage, and no forced pickup window. The business picks the discount %
/// and an expiry date of their own choosing, and can come back and change
/// or delete it whenever they like.
class AddEditDealScreen extends StatefulWidget {
  final String businessId;
  final String businessName;
  final Deal? existingDeal;

  const AddEditDealScreen({
    super.key,
    required this.businessId,
    required this.businessName,
    this.existingDeal,
  });

  @override
  State<AddEditDealScreen> createState() => _AddEditDealScreenState();
}

class _AddEditDealScreenState extends State<AddEditDealScreen> {
  final _databaseService = DatabaseService();

  // Tracked by id, not the MenuItem object itself — the StreamBuilder below
  // rebuilds with a brand-new List<MenuItem> (new object instances) on
  // every stream tick, and MenuItem doesn't override ==, so holding onto an
  // old instance as DropdownButtonFormField's value stops matching anything
  // in the new list and throws. Matching by id sidesteps that entirely.
  String? _selectedItemId;
  List<MenuItem> _availableItems = [];

  double _discountPercent = 20;
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  bool get _isEditing => widget.existingDeal != null;

  @override
  void initState() {
    super.initState();
    if (widget.existingDeal != null) {
      _discountPercent = widget.existingDeal!.discountPercent;
      _expiryDate = widget.existingDeal!.expiryDate;
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate.isAfter(DateTime.now())
          ? _expiryDate
          : DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _expiryDate = picked);
  }

  Future<void> _save() async {
    if (!_isEditing && _selectedItemId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a menu item for this deal.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        final updated = widget.existingDeal!.copyWith(
          discountPercent: _discountPercent,
          expiryDate: _expiryDate,
        );
        await _databaseService.updateDeal(updated);
      } else {
        final item = _availableItems.firstWhere((i) => i.id == _selectedItemId);
        final deal = Deal(
          id: const Uuid().v4(),
          businessId: widget.businessId,
          businessName: widget.businessName,
          menuItemId: item.id,
          menuItemName: item.name,
          imageUrl: item.imageUrl,
          originalPrice: item.price,
          discountPercent: _discountPercent,
          expiryDate: _expiryDate,
          createdAt: DateTime.now(),
        );
        await _databaseService.createDeal(deal);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save deal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    MenuItem? selectedItem;
    if (_selectedItemId != null) {
      for (final i in _availableItems) {
        if (i.id == _selectedItemId) {
          selectedItem = i;
          break;
        }
      }
    }
    final basePrice = _isEditing ? widget.existingDeal!.originalPrice : selectedItem?.price;
    final discountedPrice =
        basePrice == null ? null : basePrice * (1 - _discountPercent / 100);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit deal' : 'Create a deal')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_isEditing) ...[
            Text('Menu item', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text(widget.existingDeal!.menuItemName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
          ] else ...[
            Text('Choose a menu item', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            StreamBuilder<List<MenuItem>>(
              stream: _databaseService.streamBusinessMenuItems(widget.businessId),
              builder: (context, snapshot) {
                final items = (snapshot.data ?? []).where((i) => i.available).toList();
                // Cache for _save() and the price preview above — the
                // StreamBuilder is the only place that has the live list.
                _availableItems = items;

                if (items.isEmpty) {
                  return Text(
                    'Add a menu item first — deals apply a discount to an existing item.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  );
                }

                // If a previously-selected item no longer exists in the
                // latest list (e.g. it was deleted), clear the selection
                // instead of leaving a dangling id.
                final validIds = items.map((i) => i.id).toSet();
                final dropdownValue = validIds.contains(_selectedItemId) ? _selectedItemId : null;

                return DropdownButtonFormField<String>(
                  key: ValueKey(items.map((i) => i.id).join(',')),
                  initialValue: dropdownValue,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  hint: const Text('Select an item'),
                  items: items
                      .map((i) => DropdownMenuItem(
                            value: i.id,
                            child: Text('${i.name} — Rs. ${i.price.toStringAsFixed(0)}'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedItemId = v),
                );
              },
            ),
            const SizedBox(height: 24),
          ],

          Text('Discount', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _discountPercent,
                  min: 5,
                  max: 80,
                  divisions: 15,
                  activeColor: Colors.green.shade700,
                  label: '${_discountPercent.round()}%',
                  onChanged: (v) => setState(() => _discountPercent = v),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text('${_discountPercent.round()}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),

          if (discountedPrice != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text('Rs. ${basePrice!.toStringAsFixed(0)}',
                      style: TextStyle(
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey.shade600,
                          fontSize: 14)),
                  const SizedBox(width: 8),
                  Text('Rs. ${discountedPrice.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green.shade800)),
                  const Spacer(),
                  Text('Customer pays', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          Text('Runs until', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text(
              '${_expiryDate.day}/${_expiryDate.month}/${_expiryDate.year}',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.centerLeft,
            ),
            onPressed: _pickExpiryDate,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'You pick this date — there\'s no forced time limit. Edit or delete this deal anytime before then.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
            ),
          ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEditing ? 'Save changes' : 'Create deal'),
            ),
          ),
        ],
      ),
    );
  }
}
