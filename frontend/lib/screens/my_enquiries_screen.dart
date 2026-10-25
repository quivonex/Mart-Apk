// lib/screens/my_enquiries_screen.dart
//
// QNX Mart › My Enquiries – product enquiries the user sent.
//   POST enquiry/my_product-enquiries/   (login)
// Each card shows a small tracker: Sent → Forwarded to supplier → Dispatched → Delivered.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/design_tokens.dart';
import '../services/api_urls.dart';
import '../utils/shared_preferences_helper.dart';
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

class _ME {
  static const brand = Color(0xFF093C71);
  static const brandDark = Color(0xFF062A50);
  static const green = Color(0xFF10B981);
  static const bg = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
  static const tint = Color(0xFFEAF1F9);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
}

String _img(Object? raw) {
  final v = '${raw ?? ''}'.trim();
  if (v.isEmpty || v == 'null') return '';
  return v.startsWith('http') ? v : 'https://api.qnxmartb2b.com/${v.startsWith('/') ? v.substring(1) : v}';
}

String _date(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = d.toLocal();
  return '${l.day} ${tr(m[l.month - 1])} ${l.year}';
}

String _inr(Object? raw) {
  final v = double.tryParse('${raw ?? ''}') ?? 0;
  final n = v.round().toString();
  if (n.length <= 3) return '₹$n';
  final last3 = n.substring(n.length - 3);
  final rest = n.substring(0, n.length - 3).replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},');
  return '₹$rest,$last3';
}

class MyEnquiriesScreen extends StatefulWidget {
  const MyEnquiriesScreen({super.key});

  @override
  State<MyEnquiriesScreen> createState() => _MyEnquiriesScreenState();
}

class _MyEnquiriesScreenState extends State<MyEnquiriesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

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
    try {
      final token = await SharedPreferencesHelper.getAccessToken();
      if (token == null || token.isEmpty) throw Exception(tr('Please log in to see your enquiries.'));
      final res = await http
          .post(
        Uri.parse('${ApiUrls.baseUrl}/enquiry/my_product-enquiries/'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: '{}',
      )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode == 401) throw Exception(tr('Your session has expired. Please log in again.'));
      final j = jsonDecode(res.body);
      if (res.statusCode != 200 || j is! Map) throw Exception(tr('Could not load enquiries ({0}).', [res.statusCode]));
      final list = [for (final e in (j['data'] as List? ?? []).whereType<Map>()) Map<String, dynamic>.from(e)];
      if (!mounted) return;
      setState(() {
        _loading = false;
        _items = list;
      });
    } catch (e) {
      if (!mounted) return;
      final s = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _loading = false;
        _error = s.contains('SocketException') || s.contains('ClientException') ? tr('Could not reach the server.') : s;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ME.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeader)),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('My Enquiries'), style: DT.text(size: 17, weight: FontWeight.w700, color: Colors.white)),
            Text(_loading ? tr('Loading…') : tr('{0} product enquiries', [_items.length]),
                style: DT.text(size: 11.5, color: const Color(0xCCFFFFFF))),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _ME.brand))
          : _error != null
          ? _state(Icons.cloud_off_rounded, tr('Could not load enquiries'), _error!, retry: true)
          : _items.isEmpty
          ? _state(Icons.forum_outlined, tr('No enquiries yet'),
          tr('Enquiries you send from a product page will show here with their progress.'))
          : RefreshIndicator(
        color: _ME.brand,
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _card(_items[i]),
        ),
      ),
    );
  }

  Widget _state(IconData icon, String title, String body, {bool retry = false}) => ListView(
    padding: const EdgeInsets.fromLTRB(32, 70, 32, 32),
    children: [
      Center(
        child: Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(color: _ME.tint, shape: BoxShape.circle),
          child: Icon(icon, size: 38, color: _ME.brand),
        ),
      ),
      const SizedBox(height: 16),
      Text(tr(title), textAlign: TextAlign.center, style: DT.text(size: 16, weight: FontWeight.w800, color: _ME.ink)),
      const SizedBox(height: 6),
      Text(tr(body), textAlign: TextAlign.center, style: DT.text(size: 13, color: _ME.muted, height: 1.45)),
      if (retry) ...[
        const SizedBox(height: 18),
        Center(
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kBrand), // buttons: only #093C71
            onPressed: _load,
            child: Text(tr('Try again')),
          ),
        ),
      ],
    ],
  );

  Widget _card(Map<String, dynamic> e) {
    final image = _img(e['product_image']);
    final steps = <(String, bool)>[
      (tr('Sent'), true),
      (tr('Supplier'), e['is_sent_to_company'] == true),
      (tr('Dispatched'), e['is_dispatched'] == true),
      (tr('Delivered'), e['is_delivered'] == true || e['is_complete'] == true),
    ];
    final reached = steps.lastIndexWhere((s) => s.$2);
    final variant = [e['selected_variant'], e['selected_color'], e['selected_size']]
        .map((v) => '${v ?? ''}'.trim())
        .where((v) => v.isNotEmpty && v != 'null')
        .join(' · ');
    final total = e['total_amount'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ME.line),
        boxShadow: const [BoxShadow(color: Color(0x0A0F172A), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: image.isEmpty
                      ? Container(color: _ME.tint, child: const Icon(Icons.inventory_2_outlined, color: _ME.hint))
                      : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: _ME.tint)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e['product_name'] ?? 'Product'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 14, weight: FontWeight.w800, color: _ME.ink, height: 1.3)),
                    if ('${e['company_name'] ?? ''}'.isNotEmpty)
                      Text('${e['company_name']}', style: DT.text(size: 12, color: _ME.muted)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        tr('Qty {0}', [e['quantity'] ?? 1]),
                        if (variant.isNotEmpty) variant,
                        if (total != null && '$total' != 'null') _inr(total),
                      ].join(' · '),
                      style: DT.text(size: 12, weight: FontWeight.w700, color: _ME.brandDark),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ('${e['message'] ?? ''}'.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _ME.bg, borderRadius: BorderRadius.circular(10)),
              child: Text('${e['message']}',
                  maxLines: 3, overflow: TextOverflow.ellipsis, style: DT.text(size: 12.5, color: DT.onyx700, height: 1.4)),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < steps.length; i++) ...[
                Column(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: i <= reached ? _ME.green : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: i <= reached ? _ME.green : _ME.line, width: 2),
                      ),
                      child: i <= reached ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
                    ),
                    const SizedBox(height: 4),
                    Text(tr(steps[i].$1),
                        style: DT.text(
                            size: 10,
                            weight: FontWeight.w700,
                            color: i <= reached ? const Color(0xFF047857) : _ME.hint)),
                  ],
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      color: i < reached ? _ME.green : _ME.line,
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(tr('Sent on {0}', [_date('${e['created_at'] ?? ''}')]), style: DT.text(size: 11, color: _ME.hint)),
        ],
      ),
    );
  }
}
