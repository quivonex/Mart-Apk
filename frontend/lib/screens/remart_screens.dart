// lib/screens/remart_screens.dart
//
// QNX ReMart (used & resale) – drawer "QNX ReMart › All Products".
//
//   POST olx/listings/?search=&city=&category_id=   (public, active listings)
//   POST olx/categories/                             (public)
//   POST olx/enquiries/create/  {listing_id, message, phone_number}   (login)
//
// "Add Product" opens RemartAddProductScreen (photos, details, plan + Razorpay payment).

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../constants/design_tokens.dart';
import '../models/chat_models.dart';
import '../services/api_urls.dart';
import '../services/chat_service.dart';
import '../utils/chat_launcher.dart';
import '../utils/shared_preferences_helper.dart';
import 'login_screen.dart';
import 'remart_add_product_screen.dart';
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

const _green = Color(0xFF093C71);
const _greenBg = Color(0xFFEAF1F9);

/// Drawer "QNX ReMart › Add Product": opens the in-app sell form (login required).
/// Returns true when an item was posted.
Future<bool> openRemartPosting(BuildContext context) async {
  final token = await SharedPreferencesHelper.getAccessToken();
  if (!context.mounted) return false;
  if (token == null || token.isEmpty) {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.recycling_rounded, color: _green, size: 36),
        title: const Text('Login required'),
        content: const Text('Please log in to sell an item on QNX ReMart.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Login')),
        ],
      ),
    );
    if (go == true && context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
    return false;
  }
  final posted = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const RemartAddProductScreen()),
  );
  return posted == true;
}

// =====================================================================
// MODELS
// =====================================================================
class RemartListing {
  final int id;
  /// Seller (owner) of the listing – from `user_id` in olx/listings/.
  final int? userId;
  final String title;
  final String description;
  final double price;
  final bool negotiable;
  final String condition;
  final String sellerType;
  final String city;
  final String area;
  final String categoryName;
  final String subcategoryName;
  final List<String> images;
  final Map<String, dynamic> attributes;
  final String createdAt;

  /// Only in "my listings": active | pending | draft | expired | sold …
  final String status;
  final String expiresAt;
  final int viewsCount;

  RemartListing({
    this.status = '',
    this.expiresAt = '',
    this.viewsCount = 0,
    required this.id,
    this.userId,
    required this.title,
    required this.description,
    required this.price,
    required this.negotiable,
    required this.condition,
    required this.sellerType,
    required this.city,
    required this.area,
    required this.categoryName,
    required this.subcategoryName,
    required this.images,
    required this.attributes,
    required this.createdAt,
  });

