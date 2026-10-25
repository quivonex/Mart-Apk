// lib/widgets/language_button.dart
//
// Small "🌐 EN ▾" dropdown for headers (Home top bar).
// Picking a language applies it to the whole app at once.

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../l10n/app_language.dart';

const _kBrand = Color(0xFF093C71);
const _kTint = Color(0xFFEAF1F9);
const _kLine = Color(0xFFC9DBEE);

class LanguageButton extends StatelessWidget {
  /// Light style for white headers (default) or on a dark/brand header.
  final bool onDark;
  const LanguageButton({super.key, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguage.locale,
      builder: (context, locale, _) {
        final cur = AppLanguage.current;
        final fg = onDark ? Colors.white : _kBrand;
        return PopupMenuButton<String>(
          tooltip: tr('Language'),
          position: PopupMenuPosition.under,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _kLine),
          ),
          onSelected: (code) async {
            await AppLanguage.change(code);
            if (!context.mounted) return;
            ScaffoldMessenger.maybeOf(context)
              ?..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(tr('Language changed to {0}', [AppLanguage.current.nativeName])),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                margin: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ));
          },
          itemBuilder: (_) => [
            for (final o in AppLanguage.options)
              PopupMenuItem<String>(
                value: o.code,
                height: 46,
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: o.code == cur.code ? _kBrand : _kTint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        o.code == 'en' ? tr('A') : 'अ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: o.code == cur.code ? Colors.white : _kBrand,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(tr(o.nativeName),
                              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          if (o.code != 'en')
                            Text(tr(o.englishName), style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    if (o.code == cur.code) const Icon(Icons.check_rounded, color: _kBrand, size: 20),
                  ],
                ),
              ),
          ],
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: onDark ? Colors.white.withValues(alpha: 0.14) : _kTint,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: onDark ? Colors.white.withValues(alpha: 0.35) : _kLine),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.translate_rounded, size: 16, color: fg),
                const SizedBox(width: 5),
                Text(tr(cur.short), style: DT.text(size: 12.5, weight: FontWeight.w800, color: fg)),
                Icon(Icons.arrow_drop_down_rounded, size: 18, color: fg),
              ],
            ),
          ),
        );
      },
    );
  }
}
