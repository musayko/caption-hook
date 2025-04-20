import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import {StorageEvent} from "firebase-functions/v2/storage";
import {Storage} from "@google-cloud/storage";
import {SpeechClient, protos} from "@google-cloud/speech";
import * as path from "path";
import * as os from "os";
import * as fs from "fs";
import ffmpeg from "fluent-ffmpeg";
import ffmpegStatic from "ffmpeg-static";
import {Timestamp} from "firebase-admin/firestore";


// Initialize Firebase Admin SDK
admin.initializeApp();

// Initialize Google Cloud clients
const speechClient = new SpeechClient();
const storageClient = new Storage();
const firestore = admin.firestore();


// Set FFmpeg path
if (ffmpegStatic) {
  ffmpeg.setFfmpegPath(ffmpegStatic);
  console.log("FFmpeg path set to:", ffmpegStatic);
} else {
  console.error("ffmpeg-static not found! FFmpeg processing might fail.");
}

/**
 * Converts a Protocol Buffer Duration to seconds.
 * @param {protos.google.protobuf
 * .IDuration | null | undefined} duration The duration object.
 * @return {number} The duration in seconds as a float, or 0 if input is null.
 */
function durationToSeconds(
  duration: protos.google.protobuf.IDuration | null | undefined
): number {
  if (!duration) return 0;
  const seconds = duration.seconds ? Number(duration.seconds) : 0;
  const nanos = duration.nanos ? duration.nanos / 1e9 : 0;
  return seconds + nanos;
}

