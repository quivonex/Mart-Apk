// lib/screens/company_create_edit_screen.dart
//
// Company create / edit + Razorpay registration payment (all in one screen).
//
// CREATE FLOW
//   Step 1  Details form ──► POST /company/company/create/   (multipart: fields + logo + images)
//   Step 2  Payment      ──► POST /company/create-company-payment-order/   { company_id }
//                         ──► Razorpay checkout (order_id, key, amount_in_paise)
//                         ──► POST /company/verify-payment/  { payment_id, order_id, signature, company_id }
//                         ──► success ──► Navigator.pop(context, true)
//
// EDIT FLOW
//   Details form ──► POST /company/company/update/   (multipart, partial)
//   If the company is still unpaid, a "Pay now" banner opens Step 2.
//
// Design: matches the home screen (brand blue #1A68FA, white section cards,
// sticky footer) using DT tokens + widgets/product_ui.dart.
//
// Dependencies (pubspec.yaml):
//   razorpay_flutter, image_picker, geolocator, http, http_parser, url_launcher, google_fonts
//
// WEB SUPPORT: logo/photos use XFile + bytes (Image.memory), so picking and
// uploading work in Chrome too. Razorpay checkout itself is Android/iOS only;
// on web the payment step explains this instead of hanging.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/design_tokens.dart';
import '../models/company_locations_models.dart';
import '../models/company_model.dart';
import '../services/company_locations_service.dart';
import '../services/company_service.dart';
import '../widgets/product_ui.dart';
import 'terms_conditions_screen.dart';

enum _Step { details, payment, done }

class CompanyCreateEditScreen extends StatefulWidget {
  final Company? existing;

  const CompanyCreateEditScreen({super.key, this.existing});

  @override
  State<CompanyCreateEditScreen> createState() => _CompanyCreateEditScreenState();
}

