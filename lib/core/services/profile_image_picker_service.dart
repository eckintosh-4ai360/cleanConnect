import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ProfileImagePickerService {
  static final ImagePicker _picker = ImagePicker();
  static GoTrueClient get _auth => Supabase.instance.client.auth;
  static SupabaseClient get _db => Supabase.instance.client;

  // Picks image from camera/gallery and saves to profile in Supabase
  static Future<String?> pickAndUploadProfileImage({
    required ImageSource source,
    String? customUid,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile == null) return null;

      final bytes = await pickedFile.readAsBytes();
      final base64String = base64Encode(bytes);
      final photoUrl = 'data:image/jpeg;base64,$base64String';

      final uid = customUid ?? _auth.currentUser?.id;
      if (uid == null || uid.isEmpty) return photoUrl;

      // Update profile picture in database. profiles.profile_picture_url is the
      // only home for the picture.
      //
      // It used to be copied into the auth user's metadata as 'avatar_url' as
      // well, which quietly broke the account. Supabase embeds user_metadata in
      // every access token, so a base64 photo — a few hundred bytes of JPEG
      // become tens of kilobytes once base64'd and wrapped in a JWT — pushed the
      // Authorization header past the ~16KB the API gateway accepts. Every
      // request the app made after that was rejected by the proxy with a bare
      // HTML "400 Bad Request" before it reached Postgres or any edge function,
      // which is what stopped Paystack checkout from ever starting. Readers take
      // the picture from the profiles row instead.
      await _db.from('profiles').update({'profile_picture_url': photoUrl}).eq('id', uid);

      return photoUrl;
    } catch (e) {
      debugPrint('Profile image upload error: $e');
      rethrow;
    }
  }
}
