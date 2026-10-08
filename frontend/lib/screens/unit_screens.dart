// lib/screens/catalog/unit_screens.dart
//
// UnitManageScreen - my units (active / inactive). Standard (admin) units shown as a note.
// UnitFormScreen   - create / edit. Pops with the saved CatalogUnit.
// Redesigned to match the app (brand blue #1A68FA, white cards, slate borders).

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/catalog_models.dart';
import '../services/catalog_service.dart';
import '../widgets/catalog_widgets.dart';
import '../widgets/company_ui.dart';
import '../widgets/product_ui.dart';

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline_rounded,
                size: 16, color: DT.blue800),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Standard units available to everyone: '
                  '${_standard.map((u) => u.shortName.isEmpty ? u.name : u.shortName).join(', ')}',
              style: DT.text(size: 12, color: DT.blue900, height: 1.45),
            ),
          ),
        ],
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
        appBar: const CompanyTopBar(
            title: 'Units', subtitle: 'Kg, piece, box, litre…'),
        floatingActionButton: _mine.isEmpty
            ? null
            : FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: DT.blue800,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text('Add unit',
              style: DT.text(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: Colors.white)),
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
// Unit Form (Add / Edit) — redesigned
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

  static const _brand = Color(0xFF1A68FA);

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
              CatalogUnit(
                  id: 0, name: _name.text.trim(), shortName: _short.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.background,
      appBar: _appBar(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _infoCard(
                icon: Icons.straighten_rounded,
                title: _isEdit ? 'Edit unit' : 'New unit',
                subtitle:
                'Units tell buyers how your product is measured and sold',
              ),
              const SizedBox(height: 16),
              if (!_isEdit) ...[
                _quickPickCard(),
                const SizedBox(height: 16),
              ],
              _sectionCard(
                icon: Icons.info_outline,
                title: 'Unit information',
                subtitle: 'Full name and short form',
                children: [
                  PxLabel('Unit name', required: true),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    style: DT.text(
                        size: 14, weight: FontWeight.w600, color: DT.onyx900),
                    decoration: pxInputDecoration(
                      hint: 'e.g. Kilogram',
                      icon: Icons.straighten_rounded,
                      iconColor: _brand,
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Enter the unit name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  PxLabel('Short name', required: true),
                  TextFormField(
                    controller: _short,
                    style: DT.text(
                        size: 14, weight: FontWeight.w600, color: DT.onyx900),
                    decoration: pxInputDecoration(
                      hint: 'e.g. kg',
                      icon: Icons.short_text_rounded,
                      iconColor: _brand,
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Enter a short name';
                      if (t.length > 20) return 'Max 20 characters';
                      return null;
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  PreferredSizeWidget _appBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: DT.slate200)),
          boxShadow: [
            BoxShadow(
                color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: DT.onyx900, size: 24),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Edit unit' : 'Add unit',
                          style: DT.text(
                              size: 18,
                              weight: FontWeight.w700,
                              color: DT.onyx900,
                              letterSpacing: -0.3),
                        ),
                        Text(
                          'Manage how products are measured',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(
                              size: 12,
                              weight: FontWeight.w500,
                              color: DT.slate500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DT.blue50,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.blue200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: _brand, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: DT.text(
                        size: 14,
                        weight: FontWeight.w800,
                        color: DT.onyx900)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                    DT.text(size: 11.5, color: DT.slate500, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickPickCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.slate200),
        boxShadow: PX.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DT.slate100)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: DT.blue50,
                    borderRadius: BorderRadius.circular(DT.rMd),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      size: 20, color: _brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick pick',
                          style: DT.text(
                              size: 14,
                              weight: FontWeight.w700,
                              color: DT.onyx900,
                              height: 1.2)),
                      const SizedBox(height: 2),
                      Text('Tap a common unit to fill the form',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 11.5, color: DT.slate500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (n, s) in _suggestions)
                ActionChip(
                  label: Text('$n ($s)',
                      style: DT.text(
                          size: 12.5,
                          weight: FontWeight.w600,
                          color: DT.onyx800)),
                  backgroundColor: DT.slate50,
                  side: const BorderSide(color: DT.slate200),
                  shape: const StadiumBorder(),
                  onPressed: () => setState(() {
                    _name.text = n;
                    _short.text = s;
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.slate200),
        boxShadow: PX.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: DT.slate100)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: DT.blue50,
                    borderRadius: BorderRadius.circular(DT.rMd),
                  ),
                  child: Icon(icon, size: 20, color: _brand),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: DT.text(
                              size: 14,
                              weight: FontWeight.w700,
                              color: DT.onyx900,
                              height: 1.2)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 11.5, color: DT.slate500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: DT.slate200)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _brand.withValues(alpha: 0.55),
                elevation: 2,
                shadowColor: const Color(0x401A68FA),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DT.rMd)),
              ),
              child: _saving
                  ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isEdit ? 'Save changes' : 'Add unit',
                    style: DT.text(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}