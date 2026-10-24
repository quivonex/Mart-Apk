// lib/screens/property_edit_screen.dart
//
// Real estate › Edit my property   (POST real_estate/property-update/)
//   • current values from real_estate/property-detail (slug)
//   • edits basic details, location, area, project info, photos
//   • flat types / floors / price slabs are not changed here
// Only changed fields are sent. Returns true to the caller when saved.

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/property_model.dart';
import '../services/property_edit_service.dart';
import '../services/qnx_api.dart';
import '../services/real_estate_service.dart';
import '../widgets/edit_form_kit.dart';
import 'login_screen.dart';

const _maxPhotos = 20;

class PropertyEditScreen extends StatefulWidget {
  final int propertyId;
  final String slug;
  final String title;
  const PropertyEditScreen({super.key, required this.propertyId, required this.slug, this.title = ''});

  @override
  State<PropertyEditScreen> createState() => _PropertyEditScreenState();
}

class _PropertyEditScreenState extends State<PropertyEditScreen> {
  final _form = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{
    for (final k in const [
      'title',
      'description',
      'city',
      'area',
      'address',
      'landmark',
      'pincode',
      'total_area',
      'plot_area',
      'completion_percentage',
      'rera_number',
      'google_location_url',
      'property_website_url',
    ])
      k: TextEditingController(),
  };

  PropertyDetail? _d;
  final Map<String, String> _orig = {};
  bool _loading = true;
  String? _error;
  bool _saving = false;

  bool _negotiable = false;
  bool _underConstruction = false;
  String _possession = ''; // YYYY-MM-DD
  final Set<int> _removed = {};
  final List<EkNewPhoto> _added = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _clean(String s) {
    final t = s.trim();
    if (t == 'null' || t == 'None') return '';
    // "1200.00" → "1200"
    final n = double.tryParse(t);
    if (n != null && t.contains('.') && n == n.roundToDouble()) return n.toStringAsFixed(0);
    return t;
  }

  String _dateOnly(String s) {
    final d = DateTime.tryParse(s.trim());
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await RealEstateService.getPropertyDetail(widget.slug);
    if (!mounted) return;
    final d = r.data;
    if (!r.status || d == null) {
      setState(() {
        _loading = false;
        _error = r.message ?? 'Could not load this property.';
      });
      return;
    }
    _d = d;
    final values = <String, String>{
      'title': d.title,
      'description': d.description,
      'city': d.city,
      'area': d.area,
      'address': d.address,
      'landmark': d.landmark,
      'pincode': d.pincode,
      'total_area': _clean(d.totalArea),
      'plot_area': _clean(d.plotArea),
      'completion_percentage': _clean(d.completionPercentage),
      'rera_number': d.reraNumber,
      'google_location_url': d.googleLocationUrl ?? '',
      'property_website_url': d.propertyWebsiteUrl ?? '',
    };
    values.forEach((k, v) {
      final t = _clean(v);
      _orig[k] = t;
      _c[k]!.text = t;
    });
    _negotiable = d.isNegotiable;
    _underConstruction = d.isUnderConstruction;
    _possession = _dateOnly(d.possessionDate);
    _orig['possession_date'] = _possession;
    setState(() => _loading = false);
  }

  int get _photoCount =>
      (_d?.images.where((e) => !_removed.contains(e.id)).length ?? 0) + _added.length;

  Future<void> _addPhotos() async {
    final picked = await ekPickPhotos(context, left: _maxPhotos - _photoCount);
    if (picked.isEmpty || !mounted) return;
    setState(() => _added.addAll(picked));
  }

