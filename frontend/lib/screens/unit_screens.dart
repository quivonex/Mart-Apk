// lib/screens/catalog/unit_screens.dart
//
// UnitManageScreen - my units (active / inactive). Standard (admin) units shown as a note.
// UnitFormScreen   - create / edit. Pops with the saved CatalogUnit.

import 'package:flutter/material.dart';
import '../../constants/design_tokens.dart';
import '../../models/catalog_models.dart';
import '../../services/catalog_service.dart';
import '../../widgets/catalog_widgets.dart';
import '../../widgets/company_ui.dart';

class UnitManageScreen extends StatefulWidget {
  const UnitManageScreen({super.key});

  @override
  State<UnitManageScreen> createState() => _UnitManageScreenState();
}

class _UnitManageScreenState extends State<UnitManageScreen> {
  List<CatalogUnit> _mine = [];
  List<CatalogUnit> _standard = [];
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
    final r = await CatalogService.getUnits(activeOnly: false);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _mine = r.items.where((u) => !u.isGlobal).toList();
      _standard = r.items.where((u) => u.isGlobal && u.isActive).toList();
      _error = r.ok ? null : r.message;
    });
  }

  Future<void> _openForm([CatalogUnit? existing]) async {
    final saved = await Navigator.push<CatalogUnit>(
      context,
      MaterialPageRoute(builder: (_) => UnitFormScreen(existing: existing)),
    );
    if (saved != null) {
      _changed = true;
      _load();
    }
  }

  Future<void> _toggle(CatalogUnit u) async {
    final ok = await catalogToggleActive(
      context,
      name: u.label,
      currentlyActive: u.isActive,
      call: () => CatalogService.setUnitActive(u.id, !u.isActive),
    );
    if (ok) {
      _changed = true;
      _load();
    }
  }

  Widget? _standardNote() {
    if (_standard.isEmpty) return null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DT.blue50,
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.blue200),
      ),
      child: Text(
        'Standard units available to everyone: '
            '${_standard.map((u) => u.shortName.isEmpty ? u.name : u.shortName).join(', ')}',
        style: DT.text(size: 12, color: DT.blue900, height: 1.45),
      ),
    );
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
        appBar: const CompanyTopBar(title: 'Units', subtitle: 'Kg, piece, box, litre…'),
        floatingActionButton: _mine.isEmpty
            ? null
            : FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: DT.blue800,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text('Add unit',
              style: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
        ),
        body: CatalogManageList<CatalogUnit>(
          loading: _loading,
          error: _error,
          items: _mine,
          header: _standardNote(),
          emptyIcon: Icons.straighten_rounded,
          emptyTitle: 'No units of your own',
          emptyMessage: _standard.isEmpty
              ? 'Add the units you sell in, e.g. Piece (pc), Kilogram (kg), Box (box).'
              : 'Standard units (${_standard.map((u) => u.shortName).join(', ')}) are already '
              'available. Add your own if you need another one.',
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
class UnitFormScreen extends StatefulWidget {
  final CatalogUnit? existing;

  const UnitFormScreen({super.key, this.existing});

  @override
  State<UnitFormScreen> createState() => _UnitFormScreenState();
}

class _UnitFormScreenState extends State<UnitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _short = TextEditingController(text: widget.existing?.shortName ?? '');
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  static const _suggestions = <(String, String)>[
    ('Piece', 'pc'),
    ('Kilogram', 'kg'),
    ('Gram', 'g'),
    ('Litre', 'L'),
    ('Box', 'box'),
    ('Set', 'set'),
    ('Pack', 'pack'),
    ('Metre', 'm'),
  ];

  @override
  void dispose() {
    _name.dispose();
    _short.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final res = _isEdit
        ? await CatalogService.updateUnit(widget.existing!.id,
        name: _name.text.trim(), shortName: _short.text.trim())
        : await CatalogService.createUnit(
        name: _name.text.trim(), shortName: _short.text.trim());

    if (!mounted) return;
    setState(() => _saving = false);
    showCompanySnack(context, res.message, error: !res.ok);
    if (res.ok) {
      Navigator.pop(
          context,
          res.data ??
              CatalogUnit(id: 0, name: _name.text.trim(), shortName: _short.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CatalogFormScaffold(
      title: _isEdit ? 'Edit unit' : 'Add unit',
      formKey: _formKey,
      saving: _saving,
      saveLabel: _isEdit ? 'Save changes' : 'Add unit',
      onSave: _save,
      children: [
        if (!_isEdit) ...[
          Text('Quick pick', style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (n, s) in _suggestions)
                ActionChip(
                  label: Text('$n ($s)', style: DT.text(size: 12.5, weight: FontWeight.w600)),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: DT.border),
                  onPressed: () => setState(() {
                    _name.text = n;
                    _short.text = s;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        CatalogTextField(
          controller: _name,
          label: 'Unit name *',
          hint: 'e.g. Kilogram',
          icon: Icons.straighten_rounded,
          capitalization: TextCapitalization.words,
          validator: (v) => (v ?? '').trim().isEmpty ? 'Enter the unit name' : null,
        ),
        const SizedBox(height: 12),
        CatalogTextField(
          controller: _short,
          label: 'Short name *',
          hint: 'e.g. kg',
          icon: Icons.short_text_rounded,
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Enter a short name';
            if (t.length > 20) return 'Max 20 characters';
            return null;
          },
        ),
      ],
    );
  }
}