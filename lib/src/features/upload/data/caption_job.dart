import 'package:cloud_firestore/cloud_firestore.dart';


// Represents the structure of word timing data
class WordTiming {
  final String word;
  final double startTimeSec;
  final double endTimeSec;

  WordTiming({
    required this.word,
    required this.startTimeSec,
    required this.endTimeSec,
  });

  factory WordTiming.fromMap(Map<String, dynamic> map) {
    return WordTiming(
      word: map['word'] ?? '',
      // Ensure correct type casting from Firestore numbers
      startTimeSec: (map['startTimeSec'] as num?)?.toDouble() ?? 0.0,
      endTimeSec: (map['endTimeSec'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // Optional: Add toMap if needed later
  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'startTimeSec': startTimeSec,
      'endTimeSec': endTimeSec,
    };
  }
}

// Represents the overall caption job document in Firestore
class CaptionJob {
  final String id; // Firestore document ID
  final String userId;
  final String? originalVideoPath;
  final String status; // 'initiating', 'uploaded', 'processing', 'completed', 'error'
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String? transcript;
  final List<WordTiming>? wordTimings; // Use the WordTiming class
  final String? errorMessage;

  CaptionJob({
    required this.id,
    required this.userId,
    this.originalVideoPath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.transcript,
    this.wordTimings,
    this.errorMessage,
  });

  factory CaptionJob.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    // Parse wordTimings list
    final List<WordTiming>? timings = data['wordTimings'] != null
        ? List<Map<String, dynamic>>.from(data['wordTimings'])
            .map((map) => WordTiming.fromMap(map))
            .toList()
        : null;

    return CaptionJob(
      id: doc.id,
      userId: data['userId'] ?? '',
      originalVideoPath: data['originalVideoPath'],
      status: data['status'] ?? 'unknown',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      transcript: data['transcript'],
      wordTimings: timings,
      errorMessage: data['errorMessage'],
    );
  }
}