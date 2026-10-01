// lib/screens/company_create_edit_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../models/company_locations_models.dart';
import '../models/company_model.dart';
import '../models/location_models.dart';
import '../services/company_service.dart';
import '../services/company_locations_service.dart';
import '../utils/shared_preferences_helper.dart';
import 'terms_conditions_screen.dart';

class CompanyCreateEditScreen extends StatefulWidget {
  final Company? existing;

  const CompanyCreateEditScreen({super.key, this.existing});

  @override
  State<CompanyCreateEditScreen> createState() =>
      _CompanyCreateEditScreenState();
}

class _CompanyCreateEditScreenState
    extends State<CompanyCreateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

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

  // ─── Other State ──────────────────────────────────────
  File? _logoFile;
  String _existingLogoUrl = '';

  // ✅ NEW: Map preview coords
  double? _previewLat;
  double? _previewLng;

  final List<String> _extraEmails = [];
  final List<String> _extraContacts = [];

  bool _isActive = true;
  bool _isiCertified = false;
  bool _isoCertified = false;
  bool _codAvailable = false;
  bool _acceptTerms = false;

  bool _isSubmitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _fetchStates();
    if (_isEdit) _prefill(widget.existing!);
  }

  @override
  void dispose() {
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

  // ─── Location Logic ──────────────────────────────────

  Future<void> _fetchStates() async {
    setState(() => _isLoadingStates = true);
    final res = await CompanyLocationService.getStates();   // ✅ CHANGED
    if (mounted) {
      setState(() {
        _isLoadingStates = false;
        if (res.status) _states = res.data;
      });
    }
  }

  Future<void> _fetchDistricts(int stateId) async {
    setState(() {
      _isLoadingDistricts = true;
      _districts = [];
      _talukas = [];
      _villages = [];
      _selectedDistrictId = null;
      _selectedTalukaId = null;
      _selectedVillageId = null;
    });
    final res = await CompanyLocationService.getDistricts(stateId);   // ✅ CHANGED
    if (mounted) {
      setState(() {
        _isLoadingDistricts = false;
        if (res.status) _districts = res.data;
      });
    }
  }

  // ✅ FIX: state_id + district_id both required
  Future<void> _fetchTalukas(int districtId) async {
    if (_selectedStateId == null) return;

    setState(() {
      _isLoadingTalukas = true;
      _talukas = [];
      _villages = [];
      _selectedTalukaId = null;
      _selectedVillageId = null;
    });

    final res = await CompanyLocationService.getTalukas(   // ✅ CHANGED
      _selectedStateId!,
      districtId,
    );

    if (mounted) {
      setState(() {
        _isLoadingTalukas = false;
        if (res.status) _talukas = res.data;
      });
    }
  }

  // ✅ FIX: state_id + district_id + taluka_id all required
  Future<void> _fetchVillages(int talukaId) async {
    if (_selectedStateId == null || _selectedDistrictId == null) return;

    setState(() {
      _isLoadingVillages = true;
      _villages = [];
      _selectedVillageId = null;
    });

    final res = await CompanyLocationService.getVillages(   // ✅ CHANGED
      _selectedStateId!,
      _selectedDistrictId!,
      talukaId,
    );

    if (mounted) {
      setState(() {
        _isLoadingVillages = false;
        if (res.status) _villages = res.data;
      });
    }
  }

  // ─── Live Location Logic ─────────────────────────────

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      // 1. Location services enabled check
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack('Location services are disabled.', isError: true);
        setState(() => _isFetchingLocation = false);
        return;
      }

      // 2. Permission check / request
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _snack('Location permissions are denied', isError: true);
          setState(() => _isFetchingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _snack('Location permissions are permanently denied.', isError: true);
        setState(() => _isFetchingLocation = false);
        return;
      }

      // 3. Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. Fill latitude / longitude
      _latitudeCtrl.text = position.latitude.toStringAsFixed(6);
      _longitudeCtrl.text = position.longitude.toStringAsFixed(6);

      // ✅ 4b. Save coords for map preview
      setState(() {
        _previewLat = position.latitude;
        _previewLng = position.longitude;
      });

      // 5. Reverse geocode using Nominatim (OpenStreetMap)
      final address = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );

      if (address != null && address['display_name'] != null) {
        final displayName = address['display_name'].toString();

        setState(() {
          if (_addressCtrl.text.trim().isEmpty) {
            _addressCtrl.text = displayName;
          }

          if (_pincodeCtrl.text.trim().isEmpty &&
              address['address'] != null &&
              address['address']['postcode'] != null) {
            _pincodeCtrl.text = address['address']['postcode'].toString();
          }

          if (_pickupCtrl.text.trim().isEmpty) {
            _pickupCtrl.text = displayName;
          }
        });

        _snack('Live location fetched successfully!');
      } else {
        _snack('Coordinates saved. Could not fetch address.', isError: false);
      }
    } catch (e) {
      _snack('Error getting location: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  // ─── Reverse Geocode via Nominatim ───────────────────

  Future<Map<String, dynamic>?> _reverseGeocode(
      double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'qnx_mart_app/1.0 (contact@qnxmartb2b.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('Nominatim failed: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Nominatim error: $e');
      return null;
    }
  }

  // ─── Prefill ─────────────────────────────────────────

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

    // ✅ If editing, try to show map preview from existing coords
    if (c.latitude.isNotEmpty && c.longitude.isNotEmpty) {
      _previewLat = double.tryParse(c.latitude);
      _previewLng = double.tryParse(c.longitude);
    }

    _extraEmails.addAll(c.multipleEmailIds);
    _extraContacts.addAll(c.contacts);
    _existingLogoUrl = c.logo;

    _isActive = c.isActive;
    _isiCertified = c.isiCertified;
    _isoCertified = c.isoCertified;
    _codAvailable = c.codAvailable;
  }

  Future<void> _pickLogo() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;
      final file = File(picked.path);
      final size = await file.length();
      if (size > 2 * 1024 * 1024) {
        _snack('Logo must be under 2MB', isError: true);
        return;
      }
      setState(() => _logoFile = file);
    } catch (e) {
      _snack('Failed: $e', isError: true);
    }
  }

  void _addEmail() {
    final v = _extraEmailCtrl.text.trim();
    if (v.isEmpty) return;
    final re = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
    if (!re.hasMatch(v)) {
      _snack('Invalid email', isError: true);
      return;
    }
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
    setState(() {
      _extraContacts.add(v);
      _extraContactCtrl.clear();
    });
  }

  // ─── Open Terms ──────────────────────────────────────

  Future<void> _openTerms() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TermsConditionsScreen()),
    );
    if (result == true) {
      setState(() => _acceptTerms = true);
    }
  }

  // ─── Submit ──────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      _snack('Please accept terms & conditions', isError: true);
      return;
    }

    if (!_isEdit && _logoFile == null) {
      _snack('Company logo is required', isError: true);
      return;
    }

    if (_selectedStateId == null || _selectedDistrictId == null ||
        _selectedTalukaId == null || _selectedVillageId == null) {
      _snack('Please select complete location details', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    final userId = await SharedPreferencesHelper.getUserId();

    String stateName = _states.firstWhere((e) => e.id == _selectedStateId, orElse: () => LocationItem(id: 0, name: '')).name;
    String districtName = _districts.firstWhere((e) => e.id == _selectedDistrictId, orElse: () => LocationItem(id: 0, name: '')).name;
    String talukaName = _talukas.firstWhere((e) => e.id == _selectedTalukaId, orElse: () => LocationItem(id: 0, name: '')).name;
    String villageName = _villages.firstWhere((e) => e.id == _selectedVillageId, orElse: () => LocationItem(id: 0, name: '')).name;

    final fields = <String, String>{
      'name': _nameCtrl.text.trim(),
      'company_slogan': _sloganCtrl.text.trim(),
      'owner_name': _ownerCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone_number': _phoneCtrl.text.trim(),
      'whatsapp_no': _whatsappCtrl.text.trim(),
      'website_url': _websiteCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'state': stateName,
      'district': districtName,
      'taluka': talukaName,
      'village': villageName,
      'pincode': _pincodeCtrl.text.trim(),
      'pickup_location': _pickupCtrl.text.trim(),
      'gst_number': _gstCtrl.text.trim(),
      'company_pan_no': _panCtrl.text.trim(),
      'registration_no': _regNoCtrl.text.trim(),
      'IAN_No': _ianCtrl.text.trim(),
      'farm_registration_year': _farmYearCtrl.text.trim(),
      'facebook_url': _facebookCtrl.text.trim(),
      'linkedin_url': _linkedinCtrl.text.trim(),
      'instagram_url': _instagramCtrl.text.trim(),
      'youtube_url': _youtubeCtrl.text.trim(),
      'privacy_policy_url': _privacyCtrl.text.trim(),
      'terms_conditions_url': _termsCtrl.text.trim(),
      'short_description': _shortDescCtrl.text.trim(),
      'long_description': _longDescCtrl.text.trim(),
      'latitude': _latitudeCtrl.text.trim(),
      'longitude': _longitudeCtrl.text.trim(),
      'referral_code': _referralCtrl.text.trim(),
      'is_active': _isActive.toString(),
      'ISI_certified': _isiCertified.toString(),
      'ISO_certified': _isoCertified.toString(),
      'COD_available': _codAvailable.toString(),
      'accept_terms_conditions': 'true',
    };

    if (_extraEmails.isNotEmpty) {
      fields['multiple_email_ids'] = jsonEncode(_extraEmails);
    }
    if (_extraContacts.isNotEmpty) {
      fields['contacts'] = jsonEncode(_extraContacts);
    }

    final social = <String, String>{};
    if (_facebookCtrl.text.trim().isNotEmpty) social['facebook'] = _facebookCtrl.text.trim();
    if (_linkedinCtrl.text.trim().isNotEmpty) social['linkedin'] = _linkedinCtrl.text.trim();
    if (_instagramCtrl.text.trim().isNotEmpty) social['instagram'] = _instagramCtrl.text.trim();
    if (_youtubeCtrl.text.trim().isNotEmpty) social['youtube'] = _youtubeCtrl.text.trim();
    if (social.isNotEmpty) fields['social_media_accounts'] = jsonEncode(social);

    CompanyActionResponse response;
    if (_isEdit) {
      response = await CompanyService.updateCompany(
        id: widget.existing!.id,
        fields: fields,
        logo: _logoFile,
      );
    } else {
      if (userId != null) fields['user'] = userId.toString();
      response = await CompanyService.createCompany(
        fields: fields,
        logo: _logoFile!,
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    _snack(response.displayMessage, isError: !response.isSuccess);

    if (response.isSuccess) {
      Navigator.pop(context, true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? const Color(0xFFD32F2F) : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.surfaceColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEdit ? 'Edit Company' : 'Create Company',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── LOGO ─────────────────────────────────
              _sectionTitle('Company Logo *'),
              const SizedBox(height: 10),
              _buildLogoPicker(),
              const SizedBox(height: 20),

              // ── BASIC ────────────────────────────────
              _sectionTitle('Basic Information'),
              const SizedBox(height: 12),
              _field(_nameCtrl, 'Company Name *', 'e.g. ABC Pvt Ltd', Icons.business_outlined,
                  validator: (v) => _required(v, 'Company name')),
              const SizedBox(height: 14),
              _field(_sloganCtrl, 'Company Slogan', 'e.g. Quality First', Icons.campaign_outlined),
              const SizedBox(height: 14),
              _field(_ownerCtrl, 'Owner Name *', 'e.g. John Doe', Icons.person_outline,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Owner name required';
                    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) return 'Letters only';
                    return null;
                  }),
              const SizedBox(height: 14),
              _field(_emailCtrl, 'Email *', 'john@example.com', Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email required';
                    final re = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
                    if (!re.hasMatch(v.trim())) return 'Invalid email';
                    return null;
                  }),
              const SizedBox(height: 14),
              Row(
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
                        inputFormatters: _phoneFormatters,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          return _validatePhone(v, 'WhatsApp');
                        }),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _field(_websiteCtrl, 'Website URL', 'https://example.com', Icons.language_outlined,
                  keyboardType: TextInputType.url),
              const SizedBox(height: 20),

              // ── ADDRESS & LOCATION ───────────────────
              _sectionTitle('Address & Location'),
              const SizedBox(height: 12),

              // 1. State & District
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown('State *', _states, _selectedStateId, _isLoadingStates, (val) {
                      setState(() => _selectedStateId = val);
                      if (val != null) _fetchDistricts(val);
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDropdown('District *', _districts, _selectedDistrictId, _isLoadingDistricts, (val) {
                      setState(() => _selectedDistrictId = val);
                      if (val != null) _fetchTalukas(val);
                    }, enabled: _selectedStateId != null),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Taluka & Village
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown('Taluka *', _talukas, _selectedTalukaId, _isLoadingTalukas, (val) {
                      setState(() => _selectedTalukaId = val);
                      if (val != null) _fetchVillages(val);
                    }, enabled: _selectedDistrictId != null),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDropdown('Village *', _villages, _selectedVillageId, _isLoadingVillages, (val) {
                      setState(() => _selectedVillageId = val);
                    }, enabled: _selectedTalukaId != null),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Address Field
              _field(_addressCtrl, 'Address *', 'Street address', Icons.home_outlined,
                  maxLines: 2,
                  validator: (v) => _required(v, 'Address')),
              const SizedBox(height: 14),

              // 4. Live Location Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                  icon: _isFetchingLocation
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.my_location),
                  label: Text(
                    _isFetchingLocation
                        ? 'Fetching location...'
                        : 'Get My Live Location',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppConstants.primary,
                    side: const BorderSide(color: AppConstants.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 5. Latitude & Longitude
              Row(
                children: [
                  Expanded(
                    child: _field(_latitudeCtrl, 'Latitude', 'Auto-filled', Icons.my_location),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(_longitudeCtrl, 'Longitude', 'Auto-filled', Icons.location_searching),
                  ),
                ],
              ),

              // 5b. Map Preview
              _buildLocationMapPreview(),
              const SizedBox(height: 14),

              // 6. Pincode & Pickup Location
              Row(
                children: [
                  Expanded(
                    child: _field(_pincodeCtrl, 'Pincode *', '6-digit', Icons.pin_drop_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Pincode required';
                          if (v.trim().length != 6) return '6-digit pincode';
                          return null;
                        }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(_pickupCtrl, 'Pickup Location *', 'Full pickup address', Icons.local_shipping_outlined,
                        validator: (v) => _required(v, 'Pickup location')),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── REGISTRATION ─────────────────────────
              _sectionTitle('Registration Details'),
              const SizedBox(height: 12),
              _field(_gstCtrl, 'GST Number', 'e.g. 27ABCDE1234F1Z5', Icons.receipt_long_outlined,
                  textCapitalization: TextCapitalization.characters),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _field(_panCtrl, 'PAN Number', 'e.g. ABCDE1234F', Icons.credit_card_outlined,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [LengthLimitingTextInputFormatter(10)])),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_regNoCtrl, 'Registration No.', 'REG123', Icons.assignment_outlined)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _field(_ianCtrl, 'IAN No.', 'IAN123', Icons.verified_outlined)),
                  const SizedBox(width: 10),
                  Expanded(child: _field(_farmYearCtrl, 'Firm Reg. Year', 'e.g. 2020', Icons.calendar_today_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)])),
                ],
              ),
              const SizedBox(height: 20),

              // ── EXTRA CONTACTS ───────────────────────
              _sectionTitle('Extra Emails / Contacts (Optional)'),
              const SizedBox(height: 12),
              _buildChipsEditor(
                label: 'Email IDs',
                hint: 'Enter email & press Enter',
                controller: _extraEmailCtrl,
                items: _extraEmails,
                keyboardType: TextInputType.emailAddress,
                onSubmitted: _addEmail,
                onRemove: (i) => setState(() => _extraEmails.removeAt(i)),
              ),
              const SizedBox(height: 14),
              _buildChipsEditor(
                label: 'Contact Numbers',
                hint: 'Enter 10-digit & press Enter',
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
              _field(_facebookCtrl, 'Facebook', 'https://facebook.com/...', Icons.facebook),
              const SizedBox(height: 14),
              _field(_linkedinCtrl, 'LinkedIn', 'https://linkedin.com/...', Icons.business_center_outlined),
              const SizedBox(height: 14),
              _field(_instagramCtrl, 'Instagram', 'https://instagram.com/...', Icons.camera_alt_outlined),
              const SizedBox(height: 14),
              _field(_youtubeCtrl, 'YouTube', 'https://youtube.com/...', Icons.play_circle_outline),
              const SizedBox(height: 20),

              // ── LEGAL ────────────────────────────────
              _sectionTitle('Legal URLs (Optional)'),
              const SizedBox(height: 12),
              _field(_privacyCtrl, 'Privacy Policy URL', 'https://...', Icons.privacy_tip_outlined),
              const SizedBox(height: 14),
              _field(_termsCtrl, 'Terms & Conditions URL', 'https://...', Icons.description_outlined),
              const SizedBox(height: 20),

              // ── DESCRIPTION ──────────────────────────
              _sectionTitle('Description'),
              const SizedBox(height: 12),
              _field(_shortDescCtrl, 'Short Description', 'Max 160 chars', Icons.short_text_outlined, maxLines: 2,
                  inputFormatters: [LengthLimitingTextInputFormatter(160)]),
              const SizedBox(height: 14),
              _field(_longDescCtrl, 'Long Description', 'Detailed description', Icons.notes_outlined, maxLines: 4),
              const SizedBox(height: 20),

              // ── CERTIFICATIONS ───────────────────────
              _sectionTitle('Certifications & Features'),
              const SizedBox(height: 8),
              _switchTile('Active Company', _isActive, (v) => setState(() => _isActive = v)),
              _switchTile('ISI Certified', _isiCertified, (v) => setState(() => _isiCertified = v)),
              _switchTile('ISO Certified', _isoCertified, (v) => setState(() => _isoCertified = v)),
              _switchTile('COD Available', _codAvailable, (v) => setState(() => _codAvailable = v)),
              const SizedBox(height: 14),

              // ── REFERRAL ─────────────────────────────
              _field(_referralCtrl, 'Referral Code (Optional)', 'Enter code', Icons.card_giftcard_outlined),
              const SizedBox(height: 20),

              // ── TERMS ────────────────────────────────
              CheckboxListTile(
                value: _acceptTerms,
                onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                activeColor: AppConstants.primary,
                contentPadding: EdgeInsets.zero,
                title: GestureDetector(
                  onTap: _openTerms,
                  child: RichText(
                    text: TextSpan(
                      text: 'I accept the ',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.textPrimary,
                      ),
                      children: [
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
                subtitle: Text(
                  'You must agree before submitting',
                  style: GoogleFonts.inter(fontSize: 11, color: AppConstants.textSecondary),
                ),
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
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(
                    _isEdit ? 'Update Company' : 'Create Company',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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

  // ─── Sub-widgets ─────────────────────────────────────

  Widget _buildDropdown(
      String label,
      List<LocationItem> items,
      int? selectedValue,
      bool isLoading,
      ValueChanged<int?> onChanged, {
        bool enabled = true,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.textSecondary),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedValue,
              isExpanded: true,
              hint: Text('Select', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey)),
              items: isLoading
                  ? null
                  : items.map((e) => DropdownMenuItem<int>(
                value: e.id,
                child: Text(e.name, style: GoogleFonts.inter(fontSize: 13), overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: enabled && !isLoading ? onChanged : null,
            ),
          ),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  // ─── Live Location Map Preview ───────────────────────

  Widget _buildLocationMapPreview() {
    if (_previewLat == null || _previewLng == null) {
      return const SizedBox.shrink();
    }

    final lat = _previewLat!;
    final lng = _previewLng!;

    // Static map image from OSM
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
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppConstants.primary.withOpacity(0.08),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppConstants.primary, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Live Location Preview',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.primary,
                      ),
                    ),
                  ),
                  Text(
                    '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppConstants.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Static map image
            Image.network(
              staticMapUrl,
              height: 180,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 180,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                );
              },
              errorBuilder: (_, __, ___) {
                return Container(
                  height: 180,
                  alignment: Alignment.center,
                  color: Colors.grey.shade200,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_outlined, size: 40, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        'Map preview unavailable',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppConstants.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // "Open in Google Maps" button
            TextButton.icon(
              onPressed: () {
                final url =
                    'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                _launchUrl(url);
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(
                'Open in Google Maps',
                style: GoogleFonts.inter(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack('Could not open map', isError: true);
    }
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
          border: Border.all(color: AppConstants.primary.withOpacity(0.4), width: 1.5),
        ),
        child: _logoFile != null
            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_logoFile!, fit: BoxFit.cover))
            : _existingLogoUrl.isNotEmpty
            ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(_existingLogoUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _logoIcon()),
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
          Text('Upload Logo', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppConstants.primary)),
          Text('PNG/JPG · max 2MB', style: GoogleFonts.inter(fontSize: 9, color: AppConstants.textSecondary)),
        ],
      ),
    );
  }

  // ─── Chips Editor ────────────────────────────────────

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
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppConstants.textSecondary)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppConstants.primary, width: 2)),
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
                backgroundColor: AppConstants.primary.withOpacity(0.08),
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
      activeColor: AppConstants.primary,
      title: Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppConstants.textPrimary)),
    );
  }

  // ─── Helpers ─────────────────────────────────────────

  static final List<TextInputFormatter> _phoneFormatters = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  String? _required(String? v, String name) {
    if (v == null || v.trim().isEmpty) return '$name is required';
    return null;
  }

  String? _validatePhone(String? v, String name) {
    if (v == null || v.trim().isEmpty) return '$name is required';
    if (v.trim().length != 10) return 'Enter 10-digit number';
    return null;
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppConstants.textPrimary));
  }

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
      keyboardType: keyboardType,
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppConstants.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 1)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}