import 'dart:io'; // Needed for File type later (though image_picker uses XFile)
import 'package:caption_hook/src/features/editor/caption_display_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart'; // Import image_picker
import 'package:video_player/video_player.dart'; // Import video_player for later use
import 'package:caption_hook/src/services/firestore_service.dart';
import 'package:caption_hook/src/features/upload/data/upload_repository.dart';
import 'package:caption_hook/src/features/auth/data/auth_providers.dart';
import 'package:caption_hook/src/features/auth/data/auth_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:caption_hook/src/features/history/presentation/history_screen.dart';



// --- State Class ---
@immutable
class VideoUploadState {
  const VideoUploadState({
    this.selectedVideo,
    this.isLoading = false, // For picking
    this.isValidating = false, // For validation
    this.isUploading = false, // <-- Add isUploading flag
    this.currentJobId,
    this.jobStatus,
    this.error,
  });

  final XFile? selectedVideo;
  final bool isLoading;
  final bool isValidating;
  final bool isUploading; // <-- Add isUploading flag
  final String? currentJobId;
  final String? jobStatus; // <-- Add jobStatus field
  final String? error;

  // Helper to get file name
  String? get selectedVideoName => selectedVideo?.name;

  // Determine overall busy state
  bool get isBusy => isLoading || isValidating || isUploading || jobStatus == 'processing'; 

  VideoUploadState copyWith({
    XFile? selectedVideo,
    bool? isLoading,
    bool? isValidating,
    bool? isUploading, // <-- Add isUploading flag
    String? currentJobId,
    String? jobStatus,
    String? error,
    bool clearError = false,
    bool clearVideo = false,
    bool clearJob = false,
  }) {
    return VideoUploadState(
      selectedVideo: clearVideo ? null : (selectedVideo ?? this.selectedVideo),
      isLoading: isLoading ?? this.isLoading,
      isValidating: isValidating ?? this.isValidating,
      isUploading: isUploading ?? this.isUploading,
      currentJobId: clearJob ? null : (currentJobId ?? this.currentJobId), // <-- ADD Job ID
      jobStatus: clearJob ? null : (jobStatus ?? this.jobStatus),       // <-- ADD Job Status
      error: clearError ? null : (error ?? this.error),
    );
  }
}


// --- Controller / State Notifier ---
class VideoUploadController extends StateNotifier<VideoUploadState> {
  // --- START CHANGE: Inject Dependencies ---
  final UploadRepository _uploadRepository;
  final AuthRepository _authRepository; // Inject AuthRepository to get user ID
  final FirestoreService _firestoreService;

  VideoUploadController(
    this._uploadRepository,
    this._authRepository,
    this._firestoreService) // Update constructor
      : super(const VideoUploadState());
  // --- END CHANGE ---

  final ImagePicker _picker = ImagePicker();
  static const int _maxSizeInBytes = 150 * 1024 * 1024;
  static const Duration _maxDuration = Duration(minutes: 2);

