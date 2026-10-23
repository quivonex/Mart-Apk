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
import 'branch_create_edit_screen.dart';
import 'category_screens.dart';
import 'company_create_edit_screen.dart';
import 'subcategory_create_edit_screen.dart';
import 'subcategory_screens.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kRed = Color(0xFFC62828);

const _blue = Color(0xFF093C71);

void _snack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _kRed : null,
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

// ===========================================================================
// ADD BRANCH — opens the branch form directly.
// Company is picked inside the form via the dropdown.
// ===========================================================================
Future<void> startAddBranch(BuildContext context) async {
  final saved = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => const BranchCreateEditScreen(),
    ),
  );
  if (saved == true && context.mounted) {
    _snack(context, 'Branch added successfully');
  }
}

// ===========================================================================
// ADD CATEGORY — opens the category form directly.
// Company is picked inside the form via the dropdown.
// ===========================================================================
Future<void> startAddCategory(BuildContext context) async {
  final saved = await Navigator.push<CatalogCategory>(
    context,
    MaterialPageRoute(
      builder: (_) => const CategoryFormScreen(),
    ),
  );
  if (saved != null && context.mounted) {
    _snack(context, 'Category "${saved.name}" added successfully');
  }
}

// ===========================================================================
// ADD SUBCATEGORY — opens the subcategory form directly.
// Company + category are picked inside the form via dropdowns.
// ===========================================================================
Future<void> startAddSubCategory(BuildContext context) async {
  final saved = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => const SubCategoryCreateEditScreen(),
    ),
  );
  if (saved == true && context.mounted) {
    _snack(context, 'Subcategory added successfully');
  }
}