import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:video_player/video_player.dart';
import '../services/music_service.dart';

class EndlessGameScreen extends StatefulWidget {
  final String userId;

  const EndlessGameScreen({
    super.key,
    required this.userId,
  });

  @override
  State<EndlessGameScreen> createState() => _EndlessGameScreenState();
}

class _EndlessGameScreenState extends State<EndlessGameScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  late PoseDetector _poseDetector;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  Size _imageSize = Size.zero;

  // Pose Detection
  bool _poseDetectionEnabled = true;
  int _noPoseDetectedCount = 0;

  // Alignment
  Alignment _bodyAlignment = Alignment.center;
  double _bodyScale = 1.0;
  bool _showAlignmentGuide = true;
  String _alignmentFeedback = "";
  bool _isPerfectlyAligned = false;

  // Endless Game State
  bool _isGameStarted = false;
  int _countdown = 3;
  Timer? _countdownTimer;
  Timer? _poseTimer;
  Timer? _speedTimer;

  // Scoring
  int _totalScore = 0;
  int _combo = 0;
  int _maxCombo = 0;
  String _feedbackText = "";
  Color _feedbackColor = Colors.white;
  Timer? _feedbackTimer;
  bool _showScoreAnimation = false;
  int _lastScoreIncrement = 0;

  // Current Pose Challenge
  Map<String, dynamic> _currentPose = {};
  int _poseTimeRemaining = 0;
  double _gameSpeed = 1.0;
  int _level = 1;
  int _posesCompleted = 0;
  bool _poseMatched = false;

  // Pose Database
  final List<Map<String, dynamic>> _poseChallenges = [
    {
      'name': 'ONE ARM UP',
      'description': 'Raise one arm straight up',
      'scoringLogic': _scoreOneArmUp,
      'baseScore': 100,
      'duration': 5,
    },
    {
      'name': 'BOTH ARMS UP',
      'description': 'Raise both arms straight up',
      'scoringLogic': _scoreBothArmsUp,
      'baseScore': 150,
      'duration': 4,
    },
    {
      'name': 'LEFT ARM SIDE',
      'description': 'Extend left arm to the side',
      'scoringLogic': _scoreLeftArmSide,
      'baseScore': 80,
      'duration': 4,
    },
    {
      'name': 'RIGHT ARM SIDE',
      'description': 'Extend right arm to the side',
      'scoringLogic': _scoreRightArmSide,
      'baseScore': 80,
      'duration': 4,
    },
    {
      'name': 'T-POSE',
      'description': 'Form a T shape with your arms',
      'scoringLogic': _scoreTPose,
      'baseScore': 200,
      'duration': 6,
    },
    {
      'name': 'HANDS ON HIPS',
      'description': 'Place both hands on your hips',
      'scoringLogic': _scoreHandsOnHips,
      'baseScore': 120,
      'duration': 4,
    },
    {
      'name': 'ONE LEG UP',
      'description': 'Lift one leg off the ground',
      'scoringLogic': _scoreOneLegUp,
      'baseScore': 180,
      'duration': 5,
    },
    {
      'name': 'ARMS CROSSED',
      'description': 'Cross your arms in front',
      'scoringLogic': _scoreArmsCrossed,
      'baseScore': 130,
      'duration': 4,
    },
    {
      'name': 'SQUAT POSE',
      'description': 'Go into a squat position',
      'scoringLogic': _scoreSquatPose,
      'baseScore': 220,
      'duration': 6,
    },
    {
      'name': 'STAR JUMP',
      'description': 'Jump into a star shape',
      'scoringLogic': _scoreStarJump,
      'baseScore': 250,
      'duration': 7,
    },
  ];

  // Video Player
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _showVideo = false;
  bool _isVideoPlaying = false;
  bool _videoError = false;
  Completer<void>? _videoInitializationCompleter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.accurate));

    // Pause menu music
    MusicService().pauseMusic(rememberToResume: false);
    _initializeVideo();
    _startCountdown();
  }

  void _initializeVideo() {
    // Use a generic dance video for endless mode
    const videoAsset = 'assets/videos/endless_dance.mp4'; // You'll need to add this

    _videoController = VideoPlayerController.asset(videoAsset);
    _videoController.addListener(_videoListener);

    _videoInitializationCompleter = Completer<void>();

    _videoController.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _isVideoInitialized = true;
      });
      _videoController.setLooping(true);
      _videoController.setVolume(0.0);

      if (!_videoInitializationCompleter!.isCompleted) {
        _videoInitializationCompleter!.complete();
      }
    }).catchError((error) {
      debugPrint("Video init error: $error");
      if (!mounted) return;
      setState(() {
        _isVideoInitialized = false;
        _videoError = true;
      });
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdown = 3;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _countdownTimer?.cancel();
          _startGame();
        }
      });
    });
  }

  void _startGame() async {
    MusicService().playGameMusic(danceId: 1); // Use generic game music

    setState(() {
      _isGameStarted = true;
      _totalScore = 0;
      _combo = 0;
      _maxCombo = 0;
      _level = 1;
      _posesCompleted = 0;
      _gameSpeed = 1.0;
    });

    _generateNewPose();
    _startSpeedIncreaseTimer();
  }

  void _generateNewPose() {
    final random = Random();
    _currentPose = _poseChallenges[random.nextInt(_poseChallenges.length)].cast<String, dynamic>();

    // Adjust duration based on game speed
    final baseDuration = _currentPose['duration'] as int;
    _poseTimeRemaining = (baseDuration / _gameSpeed).round();

    setState(() {
      _poseMatched = false;
      _showAlignmentGuide = true;
    });

    _poseTimer?.cancel();
    _poseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _poseTimeRemaining--;
      });

      if (_poseTimeRemaining <= 0) {
        _poseFailed();
        timer.cancel();
      }
    });
  }

  void _poseCompleted() {
    _poseTimer?.cancel();

    final baseScore = _currentPose['baseScore'] as int;
    final timeBonus = (_poseTimeRemaining * 10 * _gameSpeed).round();
    final comboBonus = _combo * 5;
    final levelBonus = _level * 20;

    final totalScore = baseScore + timeBonus + comboBonus + levelBonus;

    _addToScore(totalScore);
    _combo++;
    _maxCombo = max(_maxCombo, _combo);
    _posesCompleted++;

    _updateFeedback("Perfect! +$totalScore (Combo: $_combo)", Colors.green);

    // Level up every 5 poses
    if (_posesCompleted % 5 == 0) {
      _levelUp();
    }

    // Next pose after short delay
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _isGameStarted) {
        _generateNewPose();
      }
    });
  }

  void _poseFailed() {
    _combo = 0;
    _updateFeedback("Too slow! Next pose...", Colors.red);

    Timer(const Duration(milliseconds: 1000), () {
      if (mounted && _isGameStarted) {
        _generateNewPose();
      }
    });
  }

  void _levelUp() {
    _level++;
    _gameSpeed += 0.1; // Increase speed

    setState(() {
      _showScoreAnimation = true;
    });

    _updateFeedback("Level $_level! Speed increased!", Colors.cyan);

    Timer(const Duration(milliseconds: 2000), () {
      setState(() {
        _showScoreAnimation = false;
      });
    });
  }

  void _startSpeedIncreaseTimer() {
    _speedTimer?.cancel();
    _speedTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted || !_isGameStarted) {
        timer.cancel();
        return;
      }
      _gameSpeed += 0.05; // Gradual speed increase
    });
  }

  void _endGame() {
    _poseTimer?.cancel();
    _speedTimer?.cancel();
    _isGameStarted = false;

    MusicService().stopMusic();
    _videoController.pause();

    // Show game over dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Game Over!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Final Score: $_totalScore"),
            Text("Max Combo: $_maxCombo"),
            Text("Level Reached: $_level"),
            Text("Poses Completed: $_posesCompleted"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("MAIN MENU"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _restartGame();
            },
            child: const Text("PLAY AGAIN"),
          ),
        ],
      ),
    );
  }

  void _restartGame() {
    _startCountdown();
  }

  // ==================== SCORING FUNCTIONS ====================

  double get _alignmentMultiplier {
    final dx = _bodyAlignment.x.abs();
    final dy = _bodyAlignment.y.abs();
    final scale = _bodyScale;

    final okAligned = (dx <= 0.4 && dy <= 0.4 && scale >= 0.5 && scale <= 1.6);
    final offFrame = !(scale >= 0.4 && scale <= 1.8) || dx > 0.7 || dy > 0.7;

    if (offFrame) return 0.0;
    if (okAligned) return 0.6;
    return 0.3;
  }

  static void _scoreOneArmUp(Pose pose, Function(Pose) callback) {
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) {
      callback(pose);
      return;
    }

    final leftArmUp = leftWrist.y < leftShoulder.y - 30;
    final rightArmUp = rightWrist.y < rightShoulder.y - 30;

    // Only one arm should be up
    if (leftArmUp != rightArmUp) {
      callback(pose);
    }
  }

  static void _scoreBothArmsUp(Pose pose, Function(Pose) callback) {
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) return;

    final leftArmUp = leftWrist.y < leftShoulder.y - 30;
    final rightArmUp = rightWrist.y < rightShoulder.y - 30;

    if (leftArmUp && rightArmUp) {
      callback(pose);
    }
  }

  static void _scoreLeftArmSide(Pose pose, Function(Pose) callback) {
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];

    if (leftWrist == null || leftShoulder == null || leftElbow == null) return;

    final armExtended = (leftWrist.x - leftShoulder.x).abs() > 50;
    final elbowBent = (leftElbow.y - leftShoulder.y).abs() < 30;

    if (armExtended && !elbowBent) {
      callback(pose);
    }
  }

  static void _scoreRightArmSide(Pose pose, Function(Pose) callback) {
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];

    if (rightWrist == null || rightShoulder == null || rightElbow == null) return;

    final armExtended = (rightWrist.x - rightShoulder.x).abs() > 50;
    final elbowBent = (rightElbow.y - rightShoulder.y).abs() < 30;

    if (armExtended && !elbowBent) {
      callback(pose);
    }
  }

  static void _scoreTPose(Pose pose, Function(Pose) callback) {
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) return;

    final leftArmExtended = (leftWrist.x - leftShoulder.x).abs() > 40;
    final rightArmExtended = (rightWrist.x - rightShoulder.x).abs() > 40;
    final armsLevel = (leftWrist.y - rightWrist.y).abs() < 30;

    if (leftArmExtended && rightArmExtended && armsLevel) {
      callback(pose);
    }
  }

  static void _scoreHandsOnHips(Pose pose, Function(Pose) callback) {
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftWrist == null || rightWrist == null || leftHip == null || rightHip == null) return;

    final leftHandOnHip = _distance(leftWrist, leftHip) < 50;
    final rightHandOnHip = _distance(rightWrist, rightHip) < 50;

    if (leftHandOnHip && rightHandOnHip) {
      callback(pose);
    }
  }

  static void _scoreOneLegUp(Pose pose, Function(Pose) callback) {
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];

    if (leftAnkle == null || rightAnkle == null || leftKnee == null || rightKnee == null) return;

    final leftLegUp = (leftAnkle.y - leftKnee.y).abs() > 30;
    final rightLegUp = (rightAnkle.y - rightKnee.y).abs() > 30;

    if (leftLegUp != rightLegUp) {
      callback(pose);
    }
  }

  static void _scoreArmsCrossed(Pose pose, Function(Pose) callback) {
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftWrist == null || rightWrist == null) return;

    final wristsClose = _distance(leftWrist, rightWrist) < 50;

    if (wristsClose) {
      callback(pose);
    }
  }

  static void _scoreSquatPose(Pose pose, Function(Pose) callback) {
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftKnee == null || rightKnee == null || leftHip == null || rightHip == null) return;

    final kneesBent = (leftKnee.y - leftHip.y).abs() < 50 && (rightKnee.y - rightHip.y).abs() < 50;

    if (kneesBent) {
      callback(pose);
    }
  }

  static void _scoreStarJump(Pose pose, Function(Pose) callback) {
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null || leftAnkle == null || rightAnkle == null) return;

    final armsSpread = (leftWrist.x - rightWrist.x).abs() > 100;
    final legsSpread = (leftAnkle.x - rightAnkle.x).abs() > 80;
    final armsUp = leftWrist.y < leftShoulder!.y && rightWrist.y < rightShoulder!.y;

    if (armsSpread && legsSpread && armsUp) {
      callback(pose);
    }
  }

  static double _distance(PoseLandmark a, PoseLandmark b) {
    return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
  }

  void _addToScore(int points) {
    setState(() {
      _totalScore += points;
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

  void _updateFeedback(String text, Color color) {
    setState(() {
      _feedbackText = text;
      _feedbackColor = color;
    });

    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _feedbackText = "";
        });
      }
    });
  }

  // ==================== CAMERA AND POSE DETECTION ====================

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
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy || !mounted || !_isGameStarted || !_poseDetectionEnabled) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        _noPoseDetectedCount = 0;
        final pose = poses.first;

        if (_isGameStarted && _currentPose.isNotEmpty) {
          final scoringLogic = _currentPose['scoringLogic'] as Function;
          scoringLogic(pose, (matchedPose) {
            if (!_poseMatched) {
              _poseMatched = true;
              _poseCompleted();
            }
          });
        }
      } else {
        _noPoseDetectedCount++;
        if (_noPoseDetectedCount > 10) {
          _updateFeedback("Can't see you!", Colors.red);
        }
      }
    } catch (e) {
      debugPrint("Pose detection error: $e");
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

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      debugPrint("InputImage error: $e");
      return null;
    }
  }

  void _videoListener() {
    if (_videoController.value.hasError) {
      setState(() {
        _videoError = true;
        _isVideoPlaying = false;
      });
    } else if (_videoController.value.isPlaying) {
      setState(() {
        _isVideoPlaying = true;
        _videoError = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _poseDetector.close();
    _countdownTimer?.cancel();
    _poseTimer?.cancel();
    _speedTimer?.cancel();
    _feedbackTimer?.cancel();
    _videoController.dispose();
    MusicService().stopMusic();
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
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera Preview
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

          // Game UI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Score and Level
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Score: $_totalScore",
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.yellow,
                              shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                            ),
                          ),
                          Text(
                            "Level: $_level",
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.cyan,
                              shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                            ),
                          ),
                        ],
                      ),

                      // Combo and Speed
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "Combo: $_combo",
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.orange,
                              shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                            ),
                          ),
                          Text(
                            "Speed: ${_gameSpeed.toStringAsFixed(1)}x",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Current Pose Challenge
                  if (_isGameStarted && _currentPose.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _currentPose['name'],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _currentPose['description'],
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _poseTimeRemaining / (_currentPose['duration'] / _gameSpeed),
                            backgroundColor: Colors.grey,
                            valueColor: AlwaysStoppedAnimation(
                              _poseTimeRemaining > 3 ? Colors.green :
                              _poseTimeRemaining > 1 ? Colors.orange : Colors.red,
                            ),
                          ),
                          Text(
                            "$_poseTimeRemaining",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Countdown
          if (!_isGameStarted)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _countdown.toString(),
                    style: const TextStyle(
                      fontSize: 100,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                  ),
                  const Text(
                    "Endless Dance Mode!",
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 5, color: Colors.black)],
                    ),
                  ),
                ],
              ),
            ),

          // Feedback
          if (_feedbackText.isNotEmpty)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child:
                Container(
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
            ),

          // Score Animation
          if (_showScoreAnimation)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "+$_lastScoreIncrement",
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.yellow,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
              ),
            ),
        ],
      ),

      // Exit Button
      floatingActionButton: FloatingActionButton(
        onPressed: _endGame,
        backgroundColor: Colors.red,
        child: const Icon(Icons.exit_to_app),
      ),
    );
  }
}
