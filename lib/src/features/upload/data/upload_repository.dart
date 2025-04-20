import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart'; // To reference XFile type
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Custom exception for upload errors
class UploadException implements Exception {
  final String message;
  UploadException(this.message);

  @override
  String toString() => message;
}

class UploadRepository {
  final FirebaseStorage _firebaseStorage;

  UploadRepository(this._firebaseStorage);

  /// Uploads the video file to Firebase Storage and returns the download URL.
  Future<String> uploadVideo(XFile videoFile, String userId) async {
    try {
      final String originalFileName = videoFile.name;
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      // This is the path we need to return and save
      final String storagePath = 'videos/$userId/${timestamp}_$originalFileName';
      final Reference storageRef = _firebaseStorage.ref().child(storagePath);
      final File fileToUpload = File(videoFile.path);

      print('Starting upload to: $storagePath');
      final UploadTask uploadTask = storageRef.putFile(fileToUpload);
      await uploadTask.whenComplete(() => {});
      print('Upload successful for path: $storagePath');

      // Don't need downloadUrl here, return the storage path instead
      return storagePath; // 

    } on FirebaseException catch (e) {
      // Handle Firebase specific errors
      print('Firebase Storage Error: ${e.code} - ${e.message}');
      throw UploadException('Failed to upload video: ${e.message}');
    } catch (e) {
      // Handle other errors
      print('Unexpected Upload Error: $e');
      throw UploadException('An unexpected error occurred during upload.');
    }
  }
  Future<String> getDownloadUrl(String storagePath) async {
    try {
      // Now _firebaseStorage is accessible because this is a class method
      final ref = _firebaseStorage.ref().child(storagePath);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      print("Error getting download URL for $storagePath: $e");
      // Rethrow as our custom exception or keep original? Let's keep original for now.
      // Consider wrapping in UploadException if specific handling is needed later.
      rethrow; // Rethrow to be handled by the caller
    }
  }
}

// --- Provider ---
// (Often placed in a separate providers.dart file, but okay here for simplicity)

// Provides the FirebaseStorage instance
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

// Provides the UploadRepository instance
final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return UploadRepository(ref.watch(firebaseStorageProvider));
});