import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static const String _languageKey = 'app_language';

  Locale _locale;

  LocalizationService({
    Locale initialLocale = const Locale('en'),
  }) : _locale = initialLocale;

  Locale get locale => _locale;

  String get languageCode => _locale.languageCode;

  bool get isEnglish => languageCode == 'en';

  bool get isArabic => languageCode == 'ar';

  bool get isMalay => languageCode == 'ms';

  Future<void> loadSavedLocale() async {
    final preferences = await SharedPreferences.getInstance();

    final savedLanguage = preferences.getString(_languageKey);

    if (savedLanguage == null || savedLanguage.isEmpty) {
      return;
    }

    _locale = Locale(savedLanguage);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) {
      return;
    }

    if (_locale == locale) {
      return;
    }

    _locale = locale;

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(
      _languageKey,
      locale.languageCode,
    );

    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    final locale = supportedLocales.firstWhere(
      (item) => item.languageCode == languageCode,
      orElse: () => const Locale('en'),
    );

    await setLocale(locale);
  }

  Future<void> clearSavedLocale() async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.remove(_languageKey);
  }

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
    Locale('ms'),
  ];

  static const List<Locale> supportedLanguages = supportedLocales;

  static const Map<String, Map<String, String>> _messages = {
    'en': {
      'home': 'Home',
      'explore': 'Explore',
      'chat': 'Chat',
      'search': 'Search',
      'profile': 'Profile',
      'hello': 'Hello',
      'homeSubtitle': 'Find care that feels right for you',
      'findDoctor': 'Find the right doctor',
      'searchSupport': 'Search trusted clinicians by name or specialty.',
      'searchHint': 'Doctors, specialties, clinics',
      'recommended': 'Recommended doctors',
      'seeAll': 'See all',
      'appointments': 'Your appointments',
      'viewAll': 'View all',
      'manageVisits': 'Manage your visits',
      'reviewVisits': 'Review upcoming and past appointments',
      'community': 'From the health community',
      'exploreAction': 'Explore',
    },
    'ms': {
      'home': 'Laman Utama',
      'explore': 'Teroka',
      'chat': 'Sembang',
      'search': 'Cari',
      'profile': 'Profil',
      'hello': 'Hai',
      'homeSubtitle': 'Cari penjagaan yang sesuai untuk anda',
      'findDoctor': 'Cari doktor yang sesuai',
      'searchSupport': 'Cari doktor mengikut nama atau kepakaran.',
      'searchHint': 'Doktor, kepakaran, klinik',
      'recommended': 'Doktor disyorkan',
      'seeAll': 'Lihat semua',
      'appointments': 'Temu janji anda',
      'viewAll': 'Lihat semua',
      'manageVisits': 'Urus lawatan anda',
      'reviewVisits': 'Semak temu janji akan datang dan lepas',
      'community': 'Daripada komuniti kesihatan',
      'exploreAction': 'Teroka',
    },
    'ar': {
      'home': 'الرئيسية',
      'explore': 'استكشف',
      'chat': 'المحادثات',
      'search': 'بحث',
      'profile': 'الملف الشخصي',
      'hello': 'مرحبًا',
      'homeSubtitle': 'اعثر على الرعاية المناسبة لك',
      'findDoctor': 'اعثر على الطبيب المناسب',
      'searchSupport': 'ابحث عن الأطباء بالاسم أو التخصص.',
      'searchHint': 'الأطباء والتخصصات والعيادات',
      'recommended': 'أطباء مقترحون',
      'seeAll': 'عرض الكل',
      'appointments': 'مواعيدك',
      'viewAll': 'عرض الكل',
      'manageVisits': 'إدارة زياراتك',
      'reviewVisits': 'راجع المواعيد القادمة والسابقة',
      'community': 'من مجتمع الصحة',
      'exploreAction': 'استكشف',
    },
  };

  String text(String key) =>
      _messages[languageCode]?[key] ?? _messages['en']![key] ?? key;

  static String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      case 'ms':
        return 'Bahasa Melayu';
      default:
        return languageCode;
    }
  }

  static String getNativeLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      case 'ms':
        return 'Bahasa Melayu';
      default:
        return languageCode;
    }
  }

  static TextDirection getTextDirection(String languageCode) {
    return languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
  }
}
