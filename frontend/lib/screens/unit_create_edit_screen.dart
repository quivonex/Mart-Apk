import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';
import '../models/unit_model.dart';
import '../services/unit_service.dart';
import 'package:qnx_mart/l10n/app_language.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kBrandDark = Color(0xFF062A50);
const _kBrandLight = Color(0xFF1E5A9C);
const _kHeader = LinearGradient(
  colors: [_kBrandDark, _kBrand, _kBrandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

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
        content: Text(tr(msg)),
        backgroundColor:
        isError ? const Color(0xFFC62828) : Color(0xFF10B981),
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
        backgroundColor: _kBrand,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeader)),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isEdit ? tr('Edit Unit') : tr('Add Unit'),
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
              _sectionTitle(tr('Unit Information')),
              const SizedBox(height: 12),

              _field(
                _nameCtrl,
                tr('Unit Name *'),
                tr('e.g. Kilogram'),
                Icons.straighten_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return tr('Unit name is required');
                  }
                  if (v.trim().length < 2) {
                    return tr('Minimum 2 characters');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              _field(
                _shortNameCtrl,
                tr('Short Name *'),
                tr('e.g. kg'),
                Icons.short_text_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return tr('Short name is required');
                  }
                  if (v.trim().length > 10) {
                    return tr('Maximum 10 characters');
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
                    backgroundColor: _kBrand,
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
                    _isEdit ? tr('Update Unit') : tr('Create Unit'),
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
      tr(title),
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
      labelText: tr(label),
      prefixIcon: Icon(icon, color: _kBrand),
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
        const BorderSide(color: _kBrand, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFC62828), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFC62828), width: 2),
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
      decoration: _inputDecoration(label: tr(label), icon: icon)
          .copyWith(hintText: tr(hint)),
    );
  }
}