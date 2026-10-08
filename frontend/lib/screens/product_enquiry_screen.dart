// lib/screens/product_enquiry_screen.dart
//
// Product enquiry – Material 3 premium layout matching the app
// (brand blue #1A68FA, page #F6F8FC, white cards, slate borders,
// Plus Jakarta Sans via DT.text).
// Logic unchanged: posts to ProductEnquiryService.submitEnquiry.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/design_tokens.dart';
import '../models/product_model.dart';
import '../models/product_enquiry_model.dart';
import '../services/product_enquiry_service.dart';
import '../widgets/product_ui.dart';

// M3 spacing scale used on this screen (multiples of 4).
class _S {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

class ProductEnquiryScreen extends StatefulWidget {
  final Product product;

  const ProductEnquiryScreen({super.key, required this.product});

  @override
  State<ProductEnquiryScreen> createState() => _ProductEnquiryScreenState();
}

class _ProductEnquiryScreenState extends State<ProductEnquiryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _personNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _messageCtrl = TextEditingController();
  final _referralCtrl = TextEditingController();

  String _demoRequired = 'no'; // 'yes' or 'no'
  String? _demoType; // 'at_location' or 'online'
  File? _attachment;
  bool _isLoading = false;

  static const int _maxMessage = 500;
  static const _brand = Color(0xFF1A68FA);
  static const _brandDark = Color(0xFF0D3880);

  @override
  void initState() {
    super.initState();
    _quantityCtrl.addListener(() => setState(() {})); // refresh estimate
    _messageCtrl.addListener(() => setState(() {})); // refresh counter
  }

