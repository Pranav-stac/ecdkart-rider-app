import 'package:flutter/material.dart';

class AppColors {
  // Main Color Palette
  static const Color primaryGreen = Color(0xFF248C70);  // Primary Green (#248C70) - Headings, main brand, buttons
  static const Color accentOrange = Color(0xFFE89D1E);   // Accent Orange (#E89D1E) - Highlights, CTA, important words
  static const Color darkBlack = Color(0xFF2C2C2C);      // Dark Black (#2C2C2C) - Main text / dark headings
  static const Color lightGreen = Color(0xFF94B2AA);     // Light Green (#94B2AA) - Secondary elements / borders
  static const Color lightOrange = Color(0xFFEDB35E);    // Light Orange (#EDB35E) - Underlines / subtle accents
  static const Color offWhite = Color(0xFFF5FAF8);       // Off-White Background (#F5FAF8) - Main background
  static const Color cream = Color(0xFFE9E2CE);          // Cream (#E9E2CE) - Secondary background / card accent

  // Aliases for compatibility
  static const Color primary = primaryGreen;
  static const Color accent = accentOrange;
  static const Color secondary = accentOrange;
  static const Color dark = darkBlack;
  static const Color white = Color(0xFFFFFFFF);

  // UI Mappings
  static const Color background = offWhite;
  static const Color cardBackground = Colors.white;
  static const Color cardAccent = cream;
  static const Color textPrimary = darkBlack;
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = lightGreen;

  // Status Colors
  static const Color success = primaryGreen;
  static const Color error = Color(0xFFEF4444);
  static const Color warning = accentOrange;
  static const Color info = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGreen, primaryGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [accentOrange, lightOrange],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
