import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/database_service.dart';
import '../../services/cloudinary_service.dart';
import '../../models/listing.dart';

/// Lets a business edit an existing listing — title, description, price,
/// quantity, pickup window, and photo. Reuses the same field layout as
/// AddListingScreen but pre-fills values and calls updateListing() instead
/// of createListing().
class EditListingScreen extends StatefulWidget {
  final FoodListing listing;
  const EditListingScreen({super.key, required this.listing});

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();
  final _cloudinaryService = CloudinaryService();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _originalPriceCtrl;
  late final TextEditingController _quantityCtrl;

  late TimeOfDay _pickupStart;
  late TimeOfDay _pickupEnd;
  File? _selectedImage; // only set if the business picks a NEW photo
  String? _existingImageUrl;
  bool _saving = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    final l = widget.listing;
    _titleCtrl = TextEditingController(text: l.title);
    _descCtrl = TextEditingController(text: l.description);
    _priceCtrl = TextEditingController(text: l.price.toStringAsFixed(0));
    _originalPriceCtrl = TextEditingController(text: l.originalPrice.toStringAsFixed(0));
    _quantityCtrl = TextEditingController(text: l.quantityAvailable.toString());
    _pickupStart = TimeOfDay.fromDateTime(l.pickupStart);
    _pickupEnd = TimeOfDay.fromDateTime(l.pickupEnd);
    _existingImageUrl = l.imageUrl;
  }

  DateTime _combine(TimeOfDay t) {
    final base = widget.listing.pickupStart;
    return DateTime(base.year, base.month, base.day, t.hour, t.minute);
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;
    setState(() => _selectedImage = File(picked.path));
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _pickupStart : _pickupEnd,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _pickupStart = picked;
      } else {
        _pickupEnd = picked;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      String? imageUrl = _existingImageUrl;
      if (_selectedImage != null) {
        setState(() => _uploadingImage = true);
        try {
          final uploaded = await _cloudinaryService.uploadImage(_selectedImage!);
          if (uploaded != null) imageUrl = uploaded;
        } catch (_) {
          // Keep the old photo if a new upload fails.
        }
        if (mounted) setState(() => _uploadingImage = false);
      }

      final updated = FoodListing(
        id: widget.listing.id,
        businessId: widget.listing.businessId,
        businessName: widget.listing.businessName,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
        originalPrice: double.parse(_originalPriceCtrl.text.trim()),
        quantityAvailable: int.parse(_quantityCtrl.text.trim()),
        pickupStart: _combine(_pickupStart),
        pickupEnd: _combine(_pickupEnd),
        // Re-activate a listing if the business edits it — e.g. bumping the
        // pickup window forward on one that had expired.
        status: 'active',
        lat: widget.listing.lat,
        lng: widget.listing.lng,
        imageUrl: imageUrl,
      );

      await _databaseService.updateListing(updated);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save changes: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit listing')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    image: _selectedImage != null
                        ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                        : (_existingImageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover)
                            : null),
                  ),
                  child: (_selectedImage == null && _existingImageUrl == null)
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Add a photo (optional)', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 16),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Discounted price (Rs.)'),
                      validator: (v) =>
                          (v == null || double.tryParse(v) == null) ? 'Enter a number' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _originalPriceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Original value (Rs.)'),
                      validator: (v) =>
                          (v == null || double.tryParse(v) == null) ? 'Enter a number' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Bags available'),
                validator: (v) =>
                    (v == null || int.tryParse(v) == null) ? 'Enter a number' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pickup start'),
                      subtitle: Text(_pickupStart.format(context)),
                      onTap: () => _pickTime(true),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pickup end'),
                      subtitle: Text(_pickupEnd.format(context)),
                      onTap: () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Note: editing resets the pickup date to today. Adjust the '
                'time above if you want a different pickup window.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? Text(_uploadingImage ? 'Uploading photo...' : 'Saving...')
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
