// lib/screens/nearby_search_screen.dart
//
// QNX Mart › Nearby Search (Google Places through the QNX backend)
//
//   ┌ Search bar ─────────────────┐ [10 km ▾] [→]
//   ┌ Map (OpenStreetMap – web AND mobile, same as Add Company) ┐
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
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// OpenStreetMap (no API key) – used on web and mobile, like the Add Company map.
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';
import '../constants/design_tokens.dart';
import '../services/nearby_places_service.dart';
import '../services/nearby_subscription_service.dart';
import '../utils/login_gate.dart';
import '../utils/shared_preferences_helper.dart';
import 'login_screen.dart';
import 'nearby_subscription_screen.dart';
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

/// Why the live location is not available (shown as a banner on the map).
enum _LocIssue { none, serviceOff, denied, blocked, failed }

class _NearbySearchScreenState extends State<NearbySearchScreen> with WidgetsBindingObserver {
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

  /// The map is OpenStreetMap (flutter_map) on web AND mobile – same as the
  /// Add Company map, no Google Maps API key needed. (`_mapsOk` = Google Map,
  /// kept off.)
  final bool _mapsOk = false;
  final _osm = fm.MapController();
  bool _osmReady = false;
  bool _satellite = false; // street / satellite toggle (like Add Company)

