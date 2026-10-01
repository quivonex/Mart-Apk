import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/design_tokens.dart';
import '../models/marketing_partner_enquiry_model.dart';
import '../services/partner_service.dart';

// Extra colours used only on this screen (the rest come from DT).
class _C {
  static const blue600 = Color(0xFF2563EB);
  static const blue500 = Color(0xFF3B82F6);
  static const blue300 = Color(0xFF93C5FD);
  static const rose500 = Color(0xFFF43F5E);
  static const emerald600 = Color(0xFF059669);
  static const emerald800 = Color(0xFF065F46);
  static const indigo600 = Color(0xFF4F46E5);
  static const purple600 = Color(0xFF9333EA);
  static const sky600 = Color(0xFF0284C7);
  static const pink500 = Color(0xFFEC4899);
  static const red600 = Color(0xFFDC2626);
  static const emerald500 = Color(0xFF10B981);
}

class MarketingPartnerEnquiryScreen extends StatefulWidget {
  const MarketingPartnerEnquiryScreen({super.key});

  @override
  State<MarketingPartnerEnquiryScreen> createState() =>
      _MarketingPartnerEnquiryScreenState();
}

class _MarketingPartnerEnquiryScreenState
    extends State<MarketingPartnerEnquiryScreen> {
  final _formKey = GlobalKey<FormState>();

  // ---------- Controllers ----------
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _districtController = TextEditingController();
  final _talukaController = TextEditingController();
  final _villageController = TextEditingController();
  final _workingAreaController = TextEditingController();
  final _referredByCodeController = TextEditingController();

  // ---------- Dropdown values (sent to API as plain text) ----------
  String? _selectedState;
  String? _selectedProfession;
  String? _selectedExperience;

  static const List<String> _states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya',
    'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim',
    'Tamil Nadu', 'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand',
    'West Bengal', 'Andaman and Nicobar Islands', 'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Jammu and Kashmir',
    'Ladakh', 'Lakshadweep', 'Puducherry',
  ];

  static const List<String> _professions = [
    'Industrial Goods / Hardware Supplier',
    'Independent Sales Agent / Broker',
    'Technical Consultant / Engineer',
    'Wholesale Trader / Stockist',
    'Other Commercial Business',
  ];

  static const List<String> _experiences = [
    'Less than 1 year',
    '1 - 3 years',
    '3 - 5 years',
    '5+ years',
  ];

  // ---------- Promotion platforms (values match the API) ----------
  static const List<_Platform> _allPlatforms = [
    _Platform('instagram', 'Instagram', _C.pink500),
    _Platform('facebook', 'Facebook', _C.blue600),
    _Platform('whatsapp', 'WhatsApp', _C.emerald500),
    _Platform('youtube', 'YouTube', _C.red600),
    _Platform('twitter', 'X (Twitter)', DT.onyx800),
  ];
  final Set<String> _selectedPlatforms = {};

  // ---------- Profile image ----------
  XFile? _profileImageFile;
  Uint8List? _profileImageBytes;

  bool _isLoading = false;
  bool _referralApplied = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _pincodeController.dispose();
    _districtController.dispose();
    _talukaController.dispose();
    _villageController.dispose();
    _workingAreaController.dispose();
    _referredByCodeController.dispose();
    super.dispose();
  }

  // =================================================================
  // ACTIONS
  // =================================================================
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _profileImageFile = picked;
        _profileImageBytes = bytes;
      });
    } catch (e) {
      _showSnack('Could not open ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e',
          isError: true);
    }
  }

  void _removeImage() {
    setState(() {
      _profileImageFile = null;
      _profileImageBytes = null;
    });
  }

  void _applyReferral() {
    FocusScope.of(context).unfocus();
    if (_referredByCodeController.text.trim().isEmpty) {
      _showSnack('Enter a referral code first', isError: true);
      return;
    }
    setState(() => _referralApplied = true);
  }

  String? _clean(String value) {
    final v = value.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _showSnack('Fill in the highlighted fields', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final request = MarketingPartnerEnquiryRequest(
      applicationType: 'marketing_partner',
      fullName: _fullNameController.text.trim(),
      email: _clean(_emailController.text),
      mobile: _mobileController.text.trim(),
      state: _selectedState,
      district: _clean(_districtController.text),
      taluka: _clean(_talukaController.text),
      village: _clean(_villageController.text),
      pincode: _pincodeController.text.trim(),
      workingArea: _clean(_workingAreaController.text),
      profession: _selectedProfession,
      experience: _selectedExperience,
      promotionPlatforms:
      _selectedPlatforms.isNotEmpty ? _selectedPlatforms.toList() : null,
      profileImage: _profileImageFile,
      referredByCode: _clean(_referredByCodeController.text),
    );

    try {
      final response = await PartnerService.createEnquiry(data: request);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.status) {
        _resetForm();
        await _showSuccessSheet(response.message.isNotEmpty
            ? response.message
            : 'Application submitted');
      } else {
        _showSnack(response.allErrorMessages, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    setState(() {
      _profileImageFile = null;
      _profileImageBytes = null;
      _selectedPlatforms.clear();
      _selectedState = null;
      _selectedProfession = null;
      _selectedExperience = null;
      _referralApplied = false;
      for (final c in [
        _fullNameController,
        _emailController,
        _mobileController,
        _pincodeController,
        _districtController,
        _talukaController,
        _villageController,
        _workingAreaController,
        _referredByCodeController,
      ]) {
        c.clear();
      }
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white),
          ),
          backgroundColor: isError ? DT.error : DT.onyx900,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: isError ? 4 : 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DT.rMd),
          ),
        ),
      );
  }

  Future<void> _showSuccessSheet(String message) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: DT.emerald50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: _C.emerald600, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: DT.text(size: 16, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Our partner team will verify your details and contact you on your mobile number.',
                textAlign: TextAlign.center,
                style: DT.text(
                    size: 12.5, color: DT.onyx600, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // close sheet
                    Navigator.maybePop(this.context); // back to home
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DT.onyx900,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DT.rMd),
                    ),
                  ),
                  child: Text('Done',
                      style: DT.text(
                          size: 14,
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

  void _showHelp() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How partner onboarding works',
                  style: DT.text(size: 16, weight: FontWeight.w700)),
              const SizedBox(height: 14),
              _helpRow(Icons.edit_note_rounded, 'Details',
                  'Fill in this form. Only name, mobile and pincode are required.'),
              _helpRow(Icons.verified_user_outlined, 'Verification',
                  'Our team checks your details and may call you.'),
              _helpRow(Icons.task_alt_rounded, 'Approval',
                  'Once approved, your partner account is activated.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpRow(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: DT.blue50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _C.blue600, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DT.text(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body,
                    style: DT.text(size: 12, color: DT.onyx600, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.background,
      appBar: _buildAppBar(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _buildHeroBanner(),
              const SizedBox(height: 16),
              _buildStepper(),
              const SizedBox(height: 16),
              _buildPersonalSection(),
              const SizedBox(height: 16),
              _buildAddressSection(),
              const SizedBox(height: 16),
              _buildWorkSection(),
              const SizedBox(height: 16),
              _buildPlatformsSection(),
              const SizedBox(height: 16),
              _buildProfileImageSection(),
              const SizedBox(height: 16),
              _buildReferralSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ---------- App bar ----------
  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: DT.borderSoft)),
          boxShadow: DT.shadowXs,
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: DT.onyx700),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Marketing Partner Enquiry',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(
                            size: 16,
                            weight: FontWeight.w700,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          'QN Mart partner network',
                          style: DT.text(
                              size: 11,
                              weight: FontWeight.w500,
                              color: DT.slate500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'How it works',
                    onPressed: _showHelp,
                    icon: const Icon(Icons.help_outline_rounded,
                        color: DT.slate500, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Hero ----------
  Widget _buildHeroBanner() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DT.onyx900, Color(0xFF172554)],
        ),
        borderRadius: BorderRadius.circular(DT.rLg),
        boxShadow: DT.shadowM3,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -16,
            child: IgnorePointer(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _C.blue500.withAlpha(70),
                    _C.blue500.withAlpha(0),
                  ]),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _C.blue500.withAlpha(50),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _C.blue300.withAlpha(80)),
                      ),
                      child: Text(
                        'Partner program',
                        style: DT.text(
                            size: 10,
                            weight: FontWeight.w700,
                            color: _C.blue300),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'B2B channel expansion',
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(
                            size: 11.5,
                            weight: FontWeight.w500,
                            color: DT.slate300),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Earn commissions & grow with QN Mart',
                  style: DT.text(
                    size: 18,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Refer buyers and suppliers for industrial machinery, MRO and components, and earn on every deal.',
                  style: DT.text(
                    size: 12,
                    color: DT.slate300,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Stepper ----------
  Widget _buildStepper() {
    Widget step(int n, String label, bool active) {
      return Opacity(
        opacity: active ? 1 : 0.6,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? _C.blue600 : DT.slate100,
                shape: BoxShape.circle,
                border: active
                    ? Border.all(color: DT.blue100, width: 2)
                    : null,
              ),
              child: Text(
                '$n',
                style: DT.text(
                  size: 11,
                  weight: FontWeight.w700,
                  color: active ? Colors.white : DT.onyx600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: DT.text(
                size: 11.5,
                weight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? DT.onyx900 : DT.onyx600,
              ),
            ),
          ],
        ),
      );
    }

    Widget line(Color c) => Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.border),
        boxShadow: DT.shadowXs,
      ),
      child: Row(
        children: [
          step(1, 'Details', true),
          line(DT.blue200),
          step(2, 'Verification', false),
          line(DT.slate200),
          step(3, 'Approval', false),
        ],
      ),
    );
  }

  // ---------- Section 1: Personal ----------
  Widget _buildPersonalSection() {
    return _SectionCard(
      icon: Icons.person_outline_rounded,
      iconBg: DT.blue50,
      iconFg: _C.blue600,
      title: 'Personal Information',
      subtitle: 'Contact details for your partner agreement',
      children: [
        _field(
          label: 'Full Name',
          required: true,
          child: TextFormField(
            controller: _fullNameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            style: _inputStyle,
            decoration: _inputDecoration(hint: 'e.g. Rajesh Kumar'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Full name is required'
                : null,
          ),
        ),
        _field(
          label: 'Email Address',
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: _inputStyle,
            decoration: _inputDecoration(hint: 'name@company.com'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final regex = RegExp(r'^[\w\-.+]+@([\w-]+\.)+[\w-]{2,}$');
              return regex.hasMatch(value.trim())
                  ? null
                  : 'Enter a valid email';
            },
          ),
        ),
        _field(
          label: 'Mobile Number',
          required: true,
          helper: 'Used for verification calls and payout alerts',
          child: TextFormField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: _inputStyle.copyWith(letterSpacing: 0.6),
            decoration: _inputDecoration(
              hint: '98765 43210',
              prefix: Container(
                height: 48,
                alignment: Alignment.center,
                margin: const EdgeInsets.only(left: 1, right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  color: DT.slate100,
                  border: Border(right: BorderSide(color: DT.slate300)),
                  borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(DT.rMd)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('IN',
                        style: DT.text(
                            size: 12,
                            weight: FontWeight.w700,
                            color: DT.onyx700)),
                    const SizedBox(width: 4),
                    Text('+91',
                        style: DT.text(
                            size: 12,
                            weight: FontWeight.w600,
                            color: DT.onyx600)),
                  ],
                ),
              ),
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Mobile number is required';
              if (v.length != 10) return 'Enter a 10-digit mobile number';
              return null;
            },
          ),
        ),
      ],
    );
  }

  // ---------- Section 2: Address ----------
  Widget _buildAddressSection() {
    return _SectionCard(
      icon: Icons.location_on_outlined,
      iconBg: DT.emerald50,
      iconFg: _C.emerald600,
      title: 'Address Details',
      subtitle: 'Where you live and the market you cover',
      children: [
        _field(
          label: 'State',
          child: _dropdown(
            value: _selectedState,
            hint: 'Select your state',
            items: _states,
            onChanged: (v) => setState(() => _selectedState = v),
          ),
        ),
        _twoColumns(
          _field(
            label: 'District',
            child: TextFormField(
              controller: _districtController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: _inputStyle,
              decoration: _inputDecoration(hint: 'e.g. Pune'),
            ),
          ),
          _field(
            label: 'Taluka',
            child: TextFormField(
              controller: _talukaController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: _inputStyle,
              decoration: _inputDecoration(hint: 'e.g. Haveli'),
            ),
          ),
        ),
        _twoColumns(
          _field(
            label: 'Village / Town',
            child: TextFormField(
              controller: _villageController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: _inputStyle,
              decoration: _inputDecoration(hint: 'City or locality'),
            ),
          ),
          _field(
            label: 'Pincode',
            required: true,
            child: TextFormField(
              controller: _pincodeController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              style: _inputStyle.copyWith(letterSpacing: 1),
              decoration: _inputDecoration(hint: '411001'),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Required';
                if (v.length != 6) return 'Enter 6 digits';
                return null;
              },
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Section 3: Work ----------
  Widget _buildWorkSection() {
    return _SectionCard(
      icon: Icons.work_outline_rounded,
      iconBg: DT.indigo50,
      iconFg: _C.indigo600,
      title: 'Work Information',
      subtitle: 'Your commercial reach and expertise',
      children: [
        _field(
          label: 'Working Area / Territory',
          child: TextFormField(
            controller: _workingAreaController,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 3,
            style: _inputStyle,
            decoration: _inputDecoration(
                hint: 'e.g. Bhosari industrial cluster & Chakan MIDC'),
          ),
        ),
        _field(
          label: 'Profession / Business Type',
          child: _dropdown(
            value: _selectedProfession,
            hint: 'Select your domain',
            items: _professions,
            onChanged: (v) => setState(() => _selectedProfession = v),
          ),
        ),
        _field(
          label: 'Experience in B2B / Industrial Sales',
          child: _dropdown(
            value: _selectedExperience,
            hint: 'Select years of experience',
            items: _experiences,
            onChanged: (v) => setState(() => _selectedExperience = v),
          ),
        ),
      ],
    );
  }

  // ---------- Section 4: Platforms ----------
  Widget _buildPlatformsSection() {
    return _SectionCard(
      icon: Icons.campaign_outlined,
      iconBg: DT.purple50,
      iconFg: _C.purple600,
      title: 'Promotion Platforms',
      subtitle: 'Channels you use to reach business clients',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: DT.blue50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Select multiple',
          style: DT.text(size: 10, weight: FontWeight.w600, color: _C.blue600),
        ),
      ),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allPlatforms.map((p) {
                final selected = _selectedPlatforms.contains(p.value);
                return SizedBox(
                  width: itemWidth,
                  child: _PlatformChip(
                    platform: p,
                    selected: selected,
                    onTap: () => setState(() {
                      selected
                          ? _selectedPlatforms.remove(p.value)
                          : _selectedPlatforms.add(p.value);
                    }),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ---------- Section 5: Profile image ----------
  Widget _buildProfileImageSection() {
    final hasImage = _profileImageBytes != null;

    return _SectionCard(
      icon: Icons.badge_outlined,
      iconBg: DT.sky50,
      iconFg: _C.sky600,
      title: 'Profile Photo',
      subtitle: 'Shown on your partner ID badge',
      children: [
        if (hasImage)
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(DT.rMd),
                child: Image.memory(
                  _profileImageBytes!,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 88,
                    height: 88,
                    color: DT.slate100,
                    child: const Icon(Icons.broken_image_outlined,
                        color: DT.slate400),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profileImageFile?.name ?? 'Selected photo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 12.5, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _smallButton(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Change',
                          color: _C.blue600,
                          onTap: () => _pickImage(ImageSource.gallery),
                        ),
                        _smallButton(
                          icon: Icons.delete_outline_rounded,
                          label: 'Remove',
                          color: DT.error,
                          onTap: _removeImage,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          InkWell(
            onTap: () => _pickImage(ImageSource.gallery),
            borderRadius: BorderRadius.circular(DT.rMd),
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: DT.slate300,
                radius: DT.rMd,
              ),
              child: Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                decoration: BoxDecoration(
                  color: DT.slate50,
                  borderRadius: BorderRadius.circular(DT.rMd),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: DT.blue100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cloud_upload_outlined,
                          color: _C.blue600, size: 26),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap to upload a profile photo',
                      style: DT.text(size: 12.5, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'JPG, PNG or WEBP',
                      style: DT.text(size: 11, color: DT.slate500),
                    ),
                    const SizedBox(height: 12),
                    _smallButton(
                      icon: Icons.photo_camera_outlined,
                      label: 'Use camera',
                      color: _C.blue600,
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------- Section 6: Referral ----------
  Widget _buildReferralSection() {
    return _SectionCard(
      icon: Icons.redeem_outlined,
      iconBg: DT.amber50,
      iconFg: DT.amber600,
      title: 'Referral',
      subtitle: 'Enter a partner code if someone referred you',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _referredByCodeController,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) {
                  if (_referralApplied) {
                    setState(() => _referralApplied = false);
                  }
                },
                style: DT.text(
                  size: 13,
                  weight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
                decoration: _inputDecoration(hint: 'e.g. QN-PARTNER-88'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _applyReferral,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  _referralApplied ? _C.emerald600 : DT.onyx900,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DT.rMd),
                  ),
                ),
                child: _referralApplied
                    ? const Icon(Icons.check_rounded, size: 20)
                    : Text('Apply',
                    style: DT.text(
                        size: 12.5,
                        weight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: DT.emerald50,
            borderRadius: BorderRadius.circular(DT.rSm),
            border: Border.all(color: DT.emerald200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_outlined,
                  color: _C.emerald600, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _referralApplied
                      ? 'Code added. It will be checked when you submit.'
                      : 'Referral codes are checked when you submit your application.',
                  style: DT.text(
                    size: 11.5,
                    weight: FontWeight.w500,
                    color: _C.emerald800,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Sticky bottom bar ----------
  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DT.borderSoft)),
        boxShadow: DT.shadowBottomNav,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.blue600,
                    disabledBackgroundColor: _C.blue600.withAlpha(160),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: _C.blue500.withAlpha(60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DT.rMd),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Submit Application',
                        style: DT.text(
                          size: 14,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      size: 13, color: _C.emerald600),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Your details are shared only with the QN Mart partner team',
                      textAlign: TextAlign.center,
                      style: DT.text(size: 10.5, color: DT.slate500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =================================================================
  // FORM HELPERS
  // =================================================================
  TextStyle get _inputStyle =>
      DT.text(size: 13.5, weight: FontWeight.w500, color: DT.onyx900);

  InputDecoration _inputDecoration({String? hint, Widget? prefix}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(DT.rMd),
      borderSide: BorderSide(color: c, width: w),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: DT.text(size: 13, weight: FontWeight.w500, color: DT.slate400),
      filled: true,
      fillColor: DT.slate50,
      isDense: true,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      prefixIcon: prefix,
      prefixIconConstraints:
      const BoxConstraints(minHeight: 50, minWidth: 0),
      errorStyle: DT.text(size: 11, weight: FontWeight.w500, color: DT.error),
      errorMaxLines: 2,
      enabledBorder: border(DT.slate300),
      focusedBorder: border(_C.blue600, 1.5),
      errorBorder: border(DT.error),
      focusedErrorBorder: border(DT.error, 1.5),
      border: border(DT.slate300),
    );
  }

  Widget _dropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      menuMaxHeight: 360,
      borderRadius: BorderRadius.circular(DT.rMd),
      dropdownColor: Colors.white,
      icon: const Icon(Icons.expand_more_rounded, color: DT.slate400),
      style: _inputStyle,
      decoration: _inputDecoration(),
      hint: Text(
        hint,
        style: DT.text(size: 13, weight: FontWeight.w500, color: DT.slate400),
      ),
      items: items
          .map((e) => DropdownMenuItem(
        value: e,
        child: Text(e, overflow: TextOverflow.ellipsis),
      ))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _field({
    required String label,
    required Widget child,
    bool required = false,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx700),
            children: [
              if (required)
                TextSpan(
                  text: ' *',
                  style: DT.text(
                      size: 12, weight: FontWeight.w700, color: _C.rose500),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        child,
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(helper, style: DT.text(size: 10.5, color: DT.slate400)),
        ],
      ],
    );
  }

  Widget _twoColumns(Widget a, Widget b) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 12),
        Expanded(child: b),
      ],
    );
  }

  Widget _smallButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: DT.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: DT.text(
                      size: 11.5, weight: FontWeight.w600, color: DT.onyx700)),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// PRIVATE WIDGETS
// =====================================================================

/// White card with an icon header, used for every form section.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DT.slate100)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconFg, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: DT.text(
                              size: 14, weight: FontWeight.w700, height: 1.2)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: DT.text(size: 11, color: DT.slate500),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
          for (final child in children) ...[
            const SizedBox(height: 14),
            child,
          ],
        ],
      ),
    );
  }
}

class _Platform {
  final String value; // sent to API
  final String label; // shown to user
  final Color dot;
  const _Platform(this.value, this.label, this.dot);
}

class _PlatformChip extends StatelessWidget {
  final _Platform platform;
  final bool selected;
  final VoidCallback onTap;

  const _PlatformChip({
    required this.platform,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      button: true,
      child: Material(
        color: selected ? DT.blue50 : DT.slate50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DT.rMd),
          side: BorderSide(
            color: selected ? _C.blue600 : DT.slate200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DT.rMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: platform.dot,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    platform.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(
                      size: 12,
                      weight: FontWeight.w600,
                      color: selected ? DT.blue700 : DT.onyx700,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: selected
                      ? const Icon(Icons.check_circle_rounded,
                      key: ValueKey('on'), size: 16, color: _C.blue600)
                      : const SizedBox(key: ValueKey('off'), width: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws a dashed rounded-rectangle border (for the upload area).
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}