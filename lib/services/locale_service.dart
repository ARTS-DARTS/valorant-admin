import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService {
  static const _key = 'app_locale';
  static final ValueNotifier<Locale?> localeNotifier = ValueNotifier(null);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null) {
      localeNotifier.value = Locale(code);
    }
  }

  static Future<void> setLocale(String languageCode) async {
    localeNotifier.value = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, languageCode);
  }

  static Future<void> clearLocale() async {
    localeNotifier.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static String get currentCode {
    if (localeNotifier.value != null) return localeNotifier.value!.languageCode;
    // Нет явно выбранного языка — берём локаль устройства если она поддерживается
    final deviceCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final supported = supportedLanguages.map((l) => l['code']!).toSet();
    return supported.contains(deviceCode) ? deviceCode : 'en';
  }

  static const List<Map<String, String>> supportedLanguages = [
    {'code': 'en', 'flag': '🇬🇧', 'name': 'English'},
    {'code': 'ru', 'flag': '🇷🇺', 'name': 'Русский'},
    {'code': 'tr', 'flag': '🇹🇷', 'name': 'Türkçe'},
    {'code': 'es', 'flag': '🇪🇸', 'name': 'Español'},
    {'code': 'pt', 'flag': '🇧🇷', 'name': 'Português'},
    {'code': 'ar', 'flag': '🇸🇦', 'name': 'العربية'},
    {'code': 'ko', 'flag': '🇰🇷', 'name': '한국어'},
    {'code': 'ja', 'flag': '🇯🇵', 'name': '日本語'},
  ];
}
