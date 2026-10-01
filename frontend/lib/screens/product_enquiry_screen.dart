import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_constants.dart';
import '../models/product_model.dart';
import '../models/product_enquiry_model.dart';
import '../services/product_enquiry_service.dart';

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
  // Logic
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor:
          isError ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
      child: Scaffold(
        backgroundColor: AppConstants.surfaceColor,
        appBar: AppBar(
          backgroundColor: AppConstants.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          title: Text(
            'Product enquiry',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildContactSection(),
              const SizedBox(height: 14),
              _buildAddressSection(),
              const SizedBox(height: 14),
              _buildRequirementSection(),
              const SizedBox(height: 14),
              _buildDemoSection(),
              const SizedBox(height: 14),
              _buildExtrasSection(),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header: product summary that overlaps the app bar
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Stack(
      children: [
        // Coloured band that continues from the app bar
        Positioned(
          left: -16,
          right: -16,
          top: 0,
          height: 46,
          child: Container(color: AppConstants.primary),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: AppConstants.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inventory_2_outlined,
                      color: AppConstants.primary, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You are asking about',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppConstants.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppConstants.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppConstants.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '₹${widget.product.finalPrice}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------
  Widget _buildContactSection() {
    return _SectionCard(
      icon: Icons.person_outline,
      title: 'Your contact details',
      subtitle: 'We will reach you here with a quote',
      children: [
        _buildField(
          controller: _personNameCtrl,
          label: 'Full name',
          hint: 'John Doe',
          icon: Icons.person_outline,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter your name';
            if (v.trim().length < 2) return 'Name needs at least 2 characters';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildField(
          controller: _emailCtrl,
          label: 'Email',
          hint: 'john@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter your email';
            final re = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
            if (!re.hasMatch(v.trim())) return 'Enter a valid email address';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildField(
          controller: _contactCtrl,
          label: 'Mobile number',
          hint: '10-digit mobile number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Enter your mobile number';
            }
            if (v.trim().length != 10) return 'Enter a 10-digit mobile number';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    return _SectionCard(
      icon: Icons.location_on_outlined,
      title: 'Delivery location',
      subtitle: 'Helps us check availability and shipping',
      children: [
        _buildField(
          controller: _addressCtrl,
          label: 'Full address',
          hint: 'Street, area, landmark',
          icon: Icons.home_outlined,
          maxLines: 3,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.streetAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Enter your address';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildField(
          controller: _pincodeCtrl,
          label: 'Pincode',
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

  Widget _buildRequirementSection() {
    final remaining = _messageCtrl.text.length;
    return _SectionCard(
      icon: Icons.edit_note_outlined,
      title: 'What do you need?',
      subtitle: 'Tell us quantity and any special requirements',
      children: [
        _buildQuantityStepper(),
        const SizedBox(height: 14),
        _buildField(
          controller: _messageCtrl,
          label: 'Message',
          hint: 'Describe your requirement (at least 10 characters)',
          icon: Icons.message_outlined,
          maxLines: 5,
          minLines: 3,
          maxLength: _maxMessage,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
          counterText: '$remaining / $_maxMessage',
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Tell us what you need';
            }
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
              children: [
                Expanded(
                  child: Text(
                    'Quantity',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppConstants.textPrimary,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: state.hasError
                          ? Colors.red
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _stepperButton(Icons.remove, () => _changeQuantity(-1)),
                      SizedBox(
                        width: 56,
                        child: TextField(
                          controller: _quantityCtrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          onChanged: (_) => state.didChange(_quantityCtrl.text),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppConstants.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                            EdgeInsets.symmetric(vertical: 12),
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
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  state.errorText!,
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.red),
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, size: 20, color: AppConstants.primary),
      ),
    );
  }

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
            const SizedBox(width: 10),
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
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How should we show it?',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
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
                    const SizedBox(width: 10),
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

  Widget _buildExtrasSection() {
    return _SectionCard(
      icon: Icons.attach_file,
      title: 'Optional extras',
      subtitle: 'Add a reference photo or a referral code',
      children: [
        _buildAttachmentPicker(),
        const SizedBox(height: 14),
        _buildField(
          controller: _referralCtrl,
          label: 'Referral code',
          hint: 'Enter a code if you have one',
          icon: Icons.card_giftcard_outlined,
          textCapitalization: TextCapitalization.characters,
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: AppConstants.primary.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppConstants.primary.withOpacity(0.35),
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  color: AppConstants.primary, size: 30),
              const SizedBox(height: 8),
              Text(
                'Add a photo',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppConstants.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'JPG, PNG or WebP, up to 5MB',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppConstants.textSecondary,
                ),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              _attachment!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 56,
                height: 56,
                color: AppConstants.primary.withOpacity(0.08),
                child: Icon(Icons.insert_drive_file_outlined,
                    color: AppConstants.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Attached',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove photo',
            onPressed: _removeAttachment,
            icon: const Icon(Icons.close, color: AppConstants.error, size: 20),
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
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              if (estimate != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Estimated total',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppConstants.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _money(estimate),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppConstants.textPrimary,
                        ),
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
                      backgroundColor: AppConstants.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                      AppConstants.primary.withOpacity(0.6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Send enquiry',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
  // Shared field builder
  // ---------------------------------------------------------------------------
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? minLines,
    int? maxLength,
    String? counterText,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      validator: validator,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      buildCounter: counterText == null
          ? null
          : (_, {required currentLength, required isFocused, maxLength}) =>
          Text(
            counterText,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppConstants.textSecondary,
            ),
          ),
      style: GoogleFonts.inter(
        fontSize: 15,
        color: AppConstants.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppConstants.textLight,
        ),
        prefixIcon: maxLines > 1
            ? Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: Icon(icon, color: AppConstants.primary, size: 22),
        )
            : Icon(icon, color: AppConstants.primary, size: 22),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
        filled: true,
        fillColor: const Color(0xFFFAFAFB),
        border: border(Colors.grey.shade300),
        enabledBorder: border(Colors.grey.shade300),
        focusedBorder: border(AppConstants.primary, 1.8),
        errorBorder: border(Colors.red),
        focusedErrorBorder: border(Colors.red, 1.8),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppConstants.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppConstants.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

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
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppConstants.primary.withOpacity(0.08)
              : const Color(0xFFFAFAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppConstants.primary : Colors.grey.shade300,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: selected
                    ? AppConstants.primary
                    : AppConstants.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppConstants.primary
                      : AppConstants.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}