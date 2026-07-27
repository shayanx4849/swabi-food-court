import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Uploads images to Cloudinary using an UNSIGNED upload preset, so no
/// API secret ever needs to be embedded in the app. Cloudinary's free
/// tier requires no card and is generous enough for a pilot-scale app
/// (25 GB storage / 25 GB bandwidth per month at time of writing).
///
/// Setup required before this works:
///   1. Create a free account at https://cloudinary.com
///   2. Copy your "Cloud name" from the dashboard into [cloudName] below.
///   3. Settings -> Upload -> Add upload preset -> set Signing Mode to
///      "Unsigned" -> copy its name into [uploadPreset] below.
class CloudinaryService {
  // TODO: replace with your own values from the Cloudinary dashboard.
  static const String cloudName = 'YOUR_CLOUD_NAME';
  static const String uploadPreset = 'YOUR_UNSIGNED_UPLOAD_PRESET';

  /// Uploads a single image file and returns its public HTTPS URL,
  /// or null if the upload failed. Prints the exact failure reason to the
  /// debug console so misconfiguration (wrong cloud name, wrong preset,
  /// preset not set to Unsigned, etc.) is easy to diagnose.
  Future<String?> uploadImage(File imageFile) async {
    final url =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    // ignore: avoid_print
    print('[Cloudinary] Uploading to $url with preset "$uploadPreset"');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      // ignore: avoid_print
      print('[Cloudinary] Upload FAILED — status ${response.statusCode}: $body');
      // Common causes visible in the printed body:
      //  - "Invalid cloud_name" -> cloudName is wrong
      //  - "Upload preset not found" -> uploadPreset name is wrong/deleted
      //  - "Upload preset must be whitelisted for unsigned uploads" ->
      //    the preset's Signing Mode is not set to "Unsigned"
      return null;
    }

    // ignore: avoid_print
    print('[Cloudinary] Upload succeeded: $body');

    final data = jsonDecode(body) as Map<String, dynamic>;
    return data['secure_url'] as String?;
  }
}
