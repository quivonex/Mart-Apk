// lib/screens/loan_enquiry_screen.dart

// Loan enquiry – redesigned to match the app (brand blue #1A68FA, page
// #F6F8FC, white cards with slate borders, Plus Jakarta Sans via DT.text).
// Logic unchanged: LoanEnquiryService.createLoanEnquiry.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/design_tokens.dart';
import '../models/loan_enquiry_model.dart';
import '../services/loan_enquiry_service.dart';
import '../widgets/product_ui.dart';

// M3 spacing scale (multiples of 4).
class _S {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

const _brand = Color(0xFF1A68FA);
const _brandDark = Color(0xFF0D3880);

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

  // ----- Logic (unchanged) ------------------------------------------------

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
        content: Row(
          children: [
            Icon(
              response.isSuccess
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: _S.sm),
            Expanded(
              child: Text(
                response.displayMessage,
                style: DT.text(
                    size: 13, weight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: response.isSuccess ? const Color(0xFF059669) : DT.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(_S.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DT.rMd),
        ),
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
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: DT.background,
        appBar: _buildAppBar(),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(_S.lg, _S.md, _S.lg, _S.xxl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHero(),
                  const SizedBox(height: _S.md),
                  _buildSchemes(),
                  const SizedBox(height: _S.md),
                  _buildStepper(),
                  const SizedBox(height: _S.md),
                  _buildPersonalCard(),
                  const SizedBox(height: _S.md),
                  _buildLoanCard(),
                  const SizedBox(height: _S.md),
                  _buildLocationCard(),
                  const SizedBox(height: _S.md),
                  _buildRemarksCard(),
                  const SizedBox(height: _S.lg),
                  _buildPartners(),
                  const SizedBox(height: _S.lg),
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
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: DT.slate200)),
          boxShadow: [
            BoxShadow(
                color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _S.xs),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: DT.onyx900, size: 24),
                  ),
                  const SizedBox(width: _S.xs),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Loan Enquiry',
                                overflow: TextOverflow.ellipsis,
                                style: DT.text(
                                    size: 18,
                                    weight: FontWeight.w700,
                                    color: DT.onyx900,
                                    letterSpacing: -0.3),
                              ),
                            ),
                            const SizedBox(width: _S.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: DT.blue50,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: DT.blue200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_outlined,
                                      size: 11, color: _brand),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Verified',
                                    style: DT.text(
                                        size: 10,
                                        weight: FontWeight.w700,
                                        color: _brand),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'QNX Mart Capital & Credit Network',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 12, color: DT.slate500),
                        ),
                      ],
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

  // ----- Hero banner -------------------------------------------------------

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(_S.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_brandDark, Color(0xFF1557D0), _brand],
        ),
        borderRadius: BorderRadius.circular(DT.rLg),
        boxShadow: const [
          BoxShadow(
              color: Color(0x331A68FA), blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Ambient decorative icon bottom-right
          Positioned(
            right: -18,
            bottom: -18,
            child: Icon(Icons.account_balance_rounded,
                size: 130, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: _S.md, vertical: _S.xs),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, size: 14, color: DT.amber300),
                    const SizedBox(width: 6),
                    Text(
                      'INSTANT APPROVAL IN 15 MINS',
                      style: DT.text(
                          size: 10,
                          weight: FontWeight.w800,
                          color: DT.amber300,
                          letterSpacing: 0.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: _S.md),
              Text(
                'Business Loan\nMade Simple',
                style: DT.text(
                    size: 24,
                    weight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: _S.sm),
              Text(
                'Instant credit limits up to ₹50 Lakhs with verified Tier-1 banking partners. Quick digital sanction for purchase orders and expansion.',
                style: DT.text(
                    size: 12.5,
                    color: const Color(0xFFBFDBFE),
                    height: 1.5),
              ),
              const SizedBox(height: _S.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: _S.sm, vertical: _S.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DT.rMd),
                  border: Border.all(color: Colors.white24),
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
    return _SectionCard(
      icon: Icons.flash_on_rounded,
      title: 'Fast-track loan schemes',
      subtitle: 'Choose a category and get matched',
      children: [
        const Row(
          children: [
            Expanded(
              child: _SchemeTile(
                icon: Icons.receipt_long_outlined,
                title: 'Purchase Order Finance',
                subtitle: 'Collateral-free for MSME',
              ),
            ),
            SizedBox(width: _S.sm),
            Expanded(
              child: _SchemeTile(
                icon: Icons.precision_manufacturing_outlined,
                title: 'Machinery & Capex',
                subtitle: 'Direct OEM disbursal',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ----- Stepper -----------------------------------------------------------

  Widget _buildStepper() {
    Widget connector() => Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: DT.slate200,
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: _S.md, vertical: _S.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.slate200),
        boxShadow: PX.cardShadow,
      ),
      child: Row(
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
            child: _Step(number: 2, title: 'Bank KYC', subtitle: 'GST & PAN'),
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

  // ----- Section 1: Personal -----------------------------------------------

  Widget _buildPersonalCard() {
    return _SectionCard(
      icon: Icons.person_outline,
      title: 'Personal details',
      subtitle: 'Primary applicant or authorized director',
      children: [
        PxLabel('Full name', required: true),
        TextFormField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          style: DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
          decoration: pxInputDecoration(
            hint: 'e.g. Rajesh Kumar',
            icon: Icons.badge_outlined,
            iconColor: _brand,
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Name is required'
              : null,
        ),
        const SizedBox(height: _S.md),
        PxLabel('Mobile number', required: true),
        TextFormField(
          controller: _mobileController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          style: DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
          decoration: pxInputDecoration(
            hint: '98765 43210',
            icon: Icons.phone_outlined,
            iconColor: _brand,
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Mobile number is required';
            if (v.trim().length != 10) {
              return 'Enter a valid 10-digit mobile number';
            }
            return null;
          },
        ),
        const SizedBox(height: _S.xs),
        Text(
          'Bank approval code will be dispatched to this number',
          style: DT.text(size: 11, color: DT.slate500),
        ),
        const SizedBox(height: _S.md),
        PxLabel('Email address', required: true),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          style: DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
          decoration: pxInputDecoration(
            hint: 'name@business.com',
            icon: Icons.alternate_email,
            iconColor: _brand,
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
      ],
    );
  }

  // ----- Section 2: Loan requirements --------------------------------------

  Widget _buildLoanCard() {
    final amount = _amount;
    final emi = _estimatedEmi;

    return _SectionCard(
      icon: Icons.account_balance_outlined,
      title: 'Loan requirements',
      subtitle: 'Configure capital and repayment timeline',
      children: [
        PxLabel('Loan facility type', required: true),
        DropdownButtonFormField<String>(
          value: _selectedLoanType,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, color: DT.slate500),
          style: DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
          decoration: pxInputDecoration(
            hint: 'Select loan type',
            icon: Icons.payments_outlined,
            iconColor: _brand,
          ),
          hint: Text('Select loan type',
              style: DT.text(size: 13.5, color: DT.slate400)),
          items: LoanEnquiryRequest.loanTypeOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option['value'],
              child: Text(option['label']!,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(
                      size: 14, weight: FontWeight.w600, color: DT.onyx900)),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedLoanType = v),
          validator: (v) => (v == null || v.isEmpty)
              ? 'Please select a loan type'
              : null,
        ),
        const SizedBox(height: _S.md),

        // Loan amount with preset chips
        PxLabel('Required loan amount', required: true),
        TextFormField(
          controller: _loanAmountController,
          keyboardType: TextInputType.number,
          inputFormatters: [_IndianAmountFormatter()],
          style: DT.text(
              size: 15, weight: FontWeight.w800, color: DT.onyx900),
          decoration: pxInputDecoration(
            hint: 'e.g. 15,00,000',
            prefix: Padding(
              padding: const EdgeInsets.only(left: 14, right: 4),
              child: Text('₹',
                  style: DT.text(
                      size: 16, weight: FontWeight.w700, color: DT.onyx700)),
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Loan amount is required';
            if (_digitsToInt(v) <= 0) return 'Enter a valid amount';
            return null;
          },
        ),
        const SizedBox(height: _S.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _amountPresets.entries.map((e) {
              final selected = amount == e.key;
              return Padding(
                padding: const EdgeInsets.only(right: _S.sm),
                child: GestureDetector(
                  onTap: () => _setAmount(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: _S.md, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? _brand : DT.blue50,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: selected ? _brand : DT.blue200),
                    ),
                    child: Text(
                      e.value,
                      style: DT.text(
                        size: 11.5,
                        weight: FontWeight.w700,
                        color: selected ? Colors.white : _brand,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: _S.lg),

        // Tenure pills
        PxLabel('Tenure duration', required: true),
        Row(
          children: List.generate(_tenureOptions.length, (i) {
            final years = _tenureOptions[i];
            final selected = _tenureYears == years;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: i == _tenureOptions.length - 1 ? 0 : _S.sm),
                child: GestureDetector(
                  onTap: () => setState(() => _tenureYears = years),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? _brand : DT.slate50,
                      borderRadius: BorderRadius.circular(DT.rMd),
                      border: Border.all(
                          color: selected ? _brand : DT.slate200),
                    ),
                    child: Text(
                      years == 1 ? '1 Year' : '$years Years',
                      style: DT.text(
                        size: 12.5,
                        weight:
                        selected ? FontWeight.w700 : FontWeight.w600,
                        color: selected ? Colors.white : DT.onyx700,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: _S.lg),

        // Monthly turnover
        PxLabel('Average monthly turnover', required: true),
        TextFormField(
          controller: _monthlyIncomeController,
          keyboardType: TextInputType.number,
          inputFormatters: [_IndianAmountFormatter()],
          style: DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
          decoration: pxInputDecoration(
            hint: 'e.g. 4,50,000',
            icon: Icons.trending_up,
            iconColor: _brand,
            suffixText: '/ month',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Monthly turnover is required';
            }
            if (_digitsToInt(v) <= 0) return 'Enter a valid turnover';
            return null;
          },
        ),
        const SizedBox(height: _S.xs),
        Text(
          'Average bank credits over the last 6 months',
          style: DT.text(size: 11, color: DT.slate500),
        ),
        const SizedBox(height: _S.lg),

        // EMI estimate card
        Container(
          padding: const EdgeInsets.all(_S.md),
          decoration: BoxDecoration(
            color: DT.blue50,
            borderRadius: BorderRadius.circular(DT.rMd),
            border: Border.all(color: DT.blue200),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calculate_outlined,
                    size: 20, color: _brand),
              ),
              const SizedBox(width: _S.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Estimated EMI',
                        style: DT.text(size: 11, color: DT.slate500)),
                    const SizedBox(height: 2),
                    Text(
                      emi > 0 ? '~₹${_inr(emi)} / mo' : '—',
                      style: DT.text(
                          size: 15,
                          weight: FontWeight.w800,
                          color: DT.onyx900),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('@ 9.25% p.a.',
                      style: DT.text(
                          size: 11.5,
                          weight: FontWeight.w800,
                          color: _brand)),
                  const SizedBox(height: 2),
                  Text('Zero foreclosure fee',
                      style: DT.text(size: 10.5, color: DT.slate500)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ----- Section 3: Location -----------------------------------------------

  Widget _buildLocationCard() {
    return _SectionCard(
      icon: Icons.storefront_outlined,
      title: 'Business location',
      subtitle: 'Operating plant, warehouse, or retail premises',
      children: [
        PxLabel('City / District', required: true),
        TextFormField(
          controller: _cityController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          style: DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
          decoration: pxInputDecoration(
            hint: 'e.g. Pune / Mumbai',
            icon: Icons.apartment,
            iconColor: _brand,
          ),
          validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'City is required' : null,
        ),
        const SizedBox(height: _S.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PxLabel('State', required: true),
                  TextFormField(
                    controller: _stateController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    style: DT.text(
                        size: 14, weight: FontWeight.w600, color: DT.onyx900),
                    decoration: pxInputDecoration(
                      hint: 'e.g. Maharashtra',
                      icon: Icons.map_outlined,
                      iconColor: _brand,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'State is required'
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: _S.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PxLabel('Pincode', required: true),
                  TextFormField(
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    style: DT.text(
                        size: 14, weight: FontWeight.w600, color: DT.onyx900),
                    decoration: pxInputDecoration(
                      hint: '411001',
                      icon: Icons.pin_drop_outlined,
                      iconColor: _brand,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Pincode is required';
                      }
                      if (v.trim().length != 6) return 'Enter 6 digits';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ----- Section 4: Remarks ------------------------------------------------

  Widget _buildRemarksCard() {
    return _SectionCard(
      icon: Icons.edit_note,
      title: 'Additional information',
      subtitle: 'Optional notes for credit underwriters',
      children: [
        PxLabel('Remarks / specific purchase order details', optional: true),
        TextFormField(
          controller: _remarksController,
          maxLines: 4,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: DT.text(size: 14, weight: FontWeight.w500, color: DT.onyx900),
          decoration: pxInputDecoration(
            hint:
            'Specify existing trade lines, purchase order references, or specific disbursement target dates…',
            tinted: true,
          ),
        ),
      ],
    );
  }

  // ----- Partners strip ----------------------------------------------------

  Widget _buildPartners() {
    Widget chip(String name, IconData icon, Color color) => Container(
      padding: const EdgeInsets.symmetric(
          horizontal: _S.md, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rSm),
        border: Border.all(color: DT.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(name,
              style: DT.text(
                  size: 11.5, weight: FontWeight.w700, color: DT.onyx900)),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_S.md),
      decoration: BoxDecoration(
        color: DT.slate50,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 14, color: _brand),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'SANCTIONING INSTITUTIONAL PARTNERS',
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(
                      size: 10.5,
                      weight: FontWeight.w700,
                      color: DT.onyx700,
                      letterSpacing: 0.6),
                ),
              ),
              Text('256-bit encrypted',
                  style: DT.text(size: 10, color: DT.slate500)),
            ],
          ),
          const SizedBox(height: _S.md),
          Wrap(
            spacing: _S.sm,
            runSpacing: _S.sm,
            children: [
              chip('SBI Commercial', Icons.account_balance_rounded, _brand),
              chip('HDFC Capital', Icons.account_balance_rounded,
                  const Color(0xFF2563EB)),
              chip('ICICI Trade', Icons.account_balance_rounded,
                  const Color(0xFFF97316)),
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
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitEnquiry,
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _brand.withValues(alpha: 0.55),
              elevation: 2,
              shadowColor: const Color(0x401A68FA),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DT.rMd)),
            ),
            child: _isLoading
                ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Submit loan enquiry',
                    style: DT.text(
                        size: 15,
                        weight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(width: _S.sm),
                const Icon(Icons.arrow_forward_rounded, size: 19),
              ],
            ),
          ),
        ),
        const SizedBox(height: _S.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _S.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.verified_outlined,
                    size: 13, color: DT.slate400),
              ),
              const SizedBox(width: _S.xs),
              Flexible(
                child: Text(
                  'By submitting, you agree to QNX Mart Credit Terms & official CIBIL inquiry consent.',
                  textAlign: TextAlign.center,
                  style: DT.text(size: 10.5, color: DT.slate400),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Reusable widgets
// =============================================================================

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.slate200),
        boxShadow: PX.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DT.slate100)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: DT.blue50,
                    borderRadius: BorderRadius.circular(DT.rMd),
                  ),
                  child: Icon(icon, size: 20, color: _brand),
                ),
                const SizedBox(width: _S.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: DT.text(
                            size: 14,
                            weight: FontWeight.w700,
                            color: DT.onyx900,
                            height: 1.2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 11.5, color: DT.slate500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _S.md),
          ...children,
        ],
      ),
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
                      fontWeight: FontWeight.w400, color: Color(0xFFBFDBFE)),
                ),
            ],
          ),
          textAlign: TextAlign.center,
          style: DT.text(
              size: 13, weight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: DT.text(
              size: 10.5,
              weight: FontWeight.w600,
              color: const Color(0xCCFFFFFF)),
        ),
      ],
    );
  }
}

class _SchemeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SchemeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_S.md),
      decoration: BoxDecoration(
        color: DT.blue50,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.blue200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: _brand),
          ),
          const SizedBox(height: _S.sm),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DT.text(
                size: 12,
                weight: FontWeight.w800,
                color: DT.onyx900,
                height: 1.25),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DT.text(size: 10.5, color: DT.slate500),
          ),
        ],
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
      opacity: active ? 1 : 0.65,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? _brand : DT.slate100,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: DT.text(
                size: 11,
                weight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? Colors.white : DT.slate500,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(
                    size: 11,
                    weight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? _brand : DT.onyx700,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(size: 10, color: DT.slate500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}