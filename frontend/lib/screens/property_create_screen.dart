// lib/screens/property_create_screen.dart
//
// List a property (Real Estate) — redesigned to match code.html:
//   • Navy "Add Property" hero
//   • Property Subcategory tiles (Flat / Villa / Plot / Commercial)
//   • Transaction Type pills (Sale / Rent / Lease / PG)
//   • Construction Stage pills
//   • Basic Information (Title, Property Type, Condition, Description)
//   • Multiple Configuration cards (flat_types) with counters
//   • Location Details with "Get Live Location" GPS button + interactive map
//   • Floors + Pricing Slabs with Add buttons
//   • Amenities checklist
//   • Media & Documents (photos + PDF)
//   • Bottom bar: Reset Form + Publish Listing
//
// POST real_estate/property/create/ via PropertyCreateService.

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../constants/design_tokens.dart';
import '../models/property_model.dart';
import '../services/home_service.dart';
import '../services/property_create_service.dart';
import '../services/real_estate_service.dart';
import '../widgets/catalog_widgets.dart' show DecimalInputFormatter;
import '../widgets/product_ui.dart';
import 'package:qnx_mart/l10n/app_language.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kBrandDark = Color(0xFF062A50);
const _kBrandLight = Color(0xFF1E5A9C);
const _kRed = Color(0xFFC62828);
const _kRedBg = Color(0xFFFEF2F2);
const _kRedLine = Color(0xFFFECACA);
const _kHeader = LinearGradient(
  colors: [_kBrandDark, _kBrand, _kBrandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ─────────────────────────────────────────────────────────────────────
// Local palette (matches code.html / app theme)
// ─────────────────────────────────────────────────────────────────────
class _PC {
  static const navy = Color(0xFF062A50);
  static const navyDeep = Color(0xFF0F172A);
  static const blue600 = Color(0xFF093C71);
  static const blue500 = Color(0xFF093C71);
  static const blue50 = Color(0xFFEAF1F9);
  static const blue100 = Color(0xFFC9DBEE);
  static const blue200 = Color(0xFFC9DBEE);
  static const indigo50 = Color(0xFFEAF1F9);
  static const indigo600 = Color(0xFF062A50);
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald100 = Color(0xFFD1FAE5);
  static const emerald200 = Color(0xFFA7F3D0);
  static const emerald600 = Color(0xFF059669);
  static const emerald700 = Color(0xFF047857);
  static const rose50 = Color(0xFFFEF2F2);
  static const rose200 = Color(0xFFFECACA);
  static const rose500 = Color(0xFFC62828);
  static const rose600 = Color(0xFFC62828);
  static const amber500 = Color(0xFFF7931E);
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
  static const orange500 = Color(0xFFEA580C);
  static const bg = Color(0xFFF4F7FB);
}

// ─────────────────────────────────────────────────────────────────────
// Local data classes
// ─────────────────────────────────────────────────────────────────────
class _Unit {
  String name;
  int bedrooms;
  int bathrooms;
  int balconies;
  int parking;
  String areaSqft;
  String carpetArea;
  String builtUpArea;
  String balconyArea;
  String description;
  bool isAvailable;
  String price;
  String booking;

  _Unit({
    required this.name,
    this.bedrooms = 0,
    this.bathrooms = 0,
    this.balconies = 0,
    this.parking = 0,
    this.areaSqft = '',
    this.carpetArea = '',
    this.builtUpArea = '',
    this.balconyArea = '',
    this.description = '',
    this.isAvailable = true,
    this.price = '',
    this.booking = '',
  });
}

class _FloorDraft {
  int floorNumber;
  String floorName;
  int totalUnits;
  int availableUnits;

  _FloorDraft({
    required this.floorNumber,
    required this.floorName,
    this.totalUnits = 0,
    this.availableUnits = 0,
  });
}

class _PricingSlabDraft {
  String flatType;
  int floor;
  String basePrice;
  String pricePerSqft;
  String bookingAmount;
  String discountPercent;
  String gstPercent;

  _PricingSlabDraft({
    this.flatType = '',
    this.floor = 1,
    this.basePrice = '',
    this.pricePerSqft = '',
    this.bookingAmount = '',
    this.discountPercent = '',
    this.gstPercent = '',
  });
}

// ─────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────
class PropertyCreateScreen extends StatefulWidget {
  const PropertyCreateScreen({super.key});

  @override
  State<PropertyCreateScreen> createState() => _PropertyCreateScreenState();
}

class _PropertyCreateScreenState extends State<PropertyCreateScreen> {
  static const _maxPhotos = 10;
  static const _maxDocs = 10;
  static const _maxDocBytes = 10 * 1024 * 1024;
  static const _maxVideos = 3;
  static const _maxVideoBytes = 100 * 1024 * 1024;

  static const _types = <(String, String, String)>[
    ('flat', 'Flat / Apt', '🏢'),
    ('villa', 'Villa / Bungalow', '🏡'),
    ('plot', 'Plot / Land', '📐'),
    ('commercial', 'Commercial', '🏬'),
    ('shop', 'Shop / Retail', '🏪'),
    ('office', 'Office', '💼'),
    ('warehouse', 'Warehouse', '🏭'),
    ('other', 'Other', '🏗️'),
  ];

  static const _propertyConditions = <(String, String)>[
    ('new', 'New Launch / Brand New'),
    ('resale', 'Resale / Well Maintained'),
    ('renovation', 'Under Renovation'),
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
  bool _featured = false;
  bool _underConstruction = false;
  DateTime? _possession;
  double _completion = 0;
  double? _lat;
  double? _lng;
  double? _previewLat;
  double? _previewLng;
  bool _locating = false;

  final List<_Unit> _units = [];
  final List<_FloorDraft> _floorDrafts = [];
  final List<_PricingSlabDraft> _slabDrafts = [];

  List<Amenity> _amenities = [];
  bool _loadingAmenities = true;
  final Set<int> _selectedAmenities = {};

  final List<XFile> _photos = [];
  final List<Uint8List> _photoBytes = [];
  final List<PropertyDocumentUpload> _docs = [];
  final List<XFile> _videos = [];
  final List<int> _videoSizes = [];

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
      _title, _description, _city, _area, _address, _landmark, _pincode,
      _totalArea, _plotArea, _floors, _towers, _price, _rera, _reraWebsite,
      _website, _mapLink,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // =====================================================================
  // AMENITIES
  // =====================================================================
  Future<void> _loadAmenities() async {
    final r = await RealEstateService.getAmenitiesList();
    if (!mounted) return;
    setState(() {
      _loadingAmenities = false;
      _amenities = [...r.data]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(tr(msg)),
        backgroundColor: error ? _kRed : null,
      ));
  }

  bool get _hasInput =>
      _title.text.isNotEmpty ||
          _description.text.isNotEmpty ||
          _photos.isNotEmpty ||
          _docs.isNotEmpty ||
          _units.isNotEmpty;

  // =====================================================================
  // LOCATION
  // =====================================================================
  Future<void> _useLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack(tr('Turn on location services and try again.'), error: true);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack(tr('Location permission is needed to capture coordinates.'),
            error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _previewLat = pos.latitude;
        _previewLng = pos.longitude;
        if (_mapLink.text.trim().isEmpty) {
          _mapLink.text =
          'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
        }
      });
      _snack(tr('Location captured'));
    } catch (e) {
      _snack(tr('Could not get location: {0}', [e]), error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _snack(tr('Could not open link'), error: true);
      }
    } catch (e) {
      _snack(tr('Could not open link: {0}', [e]), error: true);
    }
  }

  // =====================================================================
  // MEDIA
  // =====================================================================
  Future<void> _pickPhotos() async {
    final room = _maxPhotos - _photos.length;
    if (room <= 0) return;
    try {
      final picked =
      await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1800);
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
      _snack(tr('Could not pick photos: {0}', [e]), error: true);
    }
  }

  // ---------------------------------------------------------------------
  // VIDEOS  (camera or gallery, bytes based → works on web too)
  // ---------------------------------------------------------------------
  Future<ImageSource?> _askVideoSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _PC.slate200,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Text(tr('Add property video'),
                  style: DT.text(size: 16, weight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(tr('Walkthrough, drone shot or sample flat tour'),
                  style: DT.text(size: 12, color: _PC.slate500)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _videoSourceTile(ctx, Icons.videocam_rounded,
                        tr('Record video'), ImageSource.camera),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _videoSourceTile(ctx, Icons.video_library_rounded,
                        tr('From gallery'), ImageSource.gallery),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _videoSourceTile(
      BuildContext ctx, IconData icon, String label, ImageSource src) {
    return Material(
      color: _PC.blue50,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(ctx, src),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _PC.blue200),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    gradient: _kHeader, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 8),
              Text(tr(label),
                  style: DT.text(
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: _PC.slate800)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickVideo() async {
    if (_videos.length >= _maxVideos) {
      _snack(tr('You can add up to {0} videos.', [_maxVideos]), error: true);
      return;
    }
    final src = await _askVideoSource();
    if (src == null) return;
    try {
      final v = await _picker.pickVideo(
          source: src, maxDuration: const Duration(minutes: 5));
      if (v == null) return;
      final size = await v.length();
      if (size > _maxVideoBytes) {
        _snack(tr('Video is {0}. Max allowed is 100 MB.', [_fileSize(size)]),
            error: true);
        return;
      }
      if (!mounted) return;
      setState(() {
        _videos.add(v);
        _videoSizes.add(size);
      });
    } catch (e) {
      _snack(tr('Could not pick video: {0}', [e]), error: true);
    }
  }

  // ---------------------------------------------------------------------
  // ADD AMENITY (small form → real_estate/amenity/create/)
  // ---------------------------------------------------------------------
  Future<void> _openAddAmenity() async {
    final created = await showModalBottomSheet<Amenity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _AmenitySheet(existing: _amenities),
    );
    if (created == null || !mounted) return;
    setState(() {
      if (!_amenities.any((a) => a.id == created.id)) {
        _amenities = [..._amenities, created]
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }
      _selectedAmenities.add(created.id);
    });
    _snack(tr('"{0}" added and selected', [created.name]));
  }

  Future<void> _pickDocuments() async {
    final room = _maxDocs - _docs.length;
    if (room <= 0) {
      _snack(tr('You can attach up to {0} PDFs.', [_maxDocs]), error: true);
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: true,
        withData: true,
      );
      if (result == null) return;
      var skipped = 0;
      final added = <PropertyDocumentUpload>[];
      for (final f in result.files.take(room)) {
        final bytes = f.bytes;
        if (bytes == null ||
            !f.name.toLowerCase().endsWith('.pdf') ||
            bytes.lengthInBytes > _maxDocBytes) {
          skipped++;
          continue;
        }
        added.add(PropertyDocumentUpload(
          fileName: f.name,
          bytes: bytes,
          type: 'other',
          title: f.name
              .replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
        ));
      }
      if (!mounted) return;
      setState(() => _docs.addAll(added));
      if (skipped > 0) {
        _snack(tr('{0} file(s) skipped – PDF only, up to 10 MB each.', [skipped]),
            error: true);
      }
    } catch (e) {
      _snack(tr('Could not open files: {0}', [e]), error: true);
    }
  }

  String _fileSize(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  // =====================================================================
  // CONFIGURATION (flat types)
  // =====================================================================
  Future<void> _editUnit([int? index]) async {
    final existing = index == null ? null : _units[index];
    final result = await showModalBottomSheet<_Unit>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UnitSheet(
        existing: existing,
        taken: {
          for (var i = 0; i < _units.length; i++)
            if (i != index) _units[i].name.trim().toLowerCase()
        },
      ),
    );
    if (result == null || !mounted) return;
    setState(() => index == null ? _units.add(result) : _units[index] = result);
  }

  Future<void> _editFloor([int? index]) async {
    final existing = index == null ? null : _floorDrafts[index];
    final result = await showModalBottomSheet<_FloorDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FloorSheet(existing: existing),
    );
    if (result == null || !mounted) return;
    setState(() => index == null
        ? _floorDrafts.add(result)
        : _floorDrafts[index] = result);
  }

  Future<void> _editSlab([int? index]) async {
    final existing = index == null ? null : _slabDrafts[index];
    final result = await showModalBottomSheet<_PricingSlabDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SlabSheet(
        existing: existing,
        unitNames: _units.map((u) => u.name).toList(),
      ),
    );
    if (result == null || !mounted) return;
    setState(() =>
    index == null ? _slabDrafts.add(result) : _slabDrafts[index] = result);
  }

  // =====================================================================
  // SUBMIT
  // =====================================================================
  String _num(String s) {
    final d = double.tryParse(s.trim());
    if (d == null) return s.trim();
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  Map<String, String> _buildFields() {
    final units = [..._units];
    final quickPrice = double.tryParse(_price.text.trim());
    if (units.isEmpty && quickPrice != null && quickPrice > 0) {
      units.add(_Unit(
        name: 'Standard',
        price: _price.text.trim(),
        areaSqft: _totalArea.text.trim(),
      ));
    }
    final priced =
    units.where((u) => (double.tryParse(u.price) ?? 0) > 0).toList();

    String d(DateTime x) =>
        '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';

    final f = <String, String>{
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'property_type': _type,
      'transaction_type': _transaction,
      'property_condition': _condition,
      'status': 'pending',
      'city': _city.text.trim(),
      'area': _area.text.trim(),
      'address': _address.text.trim(),
      'landmark': _landmark.text.trim(),
      'pincode': _pincode.text.trim(),
      'total_floors': '${int.tryParse(_floors.text.trim()) ?? 1}',
      'total_towers': '${int.tryParse(_towers.text.trim()) ?? 1}',
      'is_negotiable': '$_negotiable',
      'is_featured': '$_featured',
      'is_under_construction': '$_underConstruction',
      'ready_to_move': '${!_underConstruction}',
      'completion_percentage':
      '${_underConstruction ? _completion.round() : 100}',
      if (_totalArea.text.trim().isNotEmpty)
        'total_area': _num(_totalArea.text),
      if (_plotArea.text.trim().isNotEmpty) 'plot_area': _num(_plotArea.text),
      if (_lat != null) 'latitude': _lat!.toStringAsFixed(7),
      if (_lng != null) 'longitude': _lng!.toStringAsFixed(7),
      if (_mapLink.text.trim().isNotEmpty)
        'google_location_url': _mapLink.text.trim(),
      if (_rera.text.trim().isNotEmpty) 'rera_number': _rera.text.trim(),
      if (_reraWebsite.text.trim().isNotEmpty)
        'rera_website': _reraWebsite.text.trim(),
      if (_website.text.trim().isNotEmpty)
        'property_website_url': _website.text.trim(),
      if (_underConstruction && _possession != null)
        'possession_date': d(_possession!),
      if (_selectedAmenities.isNotEmpty)
        'amenities': jsonEncode(_selectedAmenities.toList()),
    };

    // ── flat_types
    if (units.isNotEmpty) {
      f['flat_types'] = jsonEncode([
        for (final u in units)
          {
            'flat_type': u.name.trim(),
            if (u.areaSqft.trim().isNotEmpty) 'area_sqft': _num(u.areaSqft),
            if (u.carpetArea.trim().isNotEmpty)
              'carpet_area': _num(u.carpetArea),
            if (u.builtUpArea.trim().isNotEmpty)
              'built_up_area': _num(u.builtUpArea),
            if (u.balconyArea.trim().isNotEmpty)
              'balcony_area': _num(u.balconyArea),
            'bedrooms': u.bedrooms,
            'bathrooms': u.bathrooms,
            'balconies': u.balconies,
            'parking_count': u.parking,
            if (u.description.trim().isNotEmpty)
              'description': u.description.trim(),
            'is_available': u.isAvailable,
          }
      ]);
    }

    // ── floors
    if (_floorDrafts.isNotEmpty) {
      f['floors'] = jsonEncode([
        for (final fl in _floorDrafts)
          {
            'floor_number': fl.floorNumber,
            'floor_name': fl.floorName,
            'total_units': fl.totalUnits,
            'available_units': fl.availableUnits,
          }
      ]);
    }

    // ── pricing_slabs
    final slabs = <Map<String, dynamic>>[];
    if (_slabDrafts.isNotEmpty) {
      for (final s in _slabDrafts) {
        slabs.add({
          'flat_type': s.flatType,
          'floor': s.floor,
          if (s.basePrice.trim().isNotEmpty) 'base_price': _num(s.basePrice),
          if (s.pricePerSqft.trim().isNotEmpty)
            'price_per_sqft': _num(s.pricePerSqft),
          if (s.bookingAmount.trim().isNotEmpty)
            'booking_amount': _num(s.bookingAmount),
          if (s.discountPercent.trim().isNotEmpty)
            'discount_percentage': s.discountPercent.trim(),
          if (s.gstPercent.trim().isNotEmpty)
            'gst_percentage': s.gstPercent.trim(),
          'is_available': true,
        });
      }
    } else if (priced.isNotEmpty) {
      if (!f.containsKey('floors')) {
        f['floors'] = jsonEncode([
          {'floor_number': 1, 'floor_name': 'All floors'}
        ]);
      }
      for (final u in priced) {
        slabs.add({
          'flat_type': u.name.trim(),
          'floor': 1,
          'base_price': _num(u.price),
          if (u.booking.trim().isNotEmpty) 'booking_amount': _num(u.booking),
          'is_available': true,
        });
      }
    }
    if (slabs.isNotEmpty) f['pricing_slabs'] = jsonEncode(slabs);

    return f;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitAttempted = true);
    if (!_formKey.currentState!.validate()) {
      _snack(tr('Please fix the highlighted fields'), error: true);
      return;
    }
    if (_photos.isEmpty) {
      _snack(tr('Add at least one photo of the property'), error: true);
      return;
    }
    setState(() => _saving = true);
    final r = await PropertyCreateService.createProperty(
      fields: _buildFields(),
      images: _photos,
      videos: _videos,
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
          decoration: const BoxDecoration(
              color: DT.emerald50, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded,
              color: DT.emerald700, size: 32),
        ),
        title:
        Text(tr('Property submitted'), textAlign: TextAlign.center),
        content: Text(
          tr('{0} was sent for admin approval{1}.\n\n{2}', [_title.text.trim(), _docs.isNotEmpty ? ' with ${_docs.length} document${_docs.length == 1 ? '' : 's'}' : '', r.subscriptionRequired ? 'A listing subscription is needed to make it live.' : (r.freeDays != null && r.freeDays! > 0 ? 'Your listing is free for ${r.freeDays} days.' : '')]),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _kBrand, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('Done'))),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  void _reset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Reset form?')),
        content: Text(tr('All entered details will be cleared.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('Cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _title.clear();
                _description.clear();
                _city.clear();
                _area.clear();
                _address.clear();
                _landmark.clear();
                _pincode.clear();
                _totalArea.clear();
                _plotArea.clear();
                _price.clear();
                _rera.clear();
                _reraWebsite.clear();
                _website.clear();
                _mapLink.clear();
                _floors.text = '1';
                _towers.text = '1';
                _units.clear();
                _floorDrafts.clear();
                _slabDrafts.clear();
                _photos.clear();
                _photoBytes.clear();
                _docs.clear();
                _videos.clear();
                _videoSizes.clear();
                _selectedAmenities.clear();
                _type = 'flat';
                _transaction = 'sale';
                _condition = 'new';
                _negotiable = true;
                _featured = false;
                _underConstruction = false;
                _possession = null;
                _completion = 0;
                _lat = null;
                _lng = null;
                _previewLat = null;
                _previewLng = null;
                _submitAttempted = false;
              });
            },
            child: Text(tr('Reset')),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // BUILD
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasInput && !_saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tr('Discard this listing?')),
            content: Text(tr('The details you entered will be lost.')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr('Keep editing'))),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: _kBrand), // buttons: only #093C71
                child: Text(tr('Discard')),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: _PC.bg,
        body: Column(
          children: [
            _header(),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _heroBanner(),
                      const SizedBox(height: 16),
                      _subcategorySection(),
                      const SizedBox(height: 16),
                      _basicInfoSection(),
                      const SizedBox(height: 16),
                      _configurationsSection(),
                      const SizedBox(height: 16),
                      _locationSection(),
                      const SizedBox(height: 16),
                      _floorsSection(),
                      const SizedBox(height: 16),
                      _pricingSection(),
                      const SizedBox(height: 16),
                      _amenitiesSection(),
                      const SizedBox(height: 16),
                      _mediaSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _bottomBar(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // HEADER — back button + QNXMart logo + cart badge + profile icon
  // ─────────────────────────────────────────────────────────────────────
  Widget _header() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _PC.slate200)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: tr('Back'),
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded,
                    color: _PC.slate900, size: 22),
              ),
              const SizedBox(width: 2),
              Image.asset(
                'lib/assets/images/qnx_mart_logo.png',
                height: 34,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: tr('QNX'),
                        style: DT.text(
                            size: 18,
                            weight: FontWeight.w900,
                            color: const Color(0xFF093C71),
                            letterSpacing: -0.6),
                      ),
                      TextSpan(
                        text: tr('MART'),
                        style: DT.text(
                            size: 18,
                            weight: FontWeight.w800,
                            color: _kRed,
                            letterSpacing: -0.3),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FutureBuilder<int>(
                future: HomeService.getCartCount(),
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: tr('Cart'),
                        onPressed: () {
                          Navigator.maybePop(context);
                        },
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          size: 24,
                          color: _PC.slate900,
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          right: 4,
                          top: 4,
                          child: Container(
                            constraints: const BoxConstraints(
                                minWidth: 18, minHeight: 18),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC62828),
                              borderRadius: BorderRadius.circular(999),
                              border:
                              Border.all(color: Colors.white, width: 2),
                            ),
                            child: Text(
                              tr(count > 99 ? '99+' : '$count'),
                              style: DT.text(
                                  size: 9,
                                  weight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              PopupMenuButton<String>(
                tooltip: tr('Account'),
                offset: const Offset(0, 42),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                onSelected: (v) {
                  if (v == 'back') {
                    Navigator.maybePop(context);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Text(tr('Signed in'),
                        style: DT.text(
                            size: 12,
                            weight: FontWeight.w700,
                            color: _PC.slate900)),
                  ),
                  PopupMenuItem(
                    value: 'back',
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_back_rounded,
                            size: 18, color: _PC.slate700),
                        const SizedBox(width: 10),
                        Text(tr('Back to home'),
                            style: DT.text(
                                size: 13,
                                weight: FontWeight.w600,
                                color: _PC.slate900)),
                      ],
                    ),
                  ),
                ],
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                    decoration: BoxDecoration(
                      color: _PC.slate100,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: _PC.slate200,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 16,
                            color: _PC.slate600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: _PC.slate500,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // HERO BANNER
  // ─────────────────────────────────────────────────────────────────────
  Widget _heroBanner() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_PC.navy, _PC.navyDeep],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: _PC.blue500.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    child: const Icon(Icons.apartment_rounded,
                        color: _PC.blue200, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(tr('Add Property'),
                      style: DT.text(
                          size: 20,
                          weight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tr('Fill in the comprehensive details below to list your property on QNXMart Real Estate.'),
                style:
                DT.text(size: 12, color: _PC.slate300, height: 1.5),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.list_alt_rounded,
                    size: 14, color: Colors.white),
                label: Text(tr('My Properties'),
                    style: DT.text(
                        size: 12,
                        weight: FontWeight.w600,
                        color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.20)),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(0, 0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // SUBCATEGORY SECTION
  // ─────────────────────────────────────────────────────────────────────
  Widget _subcategorySection() {
    return _card(
      title: tr('SELECT PROPERTY SUBCATEGORY'),
      accentColor: _PC.indigo600,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _PC.emerald50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _PC.emerald200),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 14, color: _PC.emerald600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('Active Configuration: {0} Form (Custom Attributes Enabled)', [_typeLabel(_type)]),
                  style: DT.text(
                      size: 11,
                      weight: FontWeight.w600,
                      color: _PC.emerald700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            const gap = 10.0;
            final w = (c.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (v, label, emoji) in _types)
                  SizedBox(
                    width: w,
                    child: _categoryTile(v, label, emoji),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: _PC.slate100),
        const SizedBox(height: 14),
        _label(tr('Transaction Type'), required: true),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (v, label) in [
              ('sale', tr('Sale')),
              ('rent', tr('Rent')),
              ('lease', tr('Lease')),
              ('pg', tr('PG/Hostel')),
            ])
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: v == 'pg' ? 0 : 6),
                  child: _pillButton(
                    label: tr(label),
                    selected: _transaction == v,
                    onTap: () => setState(() => _transaction = v),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _label(tr('Construction Stage'), required: true),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _pillButton(
                label: tr('Under Construction'),
                selected: _underConstruction,
                onTap: () => setState(() => _underConstruction = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _pillButton(
                label: tr('Ready to Move'),
                selected: !_underConstruction,
                onTap: () => setState(() => _underConstruction = false),
              ),
            ),
          ],
        ),
        if (_underConstruction) ...[
          const SizedBox(height: 14),
          _label(tr('Possession date')),
          const SizedBox(height: 6),
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
            icon: const Icon(Icons.event_outlined, size: 16),
            label: Text(
              _possession == null
                  ? tr('Select date')
                  : '${_possession!.day}/${_possession!.month}/${_possession!.year}',
              style: DT.text(size: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _PC.slate700,
              side: const BorderSide(color: _PC.slate200),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(tr('Construction progress'),
                  style: DT.text(
                      size: 12,
                      weight: FontWeight.w600,
                      color: _PC.slate600)),
              const Spacer(),
              Text('${_completion.round()}%',
                  style: DT.text(
                      size: 13,
                      weight: FontWeight.w800,
                      color: _PC.blue600)),
            ],
          ),
          Slider(
            value: _completion,
            max: 100,
            divisions: 20,
            activeColor: _PC.blue600,
            onChanged: (v) => setState(() => _completion = v),
          ),
        ],
      ],
    );
  }

  String _typeLabel(String v) =>
      _types.firstWhere((t) => t.$1 == v, orElse: () => _types.first).$2;

  Widget _categoryTile(String value, String label, String emoji) {
    final selected = _type == value;
    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? _PC.indigo50 : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _PC.indigo600 : _PC.slate200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Text(tr(emoji), style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 6),
                Text(tr(label),
                    textAlign: TextAlign.center,
                    style: DT.text(
                        size: 11.5,
                        weight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? _PC.slate900 : _PC.slate700)),
              ],
            ),
            if (selected)
              const Positioned(
                right: 0,
                top: 0,
                child: Icon(Icons.check_circle_rounded,
                    size: 14, color: _PC.indigo600),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _PC.blue600 : _PC.slate100,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? const [
            BoxShadow(
                color: Color(0x33093C71),
                blurRadius: 6,
                offset: Offset(0, 2))
          ]
              : null,
        ),
        child: Text(tr(label),
            style: DT.text(
                size: 11.5,
                weight: FontWeight.w700,
                color: selected ? Colors.white : _PC.slate600)),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BASIC INFO
  // ─────────────────────────────────────────────────────────────────────
  Widget _basicInfoSection() {
    return _card(
      title: tr('Basic Information'),
      icon: Icons.info_outline_rounded,
      children: [
        _label(tr('Title'), required: true),
        const SizedBox(height: 6),
        _input(_title,
            hint: tr('Enter property title'),
            validator: (v) =>
            (v ?? '').trim().isEmpty ? tr('Title is required') : null),
        const SizedBox(height: 12),
        _label(tr('Property Type'), required: true),
        const SizedBox(height: 6),
        _dropdown(
          value: _type,
          items: _types.map((t) => (t.$1, t.$2)).toList(),
          onChanged: (v) => setState(() => _type = v),
        ),
        const SizedBox(height: 12),
        _label(tr('Property Condition'), required: true),
        const SizedBox(height: 6),
        _dropdown(
          value: _condition,
          items: _propertyConditions,
          onChanged: (v) => setState(() => _condition = v),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            text: tr('Detailed Description '),
            style: DT.text(
                size: 12, weight: FontWeight.w600, color: _PC.slate700),
            children: [
              TextSpan(
                  text: tr('(Optional)'),
                  style: DT.text(
                      size: 12,
                      weight: FontWeight.w400,
                      color: _PC.slate400)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _input(_description,
            hint:
            tr('Highlight view, corner position, sunlight, furnishings, and proximity to hubs...'),
            maxLines: 3),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // CONFIGURATIONS (flat types)
  // ─────────────────────────────────────────────────────────────────────
  Widget _configurationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _units.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _unitCard(_units[i], i),
          ),
        _addTile(
          icon: Icons.add_rounded,
          label: tr('Add Configuration'),
          subtitle:
          tr('Add another flat type (2 BHK, 3 BHK, etc.) with its own price'),
          onTap: () => _editUnit(),
        ),
      ],
    );
  }

  Widget _unitCard(_Unit u, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _PC.slate200),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(tr('CONFIGURATION #{0}', [index + 1]),
                    style: DT.text(
                        size: 11,
                        weight: FontWeight.w800,
                        color: _PC.slate800,
                        letterSpacing: 0.8)),
              ),
              GestureDetector(
                onTap: () => setState(() => _units.removeAt(index)),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _PC.rose50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _PC.rose200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_outline_rounded,
                          size: 12, color: _PC.rose600),
                      const SizedBox(width: 4),
                      Text(tr('Remove'),
                          style: DT.text(
                              size: 11,
                              weight: FontWeight.w600,
                              color: _PC.rose600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _PC.slate100),
          const SizedBox(height: 12),
          _label(tr('Flat Type'), required: true),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _PC.slate200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(trData(u.name),
                      style:
                      DT.text(size: 13.5, weight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () => _editUnit(index),
                  child: Text(tr('Edit'),
                      style: DT.text(
                          size: 12,
                          weight: FontWeight.w700,
                          color: _PC.blue600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _readOnlyField(tr('Area (sqft)'), u.areaSqft)),
              const SizedBox(width: 10),
              Expanded(
                  child:
                  _readOnlyField(tr('Carpet Area (sqft)'), u.carpetArea)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _counterBox(tr('Bedrooms'), u.bedrooms,
                        (v) => setState(() => u.bedrooms = v)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _counterBox(tr('Bathrooms'), u.bathrooms,
                        (v) => setState(() => u.bathrooms = v)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => setState(() => u.isAvailable = !u.isAvailable),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: u.isAvailable,
                    onChanged: (v) =>
                        setState(() => u.isAvailable = v ?? true),
                    activeColor: _PC.blue600,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('Unit currently available for immediate booking'),
                    style: DT.text(size: 12, color: _PC.slate700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label *',
            style: DT.text(
                size: 11.5, weight: FontWeight.w600, color: _PC.slate700)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _PC.slate200),
          ),
          child: Text(tr(value.isEmpty ? '—' : value),
              style: DT.text(size: 13, weight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _counterBox(String label, int value, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _PC.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _PC.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(label),
              style: DT.text(
                  size: 11, weight: FontWeight.w600, color: _PC.slate600)),
          const SizedBox(height: 6),
          Row(
            children: [
              _counterBtn(
                  Icons.remove, value > 0 ? () => onChanged(value - 1) : null),
              Expanded(
                child: Text('$value',
                    textAlign: TextAlign.center,
                    style: DT.text(size: 14, weight: FontWeight.w800)),
              ),
              _counterBtn(
                  Icons.add, value < 20 ? () => onChanged(value + 1) : null),
            ],
          ),
        ],
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled ? _PC.blue600 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border:
          Border.all(color: enabled ? _PC.blue600 : _PC.slate200),
        ),
        child: Icon(icon,
            size: 15, color: enabled ? Colors.white : _PC.slate600),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // LOCATION
  // ─────────────────────────────────────────────────────────────────────
  Widget _locationSection() {
    return _card(
      title: tr('Location Details'),
      icon: Icons.location_on_rounded,
      trailing: OutlinedButton.icon(
        onPressed: _locating ? null : _useLocation,
        icon: _locating
            ? const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: _PC.blue600))
            : const Icon(Icons.my_location_rounded,
            size: 14, color: _PC.blue600),
        label: Text(_locating ? tr('Getting…') : tr('Get Live Location'),
            style: DT.text(
                size: 11,
                weight: FontWeight.w700,
                color: _PC.blue600)),
        style: OutlinedButton.styleFrom(
          backgroundColor: _PC.blue50,
          side: const BorderSide(color: _PC.blue200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          minimumSize: const Size(0, 0),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      children: [
        _label(tr('Full Address'), required: true),
        const SizedBox(height: 6),
        _input(_address,
            hint: tr('Building name, Street, Block, City, State'),
            maxLines: 2,
            validator: (v) =>
            (v ?? '').trim().isEmpty ? tr('Address is required') : null),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(tr('City'), required: true),
                  const SizedBox(height: 6),
                  _input(_city,
                      hint: tr('Pune'),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? tr('City is required')
                          : null),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(tr('Area / Locality'), required: true),
                  const SizedBox(height: 6),
                  _input(_area,
                      hint: tr('Wakad'),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? tr('Area is required')
                          : null),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(tr('Landmark')),
                  const SizedBox(height: 6),
                  _input(_landmark, hint: tr('Near Metro Station')),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(tr('Pin Code')),
                  const SizedBox(height: 6),
                  _input(_pincode,
                      hint: '411045',
                      keyboard: TextInputType.number,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        return t.length != 6 ? tr('6-digit pincode') : null;
                      }),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _label(tr('Google Maps Link')),
        const SizedBox(height: 6),
        _input(_mapLink,
            hint: 'https://maps.google.com/?q=...',
            keyboard: TextInputType.url,
            prefixIcon: Icons.link_rounded),
        if (_lat != null && _lng != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.my_location_rounded,
                  size: 12, color: _PC.emerald600),
              const SizedBox(width: 4),
              Text(
                tr('Location set · {0}, {1}', [_lat!.toStringAsFixed(5), _lng!.toStringAsFixed(5)]),
                style: DT.text(
                    size: 11,
                    weight: FontWeight.w600,
                    color: _PC.emerald700),
              ),
            ],
          ),
        ],
        if (_previewLat != null && _previewLng != null) ...[
          const SizedBox(height: 12),
          _buildMapPreview(),
        ],
      ],
    );
  }

  Widget _buildMapPreview() {
    final lat = _previewLat!;
    final lng = _previewLng!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _PC.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: _PC.slate50,
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: _PC.blue600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tr('Tap on the map to move the pin'),
                    style: DT.text(size: 11.5, color: _PC.slate700),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 240,
            child: _InteractiveMapView(
              lat: lat,
              lng: lng,
              onLocationPicked: (newLat, newLng) {
                setState(() {
                  _lat = newLat;
                  _lng = newLng;
                  _previewLat = newLat;
                  _previewLng = newLng;
                  _mapLink.text =
                  'https://www.google.com/maps/search/?api=1&query=${newLat.toStringAsFixed(6)},${newLng.toStringAsFixed(6)}';
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 16, color: _PC.blue600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                    style: DT.text(
                        size: 12,
                        weight: FontWeight.w600,
                        color: _PC.slate700),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    final url =
                        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                    _openUrl(url);
                  },
                  icon: const Icon(Icons.open_in_new_rounded,
                      size: 14, color: _PC.blue600),
                  label: Text(tr('Open in Maps'),
                      style: DT.text(
                          size: 12,
                          weight: FontWeight.w700,
                          color: _PC.blue600)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: const Size(0, 0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // FLOORS
  // ─────────────────────────────────────────────────────────────────────
  Widget _floorsSection() {
    return _card(
      title: tr('Floors'),
      icon: Icons.layers_outlined,
      trailing: _addSmallButton(tr('Add Floor'), () => _editFloor()),
      children: [
        if (_floorDrafts.isEmpty)
          _emptyPlaceholder(tr('No floors added yet.'))
        else
          for (var i = 0; i < _floorDrafts.length; i++) ...[
            _floorTile(_floorDrafts[i], i),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _floorTile(_FloorDraft f, int i) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _PC.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _PC.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _PC.indigo50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${f.floorNumber}',
                style: DT.text(
                    size: 15,
                    weight: FontWeight.w800,
                    color: _PC.indigo600)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(f.floorName),
                    style:
                    DT.text(size: 13.5, weight: FontWeight.w700)),
                Text('${f.availableUnits} / ${f.totalUnits} available',
                    style: DT.text(size: 11.5, color: _PC.slate500)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _editFloor(i),
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: _PC.blue600),
          ),
          IconButton(
            onPressed: () => setState(() => _floorDrafts.removeAt(i)),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: _PC.rose600),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // PRICING SLABS
  // ─────────────────────────────────────────────────────────────────────
  Widget _pricingSection() {
    return _card(
      title: tr('Pricing Slabs'),
      icon: Icons.currency_rupee_rounded,
      trailing: _addSmallButton(tr('Add Slab'), () => _editSlab()),
      children: [
        if (_slabDrafts.isEmpty && _units.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label(tr('Expected price (₹)')),
              const SizedBox(height: 6),
              _input(_price,
                  hint: tr('Leave empty for "Price on request"'),
                  keyboard: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ]),
              const SizedBox(height: 10),
              _emptyPlaceholder(tr('No pricing slabs configured yet.')),
            ],
          )
        else
          for (var i = 0; i < _slabDrafts.length; i++) ...[
            _slabTile(_slabDrafts[i], i),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 8),
        SwitchListTile(
          value: _negotiable,
          onChanged: (v) => setState(() => _negotiable = v),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: Colors.white,
          activeTrackColor: _PC.blue600,
          title: Text(tr('Price is negotiable'),
              style: DT.text(size: 13, weight: FontWeight.w600)),
        ),
        SwitchListTile(
          value: _featured,
          onChanged: (v) => setState(() => _featured = v),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: Colors.white,
          activeTrackColor: _PC.blue600,
          title: Text(tr('Mark as featured'),
              style: DT.text(size: 13, weight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _slabTile(_PricingSlabDraft s, int i) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _PC.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _PC.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _PC.indigo50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.currency_rupee_rounded,
                size: 18, color: _PC.indigo600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.flatType.isEmpty ? tr('All units') : s.flatType,
                    style:
                    DT.text(size: 13.5, weight: FontWeight.w700)),
                Text(
                  [
                    if (s.basePrice.isNotEmpty) '₹${_num(s.basePrice)}',
                    tr('Floor {0}', [s.floor]),
                  ].join(' · '),
                  style: DT.text(size: 11.5, color: _PC.slate500),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _editSlab(i),
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: _PC.blue600),
          ),
          IconButton(
            onPressed: () => setState(() => _slabDrafts.removeAt(i)),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: _PC.rose600),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // AMENITIES
  // ─────────────────────────────────────────────────────────────────────
  Widget _amenitiesSection() {
    return _card(
      title: tr('Amenities & Features'),
      icon: Icons.auto_awesome_rounded,
      trailing: _addSmallButton(tr('Add Amenity'), _openAddAmenity),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Select available conveniences to boost listing visibility'),
                style: DT.text(size: 11.5, color: _PC.slate500),
              ),
            ),
            if (_selectedAmenities.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _PC.emerald50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _PC.emerald200),
                ),
                child: Text('${_selectedAmenities.length} selected',
                    style: DT.text(
                        size: 10.5,
                        weight: FontWeight.w700,
                        color: _PC.emerald700)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingAmenities)
          const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                    color: _PC.blue600, strokeWidth: 2),
              ))
        else if (_amenities.isEmpty)
          GestureDetector(
            onTap: _openAddAmenity,
            child: _emptyPlaceholder(
                tr('No amenities yet — tap "Add Amenity" to create one')),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              const gap = 8.0;
              final w = (c.maxWidth - gap) / 2;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final a in _amenities)
                    SizedBox(
                      width: w,
                      child: _amenityChip(a),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _amenityChip(Amenity a) {
    final selected = _selectedAmenities.contains(a.id);
    return GestureDetector(
      onTap: () => setState(() {
        selected
            ? _selectedAmenities.remove(a.id)
            : _selectedAmenities.add(a.id);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _PC.blue50 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border:
          Border.all(color: selected ? _PC.blue600 : _PC.slate100),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: selected,
                onChanged: (v) => setState(() {
                  (v ?? false)
                      ? _selectedAmenities.add(a.id)
                      : _selectedAmenities.remove(a.id);
                }),
                activeColor: _PC.blue600,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(trData(a.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(size: 12, color: _PC.slate700)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // MEDIA
  // ─────────────────────────────────────────────────────────────────────
  Widget _mediaSection() {
    return _card(
      title: tr('Media & Documents'),
      icon: Icons.cloud_upload_outlined,
      children: [
        GestureDetector(
          onTap: _pickPhotos,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: _PC.blue50.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _PC.blue200, width: 2, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                const Icon(Icons.collections_rounded,
                    size: 30, color: _PC.blue600),
                const SizedBox(height: 6),
                Text(tr('Upload Property Photos'),
                    style:
                    DT.text(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(tr('JPEG, PNG, WebP up to 5MB each (Min 3 photos)'),
                    style: DT.text(size: 10.5, color: _PC.slate400)),
                const SizedBox(height: 4),
                Text('${_photos.length}/$_maxPhotos added',
                    style: DT.text(
                        size: 11,
                        weight: FontWeight.w600,
                        color: _PC.blue600)),
              ],
            ),
          ),
        ),
        if (_photoBytes.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photoBytes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_photoBytes[i],
                        width: 90, height: 90, fit: BoxFit.cover),
                  ),
                  if (i == 0)
                    Positioned(
                      left: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _PC.blue600,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(tr('Cover'),
                            style: DT.text(
                                size: 9,
                                weight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _photos.removeAt(i);
                        _photoBytes.removeAt(i);
                      }),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        _videosBlock(),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _pickDocuments,
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: _PC.slate50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _PC.slate200),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded,
                    size: 24, color: _PC.rose600),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('RERA & Ownership Document'),
                          style: DT.text(
                              size: 12.5,
                              weight: FontWeight.w600,
                              color: _PC.slate700)),
                      Text(tr('PDF up to 10MB each'),
                          style: DT.text(
                              size: 10.5, color: _PC.slate400)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _PC.slate200),
                  ),
                  child: Text(tr('Choose File'),
                      style: DT.text(
                          size: 11,
                          weight: FontWeight.w600,
                          color: _PC.blue600)),
                ),
              ],
            ),
          ),
        ),
        if (_docs.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (var i = 0; i < _docs.length; i++) ...[
            _docTile(i),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _videosBlock() {
    final full = _videos.length >= _maxVideos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: full ? null : _pickVideo,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC9DBEE)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: _kHeader,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.videocam_rounded,
                      size: 22, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Property Videos'),
                          style: DT.text(
                              size: 12.5,
                              weight: FontWeight.w700,
                              color: _PC.slate700)),
                      Text(
                          tr('MP4 / MOV up to 100MB · {0}/{1} added', [_videos.length, _maxVideos]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 10.5, color: _PC.slate400)),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: full ? _PC.slate100 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: full ? _PC.slate200 : const Color(0xFFA3C1E0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded,
                          size: 14,
                          color: full ? _PC.slate400 : _kBrandLight),
                      const SizedBox(width: 2),
                      Text(full ? tr('Max') : tr('Add Video'),
                          style: DT.text(
                              size: 11,
                              weight: FontWeight.w700,
                              color: full ? _PC.slate400 : _kBrandLight)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        for (var i = 0; i < _videos.length; i++) ...[
          const SizedBox(height: 8),
          _videoTile(i),
        ],
      ],
    );
  }

  Widget _videoTile(int i) {
    final v = _videos[i];
    final name = v.name.isNotEmpty ? v.name : 'Video ${i + 1}';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _PC.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 38,
            decoration: BoxDecoration(
              color: _PC.navy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.play_circle_fill_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 12.5, weight: FontWeight.w700)),
                Text(tr(_fileSize(_videoSizes[i])),
                    style: DT.text(size: 10.5, color: _PC.slate500)),
              ],
            ),
          ),
          IconButton(
            tooltip: tr('Remove'),
            onPressed: () => setState(() {
              _videos.removeAt(i);
              _videoSizes.removeAt(i);
            }),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: _PC.rose600),
          ),
        ],
      ),
    );
  }

  Widget _docTile(int i) {
    final d = _docs[i];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _PC.slate200),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _PC.rose50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: _PC.rose600, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(d.fileName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                    DT.text(size: 12.5, weight: FontWeight.w700)),
                Text(tr(_fileSize(d.sizeBytes)),
                    style: DT.text(size: 10.5, color: _PC.slate500)),
              ],
            ),
          ),
          IconButton(
            tooltip: tr('Remove'),
            onPressed: () => setState(() => _docs.removeAt(i)),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: _PC.rose600),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BOTTOM BAR
  // ─────────────────────────────────────────────────────────────────────
  Widget _bottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _PC.slate200)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0F0F172A),
              blurRadius: 12,
              offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _saving ? null : _reset,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _PC.slate700,
                      side: const BorderSide(color: _PC.slate300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(tr('Reset Form'),
                        style: DT.text(
                            size: 12.5,
                            weight: FontWeight.w700,
                            color: _PC.slate700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBrand, // buttons: only #093C71
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: _PC.blue500.withValues(alpha: 0.25),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white)),
                        const SizedBox(width: 8),
                        Text(tr('Uploading…'),
                            style: DT.text(
                                size: 12.5,
                                weight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(tr('Publish Listing'),
                            style: DT.text(
                                size: 13,
                                weight: FontWeight.w700,
                                color: Colors.white)),
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 16, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // SHARED HELPERS
  // ─────────────────────────────────────────────────────────────────────
  Widget _card({
    required String title,
    IconData? icon,
    Widget? trailing,
    Color? accentColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _PC.slate200),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (accentColor != null)
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              if (accentColor != null) const SizedBox(width: 6),
              if (icon != null && accentColor == null) ...[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _PC.blue50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 14, color: _PC.blue600),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  tr(accentColor != null ? title.toUpperCase() : title),
                  style: DT.text(
                    size: accentColor != null ? 11 : 14,
                    weight: FontWeight.w800,
                    color: _PC.slate900,
                    letterSpacing: accentColor != null ? 0.8 : -0.2,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return RichText(
      text: TextSpan(
        text: tr(text),
        style: DT.text(
            size: 12, weight: FontWeight.w600, color: _PC.slate700),
        children: [
          if (required)
            TextSpan(
                text: ' *',
                style: DT.text(
                    size: 12, weight: FontWeight.w700, color: _PC.rose500)),
        ],
      ),
    );
  }

  Widget _input(
      TextEditingController c,
      {String? hint,
        int maxLines = 1,
        TextInputType? keyboard,
        List<TextInputFormatter>? formatters,
        IconData? prefixIcon,
        String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboard,
      inputFormatters: formatters,
      validator: validator,
      maxLines: maxLines,
      style: DT.text(size: 13, weight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: trN(hint),
        hintStyle: DT.text(size: 12.5, color: _PC.slate400),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 16, color: _PC.slate400),
        prefixIconConstraints:
        const BoxConstraints(minWidth: 40, minHeight: 20),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _PC.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _PC.blue600, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed, width: 1.6),
        ),
        errorStyle: DT.text(size: 11, color: _kRed),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<(String, String)> items,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _PC.slate200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _PC.slate400),
          style: DT.text(size: 13, weight: FontWeight.w500),
          items: items
              .map((e) => DropdownMenuItem<String>(
            value: e.$1,
            child: Text(tr(e.$2), overflow: TextOverflow.ellipsis),
          ))
              .toList(),
          onChanged: (v) => onChanged(v ?? value),
        ),
      ),
    );
  }

  Widget _emptyPlaceholder(String text) => Container(
    padding: const EdgeInsets.symmetric(vertical: 20),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _PC.slate50.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: _PC.slate200, style: BorderStyle.solid),
    ),
    child:
    Text(tr(text), style: DT.text(size: 12, color: _PC.slate400)),
  );

  Widget _addSmallButton(String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
      label: Text(tr(label),
          style: DT.text(
              size: 12, weight: FontWeight.w700, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kBrand, // buttons: only #093C71
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _addTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _PC.blue50,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _PC.blue200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _PC.blue600, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(label),
                        style: DT.text(
                            size: 13.5,
                            weight: FontWeight.w700,
                            color: _PC.slate900)),
                    Text(tr(subtitle),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(
                            size: 11,
                            color: _PC.slate500,
                            height: 1.4)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: _PC.blue600),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// UNIT SHEET (edit / add a configuration)
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
  late final _area =
  TextEditingController(text: widget.existing?.areaSqft ?? '');
  late final _carpet =
  TextEditingController(text: widget.existing?.carpetArea ?? '');
  late final _built =
  TextEditingController(text: widget.existing?.builtUpArea ?? '');
  late final _balcony =
  TextEditingController(text: widget.existing?.balconyArea ?? '');
  late final _desc =
  TextEditingController(text: widget.existing?.description ?? '');
  late final _price =
  TextEditingController(text: widget.existing?.price ?? '');
  late final _booking =
  TextEditingController(text: widget.existing?.booking ?? '');
  late int _bed = widget.existing?.bedrooms ?? 2;
  late int _bath = widget.existing?.bathrooms ?? 2;
  late int _balc = widget.existing?.balconies ?? 1;
  late int _park = widget.existing?.parking ?? 1;
  late bool _available = widget.existing?.isAvailable ?? true;

  @override
  void dispose() {
    for (final c in [
      _name, _area, _carpet, _built, _balcony, _desc, _price, _booking
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _counter(String label, int value, ValueChanged<int> onChanged,
      {int max = 20}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _PC.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _PC.slate200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(label),
                style: DT.text(
                    size: 11,
                    weight: FontWeight.w600,
                    color: _PC.slate600)),
            const SizedBox(height: 6),
            Row(
              children: [
                GestureDetector(
                  onTap: value > 0 ? () => onChanged(value - 1) : null,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: value > 0 ? _PC.blue600 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                          value > 0 ? _PC.blue600 : _PC.slate200),
                    ),
                    child: Icon(Icons.remove,
                        size: 15,
                        color: value > 0 ? Colors.white : _PC.slate600),
                  ),
                ),
                Expanded(
                  child: Text('$value',
                      textAlign: TextAlign.center,
                      style: DT.text(
                          size: 14, weight: FontWeight.w800)),
                ),
                GestureDetector(
                  onTap: value < max ? () => onChanged(value + 1) : null,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: value < max ? _PC.blue600 : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                          value < max ? _PC.blue600 : _PC.slate200),
                    ),
                    child: Icon(Icons.add,
                        size: 15,
                        color:
                        value < max ? Colors.white : _PC.slate600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
              Text(
                  widget.existing == null
                      ? tr('Add configuration')
                      : tr('Edit configuration'),
                  style: DT.text(size: 17, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in const [
                  '1 BHK',
                  '2 BHK',
                  '3 BHK',
                  '4 BHK',
                  'Studio',
                  'Shop',
                  'Office'
                ])
                  ActionChip(
                    label: Text(tr(s)),
                    onPressed: () => setState(() => _name.text = s),
                  ),
              ]),
              const SizedBox(height: 12),
              _lbl(tr('Flat type'), required: true),
              _tf(_name, hint: tr('e.g. 2 BHK'), validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return tr('Enter a name');
                if (widget.taken.contains(t.toLowerCase())) {
                  return tr('This configuration already exists');
                }
                return null;
              }),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _lblCol(tr('Area (sqft)'), _area)),
                const SizedBox(width: 10),
                Expanded(child: _lblCol(tr('Carpet (sqft)'), _carpet)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _lblCol(tr('Built-up (sqft)'), _built)),
                const SizedBox(width: 10),
                Expanded(child: _lblCol(tr('Balcony (sqft)'), _balcony)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _counter(tr('Bedrooms'), _bed, (v) => setState(() => _bed = v)),
                const SizedBox(width: 10),
                _counter(tr('Bathrooms'), _bath, (v) => setState(() => _bath = v)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _counter(tr('Balconies'), _balc, (v) => setState(() => _balc = v)),
                const SizedBox(width: 10),
                _counter(tr('Parking'), _park, (v) => setState(() => _park = v)),
              ]),
              const SizedBox(height: 12),
              _lbl(tr('Description (optional)')),
              _tf(_desc,
                  hint: tr('e.g. Corner unit with park view'), maxLines: 2),
              const SizedBox(height: 12),
              _lbl(tr('Price (₹)')),
              _tf(_price,
                  hint: '5500000',
                  keyboard: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ]),
              const SizedBox(height: 12),
              _lbl(tr('Booking amount (₹)')),
              _tf(_booking,
                  hint: '100000',
                  keyboard: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(12),
                  ]),
              const SizedBox(height: 8),
              SwitchListTile(
                value: _available,
                onChanged: (v) => setState(() => _available = v),
                contentPadding: EdgeInsets.zero,
                activeThumbColor: Colors.white,
                activeTrackColor: _PC.blue600,
                title: Text(tr('Available now'),
                    style: DT.text(size: 13, weight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
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
                        balconies: _balc,
                        parking: _park,
                        areaSqft: _area.text.trim(),
                        carpetArea: _carpet.text.trim(),
                        builtUpArea: _built.text.trim(),
                        balconyArea: _balcony.text.trim(),
                        description: _desc.text.trim(),
                        isAvailable: _available,
                        price: _price.text.trim(),
                        booking: _booking.text.trim(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBrand, // buttons: only #093C71
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(tr('Save configuration'),
                      style: DT.text(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lbl(String t, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(
      text: TextSpan(
        text: tr(t),
        style: DT.text(
            size: 12, weight: FontWeight.w600, color: _PC.slate700),
        children: [
          if (required)
            TextSpan(
                text: ' *',
                style: DT.text(
                    size: 12,
                    weight: FontWeight.w700,
                    color: _PC.rose500)),
        ],
      ),
    ),
  );

  Widget _lblCol(String label, TextEditingController c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tr(label),
          style: DT.text(
              size: 11.5,
              weight: FontWeight.w600,
              color: _PC.slate700)),
      const SizedBox(height: 6),
      _tf(c),
    ],
  );

  Widget _tf(TextEditingController c,
      {String? hint,
        int maxLines = 1,
        TextInputType? keyboard,
        List<TextInputFormatter>? formatters,
        String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboard,
      inputFormatters: formatters,
      validator: validator,
      style: DT.text(size: 13.5),
      decoration: InputDecoration(
        hintText: trN(hint),
        hintStyle: DT.text(size: 12.5, color: _PC.slate400),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _PC.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _PC.blue600, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed, width: 1.6),
        ),
      ),
    );
  }
}

// =====================================================================
// FLOOR SHEET
// =====================================================================
class _FloorSheet extends StatefulWidget {
  final _FloorDraft? existing;
  const _FloorSheet({this.existing});

  @override
  State<_FloorSheet> createState() => _FloorSheetState();
}

class _FloorSheetState extends State<_FloorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name =
  TextEditingController(text: widget.existing?.floorName ?? '');
  late final _number = TextEditingController(
      text: '${widget.existing?.floorNumber ?? 1}');
  late final _total =
  TextEditingController(text: '${widget.existing?.totalUnits ?? 0}');
  late final _avail =
  TextEditingController(text: '${widget.existing?.availableUnits ?? 0}');

  @override
  void dispose() {
    for (final c in [_name, _number, _total, _avail]) {
      c.dispose();
    }
    super.dispose();
  }

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
              Text(widget.existing == null ? tr('Add floor') : tr('Edit floor'),
                  style: DT.text(size: 17, weight: FontWeight.w800)),
              const SizedBox(height: 14),
              _lbl(tr('Floor number'), required: true),
              _tf(_number,
                  hint: '1',
                  keyboard: TextInputType.number,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: (v) =>
                  (v ?? '').trim().isEmpty ? tr('Required') : null),
              const SizedBox(height: 12),
              _lbl(tr('Floor name'), required: true),
              _tf(_name,
                  hint: tr('e.g. First Floor'),
                  validator: (v) =>
                  (v ?? '').trim().isEmpty ? tr('Required') : null),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _lblCol(tr('Total units'), _total)),
                const SizedBox(width: 10),
                Expanded(child: _lblCol(tr('Available units'), _avail)),
              ]),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    Navigator.pop(
                      context,
                      _FloorDraft(
                        floorNumber: int.tryParse(_number.text) ?? 1,
                        floorName: _name.text.trim(),
                        totalUnits: int.tryParse(_total.text) ?? 0,
                        availableUnits: int.tryParse(_avail.text) ?? 0,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBrand, // buttons: only #093C71
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(tr('Save floor'),
                      style: DT.text(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lbl(String t, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(
      text: TextSpan(
        text: tr(t),
        style: DT.text(
            size: 12, weight: FontWeight.w600, color: _PC.slate700),
        children: [
          if (required)
            TextSpan(
                text: ' *',
                style: DT.text(
                    size: 12,
                    weight: FontWeight.w700,
                    color: _PC.rose500)),
        ],
      ),
    ),
  );

  Widget _lblCol(String label, TextEditingController c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tr(label),
          style: DT.text(
              size: 11.5,
              weight: FontWeight.w600,
              color: _PC.slate700)),
      const SizedBox(height: 6),
      _tf(c, keyboard: TextInputType.number, formatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ]),
    ],
  );

  Widget _tf(TextEditingController c,
      {String? hint,
        TextInputType? keyboard,
        List<TextInputFormatter>? formatters,
        String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      inputFormatters: formatters,
      validator: validator,
      style: DT.text(size: 13.5),
      decoration: InputDecoration(
        hintText: trN(hint),
        hintStyle: DT.text(size: 12.5, color: _PC.slate400),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _PC.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _PC.blue600, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed, width: 1.6),
        ),
      ),
    );
  }
}