  Future<void> _pickPossession() async {
    final now = DateTime.now();
    final init = DateTime.tryParse(_possession) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 15),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: EK.brand)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _possession = _dateOnly(picked.toIso8601String()));
  }

  Future<void> _save() async {
    final d = _d;
    if (d == null) return;
    if (!(_form.currentState?.validate() ?? false)) {
      ekSnack(context, 'Please check the highlighted fields', error: true);
      return;
    }
    final fields = <String, String?>{};
    _c.forEach((k, c) {
      final v = c.text.trim();
      if (v != (_orig[k] ?? '')) fields[k] = v;
    });
    if (_negotiable != d.isNegotiable) fields['is_negotiable'] = _negotiable ? 'true' : 'false';
    if (_underConstruction != d.isUnderConstruction) {
      fields['is_under_construction'] = _underConstruction ? 'true' : 'false';
      fields['ready_to_move'] = _underConstruction ? 'false' : 'true';
    }
    if (_possession != (_orig['possession_date'] ?? '') && _possession.isNotEmpty) {
      fields['possession_date'] = _possession;
    }
    if (fields.isEmpty && _removed.isEmpty && _added.isEmpty) {
      ekSnack(context, 'No changes to save');
      return;
    }

    setState(() => _saving = true);
    final r = await PropertyEditService.update(
      propertyId: widget.propertyId,
      fields: fields,
      deleteImageIds: _removed.toList(),
      newImages: [for (final p in _added) QnxFile('images', p.name, p.bytes)],
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!r.ok) {
      ekSnack(context, r.message, error: true);
      if (r.needsLogin) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
      return;
    }
    ekSnack(context, r.message, success: true);
    Navigator.pop(context, true);
  }

  String? _required(String? v, String what) => (v ?? '').trim().isEmpty ? 'Enter $what' : null;

  String? _number(String? v, {double? max}) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final n = double.tryParse(s);
    if (n == null || n < 0) return 'Enter a number';
    if (max != null && n > max) return 'Max $max';
    return null;
  }

  String? _url(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final u = Uri.tryParse(s);
    return u == null || !(u.isScheme('http') || u.isScheme('https')) ? 'Enter a full link (https://…)' : null;
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      backgroundColor: EK.bg,
      appBar: ekAppBar('Edit property', subtitle: d?.title ?? widget.title),
      body: _loading || d == null
          ? EkState(loading: _loading, error: _error, onRetry: _load)
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  EkSection(
                    title: 'Photos',
                    subtitle: '$_photoCount/$_maxPhotos · tap ✕ to remove',
                    icon: Icons.photo_library_outlined,
                    children: [
                      EkPhotoGrid(
                        existing: [
                          for (final i in d.images)
                            if (i.imageS3Key.isNotEmpty) EkExistingPhoto(i.id, i.imageS3Key),
                        ],
                        removed: _removed,
                        added: _added,
                        max: _maxPhotos,
                        onToggleRemove: (id) =>
                            setState(() => _removed.contains(id) ? _removed.remove(id) : _removed.add(id)),
                        onRemoveNew: (i) => setState(() => _added.removeAt(i)),
                        onAdd: _addPhotos,
                      ),
                    ],
                  ),
                  EkSection(
                    title: 'Basic details',
                    icon: Icons.apartment_rounded,
                    children: [
                      EkField(
                          controller: _c['title']!,
                          label: 'Title',
                          maxLength: 200,
                          validator: (v) => _required(v, 'a title')),
                      EkField(controller: _c['description']!, label: 'Description', maxLines: 6),
                      EkSwitch(
                        label: 'Price is negotiable',
                        value: _negotiable,
                        onChanged: (v) => setState(() => _negotiable = v),
                      ),
                    ],
                  ),
                  EkSection(
                    title: 'Location',
                    icon: Icons.location_on_outlined,
                    children: [
                      EkField(controller: _c['city']!, label: 'City', validator: (v) => _required(v, 'the city')),
                      EkField(controller: _c['area']!, label: 'Area / locality'),
                      EkField(controller: _c['address']!, label: 'Address', maxLines: 2),
                      EkField(controller: _c['landmark']!, label: 'Landmark'),
                      EkField(
                        controller: _c['pincode']!,
                        label: 'Pincode',
                        keyboard: TextInputType.number,
                        maxLength: 6,
                        validator: (v) {
                          final s = (v ?? '').trim();
                          return s.isEmpty || RegExp(r'^\d{6}$').hasMatch(s) ? null : 'Enter a 6-digit pincode';
                        },
                      ),
                      EkField(
                        controller: _c['google_location_url']!,
                        label: 'Google Maps link',
                        keyboard: TextInputType.url,
                        validator: _url,
                      ),
                    ],
                  ),
                  EkSection(
                    title: 'Size & project',
                    icon: Icons.square_foot_rounded,
                    children: [
                      EkField(
                        controller: _c['total_area']!,
                        label: 'Total area (sq ft)',
                        keyboard: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => _number(v),
                      ),
                      EkField(
                        controller: _c['plot_area']!,
                        label: 'Plot area (sq ft)',
                        keyboard: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => _number(v),
                      ),
                      EkSwitch(
                        label: 'Under construction',
                        subtitle: _underConstruction ? null : 'Ready to move',
                        value: _underConstruction,
                        onChanged: (v) => setState(() => _underConstruction = v),
                      ),
                      if (_underConstruction) ...[
                        EkField(
                          controller: _c['completion_percentage']!,
                          label: 'Completion %',
                          keyboard: TextInputType.number,
                          validator: (v) => _number(v, max: 100),
                        ),
                        _dateTile(),
                      ],
                      EkField(controller: _c['rera_number']!, label: 'RERA number'),
                      EkField(
                        controller: _c['property_website_url']!,
                        label: 'Project website',
                        keyboard: TextInputType.url,
                        validator: _url,
                      ),
                    ],
                  ),
                  _note(),
                  const SizedBox(height: 14),
                  EkButton(label: 'Save changes', icon: Icons.check_rounded, busy: _saving, onPressed: _save),
                ],
              ),
            ),
    );
  }

  Widget _dateTile() {
    final label = _possession.isEmpty ? 'Choose date' : qDateLabel(DateTime.tryParse(_possession));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _pickPossession,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: EK.line),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_outlined, size: 18, color: EK.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Possession date', style: DT.text(size: 13, color: EK.muted)),
              ),
              Text(label, style: DT.text(size: 13.5, weight: FontWeight.w700, color: EK.ink)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _note() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: EK.tint,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EK.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: EK.brand),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Prices, flat types and floor plans stay as they are. Contact support to change them.',
                style: DT.text(size: 12, color: EK.brandDark, height: 1.4),
              ),
            ),
          ],
        ),
      );
}
