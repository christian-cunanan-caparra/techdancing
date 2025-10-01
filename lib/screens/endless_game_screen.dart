import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:video_player/video_player.dart';
import '../services/music_service.dart';
import '../services/api_service.dart';
import 'endless_game_result_screen.dart';

class EndlessGameScreen extends StatefulWidget {
  final String userId;
  final bool useCustomPoses;

  const EndlessGameScreen({
    super.key,
    required this.userId,
    this.useCustomPoses = false,
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
  Pose? _lastDetectedPose;
  Timer? _poseStabilityTimer;

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
  Timer? _gameTimer;

  // Game Timer
  int _gameTimeRemaining = 60; // 60 seconds total game time
  int _totalGameTime = 60;

  // Scoring
  int _totalScore = 0;
  int _combo = 0;
  int _maxCombo = 0;
  String _feedbackText = "";
  Color _feedbackColor = Colors.white;
  Timer? _feedbackTimer;
  bool _showScoreAnimation = false;
  int _lastScoreIncrement = 0;
  bool _showTimeAnimation = false;
  int _lastTimeChange = 0;
  bool _isTimeBonus = false;

  // Current Pose Challenge
  Map<String, dynamic> _currentPose = {};
  int _poseTimeRemaining = 0;
  int _basePoseDuration = 10; // Base duration that decreases with levels
  double _gameSpeed = 1.0;
  int _level = 1;
  int _posesCompleted = 0;
  bool _poseMatched = false;
  bool _poseCurrentlyHeld = false;
  int _poseHoldTime = 0;
  bool _poseCompletedEarly = false;

  // Pose Database
  List<Map<String, dynamic>> _poseChallenges = [];
  List<Map<String, dynamic>> _customPoses = [];
  bool _isLoadingPoses = false;

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
    _loadPoses();
  }

  Future<void> _loadPoses() async {
    setState(() {
      _isLoadingPoses = true;
    });

    if (widget.useCustomPoses) {
      // Load custom poses from user's dances
      await _loadCustomPoses();
    } else {
      // Use normal random poses
      _poseChallenges = _getNormalPoseChallenges();
    }

    setState(() {
      _isLoadingPoses = false;
    });

    if (_poseChallenges.isNotEmpty) {
      _startCountdown();
    } else {
      _showError('No poses available for this mode');
    }
  }

  Future<void> _loadCustomPoses() async {
    try {
      // Get user's custom dances
      final dancesResult = await ApiService.getCustomDances(widget.userId);

      if (dancesResult['status'] == 'success') {
        final dances = List<Map<String, dynamic>>.from(dancesResult['dances'] ?? []);
        _customPoses.clear();

        // Extract poses from all custom dances
        for (final dance in dances) {
          final stepsResult = await ApiService.getCustomDanceSteps(dance['id'].toString());
          if (stepsResult['status'] == 'success') {
            final steps = List<Map<String, dynamic>>.from(stepsResult['steps'] ?? []);

            for (final step in steps) {
              // Convert custom step to pose challenge format
              final poseChallenge = _convertStepToPoseChallenge(step, dance['name']);
              _customPoses.add(poseChallenge);
            }
          }
        }

        // Use custom poses or fallback to normal poses
        _poseChallenges = _customPoses.isNotEmpty ? _customPoses : _getNormalPoseChallenges();
      } else {
        // Fallback to normal poses if error
        _poseChallenges = _getNormalPoseChallenges();
      }
    } catch (e) {
      debugPrint('Error loading custom poses: $e');
      // Fallback to normal poses
      _poseChallenges = _getNormalPoseChallenges();
    }
  }

  Map<String, dynamic> _convertStepToPoseChallenge(Map<String, dynamic> step, String danceName) {
    // Extract pose data and create a pose challenge
    final poseData = step['pose_data'] ?? {};

    return {
      'name': step['name'] ?? 'Custom Pose',
      'description': step['description'] ?? 'From: $danceName',
      'scoringLogic': _createCustomScoringLogic(poseData),
      'baseScore': 150, // Higher base score for custom poses
      'poseData': poseData,
      'isCustom': true,
    };
  }

  Function _createCustomScoringLogic(Map<String, dynamic> poseData) {
    // Create a generic scoring logic for custom poses based on pose data
    return (Pose pose, Function(Pose) callback) {
      // Simple confidence-based scoring for custom poses
      double totalConfidence = 0.0;
      int landmarkCount = 0;

      for (final landmark in pose.landmarks.values) {
        totalConfidence += landmark.likelihood;
        landmarkCount++;
      }

      if (landmarkCount > 0) {
        final averageConfidence = totalConfidence / landmarkCount;

        // Trigger callback if confidence is high enough
        if (averageConfidence > 0.7) {
          callback(pose);
        }
      }
    };
  }

  List<Map<String, dynamic>> _getNormalPoseChallenges() {
    return [
      {
        'name': 'ONE ARM UP',
        'description': 'Raise one arm straight up',
        'scoringLogic': _scoreOneArmUp,
        'baseScore': 100,
        'isCustom': false,
      },
      {
        'name': 'BOTH ARMS UP',
        'description': 'Raise both arms straight up',
        'scoringLogic': _scoreBothArmsUp,
        'baseScore': 150,
        'isCustom': false,
      },
      {
        'name': 'LEFT ARM SIDE',
        'description': 'Extend left arm to the side',
        'scoringLogic': _scoreLeftArmSide,
        'baseScore': 80,
        'isCustom': false,
      },
      {
        'name': 'RIGHT ARM SIDE',
        'description': 'Extend right arm to the side',
        'scoringLogic': _scoreRightArmSide,
        'baseScore': 80,
        'isCustom': false,
      },
      {
        'name': 'T-POSE',
        'description': 'Form a T shape with your arms',
        'scoringLogic': _scoreTPose,
        'baseScore': 200,
        'isCustom': false,
      },
      {
        'name': 'HANDS ON HIPS',
        'description': 'Place both hands on your hips',
        'scoringLogic': _scoreHandsOnHips,
        'baseScore': 120,
        'isCustom': false,
      },
      {
        'name': 'ONE LEG UP',
        'description': 'Lift one leg off the ground',
        'scoringLogic': _scoreOneLegUp,
        'baseScore': 180,
        'isCustom': false,
      },
      {
        'name': 'ARMS CROSSED',
        'description': 'Cross your arms in front',
        'scoringLogic': _scoreArmsCrossed,
        'baseScore': 130,
        'isCustom': false,
      },
      {
        'name': 'SQUAT POSE',
        'description': 'Go into a squat position',
        'scoringLogic': _scoreSquatPose,
        'baseScore': 220,
        'isCustom': false,
      },
      {
        'name': 'STAR JUMP',
        'description': 'Jump into a star shape',
        'scoringLogic': _scoreStarJump,
        'baseScore': 250,
        'isCustom': false,
      },
    ];
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
    MusicService().playGameMusic(danceId: 1);

    setState(() {
      _isGameStarted = true;
      _totalScore = 0;
      _combo = 0;
      _maxCombo = 0;
      _level = 1;
      _posesCompleted = 0;
      _gameSpeed = 1.0;
      _basePoseDuration = 10; // Reset to 10 seconds for level 1
      _gameTimeRemaining = _totalGameTime;
    });

    _generateNewPose();
    _startGameTimer();
    _startSpeedIncreaseTimer();
  }

  void _startGameTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _gameTimeRemaining--;
      });

      if (_gameTimeRemaining <= 0) {
        _gameTimer?.cancel();
        _endGame();
      }
    });
  }

  void _addTimeToGame(int seconds) {
    setState(() {
      _gameTimeRemaining += seconds;
      _lastTimeChange = seconds;
      _showTimeAnimation = true;
      _isTimeBonus = seconds > 0;
    });

    Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _showTimeAnimation = false;
        });
      }
    });
  }

  void _generateNewPose() {
    if (_poseChallenges.isEmpty) {
      _showError('No poses available');
      return;
    }

    final random = Random();
    _currentPose = _poseChallenges[random.nextInt(_poseChallenges.length)].cast<String, dynamic>();

    // Calculate pose duration based on level (gets faster each level)
    _basePoseDuration = (10 / _gameSpeed).round().clamp(3, 10); // Minimum 3 seconds, max 10
    _poseTimeRemaining = _basePoseDuration;

    setState(() {
      _poseMatched = false;
      _poseCurrentlyHeld = false;
      _poseHoldTime = 0;
      _poseCompletedEarly = false;
      _showAlignmentGuide = true;
    });

    _poseTimer?.cancel();
    _poseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _poseTimeRemaining--;
      });

      // Pose failed - time ran out
      if (_poseTimeRemaining <= 0) {
        _poseFailed();
        timer.cancel();
      }
    });
  }

  void _poseCompleted() {
    _poseTimer?.cancel();

    final baseScore = _currentPose['baseScore'] as int;
    final timeBonus = (_poseTimeRemaining * 5 * _gameSpeed).round();
    final comboBonus = _combo * 10;
    final levelBonus = _level * 20;
    final customBonus = _currentPose['isCustom'] == true ? 50 : 0;
    final holdBonus = _poseHoldTime * 2;

    // +6 BONUS for completing before time runs out!
    final earlyCompletionBonus = _poseCompletedEarly ? 6 : 0;

    final totalScore = baseScore + timeBonus + comboBonus + levelBonus + customBonus + holdBonus + earlyCompletionBonus;

    _addToScore(totalScore);

    // +5 SECONDS to game timer for completing pose!
    _addTimeToGame(5);

    _combo++;
    _maxCombo = max(_maxCombo, _combo);
    _posesCompleted++;

    final modePrefix = widget.useCustomPoses ? 'Custom ' : '';
    final earlyBonusText = _poseCompletedEarly ? " +6 Early Bonus!" : "";
    _updateFeedback("${modePrefix}Perfect! +$totalScore +5s! (Combo: $_combo)$earlyBonusText", Colors.green);

    // Level up every 5 poses
    if (_posesCompleted % 5 == 0) {
      _levelUp();
    }

    // Next pose after short delay
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted && _isGameStarted && _gameTimeRemaining > 0) {
        _generateNewPose();
      }
    });
  }

  void _poseFailed() {
    // -3 PENALTY for not completing the pose!
    if (_totalScore >= 3) {
      setState(() {
        _totalScore -= 3;
      });
    }

    // -5 SECONDS from game timer for failing pose!
    _addTimeToGame(-5);

    _combo = 0;

    _updateFeedback("-3 points! -5s! Too slow!", Colors.red);

    Timer(const Duration(milliseconds: 1000), () {
      if (mounted && _isGameStarted && _gameTimeRemaining > 0) {
        _generateNewPose();
      }
    });
  }

  void _levelUp() {
    _level++;
    _gameSpeed += 0.2; // Increased speed boost per level

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
      if (!mounted || !_isGameStarted || _gameTimeRemaining <= 0) {
        timer.cancel();
        return;
      }
      _gameSpeed += 0.05;
    });
  }

  void _endGame() {
    _poseTimer?.cancel();
    _speedTimer?.cancel();
    _gameTimer?.cancel();
    _poseStabilityTimer?.cancel();
    _isGameStarted = false;

    MusicService().stopMusic();
    _videoController.pause();

    // Navigate to result screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => EndlessGameResultScreen(
          totalScore: _totalScore,
          maxCombo: _maxCombo,
          levelReached: _level,
          posesCompleted: _posesCompleted,
          customPosesCount: _customPoses.length,
          useCustomPoses: widget.useCustomPoses,
        ),
      ),
    );
  }

  Widget _buildScoreRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _restartGame() {
    _startCountdown();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==================== SCORING FUNCTIONS ====================

  static void _scoreOneArmUp(Pose pose, Function(Pose) callback) {
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) {
      return;
    }

    final leftArmUp = leftWrist.y < leftShoulder.y - 30;
    final rightArmUp = rightWrist.y < rightShoulder.y - 30;

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

  bool _isPoseStable(Pose currentPose, Pose? lastPose) {
    if (lastPose == null) return false;

    double totalMovement = 0.0;
    int landmarkCount = 0;

    for (final type in currentPose.landmarks.keys) {
      final currentLandmark = currentPose.landmarks[type];
      final lastLandmark = lastPose.landmarks[type];

      if (currentLandmark != null && lastLandmark != null) {
        totalMovement += _distance(currentLandmark, lastLandmark);
        landmarkCount++;
      }
    }

    if (landmarkCount == 0) return false;

    final averageMovement = totalMovement / landmarkCount;
    return averageMovement < 5.0; // Threshold for stability
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
    if (_isBusy || !mounted || !_isGameStarted || !_poseDetectionEnabled || _gameTimeRemaining <= 0) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        _noPoseDetectedCount = 0;
        final currentPose = poses.first;

        // Check pose stability
        if (_lastDetectedPose != null && _isPoseStable(currentPose, _lastDetectedPose)) {
          // Pose is stable, check if it matches the current challenge
          if (_isGameStarted && _currentPose.isNotEmpty && !_poseMatched) {
            final scoringLogic = _currentPose['scoringLogic'] as Function;
            scoringLogic(currentPose, (matchedPose) {
              if (!_poseMatched) {
                _poseMatched = true;
                _poseCurrentlyHeld = true;
                _poseHoldTime++;

                // Check if completed early (before last 2 seconds)
                _poseCompletedEarly = _poseTimeRemaining > 2;

                _poseCompleted();
              }
            });
          } else if (_poseCurrentlyHeld) {
            // Continue holding the pose for bonus
            _poseHoldTime++;
          }
        } else {
          // Pose is not stable, reset holding state
          _poseCurrentlyHeld = false;
        }

        _lastDetectedPose = currentPose;
      } else {
        _noPoseDetectedCount++;
        if (_noPoseDetectedCount > 10) {
          _updateFeedback("Can't see you!", Colors.red);
        }
        _poseCurrentlyHeld = false;
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

  void _initializeVideo() {
    // Use a generic dance video for endless mode
    const videoAsset = 'assets/videos/endless_dance.mp4';

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
    _gameTimer?.cancel();
    _feedbackTimer?.cancel();
    _poseStabilityTimer?.cancel();
    _videoController.dispose();
    MusicService().stopMusic();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _isLoadingPoses) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                _isLoadingPoses
                    ? "Loading ${widget.useCustomPoses ? 'Custom' : 'Normal'} Poses..."
                    : "Initializing camera...",
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              if (widget.useCustomPoses && _isLoadingPoses)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    "Using your created poses",
                    style: TextStyle(color: Colors.purpleAccent, fontSize: 14),
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
                  // Mode Indicator and Score
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.useCustomPoses ? Colors.purple : Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.useCustomPoses ? "CUSTOM" : "NORMAL",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
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

                      // Combo, Speed and Timer
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Game Timer - Big and prominent
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _gameTimeRemaining > 10 ? Colors.green :
                                _gameTimeRemaining > 5 ? Colors.orange : Colors.red,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  "$_gameTimeRemaining",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _gameTimeRemaining > 10 ? Colors.green :
                                    _gameTimeRemaining > 5 ? Colors.orange : Colors.red,
                                    shadows: [const Shadow(blurRadius: 5, color: Colors.black)],
                                  ),
                                ),
                                if (_showTimeAnimation)
                                  Text(
                                    _isTimeBonus ? "+$_lastTimeChange" : "$_lastTimeChange",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _isTimeBonus ? Colors.green : Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
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
                          Text(
                            "Pose Time: $_basePoseDuration",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              shadows: [Shadow(blurRadius: 3, color: Colors.black)],
                            ),
                          ),
                          if (widget.useCustomPoses && _customPoses.isNotEmpty)
                            Text(
                              "Poses: ${_customPoses.length}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.purpleAccent,
                                shadows: [Shadow(blurRadius: 3, color: Colors.black)],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Current Pose Challenge
                  if (_isGameStarted && _currentPose.isNotEmpty && _gameTimeRemaining > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _currentPose['isCustom'] == true ? Colors.purpleAccent : Colors.blue,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_currentPose['isCustom'] == true)
                                const Icon(Icons.star, color: Colors.purpleAccent, size: 16),
                              Text(
                                _currentPose['name'],
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
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
                            value: _poseTimeRemaining / _basePoseDuration,
                            backgroundColor: Colors.grey,
                            valueColor: AlwaysStoppedAnimation(
                              _poseTimeRemaining > (_basePoseDuration * 0.7) ? Colors.green :
                              _poseTimeRemaining > (_basePoseDuration * 0.3) ? Colors.orange : Colors.red,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Time: $_poseTimeRemaining",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                "Complete: +5s | Fail: -5s",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.yellow,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
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
                    style: TextStyle(
                      fontSize: 100,
                      fontWeight: FontWeight.bold,
                      color: widget.useCustomPoses ? Colors.purpleAccent : Colors.cyanAccent,
                      shadows: [const Shadow(blurRadius: 10, color: Colors.black)],
                    ),
                  ),
                  Text(
                    widget.useCustomPoses ? "Custom Pose Mode!" : "Endless Dance Mode!",
                    style: const TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      shadows: [const Shadow(blurRadius: 5, color: Colors.black)],
                    ),
                  ),
                  if (widget.useCustomPoses)
                    const Text(
                      "Using your created poses",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.purpleAccent,
                        shadows: [const Shadow(blurRadius: 3, color: Colors.black)],
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
                    shadows: [const Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
              ),
            ),

          // Time Change Animation
          if (_showTimeAnimation)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _isTimeBonus ? "+$_lastTimeChange SECONDS!" : "$_lastTimeChange SECONDS!",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: _isTimeBonus ? Colors.green : Colors.red,
                    shadows: [const Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}