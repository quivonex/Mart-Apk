// lib/screens/quick_add_flows.dart
//
// Drawer "Sell & Management" shortcuts that need context first:
//   Add Branch      -> pick company  -> BranchFormScreen
//   Add Category    -> pick company  -> CategoryFormScreen
//   Add SubCategory -> pick company  -> pick category -> SubCategoryFormScreen
//
// One company / category = picked automatically. None = offer to create one.

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/catalog_models.dart';
import '../models/company_model.dart';
import '../services/catalog_service.dart';
import '../services/company_service.dart';
import 'branch_screens.dart';
import 'category_screens.dart';
import 'company_create_edit_screen.dart';
import 'subcategory_screens.dart';

const _blue = Color(0xFF0D6EFD);

void _snack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? DT.error : null,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Shows a blocking loader while [task] runs.
Future<T> _withLoader<T>(BuildContext context, Future<T> Function() task) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const Center(child: CircularProgressIndicator(color: _blue)),
  );
  try {
    return await task();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}

Future<T?> _pickFromList<T>(
    BuildContext context, {
      required String title,
      required List<T> items,
      required String Function(T) label,
      String Function(T)? sublabel,
    }) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: DT.text(size: 17, weight: FontWeight.w800))),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 20),
                itemBuilder: (_, i) {
                  final it = items[i];
                  final sub = sublabel?.call(it) ?? '';
                  return ListTile(
                    title: Text(label(it), style: DT.text(size: 14.5, weight: FontWeight.w600)),
                    subtitle: sub.isEmpty ? null : Text(sub, style: DT.text(size: 12, color: DT.slate500)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pop(ctx, it),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Returns the company to work in, or null if the user cancelled / has none.
Future<Company?> pickCompany(BuildContext context, {required String forWhat}) async {
  final r = await _withLoader(context, CompanyService.getMyCompanies);
  if (!context.mounted) return null;
  if (!r.isSuccess) {
    _snack(context, r.message ?? 'Could not load your companies', error: true);
    return null;
  }
  final companies = r.data.where((c) => c.isActive).toList();
  if (companies.isEmpty) {
    final create = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a company first'),
        content: Text('You need a company before you can add a $forWhat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add company')),
        ],
      ),
    );
    if (create == true && context.mounted) {
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const CompanyCreateEditScreen()));
    }
    return null;
  }
  if (companies.length == 1) return companies.first;
  return _pickFromList<Company>(
    context,
    title: 'Add $forWhat for which company?',
    items: companies,
    label: (c) => c.name,
    sublabel: (c) => c.isPaid ? '' : 'Registration fee pending',
  );
}

Future<void> startAddBranch(BuildContext context) async {
  final c = await pickCompany(context, forWhat: 'branch');
  if (c == null || !context.mounted) return;
  final saved = await Navigator.push<CatalogBranch>(
    context,
    MaterialPageRoute(builder: (_) => BranchFormScreen(companyId: c.id, companyName: c.name)),
  );
  if (saved != null && context.mounted) _snack(context, 'Branch "${saved.name}" added to ${c.name}');
}

Future<void> startAddCategory(BuildContext context) async {
  final c = await pickCompany(context, forWhat: 'category');
  if (c == null || !context.mounted) return;
  final saved = await Navigator.push<CatalogCategory>(
    context,
    MaterialPageRoute(builder: (_) => CategoryFormScreen(companyId: c.id, companyName: c.name)),
  );
  if (saved != null && context.mounted) _snack(context, 'Category "${saved.name}" added to ${c.name}');
}

Future<void> startAddSubCategory(BuildContext context) async {
  final c = await pickCompany(context, forWhat: 'subcategory');
  if (c == null || !context.mounted) return;

  final r = await _withLoader(context, () => CatalogService.getCategories(c.id));
  if (!context.mounted) return;
  if (!r.ok) {
    _snack(context, r.message ?? 'Could not load categories', error: true);
    return;
  }

  CatalogCategory? category;
  if (r.items.isEmpty) {
    final create = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a category first'),
        content: Text('${c.name} has no categories yet. Subcategories belong to a category.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add category')),
        ],
      ),
    );
    if (create != true || !context.mounted) return;
    category = await Navigator.push<CatalogCategory>(
      context,
      MaterialPageRoute(builder: (_) => CategoryFormScreen(companyId: c.id, companyName: c.name)),
    );
    // The create API may not return the new row; reload and match by name.
    if (category != null && category.id == 0 && context.mounted) {
      final again = await CatalogService.getCategories(c.id);
      final name = category.name.toLowerCase();
      category = again.items.where((e) => e.name.toLowerCase() == name).firstOrNull ?? category;
    }
  } else if (r.items.length == 1) {
    category = r.items.first;
  } else {
    category = await _pickFromList<CatalogCategory>(
      context,
      title: 'Choose a category',
      items: r.items,
      label: (e) => e.name,
      sublabel: (e) => e.sublabel,
    );
  }
  if (category == null || category.id == 0 || !context.mounted) return;

  final saved = await Navigator.push<CatalogSubCategory>(
    context,
    MaterialPageRoute(builder: (_) => SubCategoryFormScreen(category: category!)),
  );
  if (saved != null && context.mounted) {
    _snack(context, 'Subcategory "${saved.name}" added to ${category.name}');
  }
}