import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // Camera
  CameraController? _controller;
  bool _isCameraInitialized = false;
  late PoseDetector _poseDetector;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  Size _imageSize = Size.zero;

  // Perform
  DateTime? _lastProcessingTime;
  final double _smoothingFactor = 0.1;
  List<Pose> _previousPoses = [];
  int _framesProcessed = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();

    _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.base));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !(_controller!.value.isInitialized)) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller != null) {
        _initializeCamera();
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      CameraDescription camera;

      try {
        camera = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.front);
      } catch (e) {
        camera = cameras.first;
      }

      _controller = CameraController(
        camera,
        ResolutionPreset.low, // Use low resolution for fastest processing
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
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
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Camera Error"),
            content: const Text("Could not initialize camera. Please check permissions and try again."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        ).then((_) => Navigator.pop(context));
      }
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy || !mounted) return;

    final now = DateTime.now();
    if (_lastProcessingTime != null) {
      final timeSinceLast = now.difference(_lastProcessingTime!).inMilliseconds;
      if (timeSinceLast < 16) return;
    }

    _isBusy = true;
    _lastProcessingTime = now;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final poses = await _poseDetector.processImage(inputImage);
      _framesProcessed++;

      if (poses.isNotEmpty) {
        final smoothedPose = _smoothPose(poses.first);

        _customPaint = CustomPaint(
          painter: PosePainter(
            [smoothedPose],
            _imageSize,
            _controller!.description.lensDirection == CameraLensDirection.front,
          ),
        );
      } else {
        _customPaint = null;
      }
    } catch (e) {
      debugPrint("Pose detection error: $e");
      _customPaint = null;
    } finally {
      _isBusy = false;
      if (mounted) setState(() {});
    }
  }

  Pose _smoothPose(Pose newPose) {
    if (_previousPoses.isEmpty) {
      _previousPoses.add(newPose);
      return newPose;
    }

    final lastPose = _previousPoses.last;
    final smoothedLandmarks = <PoseLandmarkType, PoseLandmark>{};

    for (final type in newPose.landmarks.keys) {
      final newLandmark = newPose.landmarks[type]!;
      final oldLandmark = lastPose.landmarks[type];

      if (oldLandmark == null) {
        smoothedLandmarks[type] = newLandmark;
      } else {
        final smoothedX = oldLandmark.x * _smoothingFactor + newLandmark.x * (1 - _smoothingFactor);
        final smoothedY = oldLandmark.y * _smoothingFactor + newLandmark.y * (1 - _smoothingFactor);
        final smoothedZ = oldLandmark.z * _smoothingFactor + newLandmark.z * (1 - _smoothingFactor);

        smoothedLandmarks[type] = PoseLandmark(
          type: type,
          x: smoothedX,
          y: smoothedY,
          z: smoothedZ,
          likelihood: newLandmark.likelihood,
        );
      }
    }

    final smoothedPose = Pose(landmarks: smoothedLandmarks);
    _previousPoses.add(smoothedPose);

    if (_previousPoses.length > 3) {
      _previousPoses.removeAt(0);
    }

    return smoothedPose;
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                "Initializing camera...",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera + Pose overlay
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _imageSize.width,
                height: _imageSize.height,
                child: Stack(
                  children: [
                    CameraPreview(_controller!),
                    if (_customPaint != null) _customPaint!,
                  ],
                ),
              ),
            ),
          ),

          // UI Overlay
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "REALTIME CAMERA",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 5,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        "$_framesProcessed frames",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 5,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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

  PosePainter(this.poses, this.imageSize, this.isFrontCamera);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.8)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final jointStrokePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    const jointRadius = 12.0;

    Offset mapPoint(PoseLandmark? lm) {
      if (lm == null) return Offset.zero;
      final double x = isFrontCamera ? (imageSize.width - lm.x) : lm.x;
      final double y = lm.y;
      return Offset(x, y);
    }

    void drawBone(PoseLandmarkType a, PoseLandmarkType b) {
      final p1 = poses.first.landmarks[a];
      final p2 = poses.first.landmarks[b];
      if (p1 == null || p2 == null) return;

      final o1 = mapPoint(p1);
      final o2 = mapPoint(p2);
      canvas.drawLine(o1, o2, linePaint);
    }

    for (final pose in poses) {
      // Torso
      drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawBone(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      drawBone(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

      // Arms
      drawBone(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      drawBone(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      drawBone(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      drawBone(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

      // Legs
      drawBone(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      drawBone(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
      drawBone(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      drawBone(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

      // Joints
      for (final lm in pose.landmarks.values) {
        final o = mapPoint(lm);
        canvas.drawCircle(o, jointRadius, jointPaint);
        canvas.drawCircle(o, jointRadius, jointStrokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

