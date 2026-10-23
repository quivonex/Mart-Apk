import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/company_model.dart';
import '../models/subcategory_model.dart';
import '../services/catalog_service.dart';
import '../services/company_service.dart';
import '../services/subcategory_service.dart';
import '../widgets/product_ui.dart';
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
const _kHeader = LinearGradient(
  colors: [_kBrandDark, _kBrand, _kBrandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class SubCategoryCreateEditScreen extends StatefulWidget {
  final SubCategory? existing;

  const SubCategoryCreateEditScreen({super.key, this.existing});

  @override
  State<SubCategoryCreateEditScreen> createState() =>
      _SubCategoryCreateEditScreenState();
}

class _SubCategoryCreateEditScreenState
    extends State<SubCategoryCreateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Company (dropdown at top)
  List<Company> _companies = [];
  int? _selectedCompanyId;
  bool _isLoadingCompanies = true;
  String? _companiesError;

  // Categories for the selected company
  List<CategoryName> _categories = [];
  int? _selectedCategoryId;
  bool _isLoadingCategories = false;
  String? _categoriesError;

  bool _isSubmitting = false;

  static const _brand = Color(0xFF093C71);

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.existing!.name;
      _descCtrl.text = widget.existing!.description;
      _selectedCategoryId = widget.existing!.effectiveCategoryId;
    }
    _loadCompanies();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Load companies ────────────────────────────────────
  Future<void> _loadCompanies() async {
    setState(() {
      _isLoadingCompanies = true;
      _companiesError = null;
    });
    final res = await CompanyService.getMyCompanies();
    if (!mounted) return;
    setState(() {
      _isLoadingCompanies = false;
      if (res.isSuccess) {
        _companies = res.data.where((c) => c.isActive).toList();

        // If editing, try to figure out the company from the current category.
        // If we already have a selected category, we can't easily reverse-map
        // it to a company here — so we just show all companies and let the
        // user confirm. If only one company exists, auto-select it.
        if (_companies.length == 1 && _selectedCompanyId == null) {
          _selectedCompanyId = _companies.first.id;
          _loadCategories(_companies.first.id);
        }
      } else {
        _companiesError = res.message ?? 'Could not load your companies';
      }
    });
  }

  // ── Load categories for a company ─────────────────────
  Future<void> _loadCategories(int companyId) async {
    setState(() {
      _isLoadingCategories = true;
      _categoriesError = null;
      _categories = [];
    });

    // Prefer CatalogService.getCategories(companyId) — returns categories
    // that belong to this company only.
    final r = await CatalogService.getCategories(companyId);
    if (!mounted) return;

    if (r.ok) {
      setState(() {
        _isLoadingCategories = false;
        _categories = r.items
            .map((c) => CategoryName(id: c.id, name: c.name))
            .toList();
      });
    } else {
      // Fallback: use SubCategoryService.getCategoryNames() if catalog fails.
      final fallback = await SubCategoryService.getCategoryNames();
      if (!mounted) return;
      setState(() {
        _isLoadingCategories = false;
        if (fallback.isSuccess) {
          _categories = fallback.data;
        } else {
          _categoriesError = r.message ?? 'Could not load categories';
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCompanyId == null) {
      _snack('Please select a company', isError: true);
      return;
    }
    if (_selectedCategoryId == null) {
      _snack('Please select a category', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    SubCategoryActionResponse res;

    if (_isEdit) {
      res = await SubCategoryService.updateSubCategory(
        id: widget.existing!.id,
        category: _selectedCategoryId!,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );
    } else {
      res = await SubCategoryService.createSubCategory(
        category: _selectedCategoryId!,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
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
          backgroundColor: isError ? _kRed : const Color(0xFF10B981),
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
                icon: Icons.account_tree_outlined,
                title: _isEdit ? 'Edit subcategory' : 'New subcategory',
                subtitle:
                'Subcategories live inside a category, e.g. Car Batteries',
              ),
              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.business_outlined,
                title: 'Company',
                subtitle: 'Subcategory will belong to a category of this company',
                children: [_companyDropdown()],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.folder_outlined,
                title: 'Parent category',
                subtitle: 'Which category does it belong to?',
                children: [_categoryDropdown()],
              ),
              const SizedBox(height: 16),
              _sectionCard(
                icon: Icons.info_outline,
                title: 'Subcategory information',
                subtitle: 'Name and a short description',
                children: [
                  PxLabel('Subcategory name', required: true),
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: DT.text(
                        size: 14, weight: FontWeight.w600, color: DT.onyx900),
                    decoration: pxInputDecoration(
                      hint: 'e.g. Mobile Phones',
                      icon: Icons.category_outlined,
                      iconColor: _brand,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Name is required';
                      }
                      if (v.trim().length < 2) return 'Minimum 2 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  PxLabel('Description', optional: true),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 4,
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  PreferredSizeWidget _appBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(65),
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
            height: 65,
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
                          _isEdit ? 'Edit subcategory' : 'Add subcategory',
                          style: DT.text(
                              size: 18,
                              weight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3),
                        ),
                        Text(
                          'Group products inside a category',
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

  // ── Company dropdown ──────────────────────────────────
  Widget _companyDropdown() {
    if (_isLoadingCompanies) {
      return _loadingBox('Loading companies…');
    }
    if (_companiesError != null) {
      return _errorBox(_companiesError!, onRetry: _loadCompanies);
    }
    if (_companies.isEmpty) {
      return _errorBox('No companies found. Please create a company first.');
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
          _selectedCategoryId = null;
          _categories = [];
        });
        if (v != null) _loadCategories(v);
      },
      validator: (v) => v == null ? 'Company is required' : null,
    );
  }

  // ── Category dropdown (depends on company) ────────────
  Widget _categoryDropdown() {
    if (_selectedCompanyId == null) {
      return _hintBox('Select a company first');
    }
    if (_isLoadingCategories) {
      return _loadingBox('Loading categories…');
    }
    if (_categoriesError != null) {
      return _errorBox(_categoriesError!,
          onRetry: () => _loadCategories(_selectedCompanyId!));
    }
    if (_categories.isEmpty) {
      return _errorBox(
          'No categories found for this company. Please create a category first.');
    }

    return DropdownButtonFormField<int>(
      value: _selectedCategoryId,
      isExpanded: true,
      icon: const Icon(Icons.expand_more, color: DT.slate500),
      style: DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
      decoration: pxInputDecoration(
        hint: 'Select category',
        icon: Icons.folder_outlined,
        iconColor: _brand,
      ),
      hint: Text('Select category',
          style: DT.text(size: 13.5, color: DT.slate400)),
      items: _categories.map((c) {
        return DropdownMenuItem<int>(
          value: c.id,
          child: Text(c.name,
              overflow: TextOverflow.ellipsis,
              style: DT.text(
                  size: 14, weight: FontWeight.w600, color: DT.onyx900)),
        );
      }).toList(),
      onChanged: (v) => setState(() => _selectedCategoryId = v),
      validator: (v) => v == null ? 'Category is required' : null,
    );
  }

  // ── Small helpers ─────────────────────────────────────
  Widget _loadingBox(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DT.slate50,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.slate200),
      ),
      child: Row(
        children: [
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
          ),
          const SizedBox(width: 10),
          Text(text, style: DT.text(size: 12, color: DT.slate500)),
        ],
      ),
    );
  }

  Widget _errorBox(String text, {VoidCallback? onRetry}) {
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
            child: Text(text, style: DT.text(size: 12, color: _kRed)),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
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

  Widget _hintBox(String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DT.slate50,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.slate200),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: DT.slate400, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: DT.text(size: 12, color: DT.slate500)),
          ),
        ],
      ),
    );
  }

  // ── Info card ─────────────────────────────────────────
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

  // ── Section card ──────────────────────────────────────
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

  // ── Bottom bar ────────────────────────────────────────
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
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.transparent,
                  elevation: 0,
                  shadowColor: Colors.transparent,
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
                      _isEdit
                          ? 'Update subcategory'
                          : 'Create subcategory',
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