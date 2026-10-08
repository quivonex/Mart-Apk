// lib/screens/property_create_screen.dart
//
// List a property (Real Estate) – in-app form, home-screen design.
//   POST real_estate/property/create/  via PropertyCreateService
//   Photos (image_picker) + PDF documents (file_picker) – brochure, RERA, approvals…
//   New listings are sent as status "pending" (admin approves -> active).

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/design_tokens.dart';
import '../models/property_model.dart';
import '../services/property_create_service.dart';
import '../services/real_estate_service.dart';
import '../widgets/catalog_widgets.dart' show DecimalInputFormatter;
import '../widgets/product_ui.dart';
import 'dart:convert';

class _Unit {
  String name;
  int bedrooms;
  int bathrooms;
  String carpetArea;
  String price;
  String booking;
  _Unit({
    required this.name,
    this.bedrooms = 0,
    this.bathrooms = 0,
    this.carpetArea = '',
    this.price = '',
    this.booking = '',
  });
}

class PropertyCreateScreen extends StatefulWidget {
  const PropertyCreateScreen({super.key});

  @override
  State<PropertyCreateScreen> createState() => _PropertyCreateScreenState();
}

class _PropertyCreateScreenState extends State<PropertyCreateScreen> {
  static const _maxPhotos = 10;
  static const _maxDocs = 10;
  static const _maxDocBytes = 10 * 1024 * 1024;

  static const _types = <(String, String, IconData)>[
    ('flat', 'Flat / Apartment', Icons.apartment_rounded),
    ('villa', 'Villa / Bungalow', Icons.villa_rounded),
    ('plot', 'Plot / Land', Icons.landscape_rounded),
    ('commercial', 'Commercial', Icons.business_rounded),
    ('shop', 'Shop / Retail', Icons.storefront_rounded),
    ('office', 'Office', Icons.work_outline_rounded),
    ('warehouse', 'Warehouse', Icons.warehouse_rounded),
    ('other', 'Other', Icons.home_work_outlined),
  ];

  /// Backend PropertyDocument.DocumentType choices (Brochure is stored as "other").
  static const _docTypes = <(String, String)>[
    ('other', 'Brochure / Other'),
    ('rera', 'RERA document'),
    ('approval', 'Approval'),
    ('noc', 'NOC'),
    ('agreement', 'Agreement'),
    ('sale_deed', 'Sale deed'),
    ('registration', 'Registration'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _title = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  final _area = TextEditingController();
  final _address = TextEditingController();
  final _landmark = TextEditingController();
  final _pincode = TextEditingController();
  final _totalArea = TextEditingController();
  final _plotArea = TextEditingController();
  final _floors = TextEditingController(text: '1');
  final _towers = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _rera = TextEditingController();
  final _reraWebsite = TextEditingController();
  final _website = TextEditingController();
  final _mapLink = TextEditingController();

  String _type = 'flat';
  String _transaction = 'sale';
  String _condition = 'new';
  bool _negotiable = true;
  bool _underConstruction = false;
  DateTime? _possession;
  double _completion = 0;
  double? _lat;
  double? _lng;
  bool _locating = false;

  final List<_Unit> _units = [];
  List<Amenity> _amenities = [];
  bool _loadingAmenities = true;
  final Set<int> _selectedAmenities = {};

  final List<XFile> _photos = [];
  final List<Uint8List> _photoBytes = [];
  final List<PropertyDocumentUpload> _docs = [];

  bool _submitAttempted = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAmenities();
  }

  @override
  void dispose() {
    for (final c in [
      _title, _description, _city, _area, _address, _landmark, _pincode, _totalArea,
      _plotArea, _floors, _towers, _price, _rera, _reraWebsite, _website, _mapLink,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAmenities() async {
    final r = await RealEstateService.getAmenitiesList();
    if (!mounted) return;
    setState(() {
      _loadingAmenities = false;
      _amenities = [...r.data]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: error ? DT.error : null));
  }

  bool get _hasInput =>
      _title.text.isNotEmpty || _description.text.isNotEmpty || _photos.isNotEmpty || _docs.isNotEmpty;

  // ── Location ───────────────────────────────────────────
  Future<void> _useLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Turn on location services and try again.', error: true);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _snack('Location permission is needed to capture coordinates.', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        if (_mapLink.text.trim().isEmpty) {
          _mapLink.text = 'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
        }
      });
      _snack('Location captured');
    } catch (e) {
      _snack('Could not get location: $e', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ── Media ──────────────────────────────────────────────
  Future<void> _pickPhotos() async {
    final room = _maxPhotos - _photos.length;
    if (room <= 0) return;
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1800);
      final files = <XFile>[];
      final bytes = <Uint8List>[];
      for (final x in picked.take(room)) {
        final b = await x.readAsBytes();
        if (b.lengthInBytes > 8 * 1024 * 1024) continue;
        files.add(x);
        bytes.add(b);
      }
      if (!mounted) return;
      setState(() {
        _photos.addAll(files);
        _photoBytes.addAll(bytes);
      });
    } catch (e) {
      _snack('Could not pick photos: $e', error: true);
    }
  }

