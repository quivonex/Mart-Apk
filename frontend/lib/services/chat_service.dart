// lib/services/chat_service.dart
//
// Chat APIs (login token: Authorization: Bearer <access token>)
//
//   POST olx/chats/create/                         {other_user_id, product_id | property_id | listing_id}
//        -> {chat:{id}} | {data:{id}} | {id}       (existing chat id is returned again)
//   GET  olx/chats/                                -> {results:[chat]} | {data:[chat]} | [chat]
//   GET  olx/chats/{id}/messages/?page=1&page_size=100
//   POST olx/chats/{id}/messages/send/             {message}
//   POST olx/chats/{id}/offers/                    {amount, message}          (buyer only)
//   POST olx/chats/{id}/offers/{msgId}/respond/    {action: accept|reject|counter, amount?, message?, response_note?}
//   POST olx/chats/{id}/read/                      {}
//   POST olx/listings/detail/                      {id}  (ReMart owner user_id, when missing)
//
// 401 / 403 → token cleared, needsLogin = true.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';
import '../utils/shared_preferences_helper.dart';
import 'api_urls.dart';

class ChatService {
  ChatService._();

  static const _timeout = Duration(seconds: 25);

  // ---------------------------------------------------------------- helpers
  /// Error text in the documented order: detail → message → error →
  /// non_field_errors[0] → first list value → first string value.
  static String errorText(dynamic body, String fallback) {
    if (body is Map) {
      for (final k in const ['detail', 'message', 'error']) {
        final v = body[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
        if (v is List && v.isNotEmpty) return '${v.first}';
      }
      final nfe = body['non_field_errors'];
      if (nfe is List && nfe.isNotEmpty) return '${nfe.first}';
      for (final v in body.values) {
        if (v is List && v.isNotEmpty) return '${v.first}';
      }
      for (final v in body.values) {
        if (v is String && v.trim().isNotEmpty && v.length < 300) return v.trim();
      }
    } else if (body is String && body.trim().isNotEmpty && !body.trimLeft().startsWith('<')) {
      return body.trim();
    }
    return fallback;
  }

  static Future<(int, dynamic)> _send(String method, String url, {Map<String, dynamic>? body}) async {
    final token = await SharedPreferencesHelper.getAccessToken();
    if (token == null || token.isEmpty) return (401, <String, dynamic>{});
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final uri = Uri.parse(url);
    final res = method == 'GET'
        ? await http.get(uri, headers: headers).timeout(_timeout)
        : await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(_timeout);
    dynamic j;
    try {
      j = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    } catch (_) {
      j = res.body;
    }
    return (res.statusCode, j);
  }

  static bool _ok(int code) => code >= 200 && code < 300;

  /// Backend error code ("chat_limit_reached" …) or "http" for any other
  /// server answer – network problems have no code (→ "Tap to retry").
  static String _code(dynamic j) {
    final c = j is Map ? '${j['code'] ?? ''}'.trim() : '';
    return c.isEmpty ? 'http' : c;
  }

  static Future<ChatResult<T>> _authFail<T>(dynamic body) async {
    await SharedPreferencesHelper.clearAll();
    return ChatResult<T>.fail(errorText(body, 'Session expired. Please login again.'), needsLogin: true);
  }

  static Future<ChatResult<T>> _guard<T>(Future<ChatResult<T>> Function() run, String fallback) async {
    try {
      return await run();
    } on TimeoutException {
      return ChatResult<T>.fail('The server is taking too long. Please try again.');
    } catch (_) {
      return ChatResult<T>.fail(fallback);
    }
  }

  static List<Map<String, dynamic>> _list(dynamic j) {
    dynamic raw = j;
    if (j is Map) raw = j['results'] ?? j['data'] ?? j['chats'] ?? j['messages'];
    if (raw is Map) raw = raw['results'] ?? raw['data'];
    if (raw is! List) return const [];
    return [for (final e in raw.whereType<Map>()) Map<String, dynamic>.from(e)];
  }

  /// {message:{…}} | {data:{…}} | {chat:{…}} | {…}
  static Map<String, dynamic>? _object(dynamic j, List<String> keys) {
    if (j is! Map) return null;
    for (final k in keys) {
      if (j[k] is Map) return Map<String, dynamic>.from(j[k]);
    }
    return Map<String, dynamic>.from(j);
  }

  static int? _id(Map<String, dynamic>? m) {
    if (m == null) return null;
    final v = m['id'] ?? m['chat_id'];
    return v is int ? v : int.tryParse('${v ?? ''}');
  }

  // ---------------------------------------------------------------- create chat
  static Future<ChatResult<int>> createChat({
    required int otherUserId,
    required ChatItemKind kind,
    required int itemId,
  }) =>
      _guard(() async {
        final (code, j) = await _send('POST', ApiUrls.chatCreateUrl, body: {
          'other_user_id': otherUserId,
          kind.idKey: itemId,
        });
        if (code == 401 || code == 403) return _authFail<int>(j);
        if (!_ok(code)) return ChatResult<int>.fail(errorText(j, 'Failed to start chat.'));
        final id = _id(_object(j, const ['chat', 'data']));
        if (id == null || id <= 0) return ChatResult<int>.fail(errorText(j, 'Unable to start chat.'));
        return ChatResult<int>.ok(id);
      }, 'Failed to start chat.');

  // ---------------------------------------------------------------- chats
  static Future<ChatResult<List<ChatThread>>> chats() => _guard(() async {
        final (code, j) = await _send('GET', ApiUrls.chatsUrl);
        if (code == 401 || code == 403) return _authFail<List<ChatThread>>(j);
        if (!_ok(code)) return ChatResult<List<ChatThread>>.fail(errorText(j, 'Could not load chats.'));
        final list = [for (final m in _list(j)) ChatThread.fromJson(m)].where((c) => c.id > 0).toList()
          ..sort((a, b) {
            final x = a.activityAt, y = b.activityAt;
            if (x == null && y == null) return b.id.compareTo(a.id);
            if (x == null) return 1;
            if (y == null) return -1;
            return y.compareTo(x);
          });
        return ChatResult.ok(list);
      }, 'Could not load chats.');

  // ---------------------------------------------------------------- messages
  /// Oldest first.
  static Future<ChatResult<List<ChatMessage>>> messages(int chatId, {int pageSize = 100}) => _guard(() async {
        final (code, j) = await _send('GET', ApiUrls.chatMessagesUrl(chatId, pageSize: pageSize));
        if (code == 401 || code == 403) return _authFail<List<ChatMessage>>(j);
        if (!_ok(code)) return ChatResult<List<ChatMessage>>.fail(errorText(j, 'Could not load messages.'));
        final list = [for (final m in _list(j)) ChatMessage.fromJson(m)].where((m) => m.id > 0).toList()
          ..sort(compareMessages);
        return ChatResult.ok(list);
      }, 'Could not load messages.');

  static int compareMessages(ChatMessage a, ChatMessage b) {
    final x = a.createdAt, y = b.createdAt;
    if (x != null && y != null && x != y) return x.compareTo(y);
    return a.id.compareTo(b.id);
  }

  // ---------------------------------------------------------------- send
  static Future<ChatResult<ChatMessage?>> send(int chatId, String text) => _guard(() async {
        final (code, j) = await _send('POST', ApiUrls.chatSendUrl(chatId), body: {'message': text});
        if (code == 401 || code == 403) return _authFail<ChatMessage?>(j);
        if (!_ok(code)) {
          return ChatResult<ChatMessage?>.fail(errorText(j, 'Message not sent.'),
              code: _code(j));
        }
        return ChatResult<ChatMessage?>.ok(_messageFrom(j));
      }, 'Message not sent.');

  static ChatMessage? _messageFrom(dynamic j) {
    final m = _object(j, const ['message', 'data']);
    if (m == null || _id(m) == null) return null;
    return ChatMessage.fromJson(m);
  }

  // ---------------------------------------------------------------- offers
  static Future<ChatResult<ChatMessage?>> createOffer(int chatId, double amount, {String message = ''}) =>
      _guard(() async {
        final (code, j) = await _send('POST', ApiUrls.chatOffersUrl(chatId), body: {
          'amount': amount.toStringAsFixed(2),
          'message': message,
        });
        if (code == 401 || code == 403) return _authFail<ChatMessage?>(j);
        if (!_ok(code)) {
          return ChatResult<ChatMessage?>.fail(errorText(j, 'Offer not sent.'),
              code: _code(j));
        }
        return ChatResult<ChatMessage?>.ok(_messageFrom(j));
      }, 'Offer not sent.');

  /// action: accept | reject | counter (counter needs [amount]).
  static Future<ChatResult<String>> respondOffer(
    int chatId,
    int messageId,
    String action, {
    double? amount,
    String note = '',
  }) =>
      _guard(() async {
        final (code, j) = await _send('POST', ApiUrls.chatOfferRespondUrl(chatId, messageId), body: {
          'action': action,
          if (action == 'counter' && amount != null) 'amount': amount.toStringAsFixed(2),
          if (action == 'counter') 'message': note,
          if (action == 'counter') 'response_note': note,
        });
        if (code == 401 || code == 403) return _authFail<String>(j);
        if (!_ok(code) || (j is Map && j['status'] == false)) {
          return ChatResult<String>.fail(errorText(j, 'Could not update the offer.'));
        }
        return ChatResult<String>.ok(errorText(j, 'Done.'));
      }, 'Could not update the offer.');

  // ---------------------------------------------------------------- read (silent)
  static Future<void> markRead(int chatId) async {
    try {
      await _send('POST', ApiUrls.chatReadUrl(chatId), body: {});
    } catch (_) {}
  }

  // ---------------------------------------------------------------- ReMart owner
  /// user_id of a ReMart listing (olx/listings/detail/) – used when the list
  /// API did not send it.
  static Future<int?> remartOwner(int listingId) async {
    try {
      final res = await http
          .post(
            Uri.parse(ApiUrls.remartListingDetailUrl),
            headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'id': listingId}),
          )
          .timeout(_timeout);
      final j = jsonDecode(res.body);
      final d = j is Map ? (j['data'] is Map ? j['data'] : j) : null;
      if (d is! Map) return null;
      final v = d['user_id'];
      return v is int ? v : int.tryParse('${v ?? ''}');
    } catch (_) {
      return null;
    }
  }
}
