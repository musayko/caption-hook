import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:caption_hook/src/features/upload/data/caption_job.dart';
import 'package:caption_hook/src/features/upload/data/upload_repository.dart';
// Removed imports: http, dart:io, path_provider, permission_handler, ffmpeg_kit_flutter, firestore_service

class CaptionDisplayScreen extends ConsumerStatefulWidget {
  final CaptionJob job;
  const CaptionDisplayScreen({required this.job, super.key});

  @override
  ConsumerState<CaptionDisplayScreen> createState() =>
      _CaptionDisplayScreenState();
}

class _CaptionDisplayScreenState extends ConsumerState<CaptionDisplayScreen> {
  VideoPlayerController? _videoController;
  bool _isLoading = true;
  bool _isPseudoSaving = false; // Renamed state for clarity
  String? _error;
  String? _videoUrl;

  List<WordTiming> _editableTimings = [];
  int _currentTimingIndex = -1;
  String _currentCaptionText = "";
  Timer? _debounceTimer;

  // Styling State
  Color _textColor = Colors.white;
  Color _bgColor = Colors.black;
  double _bgOpacity = 0.6;
  double _captionWidth = 0.0;

  // Draggable Position State
  Offset _captionOffset = Offset.zero;
  bool _offsetInitialized = false;
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _captionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Initialize _editableTimings only if wordTimings is not null
    _editableTimings = List<WordTiming>.from(widget.job.wordTimings ?? []);
    _initializeVideoPlayer();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _setInitialCaptionPosition(),
    );
  }

  // Calculate Initial Position (keep as is)
  void _setInitialCaptionPosition() {
     print("[Position Init] Attempting to set initial position...");
    if (!mounted) {
      print("[Position Init] Failed: Widget not mounted.");
      return;
    }

    final stackContext = _stackKey.currentContext;
    final captionContext = _captionKey.currentContext;
    print("[Position Init] Stack Context found: ${stackContext != null}");
    print("[Position Init] Caption Context found: ${captionContext != null}");

    // Short delay to allow caption text to render if needed for size calculation
    Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted) return; // Check again after delay

        final stackRenderBox = stackContext?.findRenderObject() as RenderBox?;
        final captionRenderBox = captionContext?.findRenderObject() as RenderBox?;
        print("[Position Init Delay] Stack RenderBox found: ${stackRenderBox != null}, Has Size: ${stackRenderBox?.hasSize}");
        print("[Position Init Delay] Caption RenderBox found: ${captionRenderBox != null}, Has Size: ${captionRenderBox?.hasSize}");


        if (stackRenderBox != null && stackRenderBox.hasSize && captionRenderBox != null && captionRenderBox.hasSize) {
          final stackSize = stackRenderBox.size;
          final captionSize = captionRenderBox.size;
          print("[Position Init Delay] Stack Size: $stackSize");
          print("[Position Init Delay] Caption Size: $captionSize");

          // Calculate position for bottom center (adjust - 40.0 for padding)
          final double initialTop = stackSize.height - captionSize.height - 40.0;
          final double initialLeft = (stackSize.width / 2); // Center X


          // Ensure calculated values are not negative if caption is unexpectedly large
          final clampedTop = initialTop < 0 ? 0.0 : initialTop;
          // Left is already calculated based on center, no need for width here as Transform handles it
          final clampedLeft = initialLeft;


           if(mounted) {
               setState(() {
                _captionOffset = Offset(clampedLeft, clampedTop);
                _offsetInitialized = true;
                print("[Position Init Delay] Success! Offset set to: $_captionOffset");
              });
           }
        } else {
          print("[Position Init Delay] Failed: Could not get sizes. Using fallback offset.");
          // Fallback if sizes aren't ready yet
          if(mounted) {
              setState(() {
                _captionOffset = const Offset(150, 300); // Arbitrary fallback - center X approx
                _offsetInitialized = true; // Set to true even on fallback to remove "Initializing..."
                print("[Position Init Delay] Fallback offset set: $_captionOffset");
              });
          }
        }

    });
  }

  // Initialize Video Player (keep as is)
  Future<void> _initializeVideoPlayer() async {
     setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.job.originalVideoPath == null) {
        throw Exception("Video path is null in the Job data.");
      }

      // Use ref.read inside async methods if needed after initState
      _videoUrl = await ref.read(uploadRepositoryProvider).getDownloadUrl(widget.job.originalVideoPath!);
      if (!mounted) return;

      _videoController = VideoPlayerController.networkUrl(Uri.parse(_videoUrl!))
        ..initialize().then((_) {
              if (!mounted) return;
              setState(() { _isLoading = false; });
              _videoController?.addListener(_updateCaption);
              // Set initial caption size *after* player is ready and first frame might be available
              WidgetsBinding.instance.addPostFrameCallback((_) => _updateCaptionSize());
        }).catchError((error) {
            if (!mounted) return;
            setState(() { _isLoading = false; _error = "Could not load video: $error"; });
        });

       await _videoController!.setLooping(true);
    } catch (e) {
       if (!mounted) return;
       setState(() { _isLoading = false; _error = "Error initializing video: $e"; });
    }
  }

 // Update caption text based on video position
 void _updateCaption() {
    if (!mounted || _videoController == null || !_videoController!.value.isInitialized) return;

    final currentPosition = _videoController!.value.position;
    final currentPositionSec = currentPosition.inMilliseconds / 1000.0;

    int foundIndex = -1;
    String activeWord = "";

    // Find the word corresponding to the current video time
    for (int i = 0; i < _editableTimings.length; i++) {
      final timing = _editableTimings[i];
      if (currentPositionSec >= timing.startTimeSec && currentPositionSec < timing.endTimeSec) {
        activeWord = timing.word;
        foundIndex = i;
        break;
      }
    }

    // Debounce state update to avoid excessive rebuilds
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () { // Increased debounce slightly
      if (mounted && (_currentCaptionText != activeWord || _currentTimingIndex != foundIndex)) {
        setState(() {
          _currentCaptionText = activeWord;
          _currentTimingIndex = foundIndex;
        });
        // Update caption size after text potentially changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
           _updateCaptionSize();
        });
      }
    });
  }

  // Helper to update the measured width of the caption text widget
  void _updateCaptionSize() {
      if (!mounted) return;
      final captionContext = _captionKey.currentContext;
      if (captionContext != null) {
        final box = captionContext.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize) {
          // Avoid calling setState if the value hasn't changed
          if (_captionWidth != box.size.width) {
            setState(() {
                _captionWidth = box.size.width;
                print("[Caption Size Update] Width: $_captionWidth"); // Log size update
            });
          }
        }
      }
    }

  // Show Edit Dialog (keep as is)
  Future<void> _showEditDialog() async {
    if (_currentTimingIndex < 0 || _currentTimingIndex >= _editableTimings.length) return;

    final currentTiming = _editableTimings[_currentTimingIndex];
    final textController = TextEditingController(text: currentTiming.word);

    final newText = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Word"),
        content: TextFormField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Enter new word"),
        ),
        actions: [
          TextButton( onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel"),),
          TextButton( onPressed: () { Navigator.of(context).pop(textController.text); }, child: const Text("Save"),),
        ],
      ),
    );

    if (newText != null && newText != currentTiming.word) {
      setState(() {
        // Update the timing in the list
        _editableTimings[_currentTimingIndex] = WordTiming(
          word: newText,
          startTimeSec: currentTiming.startTimeSec,
          endTimeSec: currentTiming.endTimeSec,
        );
        // Immediately update the currently displayed text
        _currentCaptionText = newText;
      });
       // Update size after potential text change
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateCaptionSize());
    }
  }

  // Show Style Bottom Sheet (keep as is)
  void _showStyleBottomSheet() {
     showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        Color tempTextColor = _textColor;
        Color tempBgColor = _bgColor;
        double tempBgOpacity = _bgOpacity;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                runSpacing: 15,
                children: [
                  ListTile(
                    leading: CircleAvatar(backgroundColor: _textColor, radius: 15,),
                    title: const Text("Text Color"),
                    onTap: () => _showColorPickerDialog(
                        context: context,
                        pickerColor: _textColor,
                        onColorChanged: (color) => tempTextColor = color,
                        onColorSelected: () {
                          if(mounted) setState(() => _textColor = tempTextColor);
                          Navigator.of(context).pop();
                        },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                     leading: CircleAvatar(backgroundColor: _bgColor, radius: 15,),
                     title: const Text("Background Color"),
                     onTap: () => _showColorPickerDialog(
                          context: context,
                          pickerColor: _bgColor,
                          onColorChanged: (color) => tempBgColor = color,
                          onColorSelected: () {
                            if(mounted) setState(() => _bgColor = tempBgColor);
                             Navigator.of(context).pop();
                          },
                      ),
                  ),
                   const Divider(),
                  const Text("Background Opacity:", style: TextStyle(fontWeight: FontWeight.bold),),
                  Slider(
                    value: tempBgOpacity,
                    min: 0.0, max: 1.0, divisions: 10,
                    label: "${(tempBgOpacity * 100).toStringAsFixed(0)}%",
                    onChanged: (value) {
                      setModalState(() => tempBgOpacity = value);
                      // Update the main state immediately for live preview
                      if(mounted) setState(() => _bgOpacity = value);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Show Color Picker Dialog (keep as is)
  void _showColorPickerDialog({
    required BuildContext context,
    required Color pickerColor,
    required ValueChanged<Color> onColorChanged,
    required VoidCallback onColorSelected,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: onColorChanged,
             pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: <Widget>[
           TextButton( child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(), ),
           TextButton( child: const Text('Select'), onPressed: onColorSelected, ),
        ],
      ),
    );
  }

  // --- MODIFIED "Save" Process ---
  Future<void> _pseudoSaveProcess() async {
    print("Pseudo save process triggered...");
    if (!mounted || _isPseudoSaving) return;

    // Optional: Check if there's anything to "save"
    // if (_editableTimings.isEmpty) { ... }

    setState(() => _isPseudoSaving = true);

    // Simulate a short delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Download/Render Initiated! (Placeholder)"),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() => _isPseudoSaving = false);
    }
  }
  // --- END MODIFIED "Save" Process ---

  @override
  void dispose() {
    _videoController?.removeListener(_updateCaption);
    _debounceTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Define styles here for cleaner build method
    final captionTextStyle = textTheme.bodyLarge?.copyWith(
      color: _textColor,
      fontWeight: FontWeight.bold, // Make it bold
      fontSize: 18, // Increase font size slightly
      shadows: [ // Add subtle shadow for better readability
        const Shadow(offset: Offset(1.0, 1.0), blurRadius: 2.0, color: Colors.black54),
      ]
    );

    final captionBgDecoration = BoxDecoration(
      color: _bgColor.withOpacity(_bgOpacity),
      borderRadius: BorderRadius.circular(4), // Slightly less rounded
       boxShadow: [ // Optional: Add subtle shadow to background too
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );


    return Scaffold(
      appBar: AppBar(
        title: const Text('View/Edit Captions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.style_outlined),
            tooltip: "Edit Styles",
            onPressed: _showStyleBottomSheet,
          ),
          // --- "Save/Download" Button ---
          IconButton(
            icon: _isPseudoSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white,),
                  )
                : const Icon(Icons.download_for_offline_outlined), // Changed Icon
            tooltip: "Download Video (Placeholder)", // Changed Tooltip
            onPressed: _isPseudoSaving ? null : _pseudoSaveProcess, // Call pseudo function
          ),
          // --- END ---
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error: $_error", style: const TextStyle(color: Colors.red)),),)
              : _videoController == null || !_videoController!.value.isInitialized
                  ? const Center(child: Text("Video player initializing..."))
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          key: _stackKey,
                          children: [
                            // Video Player
                            Center(child: AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!),),),

                            // Draggable Caption
                            if (_offsetInitialized)
                              Positioned(
                                left: _captionOffset.dx, // Use calculated left offset
                                top: _captionOffset.dy,  // Use calculated top offset
                                child: Transform.translate(
                                   // Apply centering based on measured width AFTER it's available
                                   offset: Offset(-_captionWidth / 2, 0,),
                                   child: _currentCaptionText.isNotEmpty ? GestureDetector(
                                        key: _captionKey, // Key to measure size
                                        onTap: _showEditDialog,
                                        onPanUpdate: (details) {
                                            if (!mounted) return;
                                            setState(() {
                                                // Apply delta to current offset
                                                _captionOffset += details.delta;

                                                // Bounds Checking
                                                final stackRenderBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
                                                final captionRenderBox = _captionKey.currentContext?.findRenderObject() as RenderBox?;
                                                if (stackRenderBox != null && stackRenderBox.hasSize && captionRenderBox != null && captionRenderBox.hasSize) {
                                                    final stackSize = stackRenderBox.size;
                                                    // Use the measured caption width for bounds
                                                    final captionWidth = captionRenderBox.size.width;
                                                    final captionHeight = captionRenderBox.size.height;

                                                    // Clamp horizontal position (adjusting for transform)
                                                    final double minX = captionWidth / 2;
                                                    final double maxX = stackSize.width - (captionWidth / 2);
                                                    // Clamp vertical position
                                                    final double minY = 0.0;
                                                    final double maxY = stackSize.height - captionHeight;

                                                    _captionOffset = Offset(
                                                        _captionOffset.dx.clamp(minX, maxX),
                                                        _captionOffset.dy.clamp(minY, maxY),
                                                    );
                                                }
                                            });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10,), // Adjust padding
                                          decoration: captionBgDecoration,
                                          child: Text(
                                              _currentCaptionText, // Display current word
                                              textAlign: TextAlign.center,
                                              style: captionTextStyle,
                                          ),
                                        ),
                                    ) : Container(key: _captionKey), // Render empty container with key if no text, helps initial measurement
                                ),
                              )
                           else if (!_isLoading)
                             const Center(child: Text("Initializing caption position...")), // More accurate placeholder

                            // Play/Pause Button
                            Positioned(
                                bottom: 40, // Adjusted position slightly
                                left: 0, right: 0,
                                child: Center( child: FloatingActionButton(
                                    // mini: true, // Make slightly larger? Remove mini.
                                    backgroundColor: Colors.black.withOpacity(0.5), // Semi-transparent BG
                                    foregroundColor: Colors.white,
                                    child: Icon(_videoController!.value.isPlaying ? Icons.pause_circle_filled_outlined : Icons.play_circle_fill_outlined, size: 40,), // Larger icons
                                    onPressed: () { if(mounted) setState(() { _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play(); }); },
                                ),),
                              ),
                          ],
                        );
                      },
                    ),
    );
  }
}

// Ensure WordTiming class exists (usually in caption_job.dart)
// class WordTiming {
//   final String word;
//   final double startTimeSec;
//   final double endTimeSec;
//
//   WordTiming({required this.word, required this.startTimeSec, required this.endTimeSec});
//
//   // Add fromMap if needed for Firestore interaction later
//   // factory WordTiming.fromMap(Map<String, dynamic> map) { ... }
// }