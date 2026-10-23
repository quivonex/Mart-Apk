// lib/screens/catalog/category_screens.dart
//
// CategoryManageScreen - a company's categories (mine, active / inactive)
// CategoryFormScreen   - create / edit, optional branch. Pops with the saved CatalogCategory.
//
// When opened from the Drawer (no companyId), the form shows a Company dropdown
// at the top, so the user can pick which company the category belongs to.

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/catalog_models.dart';
import '../models/company_model.dart';
import '../services/catalog_service.dart';
import '../services/company_service.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/company_ui.dart';
import '../widgets/product_ui.dart';
import 'subcategory_screens.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kBrandDark = Color(0xFF062A50);
const _kBrandLight = Color(0xFF1E5A9C);
const _kTint = Color(0xFFEAF1F9);
const _kLine = Color(0xFFC9DBEE);
const _kRed = Color(0xFFC62828);
const _kRedBg = Color(0xFFFEF2F2);
const _kRedLine = Color(0xFFFECACA);
const _kOrange = Color(0xFFF7931E);
const _kOrangeDark = Color(0xFFC2410C);
const _kOrangeBg = Color(0xFFFFF7ED);
const _kOrangeLine = Color(0xFFFED7AA);
const _kHeader = LinearGradient(
  colors: [_kBrandDark, _kBrand, _kBrandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class CategoryManageScreen extends StatefulWidget {
  final int companyId;
  final String companyName;

  const CategoryManageScreen({super.key, required this.companyId, required this.companyName});

  @override
  State<CategoryManageScreen> createState() => _CategoryManageScreenState();
}

class _CategoryManageScreenState extends State<CategoryManageScreen> {
  List<CatalogCategory> _items = [];
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
    final r = await CatalogService.getCategoriesForManage(widget.companyId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = r.items;
      _error = r.ok ? null : r.message;
    });
  }

  Future<void> _openForm([CatalogCategory? existing]) async {
    final saved = await Navigator.push<CatalogCategory>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryFormScreen(
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

  Future<void> _openActions(CatalogCategory c) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DT.rXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(c.name, style: DT.text(size: 16, weight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: _kBrand),
              title: Text('Edit category', style: DT.text(size: 14, weight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.account_tree_outlined, color: _kBrand),
              title: Text('Subcategories', style: DT.text(size: 14, weight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'subs'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      _openForm(c);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SubCategoryManageScreen(category: c)),
      );
    }
  }

  Future<void> _toggle(CatalogCategory c) async {
    final ok = await catalogToggleActive(
      context,
      name: c.name,
      currentlyActive: c.isActive,
      call: () => CatalogService.setCategoryActive(c.id, !c.isActive),
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
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(65), // Fixed: Increased height to 65 to prevent 1px overflow
          child: CompanyTopBar(title: 'Categories', subtitle: widget.companyName),
        ),
        floatingActionButton: _items.isEmpty
            ? null
            : FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: _kBrand,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text('Add category',
              style: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
        ),
        body: CatalogManageList<CatalogCategory>(
          loading: _loading,
          error: _error,
          items: _items,
          emptyIcon: Icons.category_outlined,
          emptyTitle: 'No categories yet',
          emptyMessage: 'Categories group your products, e.g. Batteries, Inverters, Solar.',
          onRefresh: _load,
          onAdd: () => _openForm(),
          onEdit: _openActions,
          onToggleActive: _toggle,
        ),
      ),
    );
  }
}

// ===========================================================================
// Category Form (Add / Edit) — redesigned to match the app
//
// companyId is now OPTIONAL. When null (opened from the Drawer), the form
// shows a Company dropdown at the top. When provided (opened from
// CategoryManageScreen), the Company section is hidden and the given company
// is used directly — no behaviour change for existing callers.
// ===========================================================================
class CategoryFormScreen extends StatefulWidget {
  final int? companyId;
  final String? companyName;
  final CatalogCategory? existing;
  final int? presetBranchId;

