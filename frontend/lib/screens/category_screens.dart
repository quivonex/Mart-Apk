// lib/screens/catalog/category_screens.dart
//
// CategoryManageScreen - a company's categories (mine, active / inactive)
// CategoryFormScreen   - create / edit, optional branch. Pops with the saved CatalogCategory.

import 'package:flutter/material.dart';
import '../../constants/design_tokens.dart';
import '../../models/catalog_models.dart';
import '../../services/catalog_service.dart';
import '../../widgets/catalog_widgets.dart';
import '../../widgets/company_ui.dart';
import 'subcategory_screens.dart';

class CategoryManageScreen extends StatefulWidget {
  final int companyId;
  final String companyName;

  const CategoryManageScreen({super.key, required this.companyId, required this.companyName});

  @override
  State<CategoryManageScreen> createState() => _CategoryManageScreenState();
}

class _CategoryManageScreenState extends State<CategoryManageScreen> {
  List<CatalogCategory> _items = [];
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
    final r = await CatalogService.getCategoriesForManage(widget.companyId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = r.items;
      _error = r.ok ? null : r.message;
    });
  }

  Future<void> _openForm([CatalogCategory? existing]) async {
    final saved = await Navigator.push<CatalogCategory>(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryFormScreen(
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

  Future<void> _openActions(CatalogCategory c) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DT.rXl)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text(c.name, style: DT.text(size: 16, weight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: DT.blue800),
              title: Text('Edit category', style: DT.text(size: 14, weight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.account_tree_outlined, color: DT.blue800),
              title: Text('Subcategories', style: DT.text(size: 14, weight: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, 'subs'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      _openForm(c);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SubCategoryManageScreen(category: c)),
      );
    }
  }

  Future<void> _toggle(CatalogCategory c) async {
    final ok = await catalogToggleActive(
      context,
      name: c.name,
      currentlyActive: c.isActive,
      call: () => CatalogService.setCategoryActive(c.id, !c.isActive),
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
        appBar: CompanyTopBar(title: 'Categories', subtitle: widget.companyName),
        floatingActionButton: _items.isEmpty
            ? null
            : FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: DT.blue800,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text('Add category',
              style: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
        ),
        body: CatalogManageList<CatalogCategory>(
          loading: _loading,
          error: _error,
          items: _items,
          emptyIcon: Icons.category_outlined,
          emptyTitle: 'No categories yet',
          emptyMessage: 'Categories group your products, e.g. Batteries, Inverters, Solar.',
          onRefresh: _load,
          onAdd: () => _openForm(),
          onEdit: _openActions,
          onToggleActive: _toggle,
        ),
      ),
    );
  }
}

// ===========================================================================
class CategoryFormScreen extends StatefulWidget {
  final int companyId;
  final String companyName;
  final CatalogCategory? existing;
  final int? presetBranchId;

  const CategoryFormScreen({
    super.key,
    required this.companyId,
    required this.companyName,
    this.existing,
    this.presetBranchId,
  });

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');

  List<CatalogBranch> _branches = [];
  CatalogBranch? _branch;
  bool _loadingBranches = true;
  String? _branchError;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _loadingBranches = true;
      _branchError = null;
    });
    final r = await CatalogService.getBranches(widget.companyId);
    if (!mounted) return;
    final wantId = widget.existing?.branchId ?? widget.presetBranchId;
    setState(() {
      _loadingBranches = false;
      _branches = r.items;
      _branchError = r.ok ? null : r.message;
      _branch = r.items.where((b) => b.id == wantId).firstOrNull;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final res = _isEdit
        ? await CatalogService.updateCategory(widget.existing!.id,
        name: _name.text.trim(), description: _desc.text.trim(), branchId: _branch?.id)
        : await CatalogService.createCategory(
        companyId: widget.companyId,
        name: _name.text.trim(),
        description: _desc.text.trim(),
        branchId: _branch?.id);

    if (!mounted) return;
    setState(() => _saving = false);
    showCompanySnack(context, res.message, error: !res.ok);
    if (res.ok) {
      Navigator.pop(
          context,
          res.data ??
              CatalogCategory(id: 0, companyId: widget.companyId, name: _name.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CatalogFormScaffold(
      title: _isEdit ? 'Edit category' : 'Add category',
      subtitle: widget.companyName,
      formKey: _formKey,
      saving: _saving,
      saveLabel: _isEdit ? 'Save changes' : 'Add category',
      onSave: _save,
      children: [
        CatalogTextField(
          controller: _name,
          label: 'Category name *',
          hint: 'e.g. Batteries',
          icon: Icons.category_outlined,
          capitalization: TextCapitalization.words,
          validator: (v) => (v ?? '').trim().length < 2 ? 'Enter the category name' : null,
        ),
        const SizedBox(height: 12),
        CatalogTextField(
          controller: _desc,
          label: 'Description',
          icon: Icons.notes_outlined,
          maxLines: 3,
          capitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        CatalogPickerField<CatalogBranch>(
          label: 'Branch',
          icon: Icons.store_mall_directory_outlined,
          items: _branches,
          selected: _branch,
          loading: _loadingBranches,
          error: _branchError,
          onRetry: _loadBranches,
          onChanged: (b) => setState(() => _branch = b),
        ),
        const SizedBox(height: 6),
        Text('Leave empty to use this category for the whole company.',
            style: DT.text(size: 11.5, color: DT.slate500)),
      ],
    );
  }
}