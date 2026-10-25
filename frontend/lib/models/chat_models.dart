import 'package:qnx_mart/l10n/app_language.dart';
// lib/models/chat_models.dart
//
// Buyer ↔ seller / agent chat (olx/chats/…), used by Product, Property and
// QNX ReMart detail screens.

int? _intOrNull(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));
int _int(dynamic v) => _intOrNull(v) ?? 0;
double? _dbl(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(',', ''));
}

String _str(dynamic v) => v == null ? '' : '$v'.trim();

DateTime? _date(dynamic v) {
  final s = _str(v);
  if (s.isEmpty) return null;
  return DateTime.tryParse(s)?.toLocal();
}

/// What the chat is about.
enum ChatItemKind { product, property, listing }

extension ChatItemKindX on ChatItemKind {
  /// Body key for olx/chats/create/
  String get idKey => switch (this) {
        ChatItemKind.product => 'product_id',
        ChatItemKind.property => 'property_id',
        ChatItemKind.listing => 'listing_id',
      };

  /// "seller" / "agent" (for messages like "chat with the seller").
  String get partyLabel => this == ChatItemKind.property ? 'agent' : 'seller';

  String get ownLabel => switch (this) {
        ChatItemKind.product => tr('This is your own product.'),
        ChatItemKind.property => tr('This is your own property.'),
        ChatItemKind.listing => tr('This is your own listing.'),
      };
}

// ------------------------------------------------------------------ message
class ChatMessage {
  final int id;
  final String message;
  final String type; // text | offer | …
  final int? senderId;
  final bool isRead;
  final DateTime? createdAt;
  final double? offerAmount;
  final String offerStatus; // pending | accepted | rejected | countered …
  final String offerNote;

  // Local only (not from the server)
  final String localId;
  final bool sending;
  final bool failed;

  const ChatMessage({
    required this.id,
    required this.message,
    required this.type,
    required this.senderId,
    required this.isRead,
    required this.createdAt,
    this.offerAmount,
    this.offerStatus = '',
    this.offerNote = '',
    this.localId = '',
    this.sending = false,
    this.failed = false,
  });

  bool get isOffer => type == 'offer' || (offerAmount != null && offerAmount! > 0);
  bool get isLocal => localId.isNotEmpty && id <= 0;
  bool get isPendingOffer => isOffer && (offerStatus.isEmpty || offerStatus == 'pending');

  /// Stable key for lists.
  String get key => id > 0 ? 'm$id' : 'l$localId';

  factory ChatMessage.fromJson(Map<String, dynamic> j) {
    final sender = j['sender'];
    return ChatMessage(
      id: _int(j['id']),
      message: _str(j['message'] ?? j['text'] ?? j['content']),
      type: _str(j['message_type'] ?? j['type']).isEmpty ? 'text' : _str(j['message_type'] ?? j['type']),
      senderId: _intOrNull(j['sender_id']) ?? (sender is Map ? _intOrNull(sender['id']) : _intOrNull(sender)),
      isRead: j['is_read'] == true,
      createdAt: _date(j['created_at']),
      offerAmount: _dbl(j['offer_amount']),
      offerStatus: _str(j['offer_status']).toLowerCase(),
      offerNote: _str(j['offer_response_note']),
    );
  }

  /// Text message being sent (shown right away, replaced by the server copy).
  factory ChatMessage.pending({required String text, required int? me, double? offer}) => ChatMessage(
        id: 0,
        message: text,
        type: offer != null ? 'offer' : 'text',
        senderId: me,
        isRead: false,
        createdAt: DateTime.now(),
        offerAmount: offer,
        offerStatus: offer != null ? 'pending' : '',
        localId: '${DateTime.now().microsecondsSinceEpoch}',
        sending: true,
      );

  ChatMessage copyWith({bool? sending, bool? failed, String? offerStatus}) => ChatMessage(
        id: id,
        message: message,
        type: type,
        senderId: senderId,
        isRead: isRead,
        createdAt: createdAt,
        offerAmount: offerAmount,
        offerStatus: offerStatus ?? this.offerStatus,
        offerNote: offerNote,
        localId: localId,
        sending: sending ?? this.sending,
        failed: failed ?? this.failed,
      );
}

// ------------------------------------------------------------------ chat thread
class ChatThread {
  final int id;
  final String otherUsername;
  final int? buyerId;
  final String itemType;
  final String itemTitle;
  final ChatMessage? lastMessage;
  final int unreadCount;

  const ChatThread({
    required this.id,
    required this.otherUsername,
    required this.buyerId,
    required this.itemType,
    required this.itemTitle,
    required this.lastMessage,
    required this.unreadCount,
  });

  DateTime? get activityAt => lastMessage?.createdAt;

  String get displayName => otherUsername.isEmpty ? tr('User') : otherUsername;

  String get itemLabel => switch (itemType.toLowerCase()) {
        'product' => tr('Product'),
        'property' => tr('Property'),
        'listing' || 'olx' || 'remart' => tr('ReMart'),
        _ => itemType.isEmpty ? '' : itemType[0].toUpperCase() + itemType.substring(1),
      };

  factory ChatThread.fromJson(Map<String, dynamic> j) {
    final buyer = j['buyer'];
    final item = j['item'] is Map ? Map<String, dynamic>.from(j['item']) : const <String, dynamic>{};
    final last = j['last_message'];
    return ChatThread(
      id: _int(j['id']),
      otherUsername: _str(j['other_username'] ?? j['other_user_name'] ?? j['username']),
      // Who started the chat (= buyer). user_one is only the lower user id, so it is NOT used.
      buyerId: (buyer is Map ? _intOrNull(buyer['id']) : _intOrNull(buyer)) ??
          _intOrNull(j['buyer_id'] ?? j['started_by'] ?? j['initiated_by'] ?? j['created_by']),
      itemType: _str(item['type']),
      itemTitle: _str(item['title'] ?? item['name']),
      lastMessage: last is Map ? ChatMessage.fromJson(Map<String, dynamic>.from(last)) : null,
      unreadCount: _int(j['unread_count']),
    );
  }
}

// ------------------------------------------------------------------ result
class ChatResult<T> {
  final bool ok;
  final T? data;
  final String message;

  /// 401 / 403 – token cleared, user must log in again.
  final bool needsLogin;

  /// Backend `code`, e.g. "chat_limit_reached".
  final String code;

  const ChatResult._(this.ok, this.data, this.message, this.needsLogin, this.code);
  const ChatResult.ok(T value, [String message = '']) : this._(true, value, message, false, '');
  const ChatResult.fail(String message, {bool needsLogin = false, String code = ''})
      : this._(false, null, message, needsLogin, code);

  bool get limitReached => code == 'chat_limit_reached';
}
