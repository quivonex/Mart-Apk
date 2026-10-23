// lib/screens/remart_add_product_screen.dart
//
// QNX ReMart › Add Product – sell a used / resale item from the app.
//
//   1. Photos        (up to 10, first one is the cover)
//   2. Category      category -> subcategory -> extra fields from the backend
//                    + "Create attribute" (olx/attributes/create/) adds a new field
//   3. Item details  title, description, condition, seller type
//   4. Price         price + negotiable
//   5. Location      city, area, address, pincode
//   6. Listing plan  plan + price for the chosen category
//
// Save -> olx/listings/create/ (draft) -> Razorpay -> olx/payment/verify/ -> listing is live.
// If payment is cancelled the item stays saved; "Pay now" retries without creating it again.
// First listing: the backend makes it live for free (no plan / payment needed).
// Pops with `true` when an item was posted.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../constants/design_tokens.dart';
import '../services/remart_post_service.dart';
import '../utils/shared_preferences_helper.dart';
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
const _kOrangeDark = Color(0xFFC2410C);
const _kOrangeBg = Color(0xFFFFF7ED);
const _kOrangeLine = Color(0xFFFED7AA);
const _kHeader = LinearGradient(
  colors: [_kBrandDark, _kBrand, _kBrandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const _brand = Color(0xFF093C71);
const _brandDark = Color(0xFF062A50);
const _green = Color(0xFF10B981);
const _maxPhotos = 10;

class RemartAddProductScreen extends StatefulWidget {
  const RemartAddProductScreen({super.key});

  @override
  State<RemartAddProductScreen> createState() => _RemartAddProductScreenState();
}

class _RemartAddProductScreenState extends State<RemartAddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // photos
  final List<XFile> _photos = [];
  final List<Uint8List> _photoBytes = [];

  // category
  List<RemartOption> _categories = [];
  List<RemartOption> _subcategories = [];
  List<RemartAttribute> _attributes = [];
  int? _categoryId;
  int? _subcategoryId;
  bool _loadingCategories = true;
  bool _loadingSubcategories = false;
  bool _loadingAttributes = false;
  String? _categoryError;
  final Map<String, TextEditingController> _attrCtrls = {};
  final Map<String, dynamic> _attrValues = {};
  final Set<String> _newAttrKeys = {}; // fields created from this screen

  // details
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  String _condition = 'used';
  String _sellerType = 'individual';
  bool _negotiable = true;

  // plans
  List<RemartPlan> _plans = [];
  bool _loadingPlans = false;
  int? _planId;

  // submit
  bool _busy = false;
  String _busyText = '';
  int? _createdListingId; // set once the listing exists, so a retry only pays
  bool _showErrors = false;

  static const _conditions = <(String, String, IconData)>[
    ('new', 'New', Icons.fiber_new_rounded),
    ('like_new', 'Like new', Icons.auto_awesome_rounded),
    ('good', 'Good', Icons.thumb_up_alt_outlined),
    ('fair', 'Fair', Icons.handyman_outlined),
    ('used', 'Used', Icons.history_rounded),
  ];

  List<RemartPlan> get _pricedPlans => _plans.where((p) => (p.price ?? 0) > 0).toList();
  RemartPlan? get _plan => _pricedPlans.where((p) => p.id == _planId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _prefillCity();
    _checkFirstFree();
  }

  /// First ReMart listing is free (backend BazaarSettings.first_listing_free).
  bool _firstFree = false;

  Future<void> _checkFirstFree() async {
    final first = await RemartPostService.isFirstListing();
    if (!mounted || first != true) return;
    setState(() {
      _firstFree = true;
      _planId = null;
    });
  }

  Future<void> _prefillCity() async {
    final address = await SharedPreferencesHelper.getUserAddress();
    if (!mounted || address == null || _cityCtrl.text.isNotEmpty) return;
    final parts = address.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) _cityCtrl.text = parts[parts.length - 2];
  }

  @override
  void dispose() {
    for (final c in [_titleCtrl, _descCtrl, _priceCtrl, _cityCtrl, _areaCtrl, _addressCtrl, _pincodeCtrl]) {
      c.dispose();
    }
    for (final c in _attrCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ===================================================================
  // LOADERS
  // ===================================================================
  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _categoryError = null;
    });
    final r = await RemartPostService.categories();
    if (!mounted) return;
    setState(() {
      _loadingCategories = false;
      _categories = r.data ?? [];
      _categoryError = r.ok ? null : r.message;
    });
  }

  Future<void> _selectCategory(int id) async {
    if (_createdListingId != null || id == _categoryId) return;
    setState(() {
      _categoryId = id;
      _subcategoryId = null;
      _subcategories = [];
      _clearAttributes();
      _loadingSubcategories = true;
      _loadingPlans = true;
      _plans = [];
      _planId = null;
    });
    final results = await Future.wait([
      RemartPostService.subcategories(id),
      RemartPostService.plansFor(id),
    ]);
    if (!mounted || _categoryId != id) return;
    final subs = results[0] as RemartResult<List<RemartOption>>;
    final plans = results[1] as RemartResult<List<RemartPlan>>;
    setState(() {
      _loadingSubcategories = false;
      _subcategories = subs.data ?? [];
      _loadingPlans = false;
      _plans = plans.data ?? [];
      final priced = _pricedPlans;
      _planId = _firstFree || priced.isEmpty ? null : priced.first.id;
    });
  }

  Future<void> _selectSubcategory(int id) async {
    if (_createdListingId != null || _categoryId == null) return;
    setState(() {
      _subcategoryId = id;
      _clearAttributes();
      _loadingAttributes = true;
    });
    final r = await RemartPostService.attributes(_categoryId!, id);
    if (!mounted || _subcategoryId != id) return;
    setState(() {
      _loadingAttributes = false;
      _attributes = r.data ?? [];
      for (final a in _attributes) {
        _registerAttribute(a);
      }
    });
  }

  void _clearAttributes() {
    for (final c in _attrCtrls.values) {
      c.dispose();
    }
    _attrCtrls.clear();
    _attrValues.clear();
    _newAttrKeys.clear();
    _attributes = [];
  }

  void _registerAttribute(RemartAttribute a) {
    if (a.type == 'text' || a.type == 'number' || a.type == 'year') {
      _attrCtrls[a.key] ??= TextEditingController();
    } else if (a.type == 'boolean') {
      _attrValues[a.key] ??= false;
    }
  }

  Future<void> _openCreateAttribute() async {
    if (_createdListingId != null || _categoryId == null || _subcategoryId == null) return;
    final subName = _subcategories
        .firstWhere((o) => o.id == _subcategoryId, orElse: () => const RemartOption(0, ''))
        .name;
    final created = await showModalBottomSheet<RemartAttribute>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateAttributeSheet(
        categoryId: _categoryId!,
        subcategoryId: _subcategoryId!,
        subcategoryName: subName,
        takenKeys: {for (final a in _attributes) a.key},
        sortOrder: _attributes.length + 1,
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _attributes = [..._attributes, created];
      _registerAttribute(created);
      _newAttrKeys.add(created.key);
    });
    _snack('"${created.name}" added — fill it in below');
  }

  // ===================================================================
  // PHOTOS
  // ===================================================================
  Future<void> _addPhotos() async {
    final left = _maxPhotos - _photos.length;
    if (left <= 0) {
      _snack('You can add up to $_maxPhotos photos', error: true);
      return;
    }
    final source = await _pickSource();
    if (source == null) return;
    try {
      final List<XFile> picked;
      if (source == ImageSource.camera) {
        final shot = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1800);
        picked = shot == null ? [] : [shot];
      } else {
        picked = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 1800);
      }
      if (picked.isEmpty) return;
      final take = picked.take(left).toList();
      final bytes = await Future.wait(take.map((x) => x.readAsBytes()));
      if (!mounted) return;
      setState(() {
        _photos.addAll(take);
        _photoBytes.addAll(bytes);
      });
      if (picked.length > left) _snack('Only $left more photo${left == 1 ? '' : 's'} added (max $_maxPhotos)');
    } catch (e) {
      _snack('Could not open photos: $e', error: true);
    }
  }

  Future<ImageSource?> _pickSource() {
    if (kIsWeb) return Future.value(ImageSource.gallery);
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: DT.slate300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              Text('Add photos', style: DT.text(size: 16, weight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _sourceTile(ctx, Icons.photo_camera_outlined, 'Camera', ImageSource.camera)),
                  const SizedBox(width: 12),
                  Expanded(child: _sourceTile(ctx, Icons.photo_library_outlined, 'Gallery', ImageSource.gallery)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceTile(BuildContext ctx, IconData icon, String label, ImageSource src) => Material(
    color: _kTint,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.pop(ctx, src),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Icon(icon, color: _brand, size: 28),
            const SizedBox(height: 6),
            Text(label, style: DT.text(size: 13, weight: FontWeight.w700, color: _brandDark)),
          ],
        ),
      ),
    ),
  );

  void _removePhoto(int i) => setState(() {
    _photos.removeAt(i);
    _photoBytes.removeAt(i);
  });

  void _makeCover(int i) {
    if (i == 0) return;
    setState(() {
      _photos.insert(0, _photos.removeAt(i));
      _photoBytes.insert(0, _photoBytes.removeAt(i));
    });
  }

  // ===================================================================
  // SUBMIT
  // ===================================================================
  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white)),
        backgroundColor: error ? _kRed : DT.onyx900,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  String? _checkExtras() {
    if (_photos.isEmpty) return 'Add at least one photo';
    if (_categoryId == null) return 'Choose a category';
    if (_subcategories.isNotEmpty && _subcategoryId == null) return 'Choose a subcategory';
    for (final a in _attributes.where((a) => a.required)) {
      final v = _attrCtrls[a.key]?.text.trim() ?? _attrValues[a.key];
      if (v == null || (v is String && v.isEmpty)) return '${a.name} is required';
    }
    if (!_firstFree && _pricedPlans.isNotEmpty && _plan == null) return 'Choose a listing plan';
    return null;
  }

  Map<String, dynamic> _attributePayload() {
    final out = <String, dynamic>{};
    for (final a in _attributes) {
      final ctrl = _attrCtrls[a.key];
      if (ctrl != null) {
        final t = ctrl.text.trim();
        if (t.isEmpty) continue;
        out[a.key] = (a.type == 'number' || a.type == 'year') ? (num.tryParse(t) ?? t) : t;
      } else if (_attrValues.containsKey(a.key)) {
        out[a.key] = _attrValues[a.key];
      }
    }
    return out;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_createdListingId != null) {
      await _payAndFinish(_createdListingId!);
      return;
    }
    setState(() => _showErrors = true);
    final formOk = _formKey.currentState!.validate();
    final extra = _checkExtras();
    if (!formOk || extra != null) {
      _snack(extra ?? 'Please fix the highlighted fields', error: true);
      return;
    }

    setState(() {
      _busy = true;
      _busyText = 'Uploading ${_photos.length} photo${_photos.length == 1 ? '' : 's'}…';
    });
    final r = await RemartPostService.createListing(
      fields: {
        'category_id': '$_categoryId',
        if (_subcategoryId != null) 'subcategory_id': '$_subcategoryId',
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': _priceCtrl.text.trim(),
        'is_negotiable': _negotiable ? 'true' : 'false',
        'condition': _condition,
        'seller_type': _sellerType,
        'city': _cityCtrl.text.trim(),
        'area': _areaCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
      },
      attributes: _attributePayload(),
      images: _photos,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!r.ok || r.data == null) {
      _snack(r.ok ? 'Listing saved but no id was returned.' : r.message, error: true);
      return;
    }
    _createdListingId = r.data;

    // Free first listing → already live, skip the payment.
    final info = RemartPostService.lastCreated;
    if (info != null && info.id == r.data && info.isLive) {
      await _done(
        title: 'Your item is live!',
        message: info.freePeriodDays > 0
            ? '${_titleCtrl.text.trim()} is on QNX ReMart free for ${info.freePeriodDays} days.'
            : (info.message.isNotEmpty ? info.message : '${_titleCtrl.text.trim()} is now on QNX ReMart.'),
      );
      return;
    }
    if (_firstFree && _plan == null && _pricedPlans.isNotEmpty) {
      // Expected a free listing but the backend wants a plan – let the user pick one and pay.
      setState(() {
        _firstFree = false;
        _planId = _pricedPlans.first.id;
      });
      await _paymentPending(info?.message.isNotEmpty == true
          ? info!.message
          : 'This item needs a listing plan to go live.');
      return;
    }

    if (_plan == null) {
      await _done(
        title: 'Item submitted',
        message: 'Your item has been saved. It will appear on QNX ReMart once it is activated.',
      );
      return;
    }
    await _payAndFinish(r.data!);
  }

  Future<void> _payAndFinish(int listingId) async {
    final plan = _plan;
    if (plan == null) return;
    if (kIsWeb) {
      await _paymentPending('Online payment works in the QNX Mart Android app. Open the app to activate this item.');
      return;
    }

    setState(() {
      _busy = true;
      _busyText = 'Starting payment…';
    });
    final created = await RemartPostService.createPayment(listingId, plan.id);
    if (!mounted) return;
    if (!created.ok || created.data == null) {
      setState(() => _busy = false);
      await _paymentPending(created.message);
      return;
    }
    final d = created.data!;
    final orderId = '${d['razorpay_order_id'] ?? ''}';
    final key = '${d['razorpay_key'] ?? ''}';
    final amount = (d['amount_paise'] as num?)?.toInt() ?? int.tryParse('${d['amount_paise']}') ?? 0;
    if (orderId.isEmpty || key.isEmpty || amount <= 0) {
      setState(() => _busy = false);
      await _paymentPending('Payment could not be started.');
      return;
    }

    final email = await SharedPreferencesHelper.getUserEmail();
    final razorpay = Razorpay();
    final done = Completer<(PaymentSuccessResponse?, PaymentFailureResponse?)>();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (!done.isCompleted) done.complete((r, null));
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (!done.isCompleted) done.complete((null, r));
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      if (!done.isCompleted) done.complete((null, null));
    });
    try {
      razorpay.open({
        'key': key,
        'amount': amount,
        'currency': 'INR',
        'order_id': orderId,
        'name': 'QNX ReMart',
        'description': '${plan.name} · ${_titleCtrl.text.trim()}',
        'prefill': {if (email != null && email.isNotEmpty) 'email': email},
        'theme': {'color': '#1A68FA'},
        'retry': {'enabled': true, 'max_count': 2},
      });
    } catch (e) {
      razorpay.clear();
      if (mounted) setState(() => _busy = false);
      if (mounted) await _paymentPending('Could not open payment: $e');
      return;
    }

    final (success, failure) = await done.future;
    razorpay.clear();
    if (!mounted) return;
    if (success == null) {
      setState(() => _busy = false);
      final cancelled = failure != null && failure.code == Razorpay.PAYMENT_CANCELLED;
      await _paymentPending(cancelled
          ? 'Payment was cancelled.'
          : (failure?.message?.isNotEmpty == true ? 'Payment failed: ${failure!.message}' : 'Payment failed.'));
      return;
    }

    setState(() => _busyText = 'Confirming payment…');
    final v = await RemartPostService.verifyPayment(
      orderId: success.orderId ?? orderId,
      paymentId: success.paymentId ?? '',
      signature: success.signature ?? '',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!v.ok) {
      await _paymentPending('${v.message}\nIf money was deducted, contact support with reference ${success.paymentId}.');
      return;
    }
    await _done(
      title: 'Your item is live!',
      message: '${_titleCtrl.text.trim()} is now on QNX ReMart for ${plan.durationDays} days.',
    );
  }

  Future<void> _paymentPending(String reason) async {
    final retry = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: _kOrangeBg, shape: BoxShape.circle),
          child: const Icon(Icons.hourglass_top_rounded, color: _kOrangeDark, size: 28),
        ),
        title: Text('Item saved – payment pending',
            textAlign: TextAlign.center, style: DT.text(size: 17, weight: FontWeight.w800)),
        content: Text(
          '$reason\n\nYour item is saved but will go live only after the plan payment.',
          textAlign: TextAlign.center,
          style: DT.text(size: 13, color: DT.slate500, height: 1.45),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    foregroundColor: DT.onyx700,
                    side: const BorderSide(color: DT.slate200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Later'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: _kBrand, // buttons: only #093C71
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Pay now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (retry == true && !kIsWeb) {
      await _payAndFinish(_createdListingId!);
    } else {
      setState(() {}); // bottom bar switches to "Pay now"
    }
  }

  Future<void> _done({required String title, required String message}) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(color: DT.emerald50, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: DT.emerald700, size: 34),
        ),
        title: Text(title, textAlign: TextAlign.center, style: DT.text(size: 18, weight: FontWeight.w800)),
        content: Text(message,
            textAlign: TextAlign.center, style: DT.text(size: 13, color: DT.slate500, height: 1.45)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: _kBrand, // buttons: only #093C71
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  Future<bool> _confirmLeave() async {
    if (_busy) return false;
    final dirty = _photos.isNotEmpty || _titleCtrl.text.isNotEmpty || _categoryId != null;
    if (!dirty || _createdListingId != null) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this item?'),
        content: const Text('Your photos and details will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discard', style: DT.text(size: 14, weight: FontWeight.w700, color: _kRed)),
          ),
        ],
      ),
    );
    return leave == true;
  }

  // ===================================================================
  // BUILD
  // ===================================================================
  @override
  Widget build(BuildContext context) {
    final locked = _createdListingId != null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmLeave();
        if (ok && context.mounted) Navigator.pop(context, _createdListingId != null);
      },
      child: Scaffold(
        backgroundColor: DT.background,
        appBar: _appBar(),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: AbsorbPointer(
            absorbing: _busy || locked,
            child: Form(
              key: _formKey,
              autovalidateMode: _showErrors ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _hero(),
                  if (locked) ...[const SizedBox(height: 12), _lockedNote()],
                  const SizedBox(height: 16),
                  _photosSection(),
                  const SizedBox(height: 16),
                  _categorySection(),
                  if (_subcategoryId != null || _attributes.isNotEmpty || _loadingAttributes) ...[
                    const SizedBox(height: 16),
                    _attributesSection(),
                  ],
                  const SizedBox(height: 16),
                  _detailsSection(),
                  const SizedBox(height: 16),
                  _priceSection(),
                  const SizedBox(height: 16),
                  _locationSection(),
                  const SizedBox(height: 16),
                  _planSection(),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: _bottomBar(),
      ),
    );
  }

  PreferredSizeWidget _appBar() => PreferredSize(
    preferredSize: const Size.fromHeight(64),
    child: Container(
      decoration: const BoxDecoration(
        gradient: _kHeader,
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
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sell on QNX ReMart',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 18, weight: FontWeight.w700, letterSpacing: -0.3, color: Colors.white)),
                    Text('Used & resale items',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 12, color: const Color(0xFFC9DBEE))),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _hero() {
    final steps = [
      ('Photos', _photos.isNotEmpty),
      ('Category', _categoryId != null),
      ('Details', _titleCtrl.text.trim().length >= 3 && _priceCtrl.text.trim().isNotEmpty),
      ('Plan', _firstFree || (_pricedPlans.isEmpty ? _categoryId != null : _plan != null)),
    ];
    final doneCount = steps.where((s) => s.$2).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF062A50), _brand, Color(0xFF1E5A9C)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x33093C71), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.recycling_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Post your item',
                        style: DT.text(size: 16.5, weight: FontWeight.w800, color: Colors.white)),
                    Text('Good photos and a clear price sell faster',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 12, color: const Color(0xFFC9DBEE))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: doneCount / steps.length,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final s in steps)
                Expanded(
                  child: Row(
                    children: [
                      Icon(s.$2 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 14, color: s.$2 ? Colors.white : const Color(0xFFA3C1E0)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(s.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DT.text(
                                size: 11,
                                weight: FontWeight.w700,
                                color: s.$2 ? Colors.white : const Color(0xFFC9DBEE))),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lockedNote() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _kOrangeBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kOrangeLine),
    ),
    child: Row(
      children: [
        const Icon(Icons.lock_clock_outlined, color: _kOrangeDark, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Item saved. Complete the plan payment to make it live.',
              style: DT.text(size: 12.5, weight: FontWeight.w600, color: _kOrangeDark)),
        ),
      ],
    ),
  );

  // ---------------------------------------------------------------- photos
  Widget _photosSection() {
    final missing = _showErrors && _photos.isEmpty;
    return _Section(
      icon: Icons.photo_library_outlined,
      title: 'Photos',
      subtitle: '${_photos.length}/$_maxPhotos · first photo is the cover',
      error: missing ? 'Add at least one photo' : null,
      child: LayoutBuilder(builder: (context, box) {
        const gap = 10.0;
        final size = (box.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < _photos.length; i++) _photoTile(i, size),
            if (_photos.length < _maxPhotos)
              InkWell(
                onTap: _addPhotos,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: missing ? _kRedBg : _kTint,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: missing ? _kRedLine : _kLine, width: 1.4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: missing ? _kRed : _brand, size: 26),
                      const SizedBox(height: 6),
                      Text(_photos.isEmpty ? 'Add photos' : 'Add more',
                          style: DT.text(size: 12, weight: FontWeight.w700, color: missing ? _kRed : _brand)),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _photoTile(int i, double size) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _makeCover(i),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(_photoBytes[i], fit: BoxFit.cover),
            ),
          ),
        ),
        if (i == 0)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(99)),
              child: Text('Cover', style: DT.text(size: 10, weight: FontWeight.w800, color: Colors.white)),
            ),
          ),
        Positioned(
          right: 4,
          top: 4,
          child: GestureDetector(
            onTap: () => _removePhoto(i),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Color(0x99000000), shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );

  // ---------------------------------------------------------------- category
  Widget _categorySection() {
    Widget body;
    if (_loadingCategories) {
      body = const _Notice('Loading categories…', loading: true);
    } else if (_categoryError != null) {
      body = _Notice(_categoryError!, error: true, onRetry: _loadCategories);
    } else if (_categories.isEmpty) {
      body = const _Notice('No ReMart categories are available yet.', error: true);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Label('Category', required: true),
          _chips(_categories, _categoryId, _selectCategory),
          if (_categoryId != null) ...[
            const SizedBox(height: 16),
            if (_loadingSubcategories)
              const _Notice('Loading subcategories…', loading: true)
            else if (_subcategories.isNotEmpty) ...[
              const _Label('Subcategory', required: true),
              _chips(_subcategories, _subcategoryId, _selectSubcategory),
            ],
          ],
        ],
      );
    }
    final missing = _showErrors &&
        (_categoryId == null || (_subcategories.isNotEmpty && _subcategoryId == null));
    return _Section(
      icon: Icons.category_outlined,
      title: 'Category',
      subtitle: 'Where should buyers find it?',
      error: missing ? 'Choose a category and subcategory' : null,
      child: body,
    );
  }

  Widget _chips(List<RemartOption> items, int? selected, ValueChanged<int> onTap) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final o in items)
        ChoiceChip(
          label: Text(o.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          selected: o.id == selected,
          showCheckmark: false,
          selectedColor: _brand,
          backgroundColor: Colors.white,
          side: BorderSide(color: o.id == selected ? _brand : DT.slate200),
          shape: const StadiumBorder(),
          labelStyle: DT.text(
              size: 12.5, weight: FontWeight.w700, color: o.id == selected ? Colors.white : DT.onyx700),
          onSelected: (_) => onTap(o.id),
        ),
    ],
  );

  // ---------------------------------------------------------------- attributes
  Widget _attributesSection() {
    final locked = _createdListingId != null;
    final created = _attributes.where((a) => _newAttrKeys.contains(a.key)).toList();
    return _Section(
      icon: Icons.tune_rounded,
      title: 'More about the item',
      subtitle: 'Details buyers look for in this category',
      trailing: _loadingAttributes || locked || _subcategoryId == null
          ? null
          : _createAttributeButton(),
      child: _loadingAttributes
          ? const _Notice('Loading fields…', loading: true)
          : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_attributes.isEmpty)
            _emptyAttributes(locked)
          else
            for (var i = 0; i < _attributes.length; i++) ...[
              if (i > 0) const SizedBox(height: 14),
              _newAttrKeys.contains(_attributes[i].key)
                  ? _newBadgeWrap(_attributeField(_attributes[i]))
                  : _attributeField(_attributes[i]),
            ],
          if (created.isNotEmpty) ...[
            const SizedBox(height: 16),
            _createdSummary(created),
          ],
        ],
      ),
    );
  }

  Widget _createAttributeButton() => Material(
    color: _kTint,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: _openCreateAttribute,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_circle_outline_rounded, size: 15, color: _brand),
            const SizedBox(width: 4),
            Text('Create attribute', style: DT.text(size: 11.5, weight: FontWeight.w700, color: _brandDark)),
          ],
        ),
      ),
    ),
  );

  Widget _emptyAttributes(bool locked) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    decoration: BoxDecoration(
      color: DT.slate50,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: DT.slate200),
    ),
    child: Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: _kTint, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.playlist_add_rounded, color: _brand, size: 24),
        ),
        const SizedBox(height: 10),
        Text('No extra fields for this subcategory',
            textAlign: TextAlign.center,
            style: DT.text(size: 13, weight: FontWeight.w700, color: DT.onyx800)),
        const SizedBox(height: 4),
        Text('Add details like Brand, Model or Year so buyers can compare easily.',
            textAlign: TextAlign.center,
            style: DT.text(size: 11.5, color: DT.slate500, height: 1.4)),
        if (!locked) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: DecoratedBox(
              decoration: BoxDecoration(color: _kBrand, borderRadius: BorderRadius.circular(12)),
              child: ElevatedButton.icon(
                onPressed: _openCreateAttribute,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: Text('Create attribute',
                    style: DT.text(size: 13, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _newBadgeWrap(Widget field) => Stack(
    clipBehavior: Clip.none,
    children: [
      field,
      Positioned(
        right: 6,
        top: -8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Text('NEW', style: DT.text(size: 9, weight: FontWeight.w800, color: _green, letterSpacing: 0.6)),
        ),
      ),
    ],
  );

  Widget _createdSummary(List<RemartAttribute> created) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF1F9),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFC9DBEE)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF1E5A9C)),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Attributes you added (${created.length})',
                  style: DT.text(size: 12.5, weight: FontWeight.w800, color: const Color(0xFF062A50))),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final a in created) _attrChip(a)],
        ),
      ],
    ),
  );

  Widget _attrChip(RemartAttribute a) {
    final (icon, label) = _attrTypeMeta(a.type);
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFC9DBEE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF1E5A9C)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              [
                a.name,
                label,
                if (a.type == 'select' && a.options.isNotEmpty) '${a.options.length} options',
                if (a.required) 'required',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DT.text(size: 11.5, weight: FontWeight.w600, color: DT.onyx800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attributeField(RemartAttribute a) {
    switch (a.type) {
      case 'boolean':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: DT.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DT.slate200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(a.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 13.5, weight: FontWeight.w600, color: DT.onyx800)),
              ),
              Switch.adaptive(
                value: _attrValues[a.key] == true,
                activeTrackColor: _brand,
                onChanged: (v) => setState(() => _attrValues[a.key] = v),
              ),
            ],
          ),
        );
      case 'select':
        if (a.options.isEmpty) break;
        final sel = _attrValues[a.key] as String?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Label(a.name, required: a.required),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in a.options)
                  ChoiceChip(
                    label: Text(o, maxLines: 1, overflow: TextOverflow.ellipsis),
                    selected: sel == o,
                    showCheckmark: false,
                    selectedColor: _kTint,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: sel == o ? _brand : DT.slate200, width: sel == o ? 1.4 : 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    labelStyle:
                    DT.text(size: 12.5, weight: FontWeight.w700, color: sel == o ? _brandDark : DT.onyx700),
                    onSelected: (v) => setState(() => _attrValues[a.key] = v ? o : null),
                  ),
              ],
            ),
          ],
        );
    }
    final isNum = a.type == 'number' || a.type == 'year';
    final ctrl = _attrCtrls[a.key] ??= TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Label(a.name, required: a.required),
        TextFormField(
          controller: ctrl,
          keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          textCapitalization: isNum ? TextCapitalization.none : TextCapitalization.words,
          inputFormatters: [
            if (a.type == 'year') ...[FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
            if (a.type == 'number') FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: _inputStyle,
          decoration: _input(
            hint: a.type == 'year' ? 'e.g. ${DateTime.now().year - 2}' : 'Enter ${a.name.toLowerCase()}',
            icon: a.type == 'year' ? Icons.calendar_today_outlined : Icons.edit_note_rounded,
          ),
          validator: (v) {
            final t = (v ?? '').trim();
            if (a.required && t.isEmpty) return '${a.name} is required';
            if (a.type == 'year' && t.isNotEmpty) {
              final y = int.tryParse(t) ?? 0;
              if (y < 1900 || y > DateTime.now().year) return 'Enter a valid year';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- details
  Widget _detailsSection() => _Section(
    icon: Icons.inventory_2_outlined,
    title: 'Item details',
    subtitle: 'What are you selling?',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Title', required: true),
        TextFormField(
          controller: _titleCtrl,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          style: _inputStyle,
          decoration: _input(hint: 'e.g. Exide 150Ah inverter battery, 1 year old', icon: Icons.title_rounded)
              .copyWith(counterText: ''),
          validator: (v) => (v ?? '').trim().length < 5 ? 'Write a title of at least 5 characters' : null,
        ),
        const SizedBox(height: 14),
        const _Label('Description', required: true),
        TextFormField(
          controller: _descCtrl,
          minLines: 4,
          maxLines: 6,
          maxLength: 2000,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: _inputStyle.copyWith(fontWeight: FontWeight.w500),
          decoration: _input(
            hint: 'Condition, age, reason for selling, what is included…',
            tinted: true,
          ),
          validator: (v) => (v ?? '').trim().length < 20 ? 'Describe the item in at least 20 characters' : null,
        ),
        const SizedBox(height: 10),
        const _Label('Condition', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label, icon) in _conditions)
              ChoiceChip(
                avatar: Icon(icon, size: 16, color: _condition == value ? Colors.white : DT.slate500),
                label: Text(label),
                selected: _condition == value,
                showCheckmark: false,
                selectedColor: _brand,
                backgroundColor: Colors.white,
                side: BorderSide(color: _condition == value ? _brand : DT.slate200),
                shape: const StadiumBorder(),
                labelStyle: DT.text(
                    size: 12.5, weight: FontWeight.w700, color: _condition == value ? Colors.white : DT.onyx700),
                onSelected: (_) => setState(() => _condition = value),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const _Label('You are selling as', required: true),
        _segmented(
          [('individual', 'Individual', Icons.person_outline_rounded), ('business', 'Business', Icons.storefront_outlined)],
          _sellerType,
              (v) => setState(() => _sellerType = v),
        ),
      ],
    ),
  );

  Widget _segmented(List<(String, String, IconData)> items, String value, ValueChanged<String> onChanged) =>
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: DT.slate100, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            for (final (v, label, icon) in items)
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: value == v ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: value == v
                          ? const [BoxShadow(color: Color(0x140F172A), blurRadius: 6, offset: Offset(0, 2))]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, size: 17, color: value == v ? _brand : DT.slate500),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DT.text(
                                  size: 13, weight: FontWeight.w700, color: value == v ? DT.onyx900 : DT.slate500)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );

  // ---------------------------------------------------------------- price
  Widget _priceSection() => _Section(
    icon: Icons.currency_rupee_rounded,
    title: 'Price',
    subtitle: 'Set a fair price to sell quickly',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Price (₹)', required: true),
        TextFormField(
          controller: _priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,10}(\.\d{0,2})?')),
          ],
          onChanged: (_) => setState(() {}),
          style: DT.text(size: 18, weight: FontWeight.w800, color: DT.onyx900),
          decoration: _input(hint: '0').copyWith(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 6),
              child: Text('₹', style: DT.text(size: 18, weight: FontWeight.w800, color: _brand)),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          ),
          validator: (v) {
            final p = double.tryParse((v ?? '').trim());
            if (p == null || p <= 0) return 'Enter a price';
            return null;
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
          decoration: BoxDecoration(
            color: DT.slate50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DT.slate200),
          ),
          child: Row(
            children: [
              const Icon(Icons.handshake_outlined, color: _brand, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Price is negotiable',
                        style: DT.text(size: 13.5, weight: FontWeight.w700, color: DT.onyx800)),
                    Text('Buyers can make you an offer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 11.5, color: DT.slate500)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _negotiable,
                activeTrackColor: _brand,
                onChanged: (v) => setState(() => _negotiable = v),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ---------------------------------------------------------------- location
  Widget _locationSection() => _Section(
    icon: Icons.location_on_outlined,
    title: 'Location',
    subtitle: 'Buyers search by city',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Label('City', required: true),
                  TextFormField(
                    controller: _cityCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: _inputStyle,
                    decoration: _input(hint: 'e.g. Pune', icon: Icons.location_city_outlined),
                    validator: (v) => (v ?? '').trim().length < 2 ? 'Enter city' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Label('Pincode'),
                  TextFormField(
                    controller: _pincodeCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    style: _inputStyle,
                    decoration: _input(hint: '411001', icon: Icons.pin_drop_outlined),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return null;
                      return RegExp(r'^[1-9]\d{5}$').hasMatch(t) ? null : '6 digits';
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _Label('Area / locality'),
        TextFormField(
          controller: _areaCtrl,
          textCapitalization: TextCapitalization.words,
          style: _inputStyle,
          decoration: _input(hint: 'e.g. Hadapsar', icon: Icons.map_outlined),
        ),
        const SizedBox(height: 14),
        const _Label('Address'),
        TextFormField(
          controller: _addressCtrl,
          minLines: 2,
          maxLines: 3,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: _inputStyle.copyWith(fontWeight: FontWeight.w500),
          decoration: _input(hint: 'Shown only to buyers you talk to', tinted: true),
        ),
      ],
    ),
  );

  // ---------------------------------------------------------------- plan
  Widget _planSection() {
    Widget body;
    if (_firstFree) {
      body = Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: DT.emerald50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.celebration_rounded, color: _green, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your first listing is FREE',
                      style: DT.text(size: 14, weight: FontWeight.w800, color: DT.emerald700)),
                  const SizedBox(height: 2),
                  Text('No plan or payment needed – it goes live as soon as you post.',
                      style: DT.text(size: 12, color: DT.emerald700, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (_categoryId == null) {
      body = const _Notice('Choose a category to see listing plans.');
    } else if (_loadingPlans) {
      body = const _Notice('Loading plans…', loading: true);
    } else if (_pricedPlans.isEmpty) {
      body = const _Notice('No paid plan is set for this category. Your item will be saved and go live once it is activated.');
    } else {
      body = Column(
        children: [
          for (final p in _pricedPlans) ...[
            _planCard(p),
            const SizedBox(height: 10),
          ],
        ],
      );
    }
    return _Section(
      icon: Icons.workspace_premium_outlined,
      title: 'Listing plan',
      subtitle: 'How long your item stays live',
      child: body,
    );
  }

  Widget _planCard(RemartPlan p) {
    final sel = p.id == _planId;
    return Material(
      color: sel ? _kTint : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _planId = p.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? _brand : DT.slate200, width: sel ? 1.8 : 1),
          ),
          child: Row(
            children: [
              Icon(sel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: sel ? _brand : DT.slate300),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 14.5, weight: FontWeight.w800, color: DT.onyx900)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${p.durationDays} days live',
                        if (p.description.trim().isNotEmpty) p.description.trim(),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 12, color: DT.slate500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(_rupees(p.price ?? 0),
                  style: DT.text(size: 17, weight: FontWeight.w900, color: sel ? _brand : DT.onyx900)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- bottom bar
  Widget _bottomBar() {
    final plan = _plan;
    final locked = _createdListingId != null;
    final label = locked
        ? 'Pay ${_rupees(plan?.price ?? 0)} & go live'
        : (plan != null ? 'Post & pay ${_rupees(plan.price ?? 0)}' : (_firstFree ? 'Post item for free' : 'Post item'));
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DT.slate200)),
        boxShadow: [BoxShadow(color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (plan != null && !_busy)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${plan.durationDays} days', style: DT.text(size: 11.5, color: DT.slate500)),
                      Text(_rupees(plan.price ?? 0), style: DT.text(size: 18, weight: FontWeight.w900)),
                    ],
                  ),
                ),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _kBrand, // buttons: only #093C71
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Color(0x40093C71), blurRadius: 12, offset: Offset(0, 4))],
                    ),
                    child: ElevatedButton(
                      onPressed: _busy || (locked && plan == null) ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.transparent,
                        disabledForegroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _busy
                          ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(_busyText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
                          ),
                        ],
                      )
                          : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(locked || plan != null ? Icons.lock_rounded : Icons.upload_rounded, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DT.text(size: 15, weight: FontWeight.w700, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Screen design (private to this file)
// =====================================================================
String _rupees(double v) {
  final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final parts = s.split('.');
  var n = parts[0];
  if (n.length > 3) {
    final last3 = n.substring(n.length - 3);
    var rest = n.substring(0, n.length - 3);
    final g = <String>[];
    while (rest.length > 2) {
      g.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) g.insert(0, rest);
    n = '${g.join(',')},$last3';
  }
  return '₹$n${parts.length > 1 ? '.${parts[1]}' : ''}';
}

final TextStyle _inputStyle = DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900);

InputDecoration _input({String? hint, IconData? icon, bool tinted = false}) {
  OutlineInputBorder b(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
  return InputDecoration(
    hintText: hint,
    hintStyle: DT.text(size: 13.5, color: DT.slate400),
    hintMaxLines: 2,
    prefixIcon: icon == null ? null : Icon(icon, size: 19, color: _brand),
    filled: true,
    fillColor: tinted ? DT.slate50 : Colors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    enabledBorder: b(DT.slate200),
    focusedBorder: b(_brand, 2),
    errorBorder: b(_kRed),
    focusedErrorBorder: b(_kRed, 2),
    errorMaxLines: 2,
  );
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final String? error;
  final Widget? trailing;

  const _Section({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.error,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: error != null ? _kRedLine : DT.slate200),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: _kTint, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 19, color: _brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 14.5, weight: FontWeight.w700, color: DT.onyx900)),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 11.5, color: DT.slate500)),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Divider(height: 1, color: DT.slate100)),
          child,
          if (error != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 15, color: _kRed),
                const SizedBox(width: 6),
                Expanded(child: Text(error!, style: DT.text(size: 12, weight: FontWeight.w600, color: _kRed))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final bool required;
  const _Label(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        text: text,
        style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx700),
        children: [
          if (required) TextSpan(text: ' *', style: DT.text(size: 12, color: const Color(0xFFC62828))),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class _Notice extends StatelessWidget {
  final String text;
  final bool loading;
  final bool error;
  final VoidCallback? onRetry;
  const _Notice(this.text, {this.loading = false, this.error = false, this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: error ? _kRedBg : _kTint,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: error ? _kRedLine : _kLine),
    ),
    child: Row(
      children: [
        if (loading)
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _brand))
        else
          Icon(error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              size: 18, color: error ? _kRed : _kBrand),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: DT.text(size: 12.5, color: error ? _kRed : _kBrandDark, height: 1.4)),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Retry', style: DT.text(size: 12.5, weight: FontWeight.w700, color: error ? _kRed : _brand)),
          ),
      ],
    ),
  );
}

