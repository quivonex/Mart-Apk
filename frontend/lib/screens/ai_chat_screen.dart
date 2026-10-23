// lib/screens/ai_chat_screen.dart
//
// QNX Mart AI Assistant – chat screen (Material 3, QNX #093C71 colours).
//
//   ┌ AppBar: QNX Assistant · service ─ [history] [new chat] [⋮] ┐
//   │  user bubbles (right, #093C71)                              │
//   │  assistant bubbles (left, white) + result cards + 👍 👎 ⧉   │
//   └ [ Ask about products, orders, property… ]  (send) ──────────┘
//
// Opened from the chat button on the Home screen.
//   Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen()));
// Pass [conversationId] to open an old conversation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/design_tokens.dart';
import '../models/ai_chat_models.dart';
import '../models/product_model.dart';
import '../services/ai_chat_service.dart';
import '../utils/login_gate.dart';
import 'ai_conversations_screen.dart';
import 'order_detail_screen.dart';
import 'product_detail_screen.dart';
import 'property_detail_screen.dart';

// ── QNX MART logo colours ──────────────────────────────────────────
//   #093C71 brand (all buttons) · red = errors · orange = conditions
class AiColors {
  AiColors._();
  static const brand = Color(0xFF093C71);
  static const brandDark = Color(0xFF062A50);
  static const brandLight = Color(0xFF1E5A9C);
  static const tint = Color(0xFFEAF1F9);
  static const line = Color(0xFFC9DBEE);
  static const red = Color(0xFFC62828);
  static const redBg = Color(0xFFFEF2F2);
  static const redLine = Color(0xFFFECACA);
  static const orange = Color(0xFFF7931E);
  static const orangeDark = Color(0xFFC2410C);
  static const orangeBg = Color(0xFFFFF7ED);
  static const orangeLine = Color(0xFFFED7AA);
  static const green = Color(0xFF047857);
  static const bg = Color(0xFFF4F7FB);
  static const ink = Color(0xFF0F172A);
  static const body = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);

  static const header = LinearGradient(
    colors: [brandDark, brand, brandLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// "10:22 AM" today, "Yesterday", "Mon", "14 Jan", "14 Jan 2024".
String aiTimeLabel(DateTime? d, {bool withTime = false}) {
  if (d == null) return '';
  final now = DateTime.now();
  String hm() {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return hm();
  final date = diff == 1
      ? 'Yesterday'
      : diff < 7
      ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1]
      : d.year == now.year
      ? '${d.day} ${m[d.month - 1]}'
      : '${d.day} ${m[d.month - 1]} ${d.year}';
  return withTime ? '$date, ${hm()}' : date;
}

/// 145000 -> "₹1,45,000"
String aiRupees(num v) {
  final n = v.round();
  final s = n.abs().toString();
  if (s.length <= 3) return '₹${n < 0 ? '-' : ''}$s';
  final last3 = s.substring(s.length - 3);
  final rest = s
      .substring(0, s.length - 3)
      .replaceAllMapped(RegExp(r'(\d)(?=(\d{2})+$)'), (m) => '${m[1]},');
  return '₹${n < 0 ? '-' : ''}$rest,$last3';
}

IconData aiServiceIcon(AiService s) => switch (s) {
  AiService.mart => Icons.storefront_rounded,
  AiService.remart => Icons.recycling_rounded,
  AiService.realestate => Icons.apartment_rounded,
  AiService.general => Icons.auto_awesome_rounded,
};

// ===========================================================================
// SCREEN
// ===========================================================================
class AiChatScreen extends StatefulWidget {
  final String? conversationId;

  const AiChatScreen({super.key, this.conversationId});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  AiConversation? _conversation;
  List<AiMessage> _messages = [];
  bool _loading = false; // loading an old conversation
  bool _sending = false; // waiting for the assistant
  String? _loadError;

  static const _suggestions = <(IconData, String)>[
    (Icons.two_wheeler_rounded, 'Show me used bikes in Pune'),
    (Icons.apartment_rounded, '2 BHK flats for sale in Pune'),
    (Icons.local_shipping_outlined, 'Where is my latest order?'),
    (Icons.inventory_2_outlined, 'Best selling products this week'),
  ];

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    final id = widget.conversationId;
    if (id != null && id.isNotEmpty) _load(id);
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // =================================================================
  // DATA
  // =================================================================
  Future<void> _load(String id) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final r = await AiChatService.conversation(id);
    if (!mounted) return;
    if (r.needsLogin && await _askLogin()) return _load(id);
    setState(() {
      _loading = false;
      if (r.ok) {
        _conversation = r.data!.conversation;
        _messages = r.data!.messages;
      } else {
        _loadError = r.error;
      }
    });
    _toBottom(jump: true);
  }

  Future<bool> _askLogin() async {
    if (!mounted) return false;
    return ensureLoggedIn(context, reason: 'chat with QNX Assistant');
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    final pending = AiMessage.pending(text);
    setState(() {
      _messages = [..._messages, pending];
      _sending = true;
    });
    _toBottom();
    await _deliver(pending);
  }

  /// Sends [pending] and swaps it for the server's user + assistant messages.
  Future<void> _deliver(AiMessage pending) async {
    final r = await AiChatService.sendMessage(pending.content, conversationId: _conversation?.id);
    if (!mounted) return;
    if (r.needsLogin && await _askLogin()) return _deliver(pending);
    setState(() {
      _sending = false;
      final i = _messages.indexWhere((m) => m.id == pending.id);
      if (r.ok) {
        final reply = r.data!;
        _conversation = reply.conversation;
        final u = reply.userMessage;
        final mine = AiMessage(
          id: u.id.isEmpty ? pending.id : u.id,
          role: 'user', // this is always the message the user just typed
          content: u.content.trim().isEmpty ? pending.content : u.content,
          service: u.service,
          createdAt: u.createdAt ?? pending.createdAt,
        );
        final next = [..._messages];
        if (i >= 0) next.removeAt(i);
        next.addAll([mine, reply.assistantMessage]);
        _messages = next;
      } else if (i >= 0) {
        _messages = [..._messages]..[i] = pending.copyWith(status: 'failed');
      }
    });
    if (!r.ok) _snack(r.error ?? 'Message not sent', error: true);
    _toBottom();
  }

  Future<void> _retry(AiMessage failed) async {
    if (_sending) return;
    final again = AiMessage.pending(failed.content);
    setState(() {
      _messages = [
        for (final m in _messages)
          if (m.id != failed.id) m,
        again,
      ];
      _sending = true;
    });
    _toBottom();
    await _deliver(again);
  }

  Future<void> _setFeedback(AiMessage m, int value) async {
    final next = m.feedback == value ? null : value; // tap again = clear
    _replace(m.id, (x) => x.copyWith(feedback: next, clearFeedback: next == null));
    final r = await AiChatService.feedback(m.id, next);
    if (!mounted) return;
    if (!r.ok) {
      _replace(m.id, (x) => x.copyWith(feedback: m.feedback, clearFeedback: m.feedback == null));
      _snack(r.error ?? 'Could not save feedback', error: true);
    } else if (next != null) {
      _snack(next == 1 ? 'Thanks for your feedback!' : 'Thanks – we will use this to improve.');
    }
  }

  /// Server count, or the messages on screen when the server sends 0.
  int _count(AiConversation c) =>
      c.messageCount > 0 ? c.messageCount : _messages.where((m) => !m.isLocal).length;

  void _replace(String id, AiMessage Function(AiMessage) f) => setState(() {
    _messages = [for (final m in _messages) m.id == id ? f(m) : m];
  });

  // =================================================================
  // CONVERSATION ACTIONS
  // =================================================================
  void _newChat() {
    if (_sending) return;
    setState(() {
      _conversation = null;
      _messages = [];
      _loadError = null;
    });
    _focus.requestFocus();
  }

  Future<void> _openHistory() async {
    final picked = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => AiConversationsScreen(currentId: _conversation?.id)),
    );
    if (!mounted || picked == null) return;
    if (picked.isEmpty || picked == aiDeletedCurrent) {
      _newChat(); // "New chat", or the open conversation was deleted
    } else {
      _load(picked); // also refreshes the open one (title / archive may change)
    }
  }

  Future<void> _rename() async {
    final c = _conversation;
    if (c == null) return;
    final title = await showAiRenameDialog(context, c.title);
    if (title == null || title == c.title) return;
    final r = await AiChatService.rename(c.id, title);
    if (!mounted) return;
    if (r.ok) {
      setState(() => _conversation = c.mergedWith(r.data!));
      _snack('Conversation renamed');
    } else {
      _snack(r.error ?? 'Could not rename', error: true);
    }
  }

  Future<void> _toggleArchive() async {
    final c = _conversation;
    if (c == null) return;
    final r = await AiChatService.setArchived(c.id, !c.isArchived);
    if (!mounted) return;
    if (r.ok) {
      setState(() => _conversation = c.mergedWith({'is_archived': !c.isArchived, ...r.data!}));
      _snack(c.isArchived ? 'Moved back to chats' : 'Conversation archived');
    } else {
      _snack(r.error ?? 'Could not update', error: true);
    }
  }

  Future<void> _delete() async {
    final c = _conversation;
    if (c == null) return;
    if (!await confirmAiDelete(context, c.title)) return;
    final r = await AiChatService.delete(c.id);
    if (!mounted) return;
    if (r.ok) {
      _newChat();
      _snack('Conversation deleted');
    } else {
      _snack(r.error ?? 'Could not delete', error: true);
    }
  }

  // =================================================================
  // CARDS
  // =================================================================
  Future<void> _openCard(AiCard c) async {
    Widget? page;
    if (c.isProduct && (c.slug.isNotEmpty || c.refId != null)) {
      page = ProductDetailScreen(
        product: Product.fromJson({
          'id': c.slug.isNotEmpty ? 0 : c.refId, // detail API: id, or slug when id is 0
          'slug': c.slug,
          'name': c.title,
          'thumbnail': c.image,
          'final_price': c.price,
          'price': c.price,
          'description': c.description,
        }),
      );
    } else if (c.isProperty && c.slug.isNotEmpty) {
      page = PremiumPropertyDetailScreen(slug: c.slug, previewName: c.title);
    } else if (c.isOrder) {
      final id = int.tryParse(c.orderId) ?? c.refId;
      if (id != null) page = OrderDetailScreen(orderId: id);
    }
    if (page != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page!));
      return;
    }
    if (c.url.isNotEmpty) {
      final uri = Uri.tryParse(c.url);
      if (uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    }
    if (mounted) _cardSheet(c);
  }

  void _cardSheet(AiCard c) {
    String label(String k) => k
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (c.image.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(c.image,
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              const SizedBox(height: 12),
              Text(c.title.isEmpty ? 'Details' : c.title,
                  style: DT.text(size: 17, weight: FontWeight.w800, color: AiColors.ink)),
              if (c.price != null) ...[
                const SizedBox(height: 4),
                Text(aiRupees(c.price!),
                    style: DT.text(size: 16, weight: FontWeight.w800, color: AiColors.brand)),
              ],
              if (c.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(c.description, style: DT.text(size: 13, color: AiColors.body, height: 1.45)),
              ],
              if (c.extra.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in c.extra.entries)
                      Chip(
                        label: Text('${label(e.key)}: ${e.value}',
                            style: DT.text(size: 12, weight: FontWeight.w600, color: AiColors.brand)),
                        backgroundColor: AiColors.tint,
                        side: const BorderSide(color: AiColors.line),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // =================================================================
  // HELPERS
  // =================================================================
  void _toBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      jump
          ? _scroll.jumpTo(end)
          : _scroll.animateTo(end, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    });
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white)),
        backgroundColor: error ? AiColors.red : AiColors.ink,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  // =================================================================
  // BUILD
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AiColors.bg,
      appBar: _appBar(),
      body: Column(
        children: [
          if (_conversation?.isArchived == true) _archivedBanner(),
          Expanded(child: _body()),
          _composer(),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    final c = _conversation;
    final service = c?.activeService ?? AiService.general;
    return AppBar(
      backgroundColor: Colors.transparent,
      // Container fills the whole bar (an empty DecoratedBox has size 0 -> white bar)
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: AiColors.header)),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: Color(0x26FFFFFF),
            child: Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(c == null ? 'QNX Assistant' : c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DT.text(size: 16, weight: FontWeight.w700, color: Colors.white)),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _sending ? AiColors.orange : const Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        _sending
                            ? 'Typing…'
                            : c == null
                            ? 'AI shopping assistant'
                            : '${service.label} · ${_count(c)} messages',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DT.text(size: 11.5, color: const Color(0xFFC9DBEE)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Chat history',
          onPressed: _openHistory,
          icon: const Icon(Icons.history_rounded),
        ),
        IconButton(
          tooltip: 'New chat',
          onPressed: _sending ? null : _newChat,
          icon: const Icon(Icons.add_comment_outlined),
        ),
        if (c != null)
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) => switch (v) {
              'rename' => _rename(),
              'archive' => _toggleArchive(),
              'delete' => _delete(),
              _ => null,
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'rename',
                child: ListTile(
                    leading: Icon(Icons.edit_outlined), title: Text('Rename'), contentPadding: EdgeInsets.zero),
              ),
              PopupMenuItem(
                value: 'archive',
                child: ListTile(
                  leading: Icon(c.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
                  title: Text(c.isArchived ? 'Unarchive' : 'Archive'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: AiColors.red),
                  title: Text('Delete', style: TextStyle(color: AiColors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _archivedBanner() => Material(
    color: AiColors.orangeBg,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.archive_outlined, size: 18, color: AiColors.orangeDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text('This conversation is archived.',
                style: DT.text(size: 12.5, weight: FontWeight.w600, color: AiColors.orangeDark)),
          ),
          TextButton(
            onPressed: _toggleArchive,
            style: TextButton.styleFrom(foregroundColor: AiColors.brand),
            child: const Text('Unarchive'),
          ),
        ],
      ),
    ),
  );

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AiColors.brand));
    }
    if (_loadError != null) {
      return _ErrorState(
        message: _loadError!,
        onRetry: widget.conversationId == null && _conversation == null
            ? _newChat
            : () => _load(_conversation?.id ?? widget.conversationId!),
        onNewChat: _newChat,
      );
    }
    if (_messages.isEmpty) return _welcome();

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length) return const _TypingBubble();
        final m = _messages[i];
        final prev = i > 0 ? _messages[i - 1] : null;
        final d = m.createdAt, p = prev?.createdAt;
        final showDate = d != null &&
            (p == null || p.year != d.year || p.month != d.month || p.day != d.day);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDate) _DateChip(d!),
            m.isUser
                ? _UserBubble(message: m, onRetry: () => _retry(m))
                : _AssistantBubble(
              message: m,
              onFeedback: (v) => _setFeedback(m, v),
              onCopy: () {
                Clipboard.setData(ClipboardData(text: m.content));
                _snack('Copied');
              },
              onCard: _openCard,
            ),
          ],
        );
      },
    );
  }

  Widget _welcome() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(gradient: AiColors.header, shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 38),
          ),
        ),
        const SizedBox(height: 16),
        Text('Hi! I am QNX Assistant',
            textAlign: TextAlign.center,
            style: DT.text(size: 20, weight: FontWeight.w800, color: AiColors.ink)),
        const SizedBox(height: 6),
        Text(
          'Ask me about products, your orders, properties or ReMart listings.',
          textAlign: TextAlign.center,
          style: DT.text(size: 13.5, color: AiColors.muted, height: 1.45),
        ),
        const SizedBox(height: 24),
        Text('Try asking',
            style: DT.text(size: 12, weight: FontWeight.w700, color: AiColors.muted, letterSpacing: 0.4)),
        const SizedBox(height: 10),
        for (final (icon, text) in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AiColors.border),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AiColors.tint,
                  child: Icon(icon, size: 19, color: AiColors.brand),
                ),
                title: Text(text, style: DT.text(size: 13.5, weight: FontWeight.w600, color: AiColors.ink)),
                trailing: const Icon(Icons.north_east_rounded, size: 18, color: AiColors.hint),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onTap: () => _send(text),
              ),
            ),
          ),
      ],
    );
  }

  Widget _composer() {
    final canSend = _input.text.trim().isNotEmpty && !_sending;
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: const Color(0x22000000),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: DT.text(size: 14.5, color: AiColors.ink),
                  decoration: InputDecoration(
                    hintText: 'Ask about products, orders, property…',
                    hintStyle: DT.text(size: 14, color: AiColors.hint),
                    filled: true,
                    fillColor: AiColors.bg,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AiColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AiColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: AiColors.brand, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: canSend ? () => _send() : null,
                style: IconButton.styleFrom(
                  backgroundColor: AiColors.brand,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AiColors.line,
                  disabledForegroundColor: Colors.white,
                  fixedSize: const Size(46, 46),
                ),
                icon: _sending
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// SHARED DIALOGS (also used by the history screen)
// ===========================================================================
Future<String?> showAiRenameDialog(BuildContext context, String current) {
  final ctrl = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Rename conversation'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Title',
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AiColors.brand, width: 2)),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim().isEmpty ? null : v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          style: TextButton.styleFrom(foregroundColor: AiColors.muted),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? null : ctrl.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: AiColors.brand, foregroundColor: Colors.white),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<bool> confirmAiDelete(BuildContext context, String title) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.delete_outline_rounded, color: AiColors.red),
      title: const Text('Delete conversation?'),
      content: Text('"$title" and all its messages will be removed. This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: AiColors.muted),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AiColors.brand, foregroundColor: Colors.white),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}

// ===========================================================================
// MESSAGE WIDGETS
// ===========================================================================
class _DateChip extends StatelessWidget {
  final DateTime date;
  const _DateChip(this.date);

  @override
  Widget build(BuildContext context) {
    final label = aiTimeLabel(date);
    final text = label.contains(':') ? 'Today' : label;
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: DT.text(size: 11, weight: FontWeight.w600, color: AiColors.muted)),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final AiMessage message;
  final VoidCallback onRetry;
  const _UserBubble({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final failed = message.isFailed;
    return Padding(
      padding: const EdgeInsets.only(left: 56, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: failed ? AiColors.redBg : AiColors.brand,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
              border: failed ? Border.all(color: AiColors.redLine) : null,
            ),
            child: SelectableText(
              message.content,
              style: DT.text(size: 14, color: failed ? AiColors.red : Colors.white, height: 1.4),
            ),
          ),
          const SizedBox(height: 3),
          if (failed)
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 14, color: AiColors.red),
                    const SizedBox(width: 4),
                    Text('Not sent · Tap to retry',
                        style: DT.text(size: 11.5, weight: FontWeight.w700, color: AiColors.red)),
                  ],
                ),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(aiTimeLabel(message.createdAt),
                    style: DT.text(size: 10.5, color: AiColors.hint)),
                const SizedBox(width: 4),
                Icon(message.isSending ? Icons.schedule_rounded : Icons.done_all_rounded,
                    size: 13, color: message.isSending ? AiColors.hint : AiColors.brandLight),
              ],
            ),
        ],
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final AiMessage message;
  final ValueChanged<int> onFeedback;
  final VoidCallback onCopy;
  final ValueChanged<AiCard> onCard;

  const _AssistantBubble({
    required this.message,
    required this.onFeedback,
    required this.onCopy,
    required this.onCard,
  });

  @override
  Widget build(BuildContext context) {
    final m = message;
    final failed = m.isFailed;
    return Padding(
      padding: const EdgeInsets.only(right: 24, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(gradient: AiColors.header, shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_outlined, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: failed ? AiColors.redBg : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(color: failed ? AiColors.redLine : AiColors.border),
                  ),
                  child: AiMarkdown(
                    m.content.trim().isEmpty && failed
                        ? 'Sorry, I could not answer that. Please try again.'
                        : m.content,
                    color: failed ? AiColors.red : AiColors.body,
                  ),
                ),
                if (m.cards.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 214,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: m.cards.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => _ResultCard(card: m.cards[i], onTap: () => onCard(m.cards[i])),
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(aiTimeLabel(m.createdAt), style: DT.text(size: 10.5, color: AiColors.hint)),
                    if (m.service != AiService.general) ...[
                      const SizedBox(width: 6),
                      Icon(aiServiceIcon(m.service), size: 12, color: AiColors.hint),
                      const SizedBox(width: 2),
                      Text(m.service.label, style: DT.text(size: 10.5, color: AiColors.hint)),
                    ],
                    const Spacer(),
                    if (!m.isLocal) ...[
                      _tinyIcon(
                        tooltip: 'Helpful',
                        icon: m.feedback == 1 ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                        color: m.feedback == 1 ? AiColors.brand : AiColors.hint,
                        onTap: () => onFeedback(1),
                      ),
                      _tinyIcon(
                        tooltip: 'Not helpful',
                        icon: m.feedback == -1 ? Icons.thumb_down_alt_rounded : Icons.thumb_down_alt_outlined,
                        color: m.feedback == -1 ? AiColors.red : AiColors.hint,
                        onTap: () => onFeedback(-1),
                      ),
                    ],
                    _tinyIcon(
                      tooltip: 'Copy',
                      icon: Icons.copy_rounded,
                      color: AiColors.hint,
                      onTap: onCopy,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tinyIcon({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      );
}

class _ResultCard extends StatelessWidget {
  final AiCard card;
  final VoidCallback onTap;
  const _ResultCard({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = card;
    final (IconData icon, String kind) = c.isOrder
        ? (Icons.receipt_long_outlined, 'Order')
        : c.isProperty
        ? (Icons.apartment_rounded, 'Property')
        : c.isRemart
        ? (Icons.recycling_rounded, 'ReMart')
        : (Icons.inventory_2_outlined, 'Product');

    // second line: specs for ReMart, quantity / status for orders
    final facts = <String>[
      if (c.extra['year'] != null) '${c.extra['year']}',
      if (c.extra['km_driven'] != null) '${c.extra['km_driven']} km',
      if (c.extra['fuel'] != null) '${c.extra['fuel']}',
      if (c.extra['ownership'] != null) '${c.extra['ownership']} owner',
      if (c.isOrder && c.status.isNotEmpty) c.status,
      if (c.isOrder && c.paymentStatus.isNotEmpty) c.paymentStatus,
      if (!c.isOrder && c.quantity > 0) 'Qty ${c.quantity}',
    ];
    final price = c.isOrder ? (c.totalAmount ?? c.price) : c.price;

    return SizedBox(
      width: 168,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AiColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 96,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    c.image.isEmpty
                        ? Container(color: AiColors.tint, child: Icon(icon, size: 34, color: AiColors.brand))
                        : Image.network(c.image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: AiColors.tint, child: Icon(icon, size: 34, color: AiColors.brand))),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(kind, style: DT.text(size: 9.5, weight: FontWeight.w800, color: AiColors.brand)),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title.isNotEmpty ? c.title : (c.isOrder ? 'Order ${c.orderId}' : kind),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DT.text(size: 12.5, weight: FontWeight.w700, color: AiColors.ink, height: 1.25),
                    ),
                    if (facts.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(facts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DT.text(size: 10.5, color: AiColors.muted)),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(price == null ? 'View' : aiRupees(price),
                          style: DT.text(size: 14, weight: FontWeight.w800, color: AiColors.brand)),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: AiColors.brand),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Each dot fades in turn.
  double _dot(int i) {
    final t = (_c.value * 3 - i) % 3; // 0..3
    return t < 1 ? 1.0 - 0.7 * t : 0.3;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(gradient: AiColors.header, shape: BoxShape.circle),
            child: const Icon(Icons.smart_toy_outlined, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: AiColors.border),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    Opacity(
                      opacity: _dot(i),
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(color: AiColors.brand, shape: BoxShape.circle),
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
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onNewChat;
  const _ErrorState({required this.message, required this.onRetry, required this.onNewChat});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 32,
              backgroundColor: AiColors.redBg,
              child: Icon(Icons.cloud_off_rounded, size: 30, color: AiColors.red),
            ),
            const SizedBox(height: 14),
            Text('Could not open this chat',
                style: DT.text(size: 16, weight: FontWeight.w800, color: AiColors.ink)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center, style: DT.text(size: 13, color: AiColors.muted, height: 1.45)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(backgroundColor: AiColors.brand, foregroundColor: Colors.white),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                ),
                OutlinedButton.icon(
                  onPressed: onNewChat,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AiColors.brand,
                    side: const BorderSide(color: AiColors.brand),
                  ),
                  icon: const Icon(Icons.add_comment_outlined, size: 18),
                  label: const Text('New chat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// SMALL MARKDOWN RENDERER
// (assistant replies use **bold**, `code`, # headings, "- " / "1. " lists)
// No extra package needed.
// ===========================================================================
class AiMarkdown extends StatelessWidget {
  final String text;
  final Color color;
  const AiMarkdown(this.text, {super.key, this.color = AiColors.body});

  @override
  Widget build(BuildContext context) {
    final base = DT.text(size: 14, color: color, height: 1.45);
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final out = <Widget>[];
    var blank = false;

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        if (out.isNotEmpty && !blank) out.add(const SizedBox(height: 6));
        blank = true;
        continue;
      }
      blank = false;
      final t = line.trimLeft();

      final h = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(t);
      if (h != null) {
        final level = h.group(1)!.length;
        out.add(Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 2),
          child: Text.rich(
            TextSpan(children: _inline(h.group(2)!, base)),
            style: base.copyWith(
              fontSize: level <= 2 ? 16 : 14.5,
              fontWeight: FontWeight.w800,
              color: AiColors.ink,
            ),
          ),
        ));
        continue;
      }

      final bullet = RegExp(r'^[-*•]\s+(.*)$').firstMatch(t);
      final number = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(t);
      if (bullet != null || number != null) {
        final indent = (line.length - t.length).clamp(0, 8) * 4.0;
        out.add(Padding(
          padding: EdgeInsets.only(left: indent, top: 2, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: number != null ? 22 : 14,
                child: Text(number != null ? '${number.group(1)}.' : '•',
                    style: base.copyWith(fontWeight: FontWeight.w700, color: AiColors.brand)),
              ),
              Expanded(
                child: Text.rich(TextSpan(children: _inline(bullet?.group(1) ?? number!.group(2)!, base))),
              ),
            ],
          ),
        ));
        continue;
      }

      out.add(Text.rich(TextSpan(children: _inline(t, base))));
    }

    return SelectionArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: out),
    );
  }

  /// **bold**, __bold__, `code`, [label](url) -> label
  static List<InlineSpan> _inline(String s, TextStyle base) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|__(.+?)__|`([^`]+)`|\[([^\]]+)\]\(([^)]+)\)');
    var last = 0;
    for (final m in re.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start), style: base));
      if (m.group(1) != null || m.group(2) != null) {
        spans.add(TextSpan(
          text: m.group(1) ?? m.group(2),
          style: base.copyWith(fontWeight: FontWeight.w800, color: AiColors.ink),
        ));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
          text: m.group(3),
          style: base.copyWith(
            fontFamily: 'monospace',
            fontSize: 13,
            backgroundColor: AiColors.tint,
            color: AiColors.brandDark,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: m.group(4),
          style: base.copyWith(
            color: AiColors.brand,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
          ),
        ));
      }
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last), style: base));
    return spans;
  }
}