// =====================================================================
// SLAB SHEET
// =====================================================================
class _SlabSheet extends StatefulWidget {
  final _PricingSlabDraft? existing;
  final List<String> unitNames;
  const _SlabSheet({this.existing, required this.unitNames});

  @override
  State<_SlabSheet> createState() => _SlabSheetState();
}

class _SlabSheetState extends State<_SlabSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _flat =
  TextEditingController(text: widget.existing?.flatType ?? '');
  late final _floor =
  TextEditingController(text: '${widget.existing?.floor ?? 1}');
  late final _base =
  TextEditingController(text: widget.existing?.basePrice ?? '');
  late final _pps =
  TextEditingController(text: widget.existing?.pricePerSqft ?? '');
  late final _booking =
  TextEditingController(text: widget.existing?.bookingAmount ?? '');
  late final _disc =
  TextEditingController(text: widget.existing?.discountPercent ?? '');
  late final _gst =
  TextEditingController(text: widget.existing?.gstPercent ?? '');

  @override
  void dispose() {
    for (final c in [_flat, _floor, _base, _pps, _booking, _disc, _gst]) {
      c.dispose();
    }
    super.dispose();
  }

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
              Text(
                  widget.existing == null
                      ? tr('Add pricing slab')
                      : tr('Edit pricing slab'),
                  style: DT.text(size: 17, weight: FontWeight.w800)),
              const SizedBox(height: 14),
              _lbl(tr('Flat type'), required: true),
              if (widget.unitNames.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _PC.slate200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.unitNames.contains(_flat.text)
                          ? _flat.text
                          : widget.unitNames.first,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: _PC.slate400),
                      style: DT.text(size: 13.5),
                      items: widget.unitNames
                          .map((s) => DropdownMenuItem<String>(
                          value: s, child: Text(tr(s))))
                          .toList(),
                      onChanged: (v) => setState(() => _flat.text = v ?? ''),
                    ),
                  ),
                )
              else
                _tf(_flat,
                    hint: tr('e.g. 2 BHK'),
                    validator: (v) =>
                    (v ?? '').trim().isEmpty ? tr('Required') : null),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _lblCol(tr('Floor number'), _floor)),
                const SizedBox(width: 10),
                Expanded(child: _lblCol(tr('Base price (₹)'), _base)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _lblCol(tr('Price/sqft (₹)'), _pps)),
                const SizedBox(width: 10),
                Expanded(child: _lblCol(tr('Booking (₹)'), _booking)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _lblCol(tr('Discount %'), _disc)),
                const SizedBox(width: 10),
                Expanded(child: _lblCol(tr('GST %'), _gst)),
              ]),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    Navigator.pop(
                      context,
                      _PricingSlabDraft(
                        flatType: _flat.text.trim(),
                        floor: int.tryParse(_floor.text) ?? 1,
                        basePrice: _base.text.trim(),
                        pricePerSqft: _pps.text.trim(),
                        bookingAmount: _booking.text.trim(),
                        discountPercent: _disc.text.trim(),
                        gstPercent: _gst.text.trim(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBrand, // buttons: only #093C71
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(tr('Save slab'),
                      style: DT.text(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lbl(String t, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(
      text: TextSpan(
        text: tr(t),
        style: DT.text(
            size: 12, weight: FontWeight.w600, color: _PC.slate700),
        children: [
          if (required)
            TextSpan(
                text: ' *',
                style: DT.text(
                    size: 12,
                    weight: FontWeight.w700,
                    color: _PC.rose500)),
        ],
      ),
    ),
  );

  Widget _lblCol(String label, TextEditingController c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tr(label),
          style: DT.text(
              size: 11.5,
              weight: FontWeight.w600,
              color: _PC.slate700)),
      const SizedBox(height: 6),
      _tf(c,
          keyboard:
          const TextInputType.numberWithOptions(decimal: true),
          formatters: [DecimalInputFormatter(decimals: 2)]),
    ],
  );

  Widget _tf(TextEditingController c,
      {String? hint,
        TextInputType? keyboard,
        List<TextInputFormatter>? formatters,
        String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      inputFormatters: formatters,
      validator: validator,
      style: DT.text(size: 13.5),
      decoration: InputDecoration(
        hintText: trN(hint),
        hintStyle: DT.text(size: 12.5, color: _PC.slate400),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _PC.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _PC.blue600, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed, width: 1.6),
        ),
      ),
    );
  }
}