  Future<void> _pickDocuments() async {
    final room = _maxDocs - _docs.length;
    if (room <= 0) {
      _snack('You can attach up to $_maxDocs PDFs.', error: true);
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: true,
        withData: true, // bytes work on Android, iOS and web
      );
      if (result == null) return;
      var skipped = 0;
      final added = <PropertyDocumentUpload>[];
      for (final f in result.files.take(room)) {
        final bytes = f.bytes;
        if (bytes == null || !f.name.toLowerCase().endsWith('.pdf') || bytes.lengthInBytes > _maxDocBytes) {
          skipped++;
          continue;
        }
        added.add(PropertyDocumentUpload(
          fileName: f.name,
          bytes: bytes,
          type: _docs.isEmpty && added.isEmpty ? 'other' : 'other',
          title: f.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
        ));
      }
      if (!mounted) return;
      setState(() => _docs.addAll(added));
      if (skipped > 0) _snack('$skipped file(s) skipped – PDF only, up to 10 MB each.', error: true);
    } catch (e) {
      _snack('Could not open files: $e', error: true);
    }
  }

  String _size(int bytes) =>
      bytes < 1024 * 1024 ? '${(bytes / 1024).toStringAsFixed(0)} KB' : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  // ── Units / price ──────────────────────────────────────
  Future<void> _editUnit([int? index]) async {
    final existing = index == null ? null : _units[index];
    final result = await showModalBottomSheet<_Unit>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UnitSheet(existing: existing, taken: {
        for (var i = 0; i < _units.length; i++)
          if (i != index) _units[i].name.trim().toLowerCase()
      }),
    );
    if (result == null || !mounted) return;
    setState(() => index == null ? _units.add(result) : _units[index] = result);
  }

  String _num(String s) {
    final d = double.tryParse(s.trim());
    if (d == null) return s.trim();
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  // ── Submit ─────────────────────────────────────────────
  Map<String, String> _buildFields() {
    final units = [..._units];
    final quickPrice = double.tryParse(_price.text.trim());
    if (units.isEmpty && quickPrice != null && quickPrice > 0) {
      units.add(_Unit(name: 'Standard', price: _price.text.trim(), carpetArea: _totalArea.text.trim()));
    }
    final priced = units.where((u) => (double.tryParse(u.price) ?? 0) > 0).toList();

    String d(DateTime x) => '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';

    final f = <String, String>{
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'property_type': _type,
      'transaction_type': _transaction,
      'property_condition': _condition,
      'status': 'pending', // admin approves -> active
      'city': _city.text.trim(),
      'area': _area.text.trim(),
      'address': _address.text.trim(),
      'landmark': _landmark.text.trim(),
      'pincode': _pincode.text.trim(),
      'total_floors': '${int.tryParse(_floors.text.trim()) ?? 1}',
      'total_towers': '${int.tryParse(_towers.text.trim()) ?? 1}',
      'is_negotiable': '$_negotiable',
      'is_under_construction': '$_underConstruction',
      'ready_to_move': '${!_underConstruction}',
      'completion_percentage': '${_underConstruction ? _completion.round() : 100}',
      if (_totalArea.text.trim().isNotEmpty) 'total_area': _num(_totalArea.text),
      if (_plotArea.text.trim().isNotEmpty) 'plot_area': _num(_plotArea.text),
      if (_lat != null) 'latitude': _lat!.toStringAsFixed(7),
      if (_lng != null) 'longitude': _lng!.toStringAsFixed(7),
      if (_mapLink.text.trim().isNotEmpty) 'google_location_url': _mapLink.text.trim(),
      if (_rera.text.trim().isNotEmpty) 'rera_number': _rera.text.trim(),
      if (_reraWebsite.text.trim().isNotEmpty) 'rera_website': _reraWebsite.text.trim(),
      if (_website.text.trim().isNotEmpty) 'property_website_url': _website.text.trim(),
      if (_underConstruction && _possession != null) 'possession_date': d(_possession!),
      if (_selectedAmenities.isNotEmpty) 'amenities': jsonEncode(_selectedAmenities.toList()),
    };

    if (units.isNotEmpty) {
      f['flat_types'] = jsonEncode([
        for (final u in units)
          {
            'flat_type': u.name.trim(),
            if (u.carpetArea.trim().isNotEmpty) 'carpet_area': _num(u.carpetArea),
            'bedrooms': u.bedrooms,
            'bathrooms': u.bathrooms,
          }
      ]);
    }
    if (priced.isNotEmpty) {
      // One floor entry carries the price list (the backend links slabs by name + floor no.).
      f['floors'] = jsonEncode([
        {'floor_number': 1, 'floor_name': 'All floors'}
      ]);
      f['pricing_slabs'] = jsonEncode([
        for (final u in priced)
          {
            'flat_type': u.name.trim(),
            'floor': 1,
            'base_price': _num(u.price),
            if (u.booking.trim().isNotEmpty) 'booking_amount': _num(u.booking),
          }
      ]);
    }
    return f;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitAttempted = true);
    if (!_formKey.currentState!.validate()) {
      _snack('Please fix the highlighted fields', error: true);
      return;
    }
    if (_photos.isEmpty) {
      _snack('Add at least one photo of the property', error: true);
      return;
    }
    setState(() => _saving = true);
    final r = await PropertyCreateService.createProperty(
      fields: _buildFields(),
      images: _photos,
      documents: _docs,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!r.ok) {
      _snack(r.message, error: true);
      return;
    }
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: DT.emerald50, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: DT.emerald700, size: 32),
        ),
        title: const Text('Property submitted', textAlign: TextAlign.center),
        content: Text(
          '${_title.text.trim()} was sent for admin approval'
              '${_docs.isNotEmpty ? ' with ${_docs.length} document${_docs.length == 1 ? '' : 's'}' : ''}.\n\n'
              '${r.subscriptionRequired ? 'A listing subscription is needed to make it live.' : (r.freeDays != null && r.freeDays! > 0 ? 'Your listing is free for ${r.freeDays} days.' : '')}',
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasInput && !_saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard this listing?'),
            content: const Text('The details you entered will be lost.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: DT.error),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: DT.background,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('List a property', style: DT.text(size: 18, weight: FontWeight.w700)),
              Text('Real Estate — Buy, Sell & Rent', style: DT.text(size: 12, color: DT.slate500)),
            ],
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _basics(),
                const SizedBox(height: 16),
                _location(),
                const SizedBox(height: 16),
                _size(),
                const SizedBox(height: 16),
                _pricing(),
                const SizedBox(height: 16),
                _project(),
                const SizedBox(height: 16),
                _amenitiesSection(),
                const SizedBox(height: 16),
                _photosSection(),
                const SizedBox(height: 16),
                _documentsSection(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _footer(),
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {bool required = false,
        String? hint,
        IconData? icon,
        int maxLines = 1,
        TextInputType? keyboard,
        List<TextInputFormatter>? formatters,
        String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PxLabel(label, required: required, optional: !required),
        PxTextField(
          controller: c,
          hint: hint,
          icon: icon,
          iconColor: required ? PX.royal600 : null,
          maxLines: maxLines,
          tinted: maxLines > 1,
          keyboardType: keyboard,
          inputFormatters: formatters,
          capitalization: maxLines > 1 ? TextCapitalization.sentences : TextCapitalization.words,
          validator: validator ??
              (required ? (v) => (v ?? '').trim().isEmpty ? '$label is required' : null : null),
        ),
      ],
    );
  }

  Widget _basics() => PxSection(
    title: 'Property basics',
    subtitle: 'What are you listing?',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field('Listing title', _title,
            required: true, hint: 'e.g. Skyline Heights – 2 & 3 BHK', icon: Icons.title_rounded),
        const SizedBox(height: 14),
        const PxLabel('Property type', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (v, label, icon) in _types)
              ChoiceChip(
                avatar: Icon(icon, size: 16, color: _type == v ? Colors.white : PX.royal600),
                label: Text(label),
                selected: _type == v,
                showCheckmark: false,
                labelStyle: DT.text(
                    size: 12.5, weight: FontWeight.w700, color: _type == v ? Colors.white : PX.royal600),
                onSelected: (_) => setState(() => _type = v),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const PxLabel('Listing for', required: true),
        PxSegmented<String>(
          options: const [('sale', 'Sale'), ('rent', 'Rent'), ('lease', 'Lease'), ('pg', 'PG')],
          value: _transaction,
          onChanged: (v) => setState(() => _transaction = v),
        ),
        const SizedBox(height: 14),
        const PxLabel('Condition'),
        PxSegmented<String>(
          options: const [('new', 'New property'), ('resale', 'Resale')],
          value: _condition,
          onChanged: (v) => setState(() => _condition = v),
        ),
        const SizedBox(height: 14),
        _field('Description', _description,
            required: true,
            hint: 'Highlights, connectivity, nearby schools / offices…',
            maxLines: 5,
            validator: (v) => (v ?? '').trim().length < 20 ? 'Write at least 20 characters' : null),
      ],
    ),
  );

  Widget _location() => PxSection(
    title: 'Location',
    subtitle: 'Where is the property?',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _field('City', _city, required: true, hint: 'Pune', icon: Icons.location_city_outlined)),
          const SizedBox(width: 10),
          Expanded(child: _field('Area / locality', _area, required: true, hint: 'Wakad')),
        ]),
        const SizedBox(height: 14),
        _field('Full address', _address, required: true, hint: 'Building, street', maxLines: 2),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 3,
            child: _field('Landmark', _landmark, hint: 'Near…', icon: Icons.place_outlined),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _field('Pincode', _pincode,
                required: true,
                hint: '6 digits',
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                validator: (v) => (v ?? '').trim().length != 6 ? '6-digit pincode' : null),
          ),
        ]),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _locating ? null : _useLocation,
          icon: _locating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location_rounded, size: 18),
          label: Text(_lat == null
              ? 'Use my current location'
              : 'Location set · ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'),
        ),
        const SizedBox(height: 12),
        _field('Google Maps link', _mapLink, hint: 'https://maps.google.com/…', icon: Icons.map_outlined, keyboard: TextInputType.url),
      ],
    ),
  );

  Widget _size() => PxSection(
    title: 'Size & building',
    child: Column(
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _field('Total area (sq ft)', _totalArea,
                hint: 'e.g. 1200',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                formatters: [DecimalInputFormatter()]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _field('Plot area (sq ft)', _plotArea,
                hint: 'Optional',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                formatters: [DecimalInputFormatter()]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _field('Floors', _floors,
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _field('Towers', _towers,
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)]),
          ),
        ]),
      ],
    ),
  );

  Widget _pricing() => PxSection(
    title: 'Price & configurations',
    subtitle: 'Add each unit type (e.g. 2 BHK, 3 BHK) or just one expected price',
    trailing: PxLinkButton(label: 'Add unit', icon: Icons.add_rounded, onTap: () => _editUnit()),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_units.isEmpty) ...[
          _field('Expected price (₹)', _price,
              hint: 'Leave empty for "Price on request"',
              icon: Icons.currency_rupee_rounded,
              keyboard: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)]),
        ] else
          for (var i = 0; i < _units.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              decoration: BoxDecoration(
                color: DT.slate50,
                borderRadius: BorderRadius.circular(DT.rMd),
                border: Border.all(color: DT.slate200),
              ),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: PX.royal50, borderRadius: BorderRadius.circular(DT.rSm)),
                  child: const Icon(Icons.bed_outlined, color: PX.royal600, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_units[i].name, style: DT.text(size: 14, weight: FontWeight.w800)),
                    Text(
                      [
                        if (_units[i].bedrooms > 0) '${_units[i].bedrooms} bed',
                        if (_units[i].bathrooms > 0) '${_units[i].bathrooms} bath',
                        if (_units[i].carpetArea.isNotEmpty) '${_units[i].carpetArea} sq ft',
                        (double.tryParse(_units[i].price) ?? 0) > 0
                            ? formatRupees(double.parse(_units[i].price))
                            : 'Price on request',
                      ].join(' · '),
                      style: DT.text(size: 12, color: DT.slate500),
                    ),
                  ]),
                ),
                IconButton(onPressed: () => _editUnit(i), icon: const Icon(Icons.edit_outlined, size: 19)),
                IconButton(
                  onPressed: () => setState(() => _units.removeAt(i)),
                  icon: const Icon(Icons.delete_outline_rounded, size: 19, color: DT.error),
                ),
              ]),
            ),
        const SizedBox(height: 6),
        SwitchListTile(
          value: _negotiable,
          onChanged: (v) => setState(() => _negotiable = v),
          contentPadding: EdgeInsets.zero,
          title: Text('Price is negotiable', style: DT.text(size: 13.5, weight: FontWeight.w600)),
        ),
      ],
    ),
  );

  Widget _project() => PxSection(
    title: 'Project status & RERA',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PxSegmented<bool>(
          options: const [(false, 'Ready to move'), (true, 'Under construction')],
          value: _underConstruction,
          onChanged: (v) => setState(() => _underConstruction = v),
        ),
        if (_underConstruction) ...[
          const SizedBox(height: 14),
          const PxLabel('Possession date'),
          OutlinedButton.icon(
            onPressed: () async {
              final now = DateTime.now();
              final d = await showDatePicker(
                context: context,
                initialDate: _possession ?? DateTime(now.year + 1, now.month),
                firstDate: now,
                lastDate: DateTime(now.year + 15),
              );
              if (d != null) setState(() => _possession = d);
            },
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(_possession == null
                ? 'Select date'
                : '${_possession!.day}/${_possession!.month}/${_possession!.year}'),
          ),
          const SizedBox(height: 12),
          PxLabel('Construction progress',
              trailing: Text('${_completion.round()}%',
                  style: DT.text(size: 12.5, weight: FontWeight.w800, color: PX.royal600))),
          Slider(
            value: _completion,
            max: 100,
            divisions: 20,
            onChanged: (v) => setState(() => _completion = v),
          ),
        ],
        const SizedBox(height: 10),
        _field('RERA number', _rera, hint: 'e.g. P52100012345', icon: Icons.verified_outlined),
        const SizedBox(height: 14),
        _field('RERA website', _reraWebsite, hint: 'maharera.mahaonline.gov.in', icon: Icons.link_rounded, keyboard: TextInputType.url),
        const SizedBox(height: 14),
        _field('Project website', _website, hint: 'yourproject.com', icon: Icons.language_rounded, keyboard: TextInputType.url),
      ],
    ),
  );

  Widget _amenitiesSection() => PxSection(
    title: 'Amenities',
    subtitle: _selectedAmenities.isEmpty ? 'Tap to select' : '${_selectedAmenities.length} selected',
    child: _loadingAmenities
        ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
        : _amenities.isEmpty
        ? Text('No amenities available', style: DT.text(size: 12.5, color: DT.slate500))
        : Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in _amenities)
          FilterChip(
            label: Text(a.name.trim()),
            selected: _selectedAmenities.contains(a.id),
            showCheckmark: false,
            labelStyle: DT.text(
              size: 12.5,
              weight: FontWeight.w600,
              color: _selectedAmenities.contains(a.id) ? Colors.white : PX.royal600,
            ),
            onSelected: (sel) => setState(() {
              sel ? _selectedAmenities.add(a.id) : _selectedAmenities.remove(a.id);
            }),
          ),
      ],
    ),
  );

  Widget _photosSection() {
    final missing = _submitAttempted && _photos.isEmpty;
    return PxSection(
      title: 'Photos',
      subtitle: 'Exterior, rooms, floor plan – up to $_maxPhotos',
      trailing: Text('${_photos.length}/$_maxPhotos', style: DT.text(size: 12, weight: FontWeight.w700, color: DT.slate500)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _photoBytes.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(DT.rMd),
                        child: Image.memory(_photoBytes[i], width: 92, height: 92, fit: BoxFit.cover),
                      ),
                      if (i == 0)
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: PxPill(text: 'Cover', bg: PX.royal600, fg: Colors.white),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _photos.removeAt(i);
                            _photoBytes.removeAt(i);
                          }),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 13, color: Colors.white),
                          ),
                        ),
                      ),
                    ]),
                  ),
                if (_photos.length < _maxPhotos)
                  GestureDetector(
                    onTap: _pickPhotos,
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: PX.royal50,
                        borderRadius: BorderRadius.circular(DT.rMd),
                        border: Border.all(color: missing ? DT.error : PX.royal200),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.add_photo_alternate_outlined, color: PX.royal600),
                        const SizedBox(height: 4),
                        Text('Add', style: DT.text(size: 11.5, weight: FontWeight.w700, color: PX.royal600)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          if (missing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Add at least one photo', style: DT.text(size: 11.5, color: DT.error)),
            ),
        ],
      ),
    );
  }

  Widget _documentsSection() => PxSection(
    title: 'Documents (PDF)',
    subtitle: 'Brochure, RERA certificate, approvals, floor plans – PDF up to 10 MB each',
    trailing: PxLinkButton(label: 'Upload PDF', icon: Icons.upload_file_rounded, onTap: _pickDocuments),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_docs.isEmpty)
          InkWell(
            onTap: _pickDocuments,
            borderRadius: BorderRadius.circular(DT.rMd),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: DT.slate50,
                borderRadius: BorderRadius.circular(DT.rMd),
                border: Border.all(color: DT.slate200),
              ),
              child: Column(children: [
                const Icon(Icons.picture_as_pdf_rounded, size: 34, color: Color(0xFFDC2626)),
                const SizedBox(height: 6),
                Text('Tap to upload PDF documents', style: DT.text(size: 13, weight: FontWeight.w700, color: DT.onyx800)),
                Text('Optional – buyers trust listings with documents', style: DT.text(size: 11.5, color: DT.slate500)),
              ]),
            ),
          )
        else
          for (var i = 0; i < _docs.length; i++) _docTile(i),
      ],
    ),
  );

  Widget _docTile(int i) {
    final d = _docs[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(DT.rSm)),
              child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFDC2626), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: DT.text(size: 13, weight: FontWeight.w700)),
                Text(_size(d.sizeBytes), style: DT.text(size: 11.5, color: DT.slate500)),
              ]),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: () => setState(() => _docs.removeAt(i)),
              icon: const Icon(Icons.delete_outline_rounded, color: DT.error, size: 20),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: d.type,
                isExpanded: true,
                decoration: pxInputDecoration(dense: true),
                items: [
                  for (final (v, label) in _docTypes)
                    DropdownMenuItem(value: v, child: Text(label, style: DT.text(size: 12.5))),
                ],
                onChanged: (v) => setState(() => d.type = v ?? 'other'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: d.title,
                style: DT.text(size: 12.5),
                decoration: pxInputDecoration(hint: 'Title', dense: true),
                onChanged: (v) => d.title = v,
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _footer() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: DT.slate200)),
      boxShadow: PX.stickyShadow,
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)),
              const SizedBox(width: 10),
              Text('Uploading listing…', style: DT.text(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
            ])
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.check_rounded, size: 20),
              const SizedBox(width: 8),
              Text('Submit property for approval',
                  style: DT.text(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ),
      ),
    ),
  );
}

