// lib/screens/saved_addresses_screen.dart
//
// QNX Mart › Saved addresses (delivery addresses used at checkout).
//   POST order/address/list/     (via CheckoutService.addresses)
//   POST order/address/create/   (via CheckoutService.addAddress)
//   POST order/address/update/   (via OrderExtrasService.updateAddress) – "Edit" on a card

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/design_tokens.dart';
import '../services/checkout_service.dart';
import '../services/order_extras_service.dart';
import '../utils/shared_preferences_helper.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kBrandDark = Color(0xFF062A50);
const _kBrandLight = Color(0xFF1E5A9C);
const _kRed = Color(0xFFC62828);
const _kHeader = LinearGradient(
  colors: [_kBrandDark, _kBrand, _kBrandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class _SA {
  static const brand = Color(0xFF093C71);
  static const bg = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
  static const tint = Color(0xFFEAF1F9);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
}

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  bool _loading = true;
  String? _error;
  List<DeliveryAddress> _list = [];

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
    final r = await CheckoutService.addresses();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _list = r.data ?? [];
      _error = r.ok ? null : r.message;
    });
  }

  Future<void> _add() async {
    final saved = await showModalBottomSheet<DeliveryAddress>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddAddressSheet(),
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Address saved'),
        behavior: SnackBarBehavior.floating,
      ));
      _load();
    }
  }

    Future<void> _edit(DeliveryAddress a) async {
    final saved = await showModalBottomSheet<DeliveryAddress>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAddressSheet(initial: a),
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Address updated'),
        behavior: SnackBarBehavior.floating,
      ));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SA.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeader)),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Saved addresses', style: DT.text(size: 17, weight: FontWeight.w700, color: Colors.white)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: _kBrand, // buttons: only #093C71
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text('Add address', style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _SA.brand))
          : RefreshIndicator(
        color: _SA.brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (_error != null)
              _msg(Icons.cloud_off_rounded, 'Could not load addresses', _error!)
            else if (_list.isEmpty)
              _msg(Icons.location_off_outlined, 'No saved addresses',
                  'Add an address to see live shipping in your cart and check out faster.')
            else
              for (var i = 0; i < _list.length; i++) ...[
                _card(_list[i], first: i == 0),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _msg(IconData icon, String title, String body) => Padding(
    padding: const EdgeInsets.only(top: 60),
    child: Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(color: _SA.tint, shape: BoxShape.circle),
          child: Icon(icon, size: 38, color: _SA.brand),
        ),
        const SizedBox(height: 16),
        Text(title, style: DT.text(size: 16, weight: FontWeight.w800, color: _SA.ink)),
        const SizedBox(height: 6),
        Text(body, textAlign: TextAlign.center, style: DT.text(size: 13, color: _SA.muted, height: 1.45)),
      ],
    ),
  );

  Widget _card(DeliveryAddress a, {required bool first}) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: first ? _SA.brand : _SA.line, width: first ? 1.5 : 1),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: _SA.tint, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.home_outlined, color: _SA.brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(a.fullName.isEmpty ? 'Address' : a.fullName,
                        style: DT.text(size: 14.5, weight: FontWeight.w800, color: _SA.ink)),
                  ),
                  if (first)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _SA.tint, borderRadius: BorderRadius.circular(20)),
                      child: Text('Used for shipping estimate',
                          style: DT.text(size: 9.5, weight: FontWeight.w800, color: _SA.brand)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(a.oneLine, style: DT.text(size: 12.5, color: DT.onyx700, height: 1.45)),
              const SizedBox(height: 4),
              Text('PIN ${a.pincode}${a.mobile.isNotEmpty ? '  ·  ${a.mobile}' : ''}',
                  style: DT.text(size: 12, weight: FontWeight.w700, color: _SA.muted)),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: FilledButton.icon(
                  onPressed: () => _edit(a),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kBrand, // buttons: only #093C71
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                  label: Text('Edit', style: DT.text(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AddAddressSheet extends StatefulWidget {
  /// null = new address, otherwise edit this one.
  final DeliveryAddress? initial;
  const _AddAddressSheet({this.initial});

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  final _c = {
    for (final k in ['full_name', 'mobile_no', 'address_line1', 'address_line2', 'village', 'taluka', 'district', 'city', 'state', 'pincode'])
      k: TextEditingController(),
  };
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final a = widget.initial;
    if (a != null) {
      final v = {
        'full_name': a.fullName,
        'mobile_no': a.mobile,
        'address_line1': a.line1,
        'address_line2': a.line2,
        'village': a.village,
        'taluka': a.taluka,
        'district': a.district,
        'city': a.city,
        'state': a.state,
        'pincode': a.pincode,
      };
      v.forEach((k, t) => _c[k]!.text = t);
      return;
    }
    SharedPreferencesHelper.getUsername().then((n) {
      if (mounted && n != null && _c['full_name']!.text.isEmpty) _c['full_name']!.text = n;
    });
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final fields = {for (final e in _c.entries) e.key: e.value.text.trim()};
    final init = widget.initial;
    if (init != null) {
      final r = await OrderExtrasService.updateAddress(init.id, fields);
      if (!mounted) return;
      if (r.ok) {
        Navigator.pop(context, r.data ?? init);
      } else {
        setState(() {
          _saving = false;
          _error = r.message;
        });
      }
      return;
    }
    final r = await CheckoutService.addAddress(fields);
    if (!mounted) return;
    if (r.ok) {
      Navigator.pop(context, r.data);
    } else {
      setState(() {
        _saving = false;
        _error = r.message;
      });
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
    labelText: label,
    labelStyle: DT.text(size: 13, color: _SA.muted),
    isDense: true,
    filled: true,
    fillColor: _SA.bg,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _SA.line)),
    enabledBorder:
    OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _SA.line)),
    focusedBorder:
    OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _SA.brand, width: 1.6)),
  );

  Widget _f(String key, String label,
      {bool required = true, TextInputType? keyboard, List<TextInputFormatter>? fmt, String? Function(String)? check}) {
    return TextFormField(
      controller: _c[key],
      keyboardType: keyboard,
      inputFormatters: fmt,
      textCapitalization: keyboard == null ? TextCapitalization.words : TextCapitalization.none,
      style: DT.text(size: 13.5, weight: FontWeight.w600, color: _SA.ink),
      decoration: _dec(required ? '$label *' : label),
      validator: (v) {
        final t = (v ?? '').trim();
        if (required && t.isEmpty) return 'Required';
        return check?.call(t);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 10, 8, 14),
                  decoration: const BoxDecoration(gradient: _kHeader),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(widget.initial == null ? 'New delivery address' : 'Edit address',
                                style: DT.text(size: 16.5, weight: FontWeight.w800, color: Colors.white)),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    children: [
                      _f('full_name', 'Full name'),
                      const SizedBox(height: 10),
                      _f('mobile_no', 'Mobile number',
                          keyboard: TextInputType.phone,
                          fmt: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                          check: (t) => RegExp(r'^[6-9]\d{9}$').hasMatch(t) ? null : 'Enter a valid 10-digit number'),
                      const SizedBox(height: 10),
                      _f('address_line1', 'House / building, street'),
                      const SizedBox(height: 10),
                      _f('address_line2', 'Landmark / area', required: false),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _f('village', 'Village / locality', required: false)),
                        const SizedBox(width: 10),
                        Expanded(child: _f('taluka', 'Taluka', required: false)),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _f('district', 'District', required: false)),
                        const SizedBox(width: 10),
                        Expanded(child: _f('city', 'City')),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _f('state', 'State')),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _f('pincode', 'Pincode',
                              keyboard: TextInputType.number,
                              fmt: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                              check: (t) => t.length == 6 ? null : '6 digits'),
                        ),
                      ]),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: DT.text(size: 12.5, weight: FontWeight.w600, color: _kRed)),
                      ],
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: _kBrand, borderRadius: BorderRadius.circular(14)),
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _saving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(widget.initial == null ? 'Save address' : 'Update address', style: DT.text(size: 14.5, weight: FontWeight.w800, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