class _CompanyCreateEditScreenState extends State<CompanyCreateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final Razorpay _razorpay;

  static const int _maxImages = 5;

  // ─── Controllers ──────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _pickupCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _regNoCtrl = TextEditingController();
  final _ianCtrl = TextEditingController();
  final _farmYearCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _privacyCtrl = TextEditingController();
  final _termsCtrl = TextEditingController();
  final _shortDescCtrl = TextEditingController();
  final _longDescCtrl = TextEditingController();
  final _latitudeCtrl = TextEditingController();
  final _longitudeCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();
  final _extraEmailCtrl = TextEditingController();
  final _extraContactCtrl = TextEditingController();

  // ─── Location State ───────────────────────────────────
  List<LocationItem> _states = [];
  List<LocationItem> _districts = [];
  List<LocationItem> _talukas = [];
  List<LocationItem> _villages = [];

  int? _selectedStateId;
  int? _selectedDistrictId;
  int? _selectedTalukaId;
  int? _selectedVillageId;

  bool _isLoadingStates = false;
  bool _isLoadingDistricts = false;
  bool _isLoadingTalukas = false;
  bool _isLoadingVillages = false;
  bool _isFetchingLocation = false;

  String? _statesError;
  String? _districtsError;
  String? _talukasError;
  String? _villagesError;
  bool _submitAttempted = false;

  // ─── Form State ───────────────────────────────────────
  XFile? _logoFile;
  Uint8List? _logoBytes; // for preview (works on web + mobile)
  String _existingLogoUrl = '';
  final List<XFile> _imageFiles = [];
  final List<Uint8List> _imageBytes = [];

  double? _previewLat;
  double? _previewLng;

  final List<String> _extraEmails = [];
  final List<String> _extraContacts = [];

  bool _isiCertified = false;
  bool _isoCertified = false;
  bool _codAvailable = false;
  bool _acceptTerms = false;

  bool _isSubmitting = false;

  // ─── Payment State ────────────────────────────────────
  _Step _step = _Step.details;
  Company? _company; // created (or existing unpaid) company being paid for
  CompanyPaymentOrderResponse? _order;
  bool _isCreatingOrder = false;
  bool _isCheckoutOpen = false;
  bool _isVerifying = false;
  String? _paymentError;
  String? _paidPaymentId;

  bool get _isEdit => widget.existing != null;

  // =====================================================================
  // LIFECYCLE
  // =====================================================================
  @override
  void initState() {
    super.initState();

    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    if (_isEdit) _prefill(widget.existing!);
    _fetchStates().then((_) {
      if (_isEdit) _prefillLocation(widget.existing!);
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    for (final c in [
      _nameCtrl, _sloganCtrl, _ownerCtrl, _emailCtrl, _phoneCtrl,
      _whatsappCtrl, _websiteCtrl, _addressCtrl,
      _pincodeCtrl, _pickupCtrl, _gstCtrl, _panCtrl, _regNoCtrl, _ianCtrl,
      _farmYearCtrl, _facebookCtrl, _linkedinCtrl, _instagramCtrl,
      _youtubeCtrl, _privacyCtrl, _termsCtrl, _shortDescCtrl,
      _longDescCtrl, _latitudeCtrl, _longitudeCtrl, _referralCtrl,
      _extraEmailCtrl, _extraContactCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // =====================================================================
  // LOCATION
  // =====================================================================
  Future<void> _fetchStates() async {
    setState(() {
      _isLoadingStates = true;
      _statesError = null;
    });
    final res = await CompanyLocationService.getStates();
    if (!mounted) return;
    setState(() {
      _isLoadingStates = false;
      _states = res.data;
      _statesError = res.data.isEmpty
          ? (res.status ? 'No states found. Add states in the admin panel.' : res.message)
          : null;
    });
  }

  Future<void> _fetchDistricts(int stateId) async {
    setState(() {
      _isLoadingDistricts = true;
      _districtsError = null;
      _talukasError = null;
      _villagesError = null;
      _districts = [];
      _talukas = [];
      _villages = [];
      _selectedDistrictId = null;
      _selectedTalukaId = null;
      _selectedVillageId = null;
    });
    final res = await CompanyLocationService.getDistricts(stateId);
    if (!mounted || _selectedStateId != stateId) return; // user changed state meanwhile
    setState(() {
      _isLoadingDistricts = false;
      _districts = res.data;
      _districtsError = res.data.isEmpty
          ? (res.status ? 'No districts found for this state.' : res.message)
          : null;
    });
  }

  Future<void> _fetchTalukas(int districtId) async {
    final stateId = _selectedStateId;
    if (stateId == null) return;
    setState(() {
      _isLoadingTalukas = true;
      _talukasError = null;
      _villagesError = null;
      _talukas = [];
      _villages = [];
      _selectedTalukaId = null;
      _selectedVillageId = null;
    });
    final res = await CompanyLocationService.getTalukas(stateId, districtId);
    if (!mounted || _selectedDistrictId != districtId) return;
    setState(() {
      _isLoadingTalukas = false;
      _talukas = res.data;
      _talukasError = res.data.isEmpty
          ? (res.status ? 'No talukas found for this district.' : res.message)
          : null;
    });
  }

  Future<void> _fetchVillages(int talukaId) async {
    final stateId = _selectedStateId;
    final districtId = _selectedDistrictId;
    if (stateId == null || districtId == null) return;
    setState(() {
      _isLoadingVillages = true;
      _villagesError = null;
      _villages = [];
      _selectedVillageId = null;
    });
    final res = await CompanyLocationService.getVillages(stateId, districtId, talukaId);
    if (!mounted || _selectedTalukaId != talukaId) return;
    setState(() {
      _isLoadingVillages = false;
      _villages = res.data;
      _villagesError = res.data.isEmpty
          ? (res.status ? 'No villages found for this taluka.' : res.message)
          : null;
    });
  }

  // Selection handlers (reset children, load next level)
  void _onStateSelected(LocationItem s) {
    if (s.id == _selectedStateId) return;
    setState(() => _selectedStateId = s.id);
    _fetchDistricts(s.id);
  }

  void _onDistrictSelected(LocationItem d) {
    if (d.id == _selectedDistrictId) return;
    setState(() => _selectedDistrictId = d.id);
    _fetchTalukas(d.id);
  }

  void _onTalukaSelected(LocationItem t) {
    if (t.id == _selectedTalukaId) return;
    setState(() => _selectedTalukaId = t.id);
    _fetchVillages(t.id);
  }

  void _onVillageSelected(LocationItem v) {
    setState(() => _selectedVillageId = v.id);
  }

  /// Edit mode: backend stores names, not ids, so match names to preselect.
  Future<void> _prefillLocation(Company c) async {
    int? match(List<LocationItem> list, String name) {
      final n = name.trim().toLowerCase();
      if (n.isEmpty) return null;
      for (final e in list) {
        if (e.name.trim().toLowerCase() == n) return e.id;
      }
      return null;
    }

    final s = match(_states, c.state);
    if (s == null || !mounted) return;
    setState(() => _selectedStateId = s);
    await _fetchDistricts(s);

    final d = match(_districts, c.district);
    if (d == null || !mounted) return;
    setState(() => _selectedDistrictId = d);
    await _fetchTalukas(d);

    final t = match(_talukas, c.taluka);
    if (t == null || !mounted) return;
    setState(() => _selectedTalukaId = t);
    await _fetchVillages(t);

    final v = match(_villages, c.village);
    if (v != null && mounted) setState(() => _selectedVillageId = v);
  }

  String _nameOf(List<LocationItem> list, int? id) {
    for (final e in list) {
      if (e.id == id) return e.name;
    }
    return '';
  }

  // =====================================================================
  // LIVE LOCATION
  // =====================================================================
  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _snack('Location services are disabled.', isError: true);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _snack('Location permission denied', isError: true);
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _snack('Location permission permanently denied. Enable it in Settings.',
            isError: true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Backend: DecimalField(max_digits=9, decimal_places=6)
      _latitudeCtrl.text = position.latitude.toStringAsFixed(6);
      _longitudeCtrl.text = position.longitude.toStringAsFixed(6);
      setState(() {
        _previewLat = position.latitude;
        _previewLng = position.longitude;
      });

      final address = await _reverseGeocode(position.latitude, position.longitude);
      if (!mounted) return;
      if (address != null && address['display_name'] != null) {
        final displayName = address['display_name'].toString();
        setState(() {
          if (_addressCtrl.text.trim().isEmpty) _addressCtrl.text = displayName;
          final postcode = address['address']?['postcode']?.toString() ?? '';
          final pin = postcode.replaceAll(RegExp(r'[^0-9]'), '');
          if (_pincodeCtrl.text.trim().isEmpty && pin.length == 6) {
            _pincodeCtrl.text = pin;
          }
          if (_pickupCtrl.text.trim().isEmpty) _pickupCtrl.text = displayName;
        });
        _snack('Live location fetched');
      } else {
        _snack('Coordinates saved. Could not fetch the address.');
      }
    } catch (e) {
      _snack('Error getting location: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<Map<String, dynamic>?> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'qnx_mart_app/1.0 (contact@qnxmartb2b.com)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Nominatim error: $e');
      return null;
    }
  }

  // =====================================================================
  // PREFILL (edit)
  // =====================================================================
  void _prefill(Company c) {
    _nameCtrl.text = c.name;
    _sloganCtrl.text = c.companySlogan;
    _ownerCtrl.text = c.ownerName;
    _emailCtrl.text = c.email;
    _phoneCtrl.text = c.phoneNumber;
    _whatsappCtrl.text = c.whatsappNo;
    _websiteCtrl.text = c.websiteUrl;
    _addressCtrl.text = c.address;
    _pincodeCtrl.text = c.pincode;
    _pickupCtrl.text = c.pickupLocation;
    _gstCtrl.text = c.gstNumber;
    _panCtrl.text = c.companyPanNo;
    _regNoCtrl.text = c.registrationNo;
    _ianCtrl.text = c.ianNo;
    _farmYearCtrl.text = c.farmRegistrationYear;
    _facebookCtrl.text = c.facebookUrl;
    _linkedinCtrl.text = c.linkedinUrl;
    _instagramCtrl.text = c.instagramUrl;
    _youtubeCtrl.text = c.youtubeUrl;
    _privacyCtrl.text = c.privacyPolicyUrl;
    _termsCtrl.text = c.termsConditionsUrl;
    _shortDescCtrl.text = c.shortDescription;
    _longDescCtrl.text = c.longDescription;
    _latitudeCtrl.text = c.latitude;
    _longitudeCtrl.text = c.longitude;

    if (c.latitude.isNotEmpty && c.longitude.isNotEmpty) {
      _previewLat = double.tryParse(c.latitude);
      _previewLng = double.tryParse(c.longitude);
    }

    _extraEmails.addAll(c.multipleEmailIds);
    _extraContacts.addAll(c.contacts);
    _existingLogoUrl = c.logo;

    _isiCertified = c.isiCertified;
    _isoCertified = c.isoCertified;
    _codAvailable = c.codAvailable;
    _acceptTerms = true; // already accepted when the company was created
  }

  // =====================================================================
  // PICKERS / CHIPS
  // =====================================================================
  static const int _maxLogoBytes = 2 * 1024 * 1024; // 2 MB
  static const int _maxImageBytes = 5 * 1024 * 1024; // 5 MB per photo

  Future<void> _pickLogo() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes(); // XFile works on web + mobile
      if (bytes.lengthInBytes > _maxLogoBytes) {
        _snack('Logo must be under 2MB', isError: true);
        return;
      }
      if (!mounted) return;
      setState(() {
        _logoFile = picked;
        _logoBytes = bytes;
      });
    } catch (e) {
      _snack('Could not pick logo: $e', isError: true);
    }
  }

  Future<void> _pickImages() async {
    final room = _maxImages - _imageFiles.length;
    if (room <= 0) {
      _snack('You can add up to $_maxImages photos', isError: true);
      return;
    }
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 80, maxWidth: 1600);
      if (picked.isEmpty) return;

      var skippedLarge = 0;
      final newFiles = <XFile>[];
      final newBytes = <Uint8List>[];
      for (final x in picked.take(room)) {
        final bytes = await x.readAsBytes();
        if (bytes.lengthInBytes > _maxImageBytes) {
          skippedLarge++;
          continue;
        }
        newFiles.add(x);
        newBytes.add(bytes);
      }
      if (!mounted) return;
      setState(() {
        _imageFiles.addAll(newFiles);
        _imageBytes.addAll(newBytes);
      });
      if (skippedLarge > 0) {
        _snack('$skippedLarge photo(s) skipped (over 5MB)', isError: true);
      } else if (picked.length > room) {
        _snack('Only $room more photo(s) added (max $_maxImages)');
      }
    } catch (e) {
      _snack('Could not pick photos: $e', isError: true);
    }
  }

  void _removeImage(int i) {
    setState(() {
      _imageFiles.removeAt(i);
      _imageBytes.removeAt(i);
    });
  }

  void _addEmail() {
    final v = _extraEmailCtrl.text.trim();
    if (v.isEmpty) return;
    if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(v)) {
      _snack('Invalid email', isError: true);
      return;
    }
    if (_extraEmails.contains(v)) return;
    setState(() {
      _extraEmails.add(v);
      _extraEmailCtrl.clear();
    });
  }

  void _addContact() {
    final v = _extraContactCtrl.text.trim();
    if (v.isEmpty) return;
    if (v.length != 10) {
      _snack('Enter 10-digit number', isError: true);
      return;
    }
    if (_extraContacts.contains(v)) return;
    setState(() {
      _extraContacts.add(v);
      _extraContactCtrl.clear();
    });
  }

  Future<void> _openTerms() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsConditionsScreen()),
    );
    if (result == true) setState(() => _acceptTerms = true);
  }

  // =====================================================================
  // STEP 1 – SUBMIT (create / update)
  // =====================================================================

  /// Fields that are UNIQUE in the Company model. Sending "" for these makes the
  /// 2nd company with an empty value crash (IntegrityError), so blanks are omitted.
  static const _uniqueFields = {
    'name', 'email', 'gst_number', 'registration_no', 'company_pan_no',
  };

  Map<String, String> _buildFields() {
    final raw = <String, String>{
      'name': _nameCtrl.text.trim(),
      'company_slogan': _sloganCtrl.text.trim(),
      'owner_name': _ownerCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone_number': _phoneCtrl.text.trim(),
      'whatsapp_no': _whatsappCtrl.text.trim(),
      'website_url': _normalizeUrl(_websiteCtrl.text),
      'address': _addressCtrl.text.trim(),
      'state': _nameOf(_states, _selectedStateId),
      'district': _nameOf(_districts, _selectedDistrictId),
      'taluka': _nameOf(_talukas, _selectedTalukaId),
      'village': _nameOf(_villages, _selectedVillageId),
      'pincode': _pincodeCtrl.text.trim(),
      'pickup_location': _pickupCtrl.text.trim(),
      'gst_number': _gstCtrl.text.trim().toUpperCase(),
      'company_pan_no': _panCtrl.text.trim().toUpperCase(),
      'registration_no': _regNoCtrl.text.trim(),
      'IAN_No': _ianCtrl.text.trim(),
      'farm_registration_year': _farmYearCtrl.text.trim(),
      'facebook_url': _normalizeUrl(_facebookCtrl.text),
      'linkedin_url': _normalizeUrl(_linkedinCtrl.text),
      'instagram_url': _normalizeUrl(_instagramCtrl.text),
      'youtube_url': _normalizeUrl(_youtubeCtrl.text),
      'privacy_policy_url': _normalizeUrl(_privacyCtrl.text),
      'terms_conditions_url': _normalizeUrl(_termsCtrl.text),
      'short_description': _shortDescCtrl.text.trim(),
      'long_description': _longDescCtrl.text.trim(),
      'latitude': _trimCoord(_latitudeCtrl.text),
      'longitude': _trimCoord(_longitudeCtrl.text),
      'ISI_certified': _isiCertified.toString(),
      'ISO_certified': _isoCertified.toString(),
      'COD_available': _codAvailable.toString(),
      'accept_terms_conditions': 'true',
      'multiple_email_ids': jsonEncode(_extraEmails),
      'contacts': jsonEncode(_extraContacts),
    };

    if (!_isEdit && _referralCtrl.text.trim().isNotEmpty) {
      raw['referral_code'] = _referralCtrl.text.trim();
    }

    final social = <String, String>{
      if (raw['facebook_url']!.isNotEmpty) 'facebook': raw['facebook_url']!,
      if (raw['linkedin_url']!.isNotEmpty) 'linkedin': raw['linkedin_url']!,
      if (raw['instagram_url']!.isNotEmpty) 'instagram': raw['instagram_url']!,
      if (raw['youtube_url']!.isNotEmpty) 'youtube': raw['youtube_url']!,
    };
    raw['social_media_accounts'] = jsonEncode(social);

    // Create: drop every empty value.  Edit: keep empties (so the user can clear
    // a field) except for unique fields, which must never be sent as "".
    raw.removeWhere((k, v) => v.isEmpty && (!_isEdit || _uniqueFields.contains(k)));
    return raw;
  }

  String _normalizeUrl(String v) {
    final t = v.trim();
    if (t.isEmpty) return '';
    return t.startsWith('http://') || t.startsWith('https://') ? t : 'https://$t';
  }

  /// Keeps lat/lng within DecimalField(9, 6).
  String _trimCoord(String v) {
    final d = double.tryParse(v.trim());
    return d == null ? '' : d.toStringAsFixed(6);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitAttempted = true);
    if (!_formKey.currentState!.validate()) {
      _snack('Please fix the highlighted fields', isError: true);
      return;
    }
    if (!_isEdit && _logoFile == null) {
      _snack('Company logo is required', isError: true);
      return;
    }
    if ([_selectedStateId, _selectedDistrictId, _selectedTalukaId, _selectedVillageId]
        .contains(null)) {
      _snack('Please select state, district, taluka and village', isError: true);
      return;
    }
    if (!_acceptTerms) {
      _snack('Please accept the terms & conditions', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    final fields = _buildFields();

    final CompanyActionResponse response = _isEdit
        ? await CompanyService.updateCompany(
      id: widget.existing!.id,
      fields: fields,
      logo: _logoFile,
      images: _imageFiles,
    )
        : await CompanyService.createCompany(
      fields: fields,
      logo: _logoFile!,
      images: _imageFiles,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!response.isSuccess) {
      _snack(_readableError(response), isError: true);
      return;
    }

    if (_isEdit) {
      _snack('Company updated');
      Navigator.pop(context, true);
      return;
    }

    // ✅ Created → go to payment step
    final created = response.data != null ? Company.fromJson(response.data!) : null;
    if (created == null || created.id == 0) {
      _snack('Company created. Pay the registration fee from My Companies.');
      Navigator.pop(context, true);
      return;
    }
    _goToPayment(created);
  }

  String _readableError(CompanyActionResponse r) {
    const labels = {
      'name': 'Company name',
      'email': 'Email',
      'gst_number': 'GST number',
      'company_pan_no': 'PAN number',
      'registration_no': 'Registration number',
      'website_url': 'Website URL',
      'facebook_url': 'Facebook URL',
      'linkedin_url': 'LinkedIn URL',
      'instagram_url': 'Instagram URL',
      'youtube_url': 'YouTube URL',
      'privacy_policy_url': 'Privacy policy URL',
      'terms_conditions_url': 'Terms URL',
      'latitude': 'Latitude',
      'longitude': 'Longitude',
      'farm_registration_year': 'Registration year',
      'whatsapp_no': 'WhatsApp number',
      'short_description': 'Short description',
    };
    final errors = r.errors;
    if (errors != null && errors.isNotEmpty) {
      final key = errors.keys.first;
      final val = errors[key];
      final msg = val is List && val.isNotEmpty ? val.first.toString() : val.toString();
      final label = labels[key];
      return label == null || msg.toLowerCase().startsWith(label.toLowerCase())
          ? msg
          : '$label: $msg';
    }
    return r.displayMessage;
  }

  // =====================================================================
  // STEP 2 – PAYMENT
  // =====================================================================
  void _goToPayment(Company company) {
    setState(() {
      _company = company;
      _step = _Step.payment;
      _order = null;
      _paymentError = null;
    });
    _createOrder();
  }

  /// Creates the Razorpay order once. The same order is reused for retries,
  /// because the backend verifies against company.order_id.
  Future<void> _createOrder() async {
    final company = _company;
    if (company == null) return;
    setState(() {
      _isCreatingOrder = true;
      _paymentError = null;
    });
    final order = await CompanyService.createPaymentOrder(company.id);
    if (!mounted) return;
    setState(() {
      _isCreatingOrder = false;
      if (order.status && order.alreadyPaid) {
        // Paid already (or previous captured payment recovered by server)
        _order = order;
        _paidPaymentId = order.paymentId;
        _step = _Step.done;
      } else if (order.isSuccess) {
        _order = order;
      } else {
        _paymentError = order.message ?? 'Could not start payment. Try again.';
      }
    });
  }

  void _openCheckout() {
    final company = _company;
    final order = _order;
    if (company == null || order == null) return;

    // razorpay_flutter has no web implementation (Android/iOS only).
    if (kIsWeb) {
      setState(() => _paymentError =
      'Online payment opens in the QNX Mart Android app. Your company is saved – '
          'tap "Pay later", then pay from My Companies on your phone.');
      return;
    }

    final options = <String, dynamic>{
      'key': order.key,
      'amount': order.amountInPaise,
      'currency': order.currency,
      'order_id': order.orderId,
      'name': 'QNX Mart B2B',
      'description': 'Company registration – ${company.name}',
      'timeout': 600, // seconds
      'prefill': {
        if (company.phoneNumber.isNotEmpty) 'contact': company.phoneNumber,
        if (company.email.isNotEmpty) 'email': company.email,
        if (company.ownerName.isNotEmpty) 'name': company.ownerName,
      },
      'notes': {'company_id': company.id.toString()},
      'theme': {'color': '#2D2D6B'},
      'retry': {'enabled': true, 'max_count': 2},
    };

    try {
      setState(() {
        _isCheckoutOpen = true;
        _paymentError = null;
      });
      _razorpay.open(options);
    } catch (e) {
      setState(() {
        _isCheckoutOpen = false;
        _paymentError = 'Could not open Razorpay: $e';
      });
    }
  }

  // ─── Razorpay callbacks ────────────────────────────────
  Future<void> _onPaymentSuccess(PaymentSuccessResponse r) async {
    final company = _company;
    final order = _order;
    if (!mounted || company == null || order == null) return;

    final paymentId = r.paymentId ?? '';
    setState(() {
      _isCheckoutOpen = false;
      _isVerifying = true;
    });

    final verify = await CompanyService.verifyPayment(
      paymentId: paymentId,
      orderId: r.orderId ?? order.orderId!,
      signature: r.signature ?? '',
      companyId: company.id,
    );
    if (!mounted) return;

    setState(() {
      _isVerifying = false;
      if (verify.isSuccess) {
        _paidPaymentId = paymentId;
        _step = _Step.done;
      } else {
        _paymentError =
        '${verify.message ?? 'Payment could not be confirmed.'}\n'
            'If money was deducted, contact support with reference $paymentId.';
      }
    });
  }

  void _onPaymentError(PaymentFailureResponse r) {
    if (!mounted) return;
    String message;
    if (r.code == Razorpay.PAYMENT_CANCELLED) {
      message = 'Payment cancelled. You can try again or pay later.';
    } else if (r.code == Razorpay.NETWORK_ERROR) {
      message = 'Network error during payment. Check your connection and retry.';
    } else {
      final raw = r.message ?? '';
      final desc = RegExp(r'"description"\s*:\s*"([^"]+)"').firstMatch(raw)?.group(1);
      message = desc ?? (raw.isNotEmpty ? raw : 'Payment failed. Please try again.');
    }
    setState(() {
      _isCheckoutOpen = false;
      _paymentError = message;
    });
  }

  void _onExternalWallet(ExternalWalletResponse r) {
    if (!mounted) return;
    setState(() {
      _isCheckoutOpen = false;
      _paymentError =
      '${r.walletName ?? 'Wallet'} selected. Finish the payment there, then check My Companies.';
    });
  }

  // =====================================================================
  // HELPERS
  // =====================================================================
  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
  }

  Future<void> _launchUrl(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      _snack('Could not open link', isError: true);
    }
  }

  bool get _busy => _isSubmitting || _isCreatingOrder || _isCheckoutOpen || _isVerifying;

  // =====================================================================
  // BUILD
  // =====================================================================
  static const _bg = Color(0xFFF5F7FB);

  /// Anything typed on the details step (used to confirm before leaving).
  bool get _hasInput =>
      _nameCtrl.text.trim().isNotEmpty ||
          _ownerCtrl.text.trim().isNotEmpty ||
          _emailCtrl.text.trim().isNotEmpty ||
          _phoneCtrl.text.trim().isNotEmpty ||
          _addressCtrl.text.trim().isNotEmpty ||
          _logoFile != null ||
          _imageFiles.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final onDetails = _step == _Step.details;
    return PopScope(
      // Details: leave freely unless something was typed (create) — then confirm.
      // Payment / done: a company now exists, so always return true (list reloads).
      // Block back while checkout or verification is running.
      canPop: onDetails && !_isSubmitting && (_isEdit || !_hasInput),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _isCheckoutOpen || _isVerifying || _isSubmitting) return;
        if (onDetails) {
          final leave = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rLg)),
              title: Text('Discard this company?', style: DT.text(size: 17, weight: FontWeight.w800)),
              content: Text('The details you entered will be lost.',
                  style: DT.text(size: 13.5, color: DT.onyx600, height: 1.5)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Keep editing',
                      style: DT.text(size: 13.5, weight: FontWeight.w700, color: DT.slate500)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DT.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
                  ),
                  child: Text('Discard', style: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ),
          );
          if (leave == true && context.mounted) Navigator.pop(context);
          return;
        }
        Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _header(),
        body: switch (_step) {
          _Step.details => _buildForm(),
          _Step.payment => _buildPaymentStep(),
          _Step.done => _buildDoneStep(),
        },
        bottomNavigationBar: onDetails ? _formFooter() : null,
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────
  PreferredSizeWidget _header() {
    final showSteps = !(_isEdit && _step == _Step.details);
    final title = switch (_step) {
      _Step.details => _isEdit ? 'Edit company' : 'Add company',
      _Step.payment => 'Registration payment',
      _Step.done => 'Registration complete',
    };
    final subtitle = switch (_step) {
      _Step.details => _isEdit ? widget.existing!.name : 'Register your business on QNXMart B2B',
      _Step.payment => _company?.name ?? '',
      _Step.done => _company?.name ?? '',
    };
    return PreferredSize(
      preferredSize: Size.fromHeight(showSteps ? 112 : 64),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: DT.slate200)),
          boxShadow: [BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SizedBox(
                height: 64,
                child: Row(
                  children: [
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: DT.onyx900),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: DT.text(size: 18, weight: FontWeight.w700, color: DT.onyx900)),
                          if (subtitle.isNotEmpty)
                            Text(subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DT.text(size: 12, weight: FontWeight.w500, color: DT.slate500)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
              if (showSteps) _buildStepper(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Stepper (create mode / payment) ────────────────────
  Widget _buildStepper() {
    final onPay = _step != _Step.details;
    final done = _step == _Step.done;

    Widget step(int n, String label, {required bool active, required bool complete}) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(
                color: complete
                    ? PX.emerald500
                    : (active ? PX.royal600 : DT.slate200),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  complete ? Icons.check_circle_rounded : Icons.radio_button_checked_rounded,
                  size: 14,
                  color: complete ? PX.emerald600 : (active ? PX.royal600 : DT.slate300),
                ),
                const SizedBox(width: 4),
                Text('Step $n · $label',
                    style: DT.text(
                        size: 11.5,
                        weight: active || complete ? FontWeight.w700 : FontWeight.w500,
                        color: active || complete ? DT.onyx800 : DT.slate400)),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          step(1, 'Company details', active: !onPay, complete: onPay),
          const SizedBox(width: 10),
          step(2, 'Payment', active: onPay && !done, complete: done),
        ],
      ),
    );
  }

  // =====================================================================
  // STEP 1 UI – FORM
  // =====================================================================
  List<(String, bool)> get _requiredChecks => [
    ('Logo', _logoFile != null || _existingLogoUrl.isNotEmpty),
    ('Company name', _nameCtrl.text.trim().isNotEmpty),
    ('Owner name', _ownerCtrl.text.trim().isNotEmpty),
    ('Email', _emailCtrl.text.trim().contains('@')),
    ('Phone', _phoneCtrl.text.trim().length == 10),
    ('State', _selectedStateId != null),
    ('District', _selectedDistrictId != null),
    ('Taluka', _selectedTalukaId != null),
    ('Village', _selectedVillageId != null),
    ('Address', _addressCtrl.text.trim().isNotEmpty),
    ('Pincode', _pincodeCtrl.text.trim().length == 6),
    ('Pickup location', _pickupCtrl.text.trim().isNotEmpty),
    if (!_isEdit) ('Terms', _acceptTerms),
  ];

  List<bool> get _recommendedChecks => [
    _gstCtrl.text.trim().isNotEmpty,
    _panCtrl.text.trim().isNotEmpty,
    _shortDescCtrl.text.trim().isNotEmpty,
    _imageFiles.isNotEmpty,
    _latitudeCtrl.text.trim().isNotEmpty,
    _websiteCtrl.text.trim().isNotEmpty || _facebookCtrl.text.trim().isNotEmpty,
  ];

  int get _requiredLeft => _requiredChecks.where((c) => !c.$2).length;

  int get _completion {
    final req = _requiredChecks;
    final rec = _recommendedChecks;
    final done = req.where((c) => c.$2).length * 2 + rec.where((c) => c).length;
    return ((done / (req.length * 2 + rec.length)) * 100).round();
  }

  Widget _buildForm() {
    final showPayBanner = _isEdit && widget.existing!.isPaymentPending;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Form(
        key: _formKey,
        // Rebuild on every keystroke so the completion card stays live.
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (showPayBanner) ...[_buildPendingPaymentBanner(), const SizedBox(height: 12)],
            _completionCard(),
            const SizedBox(height: 16),
            _brandSection(),
            const SizedBox(height: 16),
            _detailsSection(),
            const SizedBox(height: 16),
            _addressSection(),
            const SizedBox(height: 16),
            _registrationSection(),
            const SizedBox(height: 16),
            _contactsSection(),
            const SizedBox(height: 16),
            _onlineSection(),
            const SizedBox(height: 16),
            _aboutSection(),
            const SizedBox(height: 16),
            _featuresSection(),
            if (!_isEdit) ...[
              const SizedBox(height: 16),
              _finishSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _completionCard() {
    final pct = _completion;
    final left = _requiredLeft;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.slate200),
        boxShadow: PX.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: PX.royal50, shape: BoxShape.circle),
            child: Text('$pct%', style: DT.text(size: 11, weight: FontWeight.w800, color: PX.royal600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile completion', style: DT.text(size: 12.5, weight: FontWeight.w700)),
                Text(
                  left == 0 ? 'All required details added' : '$left required field${left == 1 ? '' : 's'} left',
                  style: DT.text(size: 11.5, color: left == 0 ? PX.emerald600 : DT.slate500),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 8,
                backgroundColor: DT.slate100,
                color: left == 0 ? PX.emerald500 : PX.royal600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPaymentBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DT.amber50,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.amber200),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: DT.amber700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registration fee pending', style: DT.text(size: 13.5, weight: FontWeight.w800, color: DT.amber900)),
                Text('Pay to activate your admin panel and shipping pickup.',
                    style: DT.text(size: 12, color: DT.amber800, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _goToPayment(widget.existing!),
            style: ElevatedButton.styleFrom(
              backgroundColor: DT.amber600,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
            ),
            child: Text('Pay now', style: DT.text(size: 13, weight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── 1. Logo & photos ────────────────────────────────────
  Widget _brandSection() {
    final logoMissing = _submitAttempted && !_isEdit && _logoFile == null;
    return PxSection(
      title: 'Logo & photos',
      subtitle: 'Your logo appears on every product and order',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: DT.slate100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: DT.slate200),
        ),
        child: Text('${_imageFiles.length} / $_maxImages photos',
            style: DT.text(size: 11.5, weight: FontWeight.w600, color: DT.onyx700)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLogoPicker(error: logoMissing),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 112),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DT.slate50,
                    borderRadius: BorderRadius.circular(DT.rMd),
                    border: Border.all(color: DT.borderSoft),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.info_outline_rounded, size: 15, color: PX.royal600),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isEdit
                              ? 'Tap the logo to replace it. Square PNG or JPG, up to 2MB.'
                              : 'Square PNG or JPG, up to 2MB. A clear logo on a plain background looks best.',
                          style: DT.text(size: 12, color: DT.onyx600, height: 1.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (logoMissing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Company logo is required', style: DT.text(size: 11.5, color: DT.error)),
            ),
          const SizedBox(height: 16),
          PxLabel(_isEdit ? 'Add more photos' : 'Shop / warehouse photos', optional: true),
          _buildImagesPicker(),
        ],
      ),
    );
  }

  Widget _buildLogoPicker({bool error = false}) {
    final has = _logoBytes != null || _existingLogoUrl.isNotEmpty;
    Widget content;
    if (_logoBytes != null) {
      content = Image.memory(_logoBytes!, fit: BoxFit.cover);
    } else if (_existingLogoUrl.isNotEmpty) {
      content = Image.network(_existingLogoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _logoIcon());
    } else {
      content = _logoIcon();
    }
    return GestureDetector(
      onTap: _pickLogo,
      child: CustomPaint(
        foregroundPainter: has
            ? null
            : _DashedRRectPainter(color: error ? DT.error : PX.royal600.withValues(alpha: 0.6), radius: DT.rLg),
        child: Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            color: has ? Colors.white : PX.royal50.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(DT.rLg),
            border: has ? Border.all(color: DT.slate200) : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              content,
              if (has)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: DT.onyx900.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Change', style: DT.text(size: 10.5, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoIcon() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: PX.royal600.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: const Icon(Icons.add_a_photo_outlined, color: PX.royal600, size: 20),
      ),
      const SizedBox(height: 6),
      Text(_isEdit ? 'Logo' : 'Logo *', style: DT.text(size: 12, weight: FontWeight.w700, color: PX.royal600)),
    ],
  );

  Widget _buildImagesPicker() {
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < _imageBytes.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(DT.rMd),
                  border: Border.all(color: DT.slate200),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_imageBytes[i], fit: BoxFit.cover),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(i),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: DT.onyx900.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_imageFiles.length < _maxImages)
            GestureDetector(
              onTap: _pickImages,
              child: CustomPaint(
                foregroundPainter: const _DashedRRectPainter(color: DT.slate300, radius: DT.rMd),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(DT.rMd)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined, color: DT.slate500, size: 22),
                      const SizedBox(height: 3),
                      Text('Add', style: DT.text(size: 10.5, weight: FontWeight.w600, color: DT.slate500)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 2. Company details ──────────────────────────────────
  Widget _detailsSection() {
    return PxSection(
      title: 'Company details',
      subtitle: 'Name, owner and how buyers can reach you',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PxLabel('Company name', required: true),
          PxTextField(
            controller: _nameCtrl,
            hint: 'e.g. ABC Industries Pvt Ltd',
            icon: Icons.business_outlined,
            iconColor: PX.royal600,
            capitalization: TextCapitalization.words,
            validator: (v) => _required(v, 'Company name'),
          ),
          const SizedBox(height: 14),
          const PxLabel('Slogan', optional: true),
          PxTextField(controller: _sloganCtrl, hint: 'e.g. Quality first', icon: Icons.campaign_outlined),
          const SizedBox(height: 14),
          const PxLabel('Owner name', required: true),
          PxTextField(
            controller: _ownerCtrl,
            hint: 'e.g. Rahul Patil',
            icon: Icons.person_outline_rounded,
            iconColor: PX.royal600,
            capitalization: TextCapitalization.words,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Owner name required';
              if (!RegExp(r'^[a-zA-Z.\s]+$').hasMatch(v.trim())) return 'Letters only';
              return null;
            },
          ),
          const SizedBox(height: 14),
          const PxLabel('Email', required: true),
          PxTextField(
            controller: _emailCtrl,
            hint: 'name@company.com',
            icon: Icons.mail_outline_rounded,
            iconColor: PX.royal600,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email required';
              if (!RegExp(r'^[\w\-\.+]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(v.trim())) return 'Invalid email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PxLabel('Phone', required: true),
                    PxTextField(
                      controller: _phoneCtrl,
                      hint: '10-digit',
                      icon: Icons.phone_outlined,
                      iconColor: PX.royal600,
                      keyboardType: TextInputType.phone,
                      inputFormatters: _phoneFormatters,
                      validator: (v) => _validatePhone(v, 'Phone'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PxLabel('WhatsApp', optional: true),
                    PxTextField(
                      controller: _whatsappCtrl,
                      hint: '10-digit',
                      icon: Icons.chat_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: _phoneFormatters,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        return _validatePhone(v, 'WhatsApp');
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_phoneCtrl.text.trim().length == 10 && _whatsappCtrl.text.trim().isEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: PxLinkButton(
                label: 'Same as phone',
                icon: Icons.content_copy_rounded,
                onTap: () => setState(() => _whatsappCtrl.text = _phoneCtrl.text.trim()),
              ),
            ),
        ],
      ),
    );
  }

  // ── 3. Address & location ───────────────────────────────
  Widget _addressSection() {
    return PxSection(
      title: 'Address & location',
      subtitle: 'Used for your company page and shipping pickup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _locationPicker(
            label: 'State',
            icon: Icons.map_outlined,
            items: _states,
            selectedId: _selectedStateId,
            loading: _isLoadingStates,
            error: _statesError,
            onRetry: _fetchStates,
            onSelected: _onStateSelected,
          ),
          const SizedBox(height: 12),
          _locationPicker(
            label: 'District',
            icon: Icons.location_city_outlined,
            items: _districts,
            selectedId: _selectedDistrictId,
            loading: _isLoadingDistricts,
            error: _districtsError,
            enabled: _selectedStateId != null,
            disabledHint: 'Select a state first',
            onRetry: () => _fetchDistricts(_selectedStateId!),
            onSelected: _onDistrictSelected,
          ),
          const SizedBox(height: 12),
          _locationPicker(
            label: 'Taluka',
            icon: Icons.account_tree_outlined,
            items: _talukas,
            selectedId: _selectedTalukaId,
            loading: _isLoadingTalukas,
            error: _talukasError,
            enabled: _selectedDistrictId != null,
            disabledHint: 'Select a district first',
            onRetry: () => _fetchTalukas(_selectedDistrictId!),
            onSelected: _onTalukaSelected,
          ),
          const SizedBox(height: 12),
          _locationPicker(
            label: 'Village',
            icon: Icons.holiday_village_outlined,
            items: _villages,
            selectedId: _selectedVillageId,
            loading: _isLoadingVillages,
            error: _villagesError,
            enabled: _selectedTalukaId != null,
            disabledHint: 'Select a taluka first',
            onRetry: () => _fetchVillages(_selectedTalukaId!),
            onSelected: _onVillageSelected,
          ),
          const SizedBox(height: 16),
          const PxLabel('Street address', required: true),
          PxTextField(
            controller: _addressCtrl,
            hint: 'Building, street, landmark',
            maxLines: 2,
            tinted: true,
            capitalization: TextCapitalization.sentences,
            validator: (v) => _required(v, 'Address'),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PxLabel('Pincode', required: true),
                    PxTextField(
                      controller: _pincodeCtrl,
                      hint: '6-digit',
                      icon: Icons.pin_drop_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Pincode required';
                        if (v.trim().length != 6) return '6-digit pincode';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PxLabel('Pickup location', required: true),
                    PxTextField(
                      controller: _pickupCtrl,
                      hint: 'Where couriers collect',
                      icon: Icons.local_shipping_outlined,
                      validator: (v) => _required(v, 'Pickup location'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_addressCtrl.text.trim().isNotEmpty && _pickupCtrl.text.trim().isEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: PxLinkButton(
                label: 'Use street address',
                icon: Icons.content_copy_rounded,
                onTap: () => setState(() => _pickupCtrl.text = _addressCtrl.text.trim()),
              ),
            ),
          const SizedBox(height: 16),
          // Live location box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xB3F8FAFC),
              borderRadius: BorderRadius.circular(DT.rMd),
              border: Border.all(color: DT.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Map location', style: DT.text(size: 12, weight: FontWeight.w700, color: DT.onyx800)),
                    const Spacer(),
                    Text('Optional · helps buyers find you', style: DT.text(size: 11, color: DT.slate500)),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                  icon: _isFetchingLocation
                      ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: PX.royal600))
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(_isFetchingLocation ? 'Getting your location…' : 'Use my current location',
                      style: DT.text(size: 13.5, weight: FontWeight.w700, color: PX.royal600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PX.royal600,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: PX.royal200),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: PxTextField(
                        controller: _latitudeCtrl,
                        hint: 'Latitude',
                        dense: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PxTextField(
                        controller: _longitudeCtrl,
                        hint: 'Longitude',
                        dense: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                    ),
                  ],
                ),
                _buildLocationMapPreview(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Registration & tax ───────────────────────────────
  Widget _registrationSection() {
    return PxSection(
      title: 'Registration & tax',
      subtitle: 'Optional, but verified details build buyer trust',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PxLabel('GST number', optional: true),
          PxTextField(
            controller: _gstCtrl,
            hint: 'e.g. 27ABCDE1234F1Z5',
            icon: Icons.receipt_long_outlined,
            capitalization: TextCapitalization.characters,
            inputFormatters: [LengthLimitingTextInputFormatter(15)],
            validator: (v) {
              final t = (v ?? '').trim().toUpperCase();
              if (t.isEmpty) return null;
              if (!RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][A-Z\d]Z[A-Z\d]$').hasMatch(t)) return 'Invalid GST number';
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PxLabel('PAN'),
                    PxTextField(
                      controller: _panCtrl,
                      hint: 'ABCDE1234F',
                      icon: Icons.credit_card_outlined,
                      capitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(10)],
                      validator: (v) {
                        final t = (v ?? '').trim().toUpperCase();
                        if (t.isEmpty) return null;
                        if (!RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(t)) return 'Invalid PAN';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PxLabel('Registration no.'),
                    PxTextField(controller: _regNoCtrl, hint: 'REG123', icon: Icons.assignment_outlined),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PxLabel('IAN no.'),
                    PxTextField(
                      controller: _ianCtrl,
                      hint: 'IAN123',
                      icon: Icons.verified_outlined,
                      inputFormatters: [LengthLimitingTextInputFormatter(25)],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PxLabel('Firm reg. year'),
                    PxTextField(
                      controller: _farmYearCtrl,
                      hint: 'e.g. 2020',
                      icon: Icons.calendar_today_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        final y = int.tryParse(t) ?? 0;
                        if (y < 1900 || y > DateTime.now().year) return 'Invalid year';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 5. Extra contacts ───────────────────────────────────
  Widget _contactsSection() {
    return PxSection(
      title: 'Extra contacts',
      subtitle: 'More emails or numbers for enquiries',
      icon: Icons.contacts_outlined,
      compact: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          _buildChipsEditor(
            label: 'Email IDs',
            hint: 'Type an email and tap +',
            controller: _extraEmailCtrl,
            items: _extraEmails,
            keyboardType: TextInputType.emailAddress,
            icon: Icons.alternate_email_rounded,
            onSubmitted: _addEmail,
            onRemove: (i) => setState(() => _extraEmails.removeAt(i)),
          ),
          const SizedBox(height: 14),
          _buildChipsEditor(
            label: 'Contact numbers',
            hint: '10-digit number, tap +',
            controller: _extraContactCtrl,
            items: _extraContacts,
            keyboardType: TextInputType.phone,
            inputFormatters: _phoneFormatters,
            icon: Icons.phone_outlined,
            onSubmitted: _addContact,
            onRemove: (i) => setState(() => _extraContacts.removeAt(i)),
          ),
        ],
      ),
    );
  }

  Widget _buildChipsEditor({
    required String label,
    required String hint,
    required TextEditingController controller,
    required List<String> items,
    required VoidCallback onSubmitted,
    required void Function(int) onRemove,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PxLabel(label, optional: true),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmitted(),
          style: DT.text(size: 13.5, weight: FontWeight.w500),
          decoration: pxInputDecoration(
            hint: hint,
            icon: icon,
            suffix: IconButton(
              tooltip: 'Add',
              icon: const Icon(Icons.add_circle_rounded, color: PX.royal600),
              onPressed: onSubmitted,
            ),
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < items.length; i++)
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                  decoration: BoxDecoration(color: DT.slate100, borderRadius: BorderRadius.circular(DT.rSm)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(items[i], style: DT.text(size: 12, weight: FontWeight.w500, color: DT.onyx700)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => onRemove(i),
                        child: const Icon(Icons.cancel_rounded, size: 15, color: DT.slate400),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // ── 6. Online presence ──────────────────────────────────
  Widget _onlineSection() {
    Widget link(TextEditingController c, String label, String hint, IconData icon) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PxLabel(label, optional: true),
          PxTextField(controller: c, hint: hint, icon: icon, keyboardType: TextInputType.url),
        ],
      ),
    );
    return PxSection(
      title: 'Online presence',
      subtitle: 'Website, social pages and policies',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          link(_websiteCtrl, 'Website', 'yourcompany.com', Icons.language_rounded),
          link(_facebookCtrl, 'Facebook', 'facebook.com/yourpage', Icons.facebook_rounded),
          link(_instagramCtrl, 'Instagram', 'instagram.com/yourpage', Icons.camera_alt_outlined),
          link(_linkedinCtrl, 'LinkedIn', 'linkedin.com/company/…', Icons.work_outline_rounded),
          link(_youtubeCtrl, 'YouTube', 'youtube.com/@yourchannel', Icons.smart_display_outlined),
          const Divider(height: 20, color: DT.slate100),
          link(_privacyCtrl, 'Privacy policy URL', 'https://…', Icons.privacy_tip_outlined),
          link(_termsCtrl, 'Terms & conditions URL', 'https://…', Icons.gavel_outlined),
          Text('Links without https:// are fixed automatically.',
              style: DT.text(size: 11.5, color: DT.slate400)),
        ],
      ),
    );
  }

  // ── 7. About ────────────────────────────────────────────
  Widget _aboutSection() {
    return PxSection(
      title: 'About your company',
      subtitle: 'Shown on your company page',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PxLabel('Short description',
              trailing: Text('${_shortDescCtrl.text.length}/160', style: DT.text(size: 11, color: DT.slate400))),
          PxTextField(
            controller: _shortDescCtrl,
            hint: 'One line about what you do',
            maxLines: 2,
            tinted: true,
            capitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(160)],
          ),
          const SizedBox(height: 14),
          const PxLabel('Long description', optional: true),
          PxTextField(
            controller: _longDescCtrl,
            hint: 'Products, experience, clients, certifications…',
            maxLines: 5,
            tinted: true,
            capitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  // ── 8. Certifications & features ────────────────────────
  Widget _featuresSection() {
    return PxSection(
      title: 'Certifications & features',
      icon: Icons.workspace_premium_outlined,
      compact: true,
      child: Column(
        children: [
          const SizedBox(height: 4),
          _switchTile('ISI certified', 'Bureau of Indian Standards mark', Icons.verified_rounded, _isiCertified,
                  (v) => setState(() => _isiCertified = v)),
          _switchTile('ISO certified', 'International quality standard', Icons.workspace_premium_rounded,
              _isoCertified, (v) => setState(() => _isoCertified = v)),
          _switchTile('Cash on delivery', 'Buyers can pay when the order arrives', Icons.payments_outlined,
              _codAvailable, (v) => setState(() => _codAvailable = v)),
        ],
      ),
    );
  }

  Widget _switchTile(String title, String subtitle, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: value ? PX.royal50 : const Color(0x99F8FAFC),
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: value ? PX.royal200 : DT.slate200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: value ? PX.royal600 : DT.slate400),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DT.text(size: 13, weight: FontWeight.w700, color: DT.onyx900)),
                Text(subtitle, style: DT.text(size: 11, color: DT.slate500)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: PX.royal600,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: DT.slate300,
            trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }

  // ── 9. Referral + terms (create only) ───────────────────
  Widget _finishSection() {
    final termsMissing = _submitAttempted && !_acceptTerms;
    return PxSection(
      title: 'Almost done',
      subtitle: 'A one-time registration fee is charged after creation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PxLabel('Referral code', optional: true),
          PxTextField(
            controller: _referralCtrl,
            hint: 'Marketing partner code',
            icon: Icons.card_giftcard_outlined,
            capitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(DT.rMd),
            onTap: () => setState(() => _acceptTerms = !_acceptTerms),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
              decoration: BoxDecoration(
                color: _acceptTerms ? PX.royal50 : Colors.white,
                borderRadius: BorderRadius.circular(DT.rMd),
                border: Border.all(color: termsMissing ? DT.error : (_acceptTerms ? PX.royal200 : DT.slate200)),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _acceptTerms,
                    onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                    activeColor: PX.royal600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'I accept the ',
                        style: DT.text(size: 13, weight: FontWeight.w500, color: DT.onyx800),
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: GestureDetector(
                              onTap: _openTerms,
                              child: Text('Terms & Conditions',
                                  style: DT.text(
                                      size: 13,
                                      weight: FontWeight.w700,
                                      color: PX.royal600,
                                      decoration: TextDecoration.underline)),
                            ),
                          ),
                          TextSpan(text: ' *', style: DT.text(size: 13, color: PX.rose500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (termsMissing)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text('Please accept the terms to continue', style: DT.text(size: 11.5, color: DT.error)),
            ),
        ],
      ),
    );
  }

  // ── Sticky footer ───────────────────────────────────────
  Widget _formFooter() {
    final left = _requiredLeft;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DT.slate200)),
        boxShadow: PX.stickyShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PX.royal600,
                    disabledBackgroundColor: PX.royal600.withValues(alpha: 0.55),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: const Color(0x401A68FA),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
                  ),
                  child: _isSubmitting
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white)),
                      const SizedBox(width: 10),
                      Text(_isEdit ? 'Saving…' : 'Creating company…',
                          style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
                    ],
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_isEdit ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(_isEdit ? 'Save changes' : 'Create & continue to payment',
                          style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                left == 0
                    ? 'All required details added · ${_completion}% complete'
                    : '$left required field${left == 1 ? '' : 's'} left',
                style: DT.text(size: 11, color: left == 0 ? PX.emerald600 : DT.slate400),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // STEP 2 UI – PAYMENT
  // =====================================================================
  Widget _buildPaymentStep() {
    final company = _company!;
    final order = _order;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Company created
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  _companyAvatar(company),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PxPill(
                          text: _isEdit ? 'Company registered' : 'Company created',
                          bg: PX.emerald100,
                          fg: DT.emerald700,
                          icon: Icons.check_rounded,
                        ),
                        const SizedBox(height: 6),
                        Text(company.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DT.text(size: 17, weight: FontWeight.w800, color: DT.onyx900)),
                        if (company.ownerName.isNotEmpty)
                          Text(company.ownerName, style: DT.text(size: 12.5, color: DT.slate500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Fee
            Container(
              decoration: _cardDecoration(),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0B2A5B), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ONE-TIME REGISTRATION FEE',
                            style: DT.text(size: 11, weight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.8)),
                        const SizedBox(height: 6),
                        if (_isCreatingOrder)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: LinearProgressIndicator(minHeight: 3, color: Colors.white, backgroundColor: Colors.white24),
                          )
                        else
                          Text(order?.amountLabel ?? '—',
                              style: DT.text(size: 36, weight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
                        Text('Paid once · no renewal', style: DT.text(size: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                    child: Column(
                      children: [
                        _benefit(Icons.dashboard_customize_outlined,
                            'Company admin panel (login link sent to ${company.email.isEmpty ? 'your email' : company.email})'),
                        _benefit(Icons.local_shipping_outlined, 'Shipping pickup set up for your orders'),
                        _benefit(Icons.storefront_outlined, 'List products for B2B buyers'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_paymentError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DT.errorBg,
                  borderRadius: BorderRadius.circular(DT.rMd),
                  border: Border.all(color: DT.errorBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: DT.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_paymentError!, style: DT.text(size: 12.5, color: DT.error, height: 1.45)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : (order == null ? _createOrder : _openCheckout),
                icon: Icon(order == null ? Icons.refresh_rounded : Icons.lock_outline_rounded, size: 18),
                label: Text(
                  order == null
                      ? (_isCreatingOrder ? 'Preparing payment…' : 'Retry')
                      : 'Pay ${order.amountLabel} securely',
                  style: DT.text(size: 15, weight: FontWeight.w800, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PX.royal600,
                  disabledBackgroundColor: PX.royal600.withValues(alpha: 0.5),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: const Color(0x401A68FA),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user_outlined, size: 14, color: DT.slate400),
                const SizedBox(width: 5),
                Text(
                  kIsWeb ? 'Razorpay checkout works in the Android app only' : 'Secured by Razorpay · UPI, cards, net banking',
                  style: DT.text(size: 11.5, color: DT.slate400),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, true),
                child: Text('Pay later', style: DT.text(size: 14, weight: FontWeight.w700, color: DT.slate500)),
              ),
            ),
            Center(
              child: Text('You can pay any time from My Companies.',
                  style: DT.text(size: 11.5, color: DT.slate400)),
            ),
          ],
        ),
        if (_isVerifying)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(DT.rLg)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: PX.royal600)),
                    const SizedBox(width: 16),
                    Text('Confirming payment…', style: DT.text(size: 14, weight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _benefit(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: PX.royal50, borderRadius: BorderRadius.circular(DT.rSm)),
          child: Icon(icon, size: 17, color: PX.royal600),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(text, style: DT.text(size: 13, color: DT.onyx800, height: 1.4)),
          ),
        ),
      ],
    ),
  );

  // =====================================================================
  // STEP 3 UI – DONE
  // =====================================================================
  Widget _buildDoneStep() {
    final company = _company!;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: PX.emerald100,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFA7F3D0), width: 6),
              ),
              child: const Icon(Icons.check_rounded, size: 50, color: DT.emerald700),
            ),
            const SizedBox(height: 22),
            Text('Payment successful', style: DT.text(size: 22, weight: FontWeight.w800, color: DT.onyx900)),
            const SizedBox(height: 8),
            Text(
              '${company.name} is now registered on QNXMart B2B'
                  '${_order != null && !_order!.alreadyPaid ? ' · ${_order!.amountLabel} paid' : ''}.',
              textAlign: TextAlign.center,
              style: DT.text(size: 14, color: DT.onyx600, height: 1.5),
            ),
            if (_paidPaymentId != null && _paidPaymentId!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Material(
                color: DT.slate100,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _paidPaymentId!));
                    _snack('Payment reference copied');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Ref: $_paidPaymentId',
                            style: DT.text(size: 12.5, weight: FontWeight.w700, color: DT.onyx800)),
                        const SizedBox(width: 8),
                        const Icon(Icons.copy_rounded, size: 15, color: DT.slate500),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PX.royal50,
                borderRadius: BorderRadius.circular(DT.rMd),
                border: Border.all(color: PX.royal200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_read_outlined, color: PX.royal600, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      company.email.isNotEmpty
                          ? 'Admin panel login details were sent to ${company.email}.'
                          : 'Admin panel login details were sent to your email.',
                      style: DT.text(size: 12.5, color: DT.blue900, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PX.royal600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
                ),
                child: Text('Go to My Companies',
                    style: DT.text(size: 15, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // SHARED PIECES
  // =====================================================================
  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(DT.rLg),
    border: Border.all(color: DT.slate200),
    boxShadow: PX.cardShadow,
  );

  Widget _companyAvatar(Company c) {
    Widget initials() => Container(
      color: PX.royal50,
      alignment: Alignment.center,
      child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
          style: DT.text(size: 22, weight: FontWeight.w800, color: PX.royal600)),
    );
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: _logoBytes != null
          ? Image.memory(_logoBytes!, fit: BoxFit.cover)
          : c.logo.isNotEmpty
          ? Image.network(c.logo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials())
          : initials(),
    );
  }

  // ─── Location picker field + searchable sheet ───────────
  Widget _locationPicker({
    required String label,
    required IconData icon,
    required List<LocationItem> items,
    required int? selectedId,
    required bool loading,
    required String? error,
    required VoidCallback onRetry,
    required ValueChanged<LocationItem> onSelected,
    bool enabled = true,
    String? disabledHint,
  }) {
    LocationItem? selected;
    for (final e in items) {
      if (e.id == selectedId) selected = e;
    }
    final missing = _submitAttempted && enabled && selected == null && !loading;
    final canOpen = enabled && !loading && items.isNotEmpty;

    String hint;
    if (!enabled) {
      hint = disabledHint ?? 'Select $label';
    } else if (loading) {
      hint = 'Loading ${label.toLowerCase()}s…';
    } else if (items.isEmpty) {
      hint = 'No ${label.toLowerCase()}s available';
    } else {
      hint = 'Select ${label.toLowerCase()}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PxLabel(label, required: true),
        Material(
          color: enabled ? Colors.white : DT.slate100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DT.rMd),
            side: BorderSide(
              color: error != null || missing ? DT.error : (selected != null ? PX.royal600 : DT.slate200),
              width: selected != null ? 1.4 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(DT.rMd),
            onTap: canOpen
                ? () async {
              FocusScope.of(context).unfocus();
              final picked = await _showLocationSheet(label, items, selectedId);
              if (picked != null) onSelected(picked);
            }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: !enabled ? DT.slate300 : PX.royal600),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selected?.name ?? hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(
                        size: 13.5,
                        weight: FontWeight.w500,
                        color: selected != null ? DT.onyx900 : DT.slate400,
                      ),
                    ),
                  ),
                  if (loading)
                    const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: PX.royal600))
                  else
                    Icon(Icons.expand_more_rounded, color: canOpen ? DT.slate500 : DT.slate300),
                ],
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: DT.error),
                const SizedBox(width: 4),
                Expanded(child: Text(error, style: DT.text(size: 11.5, color: DT.error))),
                GestureDetector(
                  onTap: onRetry,
                  child: Text('Retry', style: DT.text(size: 11.5, weight: FontWeight.w700, color: PX.royal600)),
                ),
              ],
            ),
          )
        else if (missing)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Text('$label is required', style: DT.text(size: 11.5, color: DT.error)),
          ),
      ],
    );
  }

  Future<LocationItem?> _showLocationSheet(String label, List<LocationItem> items, int? selectedId) {
    return showModalBottomSheet<LocationItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DT.rXl))),
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final q = query.trim().toLowerCase();
            final filtered = q.isEmpty ? items : items.where((e) => e.name.toLowerCase().contains(q)).toList();
            final media = MediaQuery.of(ctx);
            return Padding(
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: SizedBox(
                height: media.size.height * 0.72,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: DT.slate300, borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Select ${label.toLowerCase()}',
                                style: DT.text(size: 16.5, weight: FontWeight.w800)),
                          ),
                          IconButton(
                              onPressed: () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded, color: DT.slate500)),
                        ],
                      ),
                    ),
                    if (items.length > 8)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: TextField(
                          onChanged: (v) => setSheet(() => query = v),
                          style: DT.text(size: 13.5),
                          decoration: pxInputDecoration(hint: 'Search ${label.toLowerCase()}', icon: Icons.search_rounded, tinted: true),
                        ),
                      ),
                    const Divider(height: 1, color: DT.slate200),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(child: Text('No match for "$query"', style: DT.text(size: 13, color: DT.slate500)))
                          : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: DT.slate100),
                        itemBuilder: (_, i) {
                          final item = filtered[i];
                          final sel = item.id == selectedId;
                          return ListTile(
                            title: Text(item.name,
                                style: DT.text(
                                    size: 14,
                                    weight: sel ? FontWeight.w700 : FontWeight.w500,
                                    color: sel ? PX.royal600 : DT.onyx900)),
                            trailing: sel ? const Icon(Icons.check_circle_rounded, color: PX.royal600) : null,
                            onTap: () => Navigator.pop(ctx, item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLocationMapPreview() {
    if (_previewLat == null || _previewLng == null) return const SizedBox.shrink();
    final lat = _previewLat!;
    final lng = _previewLng!;
    final staticMapUrl =
        'https://staticmap.openstreetmap.de/staticmap.php?center=$lat,$lng&zoom=16&size=800x300&maptype=mapnik&markers=$lat,$lng,red-pushpin';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.slate200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Image.network(
            staticMapUrl,
            height: 150,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, p) => p == null
                ? child
                : Container(
                height: 150,
                color: DT.slate100,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2, color: PX.royal600)),
            errorBuilder: (_, __, ___) => Container(
              height: 90,
              color: DT.slate100,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map_outlined, color: DT.slate400),
                  const SizedBox(width: 6),
                  Text('Map preview unavailable', style: DT.text(size: 12, color: DT.slate500)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 16, color: PX.royal600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                      style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx700)),
                ),
                PxLinkButton(
                  label: 'Open in Maps',
                  icon: Icons.open_in_new_rounded,
                  iconAfter: true,
                  onTap: () => _launchUrl('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Validation helpers ───────────────────────────────
  static final List<TextInputFormatter> _phoneFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  String? _required(String? v, String name) => (v == null || v.trim().isEmpty) ? '$name is required' : null;

  String? _validatePhone(String? v, String name) {
    if (v == null || v.trim().isEmpty) return '$name is required';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())) return 'Enter valid 10-digit number';
    return null;
  }
}

// =====================================================================
// DASHED BORDER (logo / add-photo boxes)
// =====================================================================
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.8, 0.8, size.width - 1.6, size.height - 1.6),
      Radius.circular(radius),
    );
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => old.color != color || old.radius != radius;
}