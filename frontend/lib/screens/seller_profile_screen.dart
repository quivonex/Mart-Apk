import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/design_tokens.dart';
import '../models/seller_model.dart';
import '../services/seller_service.dart';

// Colours used only on this screen (the rest come from DT).
class _C {
  static const navy1 = Color(0xFF1B223C);
  static const navy2 = Color(0xFF212B4E);
  static const navy3 = Color(0xFF242E54);
  static const navy4 = Color(0xFF161D36);
  static const blue600 = Color(0xFF2563EB);
  static const blue400 = Color(0xFF60A5FA);
  static const indigo600 = Color(0xFF4F46E5);
  static const teal600 = Color(0xFF0D9488);
  static const emerald600 = Color(0xFF059669);
  static const emerald300 = Color(0xFF6EE7B7);
  static const amber300 = Color(0xFFFCD34D);
}

class SellerProfileScreen extends StatefulWidget {
  /// Optional: logged-in user ID (used when creating a new seller).
  final int? userId;

  const SellerProfileScreen({super.key, this.userId});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // ---------- Controllers ----------
  final _businessCategoryCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _designationCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _altMobileCtrl = TextEditingController();
  final _landlineCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();

  late final Listenable _allFields = Listenable.merge([
    _businessCategoryCtrl, _contactNameCtrl, _designationCtrl, _emailCtrl,
    _mobileCtrl, _addressCtrl, _cityCtrl, _stateCtrl, _pincodeCtrl,
    _panCtrl, _accountCtrl, _ifscCtrl, _bankNameCtrl, _branchCtrl,
  ]);

  static final RegExp _panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
  static final RegExp _ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
  static final RegExp _emailRegex =
  RegExp(r'^[\w\-.+]+@([\w-]+\.)+[\w-]{2,}$');

  String? _businessType;
  int? _existingSellerId;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _loadError;

  bool get _isEdit => _existingSellerId != null;

  @override
  void initState() {
    super.initState();
    _loadSellerProfile();
  }