  factory RemartListing.fromJson(Map<String, dynamic> j) {
    final imgs = (j['images'] as List? ?? [])
        .whereType<Map>()
        .toList()
      ..sort((a, b) {
        final p = (b['is_primary'] == true ? 1 : 0) - (a['is_primary'] == true ? 1 : 0);
        if (p != 0) return p;
        return ((a['sort_order'] ?? 0) as num).compareTo((b['sort_order'] ?? 0) as num);
      });
    return RemartListing(
      id: j['id'] is int ? j['id'] : int.tryParse('${j['id']}') ?? 0,
      userId: j['user_id'] is int ? j['user_id'] : int.tryParse('${j['user_id'] ?? ''}'),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      price: double.tryParse('${j['price']}') ?? 0,
      negotiable: j['is_negotiable'] == true,
      condition: (j['condition'] ?? '').toString(),
      sellerType: (j['seller_type'] ?? '').toString(),
      city: (j['city'] ?? '').toString(),
      area: (j['area'] ?? '').toString(),
      categoryName: (j['category_name'] ?? '').toString(),
      subcategoryName: (j['subcategory_name'] ?? '').toString(),
      images: [
        for (final m in imgs)
          if ((m['image_url'] ?? '').toString().startsWith('http')) m['image_url'].toString()
      ],
      attributes: j['attributes'] is Map ? Map<String, dynamic>.from(j['attributes']) : const {},
      createdAt: (j['created_at'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      expiresAt: (j['expires_at'] ?? '').toString(),
      viewsCount: j['views_count'] is int ? j['views_count'] : int.tryParse('${j['views_count'] ?? ''}') ?? 0,
    );
  }

  String get conditionLabel => switch (condition) {
    'new' => 'New',
    'like_new' => 'Like new',
    'good' => 'Good',
    'fair' => 'Fair',
    'used' => 'Used',
    _ => condition,
  };

  /// True when the logged-in user posted this listing.
  Future<bool> isMine() async {
    final me = await SharedPreferencesHelper.getUserId();
    return me != null && userId != null && me == userId;
  }

  String get location => [area, city].where((s) => s.trim().isNotEmpty).join(', ');
}

String _rupees(double v) {
  final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  final parts = s.split('.');
  var n = parts[0];
  if (n.length > 3) {
    final last3 = n.substring(n.length - 3);
    var rest = n.substring(0, n.length - 3);
    final g = <String>[];
    while (rest.length > 2) {
      g.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) g.insert(0, rest);
    n = '${g.join(',')},$last3';
  }
  return '₹$n${parts.length > 1 ? '.${parts[1]}' : ''}';
}

// =====================================================================
// SHARED API (used by this screen and the home "QNXRemart" pill)
// =====================================================================
class RemartApi {
  static String _err(Object e) {
    final s = e.toString().replaceFirst('Exception: ', '');
    if (s.contains('SocketException') || s.contains('ClientException')) {
      return 'Could not reach the server.';
    }
    if (s.contains('TimeoutException')) return 'The server took too long to respond.';
    return s;
  }

  static Future<(int, dynamic)> _authPost(String path) async {
    final token = await SharedPreferencesHelper.getAccessToken();
    if (token == null || token.isEmpty) throw Exception('Please log in to continue.');
    final res = await http
        .post(Uri.parse('${ApiUrls.baseUrl}$path'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: '{}')
        .timeout(const Duration(seconds: 25));
    if (res.statusCode == 401) throw Exception('Your session has expired. Please log in again.');
    try {
      return (res.statusCode, jsonDecode(res.body));
    } catch (_) {
      throw Exception('Server error (${res.statusCode}). Please try again later.');
    }
  }

  /// Items the logged-in user posted (any status).  POST olx/my-listings/
  static Future<(List<RemartListing>, String?)> myListings() async {
    try {
      final (code, j) = await _authPost('/olx/my-listings/');
      if (code != 200 || j is! Map || j['success'] == false) {
        throw Exception(j is Map ? (j['message'] ?? 'Could not load your items') : 'Could not load your items');
      }
      final items = (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => RemartListing.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return (items, null);
    } catch (e) {
      return (<RemartListing>[], _err(e));
    }
  }

  /// Enquiries the logged-in user sent to sellers.  POST olx/enquiries/
  static Future<(List<Map<String, dynamic>>, String?)> myEnquiries() async {
    try {
      final (code, j) = await _authPost('/olx/enquiries/');
      if (code != 200 || j is! Map || j['success'] == false) {
        throw Exception(j is Map ? (j['message'] ?? 'Could not load enquiries') : 'Could not load enquiries');
      }
      return ([for (final e in (j['data'] as List? ?? []).whereType<Map>()) Map<String, dynamic>.from(e)], null);
    } catch (e) {
      return (<Map<String, dynamic>>[], _err(e));
    }
  }

  /// Active listings. Filters are read from the query string by the backend.
  static Future<(List<RemartListing>, String?)> listings({
    String? search,
    String? city,
    int? categoryId,
  }) async {
    try {
      final q = <String, String>{
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (categoryId != null) 'category_id': '$categoryId',
      };
      final uri = Uri.parse('${ApiUrls.baseUrl}/olx/listings/')
          .replace(queryParameters: q.isEmpty ? null : q);
      final res = await http
          .post(uri, headers: const {'Content-Type': 'application/json'}, body: '{}')
          .timeout(const Duration(seconds: 25));
      final j = jsonDecode(res.body);
      if (res.statusCode != 200 || j is! Map || j['success'] != true) {
        throw Exception(j is Map ? (j['message'] ?? 'Could not load listings') : 'Could not load listings');
      }
      final items = (j['data'] as List? ?? [])
          .whereType<Map>()
          .map((e) => RemartListing.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return (items, null);
    } catch (e) {
      return (<RemartListing>[], _err(e));
    }
  }

  /// (id, name) of active ReMart categories.
  static Future<List<(int, String)>> categories() async {
    try {
      final res = await http
          .post(Uri.parse('${ApiUrls.baseUrl}/olx/categories/'),
          headers: const {'Content-Type': 'application/json'}, body: '{}')
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(res.body);
      final list = (j is Map ? j['data'] as List? : null) ?? [];
      return [
        for (final c in list.whereType<Map>())
          if (c['id'] != null) ((c['id'] as num).toInt(), (c['name'] ?? '').toString())
      ];
    } catch (_) {
      return const [];
    }
  }
}

/// "Send enquiry to seller" – checks login, then shows the enquiry sheet.
Future<void> startRemartEnquiry(BuildContext context, RemartListing listing, {String? message}) async {
  // The backend refuses enquiries on your own listing – say so up front.
  if (await listing.isMine()) {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.storefront_rounded, color: Color(0xFF093C71), size: 36),
        title: const Text('This is your listing'),
        content: const Text(
            'Buyers can send you enquiries on this item. You can\'t send an enquiry on your own listing.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    return;
  }
  final token = await SharedPreferencesHelper.getAccessToken();
  if (!context.mounted) return;
  if (token == null || token.isEmpty) {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login required'),
        content: const Text('Please log in to send an enquiry to the seller.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Login')),
        ],
      ),
    );
    if (go == true && context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
    return;
  }
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EnquirySheet(listing: listing, token: token, initialMessage: message),
  );
}

// =====================================================================
// LIST
// =====================================================================
class RemartListingsScreen extends StatefulWidget {
  const RemartListingsScreen({super.key});