// =====================================================================
// CREATE ATTRIBUTE (olx/attributes/create/)
// =====================================================================
(IconData, String) _attrTypeMeta(String type) => switch (type) {
  'number' => (Icons.pin_outlined, 'Number'),
  'select' => (Icons.checklist_rounded, 'Options'),
  'boolean' => (Icons.toggle_on_outlined, 'Yes / No'),
  'year' => (Icons.calendar_today_outlined, 'Year'),
  _ => (Icons.short_text_rounded, 'Text'),
};

class _CreateAttributeSheet extends StatefulWidget {
  final int categoryId;
  final int subcategoryId;
  final String subcategoryName;
  final Set<String> takenKeys;
  final int sortOrder;

  const _CreateAttributeSheet({
    required this.categoryId,
    required this.subcategoryId,
    required this.subcategoryName,
    required this.takenKeys,
    required this.sortOrder,
  });

  @override
  State<_CreateAttributeSheet> createState() => _CreateAttributeSheetState();
}

class _CreateAttributeSheetState extends State<_CreateAttributeSheet> {
  static const _types = ['text', 'number', 'select', 'boolean', 'year'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _option = TextEditingController();
  final _optionFocus = FocusNode();
  String _type = 'text';
  bool _required = false;
  final List<String> _options = [];
  bool _saving = false;
  bool _tried = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _option.dispose();
    _optionFocus.dispose();
    super.dispose();
  }