export const onVideoUpload = functions.storage.onObjectFinalized(
  {
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (event: StorageEvent) => {
    const fileMetadata = event.data;
    const filePath = fileMetadata.name;
    const contentType = fileMetadata.contentType;
    const bucketName = fileMetadata.bucket;
    const userId = filePath?.split("/")[1];

    console.log(`New file detected: gs://${bucketName}/${filePath}`);
    console.log(`Content Type: ${contentType}`);

    if (!filePath) {
      console.log("File path is undefined. Exiting function.");
      return;
    }

    if (
      !filePath.startsWith("videos/") ||
      !contentType?.startsWith("video/")
    ) {
      console.log(
        `File ${filePath} is not a video in the 'videos/' folder or ` +
        `content type (${contentType}) is not video. Ignoring.`
      );
      return;
    }

    if (!userId) {
      console.error("Could not extract userId from path.");
      return;
    }

    console.log(`User ID extracted: ${userId}`);
    console.log(`Processing video file: ${filePath}`);

    let jobDocRef: admin.firestore.DocumentReference | null = null;

    try {
      const jobQuery = firestore
        .collection("transcriptionJobs")
        .where("originalVideoPath", "==", filePath)
        .where("userId", "==", userId)
        .where("status", "==", "uploaded")
        .limit(1);

      const querySnapshot = await jobQuery.get();

      if (querySnapshot.empty) {
        console.log(
          "No matching job found in Firestore for path " + filePath + " " +
          "with status \"uploaded\"."
        );
        return;
      }

      jobDocRef = querySnapshot.docs[0].ref;
      console.log(`Found matching Firestore job document: ${jobDocRef.path}`);

      await jobDocRef.update({
        status: "processing",
        updatedAt: Timestamp.now(),
      });

      console.log(`Job ${jobDocRef.id} status updated to 'processing'.`);
    } catch (error) {
      console.error(
        "Error finding/updating initial job status in Firestore:",
        error
      );
      return;
    }

    const bucket = storageClient.bucket(bucketName);
    const remoteVideoFile = bucket.file(filePath);

    const uniquePrefix = `${Date.now()}_${userId}`;
    const baseFileName = path.basename(filePath);
    const tempVideoPath = path.join(
      os.tmpdir(),
      `${uniquePrefix}_${baseFileName}`
    );
    const tempAudioFileName = `${uniquePrefix}_${baseFileName.replace(
      path.extname(baseFileName),
      ".wav"
    )}`;
    const tempAudioPath = path.join(os.tmpdir(), tempAudioFileName);
    const targetSampleRate = 16000;
    const audioStoragePath = `extracted_audio/${userId}/${tempAudioFileName}`;

    try {
      console.log(`Downloading video to: ${tempVideoPath}`);
      await remoteVideoFile.download({destination: tempVideoPath});
      console.log("Video downloaded successfully.");

      console.log(`Extracting audio to: ${tempAudioPath}`);
      await new Promise<void>((resolve, reject) => {
        ffmpeg(tempVideoPath)
          .noVideo()
          .audioCodec("pcm_s16le")
          .audioFrequency(targetSampleRate)
          .audioChannels(1)
          .output(tempAudioPath)
          .on("end", () => {
            console.log("FFmpeg ok.");
            resolve();
          })
          .on("error", (err: Error) => {
            reject(err);
          })
          .run();
      });
      console.log("Audio extracted successfully.");

      console.log(`Uploading extracted audio to: ${audioStoragePath}`);
      const [uploadedAudioFile] = await bucket.upload(tempAudioPath, {
        destination: audioStoragePath,
        metadata: {contentType: "audio/wav"},
      });
      const gcsAudioUri = `gs://${bucketName}/${audioStoragePath}`;
      console.log("Audio uploaded successfully:", gcsAudioUri);

      const config: protos.google.cloud.speech.v1.IRecognitionConfig = {
        encoding: "LINEAR16",
        sampleRateHertz: targetSampleRate,
        languageCode: "en-US",
        enableWordTimeOffsets: true,
        enableAutomaticPunctuation: true,
        model: "video",
      };

      const audio: protos.google.cloud.speech.v1.IRecognitionAudio = {
        uri: gcsAudioUri,
      };

      const request: protos.google.cloud.speech.v1.
      ILongRunningRecognizeRequest =
        {
          config,
          audio,
        };

      console.log("[Speech API] Sending request...");
      const [operation] = await speechClient.longRunningRecognize(request);
      console.log("[Speech API] Waiting for operation...");
      const [response] = await operation.promise();
      console.log("[Speech API] Operation finished.");

      if (response.results && response.results.length > 0) {
        const transcription = response.results
          .map((r) => r.alternatives?.[0]?.transcript ?? "")
          .join("\n");

        const wordTimings = response.results
          .flatMap((r) => r.alternatives?.[0]?.words ?? [])
          .map((w) => ({
            word: w.word ?? "",
            startTimeSec: durationToSeconds(w.startTime),
            endTimeSec: durationToSeconds(w.endTime),
          }));

        console.log(
          `Transcription received (length: ${transcription.length}), ` +
          `${wordTimings.length} words.`
        );

        await jobDocRef.update({
          status: "completed",
          updatedAt: Timestamp.now(),
          transcript: transcription,
          wordTimings: wordTimings,
          errorMessage: null,
        });

        console.log(`Firestore job ${jobDocRef.id} updated with results.`);
      } else {
        console.log("No transcription results found.");
        await jobDocRef.update({
          status: "completed",
          updatedAt: Timestamp.now(),
          transcript: "",
          wordTimings: [],
          errorMessage: "No transcription results returned by API.",
        });
      }

      try {
        await uploadedAudioFile.delete();
        console.log("[Cleanup] Extracted audio deleted.");
      } catch (deleteError) {
        console.error("[Cleanup] Error deleting audio:", deleteError);
      }
    } catch (error: unknown) {
      const errorMessage = error instanceof
      Error ? error.message : String(error);
      console.error("ERROR during processing:", errorMessage);
      try {
        await jobDocRef.update({
          status: "error",
          updatedAt: Timestamp.now(),
          errorMessage: errorMessage,
        });
        console.log(`Firestore job ${jobDocRef.id} updated with error status.`);
      } catch (firestoreError) {
        console.error(
          "ERROR updating Firestore job status with error:",
          firestoreError
        );
      }
    } finally {
      try {
        if (fs.existsSync(tempVideoPath)) {
          fs.unlinkSync(tempVideoPath);
          console.log("[Cleanup] Cleaned temp video.");
        }
        if (fs.existsSync(tempAudioPath)) {
          fs.unlinkSync(tempAudioPath);
          console.log("[Cleanup] Cleaned temp audio.");
        }
      } catch (cleanupError) {
        console.error(
          "[Cleanup] Error cleaning up temporary files:",
          cleanupError
        );
      }
    }

    console.log(`Function execution finished for ${filePath}.`);
    return;
  }
);
