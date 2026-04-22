import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_logger.dart';

/// Service for uploading and managing food images in Firebase Storage.
/// Abstracts Firebase Storage and Auth operations for better testability.
class ImageUploadService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current authenticated user
  static User? get currentUser => _auth.currentUser;

  /// Get current user ID or null if not authenticated
  static String? get currentUserId => _auth.currentUser?.uid;

  /// Check if user is authenticated
  static bool get isAuthenticated => _auth.currentUser != null;

  /// Upload a food image to Firebase Storage and return the download URL.
  /// 
  /// [file] - The image file to upload
  /// [requestId] - Unique request ID for the image (used as filename)
  /// 
  /// Returns the download URL of the uploaded image.
  /// Throws an exception if user is not authenticated or upload fails.
  static Future<String> uploadFoodImage(File file, String requestId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final imagePath = 'food_images/${user.uid}/$requestId.jpg';
      final imageRef = _storage.ref().child(imagePath);

      // Upload file
      await imageRef.putFile(file);

      // Get and return download URL
      final downloadUrl = await imageRef.getDownloadURL();
      AppLogger.log('Food image uploaded: $imagePath', tag: 'ImageUpload');
      return downloadUrl;
    } catch (e) {
      AppLogger.error('Failed to upload food image', error: e, tag: 'ImageUpload');
      throw Exception('Upload failed: $e');
    }
  }

  /// Delete an uploaded food image from Firebase Storage.
  /// 
  /// [requestId] - The request ID used when uploading the image
  /// 
  /// Silently fails if image doesn't exist or user is not authenticated.
  static Future<void> deleteFoodImage(String requestId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final imagePath = 'food_images/${user.uid}/$requestId.jpg';
      await _storage.ref().child(imagePath).delete();
      AppLogger.log('Food image deleted: $imagePath', tag: 'ImageUpload');
    } catch (e) {
      // Silently ignore deletion errors (image may not exist)
      AppLogger.warning('Could not delete food image: $e', tag: 'ImageUpload');
    }
  }

  /// Get the storage path for a food image.
  /// Useful for checking if an image exists or for cleanup operations.
  static String getFoodImagePath(String userId, String requestId) {
    return 'food_images/$userId/$requestId.jpg';
  }
}
