import 'package:flutter/material.dart';

class AppConstants {
  // Primary Colors - Deep Indigo/Navy
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryLighter = Color(0xFFA5B4FC);

  // Accent Colors - Warm Gold/Amber
  static const Color accent = Color(0xFFF97316);
  static const Color accentLight = Color(0xFFFB923C);
  static const Color accentDark = Color(0xFFEA580C);

  // Secondary Accent - Soft Teal
  static const Color secondary = Color(0xFF8B5CF6);
  static const Color secondaryLight = Color(0xFFA78BFA);

  // Neutral Colors
  static const Color surfaceColor = Color(0xFFF8FAFC);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textLight = Color(0xFF94A3B8);

  // Backgrounds
  static const Color white = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF1F5F9);

  // Status Colors (Soft)
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF6366F1);

  // Palette matches the home screen (see constants/app_theme.dart).

  // App Info
  static const String appName = 'QNX MART';

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
    ],
  );

  /// App-bar gradient (indigo -> violet).
  static const LinearGradient appBarGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1), Color(0xFF8B5CF6)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF97316),
      Color(0xFFFB923C),
    ],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4F46E5),
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
    ],
  );
}

// Glossy Decorations
class GlossyDecoration {
  static BoxDecoration gradientCard = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppConstants.primary.withOpacity(0.08),
        AppConstants.accent.withOpacity(0.08),
      ],
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Colors.white.withOpacity(0.4),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: AppConstants.primary.withOpacity(0.08),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration glossyButtonPrimary = BoxDecoration(
    gradient: AppConstants.primaryGradient,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: AppConstants.primary.withOpacity(0.3),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration glossyButtonAccent = BoxDecoration(
    gradient: AppConstants.accentGradient,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: AppConstants.accent.withOpacity(0.3),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration glossyCircle = BoxDecoration(
    gradient: RadialGradient(
      colors: [
        AppConstants.primary.withOpacity(0.06),
        Colors.transparent,
      ],
    ),
    shape: BoxShape.circle,
  );

  static BoxDecoration glossyCircleAccent = BoxDecoration(
    gradient: RadialGradient(
      colors: [
        AppConstants.accent.withOpacity(0.06),
        Colors.transparent,
      ],
    ),
    shape: BoxShape.circle,
  );
}