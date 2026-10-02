// lib/widgets/company_ui.dart
//
// Small shared widgets for the company module screens, built on DT tokens
// so they match CompanyListScreen.

import 'package:flutter/material.dart';
import '../constants/design_tokens.dart';

// ---------------------------------------------------------------------------
// App bar: white, bottom border, back button, title + optional subtitle.
// ---------------------------------------------------------------------------
class CompanyTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;

  const CompanyTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
  });

  @override
  Size get preferredSize => Size.fromHeight(64 + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: DT.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: DT.onyx700),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DT.text(
                                  size: 17,
                                  weight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  height: 1.2)),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DT.text(size: 12, color: DT.slate500)),
                        ],
                      ),
                    ),
                    ...actions,
                  ],
                ),
              ),
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section card with a heading.
// ---------------------------------------------------------------------------
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DT.rLg),
        border: Border.all(color: DT.border),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: DT.text(size: 14, weight: FontWeight.w700, letterSpacing: -0.2)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Label/value row. Hidden automatically when value is empty.
// ---------------------------------------------------------------------------
class InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const InfoLine({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: DT.slate400),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(label, style: DT.text(size: 12, color: DT.slate500, height: 1.4)),
          ),
          Expanded(
            child: Text(
              value,
              style: DT.text(
                size: 12.5,
                weight: FontWeight.w600,
                color: onTap != null ? DT.blue800 : DT.onyx800,
                height: 1.4,
              ),
            ),
          ),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 6, top: 1),
              child: Icon(Icons.open_in_new_rounded, size: 14, color: DT.blue800),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(DT.rSm), child: row);
  }
}

// ---------------------------------------------------------------------------
// Empty / error state.
// ---------------------------------------------------------------------------
class StateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  const StateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isError ? DT.errorBg : DT.blue50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: isError ? DT.error : DT.blue800),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: DT.text(size: 16, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: DT.text(size: 13, color: DT.slate500, height: 1.45)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(isError ? Icons.refresh_rounded : Icons.add_rounded, size: 18),
                label: Text(actionLabel!,
                    style: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DT.blue800,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logo with initials fallback.
// ---------------------------------------------------------------------------
class CompanyLogo extends StatelessWidget {
  final String url;
  final String name;
  final double size;

  const CompanyLogo({super.key, required this.url, required this.name, this.size = 52});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: DT.blue50,
      alignment: Alignment.center,
      child: Text(_initials,
          style: DT.text(size: size * 0.36, weight: FontWeight.w800, color: DT.blue800)),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DT.rMd),
        border: Border.all(color: DT.border),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? fallback
          : Image.network(url,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
void showCompanySnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg,
          style: DT.text(size: 13, weight: FontWeight.w600, color: Colors.white)),
      backgroundColor: error ? DT.error : DT.onyx900,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
    ));
}

Future<bool> confirmAction(
    BuildContext context, {
      required String title,
      required String message,
      required String confirmLabel,
      bool destructive = false,
    }) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rLg)),
      title: Text(title, style: DT.text(size: 17, weight: FontWeight.w800)),
      content: Text(message, style: DT.text(size: 13, color: DT.onyx600, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel',
              style: DT.text(size: 13.5, weight: FontWeight.w600, color: DT.slate500)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: destructive ? DT.error : DT.blue800,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DT.rMd)),
          ),
          child: Text(confirmLabel,
              style: DT.text(size: 13.5, weight: FontWeight.w700, color: Colors.white)),
        ),
      ],
    ),
  );
  return ok == true;
}