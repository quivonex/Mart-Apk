// lib/screens/supplier_create_edit_screen.dart
//
// Create:  POST /company/suppliers/create/
// Update:  POST /company/suppliers/update/   (id + changed fields)
// Required by backend: name, email, phone, address, state, district, taluka,
//                      village, company.  latitude/longitude optional.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/design_tokens.dart';
import '../models/company_locations_models.dart';
import '../models/company_model.dart';
import '../models/supplier_model.dart';
import '../services/company_locations_service.dart';
import '../services/supplier_service.dart';
import '../widgets/company_ui.dart';

class SupplierCreateEditScreen extends StatefulWidget {
  final Company company;
  final Supplier? existing;

  const SupplierCreateEditScreen({super.key, required this.company, this.existing});

  @override
  State<SupplierCreateEditScreen> createState() => _SupplierCreateEditScreenState();
}

class _SupplierCreateEditScreenState extends State<SupplierCreateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
  late final _emailCtrl = TextEditingController(text: widget.existing?.email ?? '');
  late final _addressCtrl = TextEditingController(text: widget.existing?.address ?? '');

  bool get _isEdit => widget.existing != null;

  // Location cascade
  List<LocationItem> _states = [], _districts = [], _talukas = [], _villages = [];
  int? _stateId, _districtId, _talukaId, _villageId;
  bool _loadingStates = false, _loadingDistricts = false;
  bool _loadingTalukas = false, _loadingVillages = false;

  // Optional GPS
  String _lat = '', _lng = '';
  bool _locating = false;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _lat = widget.existing?.latitude ?? '';
    _lng = widget.existing?.longitude ?? '';
    _initLocations();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // =================================================================
  // LOCATION LOADING (with prefill for edit by matching names)
  // =================================================================
  int? _matchId(List<LocationItem> list, String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final n = name.trim().toLowerCase();
    for (final e in list) {
      if (e.name.trim().toLowerCase() == n) return e.id;
    }
    return null;
  }

  Future<void> _initLocations() async {
    setState(() => _loadingStates = true);
    final res = await CompanyLocationService.getStates();
    if (!mounted) return;
    setState(() {
      _loadingStates = false;
      _states = res.data;
    });

    final ex = widget.existing;
    if (ex == null) return;

    final sId = _matchId(_states, ex.state);
    if (sId == null) return;
    await _onState(sId);

    final dId = _matchId(_districts, ex.district);
    if (dId == null) return;
    await _onDistrict(dId);

    final tId = _matchId(_talukas, ex.taluka);
    if (tId == null) return;
    await _onTaluka(tId);

    final vId = _matchId(_villages, ex.village);
    if (vId != null && mounted) setState(() => _villageId = vId);
  }

  Future<void> _onState(int? id) async {
    setState(() {
      _stateId = id;
      _districtId = _talukaId = _villageId = null;
      _districts = _talukas = _villages = [];
      _loadingDistricts = id != null;
    });
    if (id == null) return;
    final res = await CompanyLocationService.getDistricts(id);
    if (!mounted) return;
    setState(() {
      _loadingDistricts = false;
      _districts = res.data;
    });
  }

  Future<void> _onDistrict(int? id) async {
    setState(() {
      _districtId = id;
      _talukaId = _villageId = null;
      _talukas = _villages = [];
      _loadingTalukas = id != null;
    });
    if (id == null || _stateId == null) return;
    final res = await CompanyLocationService.getTalukas(_stateId!, id);
    if (!mounted) return;
    setState(() {
      _loadingTalukas = false;
      _talukas = res.data;
    });
  }

  Future<void> _onTaluka(int? id) async {
    setState(() {
      _talukaId = id;
      _villageId = null;
      _villages = [];
      _loadingVillages = id != null;
    });
    if (id == null || _stateId == null || _districtId == null) return;
    final res = await CompanyLocationService.getVillages(_stateId!, _districtId!, id);
    if (!mounted) return;
    setState(() {
      _loadingVillages = false;
      _villages = res.data;
    });
  }

  String _nameOf(List<LocationItem> list, int? id) =>
      list.where((e) => e.id == id).map((e) => e.name).firstOrNull ?? '';

  // =================================================================
  // GPS
  // =================================================================
  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Turn on location services and try again.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'Location permission is needed to capture coordinates.';
      }
      // Same call style as company_create_edit_screen.dart (geolocator ^10)
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        // Backend DecimalField(max_digits=9, decimal_places=6)
        _lat = pos.latitude.toStringAsFixed(6);
        _lng = pos.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      if (mounted) showCompanySnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // =================================================================
  // SUBMIT
  // =================================================================
  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if ([_stateId, _districtId, _talukaId, _villageId].contains(null)) {
      showCompanySnack(context, 'Select state, district, taluka and village.', error: true);
      return;
    }

    final fields = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'state': _nameOf(_states, _stateId),
      'district': _nameOf(_districts, _districtId),
      'taluka': _nameOf(_talukas, _talukaId),
      'village': _nameOf(_villages, _villageId),
      'company': widget.company.id,
      if (_lat.isNotEmpty) 'latitude': _lat,
      if (_lng.isNotEmpty) 'longitude': _lng,
    };

    setState(() => _saving = true);
    final res = _isEdit
        ? await SupplierService.updateSupplier(widget.existing!.id, fields)
        : await SupplierService.createSupplier(fields);
    if (!mounted) return;
    setState(() => _saving = false);

    showCompanySnack(context, res.displayMessage, error: !res.isSuccess);
    if (res.isSuccess) Navigator.pop(context, true);
  }

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.background,
      appBar: CompanyTopBar(
        title: _isEdit ? 'Edit supplier' : 'Add supplier',
        subtitle: widget.company.name,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              SectionCard(
                title: 'Supplier',
                child: Column(children: [
                  _field(_nameCtrl, 'Business or person name',
                      icon: Icons.storefront_outlined,
                      capitalization: TextCapitalization.words,
                      validator: (v) =>
                      (v ?? '').trim().length < 2 ? 'Enter the supplier name' : null),
                  _field(_phoneCtrl, 'Phone number',
                      icon: Icons.phone_outlined,
                      keyboard: TextInputType.phone,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch((v ?? '').trim())
                          ? null
                          : 'Enter a valid 10-digit mobile number'),
                  _field(_emailCtrl, 'Email',
                      icon: Icons.mail_outline_rounded,
                      keyboard: TextInputType.emailAddress,
                      validator: (v) =>
                      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch((v ?? '').trim())
                          ? null
                          : 'Enter a valid email'),
                ]),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Address',
                child: Column(children: [
                  _field(_addressCtrl, 'Street, building, landmark',
                      icon: Icons.home_work_outlined,
                      maxLines: 3,
                      capitalization: TextCapitalization.sentences,
                      validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter the address' : null),
                  _dropdown('State', _states, _stateId, _loadingStates, (v) => _onState(v)),
                  _dropdown('District', _districts, _districtId, _loadingDistricts,
                          (v) => _onDistrict(v),
                      enabled: _stateId != null),
                  _dropdown('Taluka', _talukas, _talukaId, _loadingTalukas,
                          (v) => _onTaluka(v),
                      enabled: _districtId != null),
                  _dropdown('Village', _villages, _villageId, _loadingVillages,
                          (v) => setState(() => _villageId = v),
                      enabled: _talukaId != null),
                ]),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Map location',
                trailing: Text('Optional', style: DT.text(size: 11.5, color: DT.slate400)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _lat.isEmpty
                            ? 'Capture coordinates while you are at the supplier.'
                            : '$_lat, $_lng',
                        style: DT.text(
                          size: 12.5,
                          color: _lat.isEmpty ? DT.slate500 : DT.onyx800,
                          weight: _lat.isEmpty ? FontWeight.w500 : FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _locating ? null : _useCurrentLocation,
                      icon: _locating
                          ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded, size: 16),
                      label: Text(_lat.isEmpty ? 'Use current' : 'Update',
                          style: DT.text(
                              size: 12.5, weight: FontWeight.w700, color: DT.blue800)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DT.blue800,
                        side: const BorderSide(color: DT.blue200),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DT.rMd)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: DT.blue800,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
              ),
              child: _saving
                  ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(_isEdit ? 'Save changes' : 'Add supplier',
                  style: DT.text(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
      TextEditingController ctrl,
      String label, {
        required IconData icon,
        TextInputType? keyboard,
        List<TextInputFormatter>? formatters,
        String? Function(String?)? validator,
        int maxLines = 1,
        TextCapitalization capitalization = TextCapitalization.none,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: maxLines > 1 ? TextInputType.multiline : keyboard,
        inputFormatters: formatters,
        validator: validator,
        maxLines: maxLines,
        textCapitalization: capitalization,
        style: DT.text(size: 13.5),
        decoration: _decoration(label, icon),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    labelStyle: DT.text(size: 13, color: DT.slate500),
    prefixIcon: Icon(icon, size: 19, color: DT.slate400),
    filled: true,
    fillColor: DT.slate50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DT.rMd),
      borderSide: const BorderSide(color: DT.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DT.rMd),
      borderSide: const BorderSide(color: DT.blue800, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DT.rMd),
      borderSide: const BorderSide(color: DT.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(DT.rMd),
      borderSide: const BorderSide(color: DT.error, width: 1.4),
    ),
  );

  Widget _dropdown(
      String label,
      List<LocationItem> items,
      int? value,
      bool loading,
      ValueChanged<int?> onChanged, {
        bool enabled = true,
      }) {
    final safeValue = items.any((e) => e.id == value) ? value : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: enabled ? DT.slate50 : DT.slate100,
              borderRadius: BorderRadius.circular(DT.rMd),
              border: Border.all(color: DT.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: safeValue,
                isExpanded: true,
                hint: Text(
                  loading ? 'Loading $label…' : (enabled ? 'Select $label' : label),
                  style: DT.text(size: 13.5, color: DT.slate400),
                ),
                icon: const Icon(Icons.expand_more_rounded, color: DT.slate400),
                items: items
                    .map((e) => DropdownMenuItem<int>(
                  value: e.id,
                  child: Text(e.name,
                      overflow: TextOverflow.ellipsis, style: DT.text(size: 13.5)),
                ))
                    .toList(),
                onChanged: enabled && !loading ? onChanged : null,
              ),
            ),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: LinearProgressIndicator(minHeight: 2, color: DT.blue800),
            ),
        ],
      ),
    );
  }
}