  @override
  void dispose() {
    for (final c in [
      _businessCategoryCtrl, _contactNameCtrl, _designationCtrl, _emailCtrl,
      _mobileCtrl, _altMobileCtrl, _landlineCtrl, _addressCtrl, _cityCtrl,
      _stateCtrl, _pincodeCtrl, _panCtrl, _accountCtrl, _ifscCtrl,
      _bankNameCtrl, _branchCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // =================================================================
  // LOAD EXISTING PROFILE
  // =================================================================
  Future<void> _loadSellerProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final response = await SellerService.getSellerList();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (response.isSuccess && response.hasSeller) {
          final seller = response.firstSeller!;
          _existingSellerId = seller.id;
          _prefillForm(seller);
        } else {
          _existingSellerId = null; // no profile yet → create mode
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _prefillForm(Seller s) {
    // Only select a business type the dropdown actually offers,
    // otherwise DropdownButtonFormField throws an assertion.
    final validTypes =
    SellerRequest.businessTypeOptions.map((e) => e['value']).toSet();
    _businessType = validTypes.contains(s.businessType) ? s.businessType : null;

    _businessCategoryCtrl.text = s.businessCategory;
    _contactNameCtrl.text = s.contactPersonName;
    _designationCtrl.text = s.designation;
    _emailCtrl.text = s.email;
    _mobileCtrl.text = s.mobile;
    _altMobileCtrl.text = s.alternateMobile;
    _landlineCtrl.text = s.landline;
    _addressCtrl.text = s.address;
    _cityCtrl.text = s.city;
    _stateCtrl.text = s.state;
    _pincodeCtrl.text = s.pincode;
    _panCtrl.text = s.panNumber.toUpperCase();
    _accountCtrl.text = s.accountNumber;
    _ifscCtrl.text = s.ifscCode.toUpperCase();
    _bankNameCtrl.text = s.bankName;
    _branchCtrl.text = s.branchName;
  }

  // =================================================================
  // SUBMIT (CREATE or UPDATE)
  // =================================================================
  String? _optional(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _showSnack('Fix the highlighted fields', success: false);
      return;
    }

    setState(() => _isSubmitting = true);

    final request = SellerRequest(
      id: _existingSellerId,
      user: widget.userId,
      businessType: _businessType ?? '',
      businessCategory: _businessCategoryCtrl.text.trim(),
      contactPersonName: _contactNameCtrl.text.trim(),
      designation: _designationCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      alternateMobile: _optional(_altMobileCtrl),
      landline: _optional(_landlineCtrl),
      address: _addressCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      panNumber: _optional(_panCtrl),
      accountNumber: _optional(_accountCtrl),
      ifscCode: _optional(_ifscCtrl),
      bankName: _optional(_bankNameCtrl),
      branchName: _optional(_branchCtrl),
    );

    final isUpdate = _isEdit;

    try {
      final response = isUpdate
          ? await SellerService.updateSeller(request)
          : await SellerService.createSeller(request);
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        if (response.isSuccess && !isUpdate && response.newId != null) {
          _existingSellerId = response.newId; // switch to update mode
        }
      });
      _showSnack(response.displayMessage, success: response.isSuccess);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), success: false);
    }
  }

  void _showSnack(String message, {required bool success}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: DT.text(
                      size: 13, weight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: success ? _C.emerald600 : DT.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DT.rMd),
          ),
        ),
      );
  }

  // =================================================================
  // PROFILE COMPLETION (computed from the real form values)
  // =================================================================
  List<MapEntry<String, bool>> get _completionItems => [
    MapEntry('Select business type', _businessType != null),
    MapEntry('Add business category', _businessCategoryCtrl.text.trim().isNotEmpty),
    MapEntry('Add contact name', _contactNameCtrl.text.trim().isNotEmpty),
    MapEntry('Add designation', _designationCtrl.text.trim().isNotEmpty),
    MapEntry('Add email', _emailCtrl.text.trim().isNotEmpty),
    MapEntry('Add mobile number', _mobileCtrl.text.trim().length == 10),
    MapEntry('Add address', _addressCtrl.text.trim().isNotEmpty),
    MapEntry('Add city', _cityCtrl.text.trim().isNotEmpty),
    MapEntry('Add state', _stateCtrl.text.trim().isNotEmpty),
    MapEntry('Add pincode', _pincodeCtrl.text.trim().length == 6),
    MapEntry('Add PAN', _panRegex.hasMatch(_panCtrl.text.trim())),
    MapEntry('Add bank account', _accountCtrl.text.trim().isNotEmpty),
    MapEntry('Add IFSC code', _ifscRegex.hasMatch(_ifscCtrl.text.trim())),
    MapEntry('Add bank name', _bankNameCtrl.text.trim().isNotEmpty),
    MapEntry('Add branch name', _branchCtrl.text.trim().isNotEmpty),
  ];

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: DT.background,
        appBar: _buildAppBar(),
        body: _isLoading
            ? _buildLoading()
            : _loadError != null
            ? _buildLoadError()
            : _buildForm(),
      ),
    );
  }

  // ---------- App bar ----------
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_C.navy1, _C.navy2, Color(0xFF1C2440)],
          ),
          boxShadow: [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 68,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: DT.slate200),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _isEdit ? 'Seller Profile' : 'Register as Seller',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DT.text(
                                  size: 17,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            if (_isEdit) ...[
                              const SizedBox(width: 8),
                              _darkPill('Registered', _C.emerald300,
                                  const Color(0x3310B981),
                                  const Color(0x4D34D399)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _isEdit
                              ? 'Seller ID: #$_existingSellerId'
                              : 'Set up your store to start selling',
                          style: DT.text(
                              size: 11.5,
                              weight: FontWeight.w500,
                              color: DT.slate300),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DT.rMd),
                    ),
                    onSelected: (v) {
                      if (v == 'reload') _loadSellerProfile();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'reload',
                        child: Row(
                          children: [
                            const Icon(Icons.refresh_rounded,
                                size: 18, color: DT.onyx700),
                            const SizedBox(width: 10),
                            Text('Reload saved details',
                                style: DT.text(size: 13)),
                          ],
                        ),
                      ),
                    ],
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(DT.rMd),
                      ),
                      child: const Icon(Icons.more_vert_rounded,
                          color: DT.slate200, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _darkPill(String text, Color fg, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Text(text,
          style: DT.text(size: 10, weight: FontWeight.w600, color: fg)),
    );
  }

  // ---------- Loading / error ----------
  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: _C.navy3),
          ),
          const SizedBox(height: 14),
          Text('Loading your seller details…',
              style: DT.text(size: 13, color: DT.onyx600)),
        ],
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                  color: DT.errorBg, shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_rounded,
                  color: DT.error, size: 28),
            ),
            const SizedBox(height: 14),
            Text("Couldn't load your seller details",
                textAlign: TextAlign.center,
                style: DT.text(size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(_loadError ?? '',
                textAlign: TextAlign.center,
                style: DT.text(size: 12.5, color: DT.onyx600, height: 1.5)),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadSellerProfile,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Try again',
                  style: DT.text(
                      size: 13, weight: FontWeight.w700, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.navy3,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DT.rMd)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Form ----------
  Widget _buildForm() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _buildHeroCard(),
            const SizedBox(height: 18),
            _buildBusinessSection(),
            const SizedBox(height: 18),
            _buildContactSection(),
            const SizedBox(height: 18),
            _buildAddressSection(),
            const SizedBox(height: 18),
            _buildBankSection(),
            const SizedBox(height: 22),
            _buildSubmitButton(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user_rounded,
                    size: 14, color: DT.slate400),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Your details are used only to verify and pay your store',
                    textAlign: TextAlign.center,
                    style: DT.text(
                        size: 11, weight: FontWeight.w500, color: DT.slate500),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Hero / completion card ----------
  Widget _buildHeroCard() {
    return ListenableBuilder(
      listenable: _allFields,
      builder: (context, _) {
        final items = _completionItems;
        final done = items.where((e) => e.value).length;
        final pct = done / items.length;
        final missing = items.where((e) => !e.value).toList();
        final complete = missing.isEmpty;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_C.navy3, Color(0xFF1D2645), _C.navy4],
            ),
            borderRadius: BorderRadius.circular(DT.rLg),
            border: Border.all(color: const Color(0x66334155)),
            boxShadow: DT.shadowM3,
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                bottom: -40,
                child: _glow(144, const Color(0x333B82F6)),
              ),
              Positioned(
                left: -24,
                top: -24,
                child: _glow(96, const Color(0x336366F1)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.bottomLeft,
                              end: Alignment.topRight,
                              colors: [_C.blue600, _C.blue400],
                            ),
                            borderRadius: BorderRadius.circular(DT.rMd),
                            border: Border.all(
                                color: const Color(0x1AFFFFFF), width: 2),
                          ),
                          child: Icon(
                            _isEdit
                                ? Icons.store_rounded
                                : Icons.storefront_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isEdit ? 'Seller Profile' : 'Become a Seller',
                                style: DT.text(
                                    size: 15.5,
                                    weight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isEdit
                                    ? 'Update and manage your store details'
                                    : 'Register to start selling on QN Mart',
                                style: DT.text(
                                    size: 12,
                                    color: DT.slate300,
                                    height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _darkPill(
                          '${(pct * 100).round()}% done',
                          complete ? _C.emerald300 : _C.amber300,
                          complete
                              ? const Color(0x3310B981)
                              : const Color(0x33FBBF24),
                          complete
                              ? const Color(0x4D34D399)
                              : const Color(0x4DFBBF24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.only(top: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                            top: BorderSide(color: Color(0x80334155))),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text('Profile completion',
                                  style: DT.text(
                                      size: 11, color: DT.slate300)),
                              const Spacer(),
                              Flexible(
                                child: Text(
                                  complete
                                      ? 'All details added'
                                      : 'Next: ${missing.first.key}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: DT.text(
                                      size: 11,
                                      weight: FontWeight.w600,
                                      color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 8,
                            padding: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xCC1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0x80334155)),
                            ),
                            child: LayoutBuilder(
                              builder: (context, c) => Align(
                                alignment: Alignment.centerLeft,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOut,
                                  width: c.maxWidth * pct,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: complete
                                          ? const [
                                        Color(0xFF34D399),
                                        _C.emerald600
                                      ]
                                          : const [_C.blue400, _C.blue600],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _glow(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withAlpha(0)]),
        ),
      ),
    );
  }

  // ---------- Business ----------
  Widget _buildBusinessSection() {
    return _SectionCard(
      icon: Icons.work_outline_rounded,
      iconBg: DT.blue50,
      iconFg: _C.blue600,
      title: 'Business Information',
      tag: _Tag.required,
      children: [
        DropdownButtonFormField<String>(
          value: _businessType,
          isExpanded: true,
          borderRadius: BorderRadius.circular(DT.rMd),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: DT.slate400),
          style: _inputStyle(),
          decoration: _decoration(
            label: 'Business Type',
            icon: Icons.inventory_2_outlined,
            hint: 'Select business type',
          ),
          items: SellerRequest.businessTypeOptions
              .map((e) => DropdownMenuItem<String>(
            value: e['value'],
            child: Text(e['label'] ?? e['value'] ?? '',
                overflow: TextOverflow.ellipsis),
          ))
              .toList(),
          onChanged: (v) => setState(() => _businessType = v),
          validator: (v) =>
          v == null || v.isEmpty ? 'Business type is required' : null,
        ),
        _field(
          controller: _businessCategoryCtrl,
          label: 'Business Category',
          hint: 'e.g. Electronics & Components',
          icon: Icons.grid_view_rounded,
          textCapitalization: TextCapitalization.words,
          validator: (v) => _required(v, 'Business category'),
        ),
      ],
    );
  }

  // ---------- Contact ----------
  Widget _buildContactSection() {
    return _SectionCard(
      icon: Icons.person_outline_rounded,
      iconBg: DT.indigo50,
      iconFg: _C.indigo600,
      title: 'Contact Person Details',
      tag: _Tag.required,
      children: [
        _field(
          controller: _contactNameCtrl,
          label: 'Contact Person Name',
          hint: 'e.g. Rajesh Kumar',
          icon: Icons.account_circle_outlined,
          textCapitalization: TextCapitalization.words,
          emphasize: true,
          validator: (v) => _required(v, 'Contact person name'),
        ),
        _field(
          controller: _designationCtrl,
          label: 'Designation',
          hint: 'Owner / Managing Director',
          icon: Icons.badge_outlined,
          textCapitalization: TextCapitalization.words,
          validator: (v) => _required(v, 'Designation'),
        ),
        _field(
          controller: _emailCtrl,
          label: 'Official Email',
          hint: 'name@company.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Email is required';
            return _emailRegex.hasMatch(v.trim())
                ? null
                : 'Enter a valid email';
          },
        ),
        _field(
          controller: _mobileCtrl,
          label: 'Primary Mobile',
          hint: '10-digit mobile number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          emphasize: true,
          letterSpacing: 0.8,
          prefixText: '+91  ',
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return 'Mobile is required';
            if (t.length != 10) return 'Enter a valid 10-digit number';
            return null;
          },
        ),
        _field(
          controller: _altMobileCtrl,
          label: 'Alternate Mobile (Optional)',
          hint: 'Add 10-digit number',
          icon: Icons.smartphone_outlined,
          keyboardType: TextInputType.phone,
          compact: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return null;
            return t.length != 10 ? 'Enter a valid 10-digit number' : null;
          },
        ),
        _field(
          controller: _landlineCtrl,
          label: 'Landline (Optional)',
          hint: 'STD code + number',
          icon: Icons.call_outlined,
          keyboardType: TextInputType.phone,
          compact: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
      ],
    );
  }

  // ---------- Address ----------
  Widget _buildAddressSection() {
    return _SectionCard(
      icon: Icons.location_on_outlined,
      iconBg: DT.teal50,
      iconFg: _C.teal600,
      title: 'Registered Business Address',
      tag: _Tag.required,
      children: [
        _field(
          controller: _addressCtrl,
          label: 'Address (Premise / Street)',
          hint: 'e.g. Plot 42, MIDC Industrial Area',
          icon: Icons.home_outlined,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
          validator: (v) => _required(v, 'Address'),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                controller: _cityCtrl,
                label: 'City',
                hint: 'e.g. Satara',
                icon: Icons.location_city_outlined,
                compact: true,
                textCapitalization: TextCapitalization.words,
                validator: (v) => _required(v, 'City'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                controller: _stateCtrl,
                label: 'State',
                hint: 'e.g. Maharashtra',
                icon: Icons.map_outlined,
                compact: true,
                textCapitalization: TextCapitalization.words,
                validator: (v) => _required(v, 'State'),
              ),
            ),
          ],
        ),
        _field(
          controller: _pincodeCtrl,
          label: 'Postal Pincode',
          hint: '6-digit pincode',
          icon: Icons.pin_drop_outlined,
          keyboardType: TextInputType.number,
          emphasize: true,
          letterSpacing: 2,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return 'Pincode is required';
            return t.length != 6 ? 'Enter a valid 6-digit pincode' : null;
          },
        ),
      ],
    );
  }

  // ---------- Bank & PAN ----------
  Widget _buildBankSection() {
    return _SectionCard(
      icon: Icons.credit_card_rounded,
      iconBg: DT.emerald50,
      iconFg: _C.emerald600,
      title: 'Bank & PAN (Payouts)',
      subtitle: 'Where your order payments are settled',
      tag: _Tag.optional,
      children: [
        _field(
          controller: _panCtrl,
          label: 'Permanent Account Number (PAN)',
          hint: 'e.g. ABCDE1234F',
          icon: Icons.badge_outlined,
          emphasize: true,
          letterSpacing: 1.2,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            _UpperCaseFormatter(),
            LengthLimitingTextInputFormatter(10),
          ],
          suffix: _FormatCheck(controller: _panCtrl, regex: _panRegex),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return null;
            return _panRegex.hasMatch(t)
                ? null
                : 'PAN format: 5 letters, 4 digits, 1 letter';
          },
        ),
        _field(
          controller: _accountCtrl,
          label: 'Bank Account Number',
          hint: 'Account number',
          icon: Icons.account_balance_wallet_outlined,
          keyboardType: TextInputType.number,
          emphasize: true,
          letterSpacing: 1.2,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(18),
          ],
        ),
        _field(
          controller: _ifscCtrl,
          label: 'IFSC Code',
          hint: 'e.g. SBIN0001234',
          icon: Icons.segment_rounded,
          emphasize: true,
          letterSpacing: 1.2,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            _UpperCaseFormatter(),
            LengthLimitingTextInputFormatter(11),
          ],
          suffix: _FormatCheck(controller: _ifscCtrl, regex: _ifscRegex),
          validator: (v) {
            final t = v?.trim() ?? '';
            if (t.isEmpty) return null;
            return _ifscRegex.hasMatch(t)
                ? null
                : 'IFSC format: 4 letters, 0, then 6 characters';
          },
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                controller: _bankNameCtrl,
                label: 'Bank Name',
                hint: 'e.g. State Bank of India',
                icon: Icons.account_balance_outlined,
                compact: true,
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                controller: _branchCtrl,
                label: 'Branch',
                hint: 'e.g. Andheri',
                icon: Icons.location_on_outlined,
                compact: true,
                textCapitalization: TextCapitalization.words,
              ),
            ),
          ],
        ),
        _BankSummary(bankName: _bankNameCtrl, branch: _branchCtrl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.lock_outline_rounded,
                  size: 15, color: _C.emerald600),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Add these to receive payouts. You can leave them blank and add them later.',
                style: DT.text(size: 11, color: DT.slate500, height: 1.5),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- Submit ----------
  Widget _buildSubmitButton() {
    final label = _isEdit ? 'Update Seller Profile' : 'Register as Seller';
    return Opacity(
      opacity: _isSubmitting ? 0.8 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A2340), _C.navy3, Color(0xFF1C2440)],
          ),
          borderRadius: BorderRadius.circular(DT.rLg),
          boxShadow: const [
            BoxShadow(
                color: Color(0x330F172A), blurRadius: 14, offset: Offset(0, 6)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(DT.rLg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _isSubmitting ? null : _submit,
            splashColor: Colors.white12,
            child: SizedBox(
              height: 54,
              child: Center(
                child: _isSubmitting
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
                    : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_rounded,
                        color: _C.blue400, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: DT.text(
                        size: 14.5,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =================================================================
  // FIELD HELPERS
  // =================================================================
  String? _required(String? value, String fieldName) {
    return (value == null || value.trim().isEmpty)
        ? '$fieldName is required'
        : null;
  }

  TextStyle _inputStyle({
    bool emphasize = false,
    bool compact = false,
    double? letterSpacing,
  }) {
    return DT.text(
      size: compact ? 13 : 14,
      weight: emphasize ? FontWeight.w700 : FontWeight.w500,
      color: DT.onyx900,
      letterSpacing: letterSpacing,
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
    bool compact = false,
    Widget? suffix,
    String? prefixText,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(DT.rMd),
      borderSide: BorderSide(color: c, width: w),
    );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: DT.text(size: 13, weight: FontWeight.w600, color: DT.onyx600),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
        final color = states.contains(WidgetState.error)
            ? DT.error
            : states.contains(WidgetState.focused)
            ? _C.blue600
            : DT.onyx600;
        return DT.text(size: 13, weight: FontWeight.w600, color: color);
      }),
      hintStyle: DT.text(
          size: compact ? 12.5 : 13.5,
          weight: FontWeight.w400,
          color: DT.slate400),
      prefixIcon: Icon(icon, size: compact ? 18 : 20, color: DT.slate500),
      prefixIconConstraints:
      BoxConstraints(minWidth: compact ? 40 : 46, minHeight: 44),
      prefixText: prefixText,
      prefixStyle:
      DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx600),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
          horizontal: 12, vertical: compact ? 14 : 16),
      errorStyle: DT.text(size: 11, weight: FontWeight.w500, color: DT.error),
      errorMaxLines: 2,
      enabledBorder: border(DT.slate300),
      focusedBorder: border(_C.blue600, 1.8),
      errorBorder: border(DT.error),
      focusedErrorBorder: border(DT.error, 1.8),
      border: border(DT.slate300),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool emphasize = false,
    bool compact = false,
    double? letterSpacing,
    Widget? suffix,
    String? prefixText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      minLines: 1,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      textInputAction:
      maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
      style: _inputStyle(
          emphasize: emphasize, compact: compact, letterSpacing: letterSpacing),
      decoration: _decoration(
        label: label,
        icon: icon,
        hint: hint,
        compact: compact,
        suffix: suffix,
        prefixText: prefixText,
      ),
    );
  }
}

