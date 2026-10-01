import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/subcategory_model.dart';
import '../services/subcategory_service.dart';

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

    if (res.isSuccess) {
      Navigator.pop(context, true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
        isError ? const Color(0xFFD32F2F) : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.surfaceColor,
      appBar: AppBar(
        backgroundColor: AppConstants.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEdit ? 'Edit Sub Category' : 'Add Sub Category',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Sub Category Information'),
              const SizedBox(height: 12),

              // Category dropdown
              _buildCategoryDropdown(),
              const SizedBox(height: 14),

              _field(
                _nameCtrl,
                'Sub Category Name *',
                'e.g. Mobile Phones',
                Icons.category_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Name is required';
                  }
                  if (v.trim().length < 2) {
                    return 'Minimum 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              _field(
                _descCtrl,
                'Description',
                'Enter description (optional)',
                Icons.description_outlined,
                maxLines: 4,
                validator: (_) => null,
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : Text(
                    _isEdit
                        ? 'Update Sub Category'
                        : 'Create Sub Category',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    if (_isLoadingCategories) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Row(
          children: [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Loading categories...'),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppConstants.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppConstants.error.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: AppConstants.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No categories found. Please contact admin.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppConstants.error,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedCategoryId,
      decoration: _inputDecoration(
        label: 'Category *',
        icon: Icons.folder_outlined,
      ),
      items: _categories.map((c) {
        return DropdownMenuItem<int>(
          value: c.id,
          child: Text(c.name),
        );
      }).toList(),
      onChanged: (v) => setState(() => _selectedCategoryId = v),
      validator: (v) => v == null ? 'Category is required' : null,
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppConstants.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppConstants.primary),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
        const BorderSide(color: AppConstants.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _field(
      TextEditingController ctrl,
      String label,
      String hint,
      IconData icon, {
        String? Function(String?)? validator,
        int maxLines = 1,
      }) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      maxLines: maxLines,
      decoration: _inputDecoration(label: label, icon: icon)
          .copyWith(hintText: hint),
    );
  }
}