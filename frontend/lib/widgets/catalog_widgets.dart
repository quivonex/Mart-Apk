// lib/widgets/catalog_widgets.dart
//
// Shared UI for the product form and the catalog master screens.
//   CatalogPickerField  - tap-to-pick field with search, "+ Add new" and "Manage"
//   CatalogManageList   - list body with Active/Inactive filter, edit, (de)activate
//   CatalogFormScaffold - simple form page with a sticky save button
//   CatalogTextField    - text field styled like the rest of the module

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/design_tokens.dart';
import '../models/catalog_models.dart';
import 'company_ui.dart';

// ===========================================================================
// PICKER FIELD
// ===========================================================================
class CatalogPickerField<T extends CatalogOption> extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool required;
  final T? selected;
  final List<T> items;
  final bool loading;
  final String? error;
  final bool enabled;
  final String? disabledHint;
  final bool showRequiredError;
  final ValueChanged<T?> onChanged;
  final Future<void> Function()? onAddNew;
  final VoidCallback? onManage;
  final VoidCallback? onRetry;

  const CatalogPickerField({
    super.key,
    required this.label,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.selected,
    this.required = false,
    this.loading = false,
    this.error,
    this.enabled = true,
    this.disabledHint,
    this.showRequiredError = false,
    this.onAddNew,
    this.onManage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final missing = showRequiredError && required && enabled && selected == null && !loading;
    final hasError = error != null || missing;

    String hint;
    if (!enabled) {
      hint = disabledHint ?? 'Select $label';
    } else if (loading) {
      hint = 'Loading…';
    } else if (items.isEmpty) {
      hint = onAddNew != null ? 'None yet – tap to add' : 'None available';
    } else {
      hint = 'Select ${label.toLowerCase()}';
    }

    final canTap = enabled && !loading && (items.isNotEmpty || onAddNew != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(required ? '$label *' : label,
                style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx600)),
            if (!required) ...[
              const SizedBox(width: 4),
              Text('(optional)', style: DT.text(size: 11, color: DT.slate400)),
            ],
            const Spacer(),
            if (onManage != null && enabled)
              GestureDetector(
                onTap: onManage,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text('Manage',
                      style: DT.text(size: 11.5, weight: FontWeight.w700, color: DT.blue800)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Material(
          color: enabled ? Colors.white : DT.slate100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DT.rMd),
            side: BorderSide(
              color: hasError ? DT.error : (selected != null ? DT.blue800 : DT.border),
              width: selected != null ? 1.3 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(DT.rMd),
            onTap: canTap ? () => _open(context) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: enabled ? DT.blue800 : DT.slate400),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selected?.label ?? hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(
                        size: 13.5,
                        weight: selected != null ? FontWeight.w600 : FontWeight.w500,
                        color: selected != null
                            ? DT.onyx900
                            : (enabled ? DT.slate400 : DT.slate400),
                      ),
                    ),
                  ),
                  if (loading)
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: DT.blue800))
                  else if (selected != null && !required)
                    GestureDetector(
                      onTap: () => onChanged(null),
                      child: const Icon(Icons.close_rounded, size: 18, color: DT.slate400),
                    )
                  else
                    Icon(Icons.expand_more_rounded,
                        color: canTap ? DT.slate500 : DT.slate300),
                ],
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: DT.error),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(error!, style: DT.text(size: 11.5, color: DT.error))),
                if (onRetry != null)
                  GestureDetector(
                    onTap: onRetry,
                    child: Text('Retry',
                        style: DT.text(size: 11.5, weight: FontWeight.w700, color: DT.blue800)),
                  ),
              ],
            ),
          )
        else if (missing)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Text('$label is required', style: DT.text(size: 11.5, color: DT.error)),
          ),
      ],
    );
  }

  Future<void> _open(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<_PickerResult<T>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DT.rXl)),
      ),
      builder: (ctx) => _PickerSheet<T>(
        title: label,
        items: items,
        selectedId: selected?.id,
        canAdd: onAddNew != null,
      ),
    );
    if (result == null) return;
    if (result.addNew) {
      await onAddNew?.call();
    } else {
      onChanged(result.item);
    }
  }
}

class _PickerResult<T> {
  final T? item;
  final bool addNew;
  _PickerResult.item(this.item) : addNew = false;
  _PickerResult.add()
      : item = null,
        addNew = true;
}

