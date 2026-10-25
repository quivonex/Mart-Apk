// lib/screens/language_screen.dart
//
// Language choice: English / मराठी / हिंदी
//   • LanguageScreen(firstRun: true, next: …) – once after the splash
//   • showLanguagePicker(context)            – bottom sheet (Account, Drawer)

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';
import '../l10n/app_language.dart';

const _kBrand = Color(0xFF093C71);
const _kBrandDark = Color(0xFF062A50);
const _kBrandLight = Color(0xFF1E5A9C);
const _kTint = Color(0xFFEAF1F9);
const _kLine = Color(0xFFC9DBEE);
const _kInk = Color(0xFF0F172A);
const _kMuted = Color(0xFF64748B);
const _kHeader = LinearGradient(
  colors: [_kBrandDark, _kBrand, _kBrandLight],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const _sample = {'en': 'Hello', 'mr': 'नमस्कार', 'hi': 'नमस्ते'};

class LanguageScreen extends StatefulWidget {
  final bool firstRun;

  /// Screen opened after "Continue" on the first run.
  final WidgetBuilder? next;

  const LanguageScreen({super.key, this.firstRun = false, this.next});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String _code = AppLanguage.code;

  Future<void> _pick(String code) async {
    setState(() => _code = code);
    await AppLanguage.change(code); // the whole app switches right away
  }

  Future<void> _continue() async {
    await AppLanguage.change(_code);
    if (!mounted) return;
    final next = widget.next;
    if (next != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: next));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.firstRun
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              flexibleSpace: Container(decoration: const BoxDecoration(gradient: _kHeader)),
              foregroundColor: Colors.white,
              elevation: 0,
              title: Text(tr('Language'), style: DT.text(size: 17, weight: FontWeight.w700, color: Colors.white)),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          children: [
            if (widget.firstRun) ...[
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(gradient: _kHeader, shape: BoxShape.circle),
                  child: const Icon(Icons.translate_rounded, color: Colors.white, size: 34),
                ),
              ),
              const SizedBox(height: 18),
            ],
            Text(tr('Choose your language'),
                textAlign: widget.firstRun ? TextAlign.center : TextAlign.start,
                style: DT.text(size: 21, weight: FontWeight.w800, color: _kInk)),
            const SizedBox(height: 6),
            Text(tr('You can change it any time from the language button on the home screen.'),
                textAlign: widget.firstRun ? TextAlign.center : TextAlign.start,
                style: DT.text(size: 13, color: _kMuted, height: 1.4)),
            const SizedBox(height: 22),
            for (final o in AppLanguage.options) ...[
              LanguageTile(option: o, selected: _code == o.code, onTap: () => _pick(o.code)),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _continue,
                style: FilledButton.styleFrom(
                  backgroundColor: _kBrand, // buttons: only #093C71
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(tr('Continue'), style: DT.text(size: 15, weight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LanguageTile extends StatelessWidget {
  final LanguageOption option;
  final bool selected;
  final VoidCallback onTap;
  const LanguageTile({super.key, required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _kTint : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? _kBrand : _kLine, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? _kBrand : _kTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  option.code == 'en' ? tr('A') : 'अ',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: selected ? Colors.white : _kBrand),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(option.nativeName),
                        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: _kInk)),
                    Text(
                      option.code == 'en'
                          ? _sample[option.code]!
                          : '${option.englishName} · ${_sample[option.code]}',
                      style: const TextStyle(fontSize: 12.5, color: _kMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? _kBrand : _kLine,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet used from Account and the Drawer.
Future<void> showLanguagePicker(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => ValueListenableBuilder<Locale>(
      valueListenable: AppLanguage.locale,
      builder: (ctx, loc, _) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: _kLine, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text(tr('Choose your language'), style: DT.text(size: 18, weight: FontWeight.w800, color: _kInk)),
              const SizedBox(height: 14),
              for (final o in AppLanguage.options) ...[
                LanguageTile(
                  option: o,
                  selected: loc.languageCode == o.code,
                  onTap: () async {
                    await AppLanguage.change(o.code);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
