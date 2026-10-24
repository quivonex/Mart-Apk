// lib/widgets/edit_form_kit.dart
//
// Small shared form pieces for the "edit my …" screens
// (ReMart listing, property). QNX MART colours: brand #093C71, tint #EAF1F9,
// line #C9DBEE, errors red #C62828, all buttons solid #093C71.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/design_tokens.dart';

class EK {
  static const brand = Color(0xFF093C71);
  static const brandDark = Color(0xFF062A50);
  static const brandLight = Color(0xFF1E5A9C);
  static const tint = Color(0xFFEAF1F9);
  static const line = Color(0xFFC9DBEE);
  static const border = Color(0xFFE2E8F0);
  static const bg = Color(0xFFF8FAFC);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
  static const red = Color(0xFFC62828);
  static const green = Color(0xFF047857);
  static const header = LinearGradient(
    colors: [brandDark, brand, brandLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

void ekSnack(BuildContext context, String msg, {bool error = false, bool success = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
      backgroundColor: error ? EK.red : (success ? EK.green : EK.ink),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
}

PreferredSizeWidget ekAppBar(String title, {String? subtitle}) => AppBar(
  backgroundColor: Colors.transparent,
  flexibleSpace: Container(decoration: const BoxDecoration(gradient: EK.header)),
  foregroundColor: Colors.white,
  elevation: 0,
  title: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: DT.text(size: 17, weight: FontWeight.w700, color: Colors.white)),
      if (subtitle != null && subtitle.isNotEmpty)
        Text(subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DT.text(size: 11.5, color: const Color(0xCCFFFFFF))),
    ],
  ),
);

class EkSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  const EkSection({super.key, required this.title, required this.icon, required this.children, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EK.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: EK.tint, borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, size: 18, color: EK.brand),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: DT.text(size: 14.5, weight: FontWeight.w800, color: EK.ink)),
                    if (subtitle != null)
                      Text(subtitle!, style: DT.text(size: 11.5, color: EK.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class EkField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;
  final String? prefix;
  final int? maxLength;

  const EkField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
    this.keyboard,
    this.validator,
    this.prefix,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        minLines: 1,
        maxLength: maxLength,
        keyboardType: keyboard,
        validator: validator,
        style: DT.text(size: 14, color: EK.ink),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefix,
          counterText: '',
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          labelStyle: DT.text(size: 13, color: EK.muted),
          floatingLabelStyle: DT.text(size: 13, weight: FontWeight.w700, color: EK.brand),
          hintStyle: DT.text(size: 13, color: EK.hint),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: b(EK.line),
          enabledBorder: b(EK.line),
          focusedBorder: b(EK.brand, 1.6),
          errorBorder: b(EK.red),
          focusedErrorBorder: b(EK.red, 1.6),
          errorStyle: DT.text(size: 11.5, color: EK.red),
        ),
      ),
    );
  }
}

/// Chip row for a single choice (condition, seller type …).
class EkChoice<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T> onChanged;
  const EkChoice({super.key, required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (v, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: v == value,
            showCheckmark: false,
            selectedColor: EK.brand,
            backgroundColor: EK.tint,
            side: BorderSide(color: v == value ? EK.brand : EK.line),
            labelStyle: DT.text(
                size: 12.5, weight: FontWeight.w600, color: v == value ? Colors.white : EK.brand),
            onSelected: (_) => onChanged(v),
          ),
      ],
    );
  }
}

class EkSwitch extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const EkSwitch({super.key, required this.label, required this.value, required this.onChanged, this.subtitle});

  @override
  Widget build(BuildContext context) => SwitchListTile(
    value: value,
    dense: true,
    contentPadding: EdgeInsets.zero,
    activeThumbColor: Colors.white,
    activeTrackColor: EK.brand,
    title: Text(label, style: DT.text(size: 13.5, weight: FontWeight.w600, color: EK.ink)),
    subtitle: subtitle == null ? null : Text(subtitle!, style: DT.text(size: 11.5, color: EK.muted)),
    onChanged: onChanged,
  );
}

// ── Photos: existing (tap ✕ to remove) + new ─────────────────────
class EkExistingPhoto {
  final int id;
  final String url;
  const EkExistingPhoto(this.id, this.url);
}

