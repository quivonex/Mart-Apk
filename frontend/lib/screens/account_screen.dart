// lib/screens/account_screen.dart
//
// Account tab (inside HomeScreen).
//   • Profile from accounts/profile/ (name, email, phone) – read only on the backend.
//   • Real counts: orders, enquiries left on the subscription.
//   • My activity: orders, enquiries, properties, ReMart items, subscription.
//   • Account: profile details, saved addresses, change password, seller profile.
//   • Support: help & FAQ, contact us, terms & privacy.  Logout.
//
// [onNavigate] lets HomeScreen switch tabs (e.g. 'orders').

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants/design_tokens.dart';
import '../services/api_urls.dart';
import '../services/customer_subscription_service.dart';
import '../services/order_service.dart';
import '../utils/shared_preferences_helper.dart';
import 'customer_subscription_screen.dart';
import 'forgot_password_screen.dart';
import 'help_screens.dart';
import 'login_screen.dart';
import 'my_enquiries_screen.dart';
import 'my_properties_screen.dart';
import 'my_remart_screen.dart';
import 'saved_addresses_screen.dart';
import 'seller_profile_screen.dart';
import 'terms_conditions_screen.dart';

class _AC {
  static const brand = Color(0xFF6366F1);
  static const brandDark = Color(0xFF4338CA);
  static const violet = Color(0xFF8B5CF6);
  static const orange = Color(0xFFF97316);
  static const green = Color(0xFF10B981);
  static const bg = Color(0xFFF8FAFC);
  static const line = Color(0xFFE2E8F0);
  static const tint = Color(0xFFEEF2FF);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
}

class AccountScreen extends StatefulWidget {
  /// Optional: HomeScreen route handler (used for "My orders" → orders tab).
  final void Function(String route)? onNavigate;

  const AccountScreen({super.key, this.onNavigate});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool _loading = true;
  bool _loggedIn = false;
  String _name = '';
  String _email = '';
  String _phone = '';
  String _username = '';
  String _company = '';
  String _gst = '';
  int? _orders;
  CustomerSubscriptionInfo? _subscription;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await SharedPreferencesHelper.getAccessToken();
    final name = await SharedPreferencesHelper.getUsername();
    final email = await SharedPreferencesHelper.getUserEmail();
    final company = await SharedPreferencesHelper.getCompanyName();
    final gst = await SharedPreferencesHelper.getGstNumber();
    if (!mounted) return;
    setState(() {
      _loggedIn = token != null && token.isNotEmpty;
      _name = name ?? '';
      _email = email ?? '';
      _company = company ?? '';
      _gst = gst ?? '';
      _loading = false;
    });
    if (!_loggedIn) return;

