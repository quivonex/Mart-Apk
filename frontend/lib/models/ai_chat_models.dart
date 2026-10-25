import 'package:qnx_mart/l10n/app_language.dart';
// lib/models/ai_chat_models.dart
//
// QNX Mart AI Assistant – data models.
//   AiConversation  – one chat thread           (AI/conversations/)
//   AiMessage       – one user / assistant line (messages[] / *_message)
//   AiCard          – product / order / property / remart result card
//   AiChatReply     – response of POST AI/chat/
//   AiConversationDetail – response of GET AI/conversations/<uuid>/

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

String _str(Object? v) => v == null ? '' : '$v';

int _int(Object? v) => v is int ? v : int.tryParse('$v') ?? 0;

double? _double(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(RegExp(r'[^0-9.\-]'), ''));
}

/// 'user' or 'assistant'. Accepts role / sender / author / type and
/// user, human, customer, me (any case) as the user.
String _role(Map<String, dynamic> j) {
  final v = _str(j['role'] ?? j['sender'] ?? j['author'] ?? j['message_type'] ?? j['type'])
      .trim()
      .toLowerCase();
  if (const {'user', 'human', 'customer', 'me', 'client'}.contains(v)) return 'user';
  if (j['is_user'] == true || j['from_user'] == true) return 'user';
  return 'assistant';
}

/// mart | remart | realestate | general
enum AiService { mart, remart, realestate, general }

AiService aiServiceFrom(Object? v) {
  switch ('$v'.toLowerCase()) {
    case 'mart':
      return AiService.mart;
    case 'remart':
      return AiService.remart;
    case 'realestate':
    case 'real_estate':
      return AiService.realestate;
    default:
      return AiService.general;
  }
}

extension AiServiceLabel on AiService {
  String get label => switch (this) {
    AiService.mart => tr('Mart'),
    AiService.remart => tr('ReMart'),
    AiService.realestate => tr('Real Estate'),
    AiService.general => tr('General'),
  };
}

// ---------------------------------------------------------------------------
// Conversation
// ---------------------------------------------------------------------------
class AiConversation {
  final String id;
  final String title;
  final AiService activeService;
  final Map<String, dynamic> contextState;
  final int messageCount;
  final bool isArchived;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AiConversation({
    required this.id,
    required this.title,
    this.activeService = AiService.general,
    this.contextState = const {},
    this.messageCount = 0,
    this.isArchived = false,
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
  });

  factory AiConversation.fromJson(Map<String, dynamic> j) => AiConversation(
    id: _str(j['id']),
    title: _str(j['title']).trim().isEmpty ? 'New chat' : _str(j['title']).trim(),
    activeService: aiServiceFrom(j['active_service']),
    contextState: j['context_state'] is Map
        ? Map<String, dynamic>.from(j['context_state'] as Map)
        : const {},
    messageCount: _int(j['message_count']),
    isArchived: j['is_archived'] == true,
    lastMessageAt: _date(j['last_message_at']),
    createdAt: _date(j['created_at']),
    updatedAt: _date(j['updated_at']),
  );

  /// Used for sorting and "time ago" in the history list.
  DateTime? get activityAt => lastMessageAt ?? updatedAt ?? createdAt;

  /// PATCH returns only some fields – keep the rest from the old object.
  AiConversation mergedWith(Map<String, dynamic> j) => AiConversation(
    id: id,
    title: j.containsKey('title') && _str(j['title']).trim().isNotEmpty
        ? _str(j['title']).trim()
        : title,
    activeService: j.containsKey('active_service')
        ? aiServiceFrom(j['active_service'])
        : activeService,
    contextState: contextState,
    messageCount: j.containsKey('message_count') ? _int(j['message_count']) : messageCount,
    isArchived: j.containsKey('is_archived') ? j['is_archived'] == true : isArchived,
    lastMessageAt: _date(j['last_message_at']) ?? lastMessageAt,
    createdAt: createdAt,
    updatedAt: _date(j['updated_at']) ?? updatedAt,
  );
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------
class AiCardItem {
  final String product;
  final int quantity;
  final double? price;

  const AiCardItem({required this.product, this.quantity = 0, this.price});

  factory AiCardItem.fromJson(Map<String, dynamic> j) => AiCardItem(
    product: _str(j['product']),
    quantity: _int(j['quantity']),
    price: _double(j['price']),
  );
}

class AiCard {
  final String ref;

  /// product | order | property | remart | remart_listing | listing
  final String type;
  final String slug;
  final String title;
  final String url;
  final String image;
  final String description;
  final double? price;
  final int quantity;
  final String orderId;
  final String status;
  final String paymentStatus;
  final double? totalAmount;
  final List<AiCardItem> items;

  /// Everything else the backend sends (year, km_driven, fuel, ownership, …).
  final Map<String, dynamic> extra;

  const AiCard({
    required this.ref,
    required this.type,
    this.slug = '',
    this.title = '',
    this.url = '',
    this.image = '',
    this.description = '',
    this.price,
    this.quantity = 0,
    this.orderId = '',
    this.status = '',
    this.paymentStatus = '',
    this.totalAmount,
    this.items = const [],
    this.extra = const {},
  });

  static const _known = {
    'ref', 'type', 'slug', 'title', 'url', 'image', 'description', 'price',
    'quantity', 'order_id', 'status', 'payment_status', 'total_amount', 'items',
  };

