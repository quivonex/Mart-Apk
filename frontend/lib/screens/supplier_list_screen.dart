// lib/screens/supplier_list_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/design_tokens.dart';
import '../models/company_model.dart';
import '../models/supplier_model.dart';
import '../services/supplier_service.dart';
import '../widgets/company_ui.dart';
import 'supplier_create_edit_screen.dart';

class SupplierListScreen extends StatefulWidget {
  final Company company;

  const SupplierListScreen({super.key, required this.company});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final _searchCtrl = TextEditingController();
  List<Supplier> _items = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    final res = await SupplierService.getSuppliers(widget.company.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isSuccess) {
        _items = res.data;
      } else {
        _error = res.message ?? 'Could not load suppliers';
      }
    });
  }

  List<Supplier> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where((s) => [s.name, s.phone, s.email, s.district, s.village, s.state]
        .any((f) => f.toLowerCase().contains(q)))
        .toList();
  }

  Future<void> _openForm([Supplier? existing]) async {
    final saved = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierCreateEditScreen(company: widget.company, existing: existing),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Supplier s) async {
    final ok = await confirmAction(
      context,
      title: 'Delete ${s.name}?',
      message: 'This supplier will be removed permanently.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final res = await SupplierService.deleteSupplier(s.id);
    if (!mounted) return;
    showCompanySnack(context, res.displayMessage, error: !res.isSuccess);
    if (res.isSuccess) setState(() => _items.removeWhere((e) => e.id == s.id));
  }

  Future<void> _call(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return;
    await launchUrl(Uri.parse('tel:$digits'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DT.background,
      appBar: CompanyTopBar(
        title: 'Suppliers',
        subtitle: _loading
            ? 'Loading…'
            : '${widget.company.name} · ${_items.length} supplier${_items.length == 1 ? '' : 's'}',
      ),
      floatingActionButton: _items.isEmpty
          ? null
          : FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: DT.blue800,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rLg)),
        icon: const Icon(Icons.add_rounded),
        label: Text('Add supplier',
            style: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: DT.blue800));
    }
    if (_error != null && _items.isEmpty) {
      return StateView(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load suppliers',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
        isError: true,
      );
    }
    if (_items.isEmpty) {
      return StateView(
        icon: Icons.local_shipping_outlined,
        title: 'No suppliers yet',
        message: 'Add the businesses you buy stock from to keep their contacts in one place.',
        actionLabel: 'Add supplier',
        onAction: () => _openForm(),
      );
    }

    final visible = _visible;
    return RefreshIndicator(
      color: DT.blue800,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: DT.text(size: 13.5),
            decoration: InputDecoration(
              hintText: 'Search by name, phone or place',
              hintStyle: DT.text(size: 13.5, color: DT.slate400),
              prefixIcon: const Icon(Icons.search_rounded, color: DT.slate400),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: DT.slate400),
                onPressed: () => setState(() {
                  _searchCtrl.clear();
                  _query = '';
                }),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DT.rMd),
                borderSide: const BorderSide(color: DT.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DT.rMd),
                borderSide: const BorderSide(color: DT.blue800, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text('No suppliers match "$_query".',
                  textAlign: TextAlign.center,
                  style: DT.text(size: 13, color: DT.slate500)),
            )
          else
            for (final s in visible) ...[
              _SupplierCard(
                supplier: s,
                onEdit: () => _openForm(s),
                onDelete: () => _delete(s),
                onCall: () => _call(s.phone),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCall;

  const _SupplierCard({
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DT.rLg),
        side: const BorderSide(color: DT.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompanyLogo(url: '', name: s.name, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 14.5, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    if (s.phone.isNotEmpty) _line(Icons.phone_outlined, s.phone),
                    if (s.email.isNotEmpty) _line(Icons.mail_outline_rounded, s.email),
                    if (s.locationLine.isNotEmpty)
                      _line(Icons.location_on_outlined, s.locationLine),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    tooltip: 'Call',
                    onPressed: s.phone.isEmpty ? null : onCall,
                    icon: const Icon(Icons.call_rounded, color: DT.emerald700, size: 20),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    icon: const Icon(Icons.more_vert_rounded, color: DT.slate500, size: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
                    onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit', style: DT.text(size: 13.5, weight: FontWeight.w600)),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: DT.text(
                                size: 13.5, weight: FontWeight.w600, color: DT.error)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      children: [
        Icon(icon, size: 13, color: DT.slate400),
        const SizedBox(width: 5),
        Expanded(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DT.text(size: 12, color: DT.onyx600)),
        ),
      ],
    ),
  );
}