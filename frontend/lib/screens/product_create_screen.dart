// lib/screens/catalog/product_create_screen.dart
//
// Product create form  ->  POST /product/api/products/create/  (multipart)
//
// Catalog pickers, each with "+ Add new" (auto-selects the new item) and "Manage":
//   Company (paid)  ->  Branch (optional)  ->  Category  ->  Subcategory  ->  Brand (optional)
//   Unit
//
// Backend rules handled here:
//   * weight / length / width / height are REQUIRED and are parsed by Shiprocket
//     helpers that need a number + unit ("1.5 kg", "20 cm").
//   * final_price is computed by the server; a flat discount must be < price.
//   * variant "sku" is UNIQUE in the DB, so an empty SKU is never sent (auto-generated).
//   * status / slug / product_code are set by the server, never sent.
//   * New products start as "pending" until an admin approves them.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/design_tokens.dart';
import '../../models/catalog_models.dart';
import '../../models/company_model.dart';
import '../../services/catalog_service.dart';
import '../../services/company_service.dart';
import '../../widgets/catalog_widgets.dart';
import '../../widgets/company_ui.dart';
import 'branch_screens.dart';
import 'category_screens.dart';
import 'subcategory_screens.dart';
import 'unit_screens.dart';

class ProductCreateScreen extends StatefulWidget {
  /// Preselect this company (e.g. when opened from a company's product list).
  final int? companyId;

  const ProductCreateScreen({super.key, this.companyId});

  @override
  State<ProductCreateScreen> createState() => _ProductCreateScreenState();
}

// Company wrapper so it can use the same picker.
class _CompanyOption implements CatalogOption {
  final Company company;
  _CompanyOption(this.company);
  @override
  int get id => company.id;
  @override
  String get label => company.name;
  @override
  String get sublabel => company.isPaid ? '' : 'Registration fee pending';
  @override
  bool get isActive => company.isActive;
}

class _SpecRow {
  final key = TextEditingController();
  final value = TextEditingController();
  void dispose() {
    key.dispose();
    value.dispose();
  }
}

class _Variant {
  Map<String, String> attributes;
  double price;
  int stock;
  String sku;
  XFile? image;
  Uint8List? imageBytes;

  _Variant({
    required this.attributes,
    required this.price,
    required this.stock,
    required this.sku,
    this.image,
    this.imageBytes,
  });

  String get title => attributes.entries.map((e) => '${e.key}: ${e.value}').join(' · ');
}

