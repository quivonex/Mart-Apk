// lib/services/ai_chat_service.dart
//
// QNX Mart AI Assistant. All URLs come from ApiUrls (services/api_urls.dart).
//
//   POST   AI/chat/                        sendMessage()
//   GET    AI/conversations/               conversations()
//   GET    AI/conversations/<uuid>/        conversation()
//   PATCH  AI/conversations/<uuid>/        rename() / setArchived()
//   DELETE AI/conversations/<uuid>/        delete()
//   POST   AI/messages/<uuid>/feedback/    feedback()
//
// Every call sends  Authorization: Bearer <access_token>.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_chat_models.dart';
import '../utils/shared_preferences_helper.dart';
import 'api_urls.dart';

class AiChatService {
  AiChatService._();

  static const _timeout = Duration(seconds: 60); // AI replies can be slow

  static Future<Map<String, String>?> _headers() async {
    final token = await SharedPreferencesHelper.getAccessToken();
    if (token == null || token.isEmpty) return null;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Friendly text for an error response.
  static String _errorText(http.Response r) {
    String? detail;
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map) {
        detail = (j['detail'] ?? j['message'] ?? j['error'])?.toString();
        if (detail == null && j.isNotEmpty) {
          final v = j.values.first;
          detail = v is List && v.isNotEmpty ? '${v.first}' : '$v';
        }
      }
    } catch (_) {}
    switch (r.statusCode) {
      case 401:
        return 'Your session has expired. Please log in again.';
      case 404:
        return 'This conversation no longer exists.';
      case 429:
        return detail ?? 'You are sending messages too fast. Please wait a moment.';
      case 503:
        return detail ?? 'The assistant is temporarily unavailable. Please try later.';
      default:
        return detail ?? 'Something went wrong (${r.statusCode}). Please try again.';
    }
  }

  static String _networkError(Object e) {
    if (e is TimeoutException) return 'The assistant is taking too long. Please try again.';
    if (e is FormatException || e is TypeError) return 'Unexpected reply from the server. Please try again.';
    return 'Could not reach the server. Check your internet connection.';
  }

  static Map<String, dynamic> _json(http.Response r) {
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    return j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{};
  }

  // =================================================================
  // 1. Send message   POST AI/chat/
  // =================================================================
  static Future<AiResult<AiChatReply>> sendMessage(String message, {String? conversationId}) async {
    final h = await _headers();
    if (h == null) return const AiResult.fail('Please log in to chat with the assistant.', 401);
    try {
      final r = await http
          .post(
        Uri.parse(ApiUrls.aiChatUrl),
        headers: h,
        body: jsonEncode({
          'message': message,
          if (conversationId != null && conversationId.isNotEmpty) 'conversation_id': conversationId,
        }),
      )
          .timeout(_timeout);
      if (r.statusCode != 200 && r.statusCode != 201) return AiResult.fail(_errorText(r), r.statusCode);
      return AiResult.ok(AiChatReply.fromJson(_json(r)));
    } catch (e) {
      return AiResult.fail(_networkError(e), 0);
    }
  }

  // =================================================================
  // 2. List conversations   GET AI/conversations/
  //    (active + archived – split on the client by isArchived)
  // =================================================================
  static Future<AiResult<List<AiConversation>>> conversations() async {
    final h = await _headers();
    if (h == null) return const AiResult.fail('Please log in to chat with the assistant.', 401);
    try {
      final r = await http.get(Uri.parse(ApiUrls.aiConversationsUrl), headers: h).timeout(_timeout);
      if (r.statusCode != 200) return AiResult.fail(_errorText(r), r.statusCode);
      final body = jsonDecode(utf8.decode(r.bodyBytes));
      final raw = body is List ? body : (body is Map ? body['results'] : null);
      final list = <AiConversation>[
        if (raw is List)
          for (final e in raw.whereType<Map>()) AiConversation.fromJson(Map<String, dynamic>.from(e)),
      ]..sort((a, b) => (b.activityAt ?? DateTime(2000)).compareTo(a.activityAt ?? DateTime(2000)));
      return AiResult.ok(list);
    } catch (e) {
      return AiResult.fail(_networkError(e), 0);
    }
  }

  // =================================================================
  // 3. Conversation detail   GET AI/conversations/<uuid>/
  // =================================================================
  static Future<AiResult<AiConversationDetail>> conversation(String id) async {
    final h = await _headers();
    if (h == null) return const AiResult.fail('Please log in to chat with the assistant.', 401);
    try {
      final r = await http.get(Uri.parse(ApiUrls.aiConversationUrl(id)), headers: h).timeout(_timeout);
      if (r.statusCode != 200) return AiResult.fail(_errorText(r), r.statusCode);
      return AiResult.ok(AiConversationDetail.fromJson(_json(r)));
    } catch (e) {
      return AiResult.fail(_networkError(e), 0);
    }
  }

  // =================================================================
  // 4. Rename / archive   PATCH AI/conversations/<uuid>/
  //    Returns the changed fields (merge them into the old object).
  // =================================================================
  static Future<AiResult<Map<String, dynamic>>> _patch(String id, Map<String, dynamic> body) async {
    final h = await _headers();
    if (h == null) return const AiResult.fail('Please log in to chat with the assistant.', 401);
    try {
      final r = await http
          .patch(Uri.parse(ApiUrls.aiConversationUrl(id)), headers: h, body: jsonEncode(body))
          .timeout(_timeout);
      if (r.statusCode != 200) return AiResult.fail(_errorText(r), r.statusCode);
      final j = _json(r);
      final c = j['conversation'];
      return AiResult.ok(c is Map ? Map<String, dynamic>.from(c) : body);
    } catch (e) {
      return AiResult.fail(_networkError(e), 0);
    }
  }

  static Future<AiResult<Map<String, dynamic>>> rename(String id, String title) =>
      _patch(id, {'title': title});

  static Future<AiResult<Map<String, dynamic>>> setArchived(String id, bool archived) =>
      _patch(id, {'is_archived': archived});

  // =================================================================
  // 5. Delete   DELETE AI/conversations/<uuid>/   -> 204
  // =================================================================
  static Future<AiResult<bool>> delete(String id) async {
    final h = await _headers();
    if (h == null) return const AiResult.fail('Please log in to chat with the assistant.', 401);
    try {
      final r = await http.delete(Uri.parse(ApiUrls.aiConversationUrl(id)), headers: h).timeout(_timeout);
      if (r.statusCode != 204 && r.statusCode != 200) return AiResult.fail(_errorText(r), r.statusCode);
      return const AiResult.ok(true, 204);
    } catch (e) {
      return AiResult.fail(_networkError(e), 0);
    }
  }

  // =================================================================
  // 6. Feedback   POST AI/messages/<uuid>/feedback/
  //    1 = helpful, -1 = not helpful, null = clear
  // =================================================================
  static Future<AiResult<int?>> feedback(String messageId, int? value) async {
    final h = await _headers();
    if (h == null) return const AiResult.fail('Please log in to chat with the assistant.', 401);
    try {
      final r = await http
          .post(Uri.parse(ApiUrls.aiMessageFeedbackUrl(messageId)),
          headers: h, body: jsonEncode({'feedback': value}))
          .timeout(_timeout);
      if (r.statusCode != 200) return AiResult.fail(_errorText(r), r.statusCode);
      final f = _json(r)['feedback'];
      return AiResult.ok(f == null ? null : int.tryParse('$f'));
    } catch (e) {
      return AiResult.fail(_networkError(e), 0);
    }
  }
}
