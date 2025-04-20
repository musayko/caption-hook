import 'package:caption_hook/src/features/editor/caption_display_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:caption_hook/src/services/firestore_service.dart'; // Import providers
import 'package:caption_hook/src/features/upload/data/caption_job.dart'; // Import model
import 'package:intl/intl.dart'; // For date formatting (add intl package to pubspec.yaml)

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  // Helper to get just the filename
  String getBaseName(String? fullPath) {
     if (fullPath == null || fullPath.isEmpty) return 'Unknown Video';
     return fullPath.split('/').last.split('_').last; // Basic split based on our naming
  }


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsyncValue = ref.watch(userCaptionJobsProvider); // Watch the provider

    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing History'),
      ),
      body: jobsAsyncValue.when(
        // --- Data Loaded State ---
        data: (jobs) {
          if (jobs.isEmpty) {
            return const Center(child: Text("No history found."));
          }
          // Display jobs in a ListView
          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              // Use ListTile for a standard list appearance
              return ListTile(
                leading: Icon(
                  job.status == 'completed' ? Icons.check_circle_outline :
                  job.status == 'error' ? Icons.error_outline :
                  Icons.hourglass_empty_outlined, // processing/uploaded/initiating
                  color: job.status == 'completed' ? Colors.green :
                         job.status == 'error' ? Colors.red :
                         Colors.orange,
                ),
                title: Text(
                  // Try to extract a cleaner name from the path
                   getBaseName(job.originalVideoPath),
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  'Status: ${job.status} | ${DateFormat.yMd().add_jm().format(job.updatedAt.toDate())}', // Format date/time
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // Navigate to the display/editor screen when tapped
                  if (job.status == 'completed' || job.status == 'error') { // Allow viewing completed/error jobs
                     Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CaptionDisplayScreen(job: job),
                        ),
                      );
                  } else {
                     // Optional: Show snackbar or disable tap for processing jobs
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Job still processing...'))
                     );
                  }
                },
              );
            },
          );
        },
        // --- Error State ---
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Error loading history: $err", style: const TextStyle(color: Colors.red)),
          ),
        ),
        // --- Loading State ---
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}