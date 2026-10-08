// lib/constants/app_theme.dart
//
// One theme for the whole app, matching the home screen design:
//   brand blue #1A68FA · dark blue #0D3880 · accent orange #FF5722
//   page #F6F8FC · slate text/borders · Plus Jakarta Sans · 12–16 px radii
//
// Every default Material widget (app bars, buttons, inputs, dialogs, sheets,
// checkboxes, switches, chips, pickers, snackbars…) picks this up, so screens
// that don't set their own colours automatically look like the home page.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Palette (same values as the home screen) ──────────────
  static const Color brand = Color(0xFF1A68FA);
  static const Color brandDark = Color(0xFF0D3880);
  static const Color brandDeep = Color(0xFF1557D0);
  static const Color accent = Color(0xFFFF5722);
  static const Color page = Color(0xFFF6F8FC);
  static const Color ink = Color(0xFF0F172A); // slate-900
  static const Color inkSoft = Color(0xFF475569); // slate-600
  static const Color muted = Color(0xFF94A3B8); // slate-400
  static const Color line = Color(0xFFE2E8F0); // slate-200
  static const Color hairline = Color(0xFFF1F5F9); // slate-100
  static const Color brandTint = Color(0xFFEFF6FF); // blue-50
  static const Color danger = Color(0xFFDC2626);
  static const Color success = Color(0xFF059669);

  static TextStyle _t(double size, FontWeight w, Color c, {double? h, double? ls}) =>
      GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: w, color: c, height: h, letterSpacing: ls);

  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
      displayLarge: _t(32, FontWeight.w800, ink, ls: -0.5),
      displayMedium: _t(28, FontWeight.w800, ink, ls: -0.4),
      displaySmall: _t(24, FontWeight.w700, ink),
      headlineMedium: _t(20, FontWeight.w700, ink),
      headlineSmall: _t(18, FontWeight.w700, ink),
      titleLarge: _t(18, FontWeight.w700, ink),
      titleMedium: _t(15, FontWeight.w700, ink),
      titleSmall: _t(13.5, FontWeight.w700, ink),
      bodyLarge: _t(15, FontWeight.w500, ink),
      bodyMedium: _t(13.5, FontWeight.w500, inkSoft),
      bodySmall: _t(12, FontWeight.w500, muted),
      labelLarge: _t(14, FontWeight.w700, ink),
      labelMedium: _t(12.5, FontWeight.w600, inkSoft),
      labelSmall: _t(11, FontWeight.w600, muted),
    );

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.light,
    ).copyWith(
      primary: brand,
      onPrimary: Colors.white,
      primaryContainer: brandTint,
      onPrimaryContainer: brandDark,
      secondary: accent,
      onSecondary: Colors.white,
      tertiary: brandDark,
      surface: Colors.white,
      onSurface: ink,
      onSurfaceVariant: inkSoft,
      surfaceTint: Colors.transparent,
      outline: line,
      outlineVariant: hairline,
      error: danger,
      onError: Colors.white,
    );

    return base.copyWith(
      colorScheme: colorScheme,
      primaryColor: brand,
      scaffoldBackgroundColor: page,
      canvasColor: Colors.white,
      dividerColor: line,
      splashFactory: InkRipple.splashFactory,
      textTheme: textTheme,
      primaryTextTheme: textTheme,

      // White header with dark text and a hairline – like the home header.
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: const Color(0x140F172A),
        centerTitle: false,
        titleTextStyle: _t(18, FontWeight.w700, ink),
        iconTheme: const IconThemeData(color: ink, size: 24),
        actionsIconTheme: const IconThemeData(color: inkSoft, size: 22),
        shape: const Border(bottom: BorderSide(color: hairline)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: brand.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: _t(14.5, FontWeight.w700, Colors.white),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: _t(14.5, FontWeight.w700, Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: brand,
          side: const BorderSide(color: Color(0xFFBFDBFE)),
          minimumSize: const Size(64, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: _t(14, FontWeight.w700, brand),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand,
          textStyle: _t(13.5, FontWeight.w700, brand),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: ink),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: StadiumBorder(),
      ),

      // Inputs: white, slate border, blue focus ring – like the home search / forms.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: _t(13.5, FontWeight.w500, muted),
        labelStyle: _t(13.5, FontWeight.w500, inkSoft),
        floatingLabelStyle: _t(13, FontWeight.w600, brand),
        helperStyle: _t(11.5, FontWeight.w500, muted),
        errorStyle: _t(11.5, FontWeight.w500, danger),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: border(line),
        enabledBorder: border(line),
        disabledBorder: border(hairline),
        focusedBorder: border(brand, 1.6),
        errorBorder: border(danger),
        focusedErrorBorder: border(danger, 1.6),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: _t(17, FontWeight.w800, ink),
        contentTextStyle: _t(13.5, FontWeight.w500, inkSoft, h: 1.5),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: Colors.white,
        showDragHandle: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: _t(13.5, FontWeight.w600, ink),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: _t(13, FontWeight.w600, Colors.white),
        actionTextColor: const Color(0xFF93C5FD),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.all(16),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: brandTint,
        selectedColor: brand,
        disabledColor: hairline,
        side: const BorderSide(color: Color(0xFFDBEAFE)),
        shape: const StadiumBorder(),
        labelStyle: _t(12.5, FontWeight.w600, brand),
        secondaryLabelStyle: _t(12.5, FontWeight.w700, Colors.white),
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? brand : Colors.white),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: Color(0xFF94A3B8), width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? brand : muted),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.selected) ? brand : const Color(0xFFCBD5E1)),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: brand,
        linearTrackColor: hairline,
        circularTrackColor: Colors.transparent,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: brand,
        unselectedLabelColor: inkSoft,
        indicatorColor: brand,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: hairline,
        labelStyle: _t(13.5, FontWeight.w700, brand),
        unselectedLabelStyle: _t(13.5, FontWeight.w600, inkSoft),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: brand,
        textColor: ink,
        titleTextStyle: _t(14, FontWeight.w600, ink),
        subtitleTextStyle: _t(12, FontWeight.w500, muted),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 1),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: brand,
        headerForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: brand,
        selectionColor: Color(0x401A68FA),
        selectionHandleColor: brand,
      ),
    );
  }
}