// =====================================================================
// PRIVATE WIDGETS
// =====================================================================
enum _Tag { required, optional }

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String? subtitle;
  final _Tag tag;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.tag,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isRequired = tag == _Tag.required;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.border),
        boxShadow: DT.shadowXs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DT.slate100)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(DT.rSm),
                  ),
                  child: Icon(icon, color: iconFg, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: DT.text(
                              size: 14,
                              weight: FontWeight.w700,
                              height: 1.2,
                              letterSpacing: -0.1)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: DT.text(size: 11, color: DT.slate500)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRequired ? DT.blue50 : DT.slate100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isRequired ? 'Required' : 'Optional',
                    style: DT.text(
                      size: 10,
                      weight: FontWeight.w600,
                      color: isRequired ? _C.blue600 : DT.onyx600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final child in children) ...[
            const SizedBox(height: 18),
            child,
          ],
        ],
      ),
    );
  }
}

/// Green check shown inside PAN / IFSC fields once the format is valid.
class _FormatCheck extends StatelessWidget {
  final TextEditingController controller;
  final RegExp regex;

  const _FormatCheck({required this.controller, required this.regex});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final valid = regex.hasMatch(value.text.trim());
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: valid
              ? const Tooltip(
            key: ValueKey('ok'),
            message: 'Format looks correct',
            child: Icon(Icons.verified_rounded,
                color: _C.emerald600, size: 20),
          )
              : const SizedBox(key: ValueKey('no'), width: 0),
        );
      },
    );
  }
}

