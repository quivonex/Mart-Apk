// lib/utils/locale_controller.dart
//
// App language: English / मराठी / हिंदी
//   • LocaleController.locale  – ValueNotifier, MaterialApp rebuilds on change
//   • LocaleController.load()  – call once in main() before runApp
//   • LocaleController.change('mr')  – saves to SharedPreferences + applies
//   • LocaleController.chosen  – false until the user picks a language once
//
// The saved key is NOT removed on logout (SharedPreferencesHelper.clearAll
// removes only login keys), so the language stays after logout.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  final String code;
  final String nativeName; // shown in its own script
  final String englishName;
  const AppLanguage(this.code, this.nativeName, this.englishName);
}

class LocaleController {
  LocaleController._();

  static const _prefKey = 'app_language_code';

  static const languages = <AppLanguage>[
    AppLanguage('en', 'English', 'English'),
    AppLanguage('mr', 'मराठी', 'Marathi'),
    AppLanguage('hi', 'हिंदी', 'Hindi'),
  ];

  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('en'));

  /// true once the user has picked a language (first-run screen is skipped).
  static bool chosen = false;

  static String get code => locale.value.languageCode;

  static AppLanguage get current =>
      languages.firstWhere((l) => l.code == code, orElse: () => languages.first);

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final c = p.getString(_prefKey);
      if (c != null && languages.any((l) => l.code == c)) {
        locale.value = Locale(c);
        chosen = true;
      }
    } catch (_) {
      // storage not available (private web window) → English
    }
  }

  static Future<void> change(String code) async {
    if (!languages.any((l) => l.code == code)) return;
    locale.value = Locale(code);
    chosen = true;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefKey, code);
    } catch (_) {}
  }
}