class _ProductCreateScreenState extends State<ProductCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  static const _maxImages = 8;
  static const _maxImageBytes = 5 * 1024 * 1024;

  // ── Catalog ─────────────────────────────────────────────
  List<_CompanyOption> _companies = [];
  _CompanyOption? _company;
  bool _loadingCompanies = true;
  String? _companiesError;

  List<CatalogBranch> _branches = [];
  CatalogBranch? _branch;
  bool _loadingBranches = false;
  String? _branchesError;

  List<CatalogCategory> _categories = [];
  CatalogCategory? _category;
  bool _loadingCategories = false;
  String? _categoriesError;

  List<CatalogSubCategory> _subcategories = [];
  CatalogSubCategory? _subcategory;
  bool _loadingSubcategories = false;
  String? _subcategoriesError;

  List<CatalogBrand> _brands = [];
  CatalogBrand? _brand;
  bool _loadingBrands = false;
  String? _brandsError;

  List<CatalogUnit> _units = [];
  CatalogUnit? _unit;
  bool _loadingUnits = true;
  String? _unitsError;

  // ── Fields ──────────────────────────────────────────────
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _discountValue = TextEditingController();
  final _hsn = TextEditingController();
  final _stock = TextEditingController();
  final _weight = TextEditingController();
  final _length = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  final _bestBefore = TextEditingController();

  String _discountType = 'none'; // none | flat | percent
  double? _gst;
  String _weightUnit = 'kg';
  String _dimUnit = 'cm';
  DateTime? _mfgDate;
  DateTime? _expDate;
  bool _franchise = false;

  XFile? _thumb;
  Uint8List? _thumbBytes;
  final List<XFile> _images = [];
  final List<Uint8List> _imageBytes = [];

  final List<_SpecRow> _specs = [];
  final List<_Variant> _variants = [];

  bool _submitAttempted = false;
  bool _saving = false;

  // =====================================================================
  // LIFECYCLE
  // =====================================================================
  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _loadUnits();
    _price.addListener(_refresh);
    _discountValue.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in [
      _name, _description, _price, _discountValue, _hsn, _stock,
      _weight, _length, _width, _height, _bestBefore,
    ]) {
      c.dispose();
    }
    for (final s in _specs) {
      s.dispose();
    }
    super.dispose();
  }

  bool get _dirty =>
      _name.text.isNotEmpty || _price.text.isNotEmpty || _thumb != null || _images.isNotEmpty;

  // =====================================================================
  // LOADERS (cascade)
  // =====================================================================
  Future<void> _loadCompanies() async {
    setState(() {
      _loadingCompanies = true;
      _companiesError = null;
    });
    final r = await CompanyService.getMyCompanies();
    if (!mounted) return;
    final list = r.data.where((c) => c.isActive).map(_CompanyOption.new).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    setState(() {
      _loadingCompanies = false;
      _companies = list;
      _companiesError = r.isSuccess
          ? (list.isEmpty ? 'Create a company first.' : null)
          : (r.message ?? 'Could not load companies');
    });

    _CompanyOption? pick;
    if (widget.companyId != null) {
      pick = list.where((c) => c.id == widget.companyId).firstOrNull;
    }
    pick ??= list.where((c) => c.company.isPaid).length == 1
        ? list.firstWhere((c) => c.company.isPaid)
        : null;
    if (pick != null) _onCompany(pick);
  }

  Future<void> _loadUnits({int? selectId}) async {
    setState(() {
      _loadingUnits = true;
      _unitsError = null;
    });
    final r = await CatalogService.getUnits();
    if (!mounted) return;
    setState(() {
      _loadingUnits = false;
      _units = r.items;
      _unitsError = r.ok ? null : r.message;
      _unit = _keep(r.items, selectId ?? _unit?.id);
    });
  }

  Future<void> _loadBranches({int? selectId, String? selectName}) async {
    final company = _company;
    if (company == null) return;
    setState(() {
      _loadingBranches = true;
      _branchesError = null;
    });
    final r = await CatalogService.getBranches(company.id);
    if (!mounted || _company?.id != company.id) return;
    setState(() {
      _loadingBranches = false;
      _branches = r.items;
      _branchesError = r.ok ? null : r.message;
      _branch = _keep(r.items, selectId ?? _branch?.id, name: selectName);
    });
  }

  Future<void> _loadCategories({int? selectId, String? selectName}) async {
    final company = _company;
    if (company == null) return;
    setState(() {
      _loadingCategories = true;
      _categoriesError = null;
    });
    final r = await CatalogService.getCategories(company.id);
    if (!mounted || _company?.id != company.id) return;
    final before = _category?.id;
    setState(() {
      _loadingCategories = false;
      _categories = r.items;
      _categoriesError = r.ok ? null : r.message;
      _category = _keep(r.items, selectId ?? _category?.id, name: selectName);
    });
    if (_category?.id != before) _onCategoryChanged();
  }

  Future<void> _loadSubcategories({int? selectId, String? selectName}) async {
    final category = _category;
    if (category == null) return;
    setState(() {
      _loadingSubcategories = true;
      _subcategoriesError = null;
    });
    final r = await CatalogService.getSubCategories(category.id);
    if (!mounted || _category?.id != category.id) return;
    final before = _subcategory?.id;
    setState(() {
      _loadingSubcategories = false;
      _subcategories = r.items;
      _subcategoriesError = r.ok ? null : r.message;
      _subcategory = _keep(r.items, selectId ?? _subcategory?.id, name: selectName);
    });
    if (_subcategory?.id != before) _onSubcategoryChanged();
  }

  Future<void> _loadBrands() async {
    final sub = _subcategory;
    if (sub == null) return;
    setState(() {
      _loadingBrands = true;
      _brandsError = null;
    });
    final r = await CatalogService.getBrands(sub.id);
    if (!mounted || _subcategory?.id != sub.id) return;
    setState(() {
      _loadingBrands = false;
      _brands = r.items;
      _brandsError = r.ok ? null : r.message;
      _brand = _keep(r.items, _brand?.id);
    });
  }

  /// Keep/choose a selection after a list reload (by id, else by name).
  T? _keep<T extends CatalogOption>(List<T> items, int? id, {String? name}) {
    if (id != null && id != 0) {
      final hit = items.where((e) => e.id == id).firstOrNull;
      if (hit != null) return hit;
    }
    if (name != null && name.isNotEmpty) {
      final n = name.trim().toLowerCase();
      final hits = items.where((e) => e.label.trim().toLowerCase() == n).toList()
        ..sort((a, b) => b.id.compareTo(a.id)); // newest first
      if (hits.isNotEmpty) return hits.first;
    }
    return null;
  }

  // ── selection handlers ──────────────────────────────────
  void _onCompany(_CompanyOption? c) {
    if (c?.id == _company?.id) return;
    setState(() {
      _company = c;
      _branch = null;
      _branches = [];
      _category = null;
      _categories = [];
      _subcategory = null;
      _subcategories = [];
      _brand = null;
      _brands = [];
    });
    if (c != null) {
      _loadBranches();
      _loadCategories();
    }
  }

  void _onCategoryChanged() {
    setState(() {
      _subcategory = null;
      _subcategories = [];
      _brand = null;
      _brands = [];
    });
    if (_category != null) _loadSubcategories();
  }

  void _onSubcategoryChanged() {
    setState(() {
      _brand = null;
      _brands = [];
    });
    if (_subcategory != null) _loadBrands();
  }

  /// Categories for the chosen branch: company-wide ones + that branch's ones.
  List<CatalogCategory> get _visibleCategories {
    final b = _branch;
    if (b == null) return _categories;
    return _categories.where((c) => c.branchId == null || c.branchId == b.id).toList();
  }

  // ── Add new / Manage ─────────────────────────────────────
  Future<T?> _push<T>(Widget page) =>
      Navigator.push<T>(context, MaterialPageRoute(builder: (_) => page));

  Future<void> _addBranch() async {
    final c = _company!;
    final saved = await _push<CatalogBranch>(
        BranchFormScreen(companyId: c.id, companyName: c.label));
    if (saved != null) await _loadBranches(selectId: saved.id, selectName: saved.name);
  }

  Future<void> _manageBranches() async {
    final c = _company!;
    final changed = await _push<bool>(BranchManageScreen(companyId: c.id, companyName: c.label));
    if (changed == true) _loadBranches();
  }

  Future<void> _addCategory() async {
    final c = _company!;
    final saved = await _push<CatalogCategory>(CategoryFormScreen(
        companyId: c.id, companyName: c.label, presetBranchId: _branch?.id));
    if (saved != null) await _loadCategories(selectId: saved.id, selectName: saved.name);
  }

  Future<void> _manageCategories() async {
    final c = _company!;
    final changed =
    await _push<bool>(CategoryManageScreen(companyId: c.id, companyName: c.label));
    if (changed == true) _loadCategories();
  }

  Future<void> _addSubcategory() async {
    final cat = _category!;
    final saved = await _push<CatalogSubCategory>(SubCategoryFormScreen(category: cat));
    if (saved != null) await _loadSubcategories(selectId: saved.id, selectName: saved.name);
  }

  Future<void> _manageSubcategories() async {
    final changed = await _push<bool>(SubCategoryManageScreen(category: _category!));
    if (changed == true) _loadSubcategories();
  }

  Future<void> _addUnit() async {
    final saved = await _push<CatalogUnit>(const UnitFormScreen());
    if (saved != null) {
      await _loadUnits(selectId: saved.id);
      if (_unit == null && mounted) {
        setState(() => _unit = _keep(_units, null, name: saved.label));
      }
    }
  }

  Future<void> _manageUnits() async {
    final changed = await _push<bool>(const UnitManageScreen());
    if (changed == true) _loadUnits();
  }

  // =====================================================================
  // MEDIA
  // =====================================================================
  Future<void> _pickThumb() async {
    try {
      final x = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (bytes.lengthInBytes > _maxImageBytes) {
        showCompanySnack(context, 'Image must be under 5MB', error: true);
        return;
      }
      if (!mounted) return;
      setState(() {
        _thumb = x;
        _thumbBytes = bytes;
      });
    } catch (e) {
      if (mounted) showCompanySnack(context, 'Could not pick image: $e', error: true);
    }
  }

  Future<void> _pickImages() async {
    final room = _maxImages - _images.length;
    if (room <= 0) return;
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1600);
      var skipped = 0;
      final files = <XFile>[];
      final bytes = <Uint8List>[];
      for (final x in picked.take(room)) {
        final b = await x.readAsBytes();
        if (b.lengthInBytes > _maxImageBytes) {
          skipped++;
          continue;
        }
        files.add(x);
        bytes.add(b);
      }
      if (!mounted) return;
      setState(() {
        _images.addAll(files);
        _imageBytes.addAll(bytes);
      });
      if (skipped > 0) {
        showCompanySnack(context, '$skipped photo(s) skipped (over 5MB)', error: true);
      } else if (picked.length > room) {
        showCompanySnack(context, 'Only $room more photo(s) added (max $_maxImages)');
      }
    } catch (e) {
      if (mounted) showCompanySnack(context, 'Could not pick photos: $e', error: true);
    }
  }

  // =====================================================================
  // PRICE HELPERS
  // =====================================================================
  double? get _priceValue => double.tryParse(_price.text.trim());
  double? get _discount => double.tryParse(_discountValue.text.trim());

  double? get _finalPrice {
    final p = _priceValue;
    if (p == null) return null;
    final d = _discount ?? 0;
    return switch (_discountType) {
      'flat' => p - d,
      'percent' => p - (p * d / 100),
      _ => p,
    };
  }

  String _money(double v) =>
      v == v.roundToDouble() ? '₹${v.toStringAsFixed(0)}' : '₹${v.toStringAsFixed(2)}';

  String _num(String s) {
    final d = double.tryParse(s.trim());
    if (d == null) return s.trim();
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _autoSku([Map<String, String> attrs = const {}]) {
    String clean(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final words = _name.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    var base = words.map((w) => clean(w)).where((w) => w.isNotEmpty).map((w) {
      return w.length > 3 ? w.substring(0, 3) : w;
    }).take(3).join();
    if (base.isEmpty) base = 'PRD';
    final attrPart = attrs.values.map(clean).where((v) => v.isNotEmpty).join('-');
    final rnd = Random().nextInt(9000) + 1000;
    final sku = [base, if (attrPart.isNotEmpty) attrPart, '$rnd'].join('-');
    return sku.length > 90 ? sku.substring(0, 90) : sku;
  }

  // =====================================================================
  // SUBMIT
  // =====================================================================
  String? _validateExtras() {
    final c = _company;
    if (c == null) return 'Select a company';
    if (!c.company.isPaid) return 'Pay the registration fee for ${c.label} before adding products';
    if (_category == null) return 'Select a category';
    if (_subcategory == null) return 'Select a subcategory';
    if (_unit == null) return 'Select a unit';
    if (_thumb == null) return 'Add a main product photo';
    if (_mfgDate != null && _expDate != null && !_expDate!.isAfter(_mfgDate!)) {
      return 'Expiry date must be after the manufacturing date';
    }
    for (final s in _specs) {
      if (s.key.text.trim().isEmpty != s.value.text.trim().isEmpty) {
        return 'Fill both name and value for each specification, or remove the row';
      }
    }
    return null;
  }

  Map<String, String> _buildFields() {
    final specs = <String, String>{
      for (final s in _specs)
        if (s.key.text.trim().isNotEmpty) s.key.text.trim(): s.value.text.trim(),
    };

    final variants = [
      for (final v in _variants)
        {
          'attributes': v.attributes,
          'price': v.price,
          'stock_quantity': v.stock,
          'sku': v.sku.trim().isEmpty ? _autoSku(v.attributes) : v.sku.trim(),
        }
    ];

    final f = <String, String>{
      'company': _company!.id.toString(),
      'category': _category!.id.toString(),
      'subcategory': _subcategory!.id.toString(),
      'unit': _unit!.id.toString(),
      if (_branch != null) 'branch': _branch!.id.toString(),
      if (_brand != null) 'brand': _brand!.id.toString(),
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'price': _num(_price.text),
      'stock_quantity': (int.tryParse(_stock.text.trim()) ?? 0).toString(),
      'weight': '${_num(_weight.text)} $_weightUnit',
      'length': '${_num(_length.text)} $_dimUnit',
      'width': '${_num(_width.text)} $_dimUnit',
      'height': '${_num(_height.text)} $_dimUnit',
      if (_discountType != 'none' && (_discount ?? 0) > 0) ...{
        'discount_type': _discountType,
        'discount_value': _num(_discountValue.text),
      },
      if (_gst != null) 'GST_percent': _gst!.toStringAsFixed(2),
      if (_hsn.text.trim().isNotEmpty) 'HSN_code': _hsn.text.trim(),
      if (_mfgDate != null) 'manufacturing_date': _date(_mfgDate!),
      if (_expDate != null) 'expiry_date': _date(_expDate!),
      if (_bestBefore.text.trim().isNotEmpty) 'best_before_duration': _bestBefore.text.trim(),
      if (specs.isNotEmpty) 'specifications': jsonEncode(specs),
      'is_franchise_available': _franchise.toString(),
      'variants': jsonEncode(variants),
    };
    f.removeWhere((k, v) => k == 'description' && v.isEmpty);
    return f;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _submitAttempted = true);
    final formOk = _formKey.currentState!.validate();
    final extra = _validateExtras();
    if (!formOk || extra != null) {
      showCompanySnack(context, extra ?? 'Please fix the highlighted fields', error: true);
      return;
    }

    setState(() => _saving = true);
    final res = await CatalogService.createProduct(
      fields: _buildFields(),
      thumbnail: _thumb!,
      images: _images,
      variantImages: {
        for (var i = 0; i < _variants.length; i++)
          if (_variants[i].image != null) 'variant_image_$i': _variants[i].image!,
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (!res.ok) {
      showCompanySnack(context, res.message, error: true);
      return;
    }

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rLg)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: DT.emerald50, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: DT.emerald700, size: 32),
        ),
        title: Text('Product submitted',
            textAlign: TextAlign.center, style: DT.text(size: 18, weight: FontWeight.w800)),
        content: Text(
          '${_name.text.trim()} was added and is waiting for admin approval. '
              'It will be visible to buyers once approved.',
          textAlign: TextAlign.center,
          style: DT.text(size: 13, color: DT.onyx600, height: 1.5),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: DT.blue800,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
              ),
              child: Text('Done',
                  style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  // =====================================================================
  // BUILD
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _saving) return;
        final leave = await confirmAction(
          context,
          title: 'Discard this product?',
          message: 'The details you entered will be lost.',
          confirmLabel: 'Discard',
          destructive: true,
        );
        if (leave && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: DT.background,
        appBar: CompanyTopBar(
          title: 'Add product',
          subtitle: _company?.label ?? 'New product',
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                _catalogSection(),
                const SizedBox(height: 12),
                _detailsSection(),
                const SizedBox(height: 12),
                _priceSection(),
                const SizedBox(height: 12),
                _stockSection(),
                const SizedBox(height: 12),
                _photosSection(),
                const SizedBox(height: 12),
                _specsSection(),
                const SizedBox(height: 12),
                _variantsSection(),
                const SizedBox(height: 12),
                _moreSection(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _bottomBar(),
      ),
    );
  }

  // ── 1. Catalog ──────────────────────────────────────────
  Widget _catalogSection() {
    final c = _company;
    return SectionCard(
      title: 'Company & catalog',
      child: Column(
        children: [
          CatalogPickerField<_CompanyOption>(
            label: 'Company',
            icon: Icons.business_outlined,
            required: true,
            items: _companies,
            selected: _company,
            loading: _loadingCompanies,
            error: _companiesError,
            onRetry: _loadCompanies,
            showRequiredError: _submitAttempted,
            onChanged: _onCompany,
          ),
          if (c != null && !c.company.isPaid) ...[
            const SizedBox(height: 8),
            _notice(Icons.payments_outlined,
                'Registration fee is pending for ${c.label}. Pay it from My Companies to add products.',
                warn: true),
          ],
          const SizedBox(height: 14),
          CatalogPickerField<CatalogBranch>(
            label: 'Branch',
            icon: Icons.store_mall_directory_outlined,
            items: _branches,
            selected: _branch,
            loading: _loadingBranches,
            error: _branchesError,
            enabled: c != null,
            disabledHint: 'Select a company first',
            onRetry: _loadBranches,
            onChanged: (b) {
              setState(() => _branch = b);
              final cat = _category;
              if (cat != null && b != null && cat.branchId != null && cat.branchId != b.id) {
                setState(() => _category = null);
                _onCategoryChanged();
              }
            },
            onAddNew: c == null ? null : _addBranch,
            onManage: c == null ? null : _manageBranches,
          ),
          const SizedBox(height: 14),
          CatalogPickerField<CatalogCategory>(
            label: 'Category',
            icon: Icons.category_outlined,
            required: true,
            items: _visibleCategories,
            selected: _category,
            loading: _loadingCategories,
            error: _categoriesError,
            enabled: c != null,
            disabledHint: 'Select a company first',
            showRequiredError: _submitAttempted,
            onRetry: _loadCategories,
            onChanged: (v) {
              setState(() => _category = v);
              _onCategoryChanged();
            },
            onAddNew: c == null ? null : _addCategory,
            onManage: c == null ? null : _manageCategories,
          ),
          const SizedBox(height: 14),
          CatalogPickerField<CatalogSubCategory>(
            label: 'Subcategory',
            icon: Icons.account_tree_outlined,
            required: true,
            items: _subcategories,
            selected: _subcategory,
            loading: _loadingSubcategories,
            error: _subcategoriesError,
            enabled: _category != null,
            disabledHint: 'Select a category first',
            showRequiredError: _submitAttempted,
            onRetry: _loadSubcategories,
            onChanged: (v) {
              setState(() => _subcategory = v);
              _onSubcategoryChanged();
            },
            onAddNew: _category == null ? null : _addSubcategory,
            onManage: _category == null ? null : _manageSubcategories,
          ),
          const SizedBox(height: 14),
          CatalogPickerField<CatalogBrand>(
            label: 'Brand',
            icon: Icons.verified_outlined,
            items: _brands,
            selected: _brand,
            loading: _loadingBrands,
            error: _brandsError,
            enabled: _subcategory != null,
            disabledHint: 'Select a subcategory first',
            onRetry: _loadBrands,
            onChanged: (v) => setState(() => _brand = v),
          ),
          const SizedBox(height: 14),
          CatalogPickerField<CatalogUnit>(
            label: 'Unit',
            icon: Icons.straighten_rounded,
            required: true,
            items: _units,
            selected: _unit,
            loading: _loadingUnits,
            error: _unitsError,
            showRequiredError: _submitAttempted,
            onRetry: _loadUnits,
            onChanged: (v) => setState(() => _unit = v),
            onAddNew: _addUnit,
            onManage: _manageUnits,
          ),
        ],
      ),
    );
  }

  // ── 2. Details ──────────────────────────────────────────
  Widget _detailsSection() {
    return SectionCard(
      title: 'Product details',
      child: Column(
        children: [
          CatalogTextField(
            controller: _name,
            label: 'Product name *',
            hint: 'e.g. Exide 150Ah Inverter Battery',
            icon: Icons.inventory_2_outlined,
            capitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(200)],
            validator: (v) => (v ?? '').trim().length < 3 ? 'Enter the product name' : null,
          ),
          const SizedBox(height: 12),
          CatalogTextField(
            controller: _description,
            label: 'Description',
            hint: 'What it is, key features, what is in the box',
            maxLines: 5,
            capitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  // ── 3. Price & tax ──────────────────────────────────────
  Widget _priceSection() {
    final fp = _finalPrice;
    final p = _priceValue;
    return SectionCard(
      title: 'Price & tax',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CatalogTextField(
            controller: _price,
            label: 'Price (MRP) *',
            icon: Icons.currency_rupee_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalInputFormatter()],
            validator: (v) {
              final d = double.tryParse((v ?? '').trim());
              if (d == null || d <= 0) return 'Enter a price greater than 0';
              return null;
            },
          ),
          const SizedBox(height: 12),
          Text('Discount', style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx600)),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'none', label: Text('None')),
              ButtonSegment(value: 'flat', label: Text('Flat ₹')),
              ButtonSegment(value: 'percent', label: Text('Percent %')),
            ],
            selected: {_discountType},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _discountType = s.first;
              if (_discountType == 'none') _discountValue.clear();
            }),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: DT.blue800,
              selectedForegroundColor: Colors.white,
              textStyle: DT.text(size: 12.5, weight: FontWeight.w700),
            ),
          ),
          if (_discountType != 'none') ...[
            const SizedBox(height: 12),
            CatalogTextField(
              controller: _discountValue,
              label: _discountType == 'flat' ? 'Discount amount (₹) *' : 'Discount (%) *',
              icon: Icons.local_offer_outlined,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [DecimalInputFormatter()],
              validator: (v) {
                final d = double.tryParse((v ?? '').trim());
                if (d == null || d <= 0) return 'Enter the discount';
                if (_discountType == 'percent' && d >= 100) return 'Must be less than 100%';
                if (_discountType == 'flat' && p != null && d >= p) {
                  return 'Must be less than the price';
                }
                return null;
              },
            ),
          ],
          if (fp != null && p != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: DT.emerald50,
                borderRadius: BorderRadius.circular(DT.rMd),
                border: Border.all(color: DT.emerald200),
              ),
              child: Row(
                children: [
                  Text('Selling price',
                      style: DT.text(size: 12.5, weight: FontWeight.w600, color: DT.emerald700)),
                  const Spacer(),
                  if (fp < p) ...[
                    Text(_money(p),
                        style: DT.text(
                            size: 12.5,
                            color: DT.slate500,
                            decoration: TextDecoration.lineThrough)),
                    const SizedBox(width: 8),
                  ],
                  Text(fp <= 0 ? 'Invalid' : _money(fp),
                      style: DT.text(
                          size: 17,
                          weight: FontWeight.w800,
                          color: fp <= 0 ? DT.error : DT.emerald700)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('GST', style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx600)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in const [0.0, 5.0, 12.0, 18.0, 28.0])
                ChoiceChip(
                  label: Text('${g.toStringAsFixed(0)}%'),
                  selected: _gst == g,
                  onSelected: (sel) => setState(() => _gst = sel ? g : null),
                  selectedColor: DT.blue800,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: _gst == g ? DT.blue800 : DT.border),
                  labelStyle: DT.text(
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: _gst == g ? Colors.white : DT.onyx700),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 12),
          CatalogTextField(
            controller: _hsn,
            label: 'HSN code',
            hint: '4–8 digits',
            icon: Icons.qr_code_2_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return null;
              return t.length < 4 ? 'HSN is 4 to 8 digits' : null;
            },
          ),
        ],
      ),
    );
  }

  // ── 4. Stock & shipping ─────────────────────────────────
  Widget _stockSection() {
    String? positive(String? v, String what) {
      final d = double.tryParse((v ?? '').trim());
      return (d == null || d <= 0) ? 'Enter $what' : null;
    }

    return SectionCard(
      title: 'Stock & shipping',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CatalogTextField(
            controller: _stock,
            label: 'Stock quantity *',
            icon: Icons.inventory_outlined,
            keyboardType: TextInputType.number,
            suffixText: _unit?.shortName,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7),
            ],
            validator: (v) =>
            int.tryParse((v ?? '').trim()) == null ? 'Enter the stock quantity' : null,
          ),
          const SizedBox(height: 14),
          Text('Packed weight & size (used for shipping charges)',
              style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx600)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CatalogTextField(
                  controller: _weight,
                  label: 'Weight *',
                  icon: Icons.scale_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter(decimals: 3)],
                  validator: (v) => positive(v, 'weight'),
                ),
              ),
              const SizedBox(width: 8),
              _unitToggle(['kg', 'g'], _weightUnit, (v) => setState(() => _weightUnit = v)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CatalogTextField(
                  controller: _length,
                  label: 'Length *',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter()],
                  validator: (v) => positive(v, 'length'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CatalogTextField(
                  controller: _width,
                  label: 'Width *',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter()],
                  validator: (v) => positive(v, 'width'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CatalogTextField(
                  controller: _height,
                  label: 'Height *',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [DecimalInputFormatter()],
                  validator: (v) => positive(v, 'height'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _unitToggle(['cm', 'mm'], _dimUnit, (v) => setState(() => _dimUnit = v)),
          ),
        ],
      ),
    );
  }

  Widget _unitToggle(List<String> options, String value, ValueChanged<String> onChanged) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: DT.slate100,
        borderRadius: BorderRadius.circular(DT.rMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onChanged(o),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: value == o ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(DT.rSm),
                  boxShadow: value == o
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
                      : null,
                ),
                child: Text(o,
                    style: DT.text(
                        size: 13,
                        weight: FontWeight.w700,
                        color: value == o ? DT.blue800 : DT.slate500)),
              ),
            ),
        ],
      ),
    );
  }

  // ── 5. Photos ───────────────────────────────────────────
  Widget _photosSection() {
    final thumbMissing = _submitAttempted && _thumb == null;
    return SectionCard(
      title: 'Photos',
      trailing: Text('${_images.length + (_thumb == null ? 0 : 1)}/${_maxImages + 1}',
          style: DT.text(size: 11.5, color: DT.slate400)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickThumb,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: DT.slate50,
                    borderRadius: BorderRadius.circular(DT.rMd),
                    border: Border.all(
                        color: thumbMissing ? DT.error : DT.blue200, width: 1.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _thumbBytes != null
                      ? Image.memory(_thumbBytes!, fit: BoxFit.cover)
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo_outlined, color: DT.blue800),
                      const SizedBox(height: 6),
                      Text('Main photo *',
                          style: DT.text(
                              size: 11.5, weight: FontWeight.w700, color: DT.blue800)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'The main photo is shown in lists and search. Use a clear photo on a plain '
                      'background. JPG/PNG up to 5MB.',
                  style: DT.text(size: 12, color: DT.slate500, height: 1.45),
                ),
              ),
            ],
          ),
          if (thumbMissing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Main photo is required', style: DT.text(size: 11.5, color: DT.error)),
            ),
          const SizedBox(height: 14),
          Text('More photos', style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _imageBytes.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(DT.rSm),
                          child: Image.memory(_imageBytes[i],
                              width: 84, height: 84, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _images.removeAt(i);
                              _imageBytes.removeAt(i);
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                  color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 13, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_images.length < _maxImages)
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(DT.rSm),
                        border: Border.all(color: DT.border),
                      ),
                      child: const Icon(Icons.add_photo_alternate_outlined, color: DT.blue800),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. Specifications ───────────────────────────────────
  Widget _specsSection() {
    return SectionCard(
      title: 'Specifications',
      trailing: TextButton.icon(
        onPressed: () => setState(() => _specs.add(_SpecRow())),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text('Add', style: DT.text(size: 12.5, weight: FontWeight.w700, color: DT.blue800)),
        style: TextButton.styleFrom(foregroundColor: DT.blue800, minimumSize: const Size(0, 32)),
      ),
      child: _specs.isEmpty
          ? Text('Optional. e.g. Capacity: 150Ah, Warranty: 36 months, Voltage: 12V',
          style: DT.text(size: 12, color: DT.slate500, height: 1.45))
          : Column(
        children: [
          for (var i = 0; i < _specs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: CatalogTextField(
                      controller: _specs[i].key,
                      label: 'Name',
                      hint: 'Capacity',
                      capitalization: TextCapitalization.words,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: CatalogTextField(
                        controller: _specs[i].value, label: 'Value', hint: '150Ah'),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _specs.removeAt(i).dispose()),
                    icon: const Icon(Icons.remove_circle_outline, color: DT.error),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── 7. Variants ─────────────────────────────────────────
  Widget _variantsSection() {
    return SectionCard(
      title: 'Variants',
      trailing: TextButton.icon(
        onPressed: () => _editVariant(),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text('Add', style: DT.text(size: 12.5, weight: FontWeight.w700, color: DT.blue800)),
        style: TextButton.styleFrom(foregroundColor: DT.blue800, minimumSize: const Size(0, 32)),
      ),
      child: _variants.isEmpty
          ? Text(
          'Optional. Add when the product comes in options with their own price or stock, '
              'e.g. Colour: Red / Size: M.',
          style: DT.text(size: 12, color: DT.slate500, height: 1.45))
          : Column(
        children: [
          for (var i = 0; i < _variants.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DT.slate50,
                borderRadius: BorderRadius.circular(DT.rMd),
                border: Border.all(color: DT.border),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(DT.rSm),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: _variants[i].imageBytes != null
                          ? Image.memory(_variants[i].imageBytes!, fit: BoxFit.cover)
                          : const ColoredBox(
                          color: DT.slate100,
                          child: Icon(Icons.style_outlined, color: DT.slate400)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_variants[i].title,
                            style: DT.text(size: 13, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          '${_money(_variants[i].price)} · ${_variants[i].stock} in stock'
                              '${_variants[i].sku.isEmpty ? '' : ' · ${_variants[i].sku}'}',
                          style: DT.text(size: 11.5, color: DT.slate500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _editVariant(i),
                    icon: const Icon(Icons.edit_outlined, size: 19, color: DT.blue800),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _variants.removeAt(i)),
                    icon: const Icon(Icons.delete_outline, size: 19, color: DT.error),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editVariant([int? index]) async {
    final existing = index == null ? null : _variants[index];
    final result = await showModalBottomSheet<_Variant>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DT.rXl)),
      ),
      builder: (_) => _VariantSheet(
        existing: existing,
        defaultPrice: _finalPrice ?? _priceValue,
        picker: _picker,
        autoSku: _autoSku,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _variants.add(result);
      } else {
        _variants[index] = result;
      }
    });
  }

  // ── 8. More ─────────────────────────────────────────────
  Widget _moreSection() {
    Future<void> pick(bool mfg) async {
      final now = DateTime.now();
      final initial = (mfg ? _mfgDate : _expDate) ?? now;
      final d = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(now.year - 10),
        lastDate: DateTime(now.year + 15),
      );
      if (d != null) setState(() => mfg ? _mfgDate = d : _expDate = d);
    }

    Widget dateField(String label, DateTime? value, bool mfg) => Expanded(
      child: InkWell(
        onTap: () => pick(mfg),
        borderRadius: BorderRadius.circular(DT.rMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(DT.rMd),
            border: Border.all(color: DT.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.event_outlined, size: 18, color: DT.slate400),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: DT.text(size: 10.5, color: DT.slate500)),
                    Text(value == null ? 'Not set' : _date(value),
                        style: DT.text(
                            size: 13,
                            weight: FontWeight.w600,
                            color: value == null ? DT.slate400 : DT.onyx900)),
                  ],
                ),
              ),
              if (value != null)
                GestureDetector(
                  onTap: () => setState(() => mfg ? _mfgDate = null : _expDate = null),
                  child: const Icon(Icons.close_rounded, size: 16, color: DT.slate400),
                ),
            ],
          ),
        ),
      ),
    );

    return SectionCard(
      title: 'More details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            dateField('Manufactured', _mfgDate, true),
            const SizedBox(width: 8),
            dateField('Expires', _expDate, false),
          ]),
          const SizedBox(height: 12),
          CatalogTextField(
            controller: _bestBefore,
            label: 'Best before / shelf life',
            hint: 'e.g. 24 months from manufacture',
            icon: Icons.timelapse_rounded,
            inputFormatters: [LengthLimitingTextInputFormatter(50)],
          ),
          const SizedBox(height: 6),
          SwitchListTile(
            value: _franchise,
            onChanged: (v) => setState(() => _franchise = v),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: DT.blue800,
            title: Text('Franchise available',
                style: DT.text(size: 13.5, weight: FontWeight.w600)),
            subtitle: Text('Buyers can enquire about a franchise for this product',
                style: DT.text(size: 11.5, color: DT.slate500)),
          ),
          const SizedBox(height: 4),
          _notice(Icons.info_outline_rounded,
              'New products are reviewed by the admin before buyers can see them.'),
        ],
      ),
    );
  }

  Widget _notice(IconData icon, String text, {bool warn = false}) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: warn ? DT.amber50 : DT.blue50,
      borderRadius: BorderRadius.circular(DT.rMd),
      border: Border.all(color: warn ? DT.amber200 : DT.blue100),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: warn ? DT.amber800 : DT.blue800),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: DT.text(
                  size: 12, color: warn ? DT.amber900 : DT.blue900, height: 1.45)),
        ),
      ],
    ),
  );

  Widget _bottomBar() {
    final fp = _finalPrice;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: DT.border)),
        ),
        child: Row(
          children: [
            if (fp != null && fp > 0) ...[
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selling at', style: DT.text(size: 11, color: DT.slate500)),
                  Text(_money(fp), style: DT.text(size: 17, weight: FontWeight.w800)),
                ],
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DT.blue800,
                    disabledBackgroundColor: DT.blue800.withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
                  ),
                  child: _saving
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: Colors.white)),
                      const SizedBox(width: 10),
                      Text('Uploading…',
                          style: DT.text(
                              size: 14, weight: FontWeight.w700, color: Colors.white)),
                    ],
                  )
                      : Text('Submit product',
                      style: DT.text(
                          size: 14.5, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// VARIANT SHEET
// ===========================================================================
class _VariantSheet extends StatefulWidget {
  final _Variant? existing;
  final double? defaultPrice;
  final ImagePicker picker;
  final String Function([Map<String, String>]) autoSku;

  const _VariantSheet({
    required this.existing,
    required this.defaultPrice,
    required this.picker,
    required this.autoSku,
  });

  @override
  State<_VariantSheet> createState() => _VariantSheetState();
}

class _VariantSheetState extends State<_VariantSheet> {
  final _formKey = GlobalKey<FormState>();
  final List<(TextEditingController, TextEditingController)> _attrs = [];
  late final _price = TextEditingController(
    text: widget.existing != null
        ? _fmt(widget.existing!.price)
        : (widget.defaultPrice == null ? '' : _fmt(widget.defaultPrice!)),
  );
  late final _stock = TextEditingController(text: widget.existing?.stock.toString() ?? '');
  late final _sku = TextEditingController(text: widget.existing?.sku ?? '');
  XFile? _image;
  Uint8List? _imageBytes;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      e.attributes.forEach((k, v) {
        _attrs.add((TextEditingController(text: k), TextEditingController(text: v)));
      });
      _image = e.image;
      _imageBytes = e.imageBytes;
    }
    if (_attrs.isEmpty) _attrs.add((TextEditingController(), TextEditingController()));
  }

  @override
  void dispose() {
    for (final (k, v) in _attrs) {
      k.dispose();
      v.dispose();
    }
    _price.dispose();
    _stock.dispose();
    _sku.dispose();
    super.dispose();
  }

  Map<String, String> get _attrMap => {
    for (final (k, v) in _attrs)
      if (k.text.trim().isNotEmpty && v.text.trim().isNotEmpty) k.text.trim(): v.text.trim(),
  };

  Future<void> _pickImage() async {
    final x = await widget.picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 1200);
    if (x == null) return;
    final b = await x.readAsBytes();
    if (!mounted) return;
    setState(() {
      _image = x;
      _imageBytes = b;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final attrs = _attrMap;
    if (attrs.isEmpty) {
      showCompanySnack(context, 'Add at least one option, e.g. Colour: Red', error: true);
      return;
    }
    Navigator.pop(
      context,
      _Variant(
        attributes: attrs,
        price: double.parse(_price.text.trim()),
        stock: int.tryParse(_stock.text.trim()) ?? 0,
        sku: _sku.text.trim().isEmpty ? widget.autoSku(attrs) : _sku.text.trim(),
        image: _image,
        imageBytes: _imageBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration:
                  BoxDecoration(color: DT.slate300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text(widget.existing == null ? 'Add variant' : 'Edit variant',
                  style: DT.text(size: 17, weight: FontWeight.w800)),
              const SizedBox(height: 14),
              Text('Options', style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx600)),
              const SizedBox(height: 8),
              for (var i = 0; i < _attrs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: CatalogTextField(
                          controller: _attrs[i].$1,
                          label: 'Option',
                          hint: 'Colour',
                          capitalization: TextCapitalization.words,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CatalogTextField(
                          controller: _attrs[i].$2,
                          label: 'Value',
                          hint: 'Red',
                          capitalization: TextCapitalization.words,
                        ),
                      ),
                      if (_attrs.length > 1)
                        IconButton(
                          onPressed: () => setState(() {
                            final (k, v) = _attrs.removeAt(i);
                            k.dispose();
                            v.dispose();
                          }),
                          icon: const Icon(Icons.remove_circle_outline, color: DT.error),
                        ),
                    ],
                  ),
                ),
              if (_attrs.length < 4)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(
                            () => _attrs.add((TextEditingController(), TextEditingController()))),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('Add option',
                        style: DT.text(size: 12.5, weight: FontWeight.w700, color: DT.blue800)),
                    style: TextButton.styleFrom(foregroundColor: DT.blue800),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CatalogTextField(
                      controller: _price,
                      label: 'Price *',
                      icon: Icons.currency_rupee_rounded,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [DecimalInputFormatter()],
                      validator: (v) {
                        final d = double.tryParse((v ?? '').trim());
                        return (d == null || d <= 0) ? 'Enter price' : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CatalogTextField(
                      controller: _stock,
                      label: 'Stock *',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(7),
                      ],
                      validator: (v) =>
                      int.tryParse((v ?? '').trim()) == null ? 'Enter stock' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CatalogTextField(
                controller: _sku,
                label: 'SKU',
                hint: 'Leave empty to auto-generate',
                icon: Icons.tag_rounded,
                inputFormatters: [LengthLimitingTextInputFormatter(90)],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: DT.slate50,
                        borderRadius: BorderRadius.circular(DT.rSm),
                        border: Border.all(color: DT.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _imageBytes != null
                          ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                          : const Icon(Icons.add_photo_alternate_outlined, color: DT.blue800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Variant photo (optional)',
                        style: DT.text(size: 12.5, color: DT.slate500)),
                  ),
                  if (_imageBytes != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _image = null;
                        _imageBytes = null;
                      }),
                      child: Text('Remove',
                          style: DT.text(size: 12.5, weight: FontWeight.w700, color: DT.error)),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DT.blue800,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
                  ),
                  child: Text(widget.existing == null ? 'Add variant' : 'Save variant',
                      style: DT.text(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}