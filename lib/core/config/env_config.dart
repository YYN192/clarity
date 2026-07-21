import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  final String openWeatherApiKey;

  /// OAuth "Web application" client ID from Google Cloud / Firebase. Needed on
  /// Android so Google Sign-In returns an idToken Firebase can consume. Leave
  /// empty on iOS/web. Public value (not a secret), but kept in .env for tidiness.
  final String googleServerClientId;

  EnvConfig({
    required this.openWeatherApiKey,
    this.googleServerClientId = '',
  });

  static Future<EnvConfig> load() async {
    await dotenv.load(fileName: "assets/.env");
    return EnvConfig(
      openWeatherApiKey: dotenv.get('OPENWEATHER_API_KEY', fallback: ''),
      googleServerClientId: dotenv.get('GOOGLE_SERVER_CLIENT_ID', fallback: ''),
    );
  }
}
