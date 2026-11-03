import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle _base = TextStyle(fontFamily: 'Segoe UI');

  static TextStyle get headline1 => _base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle get headline2 => _base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
      );

  static TextStyle get subtitle1 => _base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get subtitle2 => _base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyText1 => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.45,
      );

  static TextStyle get bodyText2 => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
      );

  static TextStyle get caption => _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get secondary => _base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get button => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.neutralWhite,
      );
}