// =====================================================================
// UNIT SHEET (2 BHK / 3 BHK …)
// =====================================================================
class _UnitSheet extends StatefulWidget {
  final _Unit? existing;
  final Set<String> taken;
  const _UnitSheet({this.existing, required this.taken});

  @override
  State<_UnitSheet> createState() => _UnitSheetState();
}

class _UnitSheetState extends State<_UnitSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _carpet = TextEditingController(text: widget.existing?.carpetArea ?? '');
  late final _price = TextEditingController(text: widget.existing?.price ?? '');
  late final _booking = TextEditingController(text: widget.existing?.booking ?? '');
  late int _bed = widget.existing?.bedrooms ?? 2;
  late int _bath = widget.existing?.bathrooms ?? 2;

  @override
  void dispose() {
    _name.dispose();
    _carpet.dispose();
    _price.dispose();
    _booking.dispose();
    super.dispose();
  }

  Widget _counter(String label, int value, ValueChanged<int> onChanged) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PxLabel(label),
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: DT.slate200),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(onPressed: value > 0 ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove_rounded)),
          Text('$value', style: DT.text(size: 15, weight: FontWeight.w800)),
          IconButton(onPressed: value < 20 ? () => onChanged(value + 1) : null, icon: const Icon(Icons.add_rounded)),
        ]),
      ),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              Text(widget.existing == null ? 'Add unit type' : 'Edit unit type',
                  style: DT.text(size: 17, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, children: [
                for (final s in const ['1 BHK', '2 BHK', '3 BHK', '4 BHK', 'Studio', 'Shop', 'Office'])
                  ActionChip(label: Text(s), onPressed: () => setState(() => _name.text = s)),
              ]),
              const SizedBox(height: 12),
              const PxLabel('Unit name', required: true),
              PxTextField(
                controller: _name,
                hint: 'e.g. 2 BHK',
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Enter a name';
                  if (widget.taken.contains(t.toLowerCase())) return 'This unit already exists';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                _counter('Bedrooms', _bed, (v) => setState(() => _bed = v)),
                const SizedBox(width: 10),
                _counter('Bathrooms', _bath, (v) => setState(() => _bath = v)),
              ]),
              const SizedBox(height: 12),
              const PxLabel('Carpet area (sq ft)', optional: true),
              PxTextField(
                controller: _carpet,
                hint: 'e.g. 750',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [DecimalInputFormatter()],
              ),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const PxLabel('Price (₹)', optional: true),
                    PxTextField(
                      controller: _price,
                      hint: '6500000',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const PxLabel('Booking (₹)', optional: true),
                    PxTextField(
                      controller: _booking,
                      hint: '100000',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    Navigator.pop(
                      context,
                      _Unit(
                        name: _name.text.trim(),
                        bedrooms: _bed,
                        bathrooms: _bath,
                        carpetArea: _carpet.text.trim(),
                        price: _price.text.trim(),
                        booking: _booking.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Save unit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}