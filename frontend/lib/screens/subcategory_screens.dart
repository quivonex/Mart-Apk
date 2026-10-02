// lib/screens/catalog/subcategory_screens.dart
//
// SubCategoryManageScreen - subcategories of one category (mine, active / inactive)
// SubCategoryFormScreen   - create / edit. Pops with the saved CatalogSubCategory.

import 'package:flutter/material.dart';
import '../../constants/design_tokens.dart';
import '../../models/catalog_models.dart';
import '../../services/catalog_service.dart';
import '../../widgets/catalog_widgets.dart';
import '../../widgets/company_ui.dart';

class SubCategoryManageScreen extends StatefulWidget {
  final CatalogCategory category;

  const SubCategoryManageScreen({super.key, required this.category});

  @override
  State<SubCategoryManageScreen> createState() => _SubCategoryManageScreenState();
}

class _SubCategoryManageScreenState extends State<SubCategoryManageScreen> {
  List<CatalogSubCategory> _items = [];
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
    final r = await CatalogService.getSubCategoriesForManage(widget.category.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = r.items;
      _error = r.ok ? null : r.message;
    });
  }

  Future<void> _openForm([CatalogSubCategory? existing]) async {
    final saved = await Navigator.push<CatalogSubCategory>(
      context,
      MaterialPageRoute(
        builder: (_) => SubCategoryFormScreen(category: widget.category, existing: existing),
      ),
    );
    if (saved != null) {
      _changed = true;
      _load();
    }
  }

  Future<void> _toggle(CatalogSubCategory s) async {
    final ok = await catalogToggleActive(
      context,
      name: s.name,
      currentlyActive: s.isActive,
      call: () => CatalogService.setSubCategoryActive(s.id, !s.isActive),
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
        appBar: CompanyTopBar(title: 'Subcategories', subtitle: widget.category.name),
        floatingActionButton: _items.isEmpty
            ? null
            : FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: DT.blue800,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text('Add subcategory',
              style: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
        ),
        body: CatalogManageList<CatalogSubCategory>(
          loading: _loading,
          error: _error,
          items: _items,
          emptyIcon: Icons.account_tree_outlined,
          emptyTitle: 'No subcategories yet',
          emptyMessage:
          'Split ${widget.category.name} into smaller groups, e.g. Car Batteries, Inverter Batteries.',
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
class SubCategoryFormScreen extends StatefulWidget {
  final CatalogCategory category;
  final CatalogSubCategory? existing;

  const SubCategoryFormScreen({super.key, required this.category, this.existing});

  @override
  State<SubCategoryFormScreen> createState() => _SubCategoryFormScreenState();
}

class _SubCategoryFormScreenState extends State<SubCategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final res = _isEdit
        ? await CatalogService.updateSubCategory(widget.existing!.id,
        categoryId: widget.category.id,
        name: _name.text.trim(),
        description: _desc.text.trim())
        : await CatalogService.createSubCategory(
        categoryId: widget.category.id,
        name: _name.text.trim(),
        description: _desc.text.trim());

    if (!mounted) return;
    setState(() => _saving = false);
    showCompanySnack(context, res.message, error: !res.ok);
    if (res.ok) {
      Navigator.pop(
          context,
          res.data ??
              CatalogSubCategory(
                  id: 0, categoryId: widget.category.id, name: _name.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CatalogFormScaffold(
      title: _isEdit ? 'Edit subcategory' : 'Add subcategory',
      subtitle: 'In ${widget.category.name}',
      formKey: _formKey,
      saving: _saving,
      saveLabel: _isEdit ? 'Save changes' : 'Add subcategory',
      onSave: _save,
      children: [
        CatalogTextField(
          controller: _name,
          label: 'Subcategory name *',
          hint: 'e.g. Inverter Batteries',
          icon: Icons.account_tree_outlined,
          capitalization: TextCapitalization.words,
          validator: (v) => (v ?? '').trim().length < 2 ? 'Enter the subcategory name' : null,
        ),
        const SizedBox(height: 12),
        CatalogTextField(
          controller: _desc,
          label: 'Description',
          icon: Icons.notes_outlined,
          maxLines: 3,
          capitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}