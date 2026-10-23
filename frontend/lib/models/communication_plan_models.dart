// lib/models/communication_plan_models.dart
//
// QNX ReMart Communication Plan – limits for chats and enquiries.

int? _intN(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));
double _dbl(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(',', '')) ?? 0;
String _str(dynamic v) => v == null ? '' : '$v'.trim();
DateTime? _date(dynamic v) {
  final s = _str(v);
  return s.isEmpty ? null : DateTime.tryParse(s)?.toLocal();
}

/// "monthly" → "per month", "subscription" → "for the plan period".
String commPeriodLabel(String p) => switch (p.toLowerCase()) {
  'daily' => 'per day',
  'weekly' => 'per week',
  'monthly' => 'per month',
  'yearly' || 'annual' => 'per year',
  'subscription' || '' => 'for the plan period',
  _ => 'per $p',
};

/// "Unlimited chats" / "20 chats per month"
String commLimitLabel({
  required bool unlimited,
  required int? limit,
  required String period,
  required String noun,
}) {
  if (unlimited) return 'Unlimited ${noun}s';
  if (limit == null) return '';
  return '$limit ${limit == 1 ? noun : '${noun}s'} ${commPeriodLabel(period)}';
}

class CommPlan {
  final int id;
  final String name;
  final String description;
  final double price;
  final int durationDays;
  final bool chatUnlimited;
  final int? chatLimit;
  final String chatLimitPeriod;
  final bool enquiryUnlimited;
  final int? enquiryLimit;
  final String enquiryLimitPeriod;

  const CommPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationDays,
    required this.chatUnlimited,
    required this.chatLimit,
    required this.chatLimitPeriod,
    required this.enquiryUnlimited,
    required this.enquiryLimit,
    required this.enquiryLimitPeriod,
  });

  String get chatLabel =>
      commLimitLabel(unlimited: chatUnlimited, limit: chatLimit, period: chatLimitPeriod, noun: 'chat');
  String get enquiryLabel =>
      commLimitLabel(unlimited: enquiryUnlimited, limit: enquiryLimit, period: enquiryLimitPeriod, noun: 'enquiry');

  String get durationLabel {
    final d = durationDays;
    if (d <= 0) return '';
    if (d % 365 == 0) return d == 365 ? '1 year' : '${d ~/ 365} years';
    if (d % 30 == 0) return d == 30 ? '1 month' : '${d ~/ 30} months';
    return d == 1 ? '1 day' : '$d days';
  }

  factory CommPlan.fromJson(Map<String, dynamic> j) => CommPlan(
    id: _intN(j['id']) ?? 0,
    name: _str(j['name']).isEmpty ? 'Plan' : _str(j['name']),
    description: _str(j['description']),
    price: _dbl(j['price']),
    durationDays: _intN(j['duration_days']) ?? 0,
    chatUnlimited: j['chat_unlimited'] == true,
    chatLimit: _intN(j['chat_limit']),
    chatLimitPeriod: _str(j['chat_limit_period']),
    enquiryUnlimited: j['enquiry_unlimited'] == true,
    enquiryLimit: _intN(j['enquiry_limit']),
    enquiryLimitPeriod: _str(j['enquiry_limit_period']),
  );
}

class CommSubscription {
  final int id;
  final String planName;
  final double pricePaid;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final bool currentlyValid;
  final String status;
  final bool chatUnlimited;
  final int? chatLimit;
  final String chatLimitPeriod;
  final bool enquiryUnlimited;
  final int? enquiryLimit;
  final String enquiryLimitPeriod;

  const CommSubscription({
    required this.id,
    required this.planName,
    required this.pricePaid,
    required this.startsAt,
    required this.expiresAt,
    required this.currentlyValid,
    required this.status,
    required this.chatUnlimited,
    required this.chatLimit,
    required this.chatLimitPeriod,
    required this.enquiryUnlimited,
    required this.enquiryLimit,
    required this.enquiryLimitPeriod,
  });

  String get chatLabel =>
      commLimitLabel(unlimited: chatUnlimited, limit: chatLimit, period: chatLimitPeriod, noun: 'chat');
  String get enquiryLabel =>
      commLimitLabel(unlimited: enquiryUnlimited, limit: enquiryLimit, period: enquiryLimitPeriod, noun: 'enquiry');

  int get daysLeft {
    final e = expiresAt;
    if (e == null) return 0;
    final left = e.difference(DateTime.now());
    return left.isNegative ? 0 : (left.inHours / 24).ceil();
  }

  String get statusLabel {
    if (currentlyValid) return 'Active';
    if (status.isEmpty) return 'Inactive';
    return status[0].toUpperCase() + status.substring(1);
  }

  factory CommSubscription.fromJson(Map<String, dynamic> j) {
    final plan = j['plan'] is Map ? Map<String, dynamic>.from(j['plan']) : const <String, dynamic>{};
    final name = _str(j['plan_name']).isNotEmpty ? _str(j['plan_name']) : _str(plan['name']);
    return CommSubscription(
      id: _intN(j['id']) ?? 0,
      planName: name.isEmpty ? 'Plan' : name,
      pricePaid: _dbl(j['price_paid']),
      startsAt: _date(j['starts_at']),
      expiresAt: _date(j['expires_at']),
      currentlyValid: j['is_currently_valid'] == true,
      status: _str(j['status']).toLowerCase(),
      chatUnlimited: j['chat_unlimited_snapshot'] == true,
      chatLimit: _intN(j['chat_limit_snapshot']),
      chatLimitPeriod: _str(j['chat_limit_period_snapshot']),
      enquiryUnlimited: j['enquiry_unlimited_snapshot'] == true,
      enquiryLimit: _intN(j['enquiry_limit_snapshot']),
      enquiryLimitPeriod: _str(j['enquiry_limit_period_snapshot']),
    );
  }
}

/// Chat / enquiry usage for the current period.
class CommUsage {
  final bool unlimited;
  final int used;
  final int? limit;
  final int? remaining;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  const CommUsage({
    required this.unlimited,
    required this.used,
    required this.limit,
    required this.remaining,
    required this.periodStart,
    required this.periodEnd,
  });

  /// 0..1 used (0 for unlimited).
  double get fraction {
    if (unlimited || limit == null || limit! <= 0) return 0;
    return (used / limit!).clamp(0.0, 1.0);
  }

  bool get exhausted => !unlimited && limit != null && (remaining ?? (limit! - used)) <= 0;

  factory CommUsage.fromJson(Map<String, dynamic> j) {
    final limit = _intN(j['limit']);
    final used = _intN(j['used']) ?? 0;
    return CommUsage(
      unlimited: j['unlimited'] == true,
      used: used,
      limit: limit,
      remaining: _intN(j['remaining']) ?? (limit == null ? null : (limit - used).clamp(0, limit)),
      periodStart: _date(j['period_start']),
      periodEnd: _date(j['period_end']),
    );
  }
}

class CommOrder {
  final String orderId;
  final String key;
  final int amountPaise;
  final String currency;
  final String planName;

  const CommOrder({
    required this.orderId,
    required this.key,
    required this.amountPaise,
    required this.currency,
    required this.planName,
  });
}

class CommResult<T> {
  final bool ok;
  final T? data;
  final String message;

  /// 401 / 403 – token cleared, user must log in again.
  final bool needsLogin;

  const CommResult._(this.ok, this.data, this.message, this.needsLogin);
  const CommResult.ok(T value, [String message = '']) : this._(true, value, message, false);
  const CommResult.fail(String message, {bool needsLogin = false}) : this._(false, null, message, needsLogin);
}
