// lib/screens/ai_conversations_screen.dart
//
// QNX Mart AI Assistant – chat history.
//   Tabs: Chats (is_archived = false) / Archived (is_archived = true)
//   Search by title, pull to refresh, swipe left to delete,
//   ⋮ menu: Rename · Archive / Unarchive · Delete
//
// Opened from the history button in AiChatScreen. Pops with:
//   <conversation id>  -> open that conversation
//   ''                 -> start a new chat
//   aiDeletedCurrent   -> the conversation that was open got deleted

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../models/ai_chat_models.dart';
import '../services/ai_chat_service.dart';
import '../utils/login_gate.dart';
import 'ai_chat_screen.dart';

/// Pop value when the conversation open in the chat screen was deleted here.
const aiDeletedCurrent = '__deleted__';

class AiConversationsScreen extends StatefulWidget {
  /// Conversation currently open in the chat screen (highlighted).
  final String? currentId;

  const AiConversationsScreen({super.key, this.currentId});

  @override
  State<AiConversationsScreen> createState() => _AiConversationsScreenState();
}

class _AiConversationsScreenState extends State<AiConversationsScreen> {
  final _search = TextEditingController();
  List<AiConversation> _all = [];
  bool _loading = true;
  String? _error;
  String _q = '';
  bool _currentDeleted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _all.isEmpty;
      _error = null;
    });
    final r = await AiChatService.conversations();
    if (!mounted) return;
    if (r.needsLogin && await ensureLoggedIn(context, reason: 'see your chats')) return _load();
    setState(() {
      _loading = false;
      if (r.ok) {
        _all = r.data!;
      } else {
        _error = r.error;
      }
    });
  }

  List<AiConversation> _visible(bool archived) {
    final q = _q.trim().toLowerCase();
    return _all
        .where((c) => c.isArchived == archived)
        .where((c) => q.isEmpty || c.title.toLowerCase().contains(q))
        .toList();
  }

  void _replace(AiConversation c) => setState(() {
    _all = [for (final x in _all) x.id == c.id ? c : x];
  });

  // ---------------------------------------------------------------- actions
  Future<void> _rename(AiConversation c) async {
    final title = await showAiRenameDialog(context, c.title);
    if (title == null || title == c.title) return;
    final r = await AiChatService.rename(c.id, title);
    if (!mounted) return;
    if (r.ok) {
      _replace(c.mergedWith(r.data!));
      _snack('Conversation renamed');
    } else {
      _snack(r.error ?? 'Could not rename', error: true);
    }
  }

  Future<void> _toggleArchive(AiConversation c) async {
    final archive = !c.isArchived;
    _replace(c.mergedWith({'is_archived': archive})); // optimistic
    final r = await AiChatService.setArchived(c.id, archive);
    if (!mounted) return;
    if (r.ok) {
      _replace(c.mergedWith({'is_archived': archive, ...r.data!}));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(archive ? 'Conversation archived' : 'Moved back to chats'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            textColor: const Color(0xFFC9DBEE),
            onPressed: () => _toggleArchive(c.mergedWith({'is_archived': archive})),
          ),
        ));
    } else {
      _replace(c);
      _snack(r.error ?? 'Could not update', error: true);
    }
  }

  /// Calls the API only. Returns true when the server deleted it.
  Future<bool> _deleteOnServer(AiConversation c) async {
    final r = await AiChatService.delete(c.id);
    if (!mounted) return false;
    if (!r.ok) _snack(r.error ?? 'Could not delete', error: true);
    return r.ok;
  }

  void _removeLocal(AiConversation c) {
    setState(() {
      _all = _all.where((x) => x.id != c.id).toList();
      if (c.id == widget.currentId) _currentDeleted = true;
    });
    _snack('Conversation deleted');
  }

  /// From the ⋮ menu: confirm, delete, remove from the list.
  Future<void> _delete(AiConversation c) async {
    if (!await confirmAiDelete(context, c.title)) return;
    if (await _deleteOnServer(c)) _removeLocal(c);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AiColors.red : null,
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _close([String? result]) =>
      Navigator.pop(context, result ?? (_currentDeleted ? aiDeletedCurrent : null));

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final active = _visible(false).length;
    final archived = _visible(true).length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AiColors.bg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            // Container fills the whole bar incl. search + tabs (empty DecoratedBox = size 0)
            flexibleSpace: Container(decoration: const BoxDecoration(gradient: AiColors.header)),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _close,
            ),
            title: Text('Chat history', style: DT.text(size: 17, weight: FontWeight.w700, color: Colors.white)),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(112),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _search,
                        onChanged: (v) => setState(() => _q = v),
                        style: DT.text(size: 14, color: AiColors.ink),
                        decoration: InputDecoration(
                          hintText: 'Search chats',
                          hintStyle: DT.text(size: 14, color: AiColors.hint),
                          prefixIcon: const Icon(Icons.search_rounded, color: AiColors.muted),
                          suffixIcon: _q.isEmpty
                              ? null
                              : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: AiColors.muted),
                            onPressed: () => setState(() {
                              _search.clear();
                              _q = '';
                            }),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  TabBar(
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFFC9DBEE),
                    labelStyle: DT.text(size: 13.5, weight: FontWeight.w700),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: 'Chats ($active)'),
                      Tab(text: 'Archived ($archived)'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _close(''),
            backgroundColor: AiColors.brand,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_comment_outlined),
            label: Text('New chat', style: DT.text(size: 14, weight: FontWeight.w700, color: Colors.white)),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator(color: AiColors.brand))
              : _error != null && _all.isEmpty
              ? _message(
            icon: Icons.cloud_off_rounded,
            iconColor: AiColors.red,
            iconBg: AiColors.redBg,
            title: 'Could not load chats',
            text: _error!,
            action: FilledButton.icon(
              onPressed: _load,
              style: FilledButton.styleFrom(
                  backgroundColor: AiColors.brand, foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          )
              : TabBarView(children: [_list(false), _list(true)]),
        ),
      ),
    );
  }

  Widget _list(bool archived) {
    final items = _visible(archived);
    if (items.isEmpty) {
      return RefreshIndicator(
        color: AiColors.brand,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 420,
              child: _message(
                icon: archived ? Icons.archive_outlined : Icons.forum_outlined,
                iconColor: AiColors.brand,
                iconBg: AiColors.tint,
                title: _q.isNotEmpty
                    ? 'No chats match "$_q"'
                    : archived
                    ? 'No archived chats'
                    : 'No chats yet',
                text: archived
                    ? 'Archive a chat from its ⋮ menu to keep it here.'
                    : 'Start a new chat and ask QNX Assistant anything.',
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AiColors.brand,
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _tile(items[i]),
      ),
    );
  }

  Widget _tile(AiConversation c) {
    final current = c.id == widget.currentId;
    return Dismissible(
      key: ValueKey(c.id),
      direction: DismissDirection.endToStart,
      // swipe: confirm + API first, the row is removed in onDismissed
      confirmDismiss: (_) async {
        if (!await confirmAiDelete(context, c.title)) return false;
        return _deleteOnServer(c);
      },
      onDismissed: (_) => _removeLocal(c),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: AiColors.red, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Material(
        color: current ? AiColors.tint : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: current ? AiColors.brand : AiColors.border, width: current ? 1.4 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          onTap: () => _close(c.id),
          leading: CircleAvatar(
            radius: 21,
            backgroundColor: AiColors.tint,
            child: Icon(aiServiceIcon(c.activeService), color: AiColors.brand, size: 21),
          ),
          title: Text(c.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DT.text(size: 14.5, weight: FontWeight.w700, color: AiColors.ink)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              [
                c.activeService.label,
                '${c.messageCount} message${c.messageCount == 1 ? '' : 's'}',
                if (current) 'Open now',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DT.text(size: 12, color: current ? AiColors.brand : AiColors.muted),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(aiTimeLabel(c.activityAt), style: DT.text(size: 11, color: AiColors.hint)),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: const Icon(Icons.more_vert_rounded, color: AiColors.muted),
                onSelected: (v) => switch (v) {
                  'rename' => _rename(c),
                  'archive' => _toggleArchive(c),
                  'delete' => _delete(c),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String text,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(radius: 32, backgroundColor: iconBg, child: Icon(icon, size: 30, color: iconColor)),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: DT.text(size: 16, weight: FontWeight.w800, color: AiColors.ink)),
            const SizedBox(height: 6),
            Text(text,
                textAlign: TextAlign.center, style: DT.text(size: 13, color: AiColors.muted, height: 1.45)),
            if (action != null) ...[const SizedBox(height: 18), action],
          ],
        ),
      ),
    );
  }
}


