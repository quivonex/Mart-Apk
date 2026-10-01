import 'package:flutter/material.dart';

class AppConstants {
  // Primary Colors - Deep Indigo/Navy
  static const Color primaryDark = Color(0xFF1A1A3E);
  static const Color primary = Color(0xFF2D2D6B);
  static const Color primaryLight = Color(0xFF4A4A8A);
  static const Color primaryLighter = Color(0xFF6B6BAE);

  // Accent Colors - Warm Gold/Amber
  static const Color accent = Color(0xFFC8943C);
  static const Color accentLight = Color(0xFFD4A84E);
  static const Color accentDark = Color(0xFFA87D32);

  // Secondary Accent - Soft Teal
  static const Color secondary = Color(0xFF3D7E7A);
  static const Color secondaryLight = Color(0xFF5A9A96);

  // Neutral Colors
  static const Color surfaceColor = Color(0xFFF7F7FC);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF5A5A72);
  static const Color textLight = Color(0xFF8A8AA0);

  // Backgrounds
  static const Color white = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFF0F0F8);

  // Status Colors (Soft)
  static const Color success = Color(0xFF3D8B7A);
  static const Color warning = Color(0xFFC8943C);
  static const Color error = Color(0xFFC44A4A);
  static const Color info = Color(0xFF4A7A9E);

  // App Info
  static const String appName = 'QNX MART';

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2D2D6B),
      Color(0xFF4A4A8A),
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFC8943C),
      Color(0xFFD4A84E),
    ],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1A1A3E),
      Color(0xFF2D2D6B),
      Color(0xFF3D7E7A),
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