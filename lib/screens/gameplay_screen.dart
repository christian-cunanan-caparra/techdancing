import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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

  // Game state variables
  bool _isGameStarted = false;
  bool _isGameFinished = false;
  int _score = 0;
  int _currentStep = 0;
  List<int> _stepScores = [];
  List<Map<String, dynamic>> _danceSteps = [];
  List<Pose> _recordedPoses = [];
  int _countdown = 3;
  late Timer _countdownTimer;
  late Timer _gameTimer;
  int _timeRemaining = 60;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.base));
    _loadDanceSteps();
    _startCountdown();
  }

  void _loadDanceSteps() {
    _danceSteps = [
      {
        'name': 'Sumabay Ka',
        'description': 'Arms swaying side to side with small steps',
        'targetLandmarks': {
          'leftShoulder': {'x': 0.4, 'y': 0.3},
          'rightShoulder': {'x': 0.6, 'y': 0.3},
        },
        'duration': 8,
        'originalDuration': 8,
        'lyrics': 'Sumabay ka nalang\nWag kang mahihiya\nSige subukan mo\nBaka may mapala',
      },
      {
        'name': 'Chacha Step',
        'description': 'Side chacha steps with arm swings',
        'targetLandmarks': {
          'leftHip': {'x': 0.3, 'y': 0.5},
          'rightHip': {'x': 0.7, 'y': 0.5},
        },
        'duration': 8,
        'originalDuration': 8,
        'lyrics': 'Walang mawawala\nKapag nagchachaga\nKung gustong gusto mo\nSundan mo lang ako',
      },
      {
        'name': 'Jumbo Hotdog Pose',
        'description': 'Arms wide open then pointing forward',
        'targetLandmarks': {
          'leftWrist': {'x': 0.2, 'y': 0.4},
          'rightWrist': {'x': 0.8, 'y': 0.4},
        },
        'duration': 16,
        'originalDuration': 16,
        'lyrics': '[jumbo hotdog\nKaya mo ba to?\nKaya mo ba to?\nKaya mo ba to?]',
      },
      {
        'name': 'Final Pose',
        'description': 'Hands on hips with confident stance',
        'targetLandmarks': {
          'leftHip': {'x': 0.4, 'y': 0.5},
          'rightHip': {'x': 0.6, 'y': 0.5},
          'leftWrist': {'x': 0.4, 'y': 0.6},
          'rightWrist': {'x': 0.6, 'y': 0.6},
        },
        'duration': 8,
        'originalDuration': 8,
        'lyrics': 'Jumbo hotdog\nKaya mo ba to?\nHindi kami ba to\nPara magpatalo',
      },
    ];
    _stepScores = List.filled(_danceSteps.length, 0);
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _countdownTimer.cancel();
          _startGame();
        }
      });
    });
  }

  void _startGame() {
    setState(() {
      _isGameStarted = true;
      _currentStep = 0;
      _score = 0;
      _timeRemaining = 60;
    });

    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;

          if (_danceSteps[_currentStep]['duration'] <= 0) {
            _nextStep();
          } else {
            _danceSteps[_currentStep]['duration']--;
          }
        } else {
          _endGame();
          timer.cancel();
        }
      });
    });
  }

  void _nextStep() {
    if (_currentStep < _danceSteps.length - 1) {
      setState(() {
        _currentStep++;
        _danceSteps[_currentStep]['duration'] = _danceSteps[_currentStep]['originalDuration'];
      });
    } else {
      _endGame();
    }
  }

  void _endGame() {
    _gameTimer.cancel();
    _calculateFinalScore();
    setState(() {
      _isGameFinished = true;
    });
  }

  void _calculateFinalScore() {
    int totalScore = 0;

    for (int i = 0; i < _stepScores.length; i++) {
      int stepScore;

      switch(i) {
        case 0:
          stepScore = _evaluateArmSwing(_recordedPoses.isNotEmpty ? _recordedPoses[i] : null);
          break;
        case 1:
          stepScore = _evaluateHipMovement(_recordedPoses.isNotEmpty ? _recordedPoses[i] : null);
          break;
        case 2:
          stepScore = _evaluateJumboPose(_recordedPoses.isNotEmpty ? _recordedPoses[i] : null);
          break;
        case 3:
          stepScore = _evaluateFinalPose(_recordedPoses.isNotEmpty ? _recordedPoses[i] : null);
          break;
        default:
          stepScore = 500 + _random.nextInt(500);
      }

      _stepScores[i] = stepScore;
      totalScore += stepScore;
    }

    setState(() {
      _score = totalScore ~/ _stepScores.length;
    });
  }

  int _evaluateArmSwing(Pose? pose) {
    if (pose == null) return 500;

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftShoulder == null || rightShoulder == null) return 500;

    double distance = (leftShoulder.x - rightShoulder.x).abs();

    if (distance > 0.3) return 950 + _random.nextInt(50);
    if (distance > 0.2) return 850 + _random.nextInt(100);
    return 600 + _random.nextInt(200);
  }

  int _evaluateJumboPose(Pose? pose) {
    if (pose == null) return 500;

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null) return 500;

    double spread = (leftWrist.x - rightWrist.x).abs();
    bool armsUp = leftShoulder != null && rightShoulder != null
        ? (leftWrist.y < leftShoulder.y && rightWrist.y < rightShoulder.y)
        : false;

    if (spread > 0.6 && armsUp) return 1000;
    if (spread > 0.4) return 800 + _random.nextInt(150);
    return 600 + _random.nextInt(200);
  }

  int _evaluateHipMovement(Pose? pose) => 700 + _random.nextInt(300);
  int _evaluateFinalPose(Pose? pose) => 750 + _random.nextInt(250);

  String _getScoreFeedback(int score) {
    if (score >= 950) return "PERFECT! 🤩";
    if (score >= 850) return "Impressive! 😍";
    if (score >= 750) return "Great job! 😊";
    if (score >= 650) return "Good effort! 👍";
    if (score >= 500) return "Keep practicing! 💪";
    return "Try again! 😅";
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

      final screenSize = MediaQuery.of(context).size;
      _ratio = _imageSize.width / _imageSize.height;

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
    if (_isBusy || !mounted || !_isGameStarted || _isGameFinished) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        if (_isGameStarted && !_isGameFinished) {
          _recordedPoses.add(poses.first);
        }

        _customPaint = CustomPaint(
          painter: PosePainter(
            poses,
            _imageSize,
            _controller!.description.lensDirection == CameraLensDirection.front,
            scaleX: _scaleX,
            scaleY: _scaleY,
            targetPose: _danceSteps[_currentStep]['targetLandmarks'],
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
    _countdownTimer.cancel();
    _gameTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isGameFinished) {
      return _buildResultsScreen();
    }

    return Scaffold(
      body: Stack(
        children: [
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

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Jumbo Hotdog Challenge",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "Room: ${widget.roomCode}",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "$_timeRemaining s",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  if (!_isGameStarted)
                    Center(
                      child: Column(
                        children: [
                          Text(
                            _countdown.toString(),
                            style: const TextStyle(
                              fontSize: 100,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyanAccent,
                            ),
                          ),
                          const Text(
                            "Get ready to dance!",
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Center(
                      child: Column(
                        children: [
                          Text(
                            _danceSteps[_currentStep]['name'],
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyanAccent,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _danceSteps[_currentStep]['description'],
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _danceSteps[_currentStep]['lyrics'],
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.yellow,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Step ${_currentStep + 1}/${_danceSteps.length}",
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: _danceSteps[_currentStep]['duration'] /
                                _danceSteps[_currentStep]['originalDuration'],
                            backgroundColor: Colors.white24,
                            color: Colors.cyanAccent,
                            minHeight: 10,
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  if (_isGameStarted)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "Score: $_score",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0523), Color(0xFF1D054A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _getScoreFeedback(_score),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
              ),
            ),

            const SizedBox(height: 30),

            Text(
              "Your Score",
              style: TextStyle(
                fontSize: 24,
                color: Colors.white.withOpacity(0.8),
              ),
            ),

            Text(
              _score.toString(),
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 30),

            Expanded(
              child: ListView.builder(
                itemCount: _stepScores.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.cyanAccent,
                      child: Text(
                        (index + 1).toString(),
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    title: Text(
                      _danceSteps[index]['name'],
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: LinearProgressIndicator(
                      value: _stepScores[index] / 1000,
                      backgroundColor: Colors.white24,
                      color: Colors.cyanAccent,
                    ),
                    trailing: Text(
                      _stepScores[index].toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "BACK TO LOBBY",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
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
  final Map<String, dynamic>? targetPose;

  PosePainter(
      this.poses,
      this.imageSize,
      this.isFrontCamera, {
        required this.scaleX,
        required this.scaleY,
        this.targetPose,
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

    final targetJointPaint = Paint()
      ..color = Colors.pink
      ..style = PaintingStyle.fill;

    final targetJointStrokePaint = Paint()
      ..color = Colors.pinkAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const jointRadius = 6.0;
    const targetJointRadius = 8.0;

    // Draw target pose if available
    if (targetPose != null) {
      for (final entry in targetPose!.entries) {
        try {
          final type = PoseLandmarkType.values.firstWhere(
                (e) => e.toString().split('.').last == entry.key,
          );

          final target = entry.value;
          double x = target['x'] * size.width;
          double y = target['y'] * size.height;

          canvas.drawCircle(Offset(x, y), targetJointRadius, targetJointPaint);
          canvas.drawCircle(Offset(x, y), targetJointRadius, targetJointStrokePaint);
        } catch (e) {
          debugPrint("Error drawing target pose: $e");
        }
      }
    }

    for (final pose in poses) {
      void drawLine(PoseLandmarkType type1, PoseLandmarkType type2) {
        final landmark1 = pose.landmarks[type1];
        final landmark2 = pose.landmarks[type2];
        if (landmark1 == null || landmark2 == null) return;

        double x1 = landmark1.x * scaleX;
        double y1 = landmark1.y * scaleY;
        double x2 = landmark2.x * scaleX;
        double y2 = landmark2.y * scaleY;

        if (isFrontCamera) {
          x1 = size.width - x1;
          x2 = size.width - x2;
        }

        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
      }

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

      // Draw all joints
      for (final landmark in pose.landmarks.values) {
        double x = landmark.x * scaleX;
        double y = landmark.y * scaleY;

        if (isFrontCamera) {
          x = size.width - x;
        }

        canvas.drawCircle(Offset(x, y), jointRadius, jointPaint);
        canvas.drawCircle(Offset(x, y), jointRadius, jointStrokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}