  // (Keep selectVideo method as it was)
   Future<void> selectVideo() async {
    state = state.copyWith(isLoading: true, clearError: true, clearVideo: true); // Reset state before picking
    XFile? video; // Declare video file here

    try {
      video = await _picker.pickVideo(source: ImageSource.gallery);

      if (video == null) {
        // User canceled the picker
        print('Video selection cancelled.');
        state = state.copyWith(isLoading: false); // Stop loading if cancelled
        return; // Exit if no video selected
      }

      // --- Start Validation ---
      state = state.copyWith(isLoading: false, isValidating: true); // Show validation progress
      print('Validating video: ${video.name}');

      // 1. Validate Format (MP4)
      final String fileName = video.name.toLowerCase();
      if (!fileName.endsWith('.mp4')) {
         throw Exception('Invalid format. Please select an MP4 video.');
      }
      print('Format validation passed.');

      // 2. Validate Size (Max 150MB)
      final int fileSize = await video.length(); // Get file size in bytes
      if (fileSize > _maxSizeInBytes) {
        final double sizeInMB = fileSize / (1024 * 1024);
        throw Exception('File too large (${sizeInMB.toStringAsFixed(1)} MB). Maximum size is 150 MB.');
      }
      print('Size validation passed (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB).');

      // 3. Validate Duration (Max 2 minutes) - Requires video_player
      VideoPlayerController? videoController; // Declare controller here
      try {
        videoController = VideoPlayerController.file(File(video.path));
        await videoController.initialize(); // Initialize to get metadata
        final Duration videoDuration = videoController.value.duration;

        if (videoDuration > _maxDuration) {
          throw Exception('Video too long (${_formatDuration(videoDuration)}). Maximum duration is 2 minutes.');
        }
         print('Duration validation passed (${_formatDuration(videoDuration)}).');
      } finally {
          // IMPORTANT: Dispose the controller to release resources
          await videoController?.dispose();
          print('VideoPlayerController disposed.');
      }
      // --- End Validation ---

      // If all validations pass, update state with the selected video
      print('Video validation successful: ${video.name}');
      state = state.copyWith(selectedVideo: video, isValidating: false);

    } catch (e) {
      // Handle errors during picking or validation
      print('Error selecting/validating video: $e');
      state = state.copyWith(
        isLoading: false,
        isValidating: false,
        error: e is Exception ? e.toString() : 'An unexpected error occurred.', // Show specific error message
        clearVideo: true // Clear video selection on error
      );
    }
  }

  // --- START CHANGE: Add Upload Method ---
  Future<void> startCaptionGenerationProcess() async {
    if (state.selectedVideo == null) {
      state = state.copyWith(error: "No video selected.", clearError: false);
      return;
    }
    if (state.isBusy) return; // Prevent multiple uploads

    final user = _authRepository.currentUser; // Get current user
    if (user == null) {
       state = state.copyWith(error: "User not logged in.", clearError: false);
       return;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearJob: true);
    String jobId = '';
    String storagePath = ''; // To store the path

try {
      // 1. Create Firestore Job Document
      jobId = await _firestoreService.createCaptionJob(user!.uid); // Use user!.uid safely now
      state = state.copyWith(currentJobId: jobId, jobStatus: 'initiating', isLoading: false, isUploading: true); // Update state

      // 2. Upload Video and get Storage Path
      storagePath = await _uploadRepository.uploadVideo( // <-- Assign returned path
        state.selectedVideo!,
        user.uid,
      );
      print("Upload complete. Storage Path: $storagePath");

      // 3. Update Job with FULL Storage Path and set status to 'uploaded'
      await _firestoreService.updateJobWithVideoPath(jobId, storagePath); // <-- Pass storagePath
      state = state.copyWith(isUploading: false, jobStatus: 'uploaded');

      print("Job $jobId updated with storage path. Waiting for Cloud Function...");

    } catch (e) { // Combined error handling
      print('Error initiating job or uploading video: $e');
      state = state.copyWith(
        isLoading: false, isUploading: false,
        error: e is FirebaseException ? e.message : e.toString(),
      );
    }
    // --- END CHANGES ---
  }

// Helper to format duration for messages
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
  // Clear video selection
  void clearSelection() {
     state = const VideoUploadState(); // Reset state
  }
}  

// --- Provider ---
final videoUploadControllerProvider = StateNotifierProvider.autoDispose<
    VideoUploadController, VideoUploadState>((ref) {
  return VideoUploadController(
    ref.watch(uploadRepositoryProvider),
    ref.watch(authRepositoryProvider),
    ref.watch(firestoreServiceProvider), // <-- ADD Firestore Service Provider
  );
});


// --- UI Widget ---
// Changed back to ConsumerWidget as no internal state needed for now
class VideoUploadScreen extends ConsumerWidget {
  const VideoUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final uploadState = ref.watch(videoUploadControllerProvider);
    final uploadController = ref.read(videoUploadControllerProvider.notifier);

