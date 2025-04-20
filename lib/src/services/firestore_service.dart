// lib/src/services/firestore_service.dart

import 'package:caption_hook/src/features/auth/data/auth_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caption_hook/src/features/upload/data/caption_job.dart'; // Import model

// Provider for Firestore instance
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// Provider for this service (still potentially useful for other methods)
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(ref.watch(firestoreProvider));
});

// Provider to fetch the list of jobs for the current user
final userCaptionJobsProvider = FutureProvider.autoDispose<List<CaptionJob>>((ref) async {
  // Get current user ID (requires AuthRepository access)
  // Need to handle the case where user is not logged in
  final authRepository = ref.watch(authRepositoryProvider);
  final userId = authRepository.currentUser?.uid;

  if (userId == null) {
    // Or return []; or throw specific error
    throw Exception("User not logged in - cannot fetch history.");
  }

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserCaptionJobs(userId);
});

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService(this._db);

  // Keep collection reference accessible
  CollectionReference<Map<String, dynamic>> get jobsCollection =>
      _db.collection('transcriptionJobs'); // Use the correct collection name

  /// Creates a new job document and returns its ID.
  Future<String> createCaptionJob(String userId) async {
    final docRef = jobsCollection.doc(); // Auto-generate ID
    await docRef.set({
      'userId': userId,
      'originalVideoPath': null, // Will be updated after upload
      'status': 'initiating',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'transcript': null,
      'wordTimings': null,
      'errorMessage': null,
    });
    print("Firestore job document created with ID: ${docRef.id}");
    return docRef.id;
  }

   /// Fetches all caption jobs for a given user, ordered by creation date.
  Future<List<CaptionJob>> getUserCaptionJobs(String userId) async {
    try {
      final querySnapshot = await jobsCollection
          .where('userId', isEqualTo: userId) // Filter by user
          .orderBy('createdAt', descending: true) // Order newest first
          .get();

      final jobs = querySnapshot.docs
          .map((doc) => CaptionJob.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      print("Fetched ${jobs.length} jobs for user $userId");
      return jobs;
    } catch (e) {
      print("Error fetching user jobs: $e");
      // Rethrow or return empty list depending on how you want UI to handle errors
      rethrow;
    }
  }

  /// Updates the job document with the video path after upload.
  Future<void> updateJobWithVideoPath(String jobId, String videoPath) async {
    await jobsCollection.doc(jobId).update({
      'originalVideoPath': videoPath,
      'status': 'uploaded', // Mark as ready for function trigger
      'updatedAt': Timestamp.now(),
    });
     print("Firestore job ${jobId} updated with video path and status 'uploaded'.");
  }

  // captionJobStream method is no longer directly used by the simplified provider below,
  // but can be kept if needed elsewhere.
  // Stream<CaptionJob?> captionJobStream(String jobId) { ... }
} // End of FirestoreService class



// --- START: SIMPLIFIED StreamProvider ---
// StreamProvider to watch a specific caption job
// Use .family to pass the jobId
final captionJobStreamProvider =
    StreamProvider.autoDispose.family<CaptionJob?, String>((ref, jobId) {
  if (jobId.isEmpty) {
    // Return an empty stream if no job ID is provided yet
    print("[StreamProvider] Job ID is empty, returning null stream."); // Added log
    return Stream.value(null);
  }
  print("[StreamProvider] Listening to job ID: $jobId"); // Added log

  // Directly access Firestore instance and listen to the document
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('transcriptionJobs') // Ensure collection name matches
      .doc(jobId)
      .snapshots() // Listen to snapshots
      .map((snapshot) {
    print("[StreamProvider] Snapshot received for job $jobId. Exists: ${snapshot.exists}"); // Added log
    if (snapshot.exists && snapshot.data() != null) {
      try {
        // Parse data into our CaptionJob model
        // Explicit cast needed because snapshot.data() is Map<String, dynamic>?
        final job = CaptionJob.fromFirestore(snapshot as DocumentSnapshot<Map<String, dynamic>>);
        print("[StreamProvider] Parsed job data for $jobId. Status: ${job.status}"); // Added log
        return job;
      } catch (e, stackTrace) {
        print("[StreamProvider] Error parsing CaptionJob from Firestore snapshot for job $jobId: $e");
        print(stackTrace); // Log stack trace for parsing errors
        return null; // Return null on parsing error
      }
    }
    print("[StreamProvider] Snapshot for job $jobId does not exist or has no data."); // Added log
    return null; // Return null if document doesn't exist or has no data
  })
  // Optional: Add error handling for the stream itself
  .handleError((error, stackTrace) {
      print("[StreamProvider] Error in Firestore stream for job $jobId: $error");
      print(stackTrace);
      // Optionally return a specific error state or rethrow
  });
  
});
// --- END: SIMPLIFIED StreamProvider ---