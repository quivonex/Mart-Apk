// lib/screens/catalog/product_create_screen.dart
//
// Add / Edit product (design: "Add Product - OnyxMart B2B").
//
// CREATE  ProductCreateScreen(companyId: 5)
//         -> POST /product/api/products/create/   (multipart, product starts "pending")
//         Local draft: form values + selections auto-save (not photos).
//
// EDIT    ProductCreateScreen(existing: product)
//         -> POST /product/company/product/update-request/   (admin approval)
//         Sends ONLY changed, non-empty values. On approval the backend validates the
//         saved values as a plain dict, where "" is NOT turned into null, so an empty
//         number / date / FK would make the approval fail.
//
// Backend rules handled:
//   * weight / length / width / height required, sent as "1.5 kg" / "20 cm"
//     (Shiprocket helpers read number + unit)
//   * flat discount < price, percent < 100
//   * variant SKU is UNIQUE -> never sent empty (auto-generated)
//   * status / slug / product_code set by the server

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/design_tokens.dart';
import '../models/catalog_models.dart';
import '../models/company_model.dart';
import '../models/my_product_model.dart';
import '../services/catalog_service.dart';
import '../services/company_service.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/company_ui.dart';
import '../widgets/product_ui.dart';
import 'branch_screens.dart';
import 'category_screens.dart';
import 'subcategory_screens.dart';
import 'unit_screens.dart';

class ProductCreateScreen extends StatefulWidget {
  /// Create mode: preselect this company.
  final int? companyId;

  /// Edit mode: the product to change (sent as an update request).
  final MyProduct? existing;

  const ProductCreateScreen({super.key, this.companyId, this.existing});

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
  static const _draftKey = 'product_create_draft_v1';
  static const _maxImages = 8;
  static const _maxImageBytes = 5 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  bool get _isEdit => widget.existing != null;

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

  /// Ids to select once each list has loaded (draft restore / edit prefill).
  final Map<String, int> _pending = {};

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

  // Photos
  XFile? _thumb;
  Uint8List? _thumbBytes;
  String _existingThumbUrl = '';
  final List<XFile> _images = [];
  final List<Uint8List> _imageBytes = [];
  List<MyProductImage> _existingImages = [];
  final Set<int> _deleteImageIds = {};

  final List<(String, String)> _specs = [];
  final List<_Variant> _variants = [];

  bool _submitAttempted = false;
  bool _saving = false;

  // Draft
  Timer? _draftTimer;
  DateTime? _draftSavedAt;
  DateTime? _restoredDraftAt;
  bool _restoring = false;

  // Edit baseline
  Map<String, String> _originalFields = {};

