// lib/screens/chat_screen.dart
//
// One conversation (buyer ↔ seller / agent).
//
//   • messages: GET olx/chats/{id}/messages/?page=1&page_size=100, then polls every
//     5 s with page_size=15 (errors while polling are silent)
//   • send: POST …/messages/send/  (chat_limit_reached / contact-info blocked → shown)
//   • offers (buyer): POST …/offers/   · seller: accept / reject / counter
//   • read: POST …/read/ (silent)
//   • 401 / 403 → token cleared → "Login required"

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/design_tokens.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../utils/shared_preferences_helper.dart';
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

class ChatColors {
  static const bg = Color(0xFFF1F5F9);
  static const line = Color(0xFFE2E8F0);
  static const tint = Color(0xFFEAF1F9);
  static const tintLine = Color(0xFFC9DBEE);
  static const ink = Color(0xFF0F172A);
  static const body = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
  static const green = Color(0xFF047857);
  static const greenBg = Color(0xFFECFDF5);
  static const red = Color(0xFFC62828);
  static const redBg = Color(0xFFFDECEC);
  static const orangeText = Color(0xFFC2410C);
  static const orangeBg = Color(0xFFFFF7ED);
  static const orangeLine = Color(0xFFFED7AA);
}

/// "₹12,000" / "₹12,000.50"
String chatRupees(double v) {
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

/// "4:05 PM"
String chatClock(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// "Today" / "Yesterday" / "21 Oct 2026"
String chatDay(DateTime d) {
  final now = DateTime.now();
  final a = DateTime(d.year, d.month, d.day);
  final b = DateTime(now.year, now.month, now.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return tr('Today');
  if (diff == 1) return tr('Yesterday');
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${tr(m[d.month - 1])} ${d.year}';
}

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String title;
  final String subtitle;

  /// true = I am the buyer (can make offers). null = unknown (offer button shown,
  /// the backend answers "Only buyers can make offers." for sellers).
  final bool? isBuyer;

  /// Opens the "Make an offer" sheet right away (ReMart "Make offer").
  final bool openOfferOnStart;
  final double? suggestedOffer;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.title,
    this.subtitle = '',
    this.isBuyer,
    this.openOfferOnStart = false,
    this.suggestedOffer,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  int? _me;
  List<ChatMessage> _messages = [];
  bool _loading = true;
  String? _error;
  bool _needsLogin = false;
  bool _sending = false;
  Timer? _poll;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    _me = await SharedPreferencesHelper.getUserId();
    await _load();
    if (!mounted) return;
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _pollNow());
    if (widget.openOfferOnStart && !ChatService.offersSupported) {
      // No offer API yet → put the offer in the message box instead.
      final p = widget.suggestedOffer;
      if (_input.text.isEmpty) {
        _input.text = p != null && p > 0
            ? tr('Hi, I am interested. Would you accept {0}?', [chatRupees(p)])
            : tr('Hi, I am interested. What is your best price?');
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    } else if (widget.openOfferOnStart && !_needsLogin && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _offerSheet();
      });
    }
  }

  bool _mine(ChatMessage m) => _me != null && m.senderId == _me;

  // ---------------------------------------------------------------- data
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await ChatService.messages(widget.chatId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) {
        _messages = [...r.data!, ..._messages.where((m) => m.isLocal)];
      } else {
        _error = r.message;
        _needsLogin = r.needsLogin;
      }
    });
    if (r.ok) ChatService.markRead(widget.chatId);
  }

  /// Latest 15 messages – merged in by id. Silent on errors.
  Future<void> _pollNow() async {
    if (_polling || _loading || _needsLogin || !mounted) return;
    _polling = true;
    try {
      final r = await ChatService.messages(widget.chatId, pageSize: 15);
      if (!mounted) return;
      if (r.needsLogin) {
        _poll?.cancel();
        setState(() {
          _needsLogin = true;
          _error = r.message;
        });
        return;
      }
      if (!r.ok) return;
      _merge(r.data!);
    } finally {
      _polling = false;
    }
  }

  void _merge(List<ChatMessage> incoming) {
    final byId = {for (final m in _messages.where((m) => m.id > 0)) m.id: m};
    var newFromOther = false;
    for (final m in incoming) {
      if (!byId.containsKey(m.id) && !_mine(m)) newFromOther = true;
      byId[m.id] = m;
    }
    final local = _messages.where((m) => m.isLocal).toList();
    final list = byId.values.toList()..sort(ChatService.compareMessages);
    setState(() => _messages = [...list, ...local]);
    if (newFromOther) ChatService.markRead(widget.chatId);
  }

  // ---------------------------------------------------------------- send text
  Future<void> _send([ChatMessage? retry]) async {
    final text = retry?.message ?? _input.text.trim();
    if (text.isEmpty || _sending) return;
    final pending = ChatMessage.pending(text: text, me: _me);
    setState(() {
      _sending = true;
      if (retry != null) _messages.removeWhere((m) => m.key == retry.key);
      _messages = [..._messages, pending];
      if (retry == null) _input.clear();
    });
    _toBottom();

    final r = await ChatService.send(widget.chatId, text);
    if (!mounted) return;
    setState(() => _sending = false);

    if (r.ok) {
      setState(() {
        _messages.removeWhere((m) => m.key == pending.key);
        if (r.data != null && !_messages.any((m) => m.id == r.data!.id)) {
          _messages = [..._messages.where((m) => !m.isLocal), r.data!, ..._messages.where((m) => m.isLocal)];
        }
      });
      _pollNow();
      return;
    }
    if (r.needsLogin) {
      _poll?.cancel();
      setState(() {
        _messages.removeWhere((m) => m.key == pending.key);
        _needsLogin = true;
        _error = r.message;
      });
      return;
    }
    // Limit reached / contact info blocked / validation → take the bubble back,
    // put the text back in the box and explain.
    final businessError = r.code.isNotEmpty;
    if (businessError) {
      setState(() {
        _messages.removeWhere((m) => m.key == pending.key);
        if (_input.text.isEmpty) _input.text = text;
      });
      if (r.limitReached) {
        await _limitReached(r.message);
      } else {
        _snack(r.message, error: true);
      }
      return;
    }
    // Network problem → keep the bubble with "Tap to retry".
    setState(() {
      final i = _messages.indexWhere((m) => m.key == pending.key);
      if (i >= 0) _messages[i] = pending.copyWith(sending: false, failed: true);
    });
  }

  // ---------------------------------------------------------------- offers
  Future<void> _offerSheet() async {
    final res = await _amountSheet(
      title: tr('Make an offer'),
      button: tr('Send offer'),
      initial: widget.suggestedOffer,
      noteHint: tr('Message (optional)'),
    );
    if (res == null || !mounted) return;
    final (amount, note) = res;
    setState(() => _sending = true);
    final r = await ChatService.createOffer(widget.chatId, amount, message: note);
    if (!mounted) return;
    setState(() => _sending = false);
    if (r.ok) {
      _snack(tr('Offer of {0} sent.', [chatRupees(amount)]));
      await _pollNow();
      _toBottom();
    } else if (r.needsLogin) {
      setState(() {
        _needsLogin = true;
        _error = r.message;
      });
    } else if (r.limitReached) {
      await _limitReached(r.message);
    } else {
      _snack(r.message, error: true);
    }
  }

  Future<void> _respond(ChatMessage m, String action) async {
    double? amount;
    String note = '';
    if (action == 'counter') {
      final res = await _amountSheet(
        title: tr('Counter offer'),
        button: tr('Send counter offer'),
        initial: m.offerAmount,
        noteHint: tr('Message (optional)'),
      );
      if (res == null || !mounted) return;
      final (a, n) = res;
      amount = a;
      note = n.isEmpty ? tr('Can you do {0}?', [chatRupees(a)]) : n;
    } else {
      final ok = await _confirm(
        action == 'accept' ? tr('Accept offer?') : tr('Reject offer?'),
        action == 'accept'
            ? tr('Accept {0} for this item?', [chatRupees(m.offerAmount ?? 0)])
            : tr('Reject the offer of {0}?', [chatRupees(m.offerAmount ?? 0)]),
        action == 'accept' ? tr('Accept') : tr('Reject'),
      );
      if (!ok || !mounted) return;
    }
    setState(() => _sending = true);
    final r = await ChatService.respondOffer(widget.chatId, m.id, action, amount: amount, note: note);
    if (!mounted) return;
    setState(() => _sending = false);
    if (r.ok) {
      _snack(r.data ?? tr('Done.'));
      await _pollNow();
    } else if (r.needsLogin) {
      setState(() {
        _needsLogin = true;
        _error = r.message;
      });
    } else {
      _snack(r.message, error: true);
      _pollNow();
    }
  }

  // ---------------------------------------------------------------- UI helpers
  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(tr(msg), style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white)),
        backgroundColor: error ? ChatColors.red : ChatColors.ink,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  /// chat_limit_reached → offer the Communication Plans.
  Future<void> _limitReached(String message) async {
    final go = await _confirm(
      tr('Chat limit reached'),
      message.isEmpty ? tr('Your chat limit has been reached. Please purchase a plan to continue.') : message,
      tr('View plans'),
    );
    if (!go || !mounted) return;
    final bought = await openCommunicationPlans(context);
    if (bought && mounted) _snack(tr('Plan activated. You can send messages again.'));
  }

  Future<bool> _confirm(String title, String body, String yes) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr(title), style: DT.text(size: 17, weight: FontWeight.w800, color: ChatColors.ink)),
        content: Text(tr(body), style: DT.text(size: 13.5, color: ChatColors.body, height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Cancel'), style: DT.text(size: 14, weight: FontWeight.w700, color: ChatColors.muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kBrand),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr(yes)),
          ),
        ],
      ),
    );
    return r == true;
  }

  /// Amount + note bottom sheet. Returns (amount, note) or null.
  Future<(double, String)?> _amountSheet({
    required String title,
    required String button,
    double? initial,
    String noteHint = '',
  }) {
    final amountCtrl = TextEditingController(
        text: initial == null || initial <= 0
            ? ''
            : (initial == initial.roundToDouble() ? initial.toStringAsFixed(0) : initial.toStringAsFixed(2)));
    final noteCtrl = TextEditingController();
    String? err;
    return showModalBottomSheet<(double, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: ChatColors.line, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(tr(title), style: DT.text(size: 17, weight: FontWeight.w800, color: ChatColors.ink)),
                const SizedBox(height: 14),
                TextField(
                  controller: amountCtrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  style: DT.text(size: 20, weight: FontWeight.w800, color: ChatColors.ink),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: DT.text(size: 20, weight: FontWeight.w800, color: _kBrand),
                    hintText: tr('Amount'),
                    errorText: trN(err),
                    filled: true,
                    fillColor: ChatColors.tint,
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: ChatColors.tintLine)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _kBrand, width: 1.6)),
                    errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: ChatColors.red)),
                    focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: ChatColors.red, width: 1.6)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  minLines: 1,
                  style: DT.text(size: 14, color: ChatColors.ink),
                  decoration: InputDecoration(
                    hintText: tr(noteHint),
                    hintStyle: DT.text(size: 13.5, color: ChatColors.hint),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: ChatColors.line)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _kBrand, width: 1.6)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _kBrand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final v = double.tryParse(amountCtrl.text.trim());
                      if (v == null || v <= 0) {
                        setSheet(() => err = tr('Enter a valid amount'));
                        return;
                      }
                      Navigator.pop(ctx, (v, noteCtrl.text.trim()));
                    },
                    child: Text(tr(button), style: DT.text(size: 15, weight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeader)),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            ChatAvatar(name: widget.title, size: 38, light: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trData(widget.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 16, weight: FontWeight.w800, color: Colors.white)),
                  if (widget.subtitle.isNotEmpty)
                    Text(tr(widget.subtitle),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 11.5, color: Colors.white.withValues(alpha: 0.8))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tr('Refresh'),
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _body()),
          if (!_needsLogin) _composer(),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _kBrand, strokeWidth: 3));
    }
    if (_needsLogin) {
      return _state(Icons.lock_outline_rounded, tr('Login required'),
          _error ?? tr('Session expired. Please login again.'), tr('Login'), () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        if (!mounted) return;
        final t = await SharedPreferencesHelper.getAccessToken();
        if (t != null && t.isNotEmpty) {
          _me = await SharedPreferencesHelper.getUserId();
          setState(() => _needsLogin = false);
          await _load();
          _poll?.cancel();
          _poll = Timer.periodic(const Duration(seconds: 5), (_) => _pollNow());
        }
      });
    }
    if (_error != null && _messages.isEmpty) {
      return _state(Icons.cloud_off_rounded, tr('Could not load messages'), _error!, tr('Try again'), _load);
    }
    if (_messages.isEmpty) {
      return _state(Icons.forum_outlined, tr('Say hello 👋'),
          tr('Ask about price, availability or delivery. Messages appear here.'), null, null);
    }

    // Newest at the bottom (reverse list).
    final items = <Widget>[];
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      items.add(_bubble(m));
      final prev = i > 0 ? _messages[i - 1] : null;
      final d = m.createdAt;
      final pd = prev?.createdAt;
      final newDay = d != null && (pd == null || pd.year != d.year || pd.month != d.month || pd.day != d.day);
      if (newDay) items.add(_dayChip(chatDay(d)));
    }
    return ListView(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      children: items,
    );
  }

  Widget _dayChip(String text) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Text(tr(text), style: DT.text(size: 11, weight: FontWeight.w700, color: ChatColors.muted)),
        ),
      );

  Widget _bubble(ChatMessage m) {
    final mine = _mine(m) || m.isLocal;
    final maxW = MediaQuery.of(context).size.width * 0.78;
    final time = m.createdAt == null ? '' : chatClock(m.createdAt!);

    Widget status() {
      if (!mine) return const SizedBox.shrink();
      if (m.failed) return const Icon(Icons.error_outline_rounded, size: 14, color: ChatColors.red);
      if (m.sending) {
        return Icon(Icons.schedule_rounded, size: 13, color: Colors.white.withValues(alpha: 0.75));
      }
      return Icon(m.isRead ? Icons.done_all_rounded : Icons.done_rounded,
          size: 14, color: m.isRead ? const Color(0xFF93C5FD) : Colors.white.withValues(alpha: 0.75));
    }

    final content = m.isOffer
        ? _offerCard(m, mine)
        : Container(
            constraints: BoxConstraints(maxWidth: maxW),
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
            decoration: BoxDecoration(
              color: mine ? _kBrand : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
              border: mine ? null : Border.all(color: ChatColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: SelectableText(tr(m.message),
                      style: DT.text(size: 14, color: mine ? Colors.white : ChatColors.ink, height: 1.35)),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr(time),
                        style: DT.text(
                            size: 10,
                            color: mine ? Colors.white.withValues(alpha: 0.75) : ChatColors.hint)),
                    if (mine) ...[const SizedBox(width: 4), status()],
                  ],
                ),
              ],
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: m.failed ? () => _send(m) : null,
            onLongPress: m.message.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: m.message));
                    _snack(tr('Message copied'));
                  },
            child: content,
          ),
          if (m.failed)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text(tr('Not sent · Tap to retry'),
                  style: DT.text(size: 11, weight: FontWeight.w700, color: ChatColors.red)),
            ),
        ],
      ),
    );
  }

  Widget _offerCard(ChatMessage m, bool mine) {
    final st = m.offerStatus.isEmpty ? 'pending' : m.offerStatus;
    final (Color fg, Color bg, String label) = switch (st) {
      'accepted' => (ChatColors.green, ChatColors.greenBg, tr('Accepted')),
      'rejected' || 'declined' => (ChatColors.red, ChatColors.redBg, tr('Rejected')),
      'countered' => (_kBrand, ChatColors.tint, tr('Countered')),
      'expired' || 'cancelled' => (ChatColors.muted, ChatColors.line, st[0].toUpperCase() + st.substring(1)),
      _ => (ChatColors.orangeText, ChatColors.orangeBg, tr('Pending')),
    };
    final canRespond = ChatService.offersSupported && !mine && m.id > 0 && m.isPendingOffer && !_sending;
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mine ? ChatColors.tintLine : ChatColors.orangeLine, width: 1.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Icon(Icons.local_offer_rounded, size: 15, color: mine ? _kBrand : ChatColors.orangeText),
                const SizedBox(width: 5),
                Text(mine ? tr('YOUR OFFER') : tr('OFFER'),
                    style: DT.text(
                        size: 10.5, weight: FontWeight.w800, color: mine ? _kBrand : ChatColors.orangeText)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                  child: Text(tr(label), style: DT.text(size: 10.5, weight: FontWeight.w800, color: fg)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Text(tr(chatRupees(m.offerAmount ?? 0)),
                style: DT.text(size: 22, weight: FontWeight.w800, color: ChatColors.ink, letterSpacing: -0.4)),
          ),
          if (m.message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: Text(tr(m.message), style: DT.text(size: 13, color: ChatColors.body, height: 1.35)),
            ),
          if (m.offerNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Text(tr('Note: {0}', [m.offerNote]),
                  style: DT.text(size: 12, color: ChatColors.muted, height: 1.35)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Text(tr(m.createdAt == null ? '' : chatClock(m.createdAt!)),
                textAlign: TextAlign.right, style: DT.text(size: 10, color: ChatColors.hint)),
          ),
          if (canRespond) ...[
            const Divider(height: 1, color: ChatColors.line),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(child: _offerBtn(tr('Reject'), () => _respond(m, 'reject'), filled: false)),
                  const SizedBox(width: 6),
                  Expanded(child: _offerBtn(tr('Counter'), () => _respond(m, 'counter'), filled: false)),
                  const SizedBox(width: 6),
                  Expanded(child: _offerBtn(tr('Accept'), () => _respond(m, 'accept'), filled: true)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _offerBtn(String label, VoidCallback onTap, {required bool filled}) => SizedBox(
        height: 36,
        child: filled
            ? FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kBrand,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onTap,
                child: Text(tr(label), style: DT.text(size: 12.5, weight: FontWeight.w800, color: Colors.white)),
              )
            : OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kBrand,
                  side: const BorderSide(color: _kBrand),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onTap,
                child: Text(tr(label), style: DT.text(size: 12.5, weight: FontWeight.w800, color: _kBrand)),
              ),
      );

  Widget _composer() {
    final canOffer = ChatService.offersSupported && widget.isBuyer != false;
    final hasText = _input.text.trim().isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ChatColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (canOffer)
              Tooltip(
                message: tr('Make an offer'),
                child: Material(
                  color: ChatColors.tint,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _sending || _loading ? null : _offerSheet,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.currency_rupee_rounded, color: _kBrand, size: 21),
                    ),
                  ),
                ),
              ),
            if (canOffer) const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: _input,
                focusNode: _focus,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: DT.text(size: 14.5, color: ChatColors.ink),
                decoration: InputDecoration(
                  hintText: tr('Type a message…'),
                  hintStyle: DT.text(size: 14, color: ChatColors.hint),
                  isDense: true,
                  filled: true,
                  fillColor: ChatColors.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Material(
              color: hasText && !_sending ? _kBrand : _kBrand.withValues(alpha: 0.4),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: hasText && !_sending ? () => _send() : null,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _state(IconData icon, String title, String body, String? button, VoidCallback? onTap) => ListView(
        padding: const EdgeInsets.fromLTRB(32, 80, 32, 24),
        children: [
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

/// Round avatar with initials.
class ChatAvatar extends StatelessWidget {
  final String name;
  final double size;
  final bool light;
  const ChatAvatar({super.key, required this.name, this.size = 44, this.light = false});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.length == 1 ? parts.first[0] : '${parts.first[0]}${parts.last[0]}').toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: light ? Colors.white.withValues(alpha: 0.18) : ChatColors.tint,
        border: light ? Border.all(color: Colors.white.withValues(alpha: 0.35)) : null,
      ),
      child: Text(tr(initials),
          style: DT.text(size: size * 0.36, weight: FontWeight.w800, color: light ? Colors.white : _kBrand)),
    );
  }
}
