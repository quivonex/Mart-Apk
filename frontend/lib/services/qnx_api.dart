// lib/services/qnx_api.dart
//
// Small shared HTTP helper for the newer feature services
// (search, edit listing/property, order extras, chat-plan history,
// offer filters, Instagram reels). Web-safe: only package:http.
//
//   final r = await QnxApi.post(ApiUrls.productSearchUrl, {'search': q});
//   if (r.ok) … r.map / r.list
//
// auth: QnxAuth.required → no token = 401 without calling the server
//       QnxAuth.optional → token sent when present
//       QnxAuth.none     → never sent

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../utils/shared_preferences_helper.dart';

enum QnxAuth { required, optional, none }

class QnxFile {
  final String field;
  final String name;
  final Uint8List bytes;
  const QnxFile(this.field, this.name, this.bytes);
}

class QnxResponse {
  final int code;
  final dynamic body;

  /// Network / timeout text when the call never reached the server.
  final String? networkError;

  const QnxResponse(this.code, this.body, [this.networkError]);

  bool get okCode => code >= 200 && code < 300;

  /// 2xx and no explicit success:false / status:false|"error".
  bool get ok {
    if (!okCode) return false;
    final b = body;
    if (b is! Map) return true;
    final s = b['success'] ?? b['status'];
    if (s == null) return true;
    final t = '$s'.toLowerCase();
    return t != 'false' && t != 'error' && t != 'failed';
  }

  bool get authFailed => code == 401;

  Map<String, dynamic> get map => body is Map ? Map<String, dynamic>.from(body as Map) : <String, dynamic>{};

  /// `data` when it is a Map, else the body map.
  Map<String, dynamic> get dataMap {
    final d = map['data'];
    return d is Map ? Map<String, dynamic>.from(d) : map;
  }

  /// List from `data` / `results` / `items` / body itself.
  List<Map<String, dynamic>> get list {
    dynamic l = body;
    if (l is Map) {
      l = l['data'] ?? l['results'] ?? l['items'] ?? l['returns'];
      if (l is Map) l = l['results'] ?? l['data'] ?? l['items'];
    }
    if (l is! List) return const [];
    return l.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  String error(String fallback) {
    if (networkError != null) return networkError!;
    if (code == 401) return 'Please login again.';
    final b = body;
    if (b is Map) {
      for (final k in const ['detail', 'message', 'error', 'errors']) {
        final v = b[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
        if (v is List && v.isNotEmpty) return '${v.first}';
        if (v is Map && v.isNotEmpty) {
          final f = v.values.first;
          return f is List && f.isNotEmpty ? '${v.keys.first}: ${f.first}' : '${v.keys.first}: $f';
        }
      }
      final nfe = b['non_field_errors'];
      if (nfe is List && nfe.isNotEmpty) return '${nfe.first}';
      for (final e in b.entries) {
        final v = e.value;
        if (v is List && v.isNotEmpty && v.first is String) return '${e.key}: ${v.first}';
      }
    }
    if (code >= 500) return 'Server error ($code). Please try again.';
    return fallback;
  }
}

class QnxApi {
  QnxApi._();

  static const _timeout = Duration(seconds: 25);
  static const _uploadTimeout = Duration(seconds: 90);

  static Future<Map<String, String>?> _headers(QnxAuth auth, {bool json = true}) async {
    final h = <String, String>{'Accept': 'application/json'};
    if (json) h['Content-Type'] = 'application/json';
    if (auth == QnxAuth.none) return h;
    final token = await SharedPreferencesHelper.getAccessToken();
    if (token == null || token.isEmpty) {
      return auth == QnxAuth.required ? null : h;
    }
    h['Authorization'] = 'Bearer $token';
    return h;
  }

  static dynamic _decode(String s) {
    if (s.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(s);
    } catch (_) {
      return s;
    }
  }

  static String _netText(Object e) {
    final s = '$e';
    if (e is TimeoutException || s.contains('TimeoutException')) {
      return 'The server took too long to respond.';
    }
    return 'Could not reach the server. Check your internet.';
  }

  static Future<QnxResponse> post(
    String url,
    Map<String, dynamic> body, {
    QnxAuth auth = QnxAuth.required,
  }) async {
    final h = await _headers(auth);
    if (h == null) return const QnxResponse(401, <String, dynamic>{});
    try {
      final res = await http.post(Uri.parse(url), headers: h, body: jsonEncode(body)).timeout(_timeout);
      return QnxResponse(res.statusCode, _decode(res.body));
    } catch (e) {
      return QnxResponse(0, null, _netText(e));
    }
  }

  /// Multipart POST. Null / empty field values are skipped.
  static Future<QnxResponse> multipart(
    String url,
    Map<String, String?> fields,
    List<QnxFile> files, {
    QnxAuth auth = QnxAuth.required,
  }) async {
    final h = await _headers(auth, json: false);
    if (h == null) return const QnxResponse(401, <String, dynamic>{});
    try {
      final req = http.MultipartRequest('POST', Uri.parse(url))..headers.addAll(h);
      fields.forEach((k, v) {
        if (v != null) req.fields[k] = v;
      });
      for (final f in files) {
        req.files.add(http.MultipartFile.fromBytes(
          f.field,
          f.bytes,
          filename: f.name,
          contentType: _mediaType(f.name),
        ));
      }
      final streamed = await req.send().timeout(_uploadTimeout);
      final res = await http.Response.fromStream(streamed);
      return QnxResponse(res.statusCode, _decode(res.body));
    } catch (e) {
      return QnxResponse(0, null, _netText(e));
    }
  }

  static MediaType _mediaType(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.png')) return MediaType('image', 'png');
    if (n.endsWith('.webp')) return MediaType('image', 'webp');
    if (n.endsWith('.gif')) return MediaType('image', 'gif');
    if (n.endsWith('.mp4')) return MediaType('video', 'mp4');
    if (n.endsWith('.mov')) return MediaType('video', 'quicktime');
    return MediaType('image', 'jpeg');
  }
}

// ── tiny parse helpers shared by the feature models ────────────────
int? qInt(dynamic v) => v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));
double qDbl(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(',', '')) ?? 0;
String qStr(dynamic v) => v == null ? '' : '$v'.trim();
bool qBool(dynamic v) => v == true || '$v'.toLowerCase() == 'true' || v == 1;
DateTime? qDate(dynamic v) {
  final s = qStr(v);
  return s.isEmpty ? null : DateTime.tryParse(s)?.toLocal();
}

String qDateLabel(DateTime? d, {bool time = false}) {
  if (d == null) return '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final base = '${d.day} ${m[d.month - 1]} ${d.year}';
  if (!time) return base;
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final mm = d.minute.toString().padLeft(2, '0');
  return '$base, $h:$mm ${d.hour < 12 ? 'AM' : 'PM'}';
}
