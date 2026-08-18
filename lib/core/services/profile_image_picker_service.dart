import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ProfileImagePickerService {
  static final ImagePicker _picker = ImagePicker();
  static GoTrueClient get _auth => Supabase.instance.client.auth;
  static SupabaseClient get _db => Supabase.instance.client;

  /// Pick an image from camera or gallery and update the profile photo in
  /// Postgres (profiles.profile_picture_url — shared across customer/rider/
  /// admin, unlike the old per-role Firestore collections) and Supabase Auth.
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

      // 1. Update the shared profiles row (customer/rider/admin all read this)
      await _db.from('profiles').update({'profile_picture_url': photoUrl}).eq('id', uid);

      // 2. Update Supabase Auth user profile photo if current logged in user
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