class _PickerSheet<T extends CatalogOption> extends StatefulWidget {
  final String title;
  final List<T> items;
  final int? selectedId;
  final bool canAdd;

  const _PickerSheet({
    required this.title,
    required this.items,
    required this.selectedId,
    required this.canAdd,
  });

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T extends CatalogOption> extends State<_PickerSheet<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.items
        : widget.items.where((e) => e.label.toLowerCase().contains(q)).toList();
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration:
              BoxDecoration(color: DT.slate300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Select ${widget.title.toLowerCase()}',
                        style: DT.text(size: 16.5, weight: FontWeight.w800)),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: DT.slate500)),
                ],
              ),
            ),
            if (widget.items.length > 6)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  style: DT.text(size: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: DT.text(size: 13.5, color: DT.slate400),
                    prefixIcon: const Icon(Icons.search_rounded, color: DT.slate400),
                    filled: true,
                    fillColor: DT.slate50,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DT.rMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            if (widget.canAdd)
              ListTile(
                leading: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: DT.blue50, borderRadius: BorderRadius.circular(DT.rSm)),
                  child: const Icon(Icons.add_rounded, color: DT.blue800, size: 20),
                ),
                title: Text('Add new ${widget.title.toLowerCase()}',
                    style: DT.text(size: 14, weight: FontWeight.w700, color: DT.blue800)),
                onTap: () => Navigator.pop(context, _PickerResult<T>.add()),
              ),
            const Divider(height: 1, color: DT.border),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                child: Text(
                  widget.items.isEmpty ? 'Nothing here yet' : 'No match for "$_q"',
                  style: DT.text(size: 13, color: DT.slate500),
                ),
              )
                  : ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: DT.slate100),
                itemBuilder: (_, i) {
                  final item = filtered[i];
                  final sel = item.id == widget.selectedId;
                  return ListTile(
                    title: Text(item.label,
                        style: DT.text(
                            size: 14,
                            weight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? DT.blue800 : DT.onyx900)),
                    subtitle: item.sublabel.isEmpty
                        ? null
                        : Text(item.sublabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 12, color: DT.slate500)),
                    trailing: sel
                        ? const Icon(Icons.check_circle_rounded, color: DT.blue800)
                        : null,
                    onTap: () => Navigator.pop(context, _PickerResult<T>.item(item)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// MANAGE LIST (body for the 4 list screens)
// ===========================================================================
class CatalogManageList<T extends CatalogOption> extends StatefulWidget {
  final bool loading;
  final String? error;
  final List<T> items;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;
  final Future<void> Function() onRefresh;
  final VoidCallback onAdd;
  final ValueChanged<T> onEdit;
  final ValueChanged<T> onToggleActive;
  final Widget? header;

  const CatalogManageList({
    super.key,
    required this.loading,
    required this.error,
    required this.items,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onRefresh,
    required this.onAdd,
    required this.onEdit,
    required this.onToggleActive,
    this.header,
  });

  @override
  State<CatalogManageList<T>> createState() => _CatalogManageListState<T>();
}

class _CatalogManageListState<T extends CatalogOption> extends State<CatalogManageList<T>> {
  bool _showInactive = false;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: DT.blue800));
    }
    if (widget.error != null && widget.items.isEmpty) {
      return StateView(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load',
        message: widget.error!,
        actionLabel: 'Try again',
        onAction: widget.onRefresh,
        isError: true,
      );
    }
    if (widget.items.isEmpty) {
      return StateView(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
        actionLabel: 'Add new',
        onAction: widget.onAdd,
      );
    }

    final active = widget.items.where((e) => e.isActive).length;
    final inactive = widget.items.length - active;
    final q = _q.trim().toLowerCase();
    final visible = widget.items
        .where((e) => e.isActive != _showInactive)
        .where((e) => q.isEmpty || e.label.toLowerCase().contains(q))
        .toList();

    return RefreshIndicator(
      color: DT.blue800,
      onRefresh: widget.onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
        children: [
          if (widget.header != null) ...[widget.header!, const SizedBox(height: 12)],
          if (widget.items.length > 6) ...[
            TextField(
              onChanged: (v) => setState(() => _q = v),
              style: DT.text(size: 13.5),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: DT.text(size: 13.5, color: DT.slate400),
                prefixIcon: const Icon(Icons.search_rounded, color: DT.slate400),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DT.rMd),
                  borderSide: const BorderSide(color: DT.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DT.rMd),
                  borderSide: const BorderSide(color: DT.blue800),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              _chip('Active', active, !_showInactive, () => setState(() => _showInactive = false)),
              const SizedBox(width: 8),
              _chip('Inactive', inactive, _showInactive,
                      () => setState(() => _showInactive = true)),
            ],
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                _showInactive ? 'Nothing deactivated.' : 'No matches.',
                textAlign: TextAlign.center,
                style: DT.text(size: 13, color: DT.slate500),
              ),
            )
          else
            for (final item in visible) ...[
              _row(item),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _chip(String text, int count, bool sel, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: sel ? DT.onyx900 : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: sel ? DT.onyx900 : DT.border),
      ),
      child: Text('$text  $count',
          style: DT.text(
              size: 12.5,
              weight: FontWeight.w700,
              color: sel ? Colors.white : DT.onyx700)),
    ),
  );

  Widget _row(T item) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DT.rMd),
        side: const BorderSide(color: DT.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(DT.rMd),
        onTap: () => widget.onEdit(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label,
                        style: DT.text(
                            size: 14,
                            weight: FontWeight.w700,
                            color: item.isActive ? DT.onyx900 : DT.slate500)),
                    if (item.sublabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(item.sublabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 12, color: DT.slate500)),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: DT.slate500, size: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
                onSelected: (v) =>
                v == 'edit' ? widget.onEdit(item) : widget.onToggleActive(item),
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit', style: DT.text(size: 13.5, weight: FontWeight.w600))),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(item.isActive ? 'Deactivate' : 'Restore',
                        style: DT.text(
                            size: 13.5,
                            weight: FontWeight.w600,
                            color: item.isActive ? DT.error : DT.emerald700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared confirm + call + snack for deactivate/restore.
Future<bool> catalogToggleActive(
    BuildContext context, {
      required String name,
      required bool currentlyActive,
      required Future<CatalogResult<void>> Function() call,
    }) async {
  final ok = await confirmAction(
    context,
    title: currentlyActive ? 'Deactivate $name?' : 'Restore $name?',
    message: currentlyActive
        ? 'It will no longer appear when adding products. You can restore it later.'
        : 'It will be available again when adding products.',
    confirmLabel: currentlyActive ? 'Deactivate' : 'Restore',
    destructive: currentlyActive,
  );
  if (!ok || !context.mounted) return false;
  final res = await call();
  if (context.mounted) showCompanySnack(context, res.message, error: !res.ok);
  return res.ok;
}

// ===========================================================================
// FORM SCAFFOLD + TEXT FIELD
// ===========================================================================
class CatalogFormScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final bool saving;
  final String saveLabel;
  final VoidCallback onSave;

  const CatalogFormScaffold({
    super.key,
    required this.title,
    required this.formKey,
    required this.children,
    required this.saving,
    required this.saveLabel,
    required this.onSave,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.background,
      appBar: CompanyTopBar(title: title, subtitle: subtitle),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: children,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: DT.border)),
          ),
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: saving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: DT.blue800,
                disabledBackgroundColor: DT.blue800.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
              ),
              child: saving
                  ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(saveLabel,
                  style: DT.text(size: 14.5, weight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}

class CatalogTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final TextCapitalization capitalization;
  final String? suffixText;
  final ValueChanged<String>? onChanged;

  const CatalogTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.none,
    this.suffixText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(DT.rMd),
        borderSide: BorderSide(color: c, width: w));
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      textCapitalization: capitalization,
      onChanged: onChanged,
      style: DT.text(size: 13.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: DT.text(size: 13, color: DT.slate500),
        hintStyle: DT.text(size: 13, color: DT.slate400),
        prefixIcon: icon == null ? null : Icon(icon, size: 19, color: DT.slate400),
        suffixText: suffixText,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        enabledBorder: b(DT.border),
        focusedBorder: b(DT.blue800, 1.4),
        errorBorder: b(DT.error),
        focusedErrorBorder: b(DT.error, 1.4),
      ),
    );
  }
}

/// Decimal input: digits and one dot, up to [decimals] places.
class DecimalInputFormatter extends TextInputFormatter {
  final int decimals;
  DecimalInputFormatter({this.decimals = 2});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final t = newValue.text;
    if (t.isEmpty) return newValue;
    final ok = RegExp('^\\d{0,8}(\\.\\d{0,$decimals})?\$').hasMatch(t);
    return ok ? newValue : oldValue;
  }
}