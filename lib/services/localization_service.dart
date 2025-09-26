// lib/services/localization_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService {
  static const String _languageKey = 'app_language';

  static Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  static Future<String> getSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'en'; // Default to English
  }
}