import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../services/api_service.dart';

class CreateDanceScreen extends StatefulWidget {
  final String userId;

  const CreateDanceScreen({super.key, required this.userId});

  @override
  State<CreateDanceScreen> createState() => _CreateDanceScreenState();
}

class _CreateDanceScreenState extends State<CreateDanceScreen> with SingleTickerProviderStateMixin {

  CameraController? _controller;
  bool _isCameraInitialized = false;
  late PoseDetector _poseDetector;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  Size _imageSize = Size.zero;

  // Dance Creation State
  String _danceName = '';
  String _danceDescription = '';
  String _currentStepName = '';
  String _currentStepDescription = '';
  String _currentStepLyrics = '';
  int _currentStepDuration = 8;

  List<Map<String, dynamic>> _steps = [];
  Pose? _currentPose;

  // UI State
  bool _showFullScreenCamera = false;
  bool _showCountdown = false;
  int _countdownValue = 7;
  late AnimationController _countdownController;
  late Animation<double> _countdownAnimation;

  // Text controllers
  final TextEditingController _stepNameController = TextEditingController();
  final TextEditingController _stepDescController = TextEditingController();
  final TextEditingController _stepLyricsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.accurate));

    _countdownController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _countdownAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _countdownController, curve: Curves.easeOut),
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize().then((_) {
        if (!mounted) return;
        final previewSize = _controller!.value.previewSize!;
        _imageSize = Size(previewSize.height, previewSize.width);
        _controller!.startImageStream(_processCameraImage);
        setState(() => _isCameraInitialized = true);
      });
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy || !mounted) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        setState(() => _currentPose = poses.first);

        _customPaint = CustomPaint(
          painter: PosePainter(
            poses,
            _imageSize,
            _controller!.description.lensDirection == CameraLensDirection.front,
          ),
        );
      } else {
        setState(() => _customPaint = null);
      }
    } catch (e) {
      debugPrint("Pose detection error: $e");
      setState(() => _customPaint = null);
    } finally {
      _isBusy = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final rotation = _controller!.description.lensDirection == CameraLensDirection.front
          ? InputImageRotation.rotation270deg
          : InputImageRotation.rotation90deg;

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: metadata,
      );
    } catch (e) {
      debugPrint("InputImage error: $e");
      return null;
    }
  }

  Map<String, dynamic> _poseToJson(Pose pose) {
    final Map<String, dynamic> data = {};
    pose.landmarks.forEach((type, landmark) {
      data[type.name] = {
        'x': landmark.x,
        'y': landmark.y,
        'z': landmark.z,
        'likelihood': landmark.likelihood,
      };
    });
    return data;
  }

  void _startCountdown() {
    if (_currentStepName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a step name")),
      );
      return;
    }

    setState(() {
      _showFullScreenCamera = true;
      _showCountdown = true;
      _countdownValue = 7;
    });

    _countdownController.reset();
    _countdownController.forward();

    Future.delayed(const Duration(milliseconds: 600), () {
      _nextCountdown();
    });
  }

  void _nextCountdown() {
    if (_countdownValue > 1) {
      setState(() => _countdownValue--);
      _countdownController.reset();
      _countdownController.forward();
      Future.delayed(const Duration(milliseconds: 600), _nextCountdown);
    } else {
      setState(() {
        _showCountdown = false;
      });
      _captureStep();
    }
  }

  void _captureStep() {
    if (_currentPose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No pose detected!")),
      );
      setState(() => _showFullScreenCamera = false);
      return;
    }

    final step = {
      'step_number': _steps.length + 1,
      'name': _currentStepName,
      'description': _currentStepDescription,
      'duration': _currentStepDuration,
      'lyrics': _currentStepLyrics,
      'pose_data': _poseToJson(_currentPose!),
    };

    setState(() {
      _steps.add(step);
      _currentStepName = '';
      _currentStepDescription = '';
      _currentStepLyrics = '';
      _stepNameController.clear();
      _stepDescController.clear();
      _stepLyricsController.clear();
      _showFullScreenCamera = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Step ${_steps.length} captured!")),
    );
  }

  Future<void> _saveDance() async {
    if (_danceName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a dance name")),
      );
      return;
    }

    if (_steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one step")),
      );
      return;
    }

    try {
      final danceResult = await ApiService.createCustomDance(
          widget.userId,
          _danceName,
          _danceDescription
      );

      if (danceResult['status'] != 'success') {
        throw Exception(danceResult['message']);
      }

      final danceId = danceResult['dance_id'];

      for (final step in _steps) {
        final stepResult = await ApiService.addCustomStep(
          danceId.toString(),
          step['step_number'],
          step['name'],
          step['description'],
          step['duration'],
          step['lyrics'],
          step['pose_data'],
        );

        if (stepResult['status'] != 'success') {
          throw Exception(stepResult['message']);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dance created successfully!")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving dance: $e")),
      );
    }
  }

  Widget _buildFullScreenCamera() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: _isCameraInitialized
                ? Stack(
              children: [
                CameraPreview(_controller!),
                if (_customPaint != null) _customPaint!,
              ],
            )
                : Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ),

          // Countdown Overlay
          if (_showCountdown)
            Container(
              color: Colors.black54,
              child: Center(
                child: AnimatedBuilder(
                  animation: _countdownAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _countdownAnimation.value,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pinkAccent.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _countdownValue.toString(),
                            style: const TextStyle(
                              fontSize: 80,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => setState(() => _showFullScreenCamera = false),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "CAPTURE POSE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(blurRadius: 5, color: Colors.black),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Instructions
          if (!_showCountdown)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    _currentStepName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(blurRadius: 5, color: Colors.black),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Hold your pose steady",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      shadows: [
                        Shadow(blurRadius: 3, color: Colors.black),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Capture Button
          if (!_showCountdown)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: FloatingActionButton(
                  onPressed: _captureStep,
                  backgroundColor: Colors.pinkAccent,
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Custom Dance"),
        backgroundColor: const Color(0xFF1A093B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveDance,
            tooltip: "Save Dance",
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0B1E), Color(0xFF1A093B), Color(0xFF2D0A5C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Camera Preview Section - Fixed height
            Container(
              height: MediaQuery.of(context).size.height * 0.3, // 30% of screen
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.pinkAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pinkAccent.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    _isCameraInitialized
                        ? Stack(
                      children: [
                        CameraPreview(_controller!),
                        if (_customPaint != null) _customPaint!,
                      ],
                    )
                        : Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt, color: Colors.white, size: 16),
                            SizedBox(width: 5),
                            Text(
                              "LIVE PREVIEW",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Dance Info and Steps Section - Scrollable
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Dance Info
                      const Text(
                        "DANCE INFORMATION",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildGlassTextField(
                        controller: null,
                        hintText: "Dance Name",
                        onChanged: (value) => setState(() => _danceName = value),
                      ),
                      const SizedBox(height: 10),
                      _buildGlassTextField(
                        controller: null,
                        hintText: "Dance Description",
                        onChanged: (value) => setState(() => _danceDescription = value),
                      ),
                      const SizedBox(height: 20),

                      // Current Step
                      const Text(
                        "CURRENT STEP",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildGlassTextField(
                        controller: _stepNameController,
                        hintText: "Step Name",
                        onChanged: (value) => setState(() => _currentStepName = value),
                      ),
                      const SizedBox(height: 10),
                      _buildGlassTextField(
                        controller: _stepDescController,
                        hintText: "Step Description",
                        onChanged: (value) => setState(() => _currentStepDescription = value),
                      ),
                      const SizedBox(height: 10),
                      _buildGlassTextField(
                        controller: _stepLyricsController,
                        hintText: "Lyrics (optional)",
                        onChanged: (value) => setState(() => _currentStepLyrics = value),
                      ),
                      const SizedBox(height: 10),

                      // Duration and Capture Button
                      Row(
                        children: [
                          const Text(
                            "Duration: ",
                            style: TextStyle(color: Colors.white70),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.pinkAccent.withOpacity(0.5)),
                            ),
                            child: DropdownButton<int>(
                              value: _currentStepDuration,
                              dropdownColor: const Color(0xFF1A093B),
                              style: const TextStyle(color: Colors.white),
                              underline: const SizedBox(),
                              items: [4, 5, 6, 8]
                                  .map((duration) => DropdownMenuItem<int>(
                                value: duration,
                                child: Text("$duration beats"),
                              ))
                                  .toList(),
                              onChanged: (value) => setState(() => _currentStepDuration = value!),
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _startCountdown,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pinkAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 5,
                              shadowColor: Colors.pinkAccent.withOpacity(0.5),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.camera_alt),
                                SizedBox(width: 8),
                                Text(
                                  "CAPTURE",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Steps List
                      if (_steps.isNotEmpty) ...[
                        const Text(
                          "CAPTURED STEPS",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 150, // Fixed height for steps list
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: ListView.builder(
                            itemCount: _steps.length,
                            itemBuilder: (context, index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.pinkAccent,
                                  child: Text(
                                    "${index + 1}",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  _steps[index]['name'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  _steps[index]['description'],
                                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () {
                                    setState(() => _steps.removeAt(index));
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20), // Extra space at bottom
                      ] else ...[
                        const SizedBox(height: 20),
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: const Center(
                            child: Text(
                              "No steps captured yet\nTap 'CAPTURE STEP' to add your first pose",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassTextField({
    required TextEditingController? controller,
    required String hintText,
    required ValueChanged<String> onChanged,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _countdownController.dispose();
    _controller?.dispose();
    _poseDetector.close();
    _stepNameController.dispose();
    _stepDescController.dispose();
    _stepLyricsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _showFullScreenCamera ? _buildFullScreenCamera() : _buildMainScreen();
  }
}

// PosePainter implementation
class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size absoluteImageSize;
  final bool isFrontCamera;

  PosePainter(this.poses, this.absoluteImageSize, this.isFrontCamera);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.cyanAccent;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(
          Offset(
            isFrontCamera
                ? size.width - (landmark.x / absoluteImageSize.width * size.width)
                : landmark.x / absoluteImageSize.width * size.width,
            landmark.y / absoluteImageSize.height * size.height,
          ),
          4,
          paint,
        );
      });
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.poses != poses;
  }
}