import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ProfileImagePickerService {
  static final ImagePicker _picker = ImagePicker();
  static GoTrueClient get _auth => Supabase.instance.client.auth;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Pick an image from camera or gallery and update profile photo in Firestore and Supabase Auth.
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

      final batch = _db.batch();

      // 1. Update users collection
      final userRef = _db.collection('users').doc(uid);
      batch.set(
        userRef,
        {
          'photoUrl': photoUrl,
          'profilePhotoUrl': photoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 2. Update customers collection
      final custRef = _db.collection('customers').doc(uid);
      batch.set(
        custRef,
        {
          'photoUrl': photoUrl,
          'profilePhotoUrl': photoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 3. Update riders collection
      final riderRef = _db.collection('riders').doc(uid);
      batch.set(
        riderRef,
        {
          'photoUrl': photoUrl,
          'profilePhotoUrl': photoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      // 4. Update Supabase Auth user profile photo if current logged in user
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
