// lib/l10n/app_language.dart
//
// App language: English / मराठी / हिंदी
//
//   • tr('My orders')                  → "माझ्या ऑर्डर्स" (मराठी)
//   • tr('{0} items left', [count])    → "{0} वस्तू शिल्लक" with {0} filled
//   • trData(product.name)             → backend translation of product /
//                                         property / ReMart text (when available)
//
// English text is the key. Translations live in strings_mr.dart and
// strings_hi.dart; a missing entry simply shows the English text.
//
// AppLanguage.change('mr') saves the choice (SharedPreferences) and rebuilds
// every screen that is open, so the whole app switches at once.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_urls.dart';
import 'strings_hi.dart';
import 'strings_mr.dart';

class LanguageOption {
  final String code;
  final String nativeName; // in its own script
  final String englishName;
  final String short; // for the small header button
  const LanguageOption(this.code, this.nativeName, this.englishName, this.short);
}

class AppLanguage {
  AppLanguage._();

  static const _prefKey = 'app_language_code';

  static const options = <LanguageOption>[
    LanguageOption('en', 'English', 'English', 'EN'),
    LanguageOption('mr', 'मराठी', 'Marathi', 'मरा'),
    LanguageOption('hi', 'हिंदी', 'Hindi', 'हिं'),
  ];

  /// MaterialApp listens to this.
  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('en'));

  /// true once the user picked a language (first-run screen is skipped).
  static bool chosen = false;

  static String get code => locale.value.languageCode;

  static LanguageOption get current =>
      options.firstWhere((o) => o.code == code, orElse: () => options.first);

  static Map<String, String> get _table => switch (code) {
        'mr' => kStringsMr,
        'hi' => kStringsHi,
        _ => const {},
      };

  /// Call once in main() before runApp.
  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final c = p.getString(_prefKey);
      if (c != null && options.any((o) => o.code == c)) {
        locale.value = Locale(c);
        chosen = true;
      }
      _loadDataCache(p);
    } catch (_) {
      // storage blocked (private web window) → English
    }
  }

  static Future<void> change(String newCode) async {
    if (!options.any((o) => o.code == newCode)) return;
    chosen = true;
    if (newCode != code) {
      locale.value = Locale(newCode);
      _rebuildAllSoon();
    }
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefKey, newCode);
    } catch (_) {}
  }

  /// Marks every element dirty so texts built with tr() refresh
  /// (screens keep their state, scroll position and data).
  static void _rebuildAllSoon() {
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      final root = binding.rootElement;
      if (root == null) return;
      void visit(Element e) {
        e.markNeedsBuild();
        e.visitChildren(visit);
      }

      root.visitChildren(visit);
    });
    binding.scheduleFrame();
  }

  // ── backend content (product / property / ReMart names …) ───────
  // POST accounts/translate/ {texts:[...], target:"mr"} → {translations:[...]}
  // Until the backend has this API, trData() just returns the original text.
  static final Map<String, Map<String, String>> _data = {'mr': {}, 'hi': {}};
  static final Set<String> _pending = {};
  static Timer? _batchTimer;
  static bool _apiMissing = false;
  static DateTime? _pauseUntil; // after an error, wait before trying again
  static const _dataPrefKey = 'app_language_data_cache_v1';

  static void _loadDataCache(SharedPreferences p) {
    try {
      final raw = p.getString(_dataPrefKey);
      if (raw == null) return;
      final j = jsonDecode(raw);
      if (j is! Map) return;
      for (final lang in const ['mr', 'hi']) {
        final m = j[lang];
        if (m is Map) _data[lang]!.addAll(m.map((k, v) => MapEntry('$k', '$v')));
      }
    } catch (_) {}
  }

  static Future<void> _saveDataCache() async {
    try {
      final p = await SharedPreferences.getInstance();
      // keep the cache small
      for (final m in _data.values) {
        if (m.length > 3000) m.remove(m.keys.first);
      }
      await p.setString(_dataPrefKey, jsonEncode(_data));
    } catch (_) {}
  }

  static String translateData(String text) {
    final lang = code;
    final t = text.trim();
    if (lang == 'en' || t.isEmpty || _apiMissing) return text;
    final pause = _pauseUntil;
    if (pause != null && DateTime.now().isBefore(pause)) return text;
    if (!RegExp(r'[A-Za-z]').hasMatch(t)) return text; // numbers, codes …
    final hit = _data[lang]![t];
    if (hit != null) return hit;
    _pending.add(t);
    _batchTimer ??= Timer(const Duration(milliseconds: 350), _flush);
    return text;
  }

  static Future<void> _flush() async {
    _batchTimer = null;
    final lang = code;
    if (lang == 'en' || _pending.isEmpty) {
      _pending.clear();
      return;
    }
    final texts = _pending.take(80).toList();
    _pending.removeAll(texts);
    try {
      final res = await http
          .post(
            Uri.parse('${ApiUrls.baseUrl}${ApiUrls.translateTexts}'),
            headers: const {'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode({'texts': texts, 'target': lang}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 404 || res.statusCode == 405) {
        _apiMissing = true; // backend has no translate API yet
        _pending.clear();
        return;
      }
      if (res.statusCode < 200 || res.statusCode >= 300) {
        _pauseUntil = DateTime.now().add(const Duration(minutes: 2));
        _pending.clear();
        return;
      }
      final j = jsonDecode(res.body);
      final list = j is Map ? (j['translations'] ?? j['data']) : null;
      if (list is List && list.length == texts.length) {
        for (var i = 0; i < texts.length; i++) {
          final v = '${list[i] ?? ''}'.trim();
          if (v.isNotEmpty) _data[lang]![texts[i]] = v;
        }
        _saveDataCache();
        if (code == lang) _rebuildAllSoon();
      }
    } catch (_) {
      // offline / server error → keep the original text, retry later
      _pauseUntil = DateTime.now().add(const Duration(minutes: 2));
      _pending.clear();
      return;
    }
    if (_pending.isNotEmpty) _batchTimer ??= Timer(const Duration(milliseconds: 350), _flush);
  }
}

/// Translate a fixed app text. English is the key; {0}, {1} … are filled
/// from [args] in order.
String tr(String en, [List<Object?> args = const []]) {
  var s = AppLanguage._table[en] ?? en;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i] ?? ''}');
  }
  return s;
}

/// Translate text that comes from the backend (product / property / ReMart
/// names, descriptions …). Shows the original until the translation arrives.
String trData(String? text) => text == null ? '' : AppLanguage.translateData(text);

/// Nullable variant of [tr] (hintText:, errorText: … may be null).
String? trN(String? en) => en == null ? null : tr(en);
