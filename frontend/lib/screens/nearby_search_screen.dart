// lib/screens/nearby_search_screen.dart
//
// QNX Mart › Nearby Search (Google Places through the QNX backend)
//
//   ┌ Search bar ─────────────────┐ [10 km ▾] [→]
//   ┌ Google Map ──────────────────────────────┐
//   │  tap anywhere = set search location        │
//   │  circle = radius, numbered pins = results  │
//   └──────────────────────────── [◎ my location]┘
//   Results list  → tap a place →  bottom sheet:
//        [ Chat on WhatsApp ]   [ View on Map (directions) ]
//
// API: POST admin_profile/places/nearby/ (needs login token + active subscription –
//      see NearbyPlacesService). 401 → login again. 403 subscription_required →
//      "View plans" (header button "Subscription" → NearbySubscriptionScreen).

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// OpenStreetMap fallback (no API key) when the Google Maps script is not on the page.
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';
import '../constants/design_tokens.dart';
import '../services/nearby_places_service.dart';
import '../services/nearby_subscription_service.dart';
import '../utils/login_gate.dart';
import '../utils/google_maps_check.dart'; // web / mobile version picked automatically
import '../utils/shared_preferences_helper.dart';
import 'login_screen.dart';
import 'nearby_subscription_screen.dart';
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

class _NS {
  static const brand = Color(0xFF093C71);
  static const brandDark = Color(0xFF062A50);
  static const violet = Color(0xFF1E5A9C);
  static const orange = Color(0xFFF7931E);
  static const whatsapp = Color(0xFF25D366);
  static const whatsappDark = Color(0xFF128C7E);
  static const greenDark = Color(0xFF047857);
  static const green = Color(0xFF22C55E);
  static const amber = Color(0xFFF7931E);
  static const bg = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
  static const tint = Color(0xFFEAF1F9);
  static const tintLine = Color(0xFFC9DBEE);
  static const ink = Color(0xFF0F172A);
  static const body = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
}

/// Radius options in km (Google allows up to 50 km).
const _radiusKm = <int>[5, 10, 15, 20, 25, 30, 35, 40, 45, 50];

/// Suggestions shown before the first search: (label, keyword)
const _suggestions = <(String, String)>[
  ('Transport', 'transport'),
  ('Packers & Movers', 'packers and movers'),
  ('Warehouse', 'warehouse'),
  ('Hardware', 'hardware store'),
  ('Courier', 'courier service'),
  ('Electrician', 'electrician'),
];

/// Default point when GPS is not available (Pune).
const _defaultPoint = LatLng(18.5204, 73.8567);

class NearbySearchScreen extends StatefulWidget {
  /// Optional keyword to search right away (e.g. 'transport').
  final String? initialKeyword;
  const NearbySearchScreen({super.key, this.initialKeyword});

  @override
  State<NearbySearchScreen> createState() => _NearbySearchScreenState();
}

class _NearbySearchScreenState extends State<NearbySearchScreen> {
  final _query = TextEditingController();
  GoogleMapController? _gmap;

  LatLng _point = _defaultPoint;
  String _pointLabel = 'Pune';
  bool _locating = false;
  int _km = 10;

  bool _loading = false;
  bool _searched = false;
  String? _error;
  bool _needsLogin = false;
  bool _needsSubscription = false;
  String _lastKeyword = '';
  List<NearbyPlace> _places = [];

  /// Saved Nearby plan of this user (active or expired) – for the header button.
  NearbyActiveSub? _sub;