// =====================================================================
// 🆕 Interactive map with flutter_map (satellite + street views)
// =====================================================================
class _InteractiveMapView extends StatefulWidget {
  final double lat;
  final double lng;
  final void Function(double lat, double lng) onLocationPicked;

  const _InteractiveMapView({
    required this.lat,
    required this.lng,
    required this.onLocationPicked,
  });

  @override
  State<_InteractiveMapView> createState() => _InteractiveMapViewState();
}

class _InteractiveMapViewState extends State<_InteractiveMapView> {
  late final MapController _mapCtrl;
  late LatLng _center;
  bool _satellite = true;

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController();
    _center = LatLng(widget.lat, widget.lng);
  }

  @override
  void didUpdateWidget(covariant _InteractiveMapView old) {
    super.didUpdateWidget(old);
    if (old.lat != widget.lat || old.lng != widget.lng) {
      _center = LatLng(widget.lat, widget.lng);
      _mapCtrl.move(_center, _mapCtrl.camera.zoom);
    }
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapCtrl,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 16,
            minZoom: 3,
            maxZoom: 19,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (tapPos, latLng) {
              _center = latLng;
              widget.onLocationPicked(latLng.latitude, latLng.longitude);
              setState(() {});
            },
          ),
          children: [
            if (_satellite)
              TileLayer(
                urlTemplate:
                'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.qnxmart.app',
                maxZoom: 19,
              )
            else
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.qnxmart.app',
                maxZoom: 19,
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _center,
                  width: 44,
                  height: 44,
                  alignment: Alignment.topCenter,
                  child: const Icon(
                    Icons.location_on,
                    size: 44,
                    color: Color(0xFFC62828),
                    shadows: [
                      Shadow(color: Colors.black38, blurRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(tr('Esri World Imagery')),
                TextSourceAttribution(tr('OpenStreetMap contributors')),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          child: Column(
            children: [
              _mapBtn(
                icon: Icons.add,
                onTap: () {
                  final z = (_mapCtrl.camera.zoom + 1).clamp(3.0, 19.0);
                  _mapCtrl.move(_center, z);
                },
              ),
              const SizedBox(height: 6),
              _mapBtn(
                icon: Icons.remove,
                onTap: () {
                  final z = (_mapCtrl.camera.zoom - 1).clamp(3.0, 19.0);
                  _mapCtrl.move(_center, z);
                },
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _mapBtn(
            icon: _satellite
                ? Icons.map_outlined
                : Icons.satellite_alt_outlined,
            onTap: () => setState(() => _satellite = !_satellite),
          ),
        ),
      ],
    );
  }

  Widget _mapBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20, color: _PC.slate800),
        ),
      ),
    );
  }
}

