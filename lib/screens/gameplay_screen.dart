import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../services/api_service.dart';
import '../services/music_service.dart';

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
  // Camera and Pose Detection
  CameraController? _controller;
  bool _isCameraInitialized = false;
  late PoseDetector _poseDetector;
  bool _isBusy = false;
  CustomPaint? _customPaint;

  // This is the camera image's intrinsic size (portrait-corrected)
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.accurate));
    _loadDanceSteps();

    // Pause menu music when entering gameplay
    MusicService().pauseMusic(rememberToResume: false);
    _startCountdown();
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

  void _loadDanceSteps() {
    switch (widget.danceId) {
      case 1: // JUMBO CHACHA
        _danceSteps = [
          {
            'name': 'Intro Sway',
            'description': 'Gentle side-to-side sway with arms',
            'duration': 8,
            'originalDuration': 8,
            'lyrics': 'Sumabay ka nalang\nWag kang mahihiya\nSige subukan mo\nBaka may mapala',
            'scoringLogic': _scoreIntroSway as ScoreFn,
          },
          {
            'name': 'Chacha Step',
            'description': 'Side chacha with arm movements',
            'duration': 8,
            'originalDuration': 8,
            'lyrics': 'Walang mawawala\nKapag nagchachaga\nKung gustong gusto mo\nSundan mo lang ako',
            'scoringLogic': _scoreChachaStep as ScoreFn,
          },
          {
            'name': 'Jumbo Pose',
            'description': 'Arms wide open, then pointing forward',
            'duration': 8,
            'originalDuration': 8,
            'lyrics': 'Jumbo hotdog\nKaya mo ba to?\nKaya mo ba to?\nKaya mo ba to?',
            'scoringLogic': _scoreJumboPose as ScoreFn,
          },
          {
            'name': 'Hotdog Point',
            'description': 'Pointing forward with alternating arms',
            'duration': 8,
            'originalDuration': 8,
            'lyrics': 'Jumbo hotdog\nKaya mo ba to?\nHindi kami ba to\nPara magpatalo',
            'scoringLogic': _scoreHotdogPoint as ScoreFn,
          },
          {
            'name': 'Final Celebration',
            'description': 'Hands on hips with confident stance',
            'duration': 8,
            'originalDuration': 8,
            'lyrics': 'Jumbo hotdog!\nKaya natin to!\nJumbo hotdog!\nAng sarap talaga!',
            'scoringLogic': _scoreFinalCelebration as ScoreFn,
          },
        ];
        break;

      case 2: // PAA TUHOD BALIKAT ULO
        _danceSteps = [
          {
            'name': 'Paa (Feet)',
            'description': 'Touch your feet with both hands',
            'duration': 8,
            'originalDuration': 8,
            'lyrics': 'Paa, paa, paa\nHawakan ang paa',
            'scoringLogic': _scorePaaStep as ScoreFn,
          },
          {
            'name': 'Tuhod (Knees)',
            'description': 'Touch your knees with both hands',
            'duration': 8,
            'originalDuration': 8,
            'lyrics': 'Tuhod, tuhod, tuhod\nHawakan ang tuhod',
            'scoringLogic': _scoreTuhodStep as ScoreFn,
          },
          {
            'name': 'Balikat (Shoulders)',
            'description': 'Touch your shoulders with both hands',
            'duration': 8,
            'originalDuration': 8,
            'lyrics': 'Balikat, balikat, balikat\nHawakan ang balikat',
            'scoringLogic': _scoreBalikatStep as ScoreFn,
          },
          {
            'name': 'Ulo (Head)',
            'description': 'Touch your head with both hands',
            'duration': 8,
            'originalDuration': 8,
            'lyrics': 'Ulo, ulo, ulo\nHawakan ang ulo',
            'scoringLogic': _scoreUloStep as ScoreFn,
          },
          {
            'name': 'Fast Sequence 1',
            'description': 'Quick: Paa, Tuhod, Balikat, Ulo!',
            'duration': 4,
            'originalDuration': 4,
            'lyrics': 'Paa, tuhod, balikat, ulo!',
            'scoringLogic': _scoreFastSequence as ScoreFn,
          },
          {
            'name': 'Fast Sequence 2',
            'description': 'Faster: Paa, Tuhod, Balikat, Ulo!',
            'duration': 4,
            'originalDuration': 4,
            'lyrics': 'Paa, tuhod, balikat, ulo!',
            'scoringLogic': _scoreFastSequence as ScoreFn,
          },
          {
            'name': 'Final Pose',
            'description': 'End with hands up celebration',
            'duration': 4,
            'originalDuration': 4,
            'lyrics': 'Tapos na!',
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
            'lyrics': 'Sumabay ka nalang\nWag kang mahihiya\nSige subukan mo\nBaka may mapala',
            'scoringLogic': _scoreIntroSway as ScoreFn,
          },
          // ... rest of JUMBO CHACHA steps
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

    final okAligned = (dx <= 0.35 && dy <= 0.35 && scale >= 0.65 && scale <= 1.45);
    final offFrame = !(scale >= 0.5 && scale <= 1.7) || dx > 0.6 || dy > 0.6;

    if (offFrame) return 0.0;
    if (okAligned) return 0.6;
    return 0.3;
  }

  // ==================== Updated Scoring functions ====================

  // ==================== PAA TUHOD BALIKAT ULO Scoring functions ====================

  void _scorePaaStep(Pose pose) {
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

    if (leftWrist == null || rightWrist == null || leftAnkle == null || rightAnkle == null) {
      _poseMatched = false;
      _updateFeedback("Show your feet and hands!", Colors.orange);
      return;
    }

    // Check if both hands are touching or near feet
    final leftHandNearFoot = _distance(leftWrist, leftAnkle) < 60;
    final rightHandNearFoot = _distance(rightWrist, rightAnkle) < 60;
    final handsLow = leftWrist.y > leftAnkle.y - 30 && rightWrist.y > rightAnkle.y - 30;

    if ((leftHandNearFoot || rightHandNearFoot) && handsLow) {
      if (!_poseMatched) {
        final base = 120 + Random().nextInt(40);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Paa! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Touch your feet!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreTuhodStep(Pose pose) {
    final m = _alignmentMultiplier;
    if (m == 0.0) {
      _poseMatched = false;
      _updateFeedback("Move into frame!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];

    if (leftWrist == null || rightWrist == null || leftKnee == null || rightKnee == null) {
      _poseMatched = false;
      _updateFeedback("Show your knees and hands!", Colors.orange);
      return;
    }

    // Check if both hands are touching or near knees
    final leftHandNearKnee = _distance(leftWrist, leftKnee) < 50;
    final rightHandNearKnee = _distance(rightWrist, rightKnee) < 50;
    final handsAtKneeLevel = leftWrist.y > leftKnee.y - 20 && rightWrist.y > rightKnee.y - 20;

    if ((leftHandNearKnee || rightHandNearKnee) && handsAtKneeLevel) {
      if (!_poseMatched) {
        final base = 120 + Random().nextInt(40);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Tuhod! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Touch your knees!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreBalikatStep(Pose pose) {
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
      _updateFeedback("Show your shoulders and hands!", Colors.orange);
      return;
    }

    // Check if both hands are touching or near shoulders
    final leftHandNearShoulder = _distance(leftWrist, leftShoulder) < 40;
    final rightHandNearShoulder = _distance(rightWrist, rightShoulder) < 40;
    final handsAtShoulderLevel = leftWrist.y < leftShoulder.y + 30 && rightWrist.y < rightShoulder.y + 30;

    if ((leftHandNearShoulder || rightHandNearShoulder) && handsAtShoulderLevel) {
      if (!_poseMatched) {
        final base = 120 + Random().nextInt(40);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Balikat! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Touch your shoulders!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreUloStep(Pose pose) {
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
      _updateFeedback("Show your head and hands!", Colors.orange);
      return;
    }

    // Check if both hands are touching or near head
    final leftHandNearHead = _distance(leftWrist, nose) < 80;
    final rightHandNearHead = _distance(rightWrist, nose) < 80;
    final handsHigh = leftWrist.y < nose.y + 50 && rightWrist.y < nose.y + 50;

    if ((leftHandNearHead || rightHandNearHead) && handsHigh) {
      if (!_poseMatched) {
        final base = 120 + Random().nextInt(40);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Ulo! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Touch your head!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreFastSequence(Pose pose) {
    final m = _alignmentMultiplier;
    if (m == 0.0) {
      _poseMatched = false;
      _updateFeedback("Move into frame!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    if (leftWrist == null || rightWrist == null) {
      _poseMatched = false;
      _updateFeedback("Show your hands!", Colors.orange);
      return;
    }

    // Check which body part the hands are closest to
    double minDistance = double.infinity;
    String currentPosition = "";

    if (leftAnkle != null) {
      final dist = _distance(leftWrist, leftAnkle);
      if (dist < minDistance) {
        minDistance = dist;
        currentPosition = "paa";
      }
    }

    if (leftKnee != null) {
      final dist = _distance(leftWrist, leftKnee);
      if (dist < minDistance) {
        minDistance = dist;
        currentPosition = "tuhod";
      }
    }

    if (leftShoulder != null) {
      final dist = _distance(leftWrist, leftShoulder);
      if (dist < minDistance) {
        minDistance = dist;
        currentPosition = "balikat";
      }
    }

    if (nose != null) {
      final dist = _distance(leftWrist, nose);
      if (dist < minDistance && dist < 100) {
        minDistance = dist;
        currentPosition = "ulo";
      }
    }

    // Award points for being in any position during fast sequence
    if (minDistance < 100 && currentPosition.isNotEmpty) {
      if (!_poseMatched) {
        final base = 200 + Random().nextInt(50);
        final score = (base * m).round();
        _addToScore(score);

        switch (currentPosition) {
          case "paa":
            _updateFeedback("Paa! +$score", Colors.green);
            break;
          case "tuhod":
            _updateFeedback("Tuhod! +$score", Colors.green);
            break;
          case "balikat":
            _updateFeedback("Balikat! +$score", Colors.green);
            break;
          case "ulo":
            _updateFeedback("Ulo! +$score", Colors.green);
            break;
        }

        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Faster! Paa, Tuhod, Balikat, Ulo!", Colors.orange);
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

    // Check for celebration pose (hands above head)
    final handsHigh = leftWrist.y < nose.y && rightWrist.y < nose.y;

    if (handsHigh) {
      if (!_poseMatched) {
        final base = 300 + Random().nextInt(100);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Perfect finish! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Hands up celebration!", Colors.orange);
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
        final base = 100 + Random().nextInt(50);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Nice sway! +$score", Colors.green);
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
        final base = 150 + Random().nextInt(50);
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
        final base = 200 + Random().nextInt(100);
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
        final base = 175 + Random().nextInt(75);
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

  void _startGame() {
    // Play the appropriate music based on danceId
    switch (widget.danceId) {
      case 1: // JUMBO CHACHA
        MusicService().playGameMusic(); // Existing Jumbo Hotdog music
    }

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
    });

    _gameTimer?.cancel();
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
    _stepScores[_currentStep] = _currentStepScore;
    _totalScore += _currentStepScore;

    if (_currentStep < _danceSteps.length - 1) {
      setState(() {
        _currentStep++;
        _currentStepScore = 0;
        _danceSteps[_currentStep]['duration'] = _danceSteps[_currentStep]['originalDuration'];
        _showAlignmentGuide = true;
        _isPerfectlyAligned = false;
      });
    } else {
      _endGame();
    }
  }

  Future<void> _updateUserLevel() async {
    try {
      final result = await ApiService.updateUserLevel(widget.userId);

      if (result['status'] != 'success') {
        debugPrint("Failed to update level: ${result['message']}");
      } else {
        debugPrint("Level updated successfully to: ${result['new_level']}");
      }
    } catch (e) {
      debugPrint("Error updating level: $e");
    }
  }

  void _endGame() {
    _gameTimer?.cancel();

    // Stop the game music
    MusicService().stopMusic();

    final maxPossibleScore = _danceSteps.length * 1000;
    final percentage = maxPossibleScore == 0 ? 0 : (_totalScore / maxPossibleScore * 100).round();

    // Check if user should level up (70% or higher)
    final bool shouldLevelUp = percentage >= 50;

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

    // Call API to update user level if they should level up
    if (shouldLevelUp) {
      _updateUserLevel();
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
            if (shouldLevelUp) ...[
              const SizedBox(height: 10),
              const Text(
                "🎉 LEVEL UP! 🎉",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
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
            onPressed: () {
              Navigator.pop(context);
              // Resume background music when returning to menu
              MusicService().playMenuMusic(screenName: 'menu');
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
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

    if (leftShoulder == null || rightShoulder == null || leftHip == null || rightHip == null) {
      setState(() {
        _alignmentFeedback = "Show your full body";
        _isPerfectlyAligned = false;
        _bodyAlignment = Alignment.center;
        _bodyScale = 1.0;
      });
      return;
    }

    final shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2;
    final shoulderCenterY = (leftShoulder.y + rightShoulder.y) / 2;
    final hipCenterX = (leftHip.x + rightHip.x) / 2;
    final hipCenterY = (leftHip.y + rightHip.y) / 2;

    final bodyCenterX = (shoulderCenterX + hipCenterX) / 2;
    final bodyCenterY = (shoulderCenterY + hipCenterY) / 2;

    final screenCenterX = _imageSize.width / 2;
    final screenCenterY = _imageSize.height / 2;

    final alignX = (bodyCenterX - screenCenterX) / screenCenterX;
    final alignY = (bodyCenterY - screenCenterY) / screenCenterY;

    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    final idealShoulderWidth = _imageSize.width * 0.3;
    final scale = shoulderWidth / idealShoulderWidth;

    bool isAligned = false;
    String feedback = "";

    if (alignX.abs() > 0.2) {
      feedback = alignX > 0 ? "Move left" : "Move right";
    } else if (alignY.abs() > 0.2) {
      feedback = alignY > 0 ? "Move up" : "Move down";
    } else if (scale < 0.8) {
      feedback = "Move closer";
    } else if (scale > 1.2) {
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

        _customPaint = CustomPaint(
          painter: PosePainter(
            [smoothedPose],
            _imageSize,
            _controller!.description.lensDirection == CameraLensDirection.front,
          ),
        );
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

    // Stop game music when screen is disposed
    if (_isGameStarted) {
      MusicService().stopMusic();
    }

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
                          const Text(
                            "Jumbo Hotdog Challenge",
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "$_timeRemaining s",
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
                                shadows: [
                                  Shadow(
                                    blurRadius: 5,
                                    color: Colors.black,
                                  ),
                                ],
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
                                shadows: [
                                  Shadow(
                                    blurRadius: 5,
                                    color: Colors.black,
                                  ),
                                ],
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
                              shadows: [
                                Shadow(
                                  blurRadius: 5,
                                  color: Colors.black,
                                ),
                              ],
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
}

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;     // intrinsic camera image size (portrait-corrected)
  final bool isFrontCamera;

  PosePainter(
      this.poses,
      this.imageSize,
      this.isFrontCamera,
      );

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