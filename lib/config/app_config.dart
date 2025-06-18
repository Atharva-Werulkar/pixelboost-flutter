import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get supabaseBucketName =>
      dotenv.env['SUPABASE_BUCKET_NAME'] ?? '';
  static String get pixelcutApiKey => dotenv.env['PIXELCUT_API_KEY'] ?? '';

  static bool get isConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        supabaseBucketName.isNotEmpty &&
        pixelcutApiKey.isNotEmpty;
  }

  static void validateConfig() {
    if (!isConfigured) {
      throw Exception(
        'Configuration incomplete. Please check your .env file and ensure all required variables are set.',
      );
    }
  }
}
