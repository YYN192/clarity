import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class Localizer {
  static final Map<String, Map<String, String>> _localizedValues = {};
  
  static const Map<String, String> _languageMap = {
    'English': 'en',
    'Spanish': 'es',
    'Bulgarian': 'bg',
    'French': 'fr',
    'German': 'de',
    'Afrikaans': 'af',
    'Arabic': 'ar',
    'Catalan': 'ca',
    'Czech': 'cs',
    'Danish': 'da',
    'Greek': 'el',
    'Finnish': 'fi',
    'Hebrew': 'he',
    'Hungarian': 'hu',
    'Italian': 'it',
    'Japanese': 'ja',
    'Korean': 'ko',
    'Dutch': 'nl',
    'Norwegian': 'no',
    'Polish': 'pl',
    'Portuguese': 'pt',
    'Romanian': 'ro',
    'Russian': 'ru',
    'Serbian': 'sr',
    'Swedish': 'sv',
    'Turkish': 'tr',
    'Ukrainian': 'uk',
    'Vietnamese': 'vi',
    'Chinese': 'zh',
  };

  /// Preloads all available translations from ARB files
  static Future<void> init() async {
    for (var entry in _languageMap.entries) {
      try {
        final String response = await rootBundle.loadString('lib/l10n/app_${entry.value}.arb');
        final data = await json.decode(response);
        
        Map<String, String> values = {};
        data.forEach((key, value) {
          if (!key.startsWith('@')) {
            values[key] = value.toString();
          }
        });
        
        _localizedValues[entry.key] = values;
      } catch (e) {
        // Skip missing files or errors
        debugPrint('Warning: Could not load translations for ${entry.key}: $e');
      }
    }
  }

  static String localize(String key, String language) {
    return _localizedValues[language]?[key] ?? _localizedValues['English']?[key] ?? key;
  }

  static String getLocaleCode(String language) {
    return _languageMap[language] ?? 'en';
  }
}