class EkNewPhoto {
  final String name;
  final Uint8List bytes;
  const EkNewPhoto(this.name, this.bytes);
}

class EkPhotoGrid extends StatelessWidget {
  final List<EkExistingPhoto> existing;
  final Set<int> removed;
  final List<EkNewPhoto> added;
  final int max;
  final ValueChanged<int> onToggleRemove;
  final ValueChanged<int> onRemoveNew;
  final VoidCallback onAdd;

  const EkPhotoGrid({
    super.key,
    required this.existing,
    required this.removed,
    required this.added,
    required this.max,
    required this.onToggleRemove,
    required this.onRemoveNew,
    required this.onAdd,
  });

  int get count => existing.where((e) => !removed.contains(e.id)).length + added.length;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      const gap = 8.0;
      final size = (box.maxWidth - gap * 2) / 3;
      Widget badge(IconData icon, Color bg, VoidCallback onTap) => Positioned(
        top: 4,
        right: 4,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
        ),
      );
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final p in existing)
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(p.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: EK.tint, child: const Icon(Icons.broken_image_outlined, color: EK.hint))),
                  ),
                  if (removed.contains(p.id))
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: EK.red),
                      ),
                      alignment: Alignment.center,
                      child: Text('Will be removed',
                          textAlign: TextAlign.center,
                          style: DT.text(size: 11, weight: FontWeight.w700, color: EK.red)),
                    ),
                  removed.contains(p.id)
                      ? badge(Icons.undo_rounded, EK.brand, () => onToggleRemove(p.id))
                      : badge(Icons.close_rounded, EK.red, () => onToggleRemove(p.id)),
                ],
              ),
            ),
          for (var i = 0; i < added.length; i++)
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(added[i].bytes, fit: BoxFit.cover),
                  ),
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: EK.green, borderRadius: BorderRadius.circular(6)),
                      child: Text('NEW', style: DT.text(size: 9.5, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                  badge(Icons.close_rounded, EK.red, () => onRemoveNew(i)),
                ],
              ),
            ),
          if (count < max)
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: EK.tint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: EK.line),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined, color: EK.brand),
                    const SizedBox(height: 4),
                    Text('Add photo', style: DT.text(size: 11.5, weight: FontWeight.w700, color: EK.brand)),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Camera / gallery chooser → list of new photos (web: gallery only).
Future<List<EkNewPhoto>> ekPickPhotos(BuildContext context, {required int left}) async {
  if (left <= 0) return const [];
  final picker = ImagePicker();
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: EK.brand),
              title: Text('Choose from gallery', style: DT.text(size: 14, weight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: EK.brand),
              title: Text('Take a photo', style: DT.text(size: 14, weight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return const [];
  try {
    final List<XFile> files;
    if (source == ImageSource.camera) {
      final shot = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1800);
      files = shot == null ? const [] : [shot];
    } else {
      files = await picker.pickMultiImage(imageQuality: 85, maxWidth: 1800);
    }
    final out = <EkNewPhoto>[];
    for (final f in files.take(left)) {
      final name = f.name.isNotEmpty ? f.name : 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      out.add(EkNewPhoto(name, await f.readAsBytes()));
    }
    return out;
  } catch (_) {
    return const [];
  }
}

/// Full-width solid brand button.
class EkButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool busy;
  final VoidCallback? onPressed;
  const EkButton({super.key, required this.label, this.icon, this.busy = false, this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    width: double.infinity,
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: EK.brand, // buttons: only #093C71
        disabledBackgroundColor: EK.brand.withValues(alpha: 0.6),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (busy)
            const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
          else if (icon != null)
            Icon(icon, size: 19),
          const SizedBox(width: 8),
          Text(label, style: DT.text(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    ),
  );
}

/// Loading / error body used while the current values load.
class EkState extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  const EkState({super.key, this.loading = false, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: EK.brand));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(color: EK.tint, shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_rounded, size: 34, color: EK.brand),
            ),
            const SizedBox(height: 14),
            Text(error ?? 'Something went wrong',
                textAlign: TextAlign.center, style: DT.text(size: 14, color: EK.muted, height: 1.4)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: EK.brand),
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