  @override
  void dispose() {
    _personNameCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    _addressCtrl.dispose();
    _pincodeCtrl.dispose();
    _quantityCtrl.dispose();
    _messageCtrl.dispose();
    _referralCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Logic (unchanged)
  // ---------------------------------------------------------------------------
  int get _quantity => int.tryParse(_quantityCtrl.text.trim()) ?? 0;

  void _changeQuantity(int delta) {
    final next = (_quantity + delta).clamp(1, 99999);
    _quantityCtrl.text = next.toString();
    _quantityCtrl.selection =
        TextSelection.collapsed(offset: _quantityCtrl.text.length);
  }

  double? get _estimate {
    final price = double.tryParse(widget.product.finalPrice.toString());
    if (price == null || _quantity < 1) return null;
    return price * _quantity;
  }

  String _money(num v) {
    final isWhole = v == v.roundToDouble();
    return '₹${isWhole ? v.toInt() : v.toStringAsFixed(2)}';
  }

  Future<void> _pickAttachment() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final sizeInBytes = await file.length();
      if (sizeInBytes > 5 * 1024 * 1024) {
        _showSnackbar('File size must be under 5MB', isError: true);
        return;
      }
      if (!mounted) return;
      setState(() => _attachment = file);
    } catch (e) {
      _showSnackbar('Failed to pick file: $e', isError: true);
    }
  }

  void _removeAttachment() => setState(() => _attachment = null);

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _showSnackbar('Please fix the highlighted fields', isError: true);
      return;
    }

    if (_demoRequired == 'yes' && (_demoType == null || _demoType!.isEmpty)) {
      _showSnackbar('Choose how you want the demo', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final request = ProductEnquiryRequest(
      product: widget.product.id.toString(),
      personName: _personNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      contact: _contactCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      quantity: _quantityCtrl.text.trim(),
      message: _messageCtrl.text.trim(),
      demoRequired: _demoRequired,
      demoType: _demoRequired == 'yes' ? _demoType : null,
      price: widget.product.finalPrice,
      enquiryReferralCode:
      _referralCtrl.text.trim().isEmpty ? null : _referralCtrl.text.trim(),
      attachment: _attachment,
    );

    final response = await ProductEnquiryService.submitEnquiry(request);

    if (!mounted) return;
    setState(() => _isLoading = false);

    _showSnackbar(response.displayMessage, isError: !response.isSuccess);

    if (response.isSuccess) {
      Navigator.pop(context, true);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: _S.sm),
              Expanded(
                child: Text(
                  msg,
                  style: DT.text(
                      size: 13, weight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? DT.error : const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.all(_S.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DT.rMd),
          ),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: DT.background,
        appBar: _appBar(),
        body: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(_S.lg, _S.md, _S.lg, _S.xxl),
            children: [
              _buildHeader(),
              const SizedBox(height: _S.md),
              _buildContactSection(),
              const SizedBox(height: _S.md),
              _buildAddressSection(),
              const SizedBox(height: _S.md),
              _buildRequirementSection(),
              const SizedBox(height: _S.md),
              _buildDemoSection(),
              const SizedBox(height: _S.md),
              _buildExtrasSection(),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────
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
                        Text(
                          'Product enquiry',
                          style: DT.text(
                              size: 18,
                              weight: FontWeight.w700,
                              color: DT.onyx900,
                              letterSpacing: -0.3),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Send your requirement to the supplier',
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

  // ---------------------------------------------------------------------------
  // Header: product summary card
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(_S.md + 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.slate200),
        boxShadow: PX.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: DT.slate100,
              borderRadius: BorderRadius.circular(DT.rMd),
              border: Border.all(color: DT.slate200),
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.product.thumbnail.isNotEmpty
                ? Image.network(
              widget.product.thumbnail,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _thumbFallback(),
            )
                : _thumbFallback(),
          ),
          const SizedBox(width: _S.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are asking about',
                  style: DT.text(size: 11.5, color: DT.slate500),
                ),
                const SizedBox(height: _S.xs),
                Text(
                  widget.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(
                      size: 15,
                      weight: FontWeight.w700,
                      color: DT.onyx900,
                      height: 1.3),
                ),
                if (widget.product.companyName.isNotEmpty) ...[
                  const SizedBox(height: _S.xs),
                  Text(
                    'Sold by ${widget.product.companyName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 11.5, color: DT.slate500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: _S.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: _S.md, vertical: _S.sm),
            decoration: BoxDecoration(
              color: _brand,
              borderRadius: BorderRadius.circular(DT.rMd),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x331A68FA),
                    blurRadius: 8,
                    offset: Offset(0, 3)),
              ],
            ),
            child: Text(
              '₹${widget.product.finalPrice}',
              style: DT.text(
                  size: 14, weight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbFallback() => const Center(
    child: Icon(Icons.inventory_2_outlined, size: 28, color: DT.slate400),
  );

  // ---------------------------------------------------------------------------
  // Section: contact
  // ---------------------------------------------------------------------------
  Widget _buildContactSection() {
    return _SectionCard(
      icon: Icons.person_outline,
      title: 'Your contact details',
      subtitle: 'We will reach you here with a quote',
      children: [
        _textField(
          controller: _personNameCtrl,
          label: 'Full name',
          required: true,
          hint: 'John Doe',
          icon: Icons.person_outline_rounded,
          capitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter your name';
            if (v.trim().length < 2) return 'Name needs at least 2 characters';
            return null;
          },
        ),
        _textField(
          controller: _emailCtrl,
          label: 'Email',
          required: true,
          hint: 'john@example.com',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter your email';
            final re = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
            if (!re.hasMatch(v.trim())) return 'Enter a valid email address';
            return null;
          },
        ),
        _textField(
          controller: _contactCtrl,
          label: 'Mobile number',
          required: true,
          hint: '10-digit mobile number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter your mobile number';
            if (v.trim().length != 10) return 'Enter a 10-digit mobile number';
            return null;
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section: address
  // ---------------------------------------------------------------------------
  Widget _buildAddressSection() {
    return _SectionCard(
      icon: Icons.location_on_outlined,
      title: 'Delivery location',
      subtitle: 'Helps us check availability and shipping',
      children: [
        _textField(
          controller: _addressCtrl,
          label: 'Full address',
          required: true,
          hint: 'Street, area, landmark',
          icon: Icons.home_outlined,
          keyboardType: TextInputType.streetAddress,
          capitalization: TextCapitalization.sentences,
          maxLines: 3,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter your address';
            return null;
          },
        ),
        _textField(
          controller: _pincodeCtrl,
          label: 'Pincode',
          required: true,
          hint: '6-digit pincode',
          icon: Icons.pin_drop_outlined,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter your pincode';
            if (v.trim().length != 6) return 'Enter a 6-digit pincode';
            return null;
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section: requirement
  // ---------------------------------------------------------------------------
  Widget _buildRequirementSection() {
    final remaining = _messageCtrl.text.length;
    return _SectionCard(
      icon: Icons.edit_note_outlined,
      title: 'What do you need?',
      subtitle: 'Tell us quantity and any special requirements',
      children: [
        _buildQuantityStepper(),
        const SizedBox(height: _S.md),
        PxLabel(
          'Message',
          required: true,
          trailing: Text(
            '$remaining / $_maxMessage',
            style: DT.text(size: 11, color: DT.slate400),
          ),
        ),
        TextFormField(
          controller: _messageCtrl,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 5,
          minLines: 3,
          maxLength: _maxMessage,
          style: DT.text(size: 14, weight: FontWeight.w500, color: DT.onyx900),
          decoration: pxInputDecoration(
            hint: 'Describe your requirement (at least 10 characters)',
            tinted: true,
          ).copyWith(counterText: ''),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Tell us what you need';
            if (v.trim().length < 10) return 'Write at least 10 characters';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildQuantityStepper() {
    return FormField<String>(
      validator: (_) {
        final n = _quantity;
        if (_quantityCtrl.text.trim().isEmpty) return 'Enter a quantity';
        if (n < 1) return 'Minimum quantity is 1';
        return null;
      },
      builder: (state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quantity',
                        style: DT.text(
                            size: 13,
                            weight: FontWeight.w700,
                            color: DT.onyx700),
                      ),
                      const SizedBox(height: 2),
                      if (_estimate != null)
                        Text(
                          'Estimated total: ${_money(_estimate!)}',
                          style: DT.text(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: _brand),
                        )
                      else
                        Text(
                          'How many units do you need?',
                          style: DT.text(size: 11.5, color: DT.slate500),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: _S.sm),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(DT.rMd),
                    border: Border.all(
                      color: state.hasError ? DT.error : DT.slate200,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _stepperButton(Icons.remove, () => _changeQuantity(-1)),
                      SizedBox(
                        width: 52,
                        child: TextField(
                          controller: _quantityCtrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          onChanged: (_) => state.didChange(_quantityCtrl.text),
                          style: DT.text(
                              size: 16,
                              weight: FontWeight.w800,
                              color: DT.onyx900),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                            EdgeInsets.symmetric(vertical: _S.md),
                          ),
                        ),
                      ),
                      _stepperButton(Icons.add, () => _changeQuantity(1)),
                    ],
                  ),
                ),
              ],
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: _S.xs + 2, left: _S.xs),
                child: Text(
                  state.errorText!,
                  style: DT.text(size: 11.5, color: DT.error),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DT.rMd),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 20, color: _brand),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section: demo
  // ---------------------------------------------------------------------------
  Widget _buildDemoSection() {
    final wantsDemo = _demoRequired == 'yes';
    return _SectionCard(
      icon: Icons.play_circle_outline,
      title: 'Product demo',
      subtitle: 'See the product in action before you decide',
      children: [
        Row(
          children: [
            Expanded(
              child: _OptionTile(
                label: 'No demo needed',
                selected: !wantsDemo,
                onTap: () => setState(() {
                  _demoRequired = 'no';
                  _demoType = null;
                }),
              ),
            ),
            const SizedBox(width: _S.sm),
            Expanded(
              child: _OptionTile(
                label: 'Yes, I want a demo',
                selected: wantsDemo,
                onTap: () => setState(() => _demoRequired = 'yes'),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: wantsDemo
              ? Padding(
            padding: const EdgeInsets.only(top: _S.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How should we show it?',
                  style: DT.text(
                      size: 12,
                      weight: FontWeight.w700,
                      color: DT.onyx700),
                ),
                const SizedBox(height: _S.sm),
                Row(
                  children: [
                    Expanded(
                      child: _OptionTile(
                        icon: Icons.storefront_outlined,
                        label: 'At my location',
                        selected: _demoType == 'at_location',
                        onTap: () =>
                            setState(() => _demoType = 'at_location'),
                      ),
                    ),
                    const SizedBox(width: _S.sm),
                    Expanded(
                      child: _OptionTile(
                        icon: Icons.videocam_outlined,
                        label: 'Online',
                        selected: _demoType == 'online',
                        onTap: () =>
                            setState(() => _demoType = 'online'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section: extras
  // ---------------------------------------------------------------------------
  Widget _buildExtrasSection() {
    return _SectionCard(
      icon: Icons.attach_file,
      title: 'Optional extras',
      subtitle: 'Add a reference photo or a referral code',
      children: [
        _buildAttachmentPicker(),
        _textField(
          controller: _referralCtrl,
          label: 'Referral code',
          optional: true,
          hint: 'Enter a code if you have one',
          icon: Icons.card_giftcard_outlined,
          capitalization: TextCapitalization.characters,
          validator: (_) => null,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Attachment
  // ---------------------------------------------------------------------------
  Widget _buildAttachmentPicker() {
    if (_attachment == null) {
      return InkWell(
        onTap: _pickAttachment,
        borderRadius: BorderRadius.circular(DT.rMd),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              vertical: _S.xl + 2, horizontal: _S.lg),
          decoration: BoxDecoration(
            color: DT.blue50,
            borderRadius: BorderRadius.circular(DT.rMd),
            border: Border.all(color: DT.blue200),
          ),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_photo_alternate_outlined,
                    color: _brand, size: 24),
              ),
              const SizedBox(height: _S.sm + 2),
              Text(
                'Add a photo',
                style: DT.text(
                    size: 13.5, weight: FontWeight.w700, color: DT.onyx900),
              ),
              const SizedBox(height: 2),
              Text(
                'JPG, PNG or WebP, up to 5MB',
                style: DT.text(size: 11.5, color: DT.slate500),
              ),
            ],
          ),
        ),
      );
    }

    final name = _attachment!.path.split(RegExp(r'[\\/]')).last;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.slate200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DT.rSm),
            child: Image.file(
              _attachment!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 56,
                height: 56,
                color: DT.blue50,
                child: const Icon(Icons.insert_drive_file_outlined,
                    color: _brand),
              ),
            ),
          ),
          const SizedBox(width: _S.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(
                      size: 13, weight: FontWeight.w700, color: DT.onyx900),
                ),
                const SizedBox(height: 2),
                Text('Attached',
                    style: DT.text(size: 11.5, color: DT.slate500)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove photo',
            onPressed: _removeAttachment,
            icon: const Icon(Icons.close_rounded, color: DT.error, size: 20),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sticky bottom bar
  // ---------------------------------------------------------------------------
  Widget _buildBottomBar() {
    final estimate = _estimate;
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
          padding: const EdgeInsets.fromLTRB(_S.lg, _S.md, _S.lg, _S.md),
          child: Row(
            children: [
              if (estimate != null)
                Padding(
                  padding: const EdgeInsets.only(right: _S.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Estimated total',
                        style: DT.text(size: 11, color: DT.slate500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _money(estimate),
                        style: DT.text(
                            size: 18,
                            weight: FontWeight.w800,
                            color: DT.onyx900),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
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
                        const Icon(Icons.send_rounded, size: 18),
                        const SizedBox(width: _S.sm),
                        Text(
                          'Send enquiry',
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
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable field helper — standardizes label + field + spacing between fields
  // ---------------------------------------------------------------------------
  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool required = false,
    bool optional = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool tinted = false,
  }) {
    return Padding(
      // Standard M3 spacing between stacked form fields.
      padding: const EdgeInsets.only(top: _S.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PxLabel(label, required: required, optional: optional),
          TextFormField(
            controller: controller,
            keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
            textInputAction: textInputAction,
            textCapitalization: capitalization,
            inputFormatters: inputFormatters,
            validator: validator,
            minLines: maxLines > 1 ? maxLines : null,
            maxLines: maxLines,
            style:
            DT.text(size: 14, weight: FontWeight.w600, color: DT.onyx900),
            decoration: pxInputDecoration(
              hint: hint,
              icon: icon,
              iconColor: _brand,
              tinted: tinted,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Section card (M3 premium)
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.slate200),
        boxShadow: PX.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (icon + title + subtitle + divider)
          Container(
            padding: const EdgeInsets.only(bottom: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DT.slate100)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: DT.blue50,
                    borderRadius: BorderRadius.circular(DT.rMd),
                  ),
                  child: Icon(icon, size: 20, color: DT.blue800),
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
          // Children – the first child has no extra top gap; the helper
          // (_textField / stepper / option tiles) provides its own padding.
          ...children,
        ],
      ),
    );
  }
}

// =============================================================================
// Option tile
// =============================================================================
class _OptionTile extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DT.rMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
            horizontal: _S.md, vertical: _S.md + 2),
        decoration: BoxDecoration(
          color: selected ? DT.blue50 : DT.slate50,
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(
            color: selected ? DT.blue800 : DT.slate200,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: selected ? DT.blue800 : DT.slate500,
              ),
              const SizedBox(width: _S.xs + 2),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: DT.text(
                  size: 12.5,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? DT.blue800 : DT.onyx700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}