  /// Web: the Maps <script> may finish loading after the first frame → re-check.
  /// While Google Maps is not available an OpenStreetMap map is shown instead.
  bool _mapsOk = googleMapsLoaded();
  Timer? _mapsTimer;
  final _osm = fm.MapController();
  bool _osmReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialKeyword != null) _query.text = widget.initialKeyword!;
    _loadSub();
    if (!_mapsOk) {
      var tries = 0;
      _mapsTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
        tries++;
        if (googleMapsLoaded()) {
          t.cancel();
          if (mounted) {
            setState(() {
              _mapsOk = true;
              _osmReady = false;
            });
          }
        } else if (tries >= 30) {
          t.cancel();
        }
      });
    }
    // setState() is not allowed inside initState → start after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _useMyLocation(quiet: true);
      if (mounted && widget.initialKeyword != null) _search();
    });
  }

  @override
  void dispose() {
    _mapsTimer?.cancel();
    _query.dispose();
    _gmap?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ location
  Future<void> _useMyLocation({bool quiet = false}) async {
    setState(() => _locating = true);
    String? problem;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        problem = 'Location is turned off.';
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          problem = 'Location permission denied.';
        } else {
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium)
              .timeout(const Duration(seconds: 15));
          if (!mounted) return;
          _setPoint(LatLng(pos.latitude, pos.longitude), 'My location');
          setState(() => _locating = false);
          return;
        }
      }
    } catch (_) {
      problem = 'Could not get your location.';
    }
    if (!mounted) return;
    setState(() => _locating = false);
    if (!quiet) _snack('$problem Tap on the map to choose a location.');
  }

  /// Sets the search centre (map tap / GPS) and re-runs the search if one was done.
  void _setPoint(LatLng p, String label) {
    setState(() {
      _point = p;
      _pointLabel = label;
    });
    _fitRadius();
    if (_searched && !_loading) _search();
  }

  /// Zooms the map so the whole radius circle is visible.
  void _fitRadius() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final m = _km * 1000.0;
      final dLat = m / 111320.0;
      final dLng = m / (111320.0 * math.cos(_point.latitude * math.pi / 180)).abs().clamp(1.0, double.infinity);
      final south = _point.latitude - dLat, north = _point.latitude + dLat;
      final west = _point.longitude - dLng, east = _point.longitude + dLng;
      // Google Map
      final ctrl = _gmap;
      if (_mapsOk && ctrl != null) {
        try {
          final b = LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east));
          ctrl.animateCamera(CameraUpdate.newLatLngBounds(b, 24));
        } catch (_) {}
      }
      // OpenStreetMap fallback
      if (!_mapsOk && _osmReady) {
        try {
          _osm.fitCamera(fm.CameraFit.bounds(
            bounds: fm.LatLngBounds(ll.LatLng(south, west), ll.LatLng(north, east)),
            padding: const EdgeInsets.all(24),
          ));
        } catch (_) {}
      }
    });
  }

  // ------------------------------------------------------------ search
  Future<void> _search([String? keyword]) async {
    if (keyword != null) _query.text = keyword;
    FocusScope.of(context).unfocus();
    final q = _query.text.trim();
    if (q.isEmpty) {
      _snack('Type what you are looking for (e.g. transport, warehouse).');
      return;
    }
    // The API needs a logged-in user.
    if (!await _hasToken()) {
      if (!mounted) return;
      await ensureLoggedIn(context, reason: 'search nearby places');
      if (!await _hasToken()) return;
    }
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _needsLogin = false;
      _needsSubscription = false;
      _searched = true;
      _lastKeyword = q;
    });
    final r = await NearbyPlacesService.search(
      lat: _point.latitude,
      lng: _point.longitude,
      keyword: q,
      radiusMeters: _km * 1000,
    );
    if (!mounted || q != _lastKeyword) return;
    // Nearest first; places without a location go to the end.
    final list = List.of(r.places)
      ..sort((a, b) {
        if (a.distanceKm < 0 && b.distanceKm < 0) return 0;
        if (a.distanceKm < 0) return 1;
        if (b.distanceKm < 0) return -1;
        return a.distanceKm.compareTo(b.distanceKm);
      });
    setState(() {
      _loading = false;
      _places = list;
      _error = r.ok ? null : r.message;
      _needsLogin = r.needsLogin;
      _needsSubscription = r.needsSubscription;
    });
    if (r.needsSubscription || r.needsLogin) _loadSub();
    _fitRadius();
  }

  // ------------------------------------------------------------ subscription
  Future<void> _loadSub() async {
    final s = await NearbySubscriptionStore.load();
    if (mounted) setState(() => _sub = s);
  }

  /// Opens the plans. Coming back with an active plan re-runs the search.
  Future<void> _openPlans() async {
    if (!await ensureLoggedIn(context, reason: 'see the Nearby Search plans')) return;
    if (!mounted) return;
    final active = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NearbySubscriptionScreen()),
    );
    await _loadSub();
    if (!mounted) return;
    if (active == true && _query.text.trim().isNotEmpty && (_needsSubscription || _searched)) _search();
  }

  Future<bool> _hasToken() async {
    final t = await SharedPreferencesHelper.getAccessToken();
    return t != null && t.isNotEmpty;
  }

  Future<void> _openLogin() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    await _loadSub();
    if (mounted && await _hasToken()) _search();
  }

  // ------------------------------------------------------------ actions
  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white)),
        backgroundColor: _NS.ink,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  Future<void> _launch(Uri uri, String what) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _snack('Could not open $what.');
  }

  void _openWhatsApp(NearbyPlace p) {
    final n = p.whatsappNumber;
    if (n.isEmpty) {
      _snack('WhatsApp number is not available for this place.');
      return;
    }
    final text = Uri.encodeComponent('Hi ${p.name}, I found your business on QNX Mart. I would like to know more.');
    _launch(Uri.parse('https://wa.me/$n?text=$text'), 'WhatsApp');
  }

  void _openDirections(NearbyPlace p) {
    if (p.hasLocation) {
      _launch(p.directionsUri, 'Google Maps');
      return;
    }
    // No coordinates → search the name / address in Google Maps.
    final q = Uri.encodeComponent('${p.name} ${p.address}'.trim());
    _launch(Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'), 'Google Maps');
  }

  /// Bottom sheet with the 2 options: Chat on WhatsApp / View on Map.
  void _showOptions(NearbyPlace p) {
    final hasWa = p.whatsappNumber.isNotEmpty;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: _NS.line, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _placeIcon(p, 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DT.text(size: 16, weight: FontWeight.w800, color: _NS.ink, height: 1.25)),
                        const SizedBox(height: 4),
                        _ratingRow(p),
                        if (p.address.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(p.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: DT.text(size: 12, color: _NS.muted, height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _sheetButton(
                icon: Icons.chat_rounded,
                label: 'Chat on WhatsApp',
                sub: hasWa ? p.phone : 'Number not available',
                color: hasWa ? _NS.whatsapp : _NS.hint,
                onTap: () {
                  Navigator.pop(ctx);
                  _openWhatsApp(p);
                },
              ),
              const SizedBox(height: 10),
              _sheetButton(
                icon: Icons.directions_rounded,
                label: 'View on Map',
                sub: p.hasLocation
                    ? 'Directions in Google Maps · ${_dist(p.distanceKm)}'
                    : 'Search in Google Maps',
                color: _NS.brand,
                onTap: () {
                  Navigator.pop(ctx);
                  _openDirections(p);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetButton({
    required IconData icon,
    required String label,
    required String sub,
    required Color color,
    required VoidCallback onTap,
  }) =>
      Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: DT.text(size: 15, weight: FontWeight.w800, color: _NS.ink)),
                      const SizedBox(height: 2),
                      Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 12, color: _NS.muted)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: color),
              ],
            ),
          ),
        ),
      );

  // ------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final mapH = (MediaQuery.of(context).size.height * 0.36).clamp(220.0, 360.0);
    return Scaffold(
      backgroundColor: _NS.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeader)),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Nearby Search', style: DT.text(size: 17, weight: FontWeight.w700, color: Colors.white)),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 10), child: _planButton()),
        ],
      ),
      body: Column(
        children: [
          _searchBar(),
          SizedBox(height: mapH, child: _map()),
          Expanded(child: _results()),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ header "Subscription" button
  Widget _planButton() {
    final s = _sub;
    final active = s != null && s.isActive;
    final label = active ? '${s!.planName} · ${s.daysLeft}d left' : 'Subscription';
    return Tooltip(
      message: active ? 'Plan active till ${nearbyDate(s!.expiresAt)}' : 'Buy a Nearby Search plan',
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _openPlans,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 170),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(active ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                    size: 16, color: active ? _NS.green : Colors.white),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 12, weight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ search bar + radius dropdown
  Widget _searchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: (_) => setState(() {}),
              style: DT.text(size: 14, weight: FontWeight.w600, color: _NS.ink),
              decoration: InputDecoration(
                hintText: 'Search transport, shops…',
                hintStyle: DT.text(size: 13.5, color: _NS.hint),
                prefixIcon: const Icon(Icons.search_rounded, color: _NS.muted),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                  onPressed: () => setState(_query.clear),
                  icon: const Icon(Icons.close_rounded, size: 18, color: _NS.hint),
                ),
                isDense: true,
                filled: true,
                fillColor: _NS.bg,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _NS.line)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _NS.brand, width: 1.6)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Radius dropdown 5 – 50 km
          Container(
            height: 46,
            padding: const EdgeInsets.only(left: 10, right: 4),
            decoration: BoxDecoration(
              color: _NS.tint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _NS.tintLine),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _km,
                borderRadius: BorderRadius.circular(14),
                dropdownColor: Colors.white,
                menuMaxHeight: 320,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _NS.brandDark),
                style: DT.text(size: 13, weight: FontWeight.w800, color: _NS.brandDark),
                items: [
                  for (final k in _radiusKm)
                    DropdownMenuItem(
                      value: k,
                      child: Text('$k km', style: DT.text(size: 13, weight: FontWeight.w800, color: _NS.brandDark)),
                    ),
                ],
                onChanged: (k) {
                  if (k == null || k == _km) return;
                  setState(() => _km = k);
                  _fitRadius();
                  if (_searched && !_loading) _search();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            height: 46,
            child: DecoratedBox(
              decoration: BoxDecoration(color: _kBrand, borderRadius: BorderRadius.circular(14)),
              child: IconButton(
                tooltip: 'Search',
                onPressed: _loading ? null : () => _search(),
                icon: _loading
                    ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ map
  /// Red pin = search location, orange pins = results (tap = WhatsApp / View on Map).
  Set<Marker> _markers() => {
    Marker(
      markerId: const MarkerId('selected_location'),
      position: _point,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: 'Search here', snippet: '$_km km radius'),
      zIndex: 2,
    ),
    for (var i = 0; i < _places.length; i++)
      if (_places[i].hasLocation)
        Marker(
          markerId: MarkerId(_places[i].canOpen ? 'place_${_places[i].placeId}' : 'place_row_$i'),
          position: LatLng(_places[i].lat, _places[i].lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: '${i + 1}. ${_places[i].name}',
            snippet: _places[i].canOpen ? 'Tap for WhatsApp / View on Map' : null,
            onTap: _places[i].canOpen ? () => _showOptions(_places[i]) : null,
          ),
          onTap: _places[i].canOpen ? () => _showOptions(_places[i]) : null,
        ),
  };

  Widget _map() {
    return Stack(
      children: [
        if (!_mapsOk)
          _osmMap()
        else
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _point, zoom: 11),
            onMapCreated: (c) {
              _gmap = c;
              _fitRadius();
            },
            onTap: (latLng) => _setPoint(latLng, 'Selected on map'),
            mapType: MapType.normal,
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // own button (works on web too)
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            compassEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            markers: _markers(),
            circles: {
              Circle(
                circleId: const CircleId('search_radius'),
                center: _point,
                radius: _km * 1000.0,
                fillColor: _NS.brand.withValues(alpha: 0.10),
                strokeColor: _NS.brand.withValues(alpha: 0.6),
                strokeWidth: 2,
              ),
            },
          ),
        // Hint
        Positioned(
          top: 10,
          left: 10,
          right: 60,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Color(0x220F172A), blurRadius: 8)],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.touch_app_rounded, size: 15, color: _NS.brand),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text('Tap on the map to set location',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 11.5, weight: FontWeight.w700, color: _NS.ink)),
                  ),
                ],
              ),
            ),
          ),
        ),
        // My location button
        Positioned(
          top: 8,
          right: 10,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 3,
            child: IconButton(
              tooltip: 'My location',
              onPressed: _locating ? null : () => _useMyLocation(),
              icon: _locating
                  ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _NS.brand))
                  : const Icon(Icons.my_location_rounded, color: _NS.brand),
            ),
          ),
        ),
        // Current point label
        Positioned(
          left: 10,
          top: 46,
          right: 60,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _NS.ink.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_pointLabel · ${_point.latitude.toStringAsFixed(4)}, ${_point.longitude.toStringAsFixed(4)} · $_km km',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DT.text(size: 11, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ results
  Widget _results() {
    if (_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: _NS.brand, strokeWidth: 3)),
              const SizedBox(height: 12),
              Text('Searching "$_lastKeyword" within $_km km…',
                  textAlign: TextAlign.center, style: DT.text(size: 13.5, weight: FontWeight.w700, color: _NS.ink)),
              const SizedBox(height: 4),
              Text('This can take a few seconds.',
                  textAlign: TextAlign.center, style: DT.text(size: 12, color: _NS.muted)),
            ],
          ),
        ),
      );
    }
    if (!_searched) return _intro();
    if (_needsSubscription) {
      final m = (_error ?? '').toLowerCase();
      final limit = m.contains('limit') || m.contains('exhaust');
      return _message(
        Icons.workspace_premium_rounded,
        limit ? 'Plan limit reached' : 'Subscription required',
        _error ?? 'No active subscription found. Please purchase a plan.',
        buttonLabel: 'View plans',
        onButton: _openPlans,
      );
    }
    if (_error != null) {
      return _message(
        _needsLogin ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
        _needsLogin ? 'Login required' : 'Search failed',
        _error!,
        buttonLabel: _needsLogin ? 'Login' : 'Try again',
        onButton: _needsLogin ? _openLogin : () => _search(),
      );
    }
    if (_places.isEmpty) {
      return _message(Icons.search_off_rounded, 'No places found',
          'Nothing found for "$_lastKeyword" within $_km km. Try a bigger radius or another keyword.');
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: Text('${_places.length} results for "$_lastKeyword"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 13, weight: FontWeight.w800, color: _NS.ink)),
              ),
              Text('Nearest first', style: DT.text(size: 11.5, weight: FontWeight.w600, color: _NS.muted)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 20),
            itemCount: _places.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _tile(_places[i], i + 1),
          ),
        ),
      ],
    );
  }

  /// OpenStreetMap version of the map (used on web when the Google Maps
  /// <script> is not in web/index.html). Same behaviour: tap = set location,
  /// circle = radius, numbered orange pins = results.
  Widget _osmMap() {
    final c = ll.LatLng(_point.latitude, _point.longitude);
    return fm.FlutterMap(
      mapController: _osm,
      options: fm.MapOptions(
        initialCenter: c,
        initialZoom: 11,
        interactionOptions: const fm.InteractionOptions(
          flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _osmReady = true;
          _fitRadius();
        },
        onTap: (_, p) => _setPoint(LatLng(p.latitude, p.longitude), 'Selected on map'),
      ),
      children: [
        fm.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.qnxmart.app',
        ),
        fm.CircleLayer(circles: [
          fm.CircleMarker(
            point: c,
            radius: _km * 1000.0,
            useRadiusInMeter: true,
            color: _NS.brand.withValues(alpha: 0.10),
            borderColor: _NS.brand.withValues(alpha: 0.6),
            borderStrokeWidth: 2,
          ),
        ]),
        fm.MarkerLayer(markers: [
          for (var i = 0; i < _places.length; i++)
            if (_places[i].hasLocation)
              fm.Marker(
                point: ll.LatLng(_places[i].lat, _places[i].lng),
                width: 26,
                height: 26,
                child: GestureDetector(
                  onTap: _places[i].canOpen ? () => _showOptions(_places[i]) : null,
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _NS.orange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [BoxShadow(color: Color(0x330F172A), blurRadius: 4)],
                    ),
                    child: Text('${i + 1}',
                        style: DT.text(size: 10, weight: FontWeight.w900, color: Colors.white)),
                  ),
                ),
              ),
          // Search point (on top)
          fm.Marker(
            point: c,
            width: 40,
            height: 40,
            alignment: Alignment.topCenter,
            child: const Icon(Icons.location_on_rounded, size: 40, color: _NS.brand),
          ),
        ]),
        const fm.RichAttributionWidget(
          alignment: fm.AttributionAlignment.bottomLeft,
          attributions: [fm.TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }

  Widget _intro() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
    children: [
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_NS.brand, _NS.violet]),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.travel_explore_rounded, size: 30, color: Colors.white),
        ),
      ),
      const SizedBox(height: 12),
      Text('Find businesses near you',
          textAlign: TextAlign.center, style: DT.text(size: 16, weight: FontWeight.w800, color: _NS.ink)),
      const SizedBox(height: 4),
      Text('Set the location on the map, choose the distance and search.',
          textAlign: TextAlign.center, style: DT.text(size: 12.5, color: _NS.muted, height: 1.4)),
      const SizedBox(height: 14),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in _suggestions)
            ActionChip(
              onPressed: () => _search(s.$2),
              label: Text(s.$1),
              labelStyle: DT.text(size: 12, weight: FontWeight.w700, color: _NS.brandDark),
              backgroundColor: Colors.white,
              side: const BorderSide(color: _NS.tintLine),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
        ],
      ),
    ],
  );

  Widget _message(IconData icon, String title, String body, {String? buttonLabel, VoidCallback? onButton}) =>
      ListView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
        children: [
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: _NS.tint, shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: _NS.brand),
            ),
          ),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: DT.text(size: 16, weight: FontWeight.w800, color: _NS.ink)),
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center, style: DT.text(size: 13, color: _NS.muted, height: 1.45)),
          if (buttonLabel != null && onButton != null) ...[
            const SizedBox(height: 14),
            Center(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kBrand), // buttons: only #093C71
                onPressed: onButton,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ],
      );

  // ------------------------------------------------------------ result tile
  String _dist(double km) => km < 0 ? '—' : km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';

  Widget _placeIcon(NearbyPlace p, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: p.iconBg, borderRadius: BorderRadius.circular(12)),
    padding: EdgeInsets.all(size * 0.22),
    child: p.iconUrl.isEmpty
        ? const Icon(Icons.storefront_rounded, color: Colors.white)
        : Image.network(p.iconUrl,
        color: Colors.white,
        errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, color: Colors.white)),
  );

  Widget _ratingRow(NearbyPlace p) {
    final full = p.rating.floor();
    final half = p.rating - full >= 0.5;
    return Row(
      children: [
        Text(p.rating.toStringAsFixed(1), style: DT.text(size: 12, weight: FontWeight.w800, color: _NS.ink)),
        const SizedBox(width: 3),
        for (var i = 0; i < 5; i++)
          Icon(
            i < full ? Icons.star_rounded : (i == full && half ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: 13,
            color: _NS.amber,
          ),
        const SizedBox(width: 3),
        Flexible(
          child: Text('(${p.ratingsTotal})',
              overflow: TextOverflow.ellipsis, style: DT.text(size: 11, color: _NS.muted)),
        ),
      ],
    );
  }

  Widget _tile(NearbyPlace p, int rank) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: p.canOpen ? () => _showOptions(p) : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _NS.line),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _placeIcon(p, 44),
                  Positioned(
                    top: -5,
                    left: -5,
                    child: Container(
                      width: 19,
                      height: 19,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _NS.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text('$rank', style: DT.text(size: 8.5, weight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 14, weight: FontWeight.w800, color: _NS.ink)),
                    const SizedBox(height: 2),
                    _ratingRow(p),
                    if (p.category.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(p.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 11, weight: FontWeight.w600, color: _NS.body)),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (p.openNow != null) ...[
                          Text(p.openNow! ? 'Open' : 'Closed',
                              style: DT.text(
                                  size: 11,
                                  weight: FontWeight.w800,
                                  color: p.openNow! ? _NS.greenDark : const Color(0xFFC2410C))),
                          Text('  ·  ', style: DT.text(size: 11, color: _NS.hint)),
                        ],
                        Expanded(
                          child: Text(p.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DT.text(size: 11.5, color: _NS.muted)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: _NS.tint, borderRadius: BorderRadius.circular(20)),
                    child: Text(_dist(p.distanceKm),
                        style: DT.text(size: 10.5, weight: FontWeight.w800, color: _NS.brandDark)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_rounded,
                          size: 16, color: p.whatsappNumber.isEmpty ? _NS.line : _NS.whatsappDark),
                      const SizedBox(width: 6),
                      const Icon(Icons.directions_rounded, size: 16, color: _NS.brand),
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
}