  void _addOptions({bool refocus = true}) {
    final parts = _option.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    var added = false;
    for (final p in parts) {
      if (_options.length >= 30) break;
      if (_options.any((o) => o.toLowerCase() == p.toLowerCase())) continue;
      _options.add(p);
      added = true;
    }
    _option.clear();
    setState(() {});
    if (added && refocus) _optionFocus.requestFocus();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_option.text.trim().isNotEmpty) _addOptions(refocus: false);
    setState(() {
      _tried = true;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    if (_type == 'select' && _options.length < 2) {
      setState(() => _error = 'Add at least 2 options for a choice field');
      return;
    }
    setState(() => _saving = true);
    final r = await RemartPostService.createAttribute(
      categoryId: widget.categoryId,
      subcategoryId: widget.subcategoryId,
      name: _name.text,
      fieldType: _type,
      options: _options,
      isRequired: _required,
      sortOrder: widget.sortOrder,
    );
    if (!mounted) return;
    if (r.ok && r.data != null) {
      Navigator.pop(context, r.data);
    } else {
      setState(() {
        _saving = false;
        _error = r.message.toLowerCase().contains('already exists')
            ? 'An attribute with this name already exists for this subcategory.'
            : r.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(),
              Flexible(
                child: Form(
                  key: _formKey,
                  autovalidateMode: _tried ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
                  child: ListView(
                    shrinkWrap: true,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    children: [
                      const _Label('Attribute name', required: true),
                      TextFormField(
                        controller: _name,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [LengthLimitingTextInputFormatter(60)],
                        style: _inputStyle,
                        decoration: _input(hint: 'e.g. Brand, Fuel type, RAM', icon: Icons.label_outline_rounded),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Enter the attribute name';
                          if (t.length < 2) return 'Too short';
                          if (widget.takenKeys.contains(RemartAttribute.keyFrom(t))) {
                            return 'This field already exists in the form';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const _Label('Field type', required: true),
                      LayoutBuilder(builder: (context, c) {
                        const gap = 8.0;
                        final cols = c.maxWidth >= 380 ? 5 : 3;
                        final w = (c.maxWidth - gap * (cols - 1)) / cols;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [for (final t in _types) _typeTile(t, w)],
                        );
                      }),
                      if (_type == 'select') ...[
                        const SizedBox(height: 16),
                        const _Label('Options', required: true),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _option,
                                focusNode: _optionFocus,
                                textCapitalization: TextCapitalization.words,
                                style: _inputStyle,
                                decoration: _input(hint: 'Type an option (or a, b, c)', icon: Icons.add_task_rounded),
                                onSubmitted: (_) => _addOptions(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () => _addOptions(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kBrand, // buttons: only #093C71
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text('Add', style: DT.text(size: 13, weight: FontWeight.w700, color: Colors.white)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_options.isEmpty)
                          Text('No options yet — add at least 2.',
                              style: DT.text(size: 11.5, color: DT.slate500))
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < _options.length; i++)
                                InputChip(
                                  label: Text(_options[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                                  labelStyle: DT.text(size: 12, weight: FontWeight.w600, color: _brandDark),
                                  backgroundColor: _kTint,
                                  side: const BorderSide(color: _kLine),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  deleteIconColor: _brandDark,
                                  onDeleted: () => setState(() => _options.removeAt(i)),
                                ),
                            ],
                          ),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
                        decoration: BoxDecoration(
                          color: DT.slate50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: DT.slate200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.priority_high_rounded, size: 18, color: DT.slate500),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Required field',
                                      style: DT.text(size: 13, weight: FontWeight.w700, color: DT.onyx800)),
                                  Text('Sellers must fill this in',
                                      style: DT.text(size: 11, color: DT.slate500)),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _required,
                              activeTrackColor: _brand,
                              onChanged: (v) => setState(() => _required = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _preview(),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _Notice(_error!, error: true),
                      ],
                    ],
                  ),
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.fromLTRB(18, 10, 8, 16),
    decoration: const BoxDecoration(gradient: _kHeader),
    child: Column(
      children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.playlist_add_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create attribute',
                      style: DT.text(size: 16.5, weight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    widget.subcategoryName.isEmpty
                        ? 'New field for this subcategory'
                        : 'New field for ${widget.subcategoryName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 12, color: const Color(0xD9FFFFFF)),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _typeTile(String type, double width) {
    final (icon, label) = _attrTypeMeta(type);
    final sel = _type == type;
    return GestureDetector(
      onTap: () => setState(() {
        _type = type;
        _error = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? _kTint : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? _brand : DT.slate200, width: sel ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: sel ? _brand : DT.slate500),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DT.text(size: 11, weight: FontWeight.w700, color: sel ? _brandDark : DT.onyx700)),
          ],
        ),
      ),
    );
  }

  /// Small live preview of how the field will look in the form.
  Widget _preview() {
    final name = _name.text.trim().isEmpty ? 'Attribute name' : _name.text.trim();
    Widget field;
    switch (_type) {
      case 'boolean':
        field = Row(
          children: [
            Expanded(child: Text(name, style: DT.text(size: 13, weight: FontWeight.w600, color: DT.onyx800))),
            Switch.adaptive(value: true, activeTrackColor: _brand, onChanged: null),
          ],
        );
      case 'select':
        final opts = _options.isEmpty ? const ['Option 1', 'Option 2'] : _options.take(4).toList();
        field = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Label(name, required: _required),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < opts.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: i == 0 ? _kTint : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: i == 0 ? _brand : DT.slate200),
                    ),
                    child: Text(opts[i],
                        style: DT.text(size: 11.5, weight: FontWeight.w700, color: i == 0 ? _brandDark : DT.onyx700)),
                  ),
              ],
            ),
          ],
        );
      default:
        final (icon, _) = _attrTypeMeta(_type);
        field = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Label(name, required: _required),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DT.slate200),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: DT.slate400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _type == 'year'
                          ? 'e.g. ${DateTime.now().year - 2}'
                          : _type == 'number'
                          ? 'e.g. 128'
                          : 'Enter ${name.toLowerCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 12.5, color: DT.slate400),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DT.slate50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DT.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('PREVIEW', style: DT.text(size: 10, weight: FontWeight.w800, color: DT.slate500, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          field,
        ],
      ),
    );
  }

  Widget _footer() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: DT.slate200)),
    ),
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(color: _kBrand, borderRadius: BorderRadius.circular(14)),
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _saving
                ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 18, color: Colors.white),
            label: Text(_saving ? 'Creating…' : 'Create attribute',
                style: DT.text(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
          ),
        ),
      ),
    ),
  );
}
