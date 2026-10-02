// lib/screens/company_photos_screen.dart
//
// Add / remove company gallery images.
// Uses POST /company/company/update/ with:
//   images            -> new files (multipart, repeated key)
//   delete_image_ids  -> JSON list of CompanyImage ids to remove

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/design_tokens.dart';
import '../models/company_model.dart';
import '../services/company_service.dart';
import '../widgets/company_ui.dart';

class CompanyPhotosScreen extends StatefulWidget {
  final Company company;

  const CompanyPhotosScreen({super.key, required this.company});

  @override
  State<CompanyPhotosScreen> createState() => _CompanyPhotosScreenState();
}

class _CompanyPhotosScreenState extends State<CompanyPhotosScreen> {
  static const int _maxPhotos = 10;

  final _picker = ImagePicker();
  final Set<int> _toDelete = {};
  final List<XFile> _newFiles = [];
  final List<Uint8List> _newBytes = []; // previews (web + mobile)
  bool _saving = false;

  List<CompanyImage> get _existing => widget.company.images;
  int get _keptCount => _existing.length - _toDelete.length;
  int get _total => _keptCount + _newFiles.length;
  bool get _dirty => _toDelete.isNotEmpty || _newFiles.isNotEmpty;

  Future<void> _pick() async {
    final room = _maxPhotos - _total;
    if (room <= 0) {
      showCompanySnack(context, 'You can keep up to $_maxPhotos photos.', error: true);
      return;
    }
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
      if (picked.isEmpty) return;
      final files = picked.take(room).toList();
      final bytes = <Uint8List>[];
      for (final x in files) {
        bytes.add(await x.readAsBytes());
      }
      if (!mounted) return;
      setState(() {
        _newFiles.addAll(files);
        _newBytes.addAll(bytes);
      });
      if (picked.length > room) {
        showCompanySnack(context, 'Only $room more photo(s) added (limit $_maxPhotos).');
      }
    } catch (e) {
      showCompanySnack(context, 'Could not open gallery: $e', error: true);
    }
  }

  Future<void> _camera() async {
    if (_total >= _maxPhotos) {
      showCompanySnack(context, 'You can keep up to $_maxPhotos photos.', error: true);
      return;
    }
    try {
      final x = await _picker.pickImage(
          source: ImageSource.camera, imageQuality: 80, maxWidth: 1600);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _newFiles.add(x);
        _newBytes.add(bytes);
      });
    } catch (e) {
      showCompanySnack(context, 'Could not open camera: $e', error: true);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final res = await CompanyService.updateCompany(
      id: widget.company.id,
      fields: const {},
      images: _newFiles,
      deleteImageIds: _toDelete.toList(),
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (res.isSuccess) {
      showCompanySnack(context, 'Photos saved');
      Navigator.pop(context, true);
    } else {
      showCompanySnack(context, res.displayMessage, error: true);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return confirmAction(
      context,
      title: 'Discard changes?',
      message: 'Your photo changes have not been saved.',
      confirmLabel: 'Discard',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        if (await _confirmDiscard() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: DT.background,
        appBar: CompanyTopBar(
          title: 'Photos',
          subtitle: '${widget.company.name} · $_total of $_maxPhotos',
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            Text(
              'Buyers see these on your company page. Tap a photo to remove it.',
              style: DT.text(size: 12.5, color: DT.slate500, height: 1.45),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final img in _existing)
                  _Tile(
                    image: Image.network(img.displayUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: DT.slate100,
                          child: Icon(Icons.broken_image_outlined, color: DT.slate400),
                        )),
                    markedForDelete: _toDelete.contains(img.id),
                    onTap: () => setState(() {
                      _toDelete.contains(img.id)
                          ? _toDelete.remove(img.id)
                          : _toDelete.add(img.id);
                    }),
                  ),
                for (var i = 0; i < _newFiles.length; i++)
                  _Tile(
                    image: Image.memory(_newBytes[i], fit: BoxFit.cover),
                    isNew: true,
                    onTap: () => setState(() {
                      _newFiles.removeAt(i);
                      _newBytes.removeAt(i);
                    }),
                  ),
                if (_total < _maxPhotos) _AddTile(onGallery: _pick, onCamera: _camera),
              ],
            ),
            if (_toDelete.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('${_toDelete.length} photo(s) will be removed when you save.',
                  style: DT.text(size: 12, color: DT.error, weight: FontWeight.w600)),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: DT.border)),
            ),
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _dirty && !_saving ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DT.blue800,
                  disabledBackgroundColor: DT.slate200,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
                ),
                child: _saving
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
                    : Text('Save photos',
                    style: DT.text(
                        size: 14.5,
                        weight: FontWeight.w700,
                        color: _dirty ? Colors.white : DT.slate400)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Widget image;
  final bool markedForDelete;
  final bool isNew;
  final VoidCallback onTap;

  const _Tile({
    required this.image,
    required this.onTap,
    this.markedForDelete = false,
    this.isNew = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DT.rMd),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: markedForDelete ? 0.35 : 1, child: image),
            if (markedForDelete)
              const Center(
                child: Icon(Icons.delete_outline_rounded, color: DT.error, size: 30),
              ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: markedForDelete ? DT.blue800 : Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  markedForDelete ? Icons.undo_rounded : Icons.close_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
            if (isNew)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: DT.emerald700,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('New',
                      style: DT.text(size: 10, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  const _AddTile({required this.onGallery, required this.onCamera});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: DT.blue50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DT.rMd),
        side: const BorderSide(color: DT.blue200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(DT.rMd),
        onTap: () => showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(DT.rXl)),
          ),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: DT.blue800),
                  title: Text('Choose from gallery',
                      style: DT.text(size: 14, weight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onGallery();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined, color: DT.blue800),
                  title: Text('Take a photo', style: DT.text(size: 14, weight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onCamera();
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, color: DT.blue800, size: 28),
            const SizedBox(height: 4),
            Text('Add photo',
                style: DT.text(size: 11.5, weight: FontWeight.w700, color: DT.blue800)),
          ],
        ),
      ),
    );
  }
}