// =====================================================================
// ADD AMENITY SHEET
// =====================================================================
class _AmenitySheet extends StatefulWidget {
  final List<Amenity> existing;
  const _AmenitySheet({required this.existing});

  @override
  State<_AmenitySheet> createState() => _AmenitySheetState();
}

class _AmenitySheetState extends State<_AmenitySheet> {
  static const _icons = <(String, IconData, String)>[
    ('pool', Icons.pool_rounded, 'Pool'),
    ('gym', Icons.fitness_center_rounded, 'Gym'),
    ('parking', Icons.local_parking_rounded, 'Parking'),
    ('garden', Icons.park_rounded, 'Garden'),
    ('security', Icons.security_rounded, 'Security'),
    ('lift', Icons.elevator_rounded, 'Lift'),
    ('power', Icons.bolt_rounded, 'Power'),
    ('clubhouse', Icons.weekend_rounded, 'Club'),
    ('play', Icons.child_care_rounded, 'Play area'),
    ('wifi', Icons.wifi_rounded, 'Wi-Fi'),
    ('cctv', Icons.videocam_outlined, 'CCTV'),
    ('star', Icons.auto_awesome_rounded, 'Other'),
  ];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  String _icon = 'star';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final name = _name.text.trim();
    // Already in the list? Just select it – no duplicate on the server.
    for (final a in widget.existing) {
      if (a.name.trim().toLowerCase() == name.toLowerCase()) {
        Navigator.pop(context, a);
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final r = await PropertyCreateService.createAmenity(name: name, icon: _icon);
    if (!mounted) return;
    if (r.ok && r.amenity != null) {
      Navigator.pop(context, r.amenity);
    } else {
      setState(() {
        _saving = false;
        _error = r.message;
      });
    }
  }

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
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _PC.slate200,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: _kHeader,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_task_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Add amenity'),
                            style: DT.text(size: 17, weight: FontWeight.w800)),
                        Text(tr('It will be added to the list and selected'),
                            style: DT.text(size: 11.5, color: _PC.slate500)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: _PC.slate400),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              RichText(
                text: TextSpan(
                  text: tr('Amenity name'),
                  style: DT.text(
                      size: 12, weight: FontWeight.w600, color: _PC.slate700),
                  children: [
                    TextSpan(
                        text: ' *',
                        style: DT.text(
                            size: 12,
                            weight: FontWeight.w700,
                            color: _PC.rose500)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                style: DT.text(size: 13.5),
                onFieldSubmitted: (_) => _save(),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return tr('Enter the amenity name');
                  if (t.length < 2) return tr('Too short');
                  return null;
                },
                decoration: InputDecoration(
                  hintText: tr('e.g. Rooftop Garden'),
                  hintStyle: DT.text(size: 12.5, color: _PC.slate400),
                  prefixIcon: const Icon(Icons.edit_outlined,
                      size: 16, color: _PC.slate400),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _PC.slate200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    const BorderSide(color: _PC.blue600, width: 1.6),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kRed),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kRed, width: 1.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(tr('Icon'),
                  style: DT.text(
                      size: 12, weight: FontWeight.w600, color: _PC.slate700)),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, c) {
                const gap = 8.0;
                final w = (c.maxWidth - gap * 3) / 4;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final it in _icons)
                      _iconTile(it.$1, it.$2, it.$3, w),
                  ],
                );
              }),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _kRedBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kRedLine),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: _kRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(tr(_error!),
                            style: DT.text(
                                size: 12,
                                weight: FontWeight.w600,
                                color: _kRed)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _kBrand, // buttons: only #093C71
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _saving
                        ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded,
                        size: 18, color: Colors.white),
                    label: Text(_saving ? tr('Saving…') : tr('Save amenity'),
                        style: DT.text(
                            size: 14,
                            weight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconTile(String key, IconData icon, String label, double width) {
    final sel = _icon == key;
    return GestureDetector(
      onTap: () => setState(() => _icon = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? _PC.blue50 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? _PC.blue600 : _PC.slate200, width: sel ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: sel ? _PC.blue600 : _PC.slate500),
            const SizedBox(height: 4),
            Text(tr(label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DT.text(
                    size: 10.5,
                    weight: FontWeight.w600,
                    color: sel ? _PC.blue600 : _PC.slate600)),
          ],
        ),
      ),
    );
  }
}
