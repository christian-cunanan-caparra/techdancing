import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class GameplayScreen extends StatefulWidget {
  final int danceId;
  final String roomCode;

  const GameplayScreen({
    super.key,
    required this.danceId,
    required this.roomCode,
  });

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  late PoseDetector _poseDetector;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  Size _imageSize = Size.zero;
  double _scaleX = 1.0;
  double _scaleY = 1.0;
  double _ratio = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.base));
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(frontCam, ResolutionPreset.high, enableAudio: false);
      await _controller!.initialize();

      if (!mounted) return;

      _imageSize = Size(
        _controller!.value.previewSize!.width,
        _controller!.value.previewSize!.height,
      );

      // Calculate scaling factors
      final screenSize = MediaQuery.of(context).size;
      _ratio = _imageSize.width / _imageSize.height;

      // Calculate separate scale factors for X and Y to maintain aspect ratio
      final scaleX = screenSize.width / _imageSize.height;
      final scaleY = screenSize.height / _imageSize.width;
      _scaleX = scaleX;
      _scaleY = scaleY;

      _controller!.startImageStream(_processCameraImage);
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint("Camera error: $e");
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy || !mounted) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        _customPaint = CustomPaint(
          painter: PosePainter(
            poses,
            _imageSize,
            _controller!.description.lensDirection == CameraLensDirection.front,
            scaleX: _scaleX,
            scaleY: _scaleY,
          ),
        );
      } else {
        _customPaint = null;
      }
    } catch (e) {
      debugPrint("Pose detection error: $e");
      _customPaint = null;
    } finally {
      if (mounted) setState(() {});
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

      final rotation =
      _controller!.description.lensDirection == CameraLensDirection.front
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

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera preview with pose detection overlay
          Transform.scale(
            scale: 1.0,
            child: Center(
              child: AspectRatio(
                aspectRatio: 1 / _ratio,
                child: Stack(
                  children: [
                    CameraPreview(_controller!),
                    if (_customPaint != null)
                      Positioned.fill(
                        child: _customPaint!,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Overlay UI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Dance ${widget.danceId}",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "Room Code: ${widget.roomCode}",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const Spacer(),
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.music_note, color: Colors.cyanAccent, size: 60),
                        SizedBox(height: 20),
                        CircularProgressIndicator(color: Colors.cyanAccent),
                        SizedBox(height: 20),
                        Text(
                          "Get ready to dance!",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final bool isFrontCamera;
  final double scaleX;
  final double scaleY;

  PosePainter(
      this.poses,
      this.imageSize,
      this.isFrontCamera, {
        required this.scaleX,
        required this.scaleY,
      });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.fill;

    final jointStrokePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const jointRadius = 6.0;

    for (final pose in poses) {
      // Function to draw a joint (circle) at a landmark position
      void drawJoint(PoseLandmarkType type) {
        final landmark = pose.landmarks[type];
        if (landmark == null) return;

        // Adjust coordinates for scaling and mirroring
        double x = landmark.x * scaleX;
        double y = landmark.y * scaleY;

        if (isFrontCamera) {
          // Mirror the x-coordinate for front camera
          x = size.width - x;
        }

        // Draw the joint with a stroke outline
        canvas.drawCircle(Offset(x, y), jointRadius, jointPaint);
        canvas.drawCircle(Offset(x, y), jointRadius, jointStrokePaint);
      }

      // Function to draw a line between two landmarks
      void drawLine(PoseLandmarkType type1, PoseLandmarkType type2) {
        final landmark1 = pose.landmarks[type1];
        final landmark2 = pose.landmarks[type2];
        if (landmark1 == null || landmark2 == null) return;

        // Adjust coordinates for scaling and mirroring
        double x1 = landmark1.x * scaleX;
        double y1 = landmark1.y * scaleY;
        double x2 = landmark2.x * scaleX;
        double y2 = landmark2.y * scaleY;

        if (isFrontCamera) {
          // Mirror the x-coordinate for front camera
          x1 = size.width - x1;
          x2 = size.width - x2;
        }

        // Draw the line
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
      }

      // Draw all the connections (skeleton lines)
      // Torso connections
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

      // Left arm connections
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);

      // Right arm connections
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

      // Left leg connections
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);

      // Right leg connections
      drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

      // Additional connections for more complete skeleton
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftEar);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightEar);
      drawLine(PoseLandmarkType.leftEye, PoseLandmarkType.rightEye);
      drawLine(PoseLandmarkType.leftEye, PoseLandmarkType.leftEar);
      drawLine(PoseLandmarkType.rightEye, PoseLandmarkType.rightEar);
      drawLine(PoseLandmarkType.leftMouth, PoseLandmarkType.rightMouth);

      // Draw all the joints (landmarks)
      for (final landmark in pose.landmarks.values) {
        double x = landmark.x * scaleX;
        double y = landmark.y * scaleY;

        if (isFrontCamera) {
          x = size.width - x;
        }

        // Draw the joint with a stroke outline
        canvas.drawCircle(Offset(x, y), jointRadius, jointPaint);
        canvas.drawCircle(Offset(x, y), jointRadius, jointStrokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}