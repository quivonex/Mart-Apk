// lib/screens/catalog/branch_screens.dart
//
// BranchManageScreen  - list a company's branches (active / inactive), add, edit, (de)activate
// BranchFormScreen    - create / edit. Pops with the saved CatalogBranch.
// Redesigned to match the app (brand blue #1A68FA, white cards, slate borders).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/design_tokens.dart';
import '../models/catalog_models.dart';
import '../services/catalog_service.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/company_ui.dart';
import '../widgets/product_ui.dart';

class BranchManageScreen extends StatefulWidget {
  final int companyId;
  final String companyName;

  const BranchManageScreen({super.key, required this.companyId, required this.companyName});

  @override
  State<BranchManageScreen> createState() => _BranchManageScreenState();
}

class _BranchManageScreenState extends State<BranchManageScreen> {
  List<CatalogBranch> _items = [];
  bool _loading = true;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await CatalogService.getBranches(widget.companyId, activeOnly: false);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = r.items;
      _error = r.ok ? null : r.message;
    });
  }

  Future<void> _openForm([CatalogBranch? existing]) async {
    final saved = await Navigator.push<CatalogBranch>(
      context,
      MaterialPageRoute(
        builder: (_) => BranchFormScreen(
          companyId: widget.companyId,
          companyName: widget.companyName,
          existing: existing,
        ),
      ),
    );
    if (saved != null) {
      _changed = true;
      _load();
    }
  }

  Future<void> _toggle(CatalogBranch b) async {
    final ok = await catalogToggleActive(
      context,
      name: b.name,
      currentlyActive: b.isActive,
      call: () => CatalogService.setBranchActive(b.id, !b.isActive),
    );
    if (ok) {
      _changed = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: DT.background,
        appBar: CompanyTopBar(title: 'Branches', subtitle: widget.companyName),
        floatingActionButton: _items.isEmpty
            ? null
            : FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: DT.blue800,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text('Add branch',
              style: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
        ),
        body: CatalogManageList<CatalogBranch>(
          loading: _loading,
          error: _error,
          items: _items,
          emptyIcon: Icons.store_mall_directory_outlined,
          emptyTitle: 'No branches yet',
          emptyMessage: 'Add a branch if this company sells from more than one location.',
          onRefresh: _load,
          onAdd: () => _openForm(),
          onEdit: _openForm,
          onToggleActive: _toggle,
        ),
      ),
    );
  }
}

// ===========================================================================
// Branch Form (Add / Edit) — redesigned
// ===========================================================================
class BranchFormScreen extends StatefulWidget {
  final int companyId;
  final String companyName;
  final CatalogBranch? existing;

  const BranchFormScreen({
    super.key,
    required this.companyId,
    required this.companyName,
    this.existing,
  });

  @override
  State<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends State<BranchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _address = TextEditingController(text: widget.existing?.address ?? '');
  bool _saving = false;

  static const _brand = Color(0xFF1A68FA);

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final res = _isEdit
        ? await CatalogService.updateBranch(widget.existing!.id,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim())
        : await CatalogService.createBranch(
        companyId: widget.companyId,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim());

    if (!mounted) return;
    setState(() => _saving = false);
    showCompanySnack(context, res.message, error: !res.ok);
    if (res.ok) {
      Navigator.pop(
        context,
        res.data ??
            CatalogBranch(id: 0, companyId: widget.companyId, name: _name.text.trim()),
      );
    }
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
                icon: Icons.info_outline,
                title: 'Branch information',
                subtitle: 'Contact details for this location',
                children: [
                  PxLabel('Branch name', required: true),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    style: DT.text(
                        size: 14, weight: FontWeight.w600, color: DT.onyx900),
                    decoration: pxInputDecoration(
                      hint: 'e.g. Mumbai HQ',
                      icon: Icons.store_outlined,
                      iconColor: _brand,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Branch name is required';
                      }
                      if (v.trim().length < 2) return 'Minimum 2 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  PxLabel('Phone number', optional: true),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: DT.text(
                        size: 14, weight: FontWeight.w600, color: DT.onyx900),
                    decoration: pxInputDecoration(
                      hint: '10-digit mobile number',
                      icon: Icons.phone_outlined,
                      iconColor: _brand,
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      return RegExp(r'^[6-9]\d{9}$').hasMatch(t)
                          ? null
                          : 'Enter a valid 10-digit number';
                    },
                  ),
                  const SizedBox(height: 14),
                  PxLabel('Email', optional: true),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: DT.text(
                        size: 14, weight: FontWeight.w600, color: DT.onyx900),
                    decoration: pxInputDecoration(
                      hint: 'branch@example.com',
                      icon: Icons.mail_outline_rounded,
                      iconColor: _brand,
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(t)
                          ? null
                          : 'Invalid email';
                    },
                  ),
                  const SizedBox(height: 14),
                  PxLabel('Address', optional: true),
                  TextFormField(
                    controller: _address,
                    maxLines: 3,
                    minLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    style: DT.text(
                        size: 14, weight: FontWeight.w500, color: DT.onyx900),
                    decoration: pxInputDecoration(
                      hint: 'Street, area, city',
                      icon: Icons.location_on_outlined,
                      iconColor: _brand,
                      tinted: true,
                    ),
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
                          widget.companyName,
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
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _brand.withValues(alpha: 0.55),
                elevation: 2,
                shadowColor: const Color(0x401A68FA),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DT.rMd)),
              ),
              child: _saving
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
                    _isEdit ? 'Save changes' : 'Add branch',
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