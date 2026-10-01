import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/property_model.dart';
import '../services/real_estate_service.dart';
import 'property_detail_screen.dart';

/// Design tokens from the HTML design (Tailwind slate / brand palette).
class _C {
  static const navy = Color(0xFF1E255E);
  static const navyDark = Color(0xFF161C47);
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate700 = Color(0xFF334155);
  static const slate900 = Color(0xFF0F172A);
  static const blue50 = Color(0xFFEFF6FF);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue200 = Color(0xFFBFDBFE);
  static const blue600 = Color(0xFF2563EB);
  static const blue700 = Color(0xFF1D4ED8);
  static const blue800 = Color(0xFF1E40AF);
  static const emerald500 = Color(0xFF10B981);
  static const emerald600 = Color(0xFF059669);
  static const amber400 = Color(0xFFFBBF24);
  static const amber500 = Color(0xFFF59E0B);
  static const amber600 = Color(0xFFD97706);
  static const amber700 = Color(0xFFB45309);
  static const amber800 = Color(0xFF92400E);
  static const amber950 = Color(0xFF451A03);
  static const amber50 = Color(0xFFFFFBEB);
  static const orange50 = Color(0xFFFFF7ED);
  static const amber200 = Color(0xFFFDE68A);
  static const error = Color(0xFFDC2626);
}

class PropertiesScreen extends StatefulWidget {
  const PropertiesScreen({super.key});

  @override
  State<PropertiesScreen> createState() => _PropertiesScreenState();
}

class _PropertiesScreenState extends State<PropertiesScreen> {
  List<Property> _allProperties = [];
  List<Property> _displayProperties = [];
  List<Amenity> _allAmenities = [];

  bool _isLoading = true;
  String? _error;

  // Filters
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedAmenityIds = {};
  String _selectedTransactionType = 'All';
  String _selectedPropertyType = 'All'; // quick category chips
  String _sort = 'relevant'; // relevant | az

  // Local favourites (keyed by slug)
  final Set<String> _favorites = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Data + filters
  // ---------------------------------------------------------------------------

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilters();
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Load both in parallel
    final results = await Future.wait([
      RealEstateService.getApprovedProperties(),
      RealEstateService.getAmenitiesList(),
    ]);

    final propertyRes = results[0] as PropertyResponse;
    final amenityRes = results[1] as AmenitiesListResponse;

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (propertyRes.status && propertyRes.data.isNotEmpty) {
        _allProperties = propertyRes.data;
        _applyFilters();
      } else {
        _allProperties = [];
        _displayProperties = [];
        _error = propertyRes.message ?? 'No properties found';
      }

