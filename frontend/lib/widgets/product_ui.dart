// lib/widgets/product_ui.dart
//
// Building blocks for "My Products" and "Add / Edit product", matching the
// OnyxMart B2B HTML designs. Slate/onyx colours come from DT; the few extra
// colours the designs use are in PX.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/design_tokens.dart';

class PX {
  PX._();
  static const Color royal600 = Color(0xFF2563EB); // brand primary
  static const Color royal700 = Color(0xFF1D4ED8); // brand dark
  static const Color royal50 = Color(0xFFEFF6FF);
  static const Color royal200 = Color(0xFFBFDBFE);
  static const Color onyx950 = Color(0xFF090D16);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color rose500 = Color(0xFFF43F5E);
  static const Color rose400 = Color(0xFFFB7185);
  static const Color rose50 = Color(0xFFFFF1F2);

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1), spreadRadius: -1),
  ];
  static const List<BoxShadow> fabShadow = [
    BoxShadow(color: Color(0x662563EB), blurRadius: 16, offset: Offset(0, 6), spreadRadius: -2),
    BoxShadow(color: Color(0x400F172A), blurRadius: 8, offset: Offset(0, 3), spreadRadius: -2),
  ];
  static const List<BoxShadow> stickyShadow = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, -4)),
  ];
}

String formatRupees(double v) {
  final whole = v == v.roundToDouble();
  final s = whole ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  // Indian grouping: 12,34,567
  final parts = s.split('.');
  var n = parts[0];
  final neg = n.startsWith('-');
  if (neg) n = n.substring(1);
  if (n.length > 3) {
    final last3 = n.substring(n.length - 3);
    var rest = n.substring(0, n.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    n = '${groups.join(',')},$last3';
  }
  return '${neg ? '-' : ''}₹$n${parts.length > 1 ? '.${parts[1]}' : ''}';
}

// ---------------------------------------------------------------------------
// Section card: white, rounded-2xl, border, header with title + subtitle.
// ---------------------------------------------------------------------------
class PxSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;
  final bool compact;

  const PxSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.trailing,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.slate200),
        boxShadow: PX.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.only(bottom: compact ? 0 : 8),
            decoration: compact
                ? null
                : const BoxDecoration(border: Border(bottom: BorderSide(color: DT.slate100))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(icon, size: 18, color: PX.royal600),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: DT.text(
                              size: compact ? 14 : 16,
                              weight: FontWeight.w700,
                              color: DT.onyx900)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: DT.text(size: 12, color: DT.slate500, height: 1.4)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          SizedBox(height: compact ? 8 : 16),
          child,
        ],
      ),
    );
  }
}

/// "Product name *"  /  "Branch (optional)"  label, with an optional right widget.
class PxLabel extends StatelessWidget {
  final String text;
  final bool required;
  final bool optional;
  final Widget? trailing;