  // =====================================================================
  // LIFECYCLE
  // =====================================================================
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_isEdit) {
      _prefillFromProduct(widget.existing!);
    } else {
      await _restoreDraft();
    }
    for (final c in _controllers) {
      c.addListener(_onFieldChanged);
    }
    _loadCompanies();
    _loadUnits();
  }

  List<TextEditingController> get _controllers => [
    _name, _description, _price, _discountValue, _hsn, _stock,
    _weight, _length, _width, _height, _bestBefore,
  ];

  @override
  void dispose() {
    _draftTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onFieldChanged() {
    if (!mounted) return;
    setState(() {}); // live price, completion %, footer status
    _scheduleDraft();
  }

  bool get _hasInput =>
      _name.text.isNotEmpty ||
          _price.text.isNotEmpty ||
          _description.text.isNotEmpty ||
          _stock.text.isNotEmpty ||
          _thumb != null ||
          _images.isNotEmpty;

  bool get _dirty {
    if (_isEdit) return _changedFields().isNotEmpty || _hasMediaChanges;
    return _hasInput;
  }

  bool get _hasMediaChanges => _thumb != null || _images.isNotEmpty || _deleteImageIds.isNotEmpty;

  // =====================================================================
  // DRAFT (create mode)
  // =====================================================================
  void _scheduleDraft() {
    if (_isEdit || _restoring || _saving) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 900), () => _saveDraft(silent: true));
  }

  Map<String, dynamic> _draftJson() => {
    'savedAt': DateTime.now().toIso8601String(),
    'company': _company?.id ?? _pending['company'],
    'branch': _branch?.id,
    'category': _category?.id,
    'subcategory': _subcategory?.id,
    'brand': _brand?.id,
    'unit': _unit?.id,
    'name': _name.text,
    'description': _description.text,
    'price': _price.text,
    'discountType': _discountType,
    'discountValue': _discountValue.text,
    'gst': _gst,
    'hsn': _hsn.text,
    'stock': _stock.text,
    'weight': _weight.text,
    'weightUnit': _weightUnit,
    'length': _length.text,
    'width': _width.text,
    'height': _height.text,
    'dimUnit': _dimUnit,
    'mfg': _mfgDate?.toIso8601String(),
    'exp': _expDate?.toIso8601String(),
    'bestBefore': _bestBefore.text,
    'franchise': _franchise,
    'specs': [for (final (k, v) in _specs) [k, v]],
    'variants': [
      for (final v in _variants)
        {'attributes': v.attributes, 'price': v.price, 'stock': v.stock, 'sku': v.sku}
    ],
  };

  Future<void> _saveDraft({bool silent = false}) async {
    if (_isEdit) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_hasInput && _specs.isEmpty && _variants.isEmpty) {
        await prefs.remove(_draftKey);
        return;
      }
      await prefs.setString(_draftKey, jsonEncode(_draftJson()));
      if (!mounted) return;
      setState(() => _draftSavedAt = DateTime.now());
      if (!silent) {
        showCompanySnack(context, 'Draft saved on this device (photos are not included)');
      }
    } catch (_) {
      if (!silent && mounted) showCompanySnack(context, 'Could not save draft', error: true);
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  Future<void> _restoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null) return;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      final draftCompany = d['company'] as int?;
      // Opened for a specific company? Only restore that company's draft.
      if (widget.companyId != null && draftCompany != null && draftCompany != widget.companyId) {
        return;
      }
      _restoring = true;
      for (final k in ['company', 'branch', 'category', 'subcategory', 'brand', 'unit']) {
        final v = d[k];
        if (v is int) _pending[k] = v;
      }
      _name.text = d['name'] ?? '';
      _description.text = d['description'] ?? '';
      _price.text = d['price'] ?? '';
      _discountType = d['discountType'] ?? 'none';
      _discountValue.text = d['discountValue'] ?? '';
      _gst = (d['gst'] as num?)?.toDouble();
      _hsn.text = d['hsn'] ?? '';
      _stock.text = d['stock'] ?? '';
      _weight.text = d['weight'] ?? '';
      _weightUnit = d['weightUnit'] ?? 'kg';
      _length.text = d['length'] ?? '';
      _width.text = d['width'] ?? '';
      _height.text = d['height'] ?? '';
      _dimUnit = d['dimUnit'] ?? 'cm';
      _mfgDate = DateTime.tryParse(d['mfg'] ?? '');
      _expDate = DateTime.tryParse(d['exp'] ?? '');
      _bestBefore.text = d['bestBefore'] ?? '';
      _franchise = d['franchise'] == true;
      _specs
        ..clear()
        ..addAll([
          for (final e in (d['specs'] as List? ?? []))
            if (e is List && e.length == 2) (e[0].toString(), e[1].toString())
        ]);
      _variants
        ..clear()
        ..addAll([
          for (final e in (d['variants'] as List? ?? []))
            if (e is Map)
              _Variant(
                attributes: Map<String, String>.from(
                    (e['attributes'] as Map).map((k, v) => MapEntry('$k', '$v'))),
                price: (e['price'] as num?)?.toDouble() ?? 0,
                stock: (e['stock'] as num?)?.toInt() ?? 0,
                sku: e['sku']?.toString() ?? '',
              )
        ]);
      _restoredDraftAt = DateTime.tryParse(d['savedAt'] ?? '');
      if (mounted) setState(() {});
    } catch (_) {
      // Corrupt draft - ignore.
    } finally {
      _restoring = false;
    }
  }

  Future<void> _reset() async {
    final ok = await confirmAction(
      context,
      title: 'Start over?',
      message: 'This clears everything you entered and deletes the saved draft.',
      confirmLabel: 'Reset form',
      destructive: true,
    );
    if (!ok || !mounted) return;
    _restoring = true;
    for (final c in _controllers) {
      c.clear();
    }
    _restoring = false;
    await _clearDraft();
    setState(() {
      _discountType = 'none';
      _gst = null;
      _weightUnit = 'kg';
      _dimUnit = 'cm';
      _mfgDate = null;
      _expDate = null;
      _franchise = false;
      _thumb = null;
      _thumbBytes = null;
      _images.clear();
      _imageBytes.clear();
      _specs.clear();
      _variants.clear();
      _branch = null;
      _category = null;
      _subcategory = null;
      _brand = null;
      _subcategories = [];
      _brands = [];
      _submitAttempted = false;
      _draftSavedAt = null;
      _restoredDraftAt = null;
    });
  }

  // =====================================================================
  // EDIT PREFILL
  // =====================================================================
  void _prefillFromProduct(MyProduct p) {
    if (p.companyId != null) _pending['company'] = p.companyId!;
    if (p.branchId != null) _pending['branch'] = p.branchId!;
    if (p.categoryId != null) _pending['category'] = p.categoryId!;
    if (p.subcategoryId != null) _pending['subcategory'] = p.subcategoryId!;
    if (p.brandId != null) _pending['brand'] = p.brandId!;
    if (p.unitId != null) _pending['unit'] = p.unitId!;

    _name.text = p.name;
    _description.text = p.description;
    _price.text = _num(p.price.toString());
    if ((p.discountType == 'flat' || p.discountType == 'percent') &&
        (p.discountValue ?? 0) > 0) {
      _discountType = p.discountType;
      _discountValue.text = _num(p.discountValue.toString());
    }
    _gst = p.gstPercent;
    _hsn.text = p.hsnCode;
    _stock.text = '${p.stock}';
    final (w, wu) = MyProduct.splitMeasure(p.weight, 'kg');
    _weight.text = w;
    _weightUnit = wu == 'g' ? 'g' : 'kg';
    final (l, du) = MyProduct.splitMeasure(p.length, 'cm');
    _length.text = l;
    _dimUnit = du == 'mm' ? 'mm' : 'cm';
    _width.text = MyProduct.splitMeasure(p.width, 'cm').$1;
    _height.text = MyProduct.splitMeasure(p.height, 'cm').$1;
    _mfgDate = DateTime.tryParse(p.manufacturingDate);
    _expDate = DateTime.tryParse(p.expiryDate);
    _bestBefore.text = p.bestBefore;
    _franchise = p.franchiseAvailable;
    _specs.addAll(p.specifications.entries.map((e) => (e.key, e.value)));
    _existingThumbUrl = p.thumbnail;
    _existingImages = List.of(p.images);

    _originalFields = _fieldsFromProduct(p);
  }

  /// Baseline values in exactly the format _currentFields() produces.
  Map<String, String> _fieldsFromProduct(MyProduct p) {
    final (w, wu) = MyProduct.splitMeasure(p.weight, 'kg');
    final (l, du) = MyProduct.splitMeasure(p.length, 'cm');
    final hasDisc =
        (p.discountType == 'flat' || p.discountType == 'percent') && (p.discountValue ?? 0) > 0;
    return {
      if (p.categoryId != null) 'category': '${p.categoryId}',
      if (p.subcategoryId != null) 'subcategory': '${p.subcategoryId}',
      if (p.unitId != null) 'unit': '${p.unitId}',
      if (p.branchId != null) 'branch': '${p.branchId}',
      if (p.brandId != null) 'brand': '${p.brandId}',
      'name': p.name.trim(),
      'description': p.description.trim(),
      'price': _num(p.price.toString()),
      'stock_quantity': '${p.stock}',
      'weight': '${_num(w)} ${wu == 'g' ? 'g' : 'kg'}',
      'length': '${_num(l)} ${du == 'mm' ? 'mm' : 'cm'}',
      'width': '${_num(MyProduct.splitMeasure(p.width, 'cm').$1)} ${du == 'mm' ? 'mm' : 'cm'}',
      'height':
      '${_num(MyProduct.splitMeasure(p.height, 'cm').$1)} ${du == 'mm' ? 'mm' : 'cm'}',
      'discount_type': hasDisc ? p.discountType : '',
      if (hasDisc) 'discount_value': _num(p.discountValue.toString()),
      if (p.gstPercent != null) 'GST_percent': p.gstPercent!.toStringAsFixed(2),
      'HSN_code': p.hsnCode.trim(),
      if (p.manufacturingDate.isNotEmpty) 'manufacturing_date': p.manufacturingDate,
      if (p.expiryDate.isNotEmpty) 'expiry_date': p.expiryDate,
      'best_before_duration': p.bestBefore.trim(),
      'specifications': jsonEncode(p.specifications),
      'is_franchise_available': p.franchiseAvailable.toString(),
    };
  }

  // =====================================================================
  // LOADERS (cascade)
  // =====================================================================
  int? _take(String key) => _pending.remove(key);

  Future<void> _loadCompanies() async {
    setState(() {
      _loadingCompanies = true;
      _companiesError = null;
    });
    final r = await CompanyService.getMyCompanies();
    if (!mounted) return;
    final list = r.data
        .where((c) => c.isActive || c.id == widget.existing?.companyId)
        .map(_CompanyOption.new)
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    setState(() {
      _loadingCompanies = false;
      _companies = list;
      _companiesError = r.isSuccess
          ? (list.isEmpty ? 'Create a company first.' : null)
          : (r.message ?? 'Could not load companies');
    });

    final wantId = _take('company') ?? widget.companyId;
    _CompanyOption? pick = list.where((c) => c.id == wantId).firstOrNull;
    final paid = list.where((c) => c.company.isPaid).toList();
    pick ??= paid.length == 1 ? paid.first : null;
    if (pick != null) _onCompany(pick, fromLoad: true);
  }

  Future<void> _loadUnits({int? selectId, String? selectName}) async {
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
      _unit = _keep(r.items, selectId ?? _take('unit') ?? _unit?.id, name: selectName);
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
      _branch = _keep(r.items, selectId ?? _take('branch') ?? _branch?.id, name: selectName);
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
      _category =
          _keep(r.items, selectId ?? _take('category') ?? _category?.id, name: selectName);
    });
    if (_category?.id != before || _category != null && _subcategories.isEmpty) {
      _onCategoryChanged(keepPending: true);
    }
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
      _subcategory = _keep(r.items, selectId ?? _take('subcategory') ?? _subcategory?.id,
          name: selectName);
    });
    if (_subcategory?.id != before || _subcategory != null && _brands.isEmpty) {
      _onSubcategoryChanged(keepPending: true);
    }
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
      _brand = _keep(r.items, _take('brand') ?? _brand?.id);
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
        ..sort((a, b) => b.id.compareTo(a.id));
      if (hits.isNotEmpty) return hits.first;
    }
    return null;
  }

  // ── selection handlers ──────────────────────────────────
  void _onCompany(_CompanyOption? c, {bool fromLoad = false}) {
    if (c?.id == _company?.id && !fromLoad) return;
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
    if (!fromLoad) {
      _pending.removeWhere((k, _) => k != 'unit');
      _scheduleDraft();
    }
    if (c != null) {
      _loadBranches();
      _loadCategories();
    }
  }

  void _onCategoryChanged({bool keepPending = false}) {
    if (!keepPending) {
      _pending.remove('subcategory');
      _pending.remove('brand');
    }
    setState(() {
      _subcategory = null;
      _subcategories = [];
      _brand = null;
      _brands = [];
    });
    if (_category != null) _loadSubcategories();
    _scheduleDraft();
  }

  void _onSubcategoryChanged({bool keepPending = false}) {
    if (!keepPending) _pending.remove('brand');
    setState(() {
      _brand = null;
      _brands = [];
    });
    if (_subcategory != null) _loadBrands();
    _scheduleDraft();
  }

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
    final saved =
    await _push<CatalogBranch>(BranchFormScreen(companyId: c.id, companyName: c.label));
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
    final saved = await _push<CatalogSubCategory>(SubCategoryFormScreen(category: _category!));
    if (saved != null) await _loadSubcategories(selectId: saved.id, selectName: saved.name);
  }

  Future<void> _manageSubcategories() async {
    final changed = await _push<bool>(SubCategoryManageScreen(category: _category!));
    if (changed == true) _loadSubcategories();
  }

  Future<void> _addUnit() async {
    final saved = await _push<CatalogUnit>(const UnitFormScreen());
    if (saved != null) await _loadUnits(selectId: saved.id, selectName: saved.label);
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
        if (mounted) showCompanySnack(context, 'Image must be under 5MB', error: true);
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

  int get _keptExistingImages =>
      _existingImages.where((i) => !_deleteImageIds.contains(i.id)).length;

  int get _photoCount =>
      (_thumb != null || _existingThumbUrl.isNotEmpty ? 1 : 0) +
          _keptExistingImages +
          _images.length;

  Future<void> _pickImages() async {
    final room = _maxImages - _keptExistingImages - _images.length;
    if (room <= 0) {
      showCompanySnack(context, 'You can add up to $_maxImages extra photos', error: true);
      return;
    }
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
        showCompanySnack(context, 'Only $room more photo(s) added');
      }
    } catch (e) {
      if (mounted) showCompanySnack(context, 'Could not pick photos: $e', error: true);
    }
  }

  // =====================================================================
  // PRICE / FORMAT HELPERS
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

  String _num(String s) {
    final d = double.tryParse(s.trim());
    if (d == null) return s.trim();
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }

  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _prettyDate(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String _autoSku([Map<String, String> attrs = const {}]) {
    String clean(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final words = _name.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    var base = words
        .map(clean)
        .where((w) => w.isNotEmpty)
        .map((w) => w.length > 3 ? w.substring(0, 3) : w)
        .take(3)
        .join();
    if (base.isEmpty) base = 'PRD';
    final attrPart = attrs.values.map(clean).where((v) => v.isNotEmpty).join('-');
    final rnd = Random().nextInt(9000) + 1000;
    final sku = [base, if (attrPart.isNotEmpty) attrPart, '$rnd'].join('-');
    return sku.length > 90 ? sku.substring(0, 90) : sku;
  }

  // =====================================================================
  // COMPLETION
  // =====================================================================
  bool _pos(TextEditingController c) => (double.tryParse(c.text.trim()) ?? 0) > 0;

  List<(String, bool)> get _requiredChecks => [
    ('Company', _company != null),
    ('Category', _category != null),
    ('Subcategory', _subcategory != null),
    ('Unit', _unit != null),
    ('Product name', _name.text.trim().length >= 3),
    ('Price', _pos(_price)),
    ('Stock quantity', int.tryParse(_stock.text.trim()) != null),
    ('Weight', _pos(_weight)),
    ('Length', _pos(_length)),
    ('Width', _pos(_width)),
    ('Height', _pos(_height)),
    ('Main photo', _thumb != null || _existingThumbUrl.isNotEmpty),
  ];

  List<bool> get _recommendedChecks => [
    _description.text.trim().length >= 20,
    _gst != null,
    _hsn.text.trim().length >= 4,
    _photoCount >= 2,
    _specs.isNotEmpty,
  ];

  int get _requiredLeft => _requiredChecks.where((c) => !c.$2).length;

  int get _completion {
    final req = _requiredChecks;
    final rec = _recommendedChecks;
    final done = req.where((c) => c.$2).length * 2 + rec.where((c) => c).length;
    final total = req.length * 2 + rec.length;
    return ((done / total) * 100).round();
  }

  // =====================================================================
  // SUBMIT
  // =====================================================================
  String? _validateExtras() {
    final c = _company;
    if (c == null) return 'Select a company';
    if (!_isEdit && !c.company.isPaid) {
      return 'Pay the registration fee for ${c.label} before adding products';
    }
    if (_category == null) return 'Select a category';
    if (_subcategory == null) return 'Select a subcategory';
    if (_unit == null) return 'Select a unit';
    if (!_pos(_weight) || !_pos(_length) || !_pos(_width) || !_pos(_height)) {
      return 'Enter packed weight, length, width and height';
    }
    if (_thumb == null && _existingThumbUrl.isEmpty) return 'Add a main product photo';
    if (_mfgDate != null && _expDate != null && !_expDate!.isAfter(_mfgDate!)) {
      return 'Expiry date must be after the manufacturing date';
    }
    return null;
  }

  /// All form values in backend format (create) / comparison format (edit).
  Map<String, String> _currentFields() {
    final hasDisc = _discountType != 'none' && (_discount ?? 0) > 0;
    final specs = <String, String>{for (final (k, v) in _specs) k: v};
    return {
      if (_category != null) 'category': '${_category!.id}',
      if (_subcategory != null) 'subcategory': '${_subcategory!.id}',
      if (_unit != null) 'unit': '${_unit!.id}',
      if (_branch != null) 'branch': '${_branch!.id}',
      if (_brand != null) 'brand': '${_brand!.id}',
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'price': _num(_price.text),
      'stock_quantity': '${int.tryParse(_stock.text.trim()) ?? 0}',
      'weight': '${_num(_weight.text)} $_weightUnit',
      'length': '${_num(_length.text)} $_dimUnit',
      'width': '${_num(_width.text)} $_dimUnit',
      'height': '${_num(_height.text)} $_dimUnit',
      'discount_type': hasDisc ? _discountType : '',
      if (hasDisc) 'discount_value': _num(_discountValue.text),
      if (_gst != null) 'GST_percent': _gst!.toStringAsFixed(2),
      'HSN_code': _hsn.text.trim(),
      if (_mfgDate != null) 'manufacturing_date': _date(_mfgDate!),
      if (_expDate != null) 'expiry_date': _date(_expDate!),
      'best_before_duration': _bestBefore.text.trim(),
      'specifications': jsonEncode(specs),
      'is_franchise_available': _franchise.toString(),
    };
  }

  /// Text-like fields that can safely be sent as "" in an update request.
  static const _clearable = {'description', 'discount_type', 'HSN_code', 'best_before_duration'};

  Map<String, String> _changedFields() {
    final now = _currentFields();
    final out = <String, String>{};
    now.forEach((k, v) {
      if (_originalFields[k] == v) return;
      if (v.isEmpty && !_clearable.contains(k)) return;
      out[k] = v;
    });
    return out;
  }

  Map<String, String> _createFields() {
    final f = _currentFields()
      ..removeWhere((k, v) =>
      v.isEmpty ||
          (k == 'specifications' && v == '{}') ||
          (k == 'discount_type' && v.isEmpty));
    f['company'] = '${_company!.id}';
    f['variants'] = jsonEncode([
      for (final v in _variants)
        {
          'attributes': v.attributes,
          'price': v.price,
          'stock_quantity': v.stock,
          'sku': v.sku.trim().isEmpty ? _autoSku(v.attributes) : v.sku.trim(),
        }
    ]);
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

    if (_isEdit) {
      final changes = _changedFields();
      if (changes.isEmpty && !_hasMediaChanges) {
        showCompanySnack(context, 'Nothing has changed yet');
        return;
      }
      setState(() => _saving = true);
      final res = await CatalogService.requestProductUpdate(
        productId: widget.existing!.id,
        fields: changes,
        thumbnail: _thumb,
        images: _images,
        deleteImageIds: _deleteImageIds.toList(),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      if (!res.ok) {
        showCompanySnack(context, res.message, error: true);
        return;
      }
      await _doneDialog(
        'Changes sent for review',
        'The admin will review your changes to ${_name.text.trim()}. The live listing '
            'stays as it is until they are approved.',
      );
      if (mounted) Navigator.pop(context, true);
      return;
    }

    setState(() => _saving = true);
    final res = await CatalogService.createProduct(
      fields: _createFields(),
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
    _draftTimer?.cancel();
    await _clearDraft();
    await _doneDialog(
      'Product submitted',
      '${_name.text.trim()} was added and is waiting for admin approval. It will be '
          'visible to buyers once approved.',
    );
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _doneDialog(String title, String body) => showDialog(
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
      title: Text(title,
          textAlign: TextAlign.center, style: DT.text(size: 18, weight: FontWeight.w800)),
      content: Text(body,
          textAlign: TextAlign.center,
          style: DT.text(size: 13, color: DT.onyx600, height: 1.5)),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: PX.royal600,
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

  Future<void> _confirmLeave() async {
    if (_isEdit) {
      final leave = await confirmAction(
        context,
        title: 'Discard changes?',
        message: 'Your edits to this product will be lost.',
        confirmLabel: 'Discard',
        destructive: true,
      );
      if (leave && mounted) Navigator.pop(context);
      return;
    }
    // Create mode: the draft is kept, so leaving is safe.
    _draftTimer?.cancel();
    await _saveDraft(silent: true);
    if (mounted) Navigator.pop(context);
  }

  // =====================================================================
  // BUILD
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _saving) return;
        _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: DT.slate50,
        appBar: _appBar(),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (_restoredDraftAt != null && !_isEdit) ...[
                  _draftBanner(),
                  const SizedBox(height: 12),
                ],
                if (_isEdit && widget.existing!.review != ProductReviewStatus.approved) ...[
                  _statusBanner(),
                  const SizedBox(height: 12),
                ],
                _completionCard(),
                const SizedBox(height: 16),
                _catalogSection(),
                const SizedBox(height: 16),
                _detailsSection(),
                const SizedBox(height: 16),
                _priceSection(),
                const SizedBox(height: 16),
                _stockSection(),
                const SizedBox(height: 16),
                _photosSection(),
                const SizedBox(height: 16),
                _specsCard(),
                const SizedBox(height: 12),
                _variantsCard(),
                const SizedBox(height: 16),
                _moreSection(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: _footer(),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────
  PreferredSizeWidget _appBar() {
    final saved = _draftSavedAt;
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: DT.slate200)),
          boxShadow: [BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: DT.onyx900, size: 24),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(_isEdit ? 'Edit product' : 'Add product',
                                overflow: TextOverflow.ellipsis,
                                style: DT.text(
                                    size: 18, weight: FontWeight.w700, color: DT.onyx900)),
                          ),
                          if (!_isEdit && saved != null) ...[
                            const SizedBox(width: 8),
                            _savedBadge(saved),
                          ],
                        ],
                      ),
                      Text(
                        _isEdit ? widget.existing!.name : 'New B2B product listing',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 12, weight: FontWeight.w500, color: DT.slate500),
                      ),
                    ],
                  ),
                ),
                if (!_isEdit)
                  TextButton(
                    onPressed: _saving ? null : _reset,
                    child: Text('Reset',
                        style: DT.text(size: 12.5, weight: FontWeight.w600, color: PX.royal600)),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _savedBadge(DateTime at) => Tooltip(
    message: 'Saved on this device at ${_time(at)}',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: DT.emerald50,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DT.emerald200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: PX.emerald500, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text('Auto-saved',
              style: DT.text(size: 11, weight: FontWeight.w600, color: DT.emerald700)),
        ],
      ),
    ),
  );

  Widget _draftBanner() => _notice(
    icon: Icons.history_rounded,
    text: 'Restored your draft from ${_prettyDate(_restoredDraftAt!)}, '
        '${_time(_restoredDraftAt!)}. Photos need to be added again.',
    action: 'Discard',
    onAction: _reset,
  );

  Widget _statusBanner() {
    final rejected = widget.existing!.review == ProductReviewStatus.rejected;
    return _notice(
      icon: rejected ? Icons.error_outline_rounded : Icons.schedule_rounded,
      text: rejected
          ? 'This product was rejected by the admin. Update the details and send them for review.'
          : 'This product is still waiting for admin approval.',
      warn: true,
    );
  }

  Widget _notice({
    required IconData icon,
    required String text,
    bool warn = false,
    String? action,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warn ? DT.amber50 : const Color(0xB3EFF6FF),
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: warn ? DT.amber200 : const Color(0xCCBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: warn ? DT.amber700 : PX.royal600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: DT.text(
                    size: 12, color: warn ? DT.amber900 : DT.blue900, height: 1.5)),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(action,
                    style: DT.text(size: 12, weight: FontWeight.w700, color: PX.royal600)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Completion ──────────────────────────────────────────
  Widget _completionCard() {
    final pct = _completion;
    final left = _requiredLeft;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.slate200),
        boxShadow: PX.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: PX.royal50, shape: BoxShape.circle),
            child: Text('$pct%',
                style: DT.text(size: 11, weight: FontWeight.w800, color: PX.royal600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Listing completion',
                    style: DT.text(size: 12, weight: FontWeight.w700, color: DT.onyx900)),
                Text(
                  left == 0
                      ? 'All required details added'
                      : '$left required field${left == 1 ? '' : 's'} left',
                  style: DT.text(size: 11, color: DT.slate500),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 8,
                backgroundColor: DT.slate100,
                color: PX.royal600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Company & catalog ────────────────────────────────
  Widget _catalogSection() {
    final c = _company;
    return PxSection(
      title: 'Company & catalog',
      subtitle: 'Select the company and where this product is listed',
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
            enabled: !_isEdit,
            disabledHint: widget.existing?.companyName,
            onRetry: _loadCompanies,
            showRequiredError: _submitAttempted,
            onChanged: _onCompany,
          ),
          if (c != null && !_isEdit && !c.company.isPaid) ...[
            const SizedBox(height: 8),
            _notice(
              icon: Icons.payments_outlined,
              text: 'Registration fee is pending for ${c.label}. Pay it from My Companies '
                  'to add products.',
              warn: true,
            ),
          ],
          const SizedBox(height: 16),
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
              _scheduleDraft();
            },
            onAddNew: c == null ? null : _addBranch,
            onManage: c == null ? null : _manageBranches,
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
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
            onChanged: (v) {
              setState(() => _brand = v);
              _scheduleDraft();
            },
          ),
          const SizedBox(height: 16),
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
            onChanged: (v) {
              setState(() => _unit = v);
              _scheduleDraft();
            },
            onAddNew: _addUnit,
            onManage: _manageUnits,
          ),
        ],
      ),
    );
  }

  // ── 2. Product details ──────────────────────────────────
  Widget _detailsSection() {
    return PxSection(
      title: 'Product details',
      subtitle: 'Name buyers search for and a clear description',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PxLabel('Product name', required: true),
          PxTextField(
            controller: _name,
            hint: 'e.g. Exide 150Ah Inverter Battery',
            icon: Icons.inventory_2_outlined,
            capitalization: TextCapitalization.words,
            inputFormatters: [LengthLimitingTextInputFormatter(200)],
            validator: (v) => (v ?? '').trim().length < 3 ? 'Enter the product name' : null,
          ),
          const SizedBox(height: 16),
          PxLabel(
            'Description',
            trailing: Text('${_description.text.length}/2000',
                style: DT.text(size: 11, color: DT.slate400)),
          ),
          PxTextField(
            controller: _description,
            hint: 'Material, grade, ratings, what is in the box…',
            maxLines: 4,
            tinted: true,
            capitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(2000)],
          ),
        ],
      ),
    );
  }

  // ── 3. Price & tax ──────────────────────────────────────
  Widget _priceSection() {
    final fp = _finalPrice;
    final p = _priceValue;
    final unit = _unit?.shortName ?? _unit?.name;
    return PxSection(
      title: 'Price & tax',
      subtitle: 'Price, trade discount and GST',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PxLabel('Price (MRP / unit)', required: true),
          PxTextField(
            controller: _price,
            hint: '0.00',
            bold: true,
            prefix: Padding(
              padding: const EdgeInsets.only(left: 14, right: 6),
              child: Text('₹',
                  style: DT.text(size: 16, weight: FontWeight.w700, color: DT.onyx600)),
            ),
            suffixText: unit == null || unit.isEmpty ? null : 'per $unit',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalInputFormatter()],
            validator: (v) {
              final d = double.tryParse((v ?? '').trim());
              if (d == null || d <= 0) return 'Enter a price greater than 0';
              return null;
            },
          ),
          const SizedBox(height: 16),
          const PxLabel('Discount'),
          PxSegmented<String>(
            options: const [('none', 'None'), ('flat', 'Flat ₹'), ('percent', 'Percent %')],
            value: _discountType,
            onChanged: (v) {
              setState(() {
                _discountType = v;
                if (v == 'none') _discountValue.clear();
              });
              _scheduleDraft();
            },
          ),
          if (_discountType != 'none') ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PxTextField(
                    controller: _discountValue,
                    dense: true,
                    hint: _discountType == 'flat' ? 'Discount amount' : 'Discount %',
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: Text(_discountType == 'flat' ? '₹' : '%',
                          style: DT.text(size: 12, weight: FontWeight.w700, color: DT.slate500)),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [DecimalInputFormatter()],
                    validator: (v) {
                      final d = double.tryParse((v ?? '').trim());
                      if (d == null || d <= 0) return 'Enter the discount';
                      if (_discountType == 'percent' && d >= 100) return 'Must be under 100%';
                      if (_discountType == 'flat' && p != null && d >= p) {
                        return 'Must be less than the price';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                if (fp != null && p != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      fp > 0 ? 'Net: ${formatRupees(fp)}' : 'Invalid',
                      style: DT.text(
                          size: 12,
                          weight: FontWeight.w600,
                          color: fp > 0 ? PX.emerald600 : DT.error),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          PxLabel('GST slab',
              trailing: Text('Standard GST rates', style: DT.text(size: 11, color: DT.slate500))),
          Row(
            children: [
              for (final (i, g) in const [0.0, 5.0, 12.0, 18.0, 28.0].indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _gstChip(g)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const PxLabel('HSN code'),
          PxTextField(
            controller: _hsn,
            hint: 'HSN code (e.g. 8507)',
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

  Widget _gstChip(double g) {
    final sel = _gst == g;
    return GestureDetector(
      onTap: () {
        setState(() => _gst = sel ? null : g);
        _scheduleDraft();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? DT.onyx900 : Colors.white,
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: sel ? DT.onyx900 : DT.slate200),
          boxShadow: sel ? const [BoxShadow(color: Color(0x1A0F172A), blurRadius: 2)] : null,
        ),
        child: Text('${g.toStringAsFixed(0)}%',
            style: DT.text(
                size: 12,
                weight: sel ? FontWeight.w700 : FontWeight.w600,
                color: sel ? Colors.white : DT.onyx700)),
      ),
    );
  }

  // ── 4. Stock & shipping ─────────────────────────────────
  Widget _stockSection() {
    final unit = _unit?.shortName ?? _unit?.name;
    final dimsMissing = _submitAttempted &&
        (!_pos(_weight) || !_pos(_length) || !_pos(_width) || !_pos(_height));

    Widget dim(String label, TextEditingController c) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label *',
              style: DT.text(size: 11, weight: FontWeight.w600, color: DT.onyx600)),
          const SizedBox(height: 4),
          PxTextField(
            controller: c,
            hint: label[0],
            dense: true,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalInputFormatter()],
          ),
        ],
      ),
    );

    return PxSection(
      title: 'Stock & shipping',
      subtitle: 'Available quantity and packed size for shipping charges',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PxLabel('Stock quantity', required: true),
          PxTextField(
            controller: _stock,
            hint: 'Stock quantity',
            icon: Icons.inventory_outlined,
            iconColor: PX.royal600,
            bold: true,
            suffixText: unit,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(7),
            ],
            validator: (v) =>
            int.tryParse((v ?? '').trim()) == null ? 'Enter the stock quantity' : null,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xB3F8FAFC),
              borderRadius: BorderRadius.circular(DT.rMd),
              border: Border.all(color: dimsMissing ? DT.error : DT.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Packed weight & size',
                        style: DT.text(size: 12, weight: FontWeight.w700, color: DT.onyx800)),
                    const Spacer(),
                    Text('For shipping charges', style: DT.text(size: 11, color: DT.slate500)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: PxTextField(
                        controller: _weight,
                        hint: 'Weight *',
                        icon: Icons.scale_outlined,
                        dense: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [DecimalInputFormatter(decimals: 3)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PxSegmented<String>(
                      small: true,
                      selectedColor: PX.royal600,
                      options: const [('kg', 'kg'), ('g', 'g')],
                      value: _weightUnit,
                      onChanged: (v) {
                        setState(() => _weightUnit = v);
                        _scheduleDraft();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    dim('Length', _length),
                    const SizedBox(width: 8),
                    dim('Width', _width),
                    const SizedBox(width: 8),
                    dim('Height', _height),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: PxSegmented<String>(
                    small: true,
                    selectedColor: PX.royal600,
                    options: const [('cm', 'cm'), ('mm', 'mm')],
                    value: _dimUnit,
                    onChanged: (v) {
                      setState(() => _dimUnit = v);
                      _scheduleDraft();
                    },
                  ),
                ),
              ],
            ),
          ),
          if (dimsMissing)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Text('Enter weight, length, width and height',
                  style: DT.text(size: 11.5, color: DT.error)),
            ),
        ],
      ),
    );
  }

  // ── 5. Photos ───────────────────────────────────────────
  Widget _photosSection() {
    final thumbMissing = _submitAttempted && _thumb == null && _existingThumbUrl.isEmpty;
    final hasThumb = _thumbBytes != null || _existingThumbUrl.isNotEmpty;

    Widget thumbContent() {
      if (_thumbBytes != null) return Image.memory(_thumbBytes!, fit: BoxFit.cover);
      if (_existingThumbUrl.isNotEmpty) {
        return Image.network(_existingThumbUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image_outlined, color: DT.slate400));
      }
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PX.royal600.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.photo_camera_outlined, color: PX.royal600, size: 22),
          ),
          const SizedBox(height: 6),
          Text('Main photo *',
              style: DT.text(size: 12, weight: FontWeight.w700, color: PX.royal600)),
          Text('Primary angle',
              style: DT.text(size: 10, color: PX.royal600.withValues(alpha: 0.8))),
        ],
      );
    }

    return PxSection(
      title: 'Photos',
      subtitle: 'Clear photos sell better',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: DT.slate100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: DT.slate200),
        ),
        child: Text('$_photoCount / ${_maxImages + 1}',
            style: DT.text(size: 11.5, weight: FontWeight.w600, color: DT.onyx700)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickThumb,
                child: CustomPaint(
                  foregroundPainter: hasThumb
                      ? null
                      : _DashedRRectPainter(
                    color: thumbMissing ? DT.error : PX.royal600.withValues(alpha: 0.6),
                    radius: DT.rLg,
                  ),
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      color: hasThumb ? DT.slate100 : PX.royal50.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(DT.rLg),
                      border: hasThumb ? Border.all(color: DT.slate200) : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        thumbContent(),
                        if (hasThumb)
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: Container(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: DT.onyx900.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Change',
                                  style: DT.text(
                                      size: 10.5,
                                      weight: FontWeight.w700,
                                      color: Colors.white)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 128),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DT.slate50,
                    borderRadius: BorderRadius.circular(DT.rMd),
                    border: Border.all(color: DT.borderSoft),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.info_outline_rounded, size: 15, color: PX.royal600),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The main photo is shown in search and listings. Use a clean shot on '
                              'a plain white background. JPG or PNG up to 5MB.',
                          style: DT.text(size: 12, color: DT.onyx600, height: 1.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (thumbMissing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Main photo is required', style: DT.text(size: 11.5, color: DT.error)),
            ),
          const SizedBox(height: 16),
          const PxLabel('More photos'),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final img in _existingImages)
                  _photoTile(
                    child: Image.network(img.url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined, color: DT.slate400)),
                    marked: _deleteImageIds.contains(img.id),
                    onRemove: () => setState(() {
                      _deleteImageIds.contains(img.id)
                          ? _deleteImageIds.remove(img.id)
                          : _deleteImageIds.add(img.id);
                    }),
                  ),
                for (var i = 0; i < _imageBytes.length; i++)
                  _photoTile(
                    child: Image.memory(_imageBytes[i], fit: BoxFit.cover),
                    isNew: _isEdit,
                    onRemove: () => setState(() {
                      _images.removeAt(i);
                      _imageBytes.removeAt(i);
                    }),
                  ),
                if (_keptExistingImages + _images.length < _maxImages)
                  GestureDetector(
                    onTap: _pickImages,
                    child: CustomPaint(
                      foregroundPainter: const _DashedRRectPainter(color: DT.slate300, radius: DT.rMd),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(DT.rMd),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_outlined,
                                color: DT.slate500, size: 22),
                            const SizedBox(height: 3),
                            Text('Add',
                                style: DT.text(
                                    size: 10.5, weight: FontWeight.w600, color: DT.slate500)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_deleteImageIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  '${_deleteImageIds.length} photo(s) will be removed once the update is approved.',
                  style: DT.text(size: 11.5, color: DT.error)),
            ),
        ],
      ),
    );
  }

  Widget _photoTile({
    required Widget child,
    required VoidCallback onRemove,
    bool marked = false,
    bool isNew = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: DT.slate100,
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: marked ? DT.error : DT.slate200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: marked ? 0.35 : 1, child: child),
            if (marked)
              const Center(child: Icon(Icons.delete_outline_rounded, color: DT.error)),
            if (isNew)
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: DT.emerald700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('New',
                      style: DT.text(size: 9, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: marked ? PX.royal600 : DT.onyx900.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(marked ? Icons.undo_rounded : Icons.close_rounded,
                      size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 6. Specifications ───────────────────────────────────
  Widget _specsCard() {
    return PxSection(
      title: 'Specifications',
      icon: Icons.tune_rounded,
      compact: true,
      trailing: PxLinkButton(label: 'Add', icon: Icons.add_rounded, onTap: () => _editSpec()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Optional. e.g. Capacity: 150Ah, Voltage: 12V, Warranty: 36 months',
              style: DT.text(size: 12, color: DT.slate500, height: 1.45)),
          if (_specs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _specs.length; i++)
                  GestureDetector(
                    onTap: () => _editSpec(i),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                      decoration: BoxDecoration(
                        color: DT.slate100,
                        borderRadius: BorderRadius.circular(DT.rSm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${_specs[i].$1}: ${_specs[i].$2}',
                              style: DT.text(size: 12, weight: FontWeight.w500, color: DT.onyx700)),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() => _specs.removeAt(i));
                              _scheduleDraft();
                            },
                            child: const Icon(Icons.cancel_rounded, size: 15, color: DT.slate400),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _editSpec([int? index]) async {
    final existing = index == null ? null : _specs[index];
    final result = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DT.rXl)),
      ),
      builder: (_) => _SpecSheet(initial: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      var at = index;
      if (at != null) _specs.removeAt(at); // editing: drop the old row first
      // A spec with the same name elsewhere is replaced, not duplicated.
      final dup = _specs.indexWhere((s) => s.$1.toLowerCase() == result.$1.toLowerCase());
      if (dup != -1) {
        _specs.removeAt(dup);
        if (at != null && dup < at) at--;
      }
      if (at != null && at <= _specs.length) {
        _specs.insert(at, result);
      } else {
        _specs.add(result);
      }
    });
    _scheduleDraft();
  }

  // ── 7. Variants ─────────────────────────────────────────
  Widget _variantsCard() {
    final existing = widget.existing?.variants ?? const <MyProductVariant>[];
    return PxSection(
      title: 'Variants',
      icon: Icons.commit_rounded,
      compact: true,
      trailing: _isEdit
          ? null
          : PxLinkButton(label: 'Add', icon: Icons.add_rounded, onTap: () => _editVariant()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isEdit)
            Text(
              existing.isEmpty
                  ? 'No variants. Variants can only be added when creating a product.'
                  : 'Variants can\'t be changed through an update request yet.',
              style: DT.text(size: 12, color: DT.slate500, height: 1.45),
            )
          else if (_variants.isEmpty)
            Text(
              'Optional. Add when the product comes in options with their own price or stock, '
                  'e.g. 100Ah / 150Ah.',
              style: DT.text(size: 12, color: DT.slate500, height: 1.45),
            ),
          for (final v in existing) ...[
            const SizedBox(height: 8),
            _variantRow(
              title: v.title,
              subtitle: '${formatRupees(v.price)} · ${v.stock} in stock · ${v.sku}',
            ),
          ],
          for (var i = 0; i < _variants.length; i++) ...[
            const SizedBox(height: 8),
            _variantRow(
              title: _variants[i].title,
              subtitle: '${formatRupees(_variants[i].price)} · ${_variants[i].stock} in stock'
                  '${_variants[i].sku.isEmpty ? '' : ' · ${_variants[i].sku}'}',
              image: _variants[i].imageBytes,
              onEdit: () => _editVariant(i),
              onDelete: () {
                setState(() => _variants.removeAt(i));
                _scheduleDraft();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _variantRow({
    required String title,
    required String subtitle,
    Uint8List? image,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: DT.slate50,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.slate200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DT.rSm),
            child: SizedBox(
              width: 40,
              height: 40,
              child: image != null
                  ? Image.memory(image, fit: BoxFit.cover)
                  : const ColoredBox(
                  color: DT.slate100,
                  child: Icon(Icons.style_outlined, color: DT.slate400, size: 20)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: DT.text(size: 13, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 11.5, color: DT.slate500)),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18, color: PX.royal600)),
          if (onDelete != null)
            IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: DT.error)),
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
    _scheduleDraft();
  }

  // ── 8. More details ─────────────────────────────────────
  Widget _moreSection() {
    Future<void> pick(bool mfg) async {
      final now = DateTime.now();
      final d = await showDatePicker(
        context: context,
        initialDate: (mfg ? _mfgDate : _expDate) ?? now,
        firstDate: DateTime(now.year - 10),
        lastDate: DateTime(now.year + 15),
      );
      if (d == null) return;
      setState(() => mfg ? _mfgDate = d : _expDate = d);
      _scheduleDraft();
    }

    Widget dateTile(String label, IconData icon, DateTime? value, bool mfg, String empty) {
      // Dates can't be cleared through an update request (see header note).
      final canClear = value != null &&
          (!_isEdit ||
              (mfg ? widget.existing!.manufacturingDate : widget.existing!.expiryDate).isEmpty);
      return Expanded(
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DT.rMd),
            side: const BorderSide(color: DT.slate200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(DT.rMd),
            onTap: () => pick(mfg),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, size: 16, color: PX.royal600),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(label,
                            style: DT.text(
                                size: 11, weight: FontWeight.w600, color: DT.slate500)),
                      ),
                      if (canClear)
                        GestureDetector(
                          onTap: () {
                            setState(() => mfg ? _mfgDate = null : _expDate = null);
                            _scheduleDraft();
                          },
                          child: const Icon(Icons.close_rounded, size: 15, color: DT.slate400),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(value == null ? empty : _prettyDate(value),
                      style: DT.text(
                          size: 12,
                          weight: FontWeight.w700,
                          color: value == null ? DT.slate400 : DT.onyx800)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return PxSection(
      title: 'More details',
      subtitle: 'Manufacturing dates and dealership',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              dateTile('Manufactured', Icons.event_outlined, _mfgDate, true, 'Select date'),
              const SizedBox(width: 12),
              dateTile('Expires', Icons.event_available_outlined, _expDate, false,
                  'Does not expire'),
            ],
          ),
          const SizedBox(height: 12),
          PxTextField(
            controller: _bestBefore,
            hint: 'Best before / shelf life (e.g. 24 months)',
            icon: Icons.timelapse_rounded,
            inputFormatters: [LengthLimitingTextInputFormatter(50)],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0x99F8FAFC),
              borderRadius: BorderRadius.circular(DT.rMd),
              border: Border.all(color: DT.slate200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Franchise & distributorship',
                          style: DT.text(size: 12, weight: FontWeight.w700, color: DT.onyx900)),
                      const SizedBox(height: 2),
                      Text('Let buyers enquire about a franchise or dealership for this product',
                          style: DT.text(size: 11, color: DT.slate500, height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Switch(
                  value: _franchise,
                  onChanged: (v) {
                    setState(() => _franchise = v);
                    _scheduleDraft();
                  },
                  activeThumbColor: Colors.white,
                  activeTrackColor: DT.onyx900,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: DT.slate300,
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _notice(
            icon: Icons.verified_user_outlined,
            text: _isEdit
                ? 'Changes are reviewed by the admin before they go live. Buyers keep seeing '
                'the current listing until then.'
                : 'New products are reviewed by the admin before they are shown to buyers.',
          ),
        ],
      ),
    );
  }

  // ── Sticky footer ───────────────────────────────────────
  Widget _footer() {
    final left = _requiredLeft;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DT.slate200)),
        boxShadow: PX.stickyShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PX.royal600,
                    disabledBackgroundColor: PX.royal600.withValues(alpha: 0.55),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: const Color(0x401A68FA),
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
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                          _isEdit
                              ? 'Submit changes for review'
                              : 'Submit product for review',
                          style: DT.text(
                              size: 14, weight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : _isEdit
                        ? () => Navigator.maybePop(context)
                        : () => _saveDraft(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 32),
                    ),
                    child: Text(_isEdit ? 'Cancel' : 'Save as draft',
                        style: DT.text(size: 12, weight: FontWeight.w600, color: DT.slate500)),
                  ),
                  const Spacer(),
                  Text(
                    left == 0
                        ? '${_completion}% complete · ready to submit'
                        : '$left required field${left == 1 ? '' : 's'} left',
                    style: DT.text(
                        size: 11, color: left == 0 ? PX.emerald600 : DT.slate400),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// DASHED BORDER
// ===========================================================================
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  const _DashedRRectPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.6,
    this.dash = 6,
    this.gap = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth,
          size.height - strokeWidth),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}

// ===========================================================================
// SPEC SHEET
// ===========================================================================
class _SpecSheet extends StatefulWidget {
  final (String, String)? initial;
  const _SpecSheet({this.initial});

  @override
  State<_SpecSheet> createState() => _SpecSheetState();
}

class _SpecSheetState extends State<_SpecSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _key = TextEditingController(text: widget.initial?.$1 ?? '');
  late final _value = TextEditingController(text: widget.initial?.$2 ?? '');

  static const _suggest = ['Capacity', 'Voltage', 'Warranty', 'Material', 'Colour', 'Model'];

  @override
  void dispose() {
    _key.dispose();
    _value.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (_key.text.trim(), _value.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: DT.slate300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(widget.initial == null ? 'Add specification' : 'Edit specification',
                    style: DT.text(size: 17, weight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in _suggest)
                      ActionChip(
                        label: Text(s,
                            style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx700)),
                        backgroundColor: DT.slate50,
                        side: const BorderSide(color: DT.slate200),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _key.text = s),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const PxLabel('Name', required: true),
                PxTextField(
                  controller: _key,
                  hint: 'e.g. Capacity',
                  capitalization: TextCapitalization.words,
                  inputFormatters: [LengthLimitingTextInputFormatter(40)],
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                const PxLabel('Value', required: true),
                PxTextField(
                  controller: _value,
                  hint: 'e.g. 150Ah',
                  inputFormatters: [LengthLimitingTextInputFormatter(120)],
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a value' : null,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PX.royal600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
                    ),
                    child: Text('Save',
                        style: DT.text(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
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
      showCompanySnack(context, 'Add at least one option, e.g. Capacity: 150Ah', error: true);
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration:
                  BoxDecoration(color: DT.slate300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.existing == null ? 'Add variant' : 'Edit variant',
                  style: DT.text(size: 17, weight: FontWeight.w800)),
              const SizedBox(height: 14),
              const PxLabel('Options', required: true),
              for (var i = 0; i < _attrs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: PxTextField(
                          controller: _attrs[i].$1,
                          hint: 'Option (Capacity)',
                          dense: true,
                          capitalization: TextCapitalization.words,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PxTextField(
                          controller: _attrs[i].$2,
                          hint: 'Value (150Ah)',
                          dense: true,
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
                  child: PxLinkButton(
                    label: 'Add option',
                    icon: Icons.add_rounded,
                    onTap: () => setState(
                            () => _attrs.add((TextEditingController(), TextEditingController()))),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const PxLabel('Price', required: true),
                        PxTextField(
                          controller: _price,
                          bold: true,
                          prefix: Padding(
                            padding: const EdgeInsets.only(left: 12, right: 4),
                            child: Text('₹',
                                style: DT.text(
                                    size: 14, weight: FontWeight.w700, color: DT.onyx600)),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [DecimalInputFormatter()],
                          validator: (v) {
                            final d = double.tryParse((v ?? '').trim());
                            return (d == null || d <= 0) ? 'Enter price' : null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const PxLabel('Stock', required: true),
                        PxTextField(
                          controller: _stock,
                          bold: true,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(7),
                          ],
                          validator: (v) =>
                          int.tryParse((v ?? '').trim()) == null ? 'Enter stock' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const PxLabel('SKU', optional: true),
              PxTextField(
                controller: _sku,
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
                        borderRadius: BorderRadius.circular(DT.rMd),
                        border: Border.all(color: DT.slate200),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _imageBytes != null
                          ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                          : const Icon(Icons.add_photo_alternate_outlined, color: PX.royal600),
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
                    backgroundColor: PX.royal600,
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