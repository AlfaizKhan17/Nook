import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/item_service.dart';
import '../services/storage_service.dart';
import '../widgets/item_badges.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});
  @override State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  final _itemService = ItemService();
  final _storage = StorageService();
  XFile? _image;
  String _type = 'FOUND';
  bool _loading = false;

  @override
  void dispose() { _title.dispose(); _location.dispose(); _description.dispose(); super.dispose(); }

  Future<void> _pick() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1400);
    if (picked != null) setState(() => _image = picked);
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _location.text.trim().isEmpty || _description.text.trim().isEmpty) {
      _show('Please fill in the item name, location and description.');
      return;
    }
    setState(() => _loading = true);
    String? url;
    var created = false;
    try {
      if (_image != null) {
        final extension = _image!.name.split('.').last.toLowerCase();
        final contentType = switch (extension) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          'gif' => 'image/gif',
          _ => 'image/jpeg',
        };
        url = await _storage.uploadItemImage(
          fileName: _image!.name,
          bytes: await _image!.readAsBytes(),
          contentType: contentType,
        );
      }
      await _itemService.createItem(
        title: _title.text.trim(),
        type: _type,
        location: _location.text.trim(),
        description: _description.text.trim(),
        imageUrl: url,
      );
      created = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post created successfully!')));
      Navigator.pop(context);
    } catch (e) {
      if (!created && url != null) await _storage.deleteImage(url);
      _show('Could not create post: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
        title: const Text('Create Post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What happened?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 15),
          _typeSwitch(),
          const SizedBox(height: 18),
          InkWell(
            onTap: _pick,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: _image == null
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_a_photo_outlined, size: 38, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 9),
                Text('Add Item Photo', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Tap to choose a photo', style: Theme.of(context).textTheme.bodySmall),
              ])
                  : ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Stack(fit: StackFit.expand, children: [
                  FutureBuilder<Uint8List>(
                  future: _image!.readAsBytes(),
                  builder: (context, snapshot) => snapshot.hasData
                      ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                      : const Center(child: CircularProgressIndicator()),
                ),
                  Positioned(top: 10, right: 10, child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(icon: const Icon(Icons.edit, color: Colors.white, size: 18), onPressed: _pick),
                  )),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _label('Item Name'),
          TextField(controller: _title, maxLength: 80, textCapitalization: TextCapitalization.sentences, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'e.g. Black Wallet', counterText: '')),
          const SizedBox(height: 15),
          _label('Location'),
          TextField(controller: _location, maxLength: 120, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'e.g. Library, CSE Building', counterText: '')),
          const SizedBox(height: 15),
          _label('Description'),
          TextField(controller: _description, maxLines: 5, maxLength: 600, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Describe the item and where it was found/lost...', counterText: '')),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading ? const SizedBox(width: 23, height: 23, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Post Item'),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 3, bottom: 7),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13)),
  );

  Widget _typeSwitch() => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).dividerColor)),
    child: Row(children: [
      _typeButton('LOST'),
      _typeButton('FOUND'),
    ]),
  );

  Widget _typeButton(String value) {
    final (fg, bg) = TypeBadge.colorsFor(context, value);
    final selected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(color: selected ? bg : Colors.transparent, borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(value, style: TextStyle(color: selected ? fg : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 12))),
        ),
      ),
    );
  }
}
