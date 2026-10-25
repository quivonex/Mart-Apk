// lib/screens/chat_list_screen.dart
//
// My Chats – GET olx/chats/  (newest activity first, unread badge).
// Filters: All · Buying (I am the buyer) · Selling (I am the seller / agent).
// Usage strip: POST olx/bazaar-communication-usage/chat/ → "7 / 20 chats used".
// "Plans" (header) → CommunicationPlansScreen.
// Tap a chat → ChatScreen. Opened from the drawer ("My Chats").

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/chat_models.dart';
import '../models/communication_plan_models.dart';
import '../services/communication_plan_service..dart';
import '../services/chat_service.dart';
import '../utils/shared_preferences_helper.dart';
import 'chat_screen.dart';
import 'communication_plans_screen.dart';
import 'login_screen.dart';
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

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatThread> _chats = [];
  bool _loading = true;
  String? _error;
  bool _needsLogin = false;
  int? _me;
  String _query = '';

  /// all | buying | selling
  String _filter = 'all';
  CommUsage? _usage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _needsLogin = false;
    });
    final token = await SharedPreferencesHelper.getAccessToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _needsLogin = true;
        _error = tr('Please login to see your chats.');
      });
      return;
    }
    _me = await SharedPreferencesHelper.getUserId();
    _boughtIds = await ChatService.buyingChatIds();
    final usageF = CommunicationPlanService.chatUsage(); // silent, may be null
    final r = await ChatService.chats();
    final usage = await usageF;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _usage = usage;
      _chats = r.data ?? const [];
      _needsLogin = r.needsLogin;
      _error = r.ok ? null : r.message;
    });
  }

  Future<void> _open(ChatThread c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: c.id,
          title: tr(c.displayName),
          subtitle: tr(c.itemTitle),
          isBuyer: _buying(c),
        ),
      ),
    );
    if (mounted) _load(); // unread counts / last message
  }

  /// true = I am the buyer, false = I am the seller / agent, null = unknown.
  /// Buyer = the backend says I started it, or I started it from a detail
  /// screen on this device. Everything else = Seller (someone messaged me).
  bool? _buying(ChatThread c) {
    if (_me != null && c.buyerId != null) return c.buyerId == _me;
    return _boughtIds.contains(c.id);
  }

  /// Chats started from a detail screen on this device (ChatService.rememberBuying).
  Set<int> _boughtIds = {};

  bool _inFilter(ChatThread c, String f) => switch (f) {
        'buying' => _buying(c) == true,
        'selling' => _buying(c) == false,
        _ => true,
      };

  Future<void> _openPlans() async {
    final bought = await openCommunicationPlans(context);
    if (mounted && bought) _load();
    if (mounted && !bought) {
      final u = await CommunicationPlanService.chatUsage();
      if (mounted) setState(() => _usage = u);
    }
  }

  List<ChatThread> get _visible {
    final q = _query.trim().toLowerCase();
    final byRole = _chats.where((c) => _inFilter(c, _filter));
    if (q.isEmpty) return byRole.toList();
    return byRole
        .where((c) =>
            c.displayName.toLowerCase().contains(q) ||
            c.itemTitle.toLowerCase().contains(q) ||
            (c.lastMessage?.message.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _chats.fold<int>(0, (s, c) => s + c.unreadCount);
    return Scaffold(
      backgroundColor: ChatColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeader)),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(unread > 0 ? tr('My Chats ({0})', [unread]) : tr('My Chats'),
            style: DT.text(size: 17, weight: FontWeight.w700, color: Colors.white)),
        actions: [
          IconButton(
            tooltip: tr('Chat plans'),
            onPressed: _openPlans,
            icon: const Icon(Icons.workspace_premium_rounded),
          ),
          IconButton(
            tooltip: tr('Refresh'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(color: _kBrand, onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading && _chats.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 160),
        Center(child: CircularProgressIndicator(color: _kBrand, strokeWidth: 3)),
      ]);
    }
    if (_needsLogin) {
      return _state(Icons.lock_outline_rounded, tr('Login required'), _error ?? tr('Please login again.'), tr('Login'),
          () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        if (mounted) _load();
      });
    }
    if (_error != null && _chats.isEmpty) {
      return _state(Icons.cloud_off_rounded, tr('Could not load chats'), _error!, tr('Try again'), _load);
    }
    if (_chats.isEmpty) {
      return _state(Icons.forum_outlined, tr('No chats yet'),
          tr('Open a product, property or ReMart item and tap "Chat" to talk to the seller.'), null, null,
          header: _usage == null ? null : _usageStrip(_usage!));
    }
    final list = _visible;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (_usage != null) _usageStrip(_usage!),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: DT.text(size: 14, color: ChatColors.ink),
            decoration: InputDecoration(
              hintText: tr('Search chats'),
              hintStyle: DT.text(size: 13.5, color: ChatColors.hint),
              prefixIcon: const Icon(Icons.search_rounded, color: ChatColors.muted),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: ChatColors.line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _kBrand, width: 1.6)),
            ),
          ),
        ),
        _filters(),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
                _query.trim().isNotEmpty
                    ? tr('No chats match "{0}".', [_query])
                    : _filter == 'buying'
                        ? tr('No chats where you are the buyer yet.')
                        : tr('No chats where you are the seller yet.'),
                textAlign: TextAlign.center,
                style: DT.text(size: 13, color: ChatColors.muted)),
          ),
        for (final c in list) _tile(c),
      ],
    );
  }

  // ---------------------------------------------------------------- filters
  Widget _filters() {
    Widget chip(String key, String label, IconData icon) {
      final count = _chats.where((c) => _inFilter(c, key)).length;
      final unread = _chats.where((c) => _inFilter(c, key)).fold<int>(0, (s, c) => s + c.unreadCount);
      final sel = _filter == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: sel ? _kBrand : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _filter = key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? _kBrand : ChatColors.tintLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: sel ? Colors.white : _kBrand),
                  const SizedBox(width: 5),
                  Text('$label ($count)',
                      style: DT.text(size: 12.5, weight: FontWeight.w800, color: sel ? Colors.white : _kBrand)),
                  if (unread > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: sel ? Colors.white : const Color(0xFFF7931E),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        children: [
          chip('all', tr('All'), Icons.forum_rounded),
          chip('buying', tr('Buyer'), Icons.shopping_bag_outlined),
          chip('selling', tr('Seller'), Icons.storefront_outlined),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- usage strip
  Widget _usageStrip(CommUsage u) {
    final exhausted = u.exhausted;
    final text = u.unlimited
        ? tr('Unlimited chats · {0} used', [u.used])
        : exhausted
            ? tr('Chat limit reached ({0} / {1})', [u.used, u.limit ?? 0])
            : '${u.used} / ${u.limit ?? 0} chats used · ${u.remaining ?? 0} left';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: exhausted ? ChatColors.orangeBg : ChatColors.tint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: exhausted ? ChatColors.orangeLine : ChatColors.tintLine),
      ),
      child: Row(
        children: [
          Icon(exhausted ? Icons.lock_clock_rounded : Icons.chat_rounded,
              size: 18, color: exhausted ? ChatColors.orangeText : _kBrand),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(text),
                    style: DT.text(
                        size: 12.5,
                        weight: FontWeight.w800,
                        color: exhausted ? ChatColors.orangeText : ChatColors.ink)),
                if (!u.unlimited) ...[
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: u.fraction,
                      minHeight: 5,
                      backgroundColor: Colors.white,
                      color: exhausted ? const Color(0xFFF7931E) : _kBrand,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _openPlans,
            style: TextButton.styleFrom(foregroundColor: _kBrand),
            child: Text(exhausted ? tr('Buy plan') : tr('Plans'),
                style: DT.text(size: 12.5, weight: FontWeight.w800, color: _kBrand)),
          ),
        ],
      ),
    );
  }

  Widget _tile(ChatThread c) {
    final last = c.lastMessage;
    final mineLast = last != null && _me != null && last.senderId == _me;
    String preview;
    if (last == null) {
      preview = tr('No messages yet');
    } else if (last.isOffer) {
      preview = '${mineLast ? 'You offered' : 'Offer'}: ${chatRupees(last.offerAmount ?? 0)}';
    } else {
      preview = '${mineLast ? 'You: ' : ''}${last.message}';
    }
    final unread = c.unreadCount > 0;
    final role = _buying(c);
    final when = c.activityAt;
    String time = '';
    if (when != null) {
      final day = chatDay(when);
      time = day == 'Today' ? chatClock(when) : day;
    }
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _open(c),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ChatColors.line))),
          child: Row(
            children: [
              ChatAvatar(name: c.displayName, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(tr(c.displayName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DT.text(
                                  size: 15,
                                  weight: unread ? FontWeight.w800 : FontWeight.w700,
                                  color: ChatColors.ink)),
                        ),
                        Text(tr(time),
                            style: DT.text(
                                size: 11,
                                weight: unread ? FontWeight.w800 : FontWeight.w500,
                                color: unread ? _kBrand : ChatColors.hint)),
                      ],
                    ),
                    if (c.itemTitle.isNotEmpty || c.itemLabel.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (c.itemLabel.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: ChatColors.tint,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(tr(c.itemLabel),
                                  style: DT.text(size: 10, weight: FontWeight.w800, color: _kBrand)),
                            ),
                          Expanded(
                            child: Text(tr(c.itemTitle),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DT.text(size: 12, weight: FontWeight.w600, color: ChatColors.body)),
                          ),
                          if (role != null)
                            Text(role ? tr('Buying') : tr('Selling'),
                                style: DT.text(
                                    size: 10.5,
                                    weight: FontWeight.w800,
                                    color: role ? _kBrand : ChatColors.green)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (last != null && last.isOffer) ...[
                          const Icon(Icons.local_offer_rounded, size: 13, color: ChatColors.orangeText),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(tr(preview),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DT.text(
                                  size: 12.5,
                                  weight: unread ? FontWeight.w700 : FontWeight.w400,
                                  color: unread ? ChatColors.ink : ChatColors.muted)),
                        ),
                        if (unread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            constraints: const BoxConstraints(minWidth: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: _kBrand, borderRadius: BorderRadius.circular(20)),
                            child: Text(tr(c.unreadCount > 99 ? '99+' : '${c.unreadCount}'),
                                textAlign: TextAlign.center,
                                style: DT.text(size: 10.5, weight: FontWeight.w800, color: Colors.white)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _state(IconData icon, String title, String body, String? button, VoidCallback? onTap,
          {Widget? header}) =>
      ListView(
        padding: EdgeInsets.fromLTRB(header == null ? 32 : 0, header == null ? 90 : 0, header == null ? 32 : 0, 24),
        children: [
          if (header != null) ...[header, const SizedBox(height: 70)],
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: ChatColors.tint, shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: _kBrand),
            ),
          ),
          const SizedBox(height: 12),
          Text(tr(title),
              textAlign: TextAlign.center, style: DT.text(size: 16, weight: FontWeight.w800, color: ChatColors.ink)),
          const SizedBox(height: 4),
          Text(tr(body),
              textAlign: TextAlign.center, style: DT.text(size: 13, color: ChatColors.muted, height: 1.45)),
          if (button != null && onTap != null) ...[
            const SizedBox(height: 14),
            Center(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _kBrand),
                onPressed: onTap,
                child: Text(tr(button)),
              ),
            ),
          ],
        ],
      );
}
