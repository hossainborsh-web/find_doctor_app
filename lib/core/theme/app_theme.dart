import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'app_colors.dart';
import 'app_text_style.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final textTheme = ThemeData(fontFamily: 'Segoe UI').textTheme.copyWith(
          displayLarge:
              AppTextStyles.headline1.copyWith(color: AppColors.neutralBlack),
          displayMedium:
              AppTextStyles.headline2.copyWith(color: AppColors.neutralBlack),
          titleLarge:
              AppTextStyles.subtitle1.copyWith(color: AppColors.neutralBlack),
          titleMedium:
              AppTextStyles.subtitle2.copyWith(color: AppColors.neutralBlack),
          bodyLarge:
              AppTextStyles.bodyText1.copyWith(color: AppColors.neutralBlack),
          bodyMedium:
              AppTextStyles.bodyText2.copyWith(color: AppColors.neutralBlack),
          bodySmall: AppTextStyles.caption.copyWith(color: AppColors.darkGrey),
          labelLarge:
              AppTextStyles.button.copyWith(color: AppColors.neutralWhite),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Segoe UI',
      primaryColor: AppColors.primaryBlue,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        secondary: AppColors.primaryBlueDark,
        tertiary: AppColors.aqua,
        error: AppColors.errorRed,
        surface: AppColors.neutralWhite,
        onPrimary: AppColors.neutralWhite,
        onSecondary: AppColors.primaryBlueDark,
        onError: AppColors.neutralWhite,
        onSurface: AppColors.neutralBlack,
      ),
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.neutralBlack,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 68,
        titleTextStyle: AppTextStyles.headline2.copyWith(
          fontSize: 24,
          color: AppColors.primaryBlueDark,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.35,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardBackground,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.borderGrey),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: AppColors.neutralWhite,
          minimumSize: const Size(0, 52),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          minimumSize: const Size(0, 52),
          side: const BorderSide(color: AppColors.borderGrey, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle:
              AppTextStyles.button.copyWith(color: AppColors.primaryBlue),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.errorRed),
        ),
        labelStyle: AppTextStyles.bodyText2.copyWith(color: AppColors.darkGrey),
        hintStyle: AppTextStyles.bodyText2.copyWith(color: AppColors.darkGrey),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderGrey,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardBackground,
        indicatorColor: AppColors.lightBlue,
        elevation: 0,
        height: 74,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppColors.primaryBlueDark
                  : AppColors.darkGrey,
            )),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.neutralWhite,
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: AppColors.darkGrey,
        elevation: 0,
        selectedLabelStyle:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.inputBackground,
        selectedColor: AppColors.surfaceMuted,
        disabledColor: AppColors.lightGrey,
        side: const BorderSide(color: AppColors.borderGrey),
        shape: const StadiumBorder(),
        labelStyle:
            AppTextStyles.bodyText2.copyWith(color: AppColors.neutralBlack),
        secondaryLabelStyle: AppTextStyles.bodyText2.copyWith(
          color: AppColors.primaryBlueDark,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: AppColors.neutralWhite,
        elevation: 3,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryBlueDark,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.primaryBlue),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.primaryBlue
                : null),
      ),
    );
  }

  static ThemeData get darkTheme {
    const background = Color(0xFF0F1222);
    const surface = Color(0xFF1A1E35);
    const onSurface = Color(0xFFE6E8F5);
    const mutedText = Color(0xFFA3A9C2);
    const border = Color(0xFF33385A);
    const accent = Color(0xFF8B8CF8);

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Segoe UI',
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: Color(0xFFC4B5FD),
        tertiary: Color(0xFFA78BFA),
        error: Color(0xFFFF7777),
        surface: surface,
        onPrimary: Color(0xFF14123A),
        onSecondary: Color(0xFF14123A),
        onError: Color(0xFF2B0C0C),
        onSurface: onSurface,
      ),
      scaffoldBackgroundColor: background,
      textTheme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Segoe UI',
      ).textTheme,
    );

    return base.copyWith(
      primaryColor: accent,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 68,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: const TextStyle(color: mutedText),
      ),
      dividerTheme:
          const DividerThemeData(color: border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: const Color(0xFF2E3360),
        elevation: 0,
        height: 74,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? accent : mutedText,
            )),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: mutedText,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2E3360),
        contentTextStyle: const TextStyle(color: onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}