  @override
  State<RemartListingsScreen> createState() => _RemartListingsScreenState();
}

class _RemartListingsScreenState extends State<RemartListingsScreen> {
  final _search = TextEditingController();
  final _city = TextEditingController();
  List<RemartListing> _items = [];
  List<(int, String)> _categories = [];
  int? _categoryId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await RemartApi.categories();
    if (mounted) setState(() => _categories = cats);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final (items, err) = await RemartApi.listings(
      search: _search.text,
      city: _city.text,
      categoryId: _categoryId,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _items = items;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: DT.onyx900,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('QNX ReMart', style: DT.text(size: 18, weight: FontWeight.w800)),
            Text('Used & resale', style: DT.text(size: 12, color: DT.slate500)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              if (await openRemartPosting(context)) _load();
            },
            icon: const Icon(Icons.add_rounded, color: _green),
            label: Text('Sell', style: DT.text(size: 13.5, weight: FontWeight.w800, color: _green)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _field(_search, 'Search items', Icons.search_rounded),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _field(_city, 'City', Icons.location_on_outlined),
                    ),
                  ],
                ),
                if (_categories.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _chip(null, 'All'),
                        for (final (id, name) in _categories) _chip(id, name),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon) => TextField(
    controller: c,
    textInputAction: TextInputAction.search,
    onSubmitted: (_) => _load(),
    style: DT.text(size: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: DT.text(size: 14, color: DT.slate400),
      prefixIcon: Icon(icon, size: 20, color: DT.slate400),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    ),
  );

  Widget _chip(int? id, String label) {
    final sel = _categoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        showCheckmark: false,
        selectedColor: _green,
        backgroundColor: _greenBg,
        side: BorderSide(color: sel ? _green : const Color(0xFFC9DBEE)),
        labelStyle: DT.text(size: 12.5, weight: FontWeight.w700, color: sel ? Colors.white : _green),
        onSelected: (_) {
          setState(() => _categoryId = id);
          _load();
        },
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: _green));
    if (_error != null) {
      return _message(Icons.cloud_off_rounded, 'Could not load listings', _error!, retry: true);
    }
    if (_items.isEmpty) {
      return _message(Icons.search_off_rounded, 'No listings found',
          'Try another search, city or category.');
    }
    return RefreshIndicator(
      color: _green,
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        itemCount: _items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 268,
        ),
        itemBuilder: (_, i) => _card(_items[i]),
      ),
    );
  }

  Widget _message(IconData icon, String title, String body, {bool retry = false}) => ListView(
    padding: const EdgeInsets.all(32),
    children: [
      const SizedBox(height: 40),
      Icon(icon, size: 44, color: DT.slate300),
      const SizedBox(height: 10),
      Text(title, textAlign: TextAlign.center, style: DT.text(size: 16, weight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(body, textAlign: TextAlign.center, style: DT.text(size: 13, color: DT.slate500)),
      if (retry) ...[
        const SizedBox(height: 14),
        Center(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: _kBrand, side: const BorderSide(color: _kBrand)),
            onPressed: _load,
            child: Text('Try again', style: DT.text(size: 13, weight: FontWeight.w700, color: _green)),
          ),
        ),
      ],
    ],
  );

  Widget _card(RemartListing l) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => RemartListingDetailScreen(listing: l))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  l.images.isEmpty
                      ? Container(
                      color: const Color(0xFFF3F4F6),
                      child: const Icon(Icons.image_outlined, size: 40, color: DT.slate300))
                      : Image.network(l.images.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Icon(Icons.broken_image_outlined, color: DT.slate300))),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                      child: Text(l.conditionLabel,
                          style: DT.text(size: 10.5, weight: FontWeight.w800, color: _green)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_rupees(l.price), style: DT.text(size: 17, weight: FontWeight.w900)),
                  if (l.negotiable)
                    Text('Negotiable', style: DT.text(size: 11, weight: FontWeight.w600, color: _green)),
                  const SizedBox(height: 4),
                  Text(l.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 13, weight: FontWeight.w600, height: 1.3)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 13, color: DT.slate400),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(l.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DT.text(size: 11.5, color: DT.slate500)),
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
}

