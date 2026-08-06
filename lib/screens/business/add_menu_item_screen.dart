import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../services/database_service.dart';
import '../../services/cloudinary_service.dart';
import '../../models/business.dart';
import '../../models/menu_item.dart';

/// Form for a business to add a new item to their regular, always-available
/// menu — separate from the time-limited surplus "Surprise Bag" listings.
class AddMenuItemScreen extends StatefulWidget {
  final Business business;
  final MenuItem? existingItem; // non-null when editing
  const AddMenuItemScreen({super.key, required this.business, this.existingItem});

  @override
  State<AddMenuItemScreen> createState() => _AddMenuItemScreenState();
}

class _AddMenuItemScreenState extends State<AddMenuItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _databaseService = DatabaseService();
  final _cloudinaryService = CloudinaryService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;

  File? _selectedImage;
  String? _existingImageUrl;
  bool _available = true;
  bool _saving = false;
  String _category = kMenuItemCategories.last; // 'Other' — matches MenuItem's default

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existingItem;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _priceCtrl = TextEditingController(text: e != null ? e.price.toStringAsFixed(0) : '');
    _existingImageUrl = e?.imageUrl;
    _available = e?.available ?? true;
    _category = e?.category ?? kMenuItemCategories.last;
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    setState(() => _selectedImage = File(picked.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      String? imageUrl = _existingImageUrl;
      if (_selectedImage != null) {
        try {
          final uploaded = await _cloudinaryService.uploadImage(_selectedImage!);
          if (uploaded != null) imageUrl = uploaded;
        } catch (_) {
          // Keep going without the photo if upload fails.
        }
      }

      final item = MenuItem(
        id: widget.existingItem?.id ?? const Uuid().v4(),
        businessId: widget.business.id,
        businessName: widget.business.name,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: double.parse(_priceCtrl.text.trim()),
        imageUrl: imageUrl,
        available: _available,
        category: _category,
      );

      if (_isEditing) {
        await _databaseService.updateMenuItem(item);
      } else {
        await _databaseService.createMenuItem(item);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit menu item' : 'New menu item')),
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
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    image: _selectedImage != null
                        ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                        : (_existingImageUrl != null
                            ? DecorationImage(image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover)
                            : null),
                  ),
                  child: (_selectedImage == null && _existingImageUrl == null)
                      ? const Center(
                          child: Icon(Icons.add_a_photo_outlined, size: 30, color: Colors.grey),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Item name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price (Rs.)'),
                validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a number' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: kMenuItemCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? kMenuItemCategories.last),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Available'),
                subtitle: const Text('Turn off to temporarily hide this item from customers'),
                value: _available,
                onChanged: (v) => setState(() => _available = v),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing ? 'Save changes' : 'Add item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
