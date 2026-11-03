import 'package:flutter/material.dart';

/// Find Doctor colour palette — "Indigo Care" redesign.
///
/// The constant names are kept from the original palette so every screen picks
/// up the new look automatically (`primaryBlue` is now indigo, `accentTeal` is
/// now violet). If you change a value here, update the dark-mode mapping in
/// `fd_palette.dart` too — it matches on these exact values.
class AppColors {
  AppColors._();

  // Brand
  static const Color primaryBlue = Color(0xFF4F46E5); // indigo 600
  static const Color primaryBlueDark = Color(0xFF1E1B4B); // indigo 950
  static const Color lightBlue = Color(0xFFE0E7FF); // indigo 100
  static const Color darkBlue = Color(0xFF1E1B4B);
  static const Color accentTeal = Color(0xFF7C3AED); // violet 600
  static const Color aqua = Color(0xFFEDE9FE); // violet 100

  // Neutrals
  static const Color neutralWhite = Colors.white;
  static const Color neutralBlack = Color(0xFF0F172A);
  static const Color darkGrey = Color(0xFF64748B);
  static const Color grey = Color(0xFF64748B);
  static const Color lightGrey = Color(0xFFF1F5F9);
  static const Color borderGrey = Color(0xFFE4E7F2);

  // Status
  static const Color successGreen = Color(0xFF18846A);
  static const Color errorRed = Color(0xFFC62828);
  static const Color warningOrange = Color(0xFFB7791F);

  // Surfaces
  static const Color background = Color(0xFFF4F5FB);
  static const Color cardBackground = Colors.white;
  static const Color surfaceMuted = Color(0xFFEEF0FF);
  static const Color inputBackground = Color(0xFFFAFAFF);

  // Sidebar / hero gradient
  static const Color sidebarTop = Color(0xFF312E81); // indigo 900
  static const Color sidebarBottom = Color(0xFF1E1B4B); // indigo 950
}
