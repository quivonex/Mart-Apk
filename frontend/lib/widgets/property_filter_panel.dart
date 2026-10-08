// lib/widgets/property_filter_panel.dart
//
// Real-estate "Filters" panel (slides in from the left, like the website):
//
//   ₹  PRICE RANGE        Min ₹ — Max ₹
//   📍 STATE              All States          (state API)
//   📍 DISTRICT / CITY    All Districts       (district API for the chosen state)
//   🏢 PROPERTY TYPE      All Types
//   ⇆  TRANSACTION TYPE   All
//   ☆  AMENITIES          checkboxes          (real_estate/amenities/list/)
//   [Clear all]  [Show N properties]
//
// Properties only store `city` / `area` (no state or district fields), so a
// property matches a state when its city or area is one of that state's
// districts, and a district when its city/area equals it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/design_tokens.dart';
import '../models/company_locations_models.dart';
import '../models/property_model.dart';
import '../services/company_locations_service.dart';
import '../services/real_estate_service.dart';

// =====================================================================
// FILTER VALUE
// =====================================================================
class PropertyFilters {
  final double? minPrice;
  final double? maxPrice;
  final int? stateId;
  final String? stateName;
  /// Lower-case district names of [stateId] (used for matching).
  final Set<String> stateDistricts;
  final String? district;
  final String? type; // flat, villa, …
  final String? transaction; // sale, rent, lease, pg
  final Set<int> amenityIds;

  const PropertyFilters({
    this.minPrice,
    this.maxPrice,
    this.stateId,
    this.stateName,
    this.stateDistricts = const {},
    this.district,
    this.type,
    this.transaction,
    this.amenityIds = const {},
  });

  static const empty = PropertyFilters();

  /// Count of active filters, for the badge on the Filters button.
  int get activeCount =>
      (minPrice != null || maxPrice != null ? 1 : 0) +
          (stateId != null ? 1 : 0) +
          (district != null ? 1 : 0) +
          (type != null ? 1 : 0) +
          (transaction != null ? 1 : 0) +
          (amenityIds.isNotEmpty ? 1 : 0);

  bool get isEmpty => activeCount == 0;

  PropertyFilters withType(String? t) => PropertyFilters(
    minPrice: minPrice,
    maxPrice: maxPrice,
    stateId: stateId,
    stateName: stateName,
    stateDistricts: stateDistricts,
    district: district,
    type: t,
    transaction: transaction,
    amenityIds: amenityIds,
  );

  bool matches(Property p) {
    if (type != null && p.propertyType != type) return false;
    if (transaction != null && p.transactionType != transaction) return false;

    if (minPrice != null || maxPrice != null) {
      final price = p.minPrice;
      if (price <= 0) return false; // "Price on request" can't be compared
      if (minPrice != null && price < minPrice!) return false;
      if (maxPrice != null && price > maxPrice!) return false;
    }

    final city = p.city.trim().toLowerCase();
    final area = p.area.trim().toLowerCase();
    if (district != null) {
      final d = district!.toLowerCase();
      if (city != d && area != d && !p.address.toLowerCase().contains(d)) return false;
    } else if (stateId != null && stateDistricts.isNotEmpty) {
      if (!stateDistricts.contains(city) && !stateDistricts.contains(area)) return false;
    }

    if (amenityIds.isNotEmpty) {
      final has = p.amenities.map((a) => a.id).toSet();
      if (!amenityIds.every(has.contains)) return false; // must have all ticked
    }
    return true;
  }
}

