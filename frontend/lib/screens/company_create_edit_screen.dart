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
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../models/company_locations_models.dart';
import '../models/company_model.dart';
import '../services/company_locations_service.dart';
import '../services/company_service.dart';
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
      if (order.isSuccess) {
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
  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _Step.details => _isEdit ? 'Edit Company' : 'Create Company',
      _Step.payment => 'Registration Payment',
      _Step.done => 'Registration Complete',
    };

    return PopScope(
      // Once a company exists (payment / done step), always return true so the
      // list reloads. Block back while checkout or verification is running.
      canPop: _step == _Step.details && !_isSubmitting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _isCheckoutOpen || _isVerifying || _isSubmitting) return;
        Navigator.pop(context, true);
      },
      child: Scaffold(
        backgroundColor: AppConstants.surfaceColor,
        appBar: AppBar(
          backgroundColor: AppConstants.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(title,
              style: GoogleFonts.inter(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          bottom: _isEdit && _step == _Step.details
              ? null
              : PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: _buildStepper(),
          ),
        ),
        body: switch (_step) {
          _Step.details => _buildForm(),
          _Step.payment => _buildPaymentStep(),
          _Step.done => _buildDoneStep(),
        },
      ),
    );
  }

  // ─── Stepper (create mode) ─────────────────────────────
  Widget _buildStepper() {
    Widget dot(int n, String label, bool active, bool done) {
      final color = done || active ? Colors.white : Colors.white54;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? AppConstants.accent : (active ? Colors.white : Colors.transparent),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
            ),
            child: done
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text('$n',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? AppConstants.primary : color)),
          ),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
        ],
      );
    }

    final onPay = _step != _Step.details;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          dot(1, 'Company details', !onPay, onPay),
          Expanded(
            child: Container(
              height: 1.5,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: onPay ? AppConstants.accent : Colors.white38,
            ),
          ),
          dot(2, 'Payment', _step == _Step.payment, _step == _Step.done),
        ],
      ),
    );
  }

  // =====================================================================
  // STEP 1 UI – FORM
  // =====================================================================
  Widget _buildForm() {
    final showPayBanner = _isEdit && widget.existing!.isPaymentPending;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showPayBanner) ...[_buildPendingPaymentBanner(), const SizedBox(height: 16)],

              // ── LOGO ─────────────────────────────────
              _sectionTitle(_isEdit ? 'Company Logo' : 'Company Logo *'),
              const SizedBox(height: 10),
              _buildLogoPicker(),
              const SizedBox(height: 20),

              // ── PHOTOS ───────────────────────────────
              _sectionTitle(_isEdit ? 'Add More Photos (Optional)' : 'Company Photos (Optional)'),
              const SizedBox(height: 4),
              Text('Shop, warehouse or product photos · up to $_maxImages',
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppConstants.textSecondary)),
              const SizedBox(height: 10),
              _buildImagesPicker(),
              const SizedBox(height: 20),

              // ── BASIC ────────────────────────────────
              _sectionTitle('Basic Information'),
              const SizedBox(height: 12),
              _field(_nameCtrl, 'Company Name *', 'e.g. ABC Pvt Ltd', Icons.business_outlined,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => _required(v, 'Company name')),
              const SizedBox(height: 14),
              _field(_sloganCtrl, 'Company Slogan', 'e.g. Quality First', Icons.campaign_outlined),
              const SizedBox(height: 14),
              _field(_ownerCtrl, 'Owner Name *', 'e.g. Rahul Patil', Icons.person_outline,
                  textCapitalization: TextCapitalization.words, validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Owner name required';
                    if (!RegExp(r'^[a-zA-Z.\s]+$').hasMatch(v.trim())) return 'Letters only';
                    return null;
                  }),
              const SizedBox(height: 14),
              _field(_emailCtrl, 'Email *', 'name@example.com', Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress, validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email required';
                    if (!RegExp(r'^[\w\-\.+]+@([\w\-]+\.)+[\w\-]{2,}$').hasMatch(v.trim())) {
                      return 'Invalid email';
                    }
                    return null;
                  }),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(_phoneCtrl, 'Phone *', '10-digit', Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: _phoneFormatters,
                        validator: (v) => _validatePhone(v, 'Phone')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(_whatsappCtrl, 'WhatsApp', '10-digit', Icons.chat_outlined,
                        keyboardType: TextInputType.phone,
                        inputFormatters: _phoneFormatters, validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          return _validatePhone(v, 'WhatsApp');
                        }),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _field(_websiteCtrl, 'Website URL', 'example.com', Icons.language_outlined,
                  keyboardType: TextInputType.url),
              const SizedBox(height: 20),

              // ── ADDRESS & LOCATION ───────────────────
              _sectionTitle('Address & Location'),
              const SizedBox(height: 12),
              Text('Select in order: state, district, taluka, then village.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppConstants.textSecondary)),
              const SizedBox(height: 12),
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
              const SizedBox(height: 14),
              _field(_addressCtrl, 'Address *', 'Street address', Icons.home_outlined,
                  maxLines: 2, validator: (v) => _required(v, 'Address')),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                  icon: _isFetchingLocation
                      ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: Text(_isFetchingLocation ? 'Fetching location...' : 'Get My Live Location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.primary,
                    side: const BorderSide(color: AppConstants.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _field(_latitudeCtrl, 'Latitude', 'Auto-filled', Icons.my_location,
                        keyboardType:
                        const TextInputType.numberWithOptions(decimal: true, signed: true)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                        _longitudeCtrl, 'Longitude', 'Auto-filled', Icons.location_searching,
                        keyboardType:
                        const TextInputType.numberWithOptions(decimal: true, signed: true)),
                  ),
                ],
              ),
              _buildLocationMapPreview(),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(_pincodeCtrl, 'Pincode *', '6-digit', Icons.pin_drop_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ], validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Pincode required';
                          if (v.trim().length != 6) return '6-digit pincode';
                          return null;
                        }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(_pickupCtrl, 'Pickup Location *', 'Pickup address',
                        Icons.local_shipping_outlined,
                        validator: (v) => _required(v, 'Pickup location')),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── REGISTRATION ─────────────────────────
              _sectionTitle('Registration Details'),
              const SizedBox(height: 12),
              _field(_gstCtrl, 'GST Number', 'e.g. 27ABCDE1234F1Z5', Icons.receipt_long_outlined,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [LengthLimitingTextInputFormatter(15)], validator: (v) {
                    final t = (v ?? '').trim().toUpperCase();
                    if (t.isEmpty) return null;
                    if (!RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][A-Z\d]Z[A-Z\d]$').hasMatch(t)) {
                      return 'Invalid GST number';
                    }
                    return null;
                  }),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(_panCtrl, 'PAN Number', 'ABCDE1234F', Icons.credit_card_outlined,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [LengthLimitingTextInputFormatter(10)], validator: (v) {
                          final t = (v ?? '').trim().toUpperCase();
                          if (t.isEmpty) return null;
                          if (!RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(t)) return 'Invalid PAN';
                          return null;
                        }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                        _regNoCtrl, 'Registration No.', 'REG123', Icons.assignment_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(_ianCtrl, 'IAN No.', 'IAN123', Icons.verified_outlined,
                        inputFormatters: [LengthLimitingTextInputFormatter(25)]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(_farmYearCtrl, 'Firm Reg. Year', 'e.g. 2020',
                        Icons.calendar_today_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ], validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return null;
                          final y = int.tryParse(t) ?? 0;
                          if (y < 1900 || y > DateTime.now().year) return 'Invalid year';
                          return null;
                        }),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── EXTRA CONTACTS ───────────────────────
              _sectionTitle('Extra Emails / Contacts (Optional)'),
              const SizedBox(height: 12),
              _buildChipsEditor(
                label: 'Email IDs',
                hint: 'Enter email & tap +',
                controller: _extraEmailCtrl,
                items: _extraEmails,
                keyboardType: TextInputType.emailAddress,
                onSubmitted: _addEmail,
                onRemove: (i) => setState(() => _extraEmails.removeAt(i)),
              ),
              const SizedBox(height: 14),
              _buildChipsEditor(
                label: 'Contact Numbers',
                hint: 'Enter 10-digit & tap +',
                controller: _extraContactCtrl,
                items: _extraContacts,
                keyboardType: TextInputType.phone,
                inputFormatters: _phoneFormatters,
                onSubmitted: _addContact,
                onRemove: (i) => setState(() => _extraContacts.removeAt(i)),
              ),
              const SizedBox(height: 20),

              // ── SOCIAL ───────────────────────────────
              _sectionTitle('Social Media Links (Optional)'),
              const SizedBox(height: 12),
              _field(_facebookCtrl, 'Facebook', 'facebook.com/yourpage', Icons.facebook,
                  keyboardType: TextInputType.url),
              const SizedBox(height: 14),
              _field(_linkedinCtrl, 'LinkedIn', 'linkedin.com/company/...',
                  Icons.business_center_outlined,
                  keyboardType: TextInputType.url),
              const SizedBox(height: 14),
              _field(_instagramCtrl, 'Instagram', 'instagram.com/...', Icons.camera_alt_outlined,
                  keyboardType: TextInputType.url),
              const SizedBox(height: 14),
              _field(_youtubeCtrl, 'YouTube', 'youtube.com/@...', Icons.play_circle_outline,
                  keyboardType: TextInputType.url),
              const SizedBox(height: 20),

              // ── LEGAL ────────────────────────────────
              _sectionTitle('Legal URLs (Optional)'),
              const SizedBox(height: 12),
              _field(_privacyCtrl, 'Privacy Policy URL', 'https://...', Icons.privacy_tip_outlined,
                  keyboardType: TextInputType.url),
              const SizedBox(height: 14),
              _field(_termsCtrl, 'Terms & Conditions URL', 'https://...',
                  Icons.description_outlined,
                  keyboardType: TextInputType.url),
              const SizedBox(height: 20),

              // ── DESCRIPTION ──────────────────────────
              _sectionTitle('Description'),
              const SizedBox(height: 12),
              _field(_shortDescCtrl, 'Short Description', 'Max 160 chars',
                  Icons.short_text_outlined,
                  maxLines: 2, inputFormatters: [LengthLimitingTextInputFormatter(160)]),
              const SizedBox(height: 14),
              _field(_longDescCtrl, 'Long Description', 'Detailed description',
                  Icons.notes_outlined,
                  maxLines: 4),
              const SizedBox(height: 20),

              // ── CERTIFICATIONS ───────────────────────
              _sectionTitle('Certifications & Features'),
              const SizedBox(height: 8),
              _switchTile('ISI Certified', _isiCertified, (v) => setState(() => _isiCertified = v)),
              _switchTile('ISO Certified', _isoCertified, (v) => setState(() => _isoCertified = v)),
              _switchTile('COD Available', _codAvailable, (v) => setState(() => _codAvailable = v)),
              const SizedBox(height: 14),

              // ── REFERRAL (create only) ───────────────
              if (!_isEdit) ...[
                _field(_referralCtrl, 'Referral Code (Optional)', 'Marketing partner code',
                    Icons.card_giftcard_outlined,
                    textCapitalization: TextCapitalization.characters),
                const SizedBox(height: 20),
              ],

              // ── TERMS ────────────────────────────────
              if (!_isEdit)
                CheckboxListTile(
                  value: _acceptTerms,
                  onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                  activeColor: AppConstants.primary,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: GestureDetector(
                    onTap: _openTerms,
                    child: RichText(
                      text: TextSpan(
                        text: 'I accept the ',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.textPrimary),
                        children: [
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppConstants.info,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ),
                  subtitle: Text('A one-time registration fee is charged after creation',
                      style: GoogleFonts.inter(fontSize: 11, color: AppConstants.textSecondary)),
                ),
              const SizedBox(height: 20),

              // ── SUBMIT ───────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(
                    _isEdit ? 'Update Company' : 'Create & Continue to Payment',
                    style: GoogleFonts.inter(
                        fontSize: 15.5, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingPaymentBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppConstants.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: AppConstants.accentDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Registration fee is pending for this company.',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppConstants.textPrimary)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _goToPayment(widget.existing!),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Pay now',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
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
          padding: const EdgeInsets.all(16),
          children: [
            // Created confirmation
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
                        Row(children: [
                          const Icon(Icons.check_circle, size: 16, color: AppConstants.success),
                          const SizedBox(width: 5),
                          Text(_isEdit ? 'Company registered' : 'Company created',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppConstants.success)),
                        ]),
                        const SizedBox(height: 4),
                        Text(company.name,
                            style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppConstants.textPrimary)),
                        if (company.ownerName.isNotEmpty)
                          Text(company.ownerName,
                              style: GoogleFonts.inter(
                                  fontSize: 12.5, color: AppConstants.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Fee card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('One-time registration fee',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppConstants.textSecondary)),
                  const SizedBox(height: 6),
                  if (_isCreatingOrder)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: LinearProgressIndicator(minHeight: 3),
                    )
                  else
                    Text(order?.amountLabel ?? '—',
                        style: GoogleFonts.inter(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            color: AppConstants.textPrimary)),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  _benefit(Icons.dashboard_customize_outlined,
                      'Company admin panel access (login link sent to ${company.email.isEmpty ? 'your email' : company.email})'),
                  _benefit(Icons.local_shipping_outlined,
                      'Shipping pickup location set up for your orders'),
                  _benefit(Icons.storefront_outlined, 'List products for B2B buyers'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_paymentError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppConstants.error.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: AppConstants.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_paymentError!,
                          style: GoogleFonts.inter(
                              fontSize: 12.5, color: AppConstants.error, height: 1.45)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Pay button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _busy
                    ? null
                    : (order == null ? _createOrder : _openCheckout),
                icon: Icon(order == null ? Icons.refresh : Icons.lock_outline, size: 18),
                label: Text(
                  order == null
                      ? (_isCreatingOrder ? 'Preparing payment…' : 'Retry')
                      : 'Pay ${order.amountLabel} securely',
                  style: GoogleFonts.inter(
                      fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.accent,
                  disabledBackgroundColor: AppConstants.accent.withValues(alpha: 0.45),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                  kIsWeb
                      ? 'Razorpay checkout works in the Android app only'
                      : 'UPI, cards, net banking and wallets via Razorpay',
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppConstants.textLight)),
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context, true),
                child: Text('Pay later',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.textSecondary)),
              ),
            ),
            Center(
              child: Text('You can pay any time from My Companies.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppConstants.textLight)),
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
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    const SizedBox(width: 16),
                    Text('Confirming payment…',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _benefit(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppConstants.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: GoogleFonts.inter(
                  fontSize: 12.5, color: AppConstants.textPrimary, height: 1.4)),
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
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppConstants.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, size: 48, color: AppConstants.success),
            ),
            const SizedBox(height: 20),
            Text('Payment successful',
                style: GoogleFonts.inter(
                    fontSize: 22, fontWeight: FontWeight.w800, color: AppConstants.textPrimary)),
            const SizedBox(height: 8),
            Text(
              '${company.name} is now registered on QNX Mart B2B'
                  '${_order != null ? ' · ${_order!.amountLabel} paid' : ''}.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppConstants.textSecondary, height: 1.5),
            ),
            if (_paidPaymentId != null && _paidPaymentId!.isNotEmpty) ...[
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _paidPaymentId!));
                  _snack('Payment reference copied');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppConstants.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ref: $_paidPaymentId',
                          style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppConstants.textPrimary)),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy_rounded, size: 15, color: AppConstants.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              company.email.isNotEmpty
                  ? 'Admin panel login details were sent to ${company.email}.'
                  : 'Admin panel login details were sent to your email.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12.5, color: AppConstants.textLight),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Go to My Companies',
                    style: GoogleFonts.inter(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  // SUB-WIDGETS
  // =====================================================================
  BoxDecoration _cardDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.grey.shade200),
  );

  Widget _companyAvatar(Company c) {
    Widget initials() => Container(
      color: AppConstants.primary.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
          style: GoogleFonts.inter(
              fontSize: 22, fontWeight: FontWeight.w800, color: AppConstants.primary)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
        child: _logoBytes != null
            ? Image.memory(_logoBytes!, fit: BoxFit.cover)
            : c.logo.isNotEmpty
            ? Image.network(c.logo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => initials())
            : initials(),
      ),
    );
  }

  // ─── Location picker field ────────────────────────────
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

    final borderColor = error != null || missing
        ? AppConstants.error
        : (selected != null ? AppConstants.primary : Colors.grey.shade300);

    String hint;
    if (!enabled) {
      hint = disabledHint ?? 'Select $label';
    } else if (loading) {
      hint = 'Loading ${label.toLowerCase()}s…';
    } else if (items.isEmpty) {
      hint = 'No ${label.toLowerCase()}s available';
    } else {
      hint = 'Select $label (${items.length})';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label *',
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.textSecondary)),
        const SizedBox(height: 6),
        Material(
          color: enabled ? Colors.white : Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: selected != null ? 1.4 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: canOpen
                ? () async {
              FocusScope.of(context).unfocus();
              final picked = await _showLocationSheet(label, items, selectedId);
              if (picked != null) onSelected(picked);
            }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Icon(icon,
                      size: 20,
                      color: enabled ? AppConstants.primary : Colors.grey.shade400),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selected?.name ?? hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: selected != null ? FontWeight.w600 : FontWeight.w400,
                        color: selected != null
                            ? AppConstants.textPrimary
                            : (enabled ? AppConstants.textLight : Colors.grey.shade400),
                      ),
                    ),
                  ),
                  if (loading)
                    const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: canOpen ? AppConstants.textSecondary : Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 14, color: AppConstants.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(error,
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppConstants.error)),
                ),
                GestureDetector(
                  onTap: onRetry,
                  child: Text('Retry',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.primary,
                          decoration: TextDecoration.underline)),
                ),
              ],
            ),
          )
        else if (missing)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text('$label is required',
                style: GoogleFonts.inter(fontSize: 11.5, color: AppConstants.error)),
          ),
      ],
    );
  }

  /// Searchable bottom sheet (states and villages lists can be long).
  Future<LocationItem?> _showLocationSheet(
      String label,
      List<LocationItem> items,
      int? selectedId,
      ) {
    return showModalBottomSheet<LocationItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final q = query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? items
                : items.where((e) => e.name.toLowerCase().contains(q)).toList();

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Select $label',
                                style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppConstants.textPrimary)),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    if (items.length > 8)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: TextField(
                          autofocus: false,
                          onChanged: (v) => setSheet(() => query = v),
                          style: GoogleFonts.inter(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search ${label.toLowerCase()}',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: AppConstants.surfaceLight,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    const Divider(height: 1),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                        child: Text('No match for "$query"',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: AppConstants.textSecondary)),
                      )
                          : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (_, i) {
                          final item = filtered[i];
                          final isSel = item.id == selectedId;
                          return ListTile(
                            title: Text(item.name,
                                style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight:
                                    isSel ? FontWeight.w700 : FontWeight.w500,
                                    color: isSel
                                        ? AppConstants.primary
                                        : AppConstants.textPrimary)),
                            trailing: isSel
                                ? const Icon(Icons.check_circle,
                                color: AppConstants.primary)
                                : null,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.grey.shade100,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppConstants.primary.withValues(alpha: 0.08),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppConstants.primary, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Location Preview',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppConstants.primary)),
                  ),
                  Text('${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                      style: GoogleFonts.inter(fontSize: 11, color: AppConstants.textSecondary)),
                ],
              ),
            ),
            Image.network(
              staticMapUrl,
              height: 180,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                  height: 180,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2)),
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                alignment: Alignment.center,
                color: Colors.grey.shade200,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.map_outlined, size: 36, color: Colors.grey),
                    const SizedBox(height: 6),
                    Text('Map preview unavailable',
                        style: GoogleFonts.inter(fontSize: 12, color: AppConstants.textSecondary)),
                  ],
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  _launchUrl('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text('Open in Google Maps', style: GoogleFonts.inter(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoPicker() {
    return GestureDetector(
      onTap: _pickLogo,
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppConstants.primary.withValues(alpha: 0.4), width: 1.5),
        ),
        child: _logoBytes != null
            ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_logoBytes!, fit: BoxFit.cover))
            : _existingLogoUrl.isNotEmpty
            ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(_existingLogoUrl,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => _logoIcon()),
        )
            : _logoIcon(),
      ),
    );
  }

  Widget _logoIcon() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_a_photo_outlined, size: 32, color: AppConstants.primary),
          const SizedBox(height: 6),
          Text('Upload Logo',
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600, color: AppConstants.primary)),
          Text('PNG/JPG · max 2MB',
              style: GoogleFonts.inter(fontSize: 9, color: AppConstants.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildImagesPicker() {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < _imageFiles.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(_imageBytes[i], width: 92, height: 92, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeImage(i),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration:
                        const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_imageFiles.length < _maxImages)
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppConstants.primary.withValues(alpha: 0.35)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined, color: AppConstants.primary),
                    const SizedBox(height: 4),
                    Text('${_imageFiles.length}/$_maxImages',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.primary)),
                  ],
                ),
              ),
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
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_circle, color: AppConstants.primary),
              onPressed: onSubmitted,
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppConstants.primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.asMap().entries.map((e) {
              return Chip(
                label: Text(e.value, style: GoogleFonts.inter(fontSize: 11)),
                backgroundColor: AppConstants.primary.withValues(alpha: 0.08),
                deleteIconColor: AppConstants.error,
                onDeleted: () => onRemove(e.key),
                side: BorderSide.none,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppConstants.primary,
      title: Text(label,
          style: GoogleFonts.inter(
              fontSize: 13, fontWeight: FontWeight.w600, color: AppConstants.textPrimary)),
    );
  }

  // ─── Validation helpers ───────────────────────────────
  static final List<TextInputFormatter> _phoneFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  String? _required(String? v, String name) =>
      (v == null || v.trim().isEmpty) ? '$name is required' : null;

  String? _validatePhone(String? v, String name) {
    if (v == null || v.trim().isEmpty) return '$name is required';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v.trim())) return 'Enter valid 10-digit number';
    return null;
  }

  Widget _sectionTitle(String title) => Text(title,
      style: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w700, color: AppConstants.textPrimary));

  Widget _field(
      TextEditingController ctrl,
      String label,
      String hint,
      IconData icon, {
        TextInputType? keyboardType,
        List<TextInputFormatter>? inputFormatters,
        String? Function(String?)? validator,
        int maxLines = 1,
        TextCapitalization textCapitalization = TextCapitalization.none,
      }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppConstants.primary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppConstants.primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}