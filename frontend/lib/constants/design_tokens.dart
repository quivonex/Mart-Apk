import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the new B2B wholesale look (from code.html).
/// Kept separate from AppConstants so existing screens keep working.
class DT {
  DT._();

  // ---------- Neutrals (onyx / slate) ----------
  static const Color onyx900 = Color(0xFF0F172A);
  static const Color onyx800 = Color(0xFF1E293B);
  static const Color onyx700 = Color(0xFF334155);
  static const Color onyx600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color background = Color(0xFFF6F8FC);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSoft = Color(0xCCE2E8F0); // slate-200/80

  // ---------- Brand ----------
  // Brand (home screen palette)
  static const Color brand = Color(0xFF1A68FA);
  static const Color brandDark = Color(0xFF0D3880);
  static const Color accent = Color(0xFFFF5722);

  static const Color blue900 = Color(0xFF0D3880);
  static const Color blue800 = Color(0xFF1A68FA);
  static const Color blue700 = Color(0xFF1557D0);
  static const Color blue200 = Color(0xFFBFDBFE);
  static const Color blue100 = Color(0xFFDBEAFE);
  static const Color blue50 = Color(0xFFEFF6FF);

  static const Color amber900 = Color(0xFF78350F);
  static const Color amber800 = Color(0xFF92400E);
  static const Color amber700 = Color(0xFFB45309);
  static const Color amber600 = Color(0xFFD97706);
  static const Color amber500 = Color(0xFFF59E0B);
  static const Color amber300 = Color(0xFFFCD34D);
  static const Color amber200 = Color(0xFFFDE68A);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color amber50 = Color(0xFFFFFBEB);

  static const Color orange900 = Color(0xFF7C2D12);
  static const Color orange100 = Color(0xFFFFEDD5);
  static const Color orange50 = Color(0xFFFFF7ED);

  static const Color emerald700 = Color(0xFF047857);
  static const Color emerald300 = Color(0xFF6EE7B7);
  static const Color emerald200 = Color(0xFFA7F3D0);
  static const Color emerald50 = Color(0xFFECFDF5);

  static const Color indigo700 = Color(0xFF4338CA);
  static const Color indigo50 = Color(0xFFEEF2FF);

  static const Color teal800 = Color(0xFF115E59);
  static const Color teal50 = Color(0xFFF0FDFA);

  static const Color sky800 = Color(0xFF075985);
  static const Color sky50 = Color(0xFFF0F9FF);

  static const Color purple800 = Color(0xFF6B21A8);
  static const Color purple50 = Color(0xFFFAF5FF);

  static const Color error = Color(0xFFB91C1C);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFFECACA);

  // ---------- Gradients ----------
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F1E36), Color(0xFF1E3A5F), Color(0xFF115E59)],
  );

  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [Color(0xFF0D3880), Color(0xFF1A68FA), Color(0xFFF59E0B)],
  );

  static const LinearGradient rfqGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFFFBEB), Color(0xB3FFF7ED)],
  );

  // ---------- Radii ----------
  static const double rSm = 8;
  static const double rMd = 12;
  static const double rLg = 16;
  static const double rXl = 24;

  // ---------- Shadows ----------
  static const List<BoxShadow> shadowXs = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> shadowM3 = [
    BoxShadow(
        color: Color(0x14000000),
        blurRadius: 6,
        spreadRadius: 2,
        offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> shadowBottomNav = [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 10, offset: Offset(0, -2)),
  ];

  // ---------- Typography (Plus Jakarta Sans) ----------
  static TextStyle text({
    double size = 12,
    FontWeight weight = FontWeight.w500,
    Color color = onyx900,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }
}