import 'dart:convert';
import 'dart:typed_data';
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

class _CreateDanceScreenState extends State<CreateDanceScreen> {
  // Camera and Pose Detection
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

  // Text controllers for clearing fields
  final TextEditingController _stepNameController = TextEditingController();
  final TextEditingController _stepDescController = TextEditingController();
  final TextEditingController _stepLyricsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.accurate));
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
        ResolutionPreset.low,
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

  // Convert pose landmarks to a JSON-serializable format
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

  void _captureStep() {
    if (_currentPose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No pose detected!")),
      );
      return;
    }

    if (_currentStepName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a step name")),
      );
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
      // Create the dance
      final danceResult = await ApiService.createCustomDance(
          widget.userId,
          _danceName,
          _danceDescription
      );

      if (danceResult['status'] != 'success') {
        throw Exception(danceResult['message']);
      }

      final danceId = danceResult['dance_id'];

      // Add all steps
      for (final step in _steps) {
        final stepResult = await ApiService.addCustomStep(
          danceId.toString(),
          step['step_number'],
          step['name'],
          step['description'],
          step['duration'],
          step['lyrics'],
          step['pose_data'], // Pass as Map directly
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

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close();
    _stepNameController.dispose();
    _stepDescController.dispose();
    _stepLyricsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Custom Dance"),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveDance,
          ),
        ],
      ),
      body: _isCameraInitialized
          ? Column(
        children: [
          // Camera Preview
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                CameraPreview(_controller!),
                if (_customPaint != null) _customPaint!,
              ],
            ),
          ),

          // Dance Info
          Expanded(
            flex: 2,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Dance Name",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _danceName = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Dance Description",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _danceDescription = value),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Current Step",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Step Name",
                    border: OutlineInputBorder(),
                  ),
                  controller: _stepNameController,
                  onChanged: (value) => setState(() => _currentStepName = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Step Description",
                    border: OutlineInputBorder(),
                  ),
                  controller: _stepDescController,
                  onChanged: (value) => setState(() => _currentStepDescription = value),
                ),
                const SizedBox(height: 10),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Lyrics (optional)",
                    border: OutlineInputBorder(),
                  ),
                  controller: _stepLyricsController,
                  onChanged: (value) => setState(() => _currentStepLyrics = value),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text("Duration: "),
                    DropdownButton<int>(
                      value: _currentStepDuration,
                      items: [4, 5, 6, 8]
                          .map((duration) => DropdownMenuItem<int>(
                        value: duration,
                        child: Text("$duration beats"),
                      ))
                          .toList(),
                      onChanged: (value) => setState(() => _currentStepDuration = value!),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _captureStep,
                      child: const Text("Capture Step"),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Steps List
          if (_steps.isNotEmpty)
            Expanded(
              flex: 1,
              child: ListView.builder(
                itemCount: _steps.length,
                itemBuilder: (context, index) => ListTile(
                  leading: Text("${index + 1}"),
                  title: Text(_steps[index]['name']),
                  subtitle: Text(_steps[index]['description']),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() => _steps.removeAt(index));
                    },
                  ),
                ),
              ),
            ),
        ],
      )
          : const Center(child: CircularProgressIndicator()),
    );
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
      ..color = Colors.green;

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