    // Fresh profile + counts (each one fails on its own).
    _loadProfile(token!);
    OrderService.getMyOrders({}).then((r) {
      if (mounted) setState(() => _orders = r.data.length);
    }).catchError((_) {});
    CustomerSubscriptionService.mySubscriptions().then((r) {
      if (mounted && r.ok) setState(() => _subscription = r.data?.$1);
    });
  }

  Future<void> _loadProfile(String token) async {
    try {
      final res = await http
          .post(Uri.parse('${ApiUrls.baseUrl}/accounts/profile/'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: '{}')
          .timeout(const Duration(seconds: 20));
      final j = jsonDecode(res.body);
      if (res.statusCode != 200 || j is! Map || j['data'] is! Map) return;
      final d = Map<String, dynamic>.from(j['data']);
      if (!mounted) return;
      setState(() {
        final n = '${d['name'] ?? ''}'.trim();
        if (n.isNotEmpty && n != 'null') _name = n;
        final e = '${d['email'] ?? ''}'.trim();
        if (e.isNotEmpty && e != 'null') _email = e;
        final p = '${d['phone_number'] ?? ''}'.trim();
        _phone = p == 'null' ? '' : p;
        final u = '${d['username'] ?? ''}'.trim();
        _username = u == 'null' ? '' : u;
      });
    } catch (_) {}
  }

  void _push(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Future<void> _login() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    if (mounted) _load();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to use your cart, orders and enquiries.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DT.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await SharedPreferencesHelper.clearAll();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
    );
  }

  void _showProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: _AC.line, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Profile details', style: DT.text(size: 17, weight: FontWeight.w800, color: _AC.ink)),
              const SizedBox(height: 12),
              _detail(Icons.person_outline_rounded, 'Name', _name),
              _detail(Icons.alternate_email_rounded, 'Email', _email),
              _detail(Icons.phone_iphone_rounded, 'Mobile', _phone),
              if (_username.isNotEmpty) _detail(Icons.badge_outlined, 'Username', _username),
              if (_company.isNotEmpty) _detail(Icons.business_outlined, 'Company', _company),
              if (_gst.isNotEmpty) _detail(Icons.receipt_long_outlined, 'GSTIN', _gst),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _AC.tint, borderRadius: BorderRadius.circular(10)),
                child: Text('To change these details, contact QNX Mart support.',
                    style: DT.text(size: 12, color: _AC.brandDark)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, size: 18, color: _AC.hint),
        const SizedBox(width: 10),
        SizedBox(width: 80, child: Text(label, style: DT.text(size: 12.5, color: _AC.muted))),
        Expanded(
          child: Text(value.isEmpty ? '—' : value,
              style: DT.text(size: 13.5, weight: FontWeight.w700, color: _AC.ink)),
        ),
      ],
    ),
  );

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(color: _AC.bg, child: Center(child: CircularProgressIndicator(color: _AC.brand)));
    }
    return ColoredBox(
      color: _AC.bg,
      child: RefreshIndicator(
        color: _AC.brand,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _loggedIn ? _profileCard() : _guestCard(),
            if (_loggedIn) ...[
              const SizedBox(height: 14),
              _statsRow(),
              const SizedBox(height: 20),
              _section('My activity', [
                _item(Icons.receipt_long_outlined, 'My orders', 'Track, cancel or return',
                    widget.onNavigate == null ? null : () => widget.onNavigate!('orders')),
                _item(Icons.forum_outlined, 'My enquiries', 'Product enquiries and their status',
                        () => _push(const MyEnquiriesScreen())),
                _item(Icons.home_work_outlined, 'My properties', 'Listings, status and plans',
                        () => _push(const MyPropertiesScreen())),
                _item(Icons.recycling_rounded, 'My ReMart items', 'Items you sell and enquiries you sent',
                        () => _push(const MyRemartScreen())),
                _item(Icons.workspace_premium_outlined, 'My subscription',
                    _subscription == null ? 'Buy a plan to enquire on properties' : '${_subscription!.remaining} enquiries left',
                        () async {
                      await openCustomerSubscription(context);
                      if (mounted) _load();
                    }),
              ]),
              const SizedBox(height: 16),
              _section('Account', [
                _item(Icons.person_outline_rounded, 'Profile details', 'Name, email and mobile', _showProfile),
                _item(Icons.location_on_outlined, 'Saved addresses', 'Delivery addresses for checkout',
                        () => _push(const SavedAddressesScreen())),
                _item(Icons.lock_reset_rounded, 'Change password', 'Reset with an OTP on your email',
                        () => _push(const ForgotPasswordScreen())),
                _item(Icons.storefront_outlined, 'Seller profile', 'Register or update your store',
                        () => _push(const SellerProfileScreen())),
              ]),
            ],
            const SizedBox(height: 16),
            _section('Help & support', [
              _item(Icons.help_outline_rounded, 'Help & FAQ', 'Answers to common questions',
                      () => _push(const HelpInfoScreen(topic: HelpTopic.faq))),
              _item(Icons.support_agent_rounded, 'Contact us', 'Call, email or send a message',
                      () => _push(const ContactUsScreen())),
              _item(Icons.privacy_tip_outlined, 'Terms & privacy', 'How we use your data',
                      () => _push(const TermsConditionsScreen())),
            ]),
            if (_loggedIn) ...[
              const SizedBox(height: 16),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _AC.line)),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: DT.errorBg, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.logout_rounded, color: DT.error, size: 20),
                  ),
                  title: Text('Log out', style: DT.text(size: 14, weight: FontWeight.w700, color: DT.error)),
                  onTap: _logout,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _guestCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: DT.headerGradient,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.account_circle_rounded, color: Colors.white, size: 44),
        const SizedBox(height: 10),
        Text('Welcome to QNX Mart', style: DT.text(size: 18, weight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 4),
        Text('Log in to see your orders, enquiries, properties and more.',
            style: DT.text(size: 12.5, color: const Color(0xD9FFFFFF), height: 1.4)),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _AC.brandDark),
          onPressed: _login,
          child: const Text('Log in / Register'),
        ),
      ],
    ),
  );

  Widget _profileCard() {
    final initial = (_name.isNotEmpty ? _name : (_email.isNotEmpty ? _email : 'U'))[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF312E81), _AC.brandDark, _AC.violet],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x406366F1), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x66FFFFFF), width: 2),
            ),
            alignment: Alignment.center,
            child: Text(initial, style: DT.text(size: 24, weight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name.isEmpty ? 'QNX Mart user' : _name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 18, weight: FontWeight.w800, color: Colors.white)),
                if (_email.isNotEmpty)
                  Text(_email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 12.5, color: const Color(0xD9FFFFFF))),
                if (_phone.isNotEmpty)
                  Text('+91 $_phone', style: DT.text(size: 12.5, color: const Color(0xD9FFFFFF))),
                if (_company.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0x26FFFFFF), borderRadius: BorderRadius.circular(20)),
                    child: Text(_company,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 11, weight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Profile details',
            onPressed: _showProfile,
            icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    final tiles = <(IconData, String, String, Color, VoidCallback?)>[
      (Icons.receipt_long_outlined, _orders == null ? '…' : '$_orders', 'Orders', _AC.brand,
      widget.onNavigate == null ? null : () => widget.onNavigate!('orders')),
      (Icons.forum_outlined, _subscription == null ? '0' : '${_subscription!.remaining}', 'Enquiries left',
      _AC.orange, () => openCustomerSubscription(context)),
      (Icons.verified_outlined, _subscription == null ? 'None' : 'Active', 'Subscription', _AC.green,
          () => openCustomerSubscription(context)),
    ];
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: tiles[i].$5,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _AC.line),
                  ),
                  child: Column(
                    children: [
                      Icon(tiles[i].$1, size: 20, color: tiles[i].$4),
                      const SizedBox(height: 4),
                      Text(tiles[i].$2, style: DT.text(size: 17, weight: FontWeight.w900, color: _AC.ink)),
                      Text(tiles[i].$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 10.5, weight: FontWeight.w600, color: _AC.muted)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _section(String title, List<Widget> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title.toUpperCase(),
            style: DT.text(size: 11, weight: FontWeight.w800, color: _AC.muted, letterSpacing: 0.9)),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _AC.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 62, color: _AC.line),
              items[i],
            ],
          ],
        ),
      ),
    ],
  );

  Widget _item(IconData icon, String title, String subtitle, VoidCallback? onTap) => ListTile(
    onTap: onTap,
    leading: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(color: _AC.tint, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: _AC.brand, size: 20),
    ),
    title: Text(title, style: DT.text(size: 14, weight: FontWeight.w700, color: _AC.ink)),
    subtitle: Text(subtitle, style: DT.text(size: 11.5, color: _AC.muted)),
    trailing: const Icon(Icons.chevron_right_rounded, color: _AC.hint),
  );
}
