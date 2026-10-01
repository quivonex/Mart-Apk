import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/property_model.dart';
import '../services/real_estate_service.dart';
import 'property_enquiry_screen.dart';

// =============================================================================
// PREMIUM design — immersive gallery, dark price card, configuration selector,
// expandable pricing, amenity icons, availability bars.
//
// Same constructor as the Standard screen. To use it, just navigate to
// PremiumPropertyDetailScreen(slug: ..., previewName: ...) instead.
// =============================================================================

class _C {
  static const navy = Color(0xFF1E255E);
  static const navyDeep = Color(0xFF141A45);
  static const navyMid = Color(0xFF2B3480);
  static const gold = Color(0xFFE5B84B);
  static const goldSoft = Color(0xFFFFF4D6);
  static const surface = Color(0xFFF6F7FB);
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate700 = Color(0xFF334155);
  static const slate900 = Color(0xFF0F172A);
  static const blue200 = Color(0xFFBFDBFE);
  static const emerald = Color(0xFF059669);
  static const emeraldBg = Color(0xFFECFDF5);
  static const amber = Color(0xFFD97706);
  static const red = Color(0xFFDC2626);
  static const redBg = Color(0xFFFEF2F2);
}

TextStyle _t(double size, FontWeight w, Color c,
    {double? height, double? ls}) =>
    GoogleFonts.plusJakartaSans(
        fontSize: size, fontWeight: w, color: c, height: height, letterSpacing: ls);

// ---- helpers ----------------------------------------------------------------

String _group(int n) {
  final s = n.abs().toString();
  final sign = n < 0 ? '-' : '';
  if (s.length <= 3) return '$sign$s';
  final last3 = s.substring(s.length - 3);
  final rest = s.substring(0, s.length - 3).replaceAllMapped(
    RegExp(r'(\d)(?=(\d{2})+$)'),
        (m) => '${m[1]},',
  );
  return '$sign$rest,$last3';
}

String _money(Object? v) {
  final s = '$v'.trim();
  final n = num.tryParse(s.replaceAll(',', ''));
  if (n == null) return s;
  final parts = n.toStringAsFixed(2).split('.');
  final frac = parts[1] == '00' ? '' : '.${parts[1]}';
  return '₹${_group(int.parse(parts[0]))}$frac';
}

bool _isZero(String s) {
  final t = s.trim();
  if (t.isEmpty) return true;
  final n = num.tryParse(t.replaceAll(',', ''));
  return n != null && n == 0;
}

String _scheduleValue(Object? v) {
  final s = '$v'.trim();
  if (s.contains('%')) return s;
  return num.tryParse(s) != null ? _money(s) : s;
}

String _prettifyKey(String key) {
  if (key.isEmpty) return key;
  final s = key.replaceAll('_', ' ');
  return s[0].toUpperCase() + s.substring(1);
}

IconData _amenityIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('pool') || n.contains('swim')) return Icons.pool;
  if (n.contains('gym') || n.contains('fitness')) return Icons.fitness_center;
  if (n.contains('park')) return Icons.local_parking;
  if (n.contains('garden') || n.contains('landscap')) return Icons.park_outlined;
  if (n.contains('lift') || n.contains('elevator')) return Icons.elevator_outlined;
  if (n.contains('secur') || n.contains('guard')) return Icons.security;
  if (n.contains('cctv') || n.contains('camera')) return Icons.videocam_outlined;
  if (n.contains('club')) return Icons.deck_outlined;
  if (n.contains('play') || n.contains('kid') || n.contains('child')) {
    return Icons.child_care;
  }
  if (n.contains('power') || n.contains('backup') || n.contains('generator')) {
    return Icons.bolt;
  }
  if (n.contains('water')) return Icons.water_drop_outlined;
  if (n.contains('fire')) return Icons.local_fire_department_outlined;
  if (n.contains('wifi') || n.contains('internet')) return Icons.wifi;
  if (n.contains('spa') || n.contains('yoga') || n.contains('meditat')) {
    return Icons.spa_outlined;
  }
  if (n.contains('sport') || n.contains('court') || n.contains('tennis')) {
    return Icons.sports_tennis;
  }
  return Icons.check_circle_outline;
}

