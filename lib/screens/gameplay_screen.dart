import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../services/music_service.dart';
import 'game_result_screen.dart';

typedef ScoreFn = void Function(Pose pose);

class GameplayScreen extends StatefulWidget {
  final int danceId;
  final String roomCode;
  final String userId;

  const GameplayScreen({
    super.key,
    required this.danceId,
    required this.roomCode,
    required this.userId,
  });

  @override
  State<GameplayScreen> createState() => _GameplayScreenState();
}

class _GameplayScreenState extends State<GameplayScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  late PoseDetector _poseDetector;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  Size _imageSize = Size.zero;

  // Alignment helpers
  bool _poseDetectionEnabled = true;
  int _noPoseDetectedCount = 0;

  // Auto-Alignment
  Alignment _bodyAlignment = Alignment.center;
  double _bodyScale = 1.0;
  bool _showAlignmentGuide = true;
  String _alignmentFeedback = "";
  Timer? _alignmentTimer;
  bool _isPerfectlyAligned = false;

  // Game State
  bool _isGameStarted = false;
  int _currentStep = 0;
  late List<Map<String, dynamic>> _danceSteps;
  List<Pose> _previousPoses = [];
  int _countdown = 3;
  Timer? _countdownTimer;
  Timer? _gameTimer;
  int _timeRemaining = 60;
  final double _smoothingFactor = 0.3;

  // Scoring
  int _totalScore = 0;
  int _currentStepScore = 0;
  String _feedbackText = "";
  Color _feedbackColor = Colors.white;
  Timer? _feedbackTimer;
  late List<int> _stepScores;
    bool _showScoreAnimation = false;
    int _lastScoreIncrement = 0;
  int _consecutiveGoodPoses = 0;

  // Prevents repeated scoring while holding the same pose
  bool _poseMatched = false;

  // Video Player - Updated variables for better state tracking
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _showVideo = false;
  bool _isVideoPlaying = false;
  bool _videoError = false;
  bool _isVideoPreparing = false;
  Completer<void>? _videoInitializationCompleter;

  Future<String> _getDanceName(int danceId) async {
    final List<Map<String, dynamic>> dances = const [
      {'id': 1, 'name': 'JUMBO HOTDOG'},
      {'id': 2, 'name': 'MODELONG CHARING'},
      {'id': 3, 'name': 'ELECTRIC SLIDE'},
      {'id': 4, 'name': 'CHA CHA SLIDE'},
      {'id': 5, 'name': 'MACARENA'},
    ];

    final dance = dances.firstWhere(
            (d) => d['id'] == danceId,
        orElse: () => {'name': 'Dance'}
    );

    return dance['name'];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.accurate));
    _loadDanceSteps();
    _initializeVideo();

    // Pause menu music when entering gameplay
    MusicService().pauseMusic(rememberToResume: false);
    _startCountdown();
  }


  void _initializeVideo() {
    setState(() {
      _isVideoPreparing = true;
      _videoError = false;
    });

    final videoAssets = {
      1: 'assets/videos/lv_0_20250908171807.mp4',
      2: 'assets/videos/lv_0_20250908171807.mp4',
      3: 'assets/videos/lv_0_20250908171807.mp4',
      4: 'assets/videos/lv_0_20250908171807.mp4',
      5: 'assets/videos/lv_0_20250908171807.mp4',
    };

    final videoAsset = videoAssets[widget.danceId] ?? 'assets/videos/lv_0_20250908171807.mp4';

    _videoInitializationCompleter = Completer<void>();

    _videoController = VideoPlayerController.asset(videoAsset)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
            _isVideoPreparing = false;
            debugPrint("Video initialized: ${_videoController.value.isInitialized}");
            debugPrint("Video duration: ${_videoController.value.duration}");

            _videoController.setLooping(true);
            _videoController.setVolume(0.0);

            if (!_videoInitializationCompleter!.isCompleted) {
              _videoInitializationCompleter!.complete();
            }
          });
        }
      }).catchError((error) {
        debugPrint("Error initializing video: $error");
        if (mounted) {
          setState(() {
            _isVideoInitialized = false;
            _isVideoPreparing = false;
            _videoError = true;
          });

          if (!_videoInitializationCompleter!.isCompleted) {
            _videoInitializationCompleter!.completeError(error);
          }
        }
      });
  }

  Future<void> _playVideoSafely() async {
    if (!mounted) return;

    if (_isVideoPreparing && _videoInitializationCompleter != null) {
      try {
        await _videoInitializationCompleter!.future;
      } catch (e) {
        debugPrint("Failed to initialize video: $e");
        setState(() => _videoError = true);
        return;
      }
    }

    if (!_isVideoInitialized || !_videoController.value.isInitialized) {
      debugPrint("Video not ready to play");
      setState(() => _videoError = true);
      return;
    }

    try {
      setState(() => _showVideo = true);

      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;

      await _videoController.play();

      if (mounted) {
        setState(() {
          _isVideoPlaying = true;
          _videoError = false;
        });
      }

      debugPrint("Video started playing successfully");
    } catch (error) {
      debugPrint("Error playing video: $error");
      if (mounted) {
        setState(() {
          _videoError = true;
          _isVideoPlaying = false;
        });
      }
      _recoverVideoPlayback();
    }
  }

  void _recoverVideoPlayback() {
    if (_videoError) {
      debugPrint("Attempting to recover video playback");
      _videoController.pause();
      _videoController.dispose();

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _initializeVideo();
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !(_controller!.value.isInitialized)) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
      _videoController.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller != null) {
        _initializeCamera();
      }
      if (_isGameStarted && _showVideo && _isVideoInitialized) {
        _playVideoSafely();
      }
    }
  }

  void _loadDanceSteps() {
    switch (widget.danceId) {
      case 1: // JUMBO CHACHA
        _danceSteps = [
          {
            'name': 'Intro Sway',
            'description': 'Gentle side-to-side sway with arms',
            'duration': 8,
            'originalDuration': 8,
            'scoringLogic': _scoreIntroSway as ScoreFn,
          },
          {
            'name': 'Chacha Step',
            'description': 'Side chacha with arm movements',
            'duration': 9.5,
            'originalDuration': 9.5,
            'scoringLogic': _scoreChachaStep as ScoreFn,
          },
          {
            'name': 'Jumbo Pose',
            'description': 'Arms wide open, then pointing forward',
            'duration': 10,
            'originalDuration': 10,
            'scoringLogic': _scoreJumboPose as ScoreFn,
          },
          {
            'name': 'Hotdog Point',
            'description': 'Pointing forward with alternating arms',
            'duration': 10,
            'originalDuration': 10,
            'scoringLogic': _scoreHotdogPoint as ScoreFn,
          },
          {
            'name': 'Final Celebration',
            'description': 'Hands on hips with confident stance',
            'duration': 5,
            'originalDuration': 5,
            'scoringLogic': _scoreFinalCelebration as ScoreFn,
          },
        ];
        break;

      case 2: // MODELONG CHARING
        _danceSteps = [
          {
            'name': 'Model Pose',
            'description': 'Strike a model pose with confidence',
            'duration': 10,
            'originalDuration': 10,
            'scoringLogic': _scoreModelPose as ScoreFn,
          },
          {
            'name': 'Arms Wave',
            'description': 'Wave arms gracefully side to side',
            'duration': 8,
            'originalDuration': 8,
            'scoringLogic': _scoreArmsWave as ScoreFn,
          },
          {
            'name': 'Hip Sway',
            'description': 'Sway hips from side to side',
            'duration': 8,
            'originalDuration': 8,
            'scoringLogic': _scoreHipSway as ScoreFn,
          },
          {
            'name': 'Star Pose',
            'description': 'Form a star shape with arms and legs',
            'duration': 3.2,
            'originalDuration': 3.2,
            'scoringLogic': _scoreStarPose as ScoreFn,
          },
          {
            'name': 'Final Pose',
            'description': 'End with a dramatic finishing pose',
            'duration': 3,
            'originalDuration': 3,
            'scoringLogic': _scoreFinalPose as ScoreFn,
          },
        ];
        break;

      default: // Default to JUMBO CHACHA
        _danceSteps = [
          {
            'name': 'Intro Sway',
            'description': 'Gentle side-to-side sway with arms',
            'duration': 8,
            'originalDuration': 8,
            'scoringLogic': _scoreIntroSway as ScoreFn,
          },
        ];
    }

    _stepScores = List.filled(_danceSteps.length, 0);
  }


  // ===== Alignment helper -> returns 1.0 (perfect), 0.6 (ok), or 0.0 (off) =====
  double get _alignmentMultiplier {
    if (_isPerfectlyAligned) return 1.0;

    final dx = _bodyAlignment.x.abs();
    final dy = _bodyAlignment.y.abs();
    final scale = _bodyScale;

    // More lenient alignment thresholds
    final okAligned = (dx <= 0.4 && dy <= 0.4 && scale >= 0.5 && scale <= 1.6);
    final offFrame = !(scale >= 0.4 && scale <= 1.8) || dx > 0.7 || dy > 0.7;

    if (offFrame) return 0.0;
    if (okAligned) return 0.6;
    return 0.3;
  }

  // ==================== Scoring functions ====================
  void _scoreModelPose(Pose pose) {
    final m = _alignmentMultiplier;
    if (m == 0.0) {
      _poseMatched = false;
      _updateFeedback("Move into frame!", Colors.red);
      return;
    }

    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    // Count visible upper body landmarks
    final upperBodyLandmarks = [leftHip, rightHip, leftShoulder, rightShoulder, leftWrist, rightWrist];
    final visibleLandmarks = upperBodyLandmarks.where((lm) => lm != null).length;

    // If we don't have enough landmarks for a model pose
    if (visibleLandmarks < 4) {
      _poseMatched = false;
      _updateFeedback("Show your upper body!", Colors.orange);
      return;
    }

    // For model pose, we need at least shoulders and hips visible
    if (leftShoulder == null || rightShoulder == null || leftHip == null || rightHip == null) {
      _poseMatched = false;
      _updateFeedback("Show your shoulders and hips!", Colors.orange);
      return;
    }

    // Check for model pose (one hand on hip, confident stance)
    bool handOnHip = false;

    // Check left hand on left hip
    if (leftWrist != null && leftHip != null) {
      handOnHip = handOnHip || _distance(leftWrist, leftHip) < 60;
    }

    // Check right hand on right hip
    if (rightWrist != null && rightHip != null) {
      handOnHip = handOnHip || _distance(rightWrist, rightHip) < 60;
    }

    // Check left hand on right hip (cross body)
    if (leftWrist != null && rightHip != null) {
      handOnHip = handOnHip || _distance(leftWrist, rightHip) < 70;
    }

    // Check right hand on left hip (cross body)
    if (rightWrist != null && leftHip != null) {
      handOnHip = handOnHip || _distance(rightWrist, leftHip) < 70;
    }

    // Check for confident stance (shoulders back, chest out)
    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    final hipWidth = (leftHip.x - rightHip.x).abs();

    // More lenient stance detection for partial poses
    final confidentStance = shoulderWidth > hipWidth * 0.7;

    // Also check if arms are in a model-like position (not hanging straight down)
    bool armsInPosition = false;
    if (leftWrist != null && rightWrist != null && leftShoulder != null && rightShoulder != null) {
      final leftArmRaised = leftWrist.y < leftShoulder.y + 50;
      final rightArmRaised = rightWrist.y < rightShoulder.y + 50;
      armsInPosition = leftArmRaised || rightArmRaised;
    }

    if ((handOnHip || armsInPosition) && confidentStance) {
      if (!_poseMatched) {
        final base = 300 + Random().nextInt(150);
        final score = (base * m).round();
        _addToScore(score);

        String feedbackText;
        if (handOnHip && armsInPosition) {
          feedbackText = "Perfect model pose! +$score";
        } else if (handOnHip) {
          feedbackText = "Good hand position! +$score";
        } else {
          feedbackText = "Great stance! +$score";
        }

        _updateFeedback(feedbackText, Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;

        Timer(const Duration(milliseconds: 1000), () {
          _poseMatched = false;
        });
      }
    } else {
      if (!handOnHip && !armsInPosition) {
        _updateFeedback("Hands on hips or raise arms!", Colors.orange);
      } else if (!handOnHip) {
        _updateFeedback("Try putting a hand on your hip!", Colors.orange);
      } else if (!confidentStance) {
        _updateFeedback("Stand with confidence!", Colors.orange);
      } else {
        _updateFeedback("Strike a model pose!", Colors.orange);
      }

      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreArmsWave(Pose pose) {
    final m = _alignmentMultiplier;
    if (m == 0.0) {
      _poseMatched = false;
      _updateFeedback("Move into frame!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) {
      _poseMatched = false;
      _updateFeedback("Show your arms!", Colors.orange);
      return;
    }

    // Check for arm wave motion (arms moving up and down alternately)
    final leftArmHeight = (leftWrist.y - leftShoulder.y).abs();
    final rightArmHeight = (rightWrist.y - rightShoulder.y).abs();

    // Arms should be at different heights for the wave motion
    final heightDifference = (leftArmHeight - rightArmHeight).abs();

    if (heightDifference > 30 && (leftArmHeight > 40 || rightArmHeight > 40)) {
      if (!_poseMatched) {
        final base = 250 + Random().nextInt(150);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Great wave! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Wave your arms!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreHipSway(Pose pose) {
    final m = _alignmentMultiplier;
    if (m == 0.0) {
      _poseMatched = false;
      _updateFeedback("Move into frame!", Colors.red);
      return;
    }

    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftHip == null || rightHip == null) {
      _poseMatched = false;
      _updateFeedback("Show your hips!", Colors.orange);
      return;
    }

    final hipDifference = (leftHip.y - rightHip.y).abs();
    final bool isSwaying = hipDifference > 10;

    if (isSwaying) {
      if (!_poseMatched) {
        final base = 140 + Random().nextInt(60);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Yeah! Hip sway! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;

        Timer(const Duration(milliseconds: 800), () {
          _poseMatched = false;
        });
      }
    } else {
      if (_poseMatched) {
        _updateFeedback("Keep swaying!", Colors.orange);
      }
      _consecutiveGoodPoses = 0;
    }
  }

  void _scoreStarPose(Pose pose) {
    final m = _alignmentMultiplier;
    if (m == 0.0) {
      _poseMatched = false;
      _updateFeedback("Move into frame!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null || leftAnkle == null || rightAnkle == null ||
        leftShoulder == null || rightShoulder == null) {
      _poseMatched = false;
      _updateFeedback("Show your full body!", Colors.orange);
      return;
    }

    // Check for star pose (arms and legs spread out)
    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    final wristWidth = (leftWrist.x - rightWrist.x).abs();
    final ankleWidth = (leftAnkle.x - rightAnkle.x).abs();

    final armsSpread = wristWidth > shoulderWidth * 1.5;
    final legsSpread = ankleWidth > shoulderWidth * 1.2;
    final armsUp = leftWrist.y < leftShoulder.y && rightWrist.y < rightShoulder.y;

    if (armsSpread && legsSpread && armsUp) {
      if (!_poseMatched) {
        final base = 500 + Random().nextInt(500);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Perfect star! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Make a star shape!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreFinalPose(Pose pose) {
    final m = _alignmentMultiplier;
    if (m == 0.0) {
      _poseMatched = false;
      _updateFeedback("Move into frame!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    if (leftWrist == null || rightWrist == null || nose == null) {
      _poseMatched = false;
      _updateFeedback("Show your hands!", Colors.orange);
      return;
    }

    // Check for dramatic final pose (arms up high)
    final leftArmUp = leftWrist.y < nose.y - 50;
    final rightArmUp = rightWrist.y < nose.y - 50;
    final armsUp = leftArmUp && rightArmUp;

    if (armsUp) {
      if (!_poseMatched) {
        final base = 300 + Random().nextInt(150);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Perfect finish! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Arms up high!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }



  void _scoreIntroSway(Pose pose) {
    final m = _alignmentMultiplier;
    if (m == 0.0) {
      _poseMatched = false;
      _updateFeedback("Move into frame!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) {
      _poseMatched = false;
      _updateFeedback("Show your arms!", Colors.orange);
      return;
    }

    // Check for gentle swaying motion (arms moving together)
    final leftArmHeight = (leftWrist.y - leftShoulder.y).abs();
    final rightArmHeight = (rightWrist.y - rightShoulder.y).abs();

    // Both arms should be at similar height for the sway
    final heightDifference = (leftArmHeight - rightArmHeight).abs();

    if (heightDifference < 50 && leftArmHeight > 50 && rightArmHeight > 50) {
      if (!_poseMatched) {
        final base = 200 + Random().nextInt(100);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Excellent sway! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Sway arms together!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }




  void _scoreChachaStep(Pose pose) {
    final m = _alignmentMultiplier;
    if (m == 0.0) {
      _poseMatched = false;
      _updateFeedback("Move into frame!", Colors.red);
      return;
    }

    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftAnkle == null || rightAnkle == null || leftHip == null || rightHip == null) {
      _poseMatched = false;
      _updateFeedback("Show your feet!", Colors.orange);
      return;
    }

    // Check for chacha step (feet wider than hips)
    final hipWidth = (leftHip.x - rightHip.x).abs();
    final ankleWidth = (leftAnkle.x - rightAnkle.x).abs();

    if (ankleWidth > hipWidth * 1.2) {
      if (!_poseMatched) {
        final base = 300 + Random().nextInt(100);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Great chacha! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Wider steps!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreJumboPose(Pose pose) {
    final m = _alignmentMultiplier;
    if (m == 0.0) {
      _poseMatched = false;
      _updateFeedback("Move into frame!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) {
      _poseMatched = false;
      _updateFeedback("Show your arms!", Colors.orange);
      return;
    }

    // Check for "Jumbo" pose (arms wide and up)
    final leftArmSpread = (leftWrist.x - leftShoulder.x).abs();
    final rightArmSpread = (rightWrist.x - rightShoulder.x).abs();
    final armsUp = leftWrist.y < leftShoulder.y && rightWrist.y < rightShoulder.y;

    if (armsUp && leftArmSpread > 50 && rightArmSpread > 50) {
      if (!_poseMatched) {
        final base = 500 + Random().nextInt(300);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("JUMBO! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Arms wide and up!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreHotdogPoint(Pose pose) {
    final m = _alignmentMultiplier;
    if (m == 0.0) {
      _poseMatched = false;
      _updateFeedback("Move into frame!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];

    if (leftWrist == null || rightWrist == null || leftElbow == null || rightElbow == null) {
      _poseMatched = false;
      _updateFeedback("Show your arms!", Colors.orange);
      return;
    }

    // Check for pointing motion (one arm extended forward)
    final leftArmExtended = (leftWrist.x - leftElbow.x).abs() > 50;
    final rightArmExtended = (rightWrist.x - rightElbow.x).abs() > 50;

    // Only one arm should be extended at a time
    if (leftArmExtended != rightArmExtended) {
      if (!_poseMatched) {
        final base = 450 + Random().nextInt(250);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Perfect point! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Point with one arm!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreFinalCelebration(Pose pose) {
    final m = _alignmentMultiplier;
    if (m == 0.0) {
      _poseMatched = false;
      _updateFeedback("Move into frame!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftWrist == null || rightWrist == null || leftHip == null || rightHip == null) {
      _poseMatched = false;
      _updateFeedback("Show your hands & hips!", Colors.orange);
      return;
    }

    // Check for hands on hips celebration pose
    final leftHandOnHip = _distance(leftWrist, leftHip) < 50;
    final rightHandOnHip = _distance(rightWrist, rightHip) < 50;

    if (leftHandOnHip && rightHandOnHip) {
      if (!_poseMatched) {
        final base = 250 + Random().nextInt(150);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Perfect finish! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Hands on hips!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _addToScore(int points) {
    if (points <= 0) return;
    setState(() {
      _currentStepScore = min(_currentStepScore + points, 1000);
      _lastScoreIncrement = points;
      _showScoreAnimation = true;
      _noPoseDetectedCount = 0;
    });

    Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showScoreAnimation = false;
        });
      }
    });
  }




  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final baX = a.x - b.x;
    final baY = a.y - b.y;
    final bcX = c.x - b.x;
    final bcY = c.y - b.y;

    final dotProduct = (baX * bcX) + (baY * bcY);
    final magBA = sqrt(baX * baX + baY * baY);
    final magBC = sqrt(bcX * bcX + bcY * bcY);

    final denom = magBA * magBC;
    if (denom == 0) return 180;

    final cosTheta = (dotProduct / denom).clamp(-1.0, 1.0);
    final angle = acos(cosTheta);
    return angle * (180 / pi);
  }

  double _distance(PoseLandmark a, PoseLandmark b) {
    return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
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

  Future<void> _startGame() async {
    MusicService().playGameMusic(danceId: widget.danceId);

    if (_videoInitializationCompleter != null) {
      try {
        await _videoInitializationCompleter!.future;
      } catch (_) {
        debugPrint("Video init failed, skipping playback");
      }
    }

    await _playVideoSafely();

    setState(() {
      _isGameStarted = true;
      _currentStep = 0;
      _timeRemaining = 60;
      _totalScore = 0;
      _currentStepScore = 0;
      _stepScores = List.filled(_danceSteps.length, 0);
      _poseDetectionEnabled = true;
      _showAlignmentGuide = true;
      _isPerfectlyAligned = false;

      for (var step in _danceSteps) {
        step['duration'] = step['originalDuration'];
      }
    });

    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;

          if (_danceSteps[_currentStep]['duration'] > 0) {
            _danceSteps[_currentStep]['duration'] =
                _danceSteps[_currentStep]['duration'] - 1;
          }

          if (_danceSteps[_currentStep]['duration'] <= 0) {
            _nextStep();
          }
        } else {
          _endGame();
          timer.cancel();
        }
      });
    });
  }




  void _nextStep() {
    debugPrint("Moving from step $_currentStep to ${_currentStep + 1}");
    debugPrint("Current step score: $_currentStepScore");

    _stepScores[_currentStep] = _currentStepScore;
    _totalScore += _currentStepScore;

    if (_currentStep < _danceSteps.length - 1) {
      setState(() {
        _currentStep++;
        _currentStepScore = 0;
        _poseMatched = false;
        _showAlignmentGuide = true;
        _isPerfectlyAligned = false;

        // Reset duration to original value
        _danceSteps[_currentStep]['duration'] = _danceSteps[_currentStep]['originalDuration'];
      });

      debugPrint("Step $_currentStep duration: ${_danceSteps[_currentStep]['duration']}s");
    } else {
      debugPrint("Game completed! Total score: $_totalScore");
      _endGame();
    }
  }

  Future<void> _updateUserXP(int xpGained) async {
    try {
      final result = await ApiService.updateUserXP(widget.userId, xpGained);

      if (result['status'] == 'success' && result['leveled_up'] == true) {
        // Show level up notification after the game over dialog
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("🎉 Level Up! You're now level ${result['new_level']}!"),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error updating XP: $e");
    }
  }

  void _endGame() {
    _gameTimer?.cancel();

    // Stop the game music and video
    MusicService().stopMusic();
    _videoController.pause();

    final maxPossibleScore = _danceSteps.length * 1000;
    final percentage = maxPossibleScore == 0 ? 0 : (_totalScore / maxPossibleScore * 100).round();

    // Calculate XP based on performance
    int xpGained = 0;
    if (percentage >= 90) {
      xpGained = 100; // Perfect score
    } else if (percentage >= 70) {
      xpGained = 75; // Very good
    } else if (percentage >= 50) {
      xpGained = 50; // Good
    } else {
      xpGained = 25; // Try again
    }

    // Add bonus for consecutive good poses
    xpGained += (_consecutiveGoodPoses ~/ 10) * 10;

    // Navigate to result screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameResultScreen(
          totalScore: _totalScore,
          percentage: percentage,
          xpGained: xpGained,
          stepScores: _stepScores,
          danceSteps: _danceSteps,
          userId: widget.userId,
        ),
      ),
    );

    // Update user XP in background
    _updateUserXP(xpGained);
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
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize().then((_) {
        if (!mounted) return;

        // In portrait, previewSize is landscape (width>height), so swap.
        final previewSize = _controller!.value.previewSize!;
        _imageSize = Size(previewSize.height, previewSize.width);

        // Start stream
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

  void _calculateAlignment(Pose pose) {
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    // Use more landmarks for better partial body detection
    final List<PoseLandmark?> keyLandmarks = [
      leftShoulder, rightShoulder, leftHip, rightHip, nose
    ];

    final int visibleLandmarks = keyLandmarks.where((lm) => lm != null).length;

    // If we don't have enough landmarks, don't try to calculate alignment
    if (visibleLandmarks < 3) {
      setState(() {
        _alignmentFeedback = "Show more of your body";
        _isPerfectlyAligned = false;
        _bodyAlignment = Alignment.center;
        _bodyScale = 1.0;
      });
      return;
    }

    // Calculate center using available landmarks
    double centerX = 0;
    double centerY = 0;
    int count = 0;

    for (final landmark in keyLandmarks) {
      if (landmark != null) {
        centerX += landmark.x;
        centerY += landmark.y;
        count++;
      }
    }

    centerX /= count;
    centerY /= count;

    final screenCenterX = _imageSize.width / 2;
    final screenCenterY = _imageSize.height / 2;

    final alignX = (centerX - screenCenterX) / screenCenterX;
    final alignY = (centerY - screenCenterY) / screenCenterY;

    // Calculate scale based on shoulder width if available, otherwise use hip width
    double scale = 1.0;
    if (leftShoulder != null && rightShoulder != null) {
      final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
      final idealShoulderWidth = _imageSize.width * 0.3;
      scale = shoulderWidth / idealShoulderWidth;
    } else if (leftHip != null && rightHip != null) {
      final hipWidth = (leftHip.x - rightHip.x).abs();
      final idealHipWidth = _imageSize.width * 0.25;
      scale = hipWidth / idealHipWidth;
    }

    bool isAligned = false;
    String feedback = "";

    // More lenient alignment thresholds
    if (alignX.abs() > 0.3) {
      feedback = alignX > 0 ? "Move left" : "Move right";
    } else if (alignY.abs() > 0.3) {
      feedback = alignY > 0 ? "Move up" : "Move down";
    } else if (scale < 0.6) {
      feedback = "Move closer";
    } else if (scale > 1.4) {
      feedback = "Move back";
    } else {
      feedback = "Perfect position!";
      isAligned = true;
    }

    setState(() {
      _bodyAlignment = Alignment(alignX, alignY);
      _bodyScale = scale;
      _alignmentFeedback = feedback;
      _isPerfectlyAligned = isAligned;

      if (isAligned) {
        _alignmentTimer?.cancel();
        _alignmentTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showAlignmentGuide = false);
        });
      } else {
        _showAlignmentGuide = true;
      }
    });
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
    if (_isBusy || !mounted || !_isGameStarted || !_poseDetectionEnabled) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        final smoothedPose = _smoothPose(poses.first);
        _noPoseDetectedCount = 0;

        _calculateAlignment(smoothedPose);

        if (_isGameStarted && _currentStep < _danceSteps.length) {
          final ScoreFn fn = _danceSteps[_currentStep]['scoringLogic'] as ScoreFn;
          fn(smoothedPose);
        }


      } else {
        _customPaint = null;
        _noPoseDetectedCount++;

        if (_noPoseDetectedCount > 5) {
          _updateFeedback("Can't see you! Move into frame", Colors.red);
        }

        if (_noPoseDetectedCount > 15) {
          setState(() => _poseDetectionEnabled = false);
          Timer(const Duration(seconds: 2), () {
            if (mounted) setState(() => _poseDetectionEnabled = true);
          });
        }
      }
    } catch (e) {
      debugPrint("Pose detection error: $e");
      _customPaint = null;

      try {
        await _poseDetector.close();
        _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.accurate));
      } catch (e) {
        debugPrint("Error reinitializing pose detector: $e");
      }
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

      // Typical for Android front camera in portrait.
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
    _countdownTimer?.cancel();
    _gameTimer?.cancel();
    _feedbackTimer?.cancel();
    _alignmentTimer?.cancel();

    // Proper video disposal
    _videoController.pause();
    _videoController.dispose();

    // Stop game music when screen is disposed
    MusicService().stopMusic();

    super.dispose();
  }

  // Add video listener to track state changes
  void _videoListener() {
    if (_videoController.value.hasError) {
      debugPrint("Video error: ${_videoController.value.errorDescription}");
      if (mounted) {
        setState(() {
          _videoError = true;
          _isVideoPlaying = false;
        });
      }
    } else if (_videoController.value.isPlaying) {
      if (mounted) {
        setState(() {
          _isVideoPlaying = true;
          _videoError = false;
        });
      }
    } else if (_videoController.value.isInitialized &&
        !_videoController.value.isPlaying) {
      if (mounted) {
        setState(() {
          _isVideoPlaying = false;
        });
      }
    }
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
              if (!_poseDetectionEnabled) ...[
                const SizedBox(height: 20),
                const Text(
                  "Optimizing for your device...",
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Camera + Pose overlay aligned by shared image size and FittedBox scaling
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

          // Video Guide (top-right corner) - Made smaller and positioned to not interfere with pose detection
          if (_showVideo && _isVideoInitialized)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: _videoController.value.aspectRatio,
                        child: VideoPlayer(_videoController),
                      ),
                      if (!_isVideoPlaying || _videoError)
                        Container(
                          color: Colors.black54,
                          child: Center(
                            child: _videoError
                                ? const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 40,
                            )
                                : const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // Video error message with retry button
          if (_videoError)
            Positioned(
              top: 180, // Position below the video container
              right: 10,
              child: GestureDetector(
                onTap: _recoverVideoPlayback,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        "Retry Video",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Alignment Guide
          if (_showAlignmentGuide && _alignmentFeedback.isNotEmpty && _isGameStarted)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 200,
                        height: 300,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _isPerfectlyAligned
                                ? Colors.green.withOpacity(0.7)
                                : Colors.orange.withOpacity(0.7),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            _alignmentFeedback,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
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
                      const SizedBox(height: 20),
                      Text(
                        "Size: ${(_bodyScale * 100).toStringAsFixed(0)}%",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
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
                ),
              ),
            ),

          // Game UI
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
                          FutureBuilder<String>(
                            future: _getDanceName(widget.danceId),
                            builder: (context, snapshot) {
                              String danceName = "Dance Challenge";
                              if (snapshot.hasData) {
                                danceName = snapshot.data!;
                              }
                              return Text(
                                "$danceName",
                                style: const TextStyle(
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
                              );
                            },
                          ),
                          Text(
                            "Room: ${widget.roomCode}",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
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
                      // REMOVED: Timer display from here
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
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                          const Text(
                            "Get ready to dance!",
                            style: TextStyle(
                              fontSize: 24,
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
                              shadows: [
                                Shadow(
                                  blurRadius: 10,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _danceSteps[_currentStep]['description'],
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  blurRadius: 5,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 15),

                          Text(
                            "Step ${_currentStep + 1}/${_danceSteps.length} • ${_danceSteps[_currentStep]['duration']}s left",
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                              shadows: [
                                Shadow(
                                  blurRadius: 5,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            "Score: $_currentStepScore/1000",
                            style: const TextStyle(
                              fontSize: 18,
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

// ... (rest of the code remains the same)
}