// =====================================================================
// DETAIL + ENQUIRY
// =====================================================================
class _Rm {
  static const brand = Color(0xFF093C71);
  static const brandDark = Color(0xFF062A50);
  static const violet = Color(0xFF1E5A9C);
  static const orange = Color(0xFFF7931E);
  static const green = Color(0xFF10B981);
  static const greenBg = Color(0xFFECFDF5);
  static const bg = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
  static const tint = Color(0xFFEAF1F9);
  static const tintLine = Color(0xFFC9DBEE);
  static const ink = Color(0xFF0F172A);
  static const body = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
  static const amberBg = Color(0xFFFFF7ED);
  static const amberLine = Color(0xFFFED7AA);
  static const amberInk = Color(0xFFC2410C);
}

/// "2 days ago" style text from an ISO date string.
String _rmAgo(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  final diff = DateTime.now().difference(d.toLocal());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} hr ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 30) return '${diff.inDays} days ago';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = d.toLocal();
  return '${l.day} ${m[l.month - 1]} ${l.year}';
}

/// "fuel_type" -> "Fuel Type"
String _rmLabel(String key) => key
    .replaceAll(RegExp(r'[_\-]+'), ' ')
    .trim()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _rmValue(dynamic v) {
  if (v is bool) return v ? 'Yes' : 'No';
  if (v is List) return v.map((e) => '$e').join(', ');
  final s = '$v'.trim();
  if (s == 'true') return 'Yes';
  if (s == 'false') return 'No';
  return s;
}

class RemartListingDetailScreen extends StatefulWidget {
  final RemartListing listing;
  const RemartListingDetailScreen({super.key, required this.listing});

  @override
  State<RemartListingDetailScreen> createState() => _RemartListingDetailScreenState();
}

class _RemartListingDetailScreenState extends State<RemartListingDetailScreen> {
  static const double _galleryHeight = 340;

