import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/franchise_plan_model.dart';
import '../services/franchise_apply_service.dart';
import 'package:qnx_mart/l10n/app_language.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kBrandDark = Color(0xFF062A50);
const _kBrandLight = Color(0xFF1E5A9C);
const _kHeader = LinearGradient(
  colors: [_kBrandDark, _kBrand, _kBrandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);


class FranchiseApplyScreen extends StatefulWidget {
  final String productSlug;
  final String productName;
  final FranchisePlan plan;

  const FranchiseApplyScreen({
    super.key,
    required this.productSlug,
    required this.productName,
    required this.plan,
  });

  @override
  State<FranchiseApplyScreen> createState() => _FranchiseApplyScreenState();
}

class _FranchiseApplyScreenState extends State<FranchiseApplyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _franchiseNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _altMobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _franchiseNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _altMobileCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _gstCtrl.dispose();
    _panCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final request = FranchiseApplyRequest(
      company: widget.plan.companyId,
      product: widget.plan.product,
      franchisePlan: widget.plan.id,
      franchiseName: _franchiseNameCtrl.text.trim(),
      ownerName: _ownerNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      mobileNo: _mobileCtrl.text.trim(),
      alternateMobileNo: _altMobileCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      gstNo: _gstCtrl.text.trim(),
      panNo: _panCtrl.text.trim(),
      joiningDate: FranchiseApplyRequest.todayDate(),
      franchiseReferralCode: _referralCtrl.text.trim().isEmpty
          ? null
          : _referralCtrl.text.trim(),
    );

    final response = await FranchiseApplyService.submitApplication(request);

    if (!mounted) return;
    setState(() => _isLoading = false);

    // 🔴 Snackbar — red on both success/error (as per your earlier request)
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
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr(response.displayMessage),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
        response.isSuccess ? const Color(0xFF10B981) : Color(0xFFC62828),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );

    if (response.isSuccess) {
      // Navigate back to plans or pop to home
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.surfaceColor,
      appBar: AppBar(
        backgroundColor: _kBrand,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeader)),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          tr('Franchise Application'),
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
              // Selected plan summary
              _buildPlanSummary(),
              const SizedBox(height: 20),

              _sectionTitle(tr('Franchise Details')),
              const SizedBox(height: 12),
              _buildField(
                controller: _franchiseNameCtrl,
                label: tr('Franchise Name'),
                hint: tr('e.g. Latur Central Franchise'),
                icon: Icons.storefront_outlined,
                validator: (v) => _required(v, tr('Franchise name')),
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _ownerNameCtrl,
                label: tr('Owner Name'),
                hint: tr('e.g. John Doe'),
                icon: Icons.person_outline,
                validator: (v) => _required(v, tr('Owner name')),
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _emailCtrl,
                label: tr('Email'),
                hint: 'john@example.com',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return tr('Email is required');
                  final re = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
                  if (!re.hasMatch(v.trim())) return tr('Enter a valid email');
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _mobileCtrl,
                label: tr('Mobile Number'),
                hint: tr('10-digit mobile number'),
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return tr('Mobile number is required');
                  }
                  if (v.trim().length != 10) return tr('Enter a valid 10-digit number');
                  return null;
                },
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _altMobileCtrl,
                label: tr('Alternate Mobile (Optional)'),
                hint: tr('10-digit alternate number'),
                icon: Icons.phone_android_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (v.trim().length != 10) return tr('Enter a valid 10-digit number');
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _sectionTitle(tr('Address')),
              const SizedBox(height: 12),
              _buildField(
                controller: _addressCtrl,
                label: tr('Address'),
                hint: tr('Street, area, landmark'),
                icon: Icons.home_outlined,
                maxLines: 2,
                validator: (v) => _required(v, tr('Address')),
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _cityCtrl,
                label: tr('City / District'),
                hint: tr('e.g. Mumbai'),
                icon: Icons.location_city_outlined,
                validator: (v) => _required(v, tr('City')),
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _stateCtrl,
                label: tr('State'),
                hint: tr('e.g. Maharashtra'),
                icon: Icons.map_outlined,
                validator: (v) => _required(v, tr('State')),
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _pincodeCtrl,
                label: tr('Pincode'),
                hint: tr('6-digit pincode'),
                icon: Icons.pin_drop_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return tr('Pincode is required');
                  if (v.trim().length != 6) return tr('Enter a valid 6-digit pincode');
                  return null;
                },
              ),
              const SizedBox(height: 20),

              _sectionTitle(tr('Business Info (Optional)')),
              const SizedBox(height: 12),
              _buildField(
                controller: _gstCtrl,
                label: tr('GST Number'),
                hint: tr('e.g. 27ABCDE1234F1Z5'),
                icon: Icons.receipt_long_outlined,
                textCapitalization: TextCapitalization.characters,
                validator: (_) => null,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _panCtrl,
                label: tr('PAN Number'),
                hint: tr('e.g. ABCDE1234F'),
                icon: Icons.credit_card_outlined,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [LengthLimitingTextInputFormatter(10)],
                validator: (_) => null,
              ),
              const SizedBox(height: 14),
              _buildField(
                controller: _referralCtrl,
                label: tr('Referral Code (Optional)'),
                hint: tr('Enter referral code if any'),
                icon: Icons.card_giftcard_outlined,
                validator: (_) => null,
              ),
              const SizedBox(height: 28),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBrand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : Text(
                    tr('Submit Application'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // -------- Plan Summary Card --------

  // -------- Plan Summary Card --------

  Widget _buildPlanSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kBrand,
            _kBrand.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Selected Plan'),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trData(widget.plan.planName),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trData(widget.productName),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tr(widget.plan.amountLabel),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),                    // ← he `)` गायब होता
            ],                      // ← Row children close
          ),                        // ← Row close
        ],                          // ← Column children close
      ),                            // ← Column close
    );                              // ← Container close + return
  }

  // -------- Helpers --------

  String? _required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return tr('{0} is required', [fieldName]);
    }
    return null;
  }

  Widget _sectionTitle(String title) {
    return Text(
      tr(title),
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppConstants.textPrimary,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: tr(label),
        hintText: tr(hint),
        prefixIcon: Icon(icon, color: _kBrand),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: _kBrand,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC62828), width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC62828), width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}