// lib/screens/catalog/branch_screens.dart
//
// BranchManageScreen  - list a company's branches (active / inactive), add, edit, (de)activate
// BranchFormScreen    - create / edit. Pops with the saved CatalogBranch.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/design_tokens.dart';
import '../../models/catalog_models.dart';
import '../../services/catalog_service.dart';
import '../../widgets/catalog_widgets.dart';
import '../../widgets/company_ui.dart';

class BranchManageScreen extends StatefulWidget {
  final int companyId;
  final String companyName;

  const BranchManageScreen({super.key, required this.companyId, required this.companyName});

  @override
  State<BranchManageScreen> createState() => _BranchManageScreenState();
}

class _BranchManageScreenState extends State<BranchManageScreen> {
  List<CatalogBranch> _items = [];
  bool _loading = true;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await CatalogService.getBranches(widget.companyId, activeOnly: false);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = r.items;
      _error = r.ok ? null : r.message;
    });
  }

  Future<void> _openForm([CatalogBranch? existing]) async {
    final saved = await Navigator.push<CatalogBranch>(
      context,
      MaterialPageRoute(
        builder: (_) => BranchFormScreen(
          companyId: widget.companyId,
          companyName: widget.companyName,
          existing: existing,
        ),
      ),
    );
    if (saved != null) {
      _changed = true;
      _load();
    }
  }

  Future<void> _toggle(CatalogBranch b) async {
    final ok = await catalogToggleActive(
      context,
      name: b.name,
      currentlyActive: b.isActive,
      call: () => CatalogService.setBranchActive(b.id, !b.isActive),
    );
    if (ok) {
      _changed = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: DT.background,
        appBar: CompanyTopBar(title: 'Branches', subtitle: widget.companyName),
        floatingActionButton: _items.isEmpty
            ? null
            : FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: DT.blue800,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text('Add branch',
              style: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
        ),
        body: CatalogManageList<CatalogBranch>(
          loading: _loading,
          error: _error,
          items: _items,
          emptyIcon: Icons.store_mall_directory_outlined,
          emptyTitle: 'No branches yet',
          emptyMessage: 'Add a branch if this company sells from more than one location.',
          onRefresh: _load,
          onAdd: () => _openForm(),
          onEdit: _openForm,
          onToggleActive: _toggle,
        ),
      ),
    );
  }
}

// ===========================================================================
class BranchFormScreen extends StatefulWidget {
  final int companyId;
  final String companyName;
  final CatalogBranch? existing;

  const BranchFormScreen({
    super.key,
    required this.companyId,
    required this.companyName,
    this.existing,
  });

  @override
  State<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends State<BranchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _phone = TextEditingController(text: widget.existing?.phone ?? '');
  late final _email = TextEditingController(text: widget.existing?.email ?? '');
  late final _address = TextEditingController(text: widget.existing?.address ?? '');
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final res = _isEdit
        ? await CatalogService.updateBranch(widget.existing!.id,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim())
        : await CatalogService.createBranch(
        companyId: widget.companyId,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim());

    if (!mounted) return;
    setState(() => _saving = false);
    showCompanySnack(context, res.message, error: !res.ok);
    if (res.ok) {
      Navigator.pop(
        context,
        res.data ??
            CatalogBranch(id: 0, companyId: widget.companyId, name: _name.text.trim()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CatalogFormScaffold(
      title: _isEdit ? 'Edit branch' : 'Add branch',
      subtitle: widget.companyName,
      formKey: _formKey,
      saving: _saving,
      saveLabel: _isEdit ? 'Save changes' : 'Add branch',
      onSave: _save,
      children: [
        CatalogTextField(
          controller: _name,
          label: 'Branch name *',
          hint: 'e.g. Pune Main Store',
          icon: Icons.store_outlined,
          capitalization: TextCapitalization.words,
          validator: (v) => (v ?? '').trim().length < 2 ? 'Enter the branch name' : null,
        ),
        const SizedBox(height: 12),
        CatalogTextField(
          controller: _phone,
          label: 'Phone',
          hint: '10-digit mobile',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            return RegExp(r'^[6-9]\d{9}$').hasMatch(t) ? null : 'Enter a valid 10-digit number';
          },
        ),
        const SizedBox(height: 12),
        CatalogTextField(
          controller: _email,
          label: 'Email',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return null;
            return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(t) ? null : 'Invalid email';
          },
        ),
        const SizedBox(height: 12),
        CatalogTextField(
          controller: _address,
          label: 'Address',
          icon: Icons.location_on_outlined,
          maxLines: 3,
          capitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}