    // --- ADD: Watch the specific job stream ---
    // Use the jobId stored in the uploadState to watch the stream
    final jobStream = ref.watch(captionJobStreamProvider(uploadState.currentJobId ?? ''));
    // --- END ADD ---

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
        actions: [IconButton(
          icon: const Icon(Icons.history),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const HistoryScreen(),
              ),
            );
          },
        )],
        // TODO: Add Logout button here later
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // --- Limitation Info ---
              Text(
                'Video Limitations:',
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text('Max Size: 150MB', style: textTheme.labelSmall, textAlign: TextAlign.center),
              Text('Max Duration: 2 minutes', style: textTheme.labelSmall, textAlign: TextAlign.center),
              Text('Supported Format: MP4', style: textTheme.labelSmall, textAlign: TextAlign.center),
              const SizedBox(height: 30),

              // --- Error Message ---
              if (uploadState.error != null || (jobStream.hasError && !jobStream.isLoading)) ...[
                Text(
                  uploadState.error ?? "Error processing job: ${jobStream.error}", // Show relevant error
                  style: textTheme.labelSmall?.copyWith(color: colorScheme.error),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
              ],

              // --- Select Video Button ---
              ElevatedButton.icon(
              icon: uploadState.isLoading || uploadState.isValidating // only show picking/validating progress
                  ? const SizedBox(/*...spinner...*/)
                  : const Icon(Icons.video_library_outlined),
              onPressed: uploadState.isBusy ? null : () => uploadController.selectVideo(),
              label: const Text('SELECT VIDEO'),
            ),
            const SizedBox(height: 20),

              // --- Selected Video Info ---
              // Show Job status if a job is active
              if (uploadState.currentJobId != null) ...[
                jobStream.when(
                  data: (job) {
                    // --- ADD LOGGING ---
                    print("Job Stream Update Received. Job ID: ${job?.id}, Status: ${job?.status}");
                    // --- END LOGGING ---

                    String statusText = 'Job Status: ${job?.status ?? 'loading...'}';
                    if (job?.status == 'completed') {
                        // --- ADD LOGGING ---
                        print("Job status is 'completed'. Attempting navigation...");
                        // --- END LOGGING ---

                        statusText = 'Processing Complete!';
                        Future.microtask(() {
                          print("Executing microtask for navigation..."); // Log microtask
                          ref.read(videoUploadControllerProvider.notifier).clearSelection();

                          if (context.mounted && job != null) {
                              print("Context is mounted, navigating to CaptionDisplayScreen..."); // Log navigation
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CaptionDisplayScreen(job: job),
                                ),
                              );
                          } else {
                              print("Navigation skipped: context mounted=${context.mounted}, job is null=${job == null}"); // Log if skipped
                          }
                        });

                         // --- END NAVIGATION ---
                     } else if (job?.status == 'error') {
                         statusText = 'Processing Failed: ${job?.errorMessage ?? 'Unknown error'}';
                     }
                     return Padding(
                       padding: const EdgeInsets.symmetric(vertical: 8.0),
                       child: Column(
                         children: [
                           if(job?.status == 'processing' || job?.status == 'uploaded')
                             const CircularProgressIndicator(),
                           const SizedBox(height: 8),
                           Text(statusText, style: textTheme.bodyMedium),
                         ],
                       ),
                     );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(children: [CircularProgressIndicator(), SizedBox(height: 8),Text("Loading job status...")])
                  ),
                  error: (err, stack) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text("Error loading job: $err", style: textTheme.bodyMedium?.copyWith(color: colorScheme.error)),
                  ),
                ),
             ] else ...[
                // Show selected video name if no job is active
                Text(
                  uploadState.selectedVideoName ?? 'No video selected yet',
                  // ... (rest of text style) ...
                ),
             ],


            const SizedBox(height: 30),

              // --- Generate Captions Button ---
              ElevatedButton.icon(
                icon: uploadState.isUploading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.closed_caption),
                label: const Text('GENERATE CAPTIONS'),
                onPressed: (uploadState.selectedVideo == null || uploadState.isBusy)
                    ? null
                    : () => uploadController.startCaptionGenerationProcess(),
              ),

              // --- Clear Selection Button ---
              if (uploadState.selectedVideo != null && !uploadState.isBusy && uploadState.currentJobId == null) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => uploadController.clearSelection(),
                  child: Text(
                    'Clear Selection',
                    style: textTheme.labelSmall?.copyWith(color: colorScheme.error),
                  ),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}