/// Small preview card of the bank, shown once a bank name is entered.
class _BankSummary extends StatelessWidget {
  final TextEditingController bankName;
  final TextEditingController branch;

  const _BankSummary({required this.bankName, required this.branch});

  String _initials(String name) {
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && w.toLowerCase() != 'of')
        .toList();
    if (words.isEmpty) return '';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length.clamp(0, 3)).toUpperCase();
    }
    return words.take(3).map((w) => w[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([bankName, branch]),
      builder: (context, _) {
        final name = bankName.text.trim();
        final br = branch.text.trim();
        if (name.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DT.slate50,
            borderRadius: BorderRadius.circular(DT.rMd),
            border: Border.all(color: DT.border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DT.blue100,
                  borderRadius: BorderRadius.circular(DT.rSm),
                ),
                child: Text(
                  _initials(name),
                  style: DT.text(
                      size: 11, weight: FontWeight.w800, color: DT.blue800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(
                            size: 12.5,
                            weight: FontWeight.w700,
                            color: DT.onyx800)),
                    const SizedBox(height: 1),
                    Text(
                      br.isEmpty ? 'Add branch name' : 'Branch: $br',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 11, color: DT.slate500),
                    ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: br.isEmpty ? DT.amber500 : const Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Forces typed text to upper case (PAN / IFSC).
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
