import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/unit_model.dart';
import '../services/unit_service.dart';

class UnitCreateEditScreen extends StatefulWidget {
  final Unit? existing;

  const UnitCreateEditScreen({super.key, this.existing});

  @override
  State<UnitCreateEditScreen> createState() =>
      _UnitCreateEditScreenState();
}

class _UnitCreateEditScreenState extends State<UnitCreateEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _shortNameCtrl = TextEditingController();

  bool _isSubmitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _nameCtrl.text = widget.existing!.name;
      _shortNameCtrl.text = widget.existing!.shortName;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _shortNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    UnitActionResponse res;

    if (_isEdit) {
      res = await UnitService.updateUnit(
        id: widget.existing!.id,
        name: _nameCtrl.text.trim(),
        shortName: _shortNameCtrl.text.trim(),
      );
    } else {
      res = await UnitService.createUnit(
        name: _nameCtrl.text.trim(),
        shortName: _shortNameCtrl.text.trim(),
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
          _isEdit ? 'Edit Unit' : 'Add Unit',
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
              _sectionTitle('Unit Information'),
              const SizedBox(height: 12),

              _field(
                _nameCtrl,
                'Unit Name *',
                'e.g. Kilogram',
                Icons.straighten_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Unit name is required';
                  }
                  if (v.trim().length < 2) {
                    return 'Minimum 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              _field(
                _shortNameCtrl,
                'Short Name *',
                'e.g. kg',
                Icons.short_text_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Short name is required';
                  }
                  if (v.trim().length > 10) {
                    return 'Maximum 10 characters';
                  }
                  return null;
                },
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
                    _isEdit ? 'Update Unit' : 'Create Unit',
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