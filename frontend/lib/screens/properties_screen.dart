import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/property_model.dart';
import '../services/real_estate_service.dart';
import 'property_detail_screen.dart';
import 'property_schedule_visit_sheet.dart';
import 'property_video_screen.dart';
import 'package:qnx_mart/l10n/app_language.dart';
// ── QNX MART logo colours (private to this screen) ──────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
const _kBrand = Color(0xFF093C71);
const _kBrandDark = Color(0xFF062A50);
const _kBrandLight = Color(0xFF1E5A9C);
const _kHeader = LinearGradient(
  colors: [_kBrandDark, _kBrand, _kBrandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Design tokens from the HTML design (Tailwind slate / brand palette).
class _C {
  static const navy = Color(0xFF062A50);
  static const navyDark = Color(0xFF062A50);
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate900 = Color(0xFF0F172A);
  static const blue50 = Color(0xFFEAF1F9);
  static const blue100 = Color(0xFFC9DBEE);
  static const blue200 = Color(0xFFC9DBEE);
  static const blue600 = Color(0xFF093C71);
  static const blue700 = Color(0xFF062A50);
  static const blue800 = Color(0xFF062A50);
  static const emerald500 = Color(0xFF10B981);
  static const emerald600 = Color(0xFF10B981);
  static const amber400 = Color(0xFFF7931E);
  static const amber500 = Color(0xFFF7931E);
  static const amber600 = Color(0xFFF7931E);
  static const amber700 = Color(0xFFC2410C);
  static const amber800 = Color(0xFFC2410C);
  static const amber950 = Color(0xFF7C2D12);
  static const amber50 = Color(0xFFFFF7ED);
  static const orange50 = Color(0xFFFFF7ED);
  static const amber200 = Color(0xFFFED7AA);
  static const orange500 = Color(0xFFF7931E); // ✅ image tag orange
  static const error = Color(0xFFC62828);
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
  String _selectedPropertyType = 'All';
  String _sort = 'relevant';

  final Set<String> _favorites = {};

  // ✅ Track current image index per property card
  final Map<String, int> _cardImageIndex = {};

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
        _error = propertyRes.message ?? tr('No properties found');
      }
      _allAmenities = amenityRes.data;
    });
  }

  void _applyFilters() {
    _displayProperties = List.from(_allProperties);

    if (_selectedPropertyType != 'All') {
      _displayProperties = _displayProperties
          .where((p) =>
      p.propertyType.toLowerCase() ==
          _selectedPropertyType.toLowerCase())
          .toList();
    }

    if (_selectedTransactionType != 'All') {
      _displayProperties = _displayProperties
          .where((p) =>
      p.transactionType.toLowerCase() ==
          _selectedTransactionType.toLowerCase())
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      _displayProperties = _displayProperties
          .where((p) =>
      p.city.toLowerCase().contains(_searchQuery) ||
          p.area.toLowerCase().contains(_searchQuery) ||
          p.address.toLowerCase().contains(_searchQuery) ||
          p.propertyType.toLowerCase().contains(_searchQuery))
          .toList();
    }

    if (_selectedAmenityIds.isNotEmpty) {
      _displayProperties = _displayProperties.where((p) {
        final ids = p.amenities.map((a) => a.id).toSet();
        return _selectedAmenityIds.every(ids.contains);
      }).toList();
    }

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

  int get _activeFilterCount =>
      _selectedAmenityIds.length + (_selectedTransactionType != 'All' ? 1 : 0);

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
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeader)),
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
              tooltip: tr('Go Back'),
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
                Text(tr('Properties'),
                    style: _t(16, FontWeight.w700, Colors.white,
                        height: 1.2, letterSpacing: -0.2)),
                Text(tr('MIDC Plots, Warehouses & Land'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(11, FontWeight.w500, const Color(0xFFC9DBEE))),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: tr('Shortlisted'),
          onPressed: () {},
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
          tooltip: tr('More Options'),
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
                      hintText: tr('Search by city, area, address...'),
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

          if (typeLabels.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _CategoryChip(
                    label: tr('All Properties'),
                    selected: _selectedPropertyType == 'All',
                    onTap: () => setState(() {
                      _selectedPropertyType = 'All';
                      _applyFilters();
                    }),
                  ),
                  ...typeLabels.entries.map(
                        (e) => _CategoryChip(
                      label: tr(e.value),
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
          TextSpan(text: tr(where)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      tooltip: tr('Sort'),
      onSelected: (v) => setState(() {
        _sort = v;
        _applyFilters();
      }),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'relevant',
          child: Text(tr('Relevant'), style: _t(13, FontWeight.w600, _C.slate900)),
        ),
        PopupMenuItem(
          value: 'az',
          child:
          Text(tr('Location (A–Z)'), style: _t(13, FontWeight.w600, _C.slate900)),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tr('Sort: {0}', [_sort == 'az' ? 'A–Z' : 'Relevant']),
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
        itemCount: _displayProperties.length + 1,
        itemBuilder: (context, index) {
          if (index == _displayProperties.length) {
            return _buildAdvisoryBanner();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPropertyCard(_displayProperties[index]),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Property card — matches 2nd screenshot
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
    final images = property.imageUrls;
    final totalImages = images.isEmpty ? 1 : images.length;
    final currentIdx = (_cardImageIndex[property.slug] ?? 0)
        .clamp(0, totalImages - 1);

    // Title: "Flat / Apartment in Pune"
    final displayTitle = property.title.isNotEmpty
        ? property.title
        : '${property.formattedPropertyType}${property.city.isEmpty ? '' : ' in ${property.city}'}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.slate200),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(property),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============ IMAGE CAROUSEL ============
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image carousel
                  if (images.isEmpty)
                    _imagePlaceholder()
                  else
                    PageView.builder(
                      itemCount: totalImages,
                      onPageChanged: (i) => setState(
                              () => _cardImageIndex[property.slug] = i),
                      itemBuilder: (_, i) => Image.network(
                        images[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                        loadingBuilder: (c, child, progress) => progress == null
                            ? child
                            : _imagePlaceholder(),
                      ),
                    ),

                  // Top gradient scrim (for tag readability)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Color(0x66000000), Color(0x00000000)],
                      ),
                    ),
                  ),

                  // Bottom subtle scrim (for dots readability)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 60,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0x55000000), Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ---- TOP-LEFT: Property type tag (orange) ----
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _C.orange500,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.apartment,
                              size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(
                            tr(property.formattedPropertyType),
                            style: _t(11, FontWeight.w700, Colors.white,
                                letterSpacing: 0.2),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ---- TOP-RIGHT: Transaction tag (white pill) ----
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 4,
                              offset: Offset(0, 1)),
                        ],
                      ),
                      child: Text(
                        tr(property.formattedTransactionType),
                        style: _t(11, FontWeight.w700, _C.navy),
                      ),
                    ),
                  ),

                  // ---- LEFT ARROW ----
                  if (totalImages > 1 && currentIdx > 0)
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            final newIdx = currentIdx - 1;
                            setState(() => _cardImageIndex[property.slug] = newIdx);
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x33000000), blurRadius: 4),
                              ],
                            ),
                            child: const Icon(Icons.chevron_left,
                                size: 22, color: _C.slate900),
                          ),
                        ),
                      ),
                    ),

                  // ---- RIGHT ARROW ----
                  if (totalImages > 1 && currentIdx < totalImages - 1)
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            final newIdx = currentIdx + 1;
                            setState(() => _cardImageIndex[property.slug] = newIdx);
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x33000000), blurRadius: 4),
                              ],
                            ),
                            child: const Icon(Icons.chevron_right,
                                size: 22, color: _C.slate900),
                          ),
                        ),
                      ),
                    ),

                  // ---- BOTTOM-RIGHT: Photo counter (camera + 5/7) ----
                  if (totalImages > 0)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_camera_outlined,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${currentIdx + 1}/$totalImages',
                              style: _t(11, FontWeight.w700, Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ---- BOTTOM-CENTER: Page dots ----
                  if (totalImages > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 14,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < totalImages && i < 6; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: i == currentIdx ? 16 : 6,
                              height: 4,
                              decoration: BoxDecoration(
                                color: i == currentIdx
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ============ BODY (compact) ============
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ---- Title + price ----
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          tr(displayTitle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(15.5, FontWeight.w800, _C.navy,
                              height: 1.25, letterSpacing: -0.2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            tr(property.formattedMinPrice),
                            maxLines: 1,
                            style: _t(16.5, FontWeight.w800, _C.blue700,
                                letterSpacing: -0.3),
                          ),
                          Text('onwards',
                              style: _t(9.5, FontWeight.w600, _C.slate400)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // ---- Location ----
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 14, color: _C.slate500),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          tr([property.area, property.city].where((s) => s.isNotEmpty).join(', ')),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(12, FontWeight.w600, _C.slate500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // ---- One compact action row ----
                  Row(
                    children: [
                      _cardAction(
                        icon: Icons.visibility_outlined,
                        label: tr('Details'),
                        fg: _C.navy,
                        bg: _C.slate50,
                        border: _C.slate200,
                        onTap: () => _openDetail(property),
                      ),
                      const SizedBox(width: 6),
                      _cardAction(
                        icon: Icons.play_circle_fill,
                        label: tr('Video'),
                        fg: _C.blue600,
                        bg: const Color(0xFFEAF1F9),
                        border: _C.blue200,
                        onTap: () => _openVideo(property),
                      ),
                      const SizedBox(width: 6),
                      _cardAction(
                        icon: Icons.event_available_rounded,
                        label: tr('Visit'),
                        fg: _C.blue600,
                        bg: _C.blue50,
                        border: _C.blue200,
                        onTap: () => _scheduleVisit(property),
                      ),
                      const SizedBox(width: 6),
                      _cardAction(
                        icon: Icons.chat_bubble_outline,
                        label: tr('Enquire'),
                        fg: Colors.white,
                        bg: _kBrand,
                        onTap: () => _openEnquiry(property),
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

  /// Small icon + label button used in the compact card action row.
  Widget _cardAction({
    required IconData icon,
    required String label,
    required Color fg,
    Color? bg,
    Color? border,
    Gradient? gradient,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            height: 46,
            decoration: BoxDecoration(
              color: gradient == null ? bg : null,
              gradient: gradient,
              borderRadius: BorderRadius.circular(10),
              border: border == null ? null : Border.all(color: border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: fg),
                const SizedBox(height: 2),
                Text(tr(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _t(11, FontWeight.w700, fg)),
              ],
            ),
          ),
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

  Future<void> _openEnquiry(Property property) async {
    if (property.slug.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: _C.navy),
      ),
    );
    final r = await RealEstateService.getPropertyDetail(property.slug);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (r.isSuccess && r.data != null) {
      // ignore: use_build_context_synchronously
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PremiumPropertyDetailScreen(
            slug: property.slug,
            previewName: '${property.area}, ${property.city}',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.message ?? tr('Could not open enquiry'))),
      );
    }
  }

  /// Plays the property's video tour (videos come from the detail API).
  void _openVideo(Property property) {
    PropertyVideoScreen.openForSlug(
      context,
      slug: property.slug,
      title: property.displayTitle,
      subtitle: '${property.area}, ${property.city}',
    );
  }

  /// Opens the "Schedule a site visit" form for this property.
  Future<void> _scheduleVisit(Property property) async {
    final sent = await showScheduleVisitSheet(
      context,
      propertyId: property.id,
      propertyTitle: property.displayTitle,
      location: '${property.area}, ${property.city}',
    );
    if (!sent || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('Site visit requested. Our team will confirm shortly.')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _C.emerald600,
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
        child: Icon(Icons.apartment, size: 60, color: Color(0x99CBD5E1)),
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
              color: const Color(0x1AF7931E),
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
                Text(tr('Looking for custom MIDC Land?'),
                    style: _t(12, FontWeight.w700, _C.amber950)),
                const SizedBox(height: 2),
                Text(
                  tr('Get assistance with land allocation, NOCs & factory setup.'),
                  style: _t(11, FontWeight.w400, _C.amber800, height: 1.25),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: _kBrand, // buttons: only #093C71
              foregroundColor: Colors.white,
              elevation: 1,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child:
            Text(tr('Request Call'), style: _t(11, FontWeight.w700, Colors.white)),
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
            Text(isError ? tr('Failed to Load') : tr('No Properties Found'),
                style: _t(18, FontWeight.w700, _C.slate900)),
            const SizedBox(height: 8),
            Text(
              _error ?? tr('Try changing your filters or search query.'),
              textAlign: TextAlign.center,
              style: _t(13, FontWeight.w500, _C.slate500, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isError ? _loadData : _clearAllFilters,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBrand, // buttons: only #093C71
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(isError ? Icons.refresh : Icons.filter_alt_off,
                  size: 18),
              label: Text(isError ? tr('Retry') : tr('Clear Filters'),
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
                    Text(tr('Filters'), style: _t(18, FontWeight.w700, _C.slate900)),
                    TextButton(
                      onPressed: () {
                        setModalState(() {});
                        _clearAllFilters();
                      },
                      child: Text(tr('Clear All'),
                          style: _t(13, FontWeight.w700, _C.blue700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Text(tr('Transaction Type'),
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
                            ? tr('All')
                            : (type == 'pg' ? tr('PG') : _cap(type)),
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

                if (_allAmenities.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(tr('Amenities'),
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
                              trData(amenity.name),
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
                      backgroundColor: _kBrand, // buttons: only #093C71
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      tr('Show {0} Results', [_displayProperties.length]),
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
            tr(label),
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
