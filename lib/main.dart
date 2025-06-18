import 'dart:developer';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Validate configuration
  AppConfig.validateConfig();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PixelBoost Pro',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          secondary: Color(0xFF74B9FF),
          surface: Color(0xFF2D3436),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFFDDD6FE),
        ),
        scaffoldBackgroundColor: const Color(0xFF1E2124),
        cardTheme: const CardThemeData(
          color: Color(0xFF2D3436),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
      ),
      home: const ImageUpscalerPage(title: 'PixelBoost Pro'),
    );
  }
}

class ImageUpscalerPage extends StatefulWidget {
  const ImageUpscalerPage({super.key, required this.title});

  final String title;

  @override
  State<ImageUpscalerPage> createState() => _ImageUpscalerPageState();
}

class _ImageUpscalerPageState extends State<ImageUpscalerPage> {
  File? _image;
  String? _upscaledImageUrl;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    log('Starting image pick');
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      log('Image picked: ${pickedFile.path}');
      setState(() {
        _image = File(pickedFile.path);
        _upscaledImageUrl = null;
      });
    } else {
      log('No image selected');
    }
  }

  Future<void> _upscaleImage() async {
    if (_image == null) {
      log('No image to upscale');
      return;
    }

    log('Starting image upload to Supabase');
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the selected image path for upload
      final imagePath = _image!.path;
      final fileName =
          imagePath.split('/').last; // Upload the image to Supabase
      final bucketName = AppConfig.supabaseBucketName;
      try {
        await Supabase.instance.client.storage
            .from(bucketName)
            .upload(fileName, _image!);
      } on Exception catch (e) {
        log('Error during upload: $e');
      }

      // Get the public URL of the uploaded image
      final publicUrl = Supabase.instance.client.storage
          .from(bucketName)
          .getPublicUrl(fileName);

      log('Image uploaded to Supabase. Public URL: $publicUrl');

      // Prepare the request data with the public URL
      final data = {
        "image_url": publicUrl,
        "scale": 2 // Adjust the scale as needed
      }; // Configure Dio for the request
      final dio = Dio();
      final apiKey = AppConfig.pixelcutApiKey;
      log('Sending upscale request');
      final response = await dio.post(
        'https://api.developer.pixelcut.ai/v1/upscale',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-API-KEY': apiKey
          },
        ),
        data: jsonEncode(data), // Ensure data is encoded as JSON
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        log('Upscale successful. URL: ${jsonData['result_url']}');
        setState(() {
          _upscaledImageUrl = jsonData['result_url'];
          _isLoading = false;
        });
      } else {
        log('Upscale failed with status code: ${response.statusCode}');
        throw Exception('Failed to upscale image');
      }
    } catch (e) {
      log('Error during upscale: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _downloadImage() async {
    if (_upscaledImageUrl == null) {
      log('No upscaled image URL to download');
      return;
    }

    log('Starting image download');
    try {
      var response = await http.get(Uri.parse(_upscaledImageUrl!));
      if (response.statusCode == 200) {
        final directory = await getDownloadsDirectory();
        if (directory == null) {
          throw Exception('Unable to access download directory');
        }
        final filePath = '${directory.path}/upscaled_image.png';
        File(filePath).writeAsBytesSync(response.bodyBytes);
        log('Image downloaded to: $filePath');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image downloaded to: $filePath')),
        );
      } else {
        log('Download failed with status code: ${response.statusCode}');
        throw Exception('Failed to download image');
      }
    } catch (e) {
      log('Error during download: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2124),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              const SizedBox(height: 20),
              Text(
                'PixelBoost',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: const Color(0xFF6C5CE7),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'AI-Powered Image Enhancement',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF74B9FF),
                      letterSpacing: 0.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Image Display Area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D3436),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF636E72).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: _buildImageDisplay(),
                ),
              ),

              const SizedBox(height: 30),

              // Action Buttons
              _buildActionButtons(context),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageDisplay() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Enhancing your image...',
              style: TextStyle(
                color: Color(0xFF74B9FF),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_upscaledImageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Image.network(
              _upscaledImageUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B894),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Enhanced',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_image != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Image.file(
              _image!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF636E72),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Original',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: Color(0xFF6C5CE7),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Select an image to enhance',
            style: TextStyle(
              color: Color(0xFF636E72),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the button below to get started',
            style: TextStyle(
              color: Color(0xFF636E72),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Select/Enhance Row
        Row(
          children: [
            Expanded(
              child: _buildModernButton(
                onPressed: _pickImage,
                icon: Icons.photo_library_outlined,
                label: 'Select Image',
                color: const Color(0xFF74B9FF),
                enabled: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildModernButton(
                onPressed: _image != null && !_isLoading ? _upscaleImage : null,
                icon: Icons.auto_fix_high,
                label: 'Enhance',
                color: const Color(0xFF6C5CE7),
                enabled: _image != null && !_isLoading,
              ),
            ),
          ],
        ),

        // Download Button (only show when upscaled image is available)
        if (_upscaledImageUrl != null) ...[
          const SizedBox(height: 16),
          _buildModernButton(
            onPressed: _downloadImage,
            icon: Icons.download_outlined,
            label: 'Download Enhanced Image',
            color: const Color(0xFF00B894),
            enabled: true,
            fullWidth: true,
          ),
        ],
      ],
    );
  }

  Widget _buildModernButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    bool fullWidth = false,
  }) {
    return SizedBox(
      height: 56,
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? color : const Color(0xFF636E72).withOpacity(0.3),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