      // Amenities — non-critical, don't fail screen if it errors
      _allAmenities = amenityRes.data;
    });
  }

  /// Must be called inside setState().
  void _applyFilters() {
    _displayProperties = List.from(_allProperties);

    // Quick category (property type)
    if (_selectedPropertyType != 'All') {
      _displayProperties = _displayProperties
          .where((p) =>
      p.propertyType.toLowerCase() ==
          _selectedPropertyType.toLowerCase())
          .toList();
    }

    // Transaction type
    if (_selectedTransactionType != 'All') {
      _displayProperties = _displayProperties
          .where((p) =>
      p.transactionType.toLowerCase() ==
          _selectedTransactionType.toLowerCase())
          .toList();
    }

    // Search (city, area, address, type)
    if (_searchQuery.isNotEmpty) {
      _displayProperties = _displayProperties
          .where((p) =>
      p.city.toLowerCase().contains(_searchQuery) ||
          p.area.toLowerCase().contains(_searchQuery) ||
          p.address.toLowerCase().contains(_searchQuery) ||
          p.propertyType.toLowerCase().contains(_searchQuery))
          .toList();
    }

    // Amenities (must have ALL selected)
    if (_selectedAmenityIds.isNotEmpty) {
      _displayProperties = _displayProperties.where((p) {
        final ids = p.amenities.map((a) => a.id).toSet();
        return _selectedAmenityIds.every(ids.contains);
      }).toList();
    }

    // Sort
    if (_sort == 'az') {
      _displayProperties.sort((a, b) =>
          a.area.toLowerCase().compareTo(b.area.toLowerCase()));
    }
  }

  void _toggleAmenity(int amenityId) {
    setState(() {
      if (!_selectedAmenityIds.remove(amenityId)) {
        _selectedAmenityIds.add(amenityId);
      }
      _applyFilters();
    });
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedAmenityIds.clear();
      _selectedTransactionType = 'All';
      _selectedPropertyType = 'All';
      _applyFilters();
    });
  }

  /// Number shown on the filter button badge.
  int get _activeFilterCount =>
      _selectedAmenityIds.length + (_selectedTransactionType != 'All' ? 1 : 0);

  /// raw propertyType -> display label, built from the loaded data.
  Map<String, String> get _propertyTypeLabels {
    final map = <String, String>{};
    for (final p in _allProperties) {
      if (p.propertyType.isEmpty) continue;
      map.putIfAbsent(p.propertyType, () => p.formattedPropertyType);
    }
    return map;
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  TextStyle _t(double size, FontWeight weight, Color color,
      {double? height, double? letterSpacing}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.slate50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchSection(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _C.navy,
      foregroundColor: Colors.white,
      elevation: 3,
      shadowColor: const Color(0x33000000),
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      automaticallyImplyLeading: false,
      toolbarHeight: 60,
      titleSpacing: 8,
      title: Row(
        children: [
          if (Navigator.of(context).canPop())
            IconButton(
              tooltip: 'Go Back',
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              onPressed: () => Navigator.maybePop(context),
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Properties',
                    style: _t(16, FontWeight.w700, Colors.white,
                        height: 1.2, letterSpacing: -0.2)),
                Text('MIDC Plots, Warehouses & Land',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(11, FontWeight.w500, const Color(0xFFBFDBFE))),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Shortlisted',
          onPressed: () {
            // TODO: open shortlisted properties
          },
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.bookmark_border, color: Colors.white, size: 22),
              if (_favorites.isNotEmpty)
                Positioned(
                  top: 0,
                  right: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: _C.amber400,
                      shape: BoxShape.circle,
                      border: Border.all(color: _C.navy, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'More Options',
          onPressed: () {},
          icon: const Icon(Icons.more_vert, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Search + chips + count bar
  // ---------------------------------------------------------------------------

  Widget _buildSearchSection() {
    final typeLabels = _propertyTypeLabels;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _C.slate200)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search + filter button
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    style: _t(13, FontWeight.w500, _C.slate900),
                    decoration: InputDecoration(
                      hintText: 'Search by city, area, address...',
                      hintStyle: _t(13, FontWeight.w500, _C.slate400),
                      filled: true,
                      fillColor: _C.slate50,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      prefixIcon: const Icon(Icons.search,
                          size: 18, color: _C.slate400),
                      prefixIconConstraints:
                      const BoxConstraints(minWidth: 40, minHeight: 40),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                        onTap: () => _searchController.clear(),
                        child: const Icon(Icons.close,
                            size: 16, color: _C.slate400),
                      )
                          : null,
                      suffixIconConstraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                      border: _searchBorder(_C.slate200, 1),
                      enabledBorder: _searchBorder(_C.slate200, 1),
                      focusedBorder: _searchBorder(_C.blue600, 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _FilterButton(
                count: _activeFilterCount,
                onTap: _openFilterSheet,
              ),
            ],
          ),

          // Category chips
          if (typeLabels.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _CategoryChip(
                    label: 'All Properties',
                    selected: _selectedPropertyType == 'All',
                    onTap: () => setState(() {
                      _selectedPropertyType = 'All';
                      _applyFilters();
                    }),
                  ),
                  ...typeLabels.entries.map(
                        (e) => _CategoryChip(
                      label: e.value,
                      selected: _selectedPropertyType == e.key,
                      onTap: () => setState(() {
                        _selectedPropertyType = e.key;
                        _applyFilters();
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Result count + sort
          if (!_isLoading && _error == null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: _C.emerald500, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Expanded(child: _buildCountText()),
                const SizedBox(width: 8),
                _buildSortMenu(),
              ],
            ),
          ],
        ],
      ),
    );
  }

  OutlineInputBorder _searchBorder(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  Widget _buildCountText() {
    final n = _displayProperties.length;
    final cities = <String>[];
    for (final p in _displayProperties) {
      if (p.city.isNotEmpty && !cities.contains(p.city)) cities.add(p.city);
    }
    String where = '';
    if (cities.isNotEmpty) {
      where = ' in ${cities.take(2).join(' & ')}';
      if (cities.length > 2) where += ' +${cities.length - 2}';
    }
    return Text.rich(
      TextSpan(
        style: _t(12, FontWeight.w500, _C.slate500),
        children: [
          TextSpan(
            text: '$n verified ${n == 1 ? 'listing' : 'listings'}',
            style: _t(12, FontWeight.w700, _C.slate900),
          ),
          TextSpan(text: where),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Sort',
      onSelected: (v) => setState(() {
        _sort = v;
        _applyFilters();
      }),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'relevant',
          child: Text('Relevant', style: _t(13, FontWeight.w600, _C.slate900)),
        ),
        PopupMenuItem(
          value: 'az',
          child:
          Text('Location (A–Z)', style: _t(13, FontWeight.w600, _C.slate900)),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sort: ${_sort == 'az' ? 'A–Z' : 'Relevant'}',
              style: _t(12, FontWeight.w700, _C.blue700)),
          const SizedBox(width: 2),
          const Icon(Icons.expand_more, size: 16, color: _C.blue700),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_C.navy),
        ),
      );
    }

    if (_displayProperties.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      color: _C.navy,
      onRefresh: _loadData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _displayProperties.length + 1, // + advisory banner
        itemBuilder: (context, index) {
          if (index == _displayProperties.length) {
            return _buildAdvisoryBanner();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPropertyCard(_displayProperties[index]),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Property card
  // ---------------------------------------------------------------------------

  Color _transactionColor(String type) {
    switch (type.toLowerCase()) {
      case 'sale':
        return _C.amber500;
      case 'lease':
        return _C.emerald600;
      case 'rent':
        return _C.blue600;
      default:
        return _C.slate700;
    }
  }

  Widget _buildPropertyCard(Property property) {
    final isFav = _favorites.contains(property.slug);
    final title = '${property.area}, ${property.city}';
    final amenities = property.amenities;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.slate200),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(property),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Media banner ----
            SizedBox(
              height: 190,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  property.primaryImageUrl.isNotEmpty
                      ? Image.network(
                    property.primaryImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    loadingBuilder: (c, child, progress) =>
                    progress == null ? child : _imagePlaceholder(),
                  )
                      : _imagePlaceholder(),
                  // top scrim so the tags stay readable on photos
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Color(0x66000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _Tag(
                                text: property.formattedPropertyType,
                                color: const Color(0xE61E255E),
                              ),
                              _Tag(
                                text: property.formattedTransactionType,
                                color: _transactionColor(
                                    property.transactionType),
                              ),
                              const _VerifiedTag(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() {
                            if (!_favorites.remove(property.slug)) {
                              _favorites.add(property.slug);
                            }
                          }),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xE6FFFFFF),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 3,
                                    offset: Offset(0, 1)),
                              ],
                            ),
                            child: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              size: 16,
                              color: isFav ? Colors.red : _C.slate700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ---- Body ----
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(16, FontWeight.w700, _C.slate900,
                        letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.location_on_outlined,
                            size: 14, color: _C.slate400),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _t(12, FontWeight.w500, _C.slate500,
                              height: 1.35),
                        ),
                      ),
                    ],
                  ),

                  // Amenity badges
                  if (amenities.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < amenities.take(3).length; i++)
                          _AmenityChip(
                            label: amenities[i].name,
                            highlighted: i == 0,
                            style: _t(
                                11,
                                FontWeight.w500,
                                i == 0 ? _C.blue800 : _C.slate700),
                          ),
                        if (amenities.length > 3)
                          _AmenityChip(
                            label: '+${amenities.length - 3} more',
                            highlighted: false,
                            style: _t(11, FontWeight.w600, _C.slate500),
                          ),
                      ],
                    ),
                  ],

                  // Footer
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: _C.slate100),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              property.formattedMinPrice,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _t(20, FontWeight.w800, _C.navy,
                                  height: 1.2),
                            ),
                            Text('Starting price',
                                style: _t(10, FontWeight.w500, _C.slate500)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => _openDetail(property),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.navy,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('View Details',
                                style: _t(12, FontWeight.w700, Colors.white)),
                            const SizedBox(width: 6),
                            const Icon(Icons.chevron_right, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(Property property) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumPropertyDetailScreen(
          slug: property.slug,
          previewName: '${property.area}, ${property.city}',
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [_C.slate200, _C.slate100, _C.slate200],
        ),
      ),
      child: const Center(
        child: Icon(Icons.apartment, size: 88, color: Color(0x99CBD5E1)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Advisory banner
  // ---------------------------------------------------------------------------

  Widget _buildAdvisoryBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.amber50, _C.orange50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.amber200),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0x1AF59E0B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.business_center_outlined,
                size: 20, color: _C.amber700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Looking for custom MIDC Land?',
                    style: _t(12, FontWeight.w700, _C.amber950)),
                const SizedBox(height: 2),
                Text(
                  'Get assistance with land allocation, NOCs & factory setup.',
                  style: _t(11, FontWeight.w400, _C.amber800, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              // TODO: hook up "Request Call" action
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.amber600,
              foregroundColor: Colors.white,
              elevation: 1,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child:
            Text('Request Call', style: _t(11, FontWeight.w700, Colors.white)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty / error state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    final isError = _error != null;
    final color = isError ? _C.error : _C.navy;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error_outline : Icons.apartment_outlined,
                size: 52,
                color: color.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(isError ? 'Failed to Load' : 'No Properties Found',
                style: _t(18, FontWeight.w700, _C.slate900)),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Try changing your filters or search query.',
              textAlign: TextAlign.center,
              style: _t(13, FontWeight.w500, _C.slate500, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isError ? _loadData : _clearAllFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: isError ? _C.error : _C.navy,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(isError ? Icons.refresh : Icons.filter_alt_off,
                  size: 18),
              label: Text(isError ? 'Retry' : 'Clear Filters',
                  style: _t(14, FontWeight.w600, Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter bottom sheet
  // ---------------------------------------------------------------------------

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _C.slate300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Filters', style: _t(18, FontWeight.w700, _C.slate900)),
                    TextButton(
                      onPressed: () {
                        setModalState(() {});
                        _clearAllFilters();
                      },
                      child: Text('Clear All',
                          style: _t(13, FontWeight.w700, _C.blue700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Transaction type
                Text('Transaction Type',
                    style: _t(13, FontWeight.w700, _C.slate900)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['All', 'sale', 'rent', 'lease', 'pg'].map((type) {
                    final selected = _selectedTransactionType == type;
                    return ChoiceChip(
                      label: Text(
                        type == 'All'
                            ? 'All'
                            : (type == 'pg' ? 'PG' : _cap(type)),
                        style: _t(12, FontWeight.w600,
                            selected ? Colors.white : _C.slate700),
                      ),
                      selected: selected,
                      showCheckmark: false,
                      selectedColor: _C.navy,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                            color: selected ? _C.navy : _C.slate200),
                      ),
                      onSelected: (_) {
                        setModalState(() {});
                        setState(() {
                          _selectedTransactionType = type;
                          _applyFilters();
                        });
                      },
                    );
                  }).toList(),
                ),

                // Amenities
                if (_allAmenities.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Amenities',
                      style: _t(13, FontWeight.w700, _C.slate900)),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.35,
                    ),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allAmenities.map((amenity) {
                          final selected =
                          _selectedAmenityIds.contains(amenity.id);
                          return FilterChip(
                            label: Text(
                              amenity.name,
                              style: _t(12, FontWeight.w600,
                                  selected ? Colors.white : _C.slate700),
                            ),
                            selected: selected,
                            selectedColor: _C.navy,
                            backgroundColor: Colors.white,
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                  color: selected ? _C.navy : _C.slate200),
                            ),
                            onSelected: (_) {
                              setModalState(() {});
                              _toggleAmenity(amenity.id);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.navy,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Show ${_displayProperties.length} Results',
                      style: _t(14, FontWeight.w700, Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Small reusable widgets
// -----------------------------------------------------------------------------

class _FilterButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _FilterButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _C.slate100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.slate200),
            ),
            child: const Icon(Icons.tune, size: 18, color: _C.slate700),
          ),
          if (count > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _C.blue600,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _C.navy : _C.slate100,
            borderRadius: BorderRadius.circular(99),
            border: selected ? null : Border.all(color: _C.slate200),
            boxShadow: selected
                ? const [
              BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 2,
                  offset: Offset(0, 1))
            ]
                : null,
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : _C.slate700,
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _VerifiedTag extends StatelessWidget {
  const _VerifiedTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _C.emerald600,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            'Verified',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenityChip extends StatelessWidget {
  final String label;
  final bool highlighted;
  final TextStyle style;

  const _AmenityChip({
    required this.label,
    required this.highlighted,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted ? _C.blue50 : _C.slate100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: highlighted ? _C.blue100 : _C.slate200),
      ),
      child: Text(label, style: style),
    );
  }
}