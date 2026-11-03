import 'package:flutter/material.dart';

/// Maps the light palette (see app_colors.dart) to its night-mode equivalent.
extension FdPalette on BuildContext {
  bool get isNightMode => Theme.of(this).brightness == Brightness.dark;

  Color fdColor(Color lightColor) {
    if (!isNightMode) return lightColor;

    return switch (lightColor.toARGB32()) {
      0xFFF4F5FB => const Color(0xFF0F1222), // page background
      0xFFFFFFFF => const Color(0xFF1A1E35), // card/surface
      0xFF0F172A || 0xFF1E1B4B => const Color(0xFFE6E8F5), // main text
      0xFF64748B => const Color(0xFFA3A9C2), // secondary text
      0xFFE4E7F2 => const Color(0xFF33385A), // border
      0xFFEEF0FF ||
      0xFFE0E7FF ||
      0xFFEDE9FE ||
      0xFFF1F5F9 ||
      0xFFFAFAFF =>
        const Color(0xFF252A47), // muted surface
      0xFF4F46E5 || 0xFF7C3AED => const Color(0xFF8B8CF8), // accent
      // Instagram-style greys used by Explore.
      0xFF262626 => const Color(0xFFE6E8F5),
      0xFF737373 => const Color(0xFFA3A9C2),
      0xFFDBDBDB || 0xFFEFEFEF => const Color(0xFF33385A),
      0xFFFAFAFA => const Color(0xFF252A47),
      _ => lightColor,
    };
  }
}
