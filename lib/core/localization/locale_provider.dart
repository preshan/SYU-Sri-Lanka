import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const supportedLanguageCodes = {'en', 'si', 'ta'};

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _loadLocale();
  }

  static const _key = 'app_locale';

  static Locale _sanitize(String? code) {
    if (code != null && supportedLanguageCodes.contains(code)) {
      return Locale(code);
    }
    return const Locale('en');
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    state = _sanitize(prefs.getString(_key));
  }

  Future<void> setLocale(Locale locale) async {
    final next = _sanitize(locale.languageCode);
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, next.languageCode);
  }
}