  factory AiCard.fromJson(Map<String, dynamic> j) {
    var image = _str(j['image']);
    if (image.isNotEmpty && !image.startsWith('http')) {
      image = 'https://api.qnxmartb2b.com/${image.startsWith('/') ? image.substring(1) : image}';
    }
    return AiCard(
      ref: _str(j['ref']),
      type: _str(j['type']).toLowerCase(),
      slug: _str(j['slug']),
      title: _str(j['title']),
      url: _str(j['url']),
      image: image,
      description: _str(j['description']),
      price: _double(j['price']),
      quantity: _int(j['quantity']),
      orderId: _str(j['order_id']),
      status: _str(j['status']),
      paymentStatus: _str(j['payment_status']),
      totalAmount: _double(j['total_amount']),
      items: j['items'] is List
          ? [
        for (final e in (j['items'] as List).whereType<Map>())
          AiCardItem.fromJson(Map<String, dynamic>.from(e)),
      ]
          : const [],
      extra: {
        for (final e in j.entries)
          if (!_known.contains(e.key) && e.value != null && '${e.value}'.isNotEmpty) e.key: e.value,
      },
    );
  }

  bool get isProduct => type == 'product';
  bool get isOrder => type == 'order';
  bool get isProperty => type == 'property';
  bool get isRemart => type == 'remart' || type == 'remart_listing' || type == 'listing';

  /// Numeric id hidden in [ref] ("123" or "product-123"), if any.
  int? get refId {
    final m = RegExp(r'(\d+)$').firstMatch(ref);
    return m == null ? null : int.tryParse(m.group(1)!);
  }
}

// ---------------------------------------------------------------------------
// Message
// ---------------------------------------------------------------------------
class AiMessage {
  final String id;

  /// user | assistant
  final String role;
  final String content;
  final AiService service;
  final List<AiCard> cards;

  /// success | failed   (client also uses "sending")
  final String status;

  /// 1 = helpful, -1 = not helpful, null = none
  final int? feedback;
  final DateTime? createdAt;

  const AiMessage({
    required this.id,
    required this.role,
    required this.content,
    this.service = AiService.general,
    this.cards = const [],
    this.status = 'success',
    this.feedback,
    this.createdAt,
  });

  factory AiMessage.fromJson(Map<String, dynamic> j) => AiMessage(
    id: _str(j['id']),
    role: _role(j),
    content: _str(j['content']),
    service: aiServiceFrom(j['service']),
    cards: j['cards'] is List
        ? [
      for (final e in (j['cards'] as List).whereType<Map>())
        AiCard.fromJson(Map<String, dynamic>.from(e)),
    ]
        : const [],
    status: _str(j['status']).isEmpty ? 'success' : _str(j['status']),
    feedback: j['feedback'] == null ? null : _int(j['feedback']),
    createdAt: _date(j['created_at']),
  );

  /// Local message shown while it is being sent.
  factory AiMessage.pending(String text) => AiMessage(
    id: 'local-${DateTime.now().microsecondsSinceEpoch}',
    role: 'user',
    content: text,
    status: 'sending',
    createdAt: DateTime.now(),
  );

  bool get isUser => role == 'user';
  bool get isSending => status == 'sending';
  bool get isFailed => status == 'failed';
  bool get isLocal => id.startsWith('local-');

  AiMessage copyWith({String? status, int? feedback, bool clearFeedback = false}) => AiMessage(
    id: id,
    role: role,
    content: content,
    service: service,
    cards: cards,
    status: status ?? this.status,
    feedback: clearFeedback ? null : (feedback ?? this.feedback),
    createdAt: createdAt,
  );
}

// ---------------------------------------------------------------------------
// Responses
// ---------------------------------------------------------------------------
class AiChatReply {
  final AiConversation conversation;
  final AiMessage userMessage;
  final AiMessage assistantMessage;

  const AiChatReply({
    required this.conversation,
    required this.userMessage,
    required this.assistantMessage,
  });

  factory AiChatReply.fromJson(Map<String, dynamic> j) => AiChatReply(
    conversation: AiConversation.fromJson(Map<String, dynamic>.from(j['conversation'] as Map)),
    userMessage: AiMessage.fromJson(Map<String, dynamic>.from(j['user_message'] as Map)),
    assistantMessage:
    AiMessage.fromJson(Map<String, dynamic>.from(j['assistant_message'] as Map)),
  );
}

class AiConversationDetail {
  final AiConversation conversation;
  final List<AiMessage> messages;

  const AiConversationDetail({required this.conversation, required this.messages});

  factory AiConversationDetail.fromJson(Map<String, dynamic> j) => AiConversationDetail(
    conversation: AiConversation.fromJson(Map<String, dynamic>.from(j['conversation'] as Map)),
    messages: j['messages'] is List
        ? [
      for (final e in (j['messages'] as List).whereType<Map>())
        AiMessage.fromJson(Map<String, dynamic>.from(e)),
    ]
        : const [],
  );
}

/// Result wrapper used by AiChatService.
class AiResult<T> {
  final T? data;
  final String? error;
  final int statusCode;

  const AiResult.ok(this.data, [this.statusCode = 200]) : error = null;
  const AiResult.fail(this.error, this.statusCode) : data = null;

  bool get ok => error == null;

  /// 401 – token missing / expired.
  bool get needsLogin => statusCode == 401;
}
