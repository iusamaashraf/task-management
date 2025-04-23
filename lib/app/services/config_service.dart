import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static Future<void> init() async {
    await dotenv.load(fileName: ".env");
  }
}
