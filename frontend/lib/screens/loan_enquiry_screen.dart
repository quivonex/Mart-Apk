import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/loan_enquiry_model.dart';
import '../services/loan_enquiry_service.dart';

/// Design tokens taken from the HTML design (Tailwind config).
class _C {
  static const primary = Color(0xFF004AC6);
  static const primaryContainer = Color(0xFF2563EB);
  static const onSurface = Color(0xFF191C1E);
  static const onSurfaceVariant = Color(0xFF434655);
  static const secondary = Color(0xFF565E74);
  static const secondaryContainer = Color(0xFFDAE2FD);
  static const secondaryFixedDim = Color(0xFFBEC6E0);
  static const onPrimaryFixedVariant = Color(0xFF003EA8);
  static const surface = Color(0xFFF7F9FB);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF2F4F6);
  static const surfaceContainer = Color(0xFFECEEF0);
  static const surfaceHigh = Color(0xFFE6E8EA);
  static const surfaceHighest = Color(0xFFE0E3E5);
  static const error = Color(0xFFBA1A1A);
  static const tertiary = Color(0xFF824500);
  static const tertiaryFixed = Color(0xFFFFDCC3);
  static const navy = Color(0xFF0F172A);
}

const _fontFamily = 'PlusJakartaSans'; // add the font in pubspec.yaml (optional)

const _schemeImg1 =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuDIPnlERvfINv5as9y3s0ghFXmT16qWumhU2mBuALfrKy-4Ox7mJknsBizgSAbG5shHmwRRVQyFuS9IO5hSyfpTYcmF3nsmvx68h5F4xaYofH8E4_DLRt1V2gInwGV5NMB-OPRLmlcraXsdpHBz71Qa3dQ54Qp4V-cuGl7JskmgFBSsvr3rn_rZrapTU2Xc_CykuTEHpcMA0tevOeM_mi2uJlopMjv0xK0c9KyQSeIHyC3OndrDsqN-2h8tLbQA5T8qaQ';
const _schemeImg2 =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuCgzXGjV_FUgGorC4N31FLnBXNMuTobgPt5UY0_gVmw5_dAek_2oR0BhpzQg2cUmV5HEIhXv0_jTuPzjY4a8bV2zOfZIm8JbZKMM0O7OOPry6PjXVdllp0PJW90T8ly3KYofWGf_AJ8ABeV2VJebzbUILKqmB27xPytHxdfG4Z5jyKxucZNgeaoSKZp5HStMxvXyE2yO5hptOhaeoExwNdQa7gw3fhMGoNm2hSD34AP43azAm3F9GkKG-e0dttczJANOw';

const _amountPresets = <int, String>{
  500000: '₹5 Lakhs',
  1000000: '₹10 Lakhs',
  1500000: '₹15 Lakhs',
  2500000: '₹25 Lakhs',
  5000000: '₹50 Lakhs',
};
const _tenureOptions = <int>[1, 2, 3, 5];
const _interestRate = 0.0925; // 9.25% p.a. (used for the EMI estimate)

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// 1500000 -> "15,00,000"
String _inr(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3).replaceAllMapped(
    RegExp(r'(\d)(?=(\d{2})+$)'),
        (m) => '${m[1]},',
  );
  return '$rest,$last3';
}

int _digitsToInt(String text) =>
    int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// Formats typed digits with Indian digit grouping (12,34,567).
