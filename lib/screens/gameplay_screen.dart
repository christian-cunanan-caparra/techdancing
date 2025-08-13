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
  double _minScale = 1.0;
  Offset _offset = Offset.zero;

  // Game state variables
  bool _isGameStarted = false;
  int _currentStep = 0;
  List<Map<String, dynamic>> _danceSteps = [];
  List<Pose> _previousPoses = [];
  int _countdown = 3;
  late Timer _countdownTimer;
  late Timer _gameTimer;
  int _timeRemaining = 60;
  final double _smoothingFactor = 0.3;

  // Scoring variables
  int _totalScore = 0;
  int _currentStepScore = 0;
  String _feedbackText = "";
  Color _feedbackColor = Colors.white;
  Timer? _feedbackTimer;
  List<int> _stepScores = [];
  bool _showScoreAnimation = false;
  int _lastScoreIncrement = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.accurate));
    _loadDanceSteps();
    _startCountdown();
  }

  void _loadDanceSteps() {
    _danceSteps = [
      {
        'name': 'Sumabay Ka',
        'description': 'Arms swaying side to side with small steps',
        'duration': 8,
        'originalDuration': 8,
        'lyrics': 'Sumabay ka nalang\nWag kang mahihiya\nSige subukan mo\nBaka may mapala',
        'scoringLogic': _scoreSumabayKa,
      },
      {
        'name': 'Chacha Step',
        'description': 'Side chacha steps with arm swings',
        'duration': 8,
        'originalDuration': 8,
        'lyrics': 'Walang mawawala\nKapag nagchachaga\nKung gustong gusto mo\nSundan mo lang ako',
        'scoringLogic': _scoreChachaStep,
      },
      {
        'name': 'Jumbo Hotdog Pose',
        'description': 'Arms wide open then pointing forward',
        'duration': 16,
        'originalDuration': 16,
        'lyrics': '[jumbo hotdog\nKaya mo ba to?\nKaya mo ba to?\nKaya mo ba to?]',
        'scoringLogic': _scoreJumboHotdogPose,
      },
      {
        'name': 'Final Pose',
        'description': 'Hands on hips with confident stance',
        'duration': 8,
        'originalDuration': 8,
        'lyrics': 'Jumbo hotdog\nKaya mo ba to?\nHindi kami ba to\nPara magpatalo',
        'scoringLogic': _scoreFinalPose,
      },
    ];
    _stepScores = List.filled(_danceSteps.length, 0);
  }

  // Scoring functions for each dance step
  void _scoreSumabayKa(Pose pose) {
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) {
      _updateFeedback("Show your arms!", Colors.orange);
      _currentStepScore = max(_currentStepScore - 10, 0);
      return;
    }

    // Check if arms are moving side to side (alternating up/down)
    final leftArmUp = leftWrist.y < leftShoulder.y;
    final rightArmUp = rightWrist.y < rightShoulder.y;

    // Should be alternating - one arm up, one arm down
    if (leftArmUp != rightArmUp) {
      final score = 100 + Random().nextInt(50); // Base score + random bonus
      _addToScore(score);
      _updateFeedback("Perfect sway! +$score", Colors.green);
    } else {
      _updateFeedback("Alternate your arms!", Colors.orange);
      _currentStepScore = max(_currentStepScore - 20, 0);
    }
  }

  void _scoreChachaStep(Pose pose) {
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftElbow == null || rightElbow == null || leftShoulder == null || rightShoulder == null) {
      _updateFeedback("Show your arms!", Colors.orange);
      _currentStepScore = max(_currentStepScore - 10, 0);
      return;
    }

    // Check if elbows are bent (arms swinging)
    final leftArmAngle = _calculateAngle(leftShoulder, leftElbow, leftWrist!);
    final rightArmAngle = _calculateAngle(rightShoulder, rightElbow, rightWrist!);

    // Arms should be bent between 60-120 degrees for chacha
    if ((leftArmAngle > 60 && leftArmAngle < 120) ||
        (rightArmAngle > 60 && rightArmAngle < 120)) {
      final score = 150 + Random().nextInt(50);
      _addToScore(score);
      _updateFeedback("Great arm swing! +$score", Colors.green);
    } else {
      _updateFeedback("Bend your arms more!", Colors.orange);
      _currentStepScore = max(_currentStepScore - 15, 0);
    }
  }

  void _scoreJumboHotdogPose(Pose pose) {
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) {
      _updateFeedback("Show your arms!", Colors.orange);
      _currentStepScore = max(_currentStepScore - 10, 0);
      return;
    }

    // Check if arms are wide open (wrist higher than shoulders and wide)
    final armsWide = (leftWrist.x < leftShoulder.x - 50 && rightWrist.x > rightShoulder.x + 50) ||
        (leftWrist.x > leftShoulder.x + 50 && rightWrist.x < rightShoulder.x - 50);

    final armsUp = leftWrist.y < leftShoulder.y && rightWrist.y < rightShoulder.y;

    if (armsWide && armsUp) {
      final score = 200 + Random().nextInt(100);
      _addToScore(score);
      _updateFeedback("JUMBO HOTDOG! +$score", Colors.green);
    } else if (armsUp) {
      _updateFeedback("Wider arms!", Colors.orange);
      _addToScore(50);
    } else {
      _updateFeedback("Arms up and wide!", Colors.orange);
      _currentStepScore = max(_currentStepScore - 10, 0);
    }
  }

  void _scoreFinalPose(Pose pose) {
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftWrist == null || rightWrist == null || leftHip == null || rightHip == null) {
      _updateFeedback("Show your hands!", Colors.orange);
      _currentStepScore = max(_currentStepScore - 10, 0);
      return;
    }

    // Check if hands are on hips (close to hip landmarks)
    final leftHandOnHip = _distance(leftWrist, leftHip) < 50;
    final rightHandOnHip = _distance(rightWrist, rightHip) < 50;

    if (leftHandOnHip && rightHandOnHip) {
      final score = 250 + Random().nextInt(150);
      _addToScore(score);
      _updateFeedback("Perfect final pose! +$score", Colors.green);
    } else if (leftHandOnHip || rightHandOnHip) {
      _updateFeedback("Both hands on hips!", Colors.orange);
      _addToScore(80);
    } else {
      _updateFeedback("Hands on hips!", Colors.orange);
      _currentStepScore = max(_currentStepScore - 10, 0);
    }
  }

  void _addToScore(int points) {
    setState(() {
      _currentStepScore = min(_currentStepScore + points, 1000);
      _lastScoreIncrement = points;
      _showScoreAnimation = true;
    });

    Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showScoreAnimation = false;
        });
      }
    });
  }

  // Helper function to calculate angle between three points
  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final baX = a.x - b.x;
    final baY = a.y - b.y;
    final bcX = c.x - b.x;
    final bcY = c.y - b.y;

    final dotProduct = (baX * bcX) + (baY * bcY);
    final magBA = sqrt(baX * baX + baY * baY);
    final magBC = sqrt(bcX * bcX + bcY * bcY);

    final angle = acos(dotProduct / (magBA * magBC));
    return angle * (180 / pi);
  }

  // Helper function to calculate distance between two landmarks
  double _distance(PoseLandmark a, PoseLandmark b) {
    return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
  }

  void _updateFeedback(String text, Color color) {
    setState(() {
      _feedbackText = text;
      _feedbackColor = color;
    });

    // Clear feedback after 2 seconds
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _feedbackText = "";
        });
      }
    });
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
      _timeRemaining = 60;
      _totalScore = 0;
      _currentStepScore = 0;
      _stepScores = List.filled(_danceSteps.length, 0);
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
    // Save the current step score before moving on
    _stepScores[_currentStep] = _currentStepScore;
    _totalScore += _currentStepScore;

    if (_currentStep < _danceSteps.length - 1) {
      setState(() {
        _currentStep++;
        _currentStepScore = 0;
        _danceSteps[_currentStep]['duration'] = _danceSteps[_currentStep]['originalDuration'];
      });
    } else {
      _endGame();
    }
  }

  void _endGame() {
    _gameTimer.cancel();

    // Calculate final score
    final maxPossibleScore = _danceSteps.length * 1000;
    final percentage = (_totalScore / maxPossibleScore * 100).round();

    String resultText;
    Color resultColor;

    if (percentage >= 90) {
      resultText = "PERFECT! ($percentage%)";
      resultColor = Colors.cyanAccent;
    } else if (percentage >= 70) {
      resultText = "VERY GOOD! ($percentage%)";
      resultColor = Colors.green;
    } else if (percentage >= 50) {
      resultText = "GOOD ($percentage%)";
      resultColor = Colors.yellow;
    } else {
      resultText = "TRY AGAIN ($percentage%)";
      resultColor = Colors.orange;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Game Over"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Total Score: $_totalScore",
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 10),
            Text(
              resultText,
              style: TextStyle(
                fontSize: 20,
                color: resultColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ..._danceSteps.asMap().entries.map((entry) {
              final idx = entry.key;
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(step['name']),
                    Text("${_stepScores[idx]} pts"),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    ).then((_) => Navigator.pop(context));
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCam = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(frontCam, ResolutionPreset.medium, enableAudio: false);
      await _controller!.initialize();

      if (!mounted) return;

      // Get the actual image size from the camera (swap width/height for portrait)
      _imageSize = Size(
        _controller!.value.previewSize!.height,
        _controller!.value.previewSize!.width,
      );

      final screenSize = MediaQuery.of(context).size;

      // Calculate scaling factors to fill the screen while maintaining aspect ratio
      double scaleX = screenSize.width / _imageSize.width;
      double scaleY = screenSize.height / _imageSize.height;

      // Use the larger scale to fill the screen
      _minScale = max(scaleX, scaleY);
      _scaleX = _minScale;
      _scaleY = _minScale;

      // Calculate offset to center the image
      _offset = Offset(
        (screenSize.width - (_imageSize.width * _minScale)) / 2,
        (screenSize.height - (_imageSize.height * _minScale)) / 2,
      );

      _controller!.startImageStream(_processCameraImage);
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint("Camera error: $e");
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

    if (_previousPoses.length > 5) {
      _previousPoses.removeAt(0);
    }

    return smoothedPose;
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy || !mounted || !_isGameStarted) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        final smoothedPose = _smoothPose(poses.first);

        // Score the current pose based on the current dance step
        if (_isGameStarted && _currentStep < _danceSteps.length) {
          _danceSteps[_currentStep]['scoringLogic'](smoothedPose);
        }

        _customPaint = CustomPaint(
          painter: PosePainter(
            [smoothedPose],
            _imageSize,
            _controller!.description.lensDirection == CameraLensDirection.front,
            scaleX: _scaleX,
            scaleY: _scaleY,
            offset: _offset,
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
    _feedbackTimer?.cancel();
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

    return Scaffold(
      body: Stack(
        children: [
          // Full screen camera preview with skeleton overlay
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _imageSize.width,
                height: _imageSize.height,
                child: Stack(
                  children: [
                    CameraPreview(_controller!),
                    if (_customPaint != null)
                      Transform.translate(
                        offset: _offset,
                        child: Transform.scale(
                          scale: _minScale,
                          child: _customPaint!,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Game UI overlay
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "$_timeRemaining s",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          AnimatedOpacity(
                            opacity: _showScoreAnimation ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              "+$_lastScoreIncrement",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyanAccent,
                              ),
                            ),
                          ),
                        ],
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
                          const SizedBox(height: 10),
                          Text(
                            "Score: $_currentStepScore/1000",
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  if (_feedbackText.isNotEmpty)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _feedbackText,
                          style: TextStyle(
                            fontSize: 20,
                            color: _feedbackColor,
                            fontWeight: FontWeight.bold,
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
}

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final bool isFrontCamera;
  final double scaleX;
  final double scaleY;
  final Offset offset;

  PosePainter(
      this.poses,
      this.imageSize,
      this.isFrontCamera, {
        required this.scaleX,
        required this.scaleY,
        required this.offset,
      });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.8)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()
      ..color = Colors.cyan.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final jointStrokePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const jointRadius = 8.0;

    for (final pose in poses) {
      // Helper function to get properly scaled and mirrored offset
      Offset getOffset(PoseLandmark? landmark) {
        if (landmark == null) return Offset.zero;

        double x = landmark.x;
        double y = landmark.y;

        // Mirror only the x-coordinate for front camera
        if (isFrontCamera) {
          x = imageSize.width - x;
        }

        // Adjust position to be more top and right
        return Offset(
          x * 1.15,
          y * 0.8,
        );
      }

      void drawLine(PoseLandmarkType type1, PoseLandmarkType type2) {
        final landmark1 = pose.landmarks[type1];
        final landmark2 = pose.landmarks[type2];
        if (landmark1 == null || landmark2 == null) return;

        final offset1 = getOffset(landmark1);
        final offset2 = getOffset(landmark2);

        canvas.drawLine(offset1, offset2, linePaint);
      }

      // Draw all the connections first
      // Torso
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

      // Left arm
      drawLine(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      drawLine(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);

      // Right arm
      drawLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      drawLine(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

      // Left legs
      drawLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      drawLine(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);

      // Right leg
      drawLine(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      drawLine(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

      // Draw all joints after connections so they appear on top
      for (final landmark in pose.landmarks.values) {
        final offset = getOffset(landmark);
        canvas.drawCircle(offset, jointRadius, jointPaint);
        canvas.drawCircle(offset, jointRadius, jointStrokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}