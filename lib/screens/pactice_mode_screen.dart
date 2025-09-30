import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../services/music_service.dart';
import '../services/api_service.dart';

class PracticeModeScreen extends StatefulWidget {
  final Map user;

  const PracticeModeScreen({super.key, required this.user});

  @override
  State<PracticeModeScreen> createState() => _PracticeModeScreenState();
}

class _PracticeModeScreenState extends State<PracticeModeScreen>
    with SingleTickerProviderStateMixin {
  final MusicService _musicService = MusicService();
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  int? _selectedDanceId;
  bool _isLoading = false;
  String _errorMessage = '';

  // List of dance names with their IDs
  final List<Map<String, dynamic>> dances = const [
    {'id': 1, 'name': 'HOTDOG NI JHUNIEL', 'difficulty': 'Easy', 'duration': '1:30'},
    {'id': 2, 'name': 'PAA TUHOD BALIKAT', 'difficulty': 'Easy', 'duration': '1:45'},
  ];

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectDance(int danceId) async {
    if (_isLoading) return;

    setState(() {
      _selectedDanceId = danceId;
      _isLoading = true;
      _errorMessage = '';
    });

    // Stop music when a dance is selected
    _musicService.pauseMusic(rememberToResume: false);

    // Add a small delay to show the loading state
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PracticeGameplayScreen(
          danceId: danceId,
          userId: widget.user['id'].toString(),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  Widget _buildDanceCard(Map<String, dynamic> dance) {
    final bool isSelected = _selectedDanceId == dance['id'];
    final bool isSelecting = _isLoading && isSelected;

    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A0C3F), Color(0xFF2D1070)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? Colors.cyanAccent.withOpacity(0.6)
                    : Colors.black.withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isSelected ? Colors.cyanAccent : Colors.purpleAccent,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _selectDance(dance['id']),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            dance['name'],
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(2, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isSelecting)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildInfoChip(
                          Icons.speed,
                          dance['difficulty'],
                          _getDifficultyColor(dance['difficulty']),
                        ),
                        const SizedBox(width: 10),
                        _buildInfoChip(
                          Icons.timer,
                          dance['duration'],
                          Colors.purpleAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Text(
                      _getDanceDescription(dance['id']),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.greenAccent;
      case 'medium':
        return Colors.orangeAccent;
      case 'hard':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _getDanceDescription(int danceId) {
    switch (danceId) {
      case 1:
        return 'A fun and energetic dance with Latin influences. Perfect for beginners and experts alike.';
      case 2:
        return 'A traditional Filipino dance that challenges your coordination and rhythm.';
      default:
        return 'A fantastic dance choice that will test your skills and provide great practice.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Practice Mode"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading
              ? null
              : () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0523), Color(0xFF1D054A), Color(0xFF2D1070)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.purple.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyan.withOpacity(0.1),
                ),
              ),
            ),

            // Main content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Practice Your Dance Moves",
                    style: TextStyle(
                      fontSize: 26,
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 8,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "No pressure, just practice!",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Dance cards
                  Expanded(
                    child: ListView(
                      children: dances.map((dance) => _buildDanceCard(dance)).toList(),
                    ),
                  ),

                  // Error message
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PracticeGameplayScreen extends StatefulWidget {
  final int danceId;
  final String userId;

  const PracticeGameplayScreen({
    super.key,
    required this.danceId,
    required this.userId,
  });

  @override
  State<PracticeGameplayScreen> createState() => _PracticeGameplayScreenState();
}

class _PracticeGameplayScreenState extends State<PracticeGameplayScreen>
    with WidgetsBindingObserver {
  // Camera and Pose Detection
  CameraController? _controller;
  bool _isCameraInitialized = false;
  late PoseDetector _poseDetector;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  Size _imageSize = Size.zero;

  // Alignment helpers
  bool _poseDetectionEnabled = true;
  int _noPoseDetectedCount = 0;
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
  final double _smoothingFactor = 0.05; // Reduced for less delay

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
  bool _poseMatched = false;

  // Performance optimization
  DateTime? _lastProcessingTime;
  int _framesProcessed = 0;
  double _averageProcessingTime = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    // Use faster model for real-time performance
    _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.base));
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
            'name': 'Intro Sway', // Keep name for result screen
            'description': 'Gentle side-to-side sway with arms',
            'duration': 8,
            'originalDuration': 8,
            'scoringLogic': _scoreIntroSway,
          },
          {
            'name': 'Chacha Step', // Keep name for result screen
            'description': 'Side chacha with arm movements',
            'duration': 8,
            'originalDuration': 8,
            'scoringLogic': _scoreChachaStep,
          },
          {
            'name': 'Jumbo Pose', // Keep name for result screen
            'description': 'Arms wide open, then pointing forward',
            'duration': 8,
            'originalDuration': 8,
            'scoringLogic': _scoreJumboPose,
          },
          {
            'name': 'Hotdog Point', // Keep name for result screen
            'description': 'Pointing forward with alternating arms',
            'duration': 8,
            'originalDuration': 8,
            'scoringLogic': _scoreHotdogPoint,
          },
          {
            'name': 'Final Celebration', // Keep name for result screen
            'description': 'Hands on hips with confident stance',
            'duration': 8,
            'originalDuration': 8,
            'scoringLogic': _scoreFinalCelebration,
          },
        ];
        break;

      case 2: // PAA TUHOD BALIKAT ULO
        _danceSteps = [
          {
            'name': 'Paa (Feet)', // Keep name for result screen
            'description': 'Touch your feet with both hands',
            'duration': 8,
            'originalDuration': 8,
            'scoringLogic': _scorePaaStep,
          },
          {
            'name': 'Tuhod (Knees)', // Keep name for result screen
            'description': 'Touch your knees with both hands',
            'duration': 8,
            'originalDuration': 8,
            'scoringLogic': _scoreTuhodStep,
          },
          {
            'name': 'Balikat (Shoulders)', // Keep name for result screen
            'description': 'Touch your shoulders with both hands',
            'duration': 8,
            'originalDuration': 8,
            'scoringLogic': _scoreBalikatStep,
          },
          {
            'name': 'Ulo (Head)', // Keep name for result screen
            'description': 'Touch your head with both hands',
            'duration': 8,
            'originalDuration': 8,
            'scoringLogic': _scoreUloStep,
          },
          {
            'name': 'Fast Sequence 1', // Keep name for result screen
            'description': 'Quick: Paa, Tuhod, Balikat, Ulo!',
            'duration': 4,
            'originalDuration': 4,
            'scoringLogic': _scoreFastSequence,
          },
          {
            'name': 'Fast Sequence 2', // Keep name for result screen
            'description': 'Faster: Paa, Tuhod, Balikat, Ulo!',
            'duration': 4,
            'originalDuration': 4,
            'scoringLogic': _scoreFastSequence,
          },
          {
            'name': 'Final Pose', // Keep name for result screen
            'description': 'End with hands up celebration',
            'duration': 4,
            'originalDuration': 4,
            'scoringLogic': _scoreFinalPose,
          },
        ];
        break;

      default: // Default to JUMBO CHACHA
        _danceSteps = [
          {
            'name': 'Intro Sway', // Keep name for result screen
            'description': 'Gentle side-to-side sway with arms',
            'duration': 8,
            'originalDuration': 8,
            'scoringLogic': _scoreIntroSway,
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

    final okAligned = (dx <= 0.35 && dy <= 0.35 && scale >= 0.65 && scale <= 1.45);
    final offFrame = !(scale >= 0.5 && scale <= 1.7) || dx > 0.6 || dy > 0.6;

    if (offFrame) return 0.0;
    if (okAligned) return 0.6;
    return 0.3;
  }

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

    final leftArmHeight = (leftWrist.y - leftShoulder.y).abs();
    final rightArmHeight = (rightWrist.y - rightShoulder.y).abs();
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

    final leftArmExtended = (leftWrist.x - leftElbow.x).abs() > 50;
    final rightArmExtended = (rightWrist.x - rightElbow.x).abs() > 50;

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
    switch (widget.danceId) {
      case 1: // JUMBO CHACHA
        MusicService().playGameMusic(danceId: widget.danceId);
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

  void _endGame() {
    _gameTimer?.cancel();
    MusicService().stopMusic();

    final maxPossibleScore = _danceSteps.length * 1000;
    final percentage = maxPossibleScore == 0 ? 0 : (_totalScore / maxPossibleScore * 100).round();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PracticeResultScreen(
          totalScore: _totalScore,
          percentage: percentage,
          stepScores: _stepScores,
          danceSteps: _danceSteps,
        ),
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
        ResolutionPreset.low, // Use low resolution for faster processing
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

    if (_previousPoses.length > 3) { // Reduced buffer size for less delay
      _previousPoses.removeAt(0);
    }

    return smoothedPose;
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy || !mounted || !_isGameStarted || !_poseDetectionEnabled) return;

    final now = DateTime.now();
    if (_lastProcessingTime != null) {
      final timeSinceLast = now.difference(_lastProcessingTime!).inMilliseconds;
      if (timeSinceLast < 16) return; // Limit to ~60fps max
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
        _noPoseDetectedCount = 0;

        _calculateAlignment(smoothedPose);

        if (_isGameStarted && _currentStep < _danceSteps.length) {
          final Function(Pose) fn = _danceSteps[_currentStep]['scoringLogic'] as Function(Pose);
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
        _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.base));
      } catch (e) {
        debugPrint("Error reinitializing pose detector: $e");
      }
    } finally {
      _isBusy = false;
      if (mounted) setState(() {});
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _poseDetector.close();
    _countdownTimer?.cancel();
    _gameTimer?.cancel();
    _feedbackTimer?.cancel();
    _alignmentTimer?.cancel();

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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Practice Mode",
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
                            "Get ready to practice!",
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
                          // Removed dance name display
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
                          // Removed lyrics container
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

class PracticeResultScreen extends StatelessWidget {
  final int totalScore;
  final int percentage;
  final List<int> stepScores;
  final List<Map<String, dynamic>> danceSteps;

  const PracticeResultScreen({
    super.key,
    required this.totalScore,
    required this.percentage,
    required this.stepScores,
    required this.danceSteps,
  });

  @override
  Widget build(BuildContext context) {
    String resultText;
    Color resultColor;

    if (percentage >= 90) {
      resultText = "PERFECT! ($percentage%)";
      resultColor = Colors.deepOrange;
    } else if (percentage >= 70) {
      resultText = "VERY GOOD! ($percentage%)";
      resultColor = Colors.green;
    } else if (percentage >= 50) {
      resultText = "GOOD ($percentage%)";
      resultColor = Colors.blue;
    } else {
      resultText = "TRY AGAIN ($percentage%)";
      resultColor = Colors.red;
    }

    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "Practice Complete",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                "Total Score: $totalScore",
                style: const TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                resultText,
                style: TextStyle(
                  fontSize: 24,
                  color: resultColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: ListView(
                  children: [
                    const Text(
                      "Step Scores:",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    ...danceSteps.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final step = entry.value;
                      // Use description if name is not available
                      final stepName = step['name'] ?? step['description'] ?? 'Step ${idx + 1}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                stepName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            Text(
                              "${stepScores[idx]} pts",
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                    child: const Text(
                      "BACK",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PracticeModeScreen(user: {}),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    ),
                    child: const Text(
                      "PRACTICE AGAIN",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}