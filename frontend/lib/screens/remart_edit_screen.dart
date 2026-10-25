// lib/screens/remart_edit_screen.dart
//
// QNX ReMart › Edit my item   (POST olx/listings/update/)
//   • loads current values (incl. photo URLs) with listing_id only
//   • edits text fields, price, condition, seller type, location,
//     item details (attributes), photos (remove / add, max 10)
//   • category stays as it is (its details depend on it)
//   • status is not changed here – "Mark as sold" is on My items
// Returns true to the caller when something was saved.

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../services/qnx_api.dart';
import '../services/remart_edit_service.dart';
import '../widgets/edit_form_kit.dart';
import 'login_screen.dart';
import 'package:qnx_mart/l10n/app_language.dart';

const _maxPhotos = 10;

class RemartEditScreen extends StatefulWidget {
  final int listingId;
  final String title;
  const RemartEditScreen({super.key, required this.listingId, this.title = ''});

  @override
  State<RemartEditScreen> createState() => _RemartEditScreenState();
}

class _RemartEditScreenState extends State<RemartEditScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _city = TextEditingController();
  final _area = TextEditingController();
  final _address = TextEditingController();
  final _pincode = TextEditingController();
  final Map<String, TextEditingController> _attr = {};

  RemartEditData? _data;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  bool _negotiable = false;
  String _condition = '';
  String _sellerType = 'individual';
  final Set<int> _removed = {};
  final List<EkNewPhoto> _added = [];

  static const _conditions = [
    ('new', 'New'),
    ('like_new', 'Like new'),
    ('good', 'Good'),
    ('fair', 'Fair'),
    ('used', 'Used'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_title, _desc, _price, _city, _area, _address, _pincode, ..._attr.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String _priceText(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await RemartEditService.load(widget.listingId);
    if (!mounted) return;
    if (!r.ok || r.data == null) {
      setState(() {
        _loading = false;
        _error = r.message;
      });
      if (r.needsLogin) _goLogin();
      return;
    }
    _fill(r.data!);
    setState(() => _loading = false);
  }

  void _fill(RemartEditData d) {
    _data = d;
    _title.text = d.title;
    _desc.text = d.description;
    _price.text = d.price > 0 ? _priceText(d.price) : '';
    _city.text = d.city;
    _area.text = d.area;
    _address.text = d.address;
    _pincode.text = d.pincode;
    _negotiable = d.negotiable;
    _condition = d.condition;
    _sellerType = d.sellerType.isEmpty ? 'individual' : d.sellerType;
    for (final c in _attr.values) {
      c.dispose();
    }
    _attr
      ..clear()
      ..addEntries(d.attributes.entries
          .where((e) => e.value is! Map && e.value is! List)
          .map((e) => MapEntry(e.key, TextEditingController(text: e.value == null ? '' : '${e.value}'))));
    _removed.clear();
    _added.clear();
  }

  void _goLogin() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  String _labelOf(String key) {
    final s = key.replaceAll('_', ' ').trim();
    return s.isEmpty ? key : s[0].toUpperCase() + s.substring(1);
  }

  int get _photoCount =>
      (_data?.images.where((e) => !_removed.contains(e.id)).length ?? 0) + _added.length;

  Future<void> _addPhotos() async {
    final picked = await ekPickPhotos(context, left: _maxPhotos - _photoCount);
    if (picked.isEmpty || !mounted) return;
    setState(() => _added.addAll(picked));
  }

  // only what changed is sent
  Future<void> _save() async {
    final d = _data;
    if (d == null) return;
    if (!(_form.currentState?.validate() ?? false)) {
      ekSnack(context, tr('Please check the highlighted fields'), error: true);
      return;
    }
    if (_photoCount == 0) {
      ekSnack(context, tr('Keep at least one photo'), error: true);
      return;
    }
    String? changed(String now, String before) => now.trim() == before.trim() ? null : now.trim();

    final price = double.tryParse(_price.text.trim().replaceAll(',', ''));
    Map<String, dynamic>? attrs;
    if (_attr.isNotEmpty) {
      final next = Map<String, dynamic>.from(d.attributes);
      var diff = false;
      _attr.forEach((k, c) {
        final old = d.attributes[k];
        final v = c.text.trim();
        if ('${old ?? ''}' == v) return;
        diff = true;
        next[k] = old is num ? (num.tryParse(v) ?? v) : (old is bool ? v.toLowerCase() == 'true' : v);
      });
      if (diff) attrs = next;
    }

    final fields = (
      title: changed(_title.text, d.title),
      description: changed(_desc.text, d.description),
      price: price != null && price != d.price ? price : null,
      negotiable: _negotiable != d.negotiable ? _negotiable : null,
      condition: _condition.isNotEmpty && _condition != d.condition ? _condition : null,
      sellerType: _sellerType != d.sellerType ? _sellerType : null,
      city: changed(_city.text, d.city),
      area: changed(_area.text, d.area),
      address: changed(_address.text, d.address),
      pincode: changed(_pincode.text, d.pincode),
    );
    final nothing = fields.title == null &&
        fields.description == null &&
        fields.price == null &&
        fields.negotiable == null &&
        fields.condition == null &&
        fields.sellerType == null &&
        fields.city == null &&
        fields.area == null &&
        fields.address == null &&
        fields.pincode == null &&
        attrs == null &&
        _removed.isEmpty &&
        _added.isEmpty;
    if (nothing) {
      ekSnack(context, tr('No changes to save'));
      return;
    }

    setState(() => _saving = true);
    final r = await RemartEditService.update(
      listingId: d.id,
      title: fields.title,
      description: fields.description,
      price: fields.price,
      negotiable: fields.negotiable,
      condition: fields.condition,
      sellerType: fields.sellerType,
      city: fields.city,
      area: fields.area,
      address: fields.address,
      pincode: fields.pincode,
      attributes: attrs,
      deleteImageIds: _removed.toList(),
      newImages: [for (final p in _added) QnxFile('images', p.name, p.bytes)],
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!r.ok) {
      ekSnack(context, r.message, error: true);
      if (r.needsLogin) _goLogin();
      return;
    }
    ekSnack(context, r.message, success: true);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      backgroundColor: EK.bg,
      appBar: ekAppBar(tr('Edit item'), subtitle: tr(d?.title ?? widget.title)),
      body: _loading || d == null
          ? EkState(loading: _loading, error: _error, onRetry: _load)
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  if (d.status.isNotEmpty && d.status != 'active') _statusNote(d.status),
                  EkSection(
                    title: tr('Photos'),
                    subtitle: '$_photoCount/$_maxPhotos · tap ✕ to remove',
                    icon: Icons.photo_library_outlined,
                    children: [
                      EkPhotoGrid(
                        existing: [for (final i in d.images) EkExistingPhoto(i.id, i.url)],
                        removed: _removed,
                        added: _added,
                        max: _maxPhotos,
                        onToggleRemove: (id) => setState(() => _removed.contains(id) ? _removed.remove(id) : _removed.add(id)),
                        onRemoveNew: (i) => setState(() => _added.removeAt(i)),
                        onAdd: _addPhotos,
                      ),
                    ],
                  ),
                  EkSection(
                    title: tr('Item details'),
                    subtitle: tr([d.categoryName, d.subcategoryName].where((s) => s.isNotEmpty).join(' › ')),
                    icon: Icons.inventory_2_outlined,
                    children: [
                      EkField(
                        controller: _title,
                        label: tr('Title'),
                        maxLength: 120,
                        validator: (v) => (v ?? '').trim().length < 3 ? tr('Enter a title') : null,
                      ),
                      EkField(
                        controller: _desc,
                        label: tr('Description'),
                        maxLines: 5,
                        validator: (v) => (v ?? '').trim().isEmpty ? tr('Enter a description') : null,
                      ),
                      Text(tr('Condition'), style: DT.text(size: 12, weight: FontWeight.w700, color: EK.muted)),
                      const SizedBox(height: 8),
                      EkChoice<String>(
                        options: _conditions,
                        value: _condition,
                        onChanged: (v) => setState(() => _condition = v),
                      ),
                      const SizedBox(height: 14),
                      Text(tr('You are'), style: DT.text(size: 12, weight: FontWeight.w700, color: EK.muted)),
                      const SizedBox(height: 8),
                      EkChoice<String>(
                        options: [('individual', tr('Individual')), ('business', tr('Business'))],
                        value: _sellerType,
                        onChanged: (v) => setState(() => _sellerType = v),
                      ),
                      if (_attr.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        for (final e in _attr.entries)
                          EkField(controller: e.value, label: tr(_labelOf(e.key))),
                      ],
                    ],
                  ),
                  EkSection(
                    title: tr('Price'),
                    icon: Icons.currency_rupee_rounded,
                    children: [
                      EkField(
                        controller: _price,
                        label: tr('Price'),
                        prefix: '₹ ',
                        keyboard: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          final p = double.tryParse((v ?? '').trim().replaceAll(',', ''));
                          return p == null || p <= 0 ? tr('Enter a valid price') : null;
                        },
                      ),
                      EkSwitch(
                        label: tr('Price is negotiable'),
                        value: _negotiable,
                        onChanged: (v) => setState(() => _negotiable = v),
                      ),
                    ],
                  ),
                  EkSection(
                    title: tr('Location'),
                    icon: Icons.location_on_outlined,
                    children: [
                      EkField(
                        controller: _city,
                        label: tr('City'),
                        validator: (v) => (v ?? '').trim().isEmpty ? tr('Enter the city') : null,
                      ),
                      EkField(controller: _area, label: tr('Area / locality')),
                      EkField(controller: _address, label: tr('Address'), maxLines: 2),
                      EkField(
                        controller: _pincode,
                        label: tr('Pincode'),
                        keyboard: TextInputType.number,
                        maxLength: 6,
                        validator: (v) {
                          final s = (v ?? '').trim();
                          return s.isEmpty || RegExp(r'^\d{6}$').hasMatch(s) ? null : tr('Enter a 6-digit pincode');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  EkButton(label: tr('Save changes'), icon: Icons.check_rounded, busy: _saving, onPressed: _save),
                ],
              ),
            ),
    );
  }

  Widget _statusNote(String status) {
    final text = switch (status) {
      'pending' => tr('This item is waiting for approval / payment. Changes are saved but it stays pending.'),
      'sold' => tr('This item is marked as sold and is not shown to buyers.'),
      'expired' => tr('This item has expired. Changes are saved but it is not shown to buyers.'),
      _ => tr('Status: {0}', [status]),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFC2410C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tr(text), style: DT.text(size: 12.5, color: const Color(0xFFC2410C), height: 1.4)),
          ),
        ],
      ),
    );
  }
}
