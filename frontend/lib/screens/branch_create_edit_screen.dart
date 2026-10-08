import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/design_tokens.dart';
import '../models/branch_model.dart';
import '../services/branch_service.dart';
import '../widgets/product_ui.dart';

class BranchCreateEditScreen extends StatefulWidget {
  final Branch? existing;

  const BranchCreateEditScreen({super.key, this.existing});

  @override
  State<BranchCreateEditScreen> createState() => _BranchCreateEditScreenState();
}

class _BranchCreateEditScreenState extends State<BranchCreateEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  List<CompanyName> _companies = [];
  int? _selectedCompanyId;
  bool _isLoadingCompanies = true;
  bool _isSubmitting = false;

  static const _brand = Color(0xFF1A68FA);

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _selectedCompanyId = widget.existing!.company;
      _nameCtrl.text = widget.existing!.name;
      _phoneCtrl.text = widget.existing!.phoneNumber;
      _emailCtrl.text = widget.existing!.email;
      _addressCtrl.text = widget.existing!.address;
    }
    _loadCompanies();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoadingCompanies = true);
    final res = await BranchService.getCompanyNames();
    if (!mounted) return;
    setState(() {
      _isLoadingCompanies = false;
      if (res.isSuccess) _companies = res.data;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCompanyId == null) {
      _snack('Please select a company', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    BranchActionResponse res;

    if (_isEdit) {
      res = await BranchService.updateBranch(
        id: widget.existing!.id,
        company: _selectedCompanyId!,
        name: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );
    } else {
      res = await BranchService.createBranch(
        company: _selectedCompanyId!,
        name: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
      );
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    _snack(res.displayMessage, isError: !res.isSuccess);
    if (res.isSuccess) Navigator.pop(context, true);
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg,
              style: DT.text(
                  size: 13, weight: FontWeight.w600, color: Colors.white)),
          backgroundColor: isError ? DT.error : const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DT.rMd)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.background,
      appBar: _appBar(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _infoCard(
                icon: Icons.storefront_outlined,
                title: _isEdit ? 'Edit branch' : 'New branch',
                subtitle:
                'Branches let you sell from more than one location',
              ),
              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.business_outlined,
                title: 'Company',
                subtitle: 'Branch will belong to this company',
                children: [_companyDropdown()],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.info_outline,
                title: 'Branch information',
                subtitle: 'Contact details for this location',
                children: [
                  _field(
                    _nameCtrl,
                    'Branch name',
                    'e.g. Mumbai HQ',
                    Icons.store_outlined,
                    required: true,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Branch name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    _phoneCtrl,
                    'Phone number',
                    '10-digit mobile number',
                    Icons.phone_outlined,
                    required: true,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Phone is required';
                      }
                      if (v.trim().length != 10) {
                        return 'Enter valid 10-digit number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _field(
                    _emailCtrl,
                    'Email',
                    'branch@example.com',
                    Icons.email_outlined,
                    required: true,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      final re =
                      RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
                      if (!re.hasMatch(v.trim())) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _field(
                    _addressCtrl,
                    'Address',
                    'Street, area, city',
                    Icons.home_outlined,
                    required: true,
                    maxLines: 2,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Address is required'
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  // ── App bar ─────────────────────────────────────────────
  PreferredSizeWidget _appBar() {
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
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: DT.onyx900, size: 24),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit branch' : 'Add branch',
                          style: DT.text(
                              size: 18,
                              weight: FontWeight.w700,
                              color: DT.onyx900,
                              letterSpacing: -0.3),
                        ),
                        Text(
                          'Manage branch details',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(
                              size: 12,
                              weight: FontWeight.w500,
                              color: DT.slate500),
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

  // ── Company dropdown ─────────────────────────────────────
  Widget _companyDropdown() {
    if (_isLoadingCompanies) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DT.slate50,
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: DT.slate200),
        ),
        child: Row(
          children: const [
            SizedBox(
              height: 18,
              width: 18,
              child:
              CircularProgressIndicator(strokeWidth: 2, color: _brand),
            ),
            SizedBox(width: 10),
            Text('Loading companies…'),
          ],
        ),
      );
    }

    if (_companies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DT.errorBg,
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: DT.errorBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: DT.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No companies found. Please create a company first.',
                style: DT.text(size: 12, color: DT.error),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedCompanyId,
      isExpanded: true,
      icon: const Icon(Icons.expand_more, color: DT.slate500),
      style: DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
      decoration: pxInputDecoration(
        hint: 'Select company',
        icon: Icons.business_outlined,
        iconColor: _brand,
      ),
      hint: Text('Select company',
          style: DT.text(size: 13.5, color: DT.slate400)),
      items: _companies.map((c) {
        return DropdownMenuItem<int>(
          value: c.id,
          child: Text(c.name,
              overflow: TextOverflow.ellipsis,
              style: DT.text(
                  size: 14, weight: FontWeight.w600, color: DT.onyx900)),
        );
      }).toList(),
      onChanged: (v) => setState(() => _selectedCompanyId = v),
      validator: (v) => v == null ? 'Company is required' : null,
    );
  }

  // ── Info banner ──────────────────────────────────────────
  Widget _infoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DT.blue50,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.blue200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: _brand, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: DT.text(
                        size: 14,
                        weight: FontWeight.w800,
                        color: DT.onyx900)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                    DT.text(size: 11.5, color: DT.slate500, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section card ─────────────────────────────────────────
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: DT.text(
                              size: 14,
                              weight: FontWeight.w700,
                              color: DT.onyx900,
                              height: 1.2)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 11.5, color: DT.slate500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ── Field helper ─────────────────────────────────────────
  Widget _field(
      TextEditingController ctrl,
      String label,
      String hint,
      IconData icon, {
        bool required = false,
        TextInputType? keyboardType,
        List<TextInputFormatter>? inputFormatters,
        String? Function(String?)? validator,
        int maxLines = 1,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PxLabel(label, required: required, optional: !required),
        TextFormField(
          controller: ctrl,
          keyboardType:
          maxLines > 1 ? TextInputType.multiline : keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          minLines: maxLines > 1 ? maxLines : null,
          maxLines: maxLines,
          style: DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
          decoration: pxInputDecoration(
            hint: hint,
            icon: icon,
            iconColor: _brand,
            tinted: maxLines > 1,
          ),
        ),
      ],
    );
  }

  // ── Sticky bottom bar ────────────────────────────────────
  Widget _bottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DT.slate200)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _brand.withValues(alpha: 0.55),
                elevation: 2,
                shadowColor: const Color(0x401A68FA),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DT.rMd)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isEdit ? 'Update branch' : 'Create branch',
                    style: DT.text(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}