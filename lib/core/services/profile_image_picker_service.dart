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

      // Update profile picture in database
      await _db.from('profiles').update({'profile_picture_url': photoUrl}).eq('id', uid);

      // Update user metadata if editing current user
      if (uid == _auth.currentUser?.id) {
        try {
          await _auth.updateUser(UserAttributes(data: {'avatar_url': photoUrl}));
        } catch (_) {}
      }

      return photoUrl;
    } catch (e) {
      debugPrint('Profile image upload error: $e');
      rethrow;
    }
  }
}