// =============================================================================
// Screen
// =============================================================================

class PremiumPropertyDetailScreen extends StatefulWidget {
  final String slug;
  final String? previewName;

  const PremiumPropertyDetailScreen({
    super.key,
    required this.slug,
    this.previewName,
  });

  @override
  State<PremiumPropertyDetailScreen> createState() =>
      _PremiumPropertyDetailScreenState();
}

class _PremiumPropertyDetailScreenState
    extends State<PremiumPropertyDetailScreen> {
  static const double _expandedHeight = 360;

  final ScrollController _scroll = ScrollController();

  PropertyDetail? _property;
  bool _isLoading = true;
  String? _error;

  int _currentImageIndex = 0;
  bool _collapsed = false;
  bool _isFavorite = false;
  bool _descExpanded = false;
  int _selectedFlat = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadDetail();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final collapsed =
        _scroll.hasClients && _scroll.offset > _expandedHeight - kToolbarHeight - 40;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await RealEstateService.getPropertyDetail(widget.slug);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (response.isSuccess) {
        _property = response.data;
        _selectedFlat = 0;
      } else {
        _error = response.message ?? 'Failed to load property details';
      }
    });
  }

  void _openEnquiry() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PropertyEnquiryScreen(property: _property!),
      ),
    );
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _C.navy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _shareSummary() {
    final p = _property!;
    _copyToClipboard(
      '${p.area}, ${p.city} — ${p.formattedMinPrice} onwards\n${p.address}',
      'Property details copied',
    );
  }

  void _openViewer(int index) {
    final urls = _property!.images.map((i) => i.imageS3Key).toList();
    if (urls.isEmpty) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) =>
            _GalleryViewer(urls: urls, initialIndex: index),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _C.surface,
        appBar: _simpleAppBar(),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_C.navy),
          ),
        ),
      );
    }

    if (_property == null) {
      return Scaffold(
        backgroundColor: _C.surface,
        appBar: _simpleAppBar(),
        body: _buildErrorState(),
      );
    }

    return Scaffold(
      backgroundColor: _C.surface,
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  AppBar _simpleAppBar() {
    return AppBar(
      backgroundColor: _C.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(widget.previewName ?? 'Property Detail',
          style: _t(16, FontWeight.w700, Colors.white)),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom bar — price + CTA
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar() {
    final p = _property!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Color(0x1F0F172A), blurRadius: 24, offset: Offset(0, -6)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Starting price',
                    style: _t(10.5, FontWeight.w500, _C.slate500)),
                Text(p.formattedMinPrice,
                    style: _t(19, FontWeight.w800, _C.navy, ls: -0.4)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_C.navyMid, _C.navy],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x401E255E),
                          blurRadius: 12,
                          offset: Offset(0, 6)),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _openEnquiry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.mail_outline, size: 20),
                    label: Text('Enquire Now',
                        style: _t(15, FontWeight.w700, Colors.white)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  Widget _buildBody() {
    final p = _property!;
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        _buildSliverAppBar(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitleBlock(),
                const SizedBox(height: 16),
                _buildPriceCard(),
                const SizedBox(height: 16),
                _buildHighlights(),
                if (p.description.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _buildAbout(),
                ],
                if (p.flatTypes.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _sectionTitle('Configuration', 'Choose a unit type'),
                  const SizedBox(height: 14),
                  _buildConfiguration(),
                ],
                if (p.pricingSlabs.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _sectionTitle('Pricing', 'Tap a plan for payment details'),
                  const SizedBox(height: 14),
                  ...List.generate(
                    p.pricingSlabs.length,
                        (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PricingCard(
                        slab: p.pricingSlabs[i],
                        initiallyExpanded: i == 0,
                      ),
                    ),
                  ),
                ],
                if (p.amenities.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionTitle('Amenities', null),
                  const SizedBox(height: 14),
                  _buildAmenities(),
                ],
                if (p.floors.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _sectionTitle('Floor Availability', 'Live unit count'),
                  const SizedBox(height: 14),
                  ...p.floors.map(_buildFloorCard),
                ],
                if (p.features.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _sectionTitle('Features', null),
                  const SizedBox(height: 14),
                  _buildFeatures(),
                ],
                if (p.reraNumber.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _buildReraCard(),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sliver app bar + gallery
  // ---------------------------------------------------------------------------

  Widget _buildSliverAppBar() {
    final p = _property!;
    return SliverAppBar(
      pinned: true,
      expandedHeight: _expandedHeight,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: _C.navy,
      automaticallyImplyLeading: false,
      leadingWidth: 62,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
        child: _GlassButton(
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onTap: () => Navigator.maybePop(context),
        ),
      ),
      title: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _collapsed ? 1 : 0,
        child: Text(widget.previewName ?? p.area,
            style: _t(16, FontWeight.w700, Colors.white)),
      ),
      actions: [
        _GlassButton(
          icon: Icons.ios_share,
          tooltip: 'Share',
          onTap: _shareSummary,
        ),
        const SizedBox(width: 8),
        _GlassButton(
          icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
          iconColor: _isFavorite ? const Color(0xFFFF6B81) : Colors.white,
          tooltip: 'Save',
          onTap: () => setState(() => _isFavorite = !_isFavorite),
        ),
        const SizedBox(width: 16),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _buildGallery(),
      ),
    );
  }

  Widget _buildGallery() {
    final p = _property!;
    final images = p.images;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (images.isEmpty)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_C.navyDeep, _C.navyMid],
              ),
            ),
            child: const Center(
              child: Icon(Icons.apartment, size: 96, color: Color(0x33FFFFFF)),
            ),
          )
        else
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => _openViewer(index),
              child: Image.network(
                images[index].imageS3Key,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (c, child, progress) => progress == null
                    ? child
                    : Container(color: _C.navyDeep),
                errorBuilder: (_, __, ___) => Container(
                  color: _C.navyDeep,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        size: 48, color: Color(0x66FFFFFF)),
                  ),
                ),
              ),
            ),
          ),

        // top + bottom scrims
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 120,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 170,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xB3000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),

        // rounded sheet edge
        Positioned(
          left: 0,
          right: 0,
          bottom: -1,
          height: 28,
          child: Container(
            decoration: const BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
          ),
        ),

        // badges (bottom-left)
        Positioned(
          left: 16,
          bottom: 44,
          child: Row(
            children: [
              if (p.isVerified)
                _imageBadge('Verified', Icons.verified, _C.emerald,
                    Colors.white),
              if (p.isVerified && p.isFeatured) const SizedBox(width: 6),
              if (p.isFeatured)
                _imageBadge('Featured', Icons.star_rounded, _C.gold, _C.navyDeep),
            ],
          ),
        ),

        // photo counter (bottom-right)
        if (images.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 44,
            child: GestureDetector(
              onTap: () => _openViewer(_currentImageIndex),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0x8C000000),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library_outlined,
                        size: 13, color: Colors.white),
                    const SizedBox(width: 5),
                    Text('${_currentImageIndex + 1} / ${images.length}',
                        style: _t(11, FontWeight.w700, Colors.white)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _imageBadge(String label, IconData icon, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label, style: _t(10.5, FontWeight.w800, fg)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Title block
  // ---------------------------------------------------------------------------

  Widget _buildTitleBlock() {
    final p = _property!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _pill(p.formattedPropertyType, _C.navy, const Color(0x141E255E)),
            _pill(p.formattedTransactionType, _C.amber, const Color(0xFFFFF4E0)),
          ],
        ),
        const SizedBox(height: 12),
        Text('${p.area}, ${p.city}',
            style: _t(26, FontWeight.w800, _C.slate900, ls: -0.6, height: 1.15)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.location_on, size: 16, color: _C.navy),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(p.address,
                  style: _t(13, FontWeight.w500, _C.slate500, height: 1.45)),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Dark price card
  // ---------------------------------------------------------------------------

  Widget _buildPriceCard() {
    final p = _property!;
    final showProgress = p.isUnderConstruction && p.completionPercentage.isNotEmpty;
    final progress = ((double.tryParse(p.completionPercentage) ?? 0) / 100)
        .clamp(0.0, 1.0)
        .toDouble();

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.navyDeep, _C.navy, _C.navyMid],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x331E255E), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x40E5B84B), Color(0x00E5B84B)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('STARTING PRICE',
                              style: _t(10, FontWeight.w700, _C.blue200,
                                  ls: 1.4)),
                          const SizedBox(height: 4),
                          Text(p.formattedMinPrice,
                              style: _t(32, FontWeight.w800, Colors.white,
                                  ls: -1, height: 1.1)),
                        ],
                      ),
                    ),
                    if (p.isNegotiable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0x26E5B84B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x66E5B84B)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_offer_outlined,
                                size: 13, color: _C.gold),
                            const SizedBox(width: 4),
                            Text('Negotiable',
                                style: _t(10.5, FontWeight.w800, _C.gold)),
                          ],
                        ),
                      ),
                  ],
                ),
                if (showProgress || p.possessionDate.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(height: 1, color: const Color(0x1FFFFFFF)),
                  const SizedBox(height: 16),
                ],
                if (showProgress) ...[
                  Row(
                    children: [
                      Text('Construction progress',
                          style: _t(11.5, FontWeight.w600, _C.blue200)),
                      const Spacer(),
                      Text('${p.completionPercentage}%',
                          style: _t(13, FontWeight.w800, _C.gold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: const Color(0x26FFFFFF),
                      valueColor: const AlwaysStoppedAnimation<Color>(_C.gold),
                    ),
                  ),
                ],
                if (p.possessionDate.isNotEmpty) ...[
                  if (showProgress) const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.event_available_outlined,
                          size: 16, color: _C.blue200),
                      const SizedBox(width: 8),
                      Text('Possession',
                          style: _t(11.5, FontWeight.w600, _C.blue200)),
                      const Spacer(),
                      Text(p.possessionDate,
                          style: _t(13, FontWeight.w800, Colors.white)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Highlights grid
  // ---------------------------------------------------------------------------

  Widget _buildHighlights() {
    final p = _property!;
    final items = <_Highlight>[
      if (p.totalArea.isNotEmpty)
        _Highlight(Icons.aspect_ratio, 'Total Area', '${p.totalArea} sqft'),
      if (p.plotArea.isNotEmpty)
        _Highlight(Icons.crop_square, 'Plot Area', '${p.plotArea} sqft'),
      if (p.totalFloors.isNotEmpty)
        _Highlight(Icons.layers_outlined, 'Floors', p.totalFloors),
      if (p.totalTowers.isNotEmpty)
        _Highlight(Icons.apartment, 'Towers', p.totalTowers),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        final cols = items.length >= 3 ? 3 : items.length;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map((h) => SizedBox(
            width: w,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: _cardDecoration(radius: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0x141E255E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(h.icon, size: 17, color: _C.navy),
                  ),
                  const SizedBox(height: 10),
                  Text(h.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _t(13, FontWeight.w800, _C.slate900)),
                  const SizedBox(height: 1),
                  Text(h.label,
                      style: _t(10.5, FontWeight.w500, _C.slate500)),
                ],
              ),
            ),
          ))
              .toList(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // About
  // ---------------------------------------------------------------------------

  Widget _buildAbout() {
    final desc = _property!.description;
    final long = desc.length > 170;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('About this property', null),
        const SizedBox(height: 12),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: Text(
            desc,
            maxLines: (!long || _descExpanded) ? null : 4,
            overflow: TextOverflow.fade,
            style: _t(13.5, FontWeight.w500, _C.slate500, height: 1.7),
          ),
        ),
        if (long)
          GestureDetector(
            onTap: () => setState(() => _descExpanded = !_descExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_descExpanded ? 'Show less' : 'Read more',
                  style: _t(12.5, FontWeight.w800, _C.navy)),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Configuration (selector + detail card)
  // ---------------------------------------------------------------------------

  Widget _buildConfiguration() {
    final flats = _property!.flatTypes;
    final idx = _selectedFlat.clamp(0, flats.length - 1);
    final flat = flats[idx];
    final ok = flat.isAvailable;

    final specs = <_Spec>[
      if (flat.carpetArea > 0)
        _Spec(Icons.square_foot, 'Carpet', '${flat.carpetArea} sqft'),
      if (flat.builtUpArea > 0)
        _Spec(Icons.home_work_outlined, 'Built-up', '${flat.builtUpArea} sqft'),
      if (flat.areaSqft > 0)
        _Spec(Icons.aspect_ratio, 'Total', '${flat.areaSqft} sqft'),
      if (flat.bedrooms > 0)
        _Spec(Icons.bed_outlined, 'Bedrooms', '${flat.bedrooms}'),
      if (flat.bathrooms > 0)
        _Spec(Icons.bathtub_outlined, 'Bathrooms', '${flat.bathrooms}'),
      if (flat.balconies > 0)
        _Spec(Icons.deck_outlined, 'Balconies', '${flat.balconies}'),
      if (flat.parkingCount > 0)
        _Spec(Icons.local_parking, 'Parking', '${flat.parkingCount}'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: flats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final selected = i == idx;
              return GestureDetector(
                onTap: () => setState(() => _selectedFlat = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? _C.navy : Colors.white,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(
                        color: selected ? _C.navy : _C.slate200),
                    boxShadow: selected
                        ? const [
                      BoxShadow(
                          color: Color(0x331E255E),
                          blurRadius: 10,
                          offset: Offset(0, 4))
                    ]
                        : null,
                  ),
                  child: Text(flats[i].flatType,
                      style: _t(13, FontWeight.w700,
                          selected ? Colors.white : _C.slate700)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Container(
            key: ValueKey(idx),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(radius: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(flat.flatType,
                          style: _t(20, FontWeight.w800, _C.slate900,
                              ls: -0.4)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ok ? _C.emeraldBg : _C.redBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: ok ? _C.emerald : _C.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(ok ? 'Available' : 'Sold Out',
                              style: _t(10.5, FontWeight.w800,
                                  ok ? _C.emerald : _C.red)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (flat.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(flat.description,
                      style: _t(12.5, FontWeight.w500, _C.slate500)),
                ],
                if (specs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, c) {
                      const gap = 10.0;
                      final w = (c.maxWidth - gap) / 2;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: specs
                            .map((s) => SizedBox(
                          width: w,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _C.slate50,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                    BorderRadius.circular(10),
                                    border: Border.all(
                                        color: _C.slate200),
                                  ),
                                  child: Icon(s.icon,
                                      size: 17, color: _C.navy),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(s.label,
                                          style: _t(10, FontWeight.w500,
                                              _C.slate500)),
                                      Text(s.value,
                                          maxLines: 1,
                                          overflow:
                                          TextOverflow.ellipsis,
                                          style: _t(12.5,
                                              FontWeight.w800,
                                              _C.slate900)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ))
                            .toList(),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Amenities
  // ---------------------------------------------------------------------------

  Widget _buildAmenities() {
    final items = _property!.amenities;
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        final w = (c.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map((a) => SizedBox(
            width: w,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 14),
              decoration: _cardDecoration(radius: 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0x141E255E),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_amenityIcon(a.name),
                        size: 20, color: _C.navy),
                  ),
                  const SizedBox(height: 8),
                  Text(a.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: _t(11, FontWeight.w700, _C.slate900,
                          height: 1.25)),
                ],
              ),
            ),
          ))
              .toList(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Floors
  // ---------------------------------------------------------------------------

  Widget _buildFloorCard(PropertyFloor floor) {
    final avail = num.tryParse('${floor.availableUnits}') ?? 0;
    final total = num.tryParse('${floor.totalUnits}') ?? 0;
    final ratio = total > 0 ? (avail / total).clamp(0.0, 1.0).toDouble() : 0.0;
    final Color color = avail <= 0
        ? _C.red
        : ratio <= 0.25
        ? _C.amber
        : _C.emerald;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(radius: 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(floor.floorName,
                      style: _t(14, FontWeight.w800, _C.slate900)),
                ),
                Text('${floor.availableUnits}',
                    style: _t(14, FontWeight.w800, color)),
                Text(' / ${floor.totalUnits} available',
                    style: _t(11.5, FontWeight.w600, _C.slate500)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: _C.slate100,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Features
  // ---------------------------------------------------------------------------

  Widget _buildFeatures() {
    final entries = _property!.features.entries.toList();
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        final w = (c.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: entries
              .map((e) => SizedBox(
            width: w,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: _cardDecoration(radius: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_prettifyKey(e.key),
                      style: _t(10.5, FontWeight.w500, _C.slate500)),
                  const SizedBox(height: 3),
                  Text(e.value.toString(),
                      style: _t(13, FontWeight.w800, _C.slate900)),
                ],
              ),
            ),
          ))
              .toList(),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // RERA
  // ---------------------------------------------------------------------------

  Widget _buildReraCard() {
    final p = _property!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_C.navyDeep, _C.navy],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0x26E5B84B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.verified_user, color: _C.gold, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('RERA REGISTERED',
                    style: _t(9.5, FontWeight.w800, _C.gold, ls: 1.3)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Flexible(
                      child: Text(p.reraNumber,
                          overflow: TextOverflow.ellipsis,
                          style: _t(16, FontWeight.w800, Colors.white)),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () =>
                          _copyToClipboard(p.reraNumber, 'RERA number copied'),
                      child: const Icon(Icons.copy_rounded,
                          size: 15, color: _C.blue200),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (p.reraQrCode.isNotEmpty) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.network(
                p.reraQrCode,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                const SizedBox(width: 52, height: 52),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared bits
  // ---------------------------------------------------------------------------

  Widget _sectionTitle(String title, String? subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _t(18, FontWeight.w800, _C.slate900, ls: -0.4)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: _t(12, FontWeight.w500, _C.slate500)),
        ],
      ],
    );
  }

  Widget _pill(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration:
      BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label.toUpperCase(),
          style: _t(10, FontWeight.w800, fg, ls: 0.8)),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration:
              const BoxDecoration(color: _C.redBg, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline, size: 52, color: _C.red),
            ),
            const SizedBox(height: 20),
            Text('Failed to Load', style: _t(18, FontWeight.w800, _C.slate900)),
            const SizedBox(height: 8),
            Text(_error ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: _t(13, FontWeight.w500, _C.slate500, height: 1.4)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadDetail,
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.navy,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('Retry', style: _t(14, FontWeight.w700, Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Small data holders + reusable widgets
// =============================================================================

class _Highlight {
  final IconData icon;
  final String label;
  final String value;
  const _Highlight(this.icon, this.label, this.value);
}

class _Spec {
  final IconData icon;
  final String label;
  final String value;
  const _Spec(this.icon, this.label, this.value);
}

BoxDecoration _cardDecoration({double radius = 16}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: _C.slate200),
  boxShadow: const [
    BoxShadow(
        color: Color(0x0A0F172A), blurRadius: 12, offset: Offset(0, 4)),
  ],
);

/// Round translucent button used on top of the gallery.
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color iconColor;

  const _GlassButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0x59000000),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x33FFFFFF)),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// Expandable pricing plan with payment-schedule timeline.
class _PricingCard extends StatefulWidget {
  final PricingSlabDetail slab;
  final bool initiallyExpanded;

  const _PricingCard({required this.slab, this.initiallyExpanded = false});

  @override
  State<_PricingCard> createState() => _PricingCardState();
}

class _PricingCardState extends State<_PricingCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final slab = widget.slab;
    final schedule = slab.paymentSchedule;
    final charges = slab.additionalCharges;
    final hasMore = (schedule != null && schedule.isNotEmpty) ||
        (charges != null && charges.isNotEmpty);

    final stats = <MapEntry<String, String>>[
      if (!_isZero(slab.pricePerSqft))
        MapEntry('Per sqft', _money(slab.pricePerSqft)),
      if (!_isZero(slab.bookingAmount))
        MapEntry('Booking', _money(slab.bookingAmount)),
      if (!_isZero(slab.discountPercentage))
        MapEntry('Discount', '${slab.discountPercentage}%'),
      if (!_isZero(slab.gstPercentage))
        MapEntry('GST', '${slab.gstPercentage}%'),
    ];

    return Container(
      decoration: _cardDecoration(radius: 20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: hasMore ? () => setState(() => _expanded = !_expanded) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(slab.flatType,
                                style: _t(16, FontWeight.w800, _C.slate900)),
                            if (slab.floor > 0)
                              Text('Floor ${slab.floor}',
                                  style:
                                  _t(11.5, FontWeight.w500, _C.slate500)),
                          ],
                        ),
                      ),
                      Text(slab.formattedBasePrice,
                          style: _t(19, FontWeight.w800, _C.navy, ls: -0.4)),
                      if (hasMore) ...[
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          duration: const Duration(milliseconds: 200),
                          turns: _expanded ? 0.5 : 0,
                          child: const Icon(Icons.expand_more,
                              color: _C.slate400),
                        ),
                      ],
                    ],
                  ),
                  if (stats.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        for (var i = 0; i < stats.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 9, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _C.slate50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(stats[i].key,
                                      style: _t(
                                          9.5, FontWeight.w500, _C.slate500)),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(stats[i].value,
                                        style: _t(12, FontWeight.w800,
                                            _C.slate900)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded && hasMore
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _C.slate100)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (schedule != null && schedule.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('PAYMENT SCHEDULE',
                        style: _t(10, FontWeight.w800, _C.slate500, ls: 1.2)),
                    const SizedBox(height: 12),
                    ..._timeline(schedule.entries.toList()),
                  ],
                  if (charges != null && charges.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('ADDITIONAL CHARGES',
                        style: _t(10, FontWeight.w800, _C.slate500, ls: 1.2)),
                    const SizedBox(height: 8),
                    ...charges.entries.map(
                          (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(_prettifyKey(e.key),
                                  style:
                                  _t(12.5, FontWeight.w500, _C.slate500)),
                            ),
                            Text(_money(e.value),
                                style:
                                _t(12.5, FontWeight.w800, _C.slate900)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _timeline(List<MapEntry<dynamic, dynamic>> entries) {
    return List.generate(entries.length, (i) {
      final e = entries[i];
      final last = i == entries.length - 1;
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 18,
              child: Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(
                      color: _C.navy,
                      shape: BoxShape.circle,
                      border: Border.all(color: _C.slate200, width: 2),
                    ),
                  ),
                  if (!last)
                    Expanded(
                      child: Container(width: 2, color: _C.slate200),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: last ? 0 : 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_prettifyKey('${e.key}'),
                          style: _t(12.5, FontWeight.w600, _C.slate700)),
                    ),
                    Text(_scheduleValue(e.value),
                        style: _t(12.5, FontWeight.w800, _C.slate900)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// Full-screen, pinch-to-zoom image viewer.
class _GalleryViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _GalleryViewer({required this.urls, required this.initialIndex});

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _controller =
  PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  widget.urls[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white38,
                      size: 56),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _GlassButton(
                    icon: Icons.close,
                    tooltip: 'Close',
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x59FFFFFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_index + 1} / ${widget.urls.length}',
                        style: _t(12, FontWeight.w700, Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}