  // ---- live location ----
  StreamSubscription<Position>? _posSub;
  LatLng? _live; // latest GPS / browser position
  double _liveAccuracy = 0; // metres
  bool _followLive = true; // search centre follows the live location until the user taps the map
  bool _gotFix = false;
  _LocIssue _locIssue = _LocIssue.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialKeyword != null) _query.text = widget.initialKeyword!;
    _loadSub();
    // Ask for location permission as soon as the screen opens and follow the
    // live position (setState() is not allowed inside initState → after 1st frame).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _startLiveLocation();
      if (mounted && widget.initialKeyword != null) _search();
    });
  }

  /// Back from phone Settings (permission / GPS turned on) → try again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _locIssue != _LocIssue.none && !_locating) {
      _startLiveLocation();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _posSub?.cancel();
    _query.dispose();
    _gmap?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ live location
  /// Asks for permission (Android / iOS dialog, browser prompt on web), shows
  /// the current position right away and then keeps following it.
  Future<void> _startLiveLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locIssue = _LocIssue.none;
    });
    var issue = _LocIssue.none;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        issue = _LocIssue.serviceOff;
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.deniedForever) {
          issue = _LocIssue.blocked;
        } else if (perm != LocationPermission.whileInUse && perm != LocationPermission.always) {
          issue = _LocIssue.denied;
        } else {
          // Last known fix first (instant, mobile only), then a fresh one.
          if (!kIsWeb) {
            final last = await Geolocator.getLastKnownPosition();
            if (last != null && mounted) _onPosition(last);
          }
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
              .timeout(const Duration(seconds: 20));
          if (!mounted) return;
          _onPosition(pos);
          _listenLive();
        }
      }
    } on TimeoutException {
      issue = _gotFix ? _LocIssue.none : _LocIssue.failed;
      if (_gotFix) _listenLive();
    } catch (_) {
      issue = _gotFix ? _LocIssue.none : _LocIssue.failed;
    }
    if (!mounted) return;
    setState(() {
      _locating = false;
      _locIssue = issue;
    });
  }

  /// Keeps receiving positions while the screen is open (every ~25 m of movement).
  void _listenLive() {
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 25),
    ).listen(_onPosition, onError: (_) {});
  }

  void _onPosition(Position p) {
    if (!mounted) return;
    final here = LatLng(p.latitude, p.longitude);
    final before = _point;
    final first = !_gotFix;
    setState(() {
      _live = here;
      _liveAccuracy = p.accuracy;
      _gotFix = true;
      _locIssue = _LocIssue.none;
      if (_followLive) {
        _point = here;
        _pointLabel = tr('My location');
      }
    });
    if (!_followLive) return;
    if (first) {
      _fitRadius();
    } else {
      _moveCamera(here);
    }
    // Moved more than 1 km → refresh the results around the new position.
    if (!first && _searched && !_loading && _distanceKm(before, here) > 1.0) _search();
  }

  /// "My location" button: follow the live position again.
  void _goLive() {
    final here = _live;
    if (here == null || _locIssue != _LocIssue.none) {
      _followLive = true;
      _startLiveLocation();
      return;
    }
    setState(() {
      _followLive = true;
      _point = here;
      _pointLabel = tr('My location');
    });
    _fitRadius();
    if (_posSub == null) _listenLive();
    if (_searched && !_loading) _search();
  }

  /// Opens phone settings (blocked permission / GPS off). On web the browser
  /// asks again or the user allows it from the address bar.
  Future<void> _fixLocation() async {
    if (kIsWeb) {
      if (_locIssue == _LocIssue.blocked) {
        _snack(tr('Location is blocked for this site. Click the lock icon in the address bar → Location → Allow, then try again.'));
      }
      _startLiveLocation();
      return;
    }
    switch (_locIssue) {
      case _LocIssue.serviceOff:
        await Geolocator.openLocationSettings();
      case _LocIssue.blocked:
        await Geolocator.openAppSettings();
      default:
        _startLiveLocation();
    }
  }

  void _moveCamera(LatLng p) {
    if (_mapsOk) {
      try {
        _gmap?.animateCamera(CameraUpdate.newLatLng(p));
      } catch (_) {}
    } else if (_osmReady) {
      try {
        _osm.move(ll.LatLng(p.latitude, p.longitude), _osm.camera.zoom);
      } catch (_) {}
    }
  }

  static double _distanceKm(LatLng a, LatLng b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude) / 1000.0;

  /// Sets the search centre (map tap / GPS) and re-runs the search if one was done.
  void _setPoint(LatLng p, String label) {
    setState(() {
      _point = p;
      _pointLabel = label;
      _followLive = false; // the user picked a place → stop following the GPS
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
      _snack(tr('Type what you are looking for (e.g. transport, warehouse).'));
      return;
    }
    // The API needs a logged-in user.
    if (!await _hasToken()) {
      if (!mounted) return;
      await ensureLoggedIn(context, reason: tr('search nearby places'));
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
    if (!await ensureLoggedIn(context, reason: tr('see the Nearby Search plans'))) return;
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
        content: Text(tr(msg), style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white)),
        backgroundColor: _NS.ink,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  Future<void> _launch(Uri uri, String what) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) _snack(tr('Could not open {0}.', [what]));
  }

  void _openWhatsApp(NearbyPlace p) {
    final n = p.whatsappNumber;
    if (n.isEmpty) {
      _snack(tr('WhatsApp number is not available for this place.'));
      return;
    }
    final text = Uri.encodeComponent('Hi ${p.name}, I found your business on QNX Mart. I would like to know more.');
    _launch(Uri.parse('https://wa.me/$n?text=$text'), tr('WhatsApp'));
  }

  void _openDirections(NearbyPlace p) {
    if (p.hasLocation) {
      _launch(p.directionsUri, tr('Google Maps'));
      return;
    }
    // No coordinates → search the name / address in Google Maps.
    final q = Uri.encodeComponent('${p.name} ${p.address}'.trim());
    _launch(Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'), tr('Google Maps'));
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
                        Text(trData(p.name),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: DT.text(size: 16, weight: FontWeight.w800, color: _NS.ink, height: 1.25)),
                        const SizedBox(height: 4),
                        _ratingRow(p),
                        if (p.address.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(tr(p.address),
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
                label: tr('Chat on WhatsApp'),
                sub: hasWa ? p.phone : tr('Number not available'),
                color: hasWa ? _NS.whatsapp : _NS.hint,
                onTap: () {
                  Navigator.pop(ctx);
                  _openWhatsApp(p);
                },
              ),
              const SizedBox(height: 10),
              _sheetButton(
                icon: Icons.directions_rounded,
                label: tr('View on Map'),
                sub: p.hasLocation
                    ? tr('Directions in Google Maps · {0}', [_dist(p.distanceKm)])
                    : tr('Search in Google Maps'),
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
                      Text(tr(label), style: DT.text(size: 15, weight: FontWeight.w800, color: _NS.ink)),
                      const SizedBox(height: 2),
                      Text(tr(sub),
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
        title: Text(tr('Nearby Search'), style: DT.text(size: 17, weight: FontWeight.w700, color: Colors.white)),
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
    final label = active ? tr('{0} · {1}d left', [s!.planName, s.daysLeft]) : 'Subscription';
    return Tooltip(
      message: active ? tr('Plan active till {0}', [nearbyDate(s!.expiresAt)]) : tr('Buy a Nearby Search plan'),
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
                  child: Text(tr(label),
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
                hintText: tr('Search transport, shops…'),
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
                tooltip: tr('Search'),
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
  /// Blue pin = you (live), red pin = a place picked on the map,
  /// orange pins = results (tap = WhatsApp / View on Map).
  Set<Marker> _markers() => {
    if (_live != null)
      Marker(
        markerId: const MarkerId('live_location'),
        position: _live!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: tr('You are here'),
          snippet: _followLive ? tr('Searching within {0} km', [_km]) : tr('Live location'),
        ),
        zIndex: 3,
      ),
    if (!_followLive || _live == null)
      Marker(
        markerId: const MarkerId('selected_location'),
        position: _point,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: tr('Search here'), snippet: tr('{0} km radius', [_km])),
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
            snippet: _places[i].canOpen ? tr('Tap for WhatsApp / View on Map') : null,
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
            initialCameraPosition: CameraPosition(target: _point, zoom: _gotFix ? 13 : 11),
            onMapCreated: (c) {
              _gmap = c;
              _fitRadius();
            },
            onTap: (latLng) => _setPoint(latLng, tr('Selected on map')),
            mapType: MapType.normal,
            myLocationEnabled: !kIsWeb && _live != null, // blue dot (mobile); web uses the blue pin
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
                    child: Text(tr('Tap on the map to set location'),
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
              tooltip: _followLive ? tr('Following your live location') : tr('Go to my location'),
              onPressed: _locating ? null : _goLive,
              icon: _locating
                  ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _NS.brand))
                  : Icon(_followLive && _live != null ? Icons.my_location_rounded : Icons.location_searching_rounded,
                  color: _NS.brand),
            ),
          ),
        ),
        // Street / satellite toggle
        Positioned(
          top: 60,
          right: 10,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 3,
            child: IconButton(
              tooltip: _satellite ? tr('Street map') : tr('Satellite'),
              onPressed: () => setState(() => _satellite = !_satellite),
              icon: Icon(_satellite ? Icons.map_rounded : Icons.satellite_alt_rounded, color: _NS.brand),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_followLive && _live != null) ...[
                    const _LiveDot(size: 8),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      _followLive && _live != null
                          ? tr('Live location · {0}, {1} · {2} km', [_point.latitude.toStringAsFixed(4), _point.longitude.toStringAsFixed(4), _km])
                          : tr('{0} · {1}, {2} · {3} km', [_pointLabel, _point.latitude.toStringAsFixed(4), _point.longitude.toStringAsFixed(4), _km]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 11, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Finding your location (first fix)
        if (_locating && !_gotFix)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.white.withValues(alpha: 0.55),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: Color(0x220F172A), blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _NS.brand)),
                      const SizedBox(width: 10),
                      Text(tr('Finding your location…'),
                          style: DT.text(size: 12.5, weight: FontWeight.w700, color: _NS.ink)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Permission / GPS problem
        if (_locIssue != _LocIssue.none && !_locating)
          Positioned(left: 10, right: 10, bottom: 10, child: _locationBanner()),
      ],
    );
  }

  Widget _locationBanner() {
    final (String text, String button) = switch (_locIssue) {
      _LocIssue.serviceOff => (tr('Location (GPS) is turned off. Turn it on to see places near you.'), tr('Turn on')),
      _LocIssue.blocked => (
      kIsWeb
          ? tr('Location is blocked for this site. Allow it from the lock icon in the address bar.')
          : tr('Location permission is blocked. Allow it in Settings to see places near you.'),
      kIsWeb ? tr('Try again') : tr('Settings')
      ),
      _LocIssue.denied => (tr('Allow location access to see places near you.'), tr('Allow')),
      _ => (tr('Could not get your location. You can also tap on the map.'), tr('Retry')),
    };
    return Material(
      color: const Color(0xFFFFF7ED), // conditions: orange
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_off_rounded, size: 18, color: Color(0xFFC2410C)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tr(text),
                  style: DT.text(size: 11.5, weight: FontWeight.w600, color: const Color(0xFFC2410C), height: 1.3)),
            ),
            const SizedBox(width: 6),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kBrand, // buttons: only #093C71
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _fixLocation,
              child: Text(tr(button), style: DT.text(size: 12, weight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
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
              Text(tr('Searching "{0}" within {1} km…', [_lastKeyword, _km]),
                  textAlign: TextAlign.center, style: DT.text(size: 13.5, weight: FontWeight.w700, color: _NS.ink)),
              const SizedBox(height: 4),
              Text(tr('This can take a few seconds.'),
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
        limit ? tr('Plan limit reached') : tr('Subscription required'),
        _error ?? tr('No active subscription found. Please purchase a plan.'),
        buttonLabel: tr('View plans'),
        onButton: _openPlans,
      );
    }
    if (_error != null) {
      return _message(
        _needsLogin ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
        _needsLogin ? tr('Login required') : tr('Search failed'),
        _error!,
        buttonLabel: _needsLogin ? tr('Login') : tr('Try again'),
        onButton: _needsLogin ? _openLogin : () => _search(),
      );
    }
    if (_places.isEmpty) {
      return _message(Icons.search_off_rounded, tr('No places found'),
          tr('Nothing found for "{0}" within {1} km. Try a bigger radius or another keyword.', [_lastKeyword, _km]));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(tr('{0} results for "{1}"', [_places.length, _lastKeyword]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 13, weight: FontWeight.w800, color: _NS.ink)),
              ),
              Text(tr('Nearest first'), style: DT.text(size: 11.5, weight: FontWeight.w600, color: _NS.muted)),
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
        initialZoom: _gotFix ? 13 : 11,
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: const fm.InteractionOptions(
          flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _osmReady = true;
          _fitRadius();
        },
        onTap: (_, p) => _setPoint(LatLng(p.latitude, p.longitude), tr('Selected on map')),
      ),
      children: [
        if (_satellite)
          fm.TileLayer(
            urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.qnxmart.app',
            maxZoom: 19,
          )
        else
          fm.TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.qnxmart.app',
            maxZoom: 19,
          ),
        fm.CircleLayer(circles: [
          if (_live != null && _liveAccuracy > 0)
            fm.CircleMarker(
              point: ll.LatLng(_live!.latitude, _live!.longitude),
              radius: _liveAccuracy.clamp(10.0, 500.0),
              useRadiusInMeter: true,
              color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
              borderColor: const Color(0xFF1E88E5).withValues(alpha: 0.35),
              borderStrokeWidth: 1,
            ),
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
          // Picked search point (only when not following the live location)
          if (!_followLive || _live == null)
            fm.Marker(
              point: c,
              width: 40,
              height: 40,
              alignment: Alignment.topCenter,
              child: const Icon(Icons.location_on_rounded, size: 40, color: _NS.brand),
            ),
          // You (live) – on top
          if (_live != null)
            fm.Marker(
              point: ll.LatLng(_live!.latitude, _live!.longitude),
              width: 30,
              height: 30,
              child: const _LiveDot(size: 18),
            ),
        ]),
        fm.RichAttributionWidget(
          alignment: fm.AttributionAlignment.bottomLeft,
          attributions: [fm.TextSourceAttribution(tr('OpenStreetMap contributors'))],
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
      Text(tr('Find businesses near you'),
          textAlign: TextAlign.center, style: DT.text(size: 16, weight: FontWeight.w800, color: _NS.ink)),
      const SizedBox(height: 4),
      Text(tr('Set the location on the map, choose the distance and search.'),
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
              label: Text(tr(s.$1)),
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
          Text(tr(title), textAlign: TextAlign.center, style: DT.text(size: 16, weight: FontWeight.w800, color: _NS.ink)),
          const SizedBox(height: 4),
          Text(tr(body), textAlign: TextAlign.center, style: DT.text(size: 13, color: _NS.muted, height: 1.45)),
          if (buttonLabel != null && onButton != null) ...[
            const SizedBox(height: 14),
            Center(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kBrand), // buttons: only #093C71
                onPressed: onButton,
                child: Text(tr(buttonLabel)),
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
        Text(tr(p.rating.toStringAsFixed(1)), style: DT.text(size: 12, weight: FontWeight.w800, color: _NS.ink)),
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
                    Text(trData(p.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 14, weight: FontWeight.w800, color: _NS.ink)),
                    const SizedBox(height: 2),
                    _ratingRow(p),
                    if (p.category.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(trData(p.category),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 11, weight: FontWeight.w600, color: _NS.body)),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (p.openNow != null) ...[
                          Text(p.openNow! ? tr('Open') : tr('Closed'),
                              style: DT.text(
                                  size: 11,
                                  weight: FontWeight.w800,
                                  color: p.openNow! ? _NS.greenDark : const Color(0xFFC2410C))),
                          Text('  ·  ', style: DT.text(size: 11, color: _NS.hint)),
                        ],
                        Expanded(
                          child: Text(tr(p.address),
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
                    child: Text(tr(_dist(p.distanceKm)),
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

/// Pulsing blue "you are here" dot (live location).
class _LiveDot extends StatefulWidget {
  final double size;
  const _LiveDot({required this.size});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1E88E5);
    final s = widget.size;
    return SizedBox(
      width: s * 1.45,
      height: s * 1.45,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: s * (0.9 + 0.55 * _c.value),
              height: s * (0.9 + 0.55 * _c.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blue.withValues(alpha: 0.35 * (1 - _c.value)),
              ),
            ),
            Container(
              width: s * 0.8,
              height: s * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blue,
                border: Border.all(color: Colors.white, width: s * 0.14),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
