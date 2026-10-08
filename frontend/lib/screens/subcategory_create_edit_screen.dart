import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/subcategory_model.dart';
import '../services/subcategory_service.dart';
import '../widgets/product_ui.dart';

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

  List<CategoryName> _categories = [];
  int? _selectedCategoryId;
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;

  static const _brand = Color(0xFF1A68FA);

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _selectedCategoryId = widget.existing!.effectiveCategoryId;
      _nameCtrl.text = widget.existing!.name;
      _descCtrl.text = widget.existing!.description;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    final res = await SubCategoryService.getCategoryNames();
    if (!mounted) return;
    setState(() {
      _isLoadingCategories = false;
      if (res.isSuccess) _categories = res.data;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
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
                icon: Icons.account_tree_outlined,
                title: _isEdit ? 'Edit subcategory' : 'New subcategory',
                subtitle:
                'Subcategories live inside a category, e.g. Car Batteries',
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
                          _isEdit ? 'Edit subcategory' : 'Add subcategory',
                          style: DT.text(
                              size: 18,
                              weight: FontWeight.w700,
                              color: DT.onyx900,
                              letterSpacing: -0.3),
                        ),
                        Text(
                          'Group products inside a category',
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

  Widget _categoryDropdown() {
    if (_isLoadingCategories) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DT.slate50,
          borderRadius: BorderRadius.circular(DT.rMd),
          border: Border.all(color: DT.slate200),
        ),
        child: const Row(
          children: [
            SizedBox(
              height: 18,
              width: 18,
              child:
              CircularProgressIndicator(strokeWidth: 2, color: _brand),
            ),
            SizedBox(width: 10),
            Text('Loading categories…'),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
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
                'No categories found. Please create a category first.',
                style: DT.text(size: 12, color: DT.error),
              ),
            ),
          ],
        ),
      );
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
    );
  }
}