  const CategoryFormScreen({
    super.key,
    this.companyId,
    this.companyName,
    this.existing,
    this.presetBranchId,
  });

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');

  // Company (only when opened from the Drawer, i.e. widget.companyId == null).
  List<Company> _companies = [];
  int? _selectedCompanyId;
  bool _loadingCompanies = false;
  String? _companiesError;

  List<CatalogBranch> _branches = [];
  CatalogBranch? _branch;
  bool _loadingBranches = true;
  String? _branchError;
  bool _saving = false;

  static const _brand = Color(0xFF093C71);

  bool get _isEdit => widget.existing != null;

  /// True when the caller already fixed the company (opened from
  /// CategoryManageScreen). In that case the Company section is hidden.
  bool get _companyLocked => widget.companyId != null;

  /// The company the form is currently working in.
  int? get _effectiveCompanyId => _companyLocked ? widget.companyId : _selectedCompanyId;

  String get _effectiveCompanyName {
    if (_companyLocked) return widget.companyName ?? '';
    if (_selectedCompanyId == null) return '';
    return _companies
        .where((c) => c.id == _selectedCompanyId)
        .map((c) => c.name)
        .firstOrNull ??
        '';
  }

  @override
  void initState() {
    super.initState();

    if (_companyLocked) {
      // Opened from CategoryManageScreen — company is fixed.
      _selectedCompanyId = widget.companyId;
      _loadBranches();
    } else if (_isEdit) {
      // Editing from the drawer — company comes from the existing record.
      _selectedCompanyId = widget.existing!.companyId;
      _loadBranches();
    }

    if (!_companyLocked) {
      _loadCompanies();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _loadingCompanies = true;
      _companiesError = null;
    });
    final res = await CompanyService.getMyCompanies();
    if (!mounted) return;
    setState(() {
      _loadingCompanies = false;
      if (res.isSuccess) {
        // Show only active companies.
        _companies = res.data.where((c) => c.isActive).toList();
        // Pre-select when editing.
        if (_isEdit && _selectedCompanyId == null) {
          _selectedCompanyId = widget.existing!.companyId;
        }
      } else {
        _companiesError = res.message ?? 'Could not load your companies';
      }
    });
  }

  Future<void> _loadBranches() async {
    final companyId = _effectiveCompanyId;
    if (companyId == null) {
      setState(() {
        _loadingBranches = false;
        _branches = [];
        _branch = null;
      });
      return;
    }

    setState(() {
      _loadingBranches = true;
      _branchError = null;
    });
    final r = await CatalogService.getBranches(companyId);
    if (!mounted) return;
    final wantId = widget.existing?.branchId ?? widget.presetBranchId;
    setState(() {
      _loadingBranches = false;
      _branches = r.items;
      _branchError = r.ok ? null : r.message;
      _branch = r.items.where((b) => b.id == wantId).firstOrNull;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final companyId = _effectiveCompanyId;
    if (companyId == null) {
      showCompanySnack(context, 'Please select a company', error: true);
      return;
    }

    setState(() => _saving = true);

    final res = _isEdit
        ? await CatalogService.updateCategory(
      widget.existing!.id,
      name: _name.text.trim(),
      description: _desc.text.trim(),
      branchId: _branch?.id,
    )
        : await CatalogService.createCategory(
      companyId: companyId,
      name: _name.text.trim(),
      description: _desc.text.trim(),
      branchId: _branch?.id,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    showCompanySnack(context, res.message, error: !res.ok);
    if (res.ok) {
      Navigator.pop(
        context,
        res.data ??
            CatalogCategory(
              id: 0,
              companyId: companyId,
              name: _name.text.trim(),
            ),
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
                icon: Icons.category_outlined,
                title: _isEdit ? 'Edit category' : 'New category',
                subtitle:
                'Categories group your products, e.g. Batteries, Inverters',
              ),

              // ── Company section: only when opened from the Drawer ──
              if (!_companyLocked) ...[
                const SizedBox(height: 16),
                _sectionCard(
                  icon: Icons.business_outlined,
                  title: 'Company',
                  subtitle: 'Category will belong to this company',
                  children: [_companyDropdown()],
                ),
              ],

              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.info_outline,
                title: 'Category information',
                subtitle: 'Name and a short description',
                children: [
                  PxLabel('Category name', required: true),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    style: DT.text(
                        size: 14, weight: FontWeight.w600, color: DT.onyx900),
                    decoration: pxInputDecoration(
                      hint: 'e.g. Batteries',
                      icon: Icons.category_outlined,
                      iconColor: _brand,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Category name is required';
                      }
                      if (v.trim().length < 2) return 'Minimum 2 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  PxLabel('Description', optional: true),
                  TextFormField(
                    controller: _desc,
                    maxLines: 3,
                    minLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    style: DT.text(
                        size: 14, weight: FontWeight.w500, color: DT.onyx900),
                    decoration: pxInputDecoration(
                      hint: 'Enter a short description (optional)',
                      icon: Icons.notes_outlined,
                      iconColor: _brand,
                      tinted: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.store_mall_directory_outlined,
                title: 'Branch',
                subtitle: 'Optional. Leave empty to use company-wide',
                children: [
                  CatalogPickerField<CatalogBranch>(
                    label: 'Assign to branch',
                    icon: Icons.store_mall_directory_outlined,
                    items: _branches,
                    selected: _branch,
                    loading: _loadingBranches,
                    error: _branchError,
                    enabled: _effectiveCompanyId != null,
                    disabledHint: 'Select a company first',
                    onRetry: _loadBranches,
                    onChanged: (b) => setState(() => _branch = b),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Leave empty to use this category for the whole company.',
                    style: DT.text(size: 11.5, color: DT.slate500),
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
          gradient: _kHeader,
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
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit category' : 'Add category',
                          style: DT.text(
                              size: 18,
                              weight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3),
                        ),
                        Text(
                          _effectiveCompanyName.isEmpty
                              ? 'Manage category details'
                              : _effectiveCompanyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(
                              size: 12,
                              weight: FontWeight.w500,
                              color: const Color(0xFFC9DBEE)),
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

  // ── Company dropdown (only shown when company is not fixed) ──
  Widget _companyDropdown() {
    if (_loadingCompanies) {
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
              child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
            ),
            SizedBox(width: 10),
            Text('Loading companies…'),
          ],
        ),
      );
    }

    if (_companiesError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kRedBg,
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: _kRedLine),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: _kRed, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _companiesError!,
                style: DT.text(size: 12, color: _kRed),
              ),
            ),
            TextButton(
              onPressed: _loadCompanies,
              child: Text('Retry',
                  style: DT.text(
                      size: 12,
                      weight: FontWeight.w700,
                      color: _kRed)),
            ),
          ],
        ),
      );
    }

    if (_companies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kOrangeBg,
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: _kOrangeLine),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _kOrange, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No companies found. Please create a company first.',
                style: DT.text(size: 12, weight: FontWeight.w600, color: _kOrangeDark),
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
      onChanged: (v) {
        setState(() {
          _selectedCompanyId = v;
          _branches = [];
          _branch = null;
        });
        _loadBranches();
      },
      validator: (v) => v == null ? 'Company is required' : null,
    );
  }

  // ── Info banner ─────────────────────────────────────────
  Widget _infoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kTint,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: _kLine),
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

  // ── Section card ────────────────────────────────────────
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
                    color: _kTint,
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

  // ── Sticky bottom bar ───────────────────────────────────
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
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _kBrand, // buttons: only #093C71
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color(0x40093C71), blurRadius: 12, offset: Offset(0, 4))],
              ),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.transparent,
                  elevation: 0,
                  shadowColor: Colors.transparent,
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
                      _isEdit ? 'Save changes' : 'Add category',
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
      ),
    );
  }
}