class _IndianAmountFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    if (digits.length > 10) digits = digits.substring(0, 10);
    final formatted = _inr(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class LoanEnquiryScreen extends StatefulWidget {
  const LoanEnquiryScreen({super.key});

  @override
  State<LoanEnquiryScreen> createState() => _LoanEnquiryScreenState();
}

class _LoanEnquiryScreenState extends State<LoanEnquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = LoanEnquiryService();

  // Controllers
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _loanAmountController = TextEditingController();
  final _monthlyIncomeController = TextEditingController(); // monthly turnover
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _remarksController = TextEditingController();

  String? _selectedLoanType;
  int _tenureYears = 3;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Rebuild so the preset chips + EMI widget stay in sync with the amount.
    _loanAmountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() => setState(() {});

  @override
  void dispose() {
    _loanAmountController.removeListener(_onAmountChanged);
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _loanAmountController.dispose();
    _monthlyIncomeController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  // ----- Logic -------------------------------------------------------------

  int get _amount => _digitsToInt(_loanAmountController.text);

  int get _estimatedEmi {
    final p = _amount;
    if (p <= 0) return 0;
    final r = _interestRate / 12;
    final n = _tenureYears * 12;
    final f = math.pow(1 + r, n);
    return (p * r * f / (f - 1)).round();
  }

  void _setAmount(int value) {
    _loanAmountController.text = _inr(value);
  }

  Future<void> _submitEnquiry() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final request = LoanEnquiryRequest(
      name: _nameController.text.trim(),
      mobile: _mobileController.text.trim(),
      email: _emailController.text.trim(),
      loanType: _selectedLoanType!,
      loanAmount: _digitsToInt(_loanAmountController.text).toDouble(),
      tenureYears: _tenureYears,
      monthlyIncome: _digitsToInt(_monthlyIncomeController.text).toDouble(),
      city: _cityController.text.trim(),
      state: _stateController.text.trim(),
      pincode: _pincodeController.text.trim(),
      remarks: _remarksController.text.trim().isEmpty
          ? null
          : _remarksController.text.trim(),
    );

    final response = await _service.createLoanEnquiry(request);

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response.displayMessage),
        backgroundColor: response.isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    if (response.isSuccess) _resetForm();
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _nameController.clear();
    _mobileController.clear();
    _emailController.clear();
    _loanAmountController.clear();
    _monthlyIncomeController.clear();
    _cityController.clear();
    _stateController.clear();
    _pincodeController.clear();
    _remarksController.clear();
    setState(() {
      _selectedLoanType = null;
      _tenureYears = 3;
    });
  }

  void _autoFillFromPincode() {
    // TODO: look up city/state from the 6-digit pincode via your API.
  }

  // ----- Build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(fontFamily: _fontFamily),
      ),
      child: Scaffold(
        backgroundColor: _C.surface,
        appBar: _buildAppBar(),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(),
                  const SizedBox(height: 12),
                  _buildSchemes(),
                  const SizedBox(height: 12),
                  _buildStepper(),
                  const SizedBox(height: 12),
                  _buildPersonalCard(),
                  const SizedBox(height: 12),
                  _buildLoanCard(),
                  const SizedBox(height: 12),
                  _buildLocationCard(),
                  const SizedBox(height: 12),
                  _buildRemarksCard(),
                  const SizedBox(height: 16),
                  _buildPartners(),
                  const SizedBox(height: 16),
                  _buildSubmit(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ----- App bar -----------------------------------------------------------

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _C.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      scrolledUnderElevation: 1,
      shadowColor: const Color(0x14000000),
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: 4,
      title: Row(
        children: [
          IconButton(
            tooltip: 'Go back',
            icon: const Icon(Icons.arrow_back, color: _C.onSurface),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'Loan Enquiry',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: _C.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _C.secondaryContainer,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_outlined,
                              size: 12, color: _C.primary),
                          SizedBox(width: 2),
                          Text(
                            'Verified',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: _C.onPrimaryFixedVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Text(
                  'OnyxMart Capital & Credit Network',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: _C.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Support assistance',
          icon: const Icon(Icons.help_outline, color: _C.secondary, size: 22),
          onPressed: () {},
        ),
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(left: 4, right: 16),
          decoration: const BoxDecoration(
            color: _C.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Color(0x1A000000), blurRadius: 2, offset: Offset(0, 1)),
            ],
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 18),
        ),
      ],
    );
  }

  // ----- Hero banner -------------------------------------------------------

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.navy, Color(0xFF1E3A8A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient glow
          Positioned(
            top: -64,
            right: -64,
            child: Container(
              width: 176,
              height: 176,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x442563EB), Color(0x002563EB)],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 14, color: _C.tertiaryFixed),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Instant In-Principle Approval in 15 Mins',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: _C.tertiaryFixed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enterprise Working Capital',
                style: TextStyle(
                  fontSize: 20,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xE6E0E3E5),
                  ),
                  children: [
                    TextSpan(text: 'Instant credit limits up to '),
                    TextSpan(
                      text: '₹50 Lakhs',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    TextSpan(
                      text:
                      ' with verified Tier-1 banking partners. Quick digital sanction for purchase orders and expansion.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x0DFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Expanded(
                        child: _TrustPip(
                            value: '8.75%',
                            suffix: ' p.a.',
                            label: 'Starting APR')),
                    Expanded(
                        child: _TrustPip(value: 'Zero', label: 'Collateral')),
                    Expanded(
                        child: _TrustPip(
                            value: 'Up to 60m', label: 'Flexible Tenure')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----- Fast-track schemes ------------------------------------------------

  Widget _buildSchemes() {
    return _Card(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FAST-TRACK LOAN SCHEMES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _C.secondary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.health_and_safety_outlined,
                        size: 13, color: _C.primary),
                    SizedBox(width: 2),
                    Text(
                      'RBI Regulated',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: _C.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Expanded(
                child: _SchemeTile(
                  imageUrl: _schemeImg1,
                  title: 'Purchase Order Finance',
                  subtitle: 'Collateral-Free for MSME',
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _SchemeTile(
                  imageUrl: _schemeImg2,
                  title: 'Machinery & Capex',
                  subtitle: 'Direct OEM Disbursal',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----- Stepper -----------------------------------------------------------

  Widget _buildStepper() {
    Widget connector() => Container(
      width: 24,
      height: 2,
      decoration: BoxDecoration(
        color: _C.surfaceHighest,
        borderRadius: BorderRadius.circular(99),
      ),
    );

    return _Card(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Flexible(
            child: _Step(
                number: 1,
                title: 'Loan Details',
                subtitle: 'In Progress',
                active: true),
          ),
          connector(),
          const Flexible(
            child: _Step(number: 2, title: 'Bank KYC', subtitle: 'GST & Pan'),
          ),
          connector(),
          const Flexible(
            child: _Step(
                number: 3, title: 'Disbursal', subtitle: 'Direct Credit'),
          ),
        ],
      ),
    );
  }

  // ----- Section 1: Personal ----------------------------------------------

  Widget _buildPersonalCard() {
    return _SectionCard(
      icon: Icons.person_outline,
      title: 'Personal Details',
      subtitle: 'Primary applicant or authorized director',
      child: Column(
        children: [
          _Field(
            label: 'Full Name',
            required: true,
            child: TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: _inputText,
              decoration: _dec(
                hint: 'e.g., Rajesh Kumar',
                icon: Icons.badge_outlined,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Name is required'
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          _Field(
            label: 'Mobile Number',
            required: true,
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 11, color: _C.primary),
                SizedBox(width: 2),
                Text('OTP Verified',
                    style: TextStyle(fontSize: 10, color: _C.primary)),
              ],
            ),
            footer: const Text(
              'Bank approval code will be dispatched to this number',
              style: TextStyle(fontSize: 11, color: _C.secondary),
            ),
            child: TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              style: _inputText,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: _dec(hint: '98765 43210').copyWith(
                prefixIcon: Container(
                  width: 52,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _C.surfaceContainer,
                    borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(8)),
                  ),
                  child: const Text(
                    '+91',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: _C.onSurface,
                    ),
                  ),
                ),
                prefixIconConstraints:
                const BoxConstraints(minWidth: 52, minHeight: 44),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Mobile number is required';
                }
                if (v.trim().length != 10) {
                  return 'Enter a valid 10-digit mobile number';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 8),
          _Field(
            label: 'Email Address',
            required: true,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: _C.surfaceContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Work email preferred',
                style: TextStyle(fontSize: 10, color: _C.secondary),
              ),
            ),
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: _inputText,
              decoration: _dec(
                hint: 'name@business.com',
                icon: Icons.alternate_email,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(v.trim())) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }

  // ----- Section 2: Loan requirements -------------------------------------

  Widget _buildLoanCard() {
    final amount = _amount;
    final emi = _estimatedEmi;

    return _SectionCard(
      icon: Icons.account_balance_outlined,
      title: 'Loan Requirements',
      subtitle: 'Configure required capital and repayment timeline',
      child: Column(
        children: [
          // Loan facility type
          _Field(
            label: 'Loan Facility Type',
            required: true,
            child: DropdownButtonFormField<String>(
              value: _selectedLoanType,
              isExpanded: true,
              style: _inputText,
              icon: const Icon(Icons.expand_more, color: _C.secondary),
              decoration: _dec(
                hint: 'Select loan type',
                icon: Icons.payments_outlined,
              ),
              hint: const Text('Select loan type',
                  style: TextStyle(fontSize: 14, color: _C.secondary)),
              items: LoanEnquiryRequest.loanTypeOptions.map((option) {
                return DropdownMenuItem<String>(
                  value: option['value'],
                  child: Text(option['label']!, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedLoanType = v),
              validator: (v) => (v == null || v.isEmpty)
                  ? 'Please select a loan type'
                  : null,
            ),
          ),
          const SizedBox(height: 8),

          // Loan amount + preset chips
          _Field(
            label: 'Required Loan Amount (₹)',
            required: true,
            footer: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _amountPresets.entries.map((e) {
                    final selected = amount == e.key;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => _setAmount(e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                            selected ? _C.primary : _C.surfaceContainer,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color:
                              selected ? Colors.white : _C.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            child: TextFormField(
              controller: _loanAmountController,
              keyboardType: TextInputType.number,
              style: _inputText.copyWith(
                  fontWeight: FontWeight.w700, fontSize: 14),
              inputFormatters: [_IndianAmountFormatter()],
              decoration: _dec(hint: 'e.g., 15,00,000').copyWith(
                prefixIcon: const SizedBox(
                  width: 34,
                  child: Center(
                    child: Text('₹',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _C.onSurface)),
                  ),
                ),
                prefixIconConstraints:
                const BoxConstraints(minWidth: 34, minHeight: 44),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Loan amount is required';
                }
                if (_digitsToInt(v) <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
          ),
          const SizedBox(height: 8),

          // Tenure pills
          _Field(
            label: 'Tenure Duration',
            required: true,
            child: Row(
              children: List.generate(_tenureOptions.length, (i) {
                final years = _tenureOptions[i];
                final selected = _tenureYears == years;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: i == _tenureOptions.length - 1 ? 0 : 6),
                    child: GestureDetector(
                      onTap: () => setState(() => _tenureYears = years),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? _C.primary : _C.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          years == 1 ? '1 Year' : '$years Years',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.2,
                            fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                            color: selected ? Colors.white : _C.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),

          // Monthly turnover
          _Field(
            label: 'Average Monthly Turnover (₹)',
            required: true,
            trailing: const Text('Bank credits last 6 mos',
                style: TextStyle(fontSize: 10, color: _C.secondary)),
            child: TextFormField(
              controller: _monthlyIncomeController,
              keyboardType: TextInputType.number,
              style: _inputText,
              inputFormatters: [_IndianAmountFormatter()],
              decoration: _dec(
                hint: 'e.g., 4,50,000',
                icon: Icons.trending_up,
              ).copyWith(prefixText: '₹ ', suffixText: '/ month'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Monthly turnover is required';
                }
                if (_digitsToInt(v) <= 0) return 'Enter a valid turnover';
                return null;
              },
            ),
          ),
          const SizedBox(height: 8),

          // EMI estimate
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0x66DAE2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0x1A004AC6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.calculate_outlined,
                      size: 18, color: _C.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estimated EMI',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: _C.secondary)),
                      Text(
                        emi > 0 ? '~₹${_inr(emi)} / mo' : '—',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _C.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('@ 9.25% p.a.',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _C.primary)),
                    Text('Zero Foreclosure Fee',
                        style: TextStyle(fontSize: 10, color: _C.secondary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----- Section 3: Location ----------------------------------------------

  Widget _buildLocationCard() {
    return _SectionCard(
      icon: Icons.storefront_outlined,
      title: 'Business Location',
      subtitle: 'Operating plant, warehouse, or retail premises',
      child: Column(
        children: [
          _Field(
            label: 'City / District',
            required: true,
            child: TextFormField(
              controller: _cityController,
              textCapitalization: TextCapitalization.words,
              style: _inputText,
              decoration:
              _dec(hint: 'e.g., Pune / Mumbai', icon: Icons.apartment),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'City is required'
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Field(
                  label: 'State',
                  required: true,
                  child: TextFormField(
                    controller: _stateController,
                    textCapitalization: TextCapitalization.words,
                    style: _inputText,
                    decoration: _dec(
                      hint: 'e.g., Maharashtra',
                      icon: Icons.map_outlined,
                      iconWidth: 36,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'State is required'
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _Field(
                  label: 'Pincode',
                  required: true,
                  trailing: GestureDetector(
                    onTap: _autoFillFromPincode,
                    child: const Text('Auto',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _C.primary)),
                  ),
                  child: TextFormField(
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    style: _inputText,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: _dec(
                      hint: 'e.g., 411001',
                      icon: Icons.pin_drop_outlined,
                      iconWidth: 36,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Pincode is required';
                      }
                      if (v.trim().length != 6) return 'Enter 6 digits';
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----- Section 4: Remarks -----------------------------------------------

  Widget _buildRemarksCard() {
    return _SectionCard(
      icon: Icons.edit_note,
      title: 'Additional Information',
      subtitle: 'Optional notes for credit underwriters',
      child: _Field(
        label: 'Remarks / Specific Purchase Order Details',
        child: TextFormField(
          controller: _remarksController,
          maxLines: 3,
          style: _inputText,
          decoration: _dec(
            hint:
            'Specify existing trade lines, purchase order references, or specific disbursement target dates...',
          ).copyWith(
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ),
    );
  }

  // ----- Partners strip ----------------------------------------------------

  Widget _buildPartners() {
    Widget chip(String name, Color dot) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _C.surfaceLowest,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 1,
              offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(name,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _C.onSurface)),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _C.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'SANCTIONING INSTITUTIONAL PARTNERS',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: _C.secondary,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 13, color: _C.primary),
                  SizedBox(width: 4),
                  Text('256-Bit Encrypted',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _C.secondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              chip('SBI Commercial', _C.primary),
              chip('HDFC Capital', _C.primaryContainer),
              chip('ICICI Trade', _C.tertiary),
            ],
          ),
        ],
      ),
    );
  }

  // ----- Submit ------------------------------------------------------------

  Widget _buildSubmit() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitEnquiry,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _C.primary.withAlpha(150),
              disabledForegroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            )
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Submit Loan Enquiry',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.verified_outlined,
                    size: 13, color: _C.secondary),
              ),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'By submitting, you agree to OnyxMart Credit Terms & official CIBIL inquiry consent.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: _C.secondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ----- Input styling -----------------------------------------------------

  static const _inputText = TextStyle(
    fontSize: 14,
    height: 1.4,
    color: _C.onSurface,
  );

  InputDecoration _dec({
    String? hint,
    IconData? icon,
    double iconWidth = 40,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color, width: width),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          fontSize: 14, color: Color(0x99565E74), fontWeight: FontWeight.w400),
      isDense: true,
      filled: true,
      fillColor: _C.surfaceLow,
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 18, color: _C.secondary),
      prefixIconConstraints:
      BoxConstraints(minWidth: iconWidth, minHeight: 44),
      contentPadding: EdgeInsets.fromLTRB(icon == null ? 12 : 0, 12, 12, 12),
      errorStyle: const TextStyle(fontSize: 11, color: _C.error),
      errorMaxLines: 2,
      border: border(Colors.transparent, 0),
      enabledBorder: border(Colors.transparent, 0),
      focusedBorder: border(_C.primary, 1.5),
      errorBorder: border(_C.error, 1),
      focusedErrorBorder: border(_C.error, 1.5),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable widgets
// ---------------------------------------------------------------------------

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({required this.child, this.padding = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _C.surfaceLowest,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _C.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: _C.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: _C.onSurface)),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: _C.secondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Label (with optional red asterisk + trailing widget) above a field.
class _Field extends StatelessWidget {
  final String label;
  final bool required;
  final Widget? trailing;
  final Widget? footer;
  final Widget child;

  const _Field({
    required this.label,
    required this.child,
    this.required = false,
    this.trailing,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: label,
                    children: required
                        ? const [
                      TextSpan(
                          text: ' *', style: TextStyle(color: _C.error)),
                    ]
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: _C.onSurfaceVariant,
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!,
              ],
            ],
          ),
        ),
        child,
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: footer!,
          ),
      ],
    );
  }
}

class _TrustPip extends StatelessWidget {
  final String value;
  final String? suffix;
  final String label;

  const _TrustPip({required this.value, required this.label, this.suffix});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: value,
            children: [
              if (suffix != null)
                TextSpan(
                  text: suffix,
                  style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      color: _C.secondaryFixedDim),
                ),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: Color(0xCCE0E3E5),
          ),
        ),
      ],
    );
  }
}

class _SchemeTile extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;

  const _SchemeTile({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: _C.surfaceContainer),
            Opacity(
              opacity: 0.9,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) =>
                const ColoredBox(color: _C.surfaceHigh),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xE60F172A),
                    Color(0x4D0F172A),
                    Color(0x000F172A),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      color: _C.surfaceHighest,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final bool active;

  const _Step({
    required this.number,
    required this.title,
    required this.subtitle,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
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
              color: active ? _C.primary : _C.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? Colors.white : _C.secondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.4,
                    color: active ? _C.primary : _C.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: _C.secondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}