// =====================================================================
// OPEN THE PANEL
// =====================================================================
/// Slides the panel in from the left. Returns the new filters, or null if closed.
Future<PropertyFilters?> showPropertyFilterPanel(
    BuildContext context, {
      required PropertyFilters initial,
      required int Function(PropertyFilters) countFor,
    }) {
  return showGeneralDialog<PropertyFilters>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Filters',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => Align(
      alignment: Alignment.centerLeft,
      child: PropertyFilterPanel(initial: initial, countFor: countFor),
    ),
    transitionBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween(begin: const Offset(-1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

// =====================================================================
// PANEL
// =====================================================================
class PropertyFilterPanel extends StatefulWidget {
  final PropertyFilters initial;
  final int Function(PropertyFilters) countFor;

  const PropertyFilterPanel({super.key, required this.initial, required this.countFor});

  @override
  State<PropertyFilterPanel> createState() => _PropertyFilterPanelState();
}

class _PropertyFilterPanelState extends State<PropertyFilterPanel> {
  static const _headerTop = Color(0xFF334155);
  static const _headerBottom = Color(0xFF475569);
  static const _label = Color(0xFF334155);
  static const _border = Color(0xFFCBD5E1);
  static const _blue = Color(0xFF1D6BF3);

  // Loaded once per app run.
  static List<LocationItem>? _statesCache;
  static List<Amenity>? _amenitiesCache;
  static final Map<int, List<LocationItem>> _districtCache = {};

  late final _min = TextEditingController(text: _fmt(widget.initial.minPrice));
  late final _max = TextEditingController(text: _fmt(widget.initial.maxPrice));
  late int? _stateId = widget.initial.stateId;
  late String? _stateName = widget.initial.stateName;
  late String? _district = widget.initial.district;
  late String? _type = widget.initial.type;
  late String? _transaction = widget.initial.transaction;
  late final Set<int> _amenityIds = {...widget.initial.amenityIds};

  List<LocationItem> _states = _statesCache ?? const [];
  List<LocationItem> _districts = const [];
  List<Amenity> _amenities = _amenitiesCache ?? const [];
  bool _loadingStates = false;
  bool _loadingDistricts = false;
  bool _loadingAmenities = false;
  String? _amenitiesError;

  static String _fmt(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  static const _types = <(String, String)>[
    ('flat', 'Flat / Apartment'),
    ('villa', 'Villa / Bungalow'),
    ('plot', 'Plot / Land'),
    ('commercial', 'Commercial Space'),
    ('shop', 'Shop / Retail'),
    ('office', 'Office Space'),
    ('warehouse', 'Warehouse'),
    ('other', 'Other'),
  ];

  static const _transactions = <(String, String)>[
    ('sale', 'For Sale'),
    ('rent', 'For Rent'),
    ('lease', 'For Lease'),
    ('pg', 'PG / Hostel'),
  ];

  @override
  void initState() {
    super.initState();
    if (_statesCache == null) _loadStates();
    if (_stateId != null) _loadDistricts(_stateId!);
    if (_amenitiesCache == null) _loadAmenities();
    _min.addListener(_refresh);
    _max.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _loadStates() async {
    setState(() => _loadingStates = true);
    final r = await CompanyLocationService.getStates();
    if (!mounted) return;
    setState(() {
      _loadingStates = false;
      _states = r.data;
      if (r.data.isNotEmpty) _statesCache = r.data;
    });
  }

  Future<void> _loadDistricts(int stateId) async {
    final cached = _districtCache[stateId];
    if (cached != null) {
      setState(() => _districts = cached);
      return;
    }
    setState(() {
      _loadingDistricts = true;
      _districts = const [];
    });
    final r = await CompanyLocationService.getDistricts(stateId);
    if (!mounted || _stateId != stateId) return;
    setState(() {
      _loadingDistricts = false;
      _districts = r.data;
      if (r.data.isNotEmpty) _districtCache[stateId] = r.data;
    });
  }

  Future<void> _loadAmenities() async {
    setState(() {
      _loadingAmenities = true;
      _amenitiesError = null;
    });
    final r = await RealEstateService.getAmenitiesList();
    if (!mounted) return;
    final list = [...r.data]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _loadingAmenities = false;
      _amenities = list;
      if (r.status && list.isNotEmpty) _amenitiesCache = list;
      if (!r.status) _amenitiesError = r.message ?? 'Could not load amenities';
    });
  }

  PropertyFilters get _current {
    var min = double.tryParse(_min.text.trim());
    var max = double.tryParse(_max.text.trim());
    if (min != null && max != null && min > max) {
      final t = min;
      min = max;
      max = t;
    }
    return PropertyFilters(
      minPrice: (min ?? 0) > 0 ? min : null,
      maxPrice: (max ?? 0) > 0 ? max : null,
      stateId: _stateId,
      stateName: _stateName,
      stateDistricts: _stateId == null
          ? const {}
          : {for (final d in (_districtCache[_stateId] ?? _districts)) d.name.trim().toLowerCase()},
      district: _district,
      type: _type,
      transaction: _transaction,
      amenityIds: {..._amenityIds},
    );
  }

  void _clearAll() {
    _min.clear();
    _max.clear();
    setState(() {
      _stateId = null;
      _stateName = null;
      _district = null;
      _districts = const [];
      _type = null;
      _transaction = null;
      _amenityIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width * 0.62).clamp(290.0, 380.0).toDouble();
    final count = widget.countFor(_current);

    return Material(
      color: Colors.white,
      elevation: 16,
      child: SizedBox(
        width: width,
        height: double.infinity,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _section(
                    icon: Icons.currency_rupee_rounded,
                    title: 'Price range',
                    child: Row(
                      children: [
                        Expanded(child: _priceBox(_min, 'Min ₹')),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('—', style: TextStyle(color: Color(0xFF94A3B8))),
                        ),
                        Expanded(child: _priceBox(_max, 'Max ₹')),
                      ],
                    ),
                  ),
                  _section(
                    icon: Icons.location_on_outlined,
                    title: 'State',
                    child: _select<int>(
                      value: _stateId,
                      allLabel: _loadingStates ? 'Loading states…' : 'All States',
                      items: [for (final s in _states) (s.id, s.name)],
                      onChanged: (id) {
                        setState(() {
                          _stateId = id;
                          _stateName = id == null ? null : _states.firstWhere((s) => s.id == id).name;
                          _district = null;
                          _districts = const [];
                        });
                        if (id != null) _loadDistricts(id);
                      },
                    ),
                  ),
                  _section(
                    icon: Icons.person_pin_circle_outlined,
                    title: 'District / City',
                    child: _select<String>(
                      value: _district,
                      allLabel: _stateId == null
                          ? 'All Districts'
                          : (_loadingDistricts ? 'Loading districts…' : 'All Districts'),
                      items: [for (final d in _districts) (d.name, d.name)],
                      enabled: _stateId != null,
                      disabledHint: 'Select a state first',
                      onChanged: (d) => setState(() => _district = d),
                    ),
                  ),
                  _section(
                    icon: Icons.apartment_rounded,
                    title: 'Property type',
                    child: _select<String>(
                      value: _type,
                      allLabel: 'All Types',
                      items: _types,
                      onChanged: (t) => setState(() => _type = t),
                    ),
                  ),
                  _section(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Transaction type',
                    child: _select<String>(
                      value: _transaction,
                      allLabel: 'All',
                      items: _transactions,
                      onChanged: (t) => setState(() => _transaction = t),
                    ),
                  ),
                  _section(
                    icon: Icons.star_border_rounded,
                    title: 'Amenities',
                    trailing: _amenityIds.isEmpty
                        ? null
                        : GestureDetector(
                      onTap: () => setState(_amenityIds.clear),
                      child: Text('Clear (${_amenityIds.length})',
                          style: DT.text(size: 12, weight: FontWeight.w700, color: _blue)),
                    ),
                    divider: false,
                    child: _amenityList(),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            _footer(count),
          ],
        ),
      ),
    );
  }

  // ── pieces ──────────────────────────────────────────────
  Widget _header() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [_headerTop, _headerBottom]),
    ),
    child: SafeArea(
      bottom: false,
      right: false,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            const SizedBox(width: 18),
            const Icon(Icons.filter_alt_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Filters', style: DT.text(size: 16, weight: FontWeight.w700, color: Colors.white)),
            const Spacer(),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    ),
  );

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
    bool divider = true,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        border: divider ? const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _label),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title.toUpperCase(),
                    style: DT.text(size: 13.5, weight: FontWeight.w800, color: _label, letterSpacing: 1.1)),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _priceBox(TextEditingController c, String hint) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
    style: DT.text(size: 14.5),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: DT.text(size: 14.5, color: const Color(0xFF94A3B8)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _blue, width: 1.6),
      ),
    ),
  );

  Widget _select<T>({
    required T? value,
    required String allLabel,
    required List<(T, String)> items,
    required ValueChanged<T?> onChanged,
    bool enabled = true,
    String? disabledHint,
  }) {
    final safe = items.any((e) => e.$1 == value) ? value : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: safe,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: DT.onyx700),
          borderRadius: BorderRadius.circular(12),
          style: DT.text(size: 14.5, color: DT.onyx900),
          hint: Text(enabled ? allLabel : (disabledHint ?? allLabel),
              style: DT.text(size: 14.5, color: enabled ? DT.onyx800 : const Color(0xFF94A3B8))),
          items: [
            DropdownMenuItem<T?>(value: null, child: Text(allLabel, style: DT.text(size: 14.5))),
            for (final (v, label) in items)
              DropdownMenuItem<T?>(
                value: v,
                child: Text(label, overflow: TextOverflow.ellipsis, style: DT.text(size: 14.5)),
              ),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _amenityList() {
    if (_loadingAmenities && _amenities.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
            child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2))),
      );
    }
    if (_amenities.isEmpty) {
      return Row(
        children: [
          Expanded(
            child: Text(_amenitiesError ?? 'No amenities available',
                style: DT.text(size: 13, color: DT.slate500)),
          ),
          if (_amenitiesError != null)
            TextButton(onPressed: _loadAmenities, child: const Text('Retry')),
        ],
      );
    }
    return Column(
      children: [
        for (final a in _amenities)
          InkWell(
            onTap: () => setState(() {
              _amenityIds.contains(a.id) ? _amenityIds.remove(a.id) : _amenityIds.add(a.id);
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _amenityIds.contains(a.id),
                      onChanged: (v) => setState(() {
                        v == true ? _amenityIds.add(a.id) : _amenityIds.remove(a.id);
                      }),
                      activeColor: _blue,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      side: const BorderSide(color: Color(0xFF64748B), width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(a.name.trim(),
                        style: DT.text(size: 15, color: const Color(0xFF334155), height: 1.35)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _footer(int count) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
    ),
    child: SafeArea(
      top: false,
      right: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            TextButton(
              onPressed: _clearAll,
              child: Text('Clear all', style: DT.text(size: 13.5, weight: FontWeight.w700, color: _label)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(_current),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: FittedBox(
                  child: Text('Show $count ${count == 1 ? 'property' : 'properties'}',
                      style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}