import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';
import '../../services/cloudinary_service.dart';
import '../../models/business.dart';
import '../../models/listing.dart';

/// Form used by a business to publish a new "Surprise Bag" surplus
/// food listing with a price, quantity, and pickup time window.
class AddListingScreen extends StatefulWidget {
  final Business business;
  const AddListingScreen({super.key, required this.business});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();
  final _cloudinaryService = CloudinaryService();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _originalPriceCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '5');

  TimeOfDay _pickupStart = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay _pickupEnd = const TimeOfDay(hour: 21, minute: 0);
  File? _selectedImage;
  bool _saving = false;
  bool _uploadingImage = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // compress a bit to keep uploads fast
    );
    if (picked == null) return;
    setState(() => _selectedImage = File(picked.path));
  }

  DateTime _combine(TimeOfDay t) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, t.hour, t.minute);
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
      String? imageUrl;
      if (_selectedImage != null) {
        setState(() => _uploadingImage = true);
        try {
          imageUrl = await _cloudinaryService.uploadImage(_selectedImage!);
        } catch (e) {
          // If the upload fails (e.g. Cloudinary not configured yet, or the
          // temp image file got cleared by the OS under low storage), we
          // still publish the listing without a photo rather than blocking
          // the business from posting surplus food.
          imageUrl = null;
        }
        if (mounted) setState(() => _uploadingImage = false);
      }

      final listing = FoodListing(
        id: const Uuid().v4(),
        businessId: widget.business.id,
        businessName: widget.business.name,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
        originalPrice: double.parse(_originalPriceCtrl.text.trim()),
        quantityAvailable: int.parse(_quantityCtrl.text.trim()),
        pickupStart: _combine(_pickupStart),
        pickupEnd: _combine(_pickupEnd),
        status: 'active',
        lat: widget.business.lat,
        lng: widget.business.lng,
        imageUrl: imageUrl,
      );

      await _databaseService.createListing(listing);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not publish listing: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New surplus listing')),
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
                        ? DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedImage == null
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
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Title', hintText: 'e.g. Bakery Surprise Bag'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What might be inside the bag'),
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
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? Text(_uploadingImage ? 'Uploading photo...' : 'Publishing...')
                    : const Text('Publish listing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