  const PxLabel(this.text, {super.key, this.required = false, this.optional = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: text,
                style: DT.text(size: 12, weight: FontWeight.w600, color: DT.onyx700),
                children: [
                  if (required)
                    TextSpan(text: ' *', style: DT.text(size: 12, color: PX.rose500)),
                  if (optional)
                    TextSpan(
                        text: ' (optional)',
                        style: DT.text(size: 12, weight: FontWeight.w400, color: DT.slate400)),
                ],
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small blue "Add" / "Manage" text button used in section headers and labels.
class PxLinkButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool iconAfter;
  final VoidCallback? onTap;

  const PxLinkButton({super.key, required this.label, this.icon, this.iconAfter = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final i = icon == null ? null : Icon(icon, size: 14, color: PX.royal600);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DT.rSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (i != null && !iconAfter) ...[i, const SizedBox(width: 3)],
            Text(label, style: DT.text(size: 12, weight: FontWeight.w700, color: PX.royal600)),
            if (i != null && iconAfter) ...[const SizedBox(width: 3), i],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input
// ---------------------------------------------------------------------------
InputDecoration pxInputDecoration({
  String? hint,
  IconData? icon,
  Color? iconColor,
  Widget? prefix,
  String? suffixText,
  Widget? suffix,
  bool dense = false,
  bool tinted = false,
}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(dense ? DT.rSm : DT.rMd),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: DT.text(size: dense ? 12 : 13.5, color: DT.slate400),
    prefixIcon: prefix ??
        (icon == null ? null : Icon(icon, size: dense ? 17 : 19, color: iconColor ?? DT.slate400)),
    prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 20),
    suffixText: suffixText,
    suffixStyle: DT.text(size: 12, weight: FontWeight.w600, color: DT.slate500),
    suffixIcon: suffix,
    filled: true,
    fillColor: tinted ? DT.slate50 : Colors.white,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 10 : 13),
    enabledBorder: b(DT.slate200),
    focusedBorder: b(PX.royal600, 2),
    errorBorder: b(DT.error),
    focusedErrorBorder: b(DT.error, 2),
    errorStyle: DT.text(size: 11.5, color: DT.error),
  );
}

class PxTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;
  final Color? iconColor;
  final Widget? prefix;
  final String? suffixText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final TextCapitalization capitalization;
  final bool bold;
  final bool dense;
  final bool tinted;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;

  const PxTextField({
    super.key,
    required this.controller,
    this.hint,
    this.icon,
    this.iconColor,
    this.prefix,
    this.suffixText,
    this.suffix,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.capitalization = TextCapitalization.none,
    this.bold = false,
    this.dense = false,
    this.tinted = false,
    this.textAlign = TextAlign.start,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      minLines: maxLines > 1 ? maxLines : null,
      textCapitalization: capitalization,
      textAlign: textAlign,
      onChanged: onChanged,
      style: DT.text(
        size: dense ? 12.5 : 13.5,
        weight: bold ? FontWeight.w700 : FontWeight.w500,
        color: DT.onyx900,
      ),
      decoration: pxInputDecoration(
        hint: hint,
        icon: icon,
        iconColor: iconColor,
        prefix: prefix,
        suffixText: suffixText,
        suffix: suffix,
        dense: dense,
        tinted: tinted,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Segmented control (dark selected pill on a grey track) - "None / Flat ₹ / Percent %"
// ---------------------------------------------------------------------------
class PxSegmented<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool small;
  final Color selectedColor;

  const PxSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.small = false,
    this.selectedColor = DT.onyx900,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: small ? Colors.white : DT.slate100,
        borderRadius: BorderRadius.circular(small ? DT.rSm : DT.rMd),
        border: Border.all(color: DT.slate200),
      ),
      child: Row(
        mainAxisSize: small ? MainAxisSize.min : MainAxisSize.max,
        children: [
          for (final (v, label) in options)
            _wrap(
              small,
              GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: EdgeInsets.symmetric(
                      horizontal: small ? 12 : 8, vertical: small ? 6 : 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: v == value ? selectedColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(small ? 6 : DT.rSm),
                    boxShadow: v == value
                        ? const [BoxShadow(color: Color(0x140F172A), blurRadius: 2)]
                        : null,
                  ),
                  child: Text(label,
                      style: DT.text(
                          size: 12,
                          weight: v == value ? FontWeight.w700 : FontWeight.w600,
                          color: v == value ? Colors.white : DT.onyx600)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _wrap(bool small, Widget child) => small ? child : Expanded(child: child);
}

// ---------------------------------------------------------------------------
// Pills
// ---------------------------------------------------------------------------
class PxPill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final Color? border;
  final Widget? trailing;

  const PxPill({
    super.key,
    required this.text,
    required this.bg,
    required this.fg,
    this.icon,
    this.border,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: fg), const SizedBox(width: 3)],
          Text(text, style: DT.text(size: 11, weight: FontWeight.w700, color: fg)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}