  final _scroll = ScrollController();
  final _pager = PageController();
  int _img = 0;
  bool _mine = false;
  bool _collapsed = false;
  bool _descOpen = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final c = _scroll.hasClients && _scroll.offset > _galleryHeight - kToolbarHeight - 30;
      if (c != _collapsed) setState(() => _collapsed = c);
    });
    widget.listing.isMine().then((v) {
      if (mounted && v) setState(() => _mine = true);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _pager.dispose();
    super.dispose();
  }

  RemartListing get l => widget.listing;

  List<MapEntry<String, dynamic>> get _specs => [
    for (final e in l.attributes.entries)
      if (e.value != null && _rmValue(e.value).isNotEmpty) e,
  ];

  /// "Chat with seller" → olx/chats/create/ {other_user_id: user_id, listing_id}
  /// [offer] = open the "Make an offer" sheet inside the chat.
  Future<void> _chat({bool offer = false}) async {
    // user_id may be missing in the list API → read it from olx/listings/detail/.
    final owner = l.userId ?? await ChatService.remartOwner(l.id);
    if (!mounted) return;
    final suggested = (l.price * 0.9 / 100).round() * 100.0;
    await ChatLauncher.start(
      context,
      kind: ChatItemKind.listing,
      itemId: l.id,
      otherUserId: owner,
      title: l.title,
      otherName: 'Seller',
      openOffer: offer,
      price: offer && suggested > 0 ? suggested : null,
    );
  }

  Future<void> _makeOffer() => _chat(offer: true);

  void _share() {
    Clipboard.setData(ClipboardData(
      text: '${l.title}\n${_rupees(l.price)}${l.negotiable ? ' (negotiable)' : ''}'
          '${l.location.isEmpty ? '' : '\n${l.location}'}\nQNX ReMart · Ad #${l.id}',
    ));
    _toast('Item details copied');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white)),
        backgroundColor: _Rm.ink,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  void _openViewer(int index) {
    if (l.images.isEmpty) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => _RmGalleryViewer(urls: l.images, initialIndex: index),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _goTo(int i) {
    if (!_pager.hasClients) return;
    _pager.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final specs = _specs;
    return Scaffold(
      backgroundColor: _Rm.bg,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          _sliverGallery(),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -22),
              child: Container(
                decoration: const BoxDecoration(
                  color: _Rm.bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _headline(),
                    const SizedBox(height: 14),
                    _priceCard(),
                    const SizedBox(height: 14),
                    _quickFacts(),
                    if (l.images.length > 1) ...[
                      const SizedBox(height: 14),
                      _thumbs(),
                    ],
                    if (specs.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _title('Specifications', Icons.tune_rounded),
                      const SizedBox(height: 10),
                      _specsCard(specs),
                    ],
                    if (l.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _title('Description', Icons.notes_rounded),
                      const SizedBox(height: 10),
                      _descriptionCard(),
                    ],
                    if (l.location.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      _title('Location', Icons.place_outlined),
                      const SizedBox(height: 10),
                      _locationCard(),
                    ],
                    const SizedBox(height: 22),
                    _safetyCard(),
                    const SizedBox(height: 14),
                    _adIdRow(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  // ---------------------------------------------------------------- gallery
  Widget _sliverGallery() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: _galleryHeight,
      backgroundColor: _collapsed ? _Rm.brand : Colors.black,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: Stack(
        fit: StackFit.expand,
        children: [
          FlexibleSpaceBar(collapseMode: CollapseMode.parallax, background: _gallery()),
          // gradient header fades in once the gallery is scrolled away
          IgnorePointer(
            ignoring: !_collapsed,
            child: AnimatedOpacity(
              opacity: _collapsed ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: const DecoratedBox(decoration: BoxDecoration(gradient: _kHeader)),
            ),
          ),
        ],
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _glassBtn(Icons.arrow_back_rounded, () => Navigator.maybePop(context)),
      ),
      title: AnimatedOpacity(
        opacity: _collapsed ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: Text(l.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DT.text(size: 16, weight: FontWeight.w700, color: Colors.white)),
      ),
      actions: [
        _glassBtn(_saved ? Icons.favorite_rounded : Icons.favorite_border_rounded, () {
          setState(() => _saved = !_saved);
          _toast(_saved ? 'Saved to your list' : 'Removed from saved');
        }, color: _saved ? const Color(0xFFC62828) : null),
        const SizedBox(width: 8),
        _glassBtn(Icons.ios_share_rounded, _share),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap, {Color? color}) => Center(
    child: Material(
      color: _collapsed ? const Color(0x26FFFFFF) : const Color(0x66000000),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: color ?? Colors.white)),
      ),
    ),
  );

  Widget _gallery() {
    if (l.images.isEmpty) {
      return Container(
        decoration: const BoxDecoration(gradient: _kHeader),
        child: const Center(child: Icon(Icons.image_outlined, size: 72, color: Color(0x66FFFFFF))),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pager,
          itemCount: l.images.length,
          onPageChanged: (i) => setState(() => _img = i),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _openViewer(i),
            child: Image.network(
              l.images[i],
              fit: BoxFit.cover,
              loadingBuilder: (c, child, p) =>
              p == null ? child : Container(color: const Color(0xFF062A50)),
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF062A50),
                child: const Center(child: Icon(Icons.broken_image_outlined, size: 48, color: Color(0x66FFFFFF))),
              ),
            ),
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x80000000), Color(0x00000000), Color(0x00000000), Color(0x8C000000)],
                stops: [0, 0.3, 0.65, 1],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 34,
          child: _pill(Icons.verified_outlined, l.conditionLabel, Colors.white, _Rm.brandDark),
        ),
        Positioned(
          right: 16,
          bottom: 34,
          child: GestureDetector(
            onTap: () => _openViewer(_img),
            child: _pill(Icons.photo_library_outlined, '${_img + 1} / ${l.images.length}',
                const Color(0x99000000), Colors.white),
          ),
        ),
        if (l.images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: IgnorePointer(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < l.images.length && i < 8; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: i == _img ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _img ? Colors.white : const Color(0x80FFFFFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _pill(IconData icon, String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: fg),
        const SizedBox(width: 4),
        Text(text, style: DT.text(size: 11.5, weight: FontWeight.w700, color: fg)),
      ],
    ),
  );

  // ---------------------------------------------------------------- headline
  Widget _headline() {
    final crumbs = [l.categoryName, l.subcategoryName].where((s) => s.trim().isNotEmpty).toList();
    final ago = _rmAgo(l.createdAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (crumbs.isNotEmpty)
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _Rm.tint,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _Rm.tintLine),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.category_outlined, size: 12, color: _Rm.brand),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(crumbs.join(' › '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DT.text(size: 11, weight: FontWeight.w700, color: _Rm.brandDark)),
                      ),
                    ],
                  ),
                ),
              ),
            if (crumbs.isNotEmpty && ago.isNotEmpty) const SizedBox(width: 8),
            if (ago.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded, size: 13, color: _Rm.hint),
                  const SizedBox(width: 3),
                  Text(ago, style: DT.text(size: 11.5, weight: FontWeight.w600, color: _Rm.muted)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(l.title,
            style: DT.text(size: 20, weight: FontWeight.w800, color: _Rm.ink, height: 1.3, letterSpacing: -0.3)),
      ],
    );
  }

  Widget _priceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF062A50), _Rm.brandDark, _Rm.violet],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x40093C71), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PRICE',
                    style: DT.text(
                        size: 10, weight: FontWeight.w700, color: const Color(0xB3FFFFFF), letterSpacing: 1.2)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(_rupees(l.price),
                      style: DT.text(size: 28, weight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: l.negotiable ? _Rm.greenBg : const Color(0x26FFFFFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(l.negotiable ? Icons.handshake_outlined : Icons.lock_outline_rounded,
                    size: 14, color: l.negotiable ? _Rm.green : Colors.white),
                const SizedBox(width: 4),
                Text(l.negotiable ? 'Negotiable' : 'Fixed price',
                    style: DT.text(
                        size: 11.5, weight: FontWeight.w800, color: l.negotiable ? const Color(0xFF047857) : Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickFacts() {
    final business = l.sellerType == 'business';
    final facts = <(IconData, String, String, Color)>[
      (Icons.verified_outlined, 'Condition', l.conditionLabel.isEmpty ? '—' : l.conditionLabel, _Rm.brand),
      (
      business ? Icons.storefront_outlined : Icons.person_outline_rounded,
      'Seller',
      l.sellerType.isEmpty ? '—' : (business ? 'Business' : 'Individual'),
      _Rm.violet,
      ),
      (Icons.location_on_outlined, 'City', l.city.isEmpty ? '—' : l.city, _Rm.orange),
    ];
    return Row(
      children: [
        for (var i = 0; i < facts.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _Rm.line),
              ),
              child: Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: facts[i].$4.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(facts[i].$1, size: 18, color: facts[i].$4),
                  ),
                  const SizedBox(height: 6),
                  Text(facts[i].$2, style: DT.text(size: 10.5, weight: FontWeight.w600, color: _Rm.muted)),
                  const SizedBox(height: 1),
                  Text(facts[i].$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: DT.text(size: 12.5, weight: FontWeight.w800, color: _Rm.ink)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _thumbs() => SizedBox(
    height: 62,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: l.images.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (_, i) {
        final sel = i == _img;
        return GestureDetector(
          onTap: () => _goTo(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 62,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? _Rm.brand : Colors.transparent, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Opacity(
                opacity: sel ? 1 : 0.7,
                child: Image.network(l.images[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: _Rm.line)),
              ),
            ),
          ),
        );
      },
    ),
  );

  // ---------------------------------------------------------------- sections
  Widget _title(String text, IconData icon) => Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: _Rm.tint, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: _Rm.brand),
      ),
      const SizedBox(width: 8),
      Text(text, style: DT.text(size: 16, weight: FontWeight.w800, color: _Rm.ink, letterSpacing: -0.2)),
    ],
  );

  BoxDecoration get _card => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _Rm.line),
    boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 2))],
  );

  Widget _specsCard(List<MapEntry<String, dynamic>> specs) {
    return Container(
      decoration: _card,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < specs.length; i++)
            Container(
              color: i.isEven ? Colors.white : _Rm.bg,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(_rmLabel(specs[i].key),
                        style: DT.text(size: 12.5, weight: FontWeight.w500, color: _Rm.muted)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 6,
                    child: Text(_rmValue(specs[i].value),
                        textAlign: TextAlign.right,
                        style: DT.text(size: 13, weight: FontWeight.w700, color: _Rm.ink)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _descriptionCard() {
    final text = l.description.trim();
    final long = text.length > 220;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: Text(
              text,
              maxLines: long && !_descOpen ? 5 : null,
              overflow: long && !_descOpen ? TextOverflow.ellipsis : TextOverflow.visible,
              style: DT.text(size: 13.5, color: _Rm.body, height: 1.6),
            ),
          ),
          if (long)
            GestureDetector(
              onTap: () => setState(() => _descOpen = !_descOpen),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_descOpen ? 'Show less' : 'Read more',
                        style: DT.text(size: 12.5, weight: FontWeight.w800, color: _Rm.brand)),
                    Icon(_descOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18, color: _Rm.brand),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _locationCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: _card,
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFEDD5), Color(0xFFFED7AA)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.location_on_rounded, color: _Rm.orange, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.area.trim().isNotEmpty ? l.area.trim() : l.city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DT.text(size: 14, weight: FontWeight.w800, color: _Rm.ink)),
              const SizedBox(height: 2),
              Text(l.area.trim().isNotEmpty && l.city.isNotEmpty ? l.city : 'Item location',
                  style: DT.text(size: 12, color: _Rm.muted)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Copy location',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: l.location));
            _toast('Location copied');
          },
          icon: const Icon(Icons.copy_rounded, size: 18, color: _Rm.hint),
        ),
      ],
    ),
  );

  Widget _safetyCard() {
    const tips = [
      'Meet the seller in a safe, public place',
      'Check the item properly before you pay',
      'Never pay in advance or share OTPs',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Rm.amberBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Rm.amberLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: Color(0xFFF7931E)),
              const SizedBox(width: 6),
              Text('Stay safe while buying',
                  style: DT.text(size: 13.5, weight: FontWeight.w800, color: _Rm.amberInk)),
            ],
          ),
          const SizedBox(height: 8),
          for (final t in tips)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFFF7931E)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(t, style: DT.text(size: 12.5, color: _Rm.amberInk, height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _adIdRow() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text('Ad ID #${l.id}', style: DT.text(size: 11.5, weight: FontWeight.w600, color: _Rm.hint)),
      const SizedBox(width: 4),
      InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          Clipboard.setData(ClipboardData(text: '${l.id}'));
          _toast('Ad ID copied');
        },
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.copy_rounded, size: 13, color: _Rm.hint),
        ),
      ),
    ],
  );

  // ---------------------------------------------------------------- bottom bar
  Widget _bottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Color(0x1A0F172A), blurRadius: 20, offset: Offset(0, -6))],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: _mine
            ? Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _Rm.tint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _Rm.tintLine),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.storefront_rounded, color: _Rm.brand, size: 20),
            const SizedBox(width: 8),
            Text('This is your listing',
                style: DT.text(size: 14.5, weight: FontWeight.w800, color: _Rm.brandDark)),
          ]),
        )
            : Row(
          children: [
            if (l.negotiable && l.price > 0) ...[
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _makeOffer,
                    icon: const Icon(Icons.local_offer_outlined, size: 18),
                    label: Text('Make offer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 13.5, weight: FontWeight.w800, color: _Rm.brandDark)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _Rm.brandDark,
                      side: const BorderSide(color: _Rm.tintLine, width: 1.4),
                      backgroundColor: _Rm.tint,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              flex: 3,
              child: SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _kBrand, // buttons: only #093C71
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Color(0x40093C71), blurRadius: 12, offset: Offset(0, 5)),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _chat(),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.white),
                    label: Text('Chat with seller',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 14.5, weight: FontWeight.w800, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// FULL-SCREEN PHOTO VIEWER (pinch to zoom)
// =====================================================================
class _RmGalleryViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _RmGalleryViewer({required this.urls, required this.initialIndex});

  @override
  State<_RmGalleryViewer> createState() => _RmGalleryViewerState();
}

class _RmGalleryViewerState extends State<_RmGalleryViewer> {
  late final PageController _pc = PageController(initialPage: widget.initialIndex);
  late int _i = widget.initialIndex;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.network(widget.urls[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                    const Icon(Icons.broken_image_outlined, size: 56, color: Colors.white38)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(20)),
                    child: Text('${_i + 1} / ${widget.urls.length}',
                        style: DT.text(size: 12.5, weight: FontWeight.w700, color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// ENQUIRY SHEET
// =====================================================================
class _EnquirySheet extends StatefulWidget {
  final RemartListing listing;
  final String token;
  final String? initialMessage;
  const _EnquirySheet({required this.listing, required this.token, this.initialMessage});

  @override
  State<_EnquirySheet> createState() => _EnquirySheetState();
}

class _EnquirySheetState extends State<_EnquirySheet> {
  final _formKey = GlobalKey<FormState>();
  late final _message = TextEditingController(
      text: widget.initialMessage ?? 'Hi, is "${widget.listing.title}" still available?');
  final _phone = TextEditingController();
  bool _sending = false;

  static const _quick = [
    'Is it still available?',
    'What is your final price?',
    'Can I see it today?',
    'Is the bill / warranty available?',
  ];

  @override
  void dispose() {
    _message.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    String msg;
    bool ok = false;
    try {
      final res = await http
          .post(
        Uri.parse('${ApiUrls.baseUrl}/olx/enquiries/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'listing_id': widget.listing.id,
          'message': _message.text.trim(),
          'phone_number': _phone.text.trim(),
        }),
      )
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(res.body);
      ok = res.statusCode >= 200 && res.statusCode < 300 && (j is! Map || j['success'] != false);
      msg = (j is Map ? j['message'] : null)?.toString() ??
          (ok ? 'Enquiry sent to the seller.' : 'Could not send enquiry.');
      if (res.statusCode == 401) msg = 'Session expired. Please log in again.';
    } catch (_) {
      msg = 'Could not reach the server.';
    }
    if (!mounted) return;
    setState(() => _sending = false);
    final messenger = ScaffoldMessenger.of(context);
    if (ok) Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? _Rm.green : _kRed,
      behavior: SnackBarBehavior.floating,
    ));
  }

  InputDecoration _dec(String hint, IconData? icon) {
    OutlineInputBorder b(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      hintStyle: DT.text(size: 13, color: _Rm.hint),
      prefixIcon: icon == null ? null : Icon(icon, size: 18, color: _Rm.hint),
      isDense: true,
      filled: true,
      fillColor: _Rm.bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      enabledBorder: b(_Rm.line),
      focusedBorder: b(_Rm.brand, 1.6),
      errorBorder: b(_kRed),
      focusedErrorBorder: b(_kRed, 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // header with item preview
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
                    decoration: const BoxDecoration(gradient: _kHeader),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: const Color(0x66FFFFFF), borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: l.images.isEmpty
                                    ? Container(
                                    color: const Color(0x26FFFFFF),
                                    child: const Icon(Icons.image_outlined, color: Colors.white))
                                    : Image.network(l.images.first,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(color: const Color(0x26FFFFFF))),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Message the seller',
                                      style: DT.text(size: 16, weight: FontWeight.w800, color: Colors.white)),
                                  Text('${_rupees(l.price)} · ${l.title}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: DT.text(size: 12, color: const Color(0xD9FFFFFF))),
                                ],
                              ),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Quick messages',
                            style: DT.text(size: 12, weight: FontWeight.w700, color: _Rm.body)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final q in _quick)
                              ActionChip(
                                label: Text(q),
                                labelStyle: DT.text(size: 12, weight: FontWeight.w700, color: _Rm.brandDark),
                                backgroundColor: _Rm.tint,
                                side: const BorderSide(color: _Rm.tintLine),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                onPressed: () => setState(() => _message.text = 'Hi, $q'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Your message *',
                            style: DT.text(size: 12, weight: FontWeight.w700, color: _Rm.body)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _message,
                          maxLines: 4,
                          minLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          style: DT.text(size: 13.5, weight: FontWeight.w600, color: _Rm.ink),
                          decoration: _dec('Write to the seller…', null),
                          validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a message' : null,
                        ),
                        const SizedBox(height: 12),
                        Text('Mobile number (optional)',
                            style: DT.text(size: 12, weight: FontWeight.w700, color: _Rm.body)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: DT.text(size: 13.5, weight: FontWeight.w600, color: _Rm.ink),
                          decoration: _dec('So the seller can call you', Icons.phone_iphone_rounded),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return null; // optional on the backend
                            return RegExp(r'^[6-9]\d{9}$').hasMatch(t) ? null : 'Enter a valid 10-digit number';
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _kBrand, // buttons: only #093C71
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: _sending ? null : _send,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: _sending
                                  ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                              label: Text(_sending ? 'Sending…' : 'Send message',
                                  style: DT.text(size: 14.5, weight: FontWeight.w800, color: Colors.white)),
                            ),
                          ),
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
}
