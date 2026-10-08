// lib/screens/remart_screens.dart
//
// QNX ReMart (used & resale) – drawer "QNX ReMart › All Products".
//
//   POST olx/listings/?search=&city=&category_id=   (public, active listings)
//   POST olx/categories/                             (public)
//   POST olx/enquiries/create/  {listing_id, message, phone_number}   (login)
//
// "Add Product" on ReMart needs the plan + payment flow, so it opens the website.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../constants/design_tokens.dart';
import '../services/api_urls.dart';
import '../utils/shared_preferences_helper.dart';
import 'login_screen.dart';

const _green = Color(0xFF1A68FA);
const _greenBg = Color(0xFFEFF6FF);
const _website = 'https://qnxmartb2b.com';

/// Drawer "QNX ReMart › Add Product": posting needs a plan and payment, done on the website.
Future<void> openRemartPosting(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.recycling_rounded, size: 40, color: _green),
            const SizedBox(height: 10),
            Text('Sell on QNX ReMart',
                textAlign: TextAlign.center, style: DT.text(size: 18, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Posting a used or resale item includes choosing a listing plan and payment. '
                  'For now this is done on our website; your listing then appears here in the app.',
              textAlign: TextAlign.center,
              style: DT.text(size: 13.5, color: DT.onyx600, height: 1.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                launchUrl(Uri.parse(_website), mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('Post on qnxmartb2b.com',
                  style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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

  RemartListing({
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
Future<void> startRemartEnquiry(BuildContext context, RemartListing listing) async {
  // The backend refuses enquiries on your own listing – say so up front.
  if (await listing.isMine()) {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.storefront_rounded, color: Color(0xFF1A68FA), size: 36),
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
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _EnquirySheet(listing: listing, token: token),
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
      backgroundColor: const Color(0xFFF5F7FB),
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
            onPressed: () => openRemartPosting(context),
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
        side: BorderSide(color: sel ? _green : const Color(0xFFDBEAFE)),
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
class RemartListingDetailScreen extends StatefulWidget {
  final RemartListing listing;
  const RemartListingDetailScreen({super.key, required this.listing});

  @override
  State<RemartListingDetailScreen> createState() => _RemartListingDetailScreenState();
}

class _RemartListingDetailScreenState extends State<RemartListingDetailScreen> {
  int _img = 0;
  bool _mine = false;

  @override
  void initState() {
    super.initState();
    widget.listing.isMine().then((v) {
      if (mounted && v) setState(() => _mine = true);
    });
  }

  Future<void> _enquire() => startRemartEnquiry(context, widget.listing);

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: DT.onyx900,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text('Listing', style: DT.text(size: 17, weight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: l.images.isEmpty
                ? Container(
                color: const Color(0xFFF3F4F6),
                child: const Icon(Icons.image_outlined, size: 60, color: DT.slate300))
                : Stack(
              children: [
                PageView.builder(
                  itemCount: l.images.length,
                  onPageChanged: (i) => setState(() => _img = i),
                  itemBuilder: (_, i) => Image.network(l.images[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined, color: DT.slate300)),
                ),
                if (l.images.length > 1)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                      child: Text('${_img + 1}/${l.images.length}',
                          style: DT.text(size: 12, weight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_rupees(l.price), style: DT.text(size: 24, weight: FontWeight.w900)),
                    if (l.negotiable) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('Negotiable',
                            style: DT.text(size: 12.5, weight: FontWeight.w700, color: _green)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(l.title, style: DT.text(size: 18, weight: FontWeight.w700, height: 1.3)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _tag(Icons.verified_outlined, l.conditionLabel),
                    if (l.sellerType.isNotEmpty)
                      _tag(l.sellerType == 'business' ? Icons.storefront_outlined : Icons.person_outline,
                          l.sellerType == 'business' ? 'Business seller' : 'Individual seller'),
                    if (l.categoryName.isNotEmpty)
                      _tag(Icons.category_outlined,
                          [l.categoryName, l.subcategoryName].where((s) => s.isNotEmpty).join(' › ')),
                    if (l.location.isNotEmpty) _tag(Icons.location_on_outlined, l.location),
                  ],
                ),
                if (l.attributes.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Details', style: DT.text(size: 15, weight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  for (final e in l.attributes.entries)
                    if (e.value != null && '${e.value}'.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 130,
                              child: Text(e.key.replaceAll('_', ' '),
                                  style: DT.text(size: 13, color: DT.slate500)),
                            ),
                            Expanded(
                              child: Text('${e.value}',
                                  style: DT.text(size: 13, weight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                ],
                if (l.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Description', style: DT.text(size: 15, weight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(l.description, style: DT.text(size: 13.5, color: DT.onyx700, height: 1.55)),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _mine
              ? Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.storefront_rounded, color: Color(0xFF1A68FA), size: 20),
              const SizedBox(width: 8),
              Text('This is your listing',
                  style: DT.text(size: 14.5, weight: FontWeight.w800, color: const Color(0xFF1A68FA))),
            ]),
          )
              : ElevatedButton.icon(
            onPressed: _enquire,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text('Send enquiry to seller',
                style: DT.text(size: 15, weight: FontWeight.w700, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: DT.onyx600),
        const SizedBox(width: 5),
        Text(text, style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx700)),
      ],
    ),
  );
}

class _EnquirySheet extends StatefulWidget {
  final RemartListing listing;
  final String token;
  const _EnquirySheet({required this.listing, required this.token});

  @override
  State<_EnquirySheet> createState() => _EnquirySheetState();
}

class _EnquirySheetState extends State<_EnquirySheet> {
  final _formKey = GlobalKey<FormState>();
  late final _message = TextEditingController(
      text: 'Hi, is "${widget.listing.title}" still available?');
  final _phone = TextEditingController();
  bool _sending = false;

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
      backgroundColor: ok ? _green : DT.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Send enquiry', style: DT.text(size: 18, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(widget.listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 13, color: DT.slate500)),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Your mobile number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null; // optional on the backend
                    return RegExp(r'^[6-9]\d{9}$').hasMatch(t) ? null : 'Enter a valid 10-digit number';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _message,
                  maxLines: 4,
                  minLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message *',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a message' : null,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _sending ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _sending
                      ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : Text('Send', style: DT.text(size: 15, weight: FontWeight.w700, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}