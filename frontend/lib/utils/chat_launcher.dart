// lib/utils/chat_launcher.dart
//
// "Chat with seller / agent" from a detail screen:
//   1. checks (item id + owner id present, logged in, not your own item)
//   2. POST olx/chats/create/  → chat id (existing chat is reused by the backend)
//   3. opens ChatScreen
//
//   ChatLauncher.start(context,
//       kind: ChatItemKind.product, itemId: p.id, otherUserId: p.companyUserId,
//       title: p.name, otherName: p.companyName);

import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import '../screens/chat_screen.dart';
import '../screens/login_screen.dart';
import '../services/chat_service.dart';
import 'shared_preferences_helper.dart';

class ChatLauncher {
  ChatLauncher._();

  static bool _busy = false;

  static Future<void> start(
    BuildContext context, {
    required ChatItemKind kind,
    required int? itemId,
    required int? otherUserId,
    String title = '',
    String otherName = '',
    bool openOffer = false,
    double? price,
  }) async {
    if (_busy) return;
    final party = kind.partyLabel;

    // 1. item + owner must be known
    if (itemId == null || itemId <= 0 || otherUserId == null || otherUserId <= 0) {
      _snack(context, kind == ChatItemKind.property
          ? 'Agent information is unavailable.'
          : 'Seller information is unavailable.');
      return;
    }

    // 2. login
    final token = await SharedPreferencesHelper.getAccessToken();
    if (!context.mounted) return;
    if (token == null || token.isEmpty) {
      _snack(context, 'Please login to chat with the $party.');
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    // 3. not your own item
    final me = await SharedPreferencesHelper.getUserId();
    if (!context.mounted) return;
    if (me != null && me == otherUserId) {
      _snack(context, kind.ownLabel);
      return;
    }

    // 4. create / reuse the chat
    _busy = true;
    _loader(context);
    final r = await ChatService.createChat(otherUserId: otherUserId, kind: kind, itemId: itemId);
    _busy = false;
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // loader

    if (!r.ok || r.data == null) {
      _snack(context, r.message, error: true);
      if (r.needsLogin) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
      return;
    }

    await ChatService.rememberBuying(r.data!); // I started it → I am the buyer
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          chatId: r.data!,
          title: otherName.isNotEmpty ? otherName : 'Chat with $party',
          subtitle: title,
          isBuyer: true, // the person who starts the chat is the buyer
          openOfferOnStart: openOffer,
          suggestedOffer: price,
        ),
      ),
    );
  }

  static void _loader(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF093C71)),
                ),
                SizedBox(width: 16),
                Expanded(child: Text('Opening chat…', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _snack(BuildContext context, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: error ? const Color(0xFFC62828) : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }
}
