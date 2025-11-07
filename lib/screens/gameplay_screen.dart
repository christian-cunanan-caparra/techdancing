import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../services/music_service.dart';
import '../services/video_cache_service.dart';
import 'game_result_screen.dart';
import 'dart:io';

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

class _GameplayScreenState extends State<GameplayScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  // ==================== SAFETY CONTROLS ====================
  bool _isDisposed = false;
  bool _isInitializing = true;

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  void _safeCancelTimer(Timer? timer) {
    try {
      timer?.cancel();
    } catch (e) {
      debugPrint("Timer cancel error: $e");
    }
  }

  // ==================== CAMERA ====================
  CameraController? _controller;
  bool _isCameraInitialized = false;
  late PoseDetector _poseDetector;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  Size _imageSize = Size.zero;

  // ==================== POSE DETECTION ====================
  bool _poseDetectionEnabled = true;
  int _noPoseDetectedCount = 0;

  // ==================== ALIGNMENT ====================
  Alignment _bodyAlignment = Alignment.center;
  double _bodyScale = 1.0;
  bool _showAlignmentGuide = true;
  String _alignmentFeedback = "";
  Timer? _alignmentTimer;
  bool _isPerfectlyAligned = false;

  // ==================== GAME STATE ====================
  bool _isGameStarted = false;
  int _currentStep = 0;
  late List<Map<String, dynamic>> _danceSteps;
  List<Pose> _previousPoses = [];
  int _countdown = 3;
  Timer? _countdownTimer;
  Timer? _gameTimer;
  int _timeRemaining = 120; // Extended to 2 minutes for longer dance
  final double _smoothingFactor = 0.3;

  // ==================== SCORING ====================
  int _totalScore = 0;
  int _currentStepScore = 0;
  String _feedbackText = "";
  Color _feedbackColor = Colors.white;
  Timer? _feedbackTimer;
  late List<int> _stepScores;
  bool _showScoreAnimation = false;
  int _lastScoreIncrement = 0;
  int _consecutiveGoodPoses = 0;

  // ==================== STAR RATING ====================
  int _currentStars = 0;
  int _maxStars = 8;
  List<AnimationController> _starControllers = [];
  List<Animation<double>> _starAnimations = [];
  bool _showStarRating = false;
  int _totalPossibleScore = 0;

  // ==================== SCORE ANIMATION ====================
  AnimationController? _scoreAnimationController;
  Animation<double>? _scoreScaleAnimation;
  Animation<Offset>? _scorePositionAnimation;

  // ==================== POSE MATCHING ====================
  bool _poseMatched = false;
  String _currentPoseType = "";
  Timer? _poseCooldownTimer;

  // ==================== VIDEO PLAYER ====================
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _showVideo = false;
  bool _isVideoPlaying = false;
  bool _videoError = false;
  bool _isVideoPreparing = false;
  Completer<void>? _videoInitializationCompleter;
  bool _videoPreloaded = false;
  bool _usingCachedVideo = false;
  bool _isVideoDisposed = false;

  // Video URLs
  final Map<int, String> _videoUrls = {
    1: 'https://admin-beatbreaker.site/flutter/1760483726917.mp4',
    2: 'https://admin-beatbreaker.site/flutter/1760482800834.mp4',
    3: 'https://admin-beatbreaker.site/flutter/1760479590483.mp4',
  };

  String? _currentVideoUrl;

  // ==================== NAVIGATION CONTROL ====================
  bool _isExiting = false;

  // ==================== WAIST MOVEMENT TRACKING ====================
  double _previousHipDifference = 0.0;
  bool _hasWaistMovement = false;

  // ==================== DISTANCE CONTROL ====================
  static const double MAX_SCALE_FOR_SCORING = 1.7;

  // ==================== INITIALIZATION ====================

  Future<String> _getDanceName(int danceId) async {
    try {
      final List<Map<String, dynamic>> dances = const [
        {'id': 1, 'name': 'JUMBO HOTDOG'},
        {'id': 2, 'name': 'MODELO'},
        {'id': 3, 'name': 'AVA MAX - SALT'},
      ];

      final dance = dances.firstWhere(
              (d) => d['id'] == danceId,
          orElse: () => {'name': 'Dance'}
      );

      return dance['name'];
    } catch (e) {
      return "Dance Challenge";
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      WidgetsBinding.instance.addObserver(this);

      // Initialize components sequentially for stability
      _loadDanceSteps();
      _initializeStarAnimations();
      _initializeScoreAnimation();

      _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.accurate));

      MusicService().pauseMusic(rememberToResume: false);

      // Start camera and video in parallel
      await Future.wait([
        _initializeCamera(),
        _preloadVideo(),
      ], eagerError: false);

      _safeSetState(() {
        _isInitializing = false;
      });

      _startCountdown();
    } catch (e, stack) {
      debugPrint("❌ App initialization error: $e\n$stack");
      _safeSetState(() {
        _isInitializing = false;
      });
      _startCountdown();
    }
  }

  void _initializeStarAnimations() {
    try {
      for (int i = 0; i < _maxStars; i++) {
        final controller = AnimationController(
          duration: const Duration(milliseconds: 300),
          vsync: this,
        );

        final animation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Curves.elasticOut,
        ));

        _starControllers.add(controller);
        _starAnimations.add(animation);
      }
    } catch (e) {
      debugPrint("Star animation error: $e");
    }
  }

  void _initializeScoreAnimation() {
    try {
      _scoreAnimationController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );

      _scoreScaleAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _scoreAnimationController!,
        curve: Curves.elasticOut,
      ));

      _scorePositionAnimation = Tween<Offset>(
        begin: const Offset(0, -0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _scoreAnimationController!,
        curve: Curves.easeOut,
      ));
    } catch (e) {
      debugPrint("Score animation error: $e");
    }
  }

  void _updateStarRating() {
    try {
      double percentage = _totalPossibleScore == 0 ? 0 : (_totalScore / _totalPossibleScore * 100).clamp(0.0, 100.0);

      int newStars = 0;
      if (percentage >= 90) newStars = 8;
      else if (percentage >= 80) newStars = 7;
      else if (percentage >= 70) newStars = 6;
      else if (percentage >= 60) newStars = 5;
      else if (percentage >= 50) newStars = 4;
      else if (percentage >= 40) newStars = 3;
      else if (percentage >= 30) newStars = 2;
      else if (percentage >= 20) newStars = 1;

      if (newStars > _currentStars) {
        _safeSetState(() {
          _currentStars = newStars;
          _showStarRating = true;
        });

        for (int i = 0; i < newStars; i++) {
          Future.delayed(Duration(milliseconds: i * 100), () {
            if (!_isDisposed && i < _starControllers.length) {
              try {
                _starControllers[i].forward();
              } catch (e) {
                debugPrint("Star controller error: $e");
              }
            }
          });
        }

        Timer(const Duration(seconds: 3), () {
          if (!_isDisposed) {
            _safeSetState(() {
              _showStarRating = false;
            });
          }
        });
      }
    } catch (e) {
      debugPrint("Star rating error: $e");
    }
  }

  void _triggerScoreAnimation() {
    try {
      if (_scoreAnimationController != null) {
        _scoreAnimationController!.reset();
        _scoreAnimationController!.forward();
      }
    } catch (e) {
      debugPrint("Score animation trigger error: $e");
    }
  }

  // ==================== NAVIGATION HANDLING ====================

  Future<bool> _showExitConfirmationDialog() async {
    if (_isExiting) return true;

    _isExiting = true;

    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Exit Game?"),
          content: const Text("Are you sure you want to quit? Your progress will be lost."),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text("Yes, Quit"),
            ),
          ],
        );
      },
    ) ?? false;

    _isExiting = false;
    return shouldExit;
  }

  Future<void> _exitGame() async {
    if (_isExiting) return;

    _isExiting = true;
    debugPrint("🔄 Exiting game safely...");

    // Stop all game activities
    _safeCancelTimer(_countdownTimer);
    _safeCancelTimer(_gameTimer);
    _safeCancelTimer(_feedbackTimer);
    _safeCancelTimer(_alignmentTimer);
    _safeCancelTimer(_poseCooldownTimer);

    try {
      MusicService().stopMusic();
    } catch (e) {
      debugPrint("Music stop error: $e");
    }

    // Dispose everything properly
    await _safeDisposeEverything();

    // Navigate back
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // ==================== VIDEO MANAGEMENT ====================

  Future<void> _safeVideoDispose() async {
    try {
      if (!_isVideoDisposed && _videoController.value.isInitialized) {
        _videoController.removeListener(_videoListener);
        await _videoController.pause();
        await _videoController.dispose();
      }
    } catch (e) {
      debugPrint("Safe video dispose error: $e");
    } finally {
      _isVideoDisposed = true;
      _isVideoInitialized = false;
      _isVideoPlaying = false;
    }
  }

  Future<void> _preloadVideo() async {
    if (_videoPreloaded || _isVideoDisposed) return;

    _safeSetState(() {
      _isVideoPreparing = true;
      _videoError = false;
    });

    _videoInitializationCompleter = Completer<void>();

    try {
      await _safeVideoDispose();

      _currentVideoUrl = _videoUrls[widget.danceId];
      if (_currentVideoUrl == null) {
        throw Exception("No video URL found for dance ${widget.danceId}");
      }

      final VideoCacheService cacheService = VideoCacheService();
      final String? cachedPath = await cacheService.getCachedVideoPath(widget.danceId);

      String videoSource;
      bool isCached = false;

      if (cachedPath != null && await File(cachedPath).exists()) {
        debugPrint("🎥 Using cached video");
        videoSource = cachedPath;
        isCached = true;
      } else {
        debugPrint("📥 Downloading video");
        await cacheService.cacheVideo(widget.danceId, _currentVideoUrl!);
        final String? newCachedPath = await cacheService.getCachedVideoPath(widget.danceId);

        if (newCachedPath != null && await File(newCachedPath).exists()) {
          debugPrint("✅ Using downloaded video");
          videoSource = newCachedPath;
          isCached = true;
        } else {
          debugPrint("🔄 Using direct network video");
          videoSource = _currentVideoUrl!;
          isCached = false;
        }
      }

      await _initializeVideoController(videoSource, isCached: isCached);

    } catch (error, stack) {
      debugPrint("❌ Video preload error: $error\n$stack");
      _safeSetState(() {
        _isVideoInitialized = false;
        _isVideoPreparing = false;
        _videoError = true;
        _videoPreloaded = false;
      });
      if (!_videoInitializationCompleter!.isCompleted) {
        _videoInitializationCompleter!.completeError(error);
      }
    }
  }

  Future<void> _initializeVideoController(String videoSource, {required bool isCached}) async {
    try {
      _isVideoDisposed = false;

      if (videoSource.startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(videoSource),
          httpHeaders: {'Cache-Control': 'max-age=3600'},
        );
      } else {
        _videoController = VideoPlayerController.file(File(videoSource));
      }

      _videoController.addListener(_videoListener);

      await _videoController.initialize().then((_) {
        if (_isDisposed || _isVideoDisposed) return;

        debugPrint("✅ Video initialized successfully");
        _safeSetState(() {
          _isVideoInitialized = true;
          _isVideoPreparing = false;
          _videoPreloaded = true;
          _usingCachedVideo = isCached;
          _videoError = false;
        });

        _videoController.setLooping(true);
        _videoController.setVolume(0.0);

        if (_videoController.value.isInitialized) {
          _videoController.play().then((_) {
            if (!_isDisposed && !_isVideoDisposed) {
              _videoController.pause();
              _videoController.seekTo(Duration.zero);
            }
          }).catchError((e) {
            debugPrint("Pre-buffer error: $e");
          });
        }

        if (!_videoInitializationCompleter!.isCompleted) {
          _videoInitializationCompleter!.complete();
        }
      }).catchError((error, stack) {
        debugPrint("❌ Video controller init error: $error\n$stack");
        if (_isDisposed) return;
        _safeSetState(() {
          _isVideoInitialized = false;
          _isVideoPreparing = false;
          _videoError = true;
          _videoPreloaded = false;
        });
        if (!_videoInitializationCompleter!.isCompleted) {
          _videoInitializationCompleter!.completeError(error);
        }
      });
    } catch (error, stack) {
      debugPrint("❌ Error creating video controller: $error\n$stack");
      if (_isDisposed) return;
      _safeSetState(() {
        _isVideoInitialized = false;
        _isVideoPreparing = false;
        _videoError = true;
        _videoPreloaded = false;
      });
      if (!_videoInitializationCompleter!.isCompleted) {
        _videoInitializationCompleter!.completeError(error);
      }
    }
  }

  Future<void> _playVideoSafely() async {
    if (_isDisposed || _isVideoDisposed) return;

    if (_isVideoPlaying && _videoController.value.isPlaying) {
      debugPrint("🎥 Video already playing, skipping restart");
      return;
    }

    if (!_videoPreloaded || _videoInitializationCompleter == null) {
      await _preloadVideo();
    }

    if (_isVideoPreparing && _videoInitializationCompleter != null) {
      try {
        await _videoInitializationCompleter!.future;
      } catch (e) {
        debugPrint("❌ Video failed to initialize: $e");
        _safeSetState(() => _videoError = true);
        return;
      }
    }

    if (!_isVideoInitialized || !_videoController.value.isInitialized || _videoController.value.hasError) {
      debugPrint("❌ Video not ready to play");
      _safeSetState(() => _videoError = true);
      return;
    }

    try {
      _safeSetState(() {
        _showVideo = true;
        _videoError = false;
      });

      if (!_videoController.value.isPlaying && _videoController.value.position.inSeconds > 1) {
        debugPrint("🎥 Resuming video from current position");
      } else {
        await _videoController.seekTo(Duration.zero);
      }

      await Future.delayed(const Duration(milliseconds: 50));

      if (_isDisposed || _isVideoDisposed) return;

      await _videoController.play().then((_) {
        if (!_isDisposed && !_isVideoDisposed) {
          _safeSetState(() {
            _isVideoPlaying = true;
            _videoError = false;
          });
          debugPrint("✅ Video playing/resumed successfully");
        }
      }).catchError((e) {
        debugPrint("❌ Error playing video: $e");
        if (!_isDisposed) {
          _safeSetState(() {
            _videoError = true;
            _isVideoPlaying = false;
          });
        }
      });

    } catch (error, stack) {
      debugPrint("❌ Unexpected video play error: $error\n$stack");
      if (!_isDisposed) {
        _safeSetState(() {
          _videoError = true;
          _isVideoPlaying = false;
        });
      }
    }
  }

  void _videoListener() {
    if (_isDisposed || _isVideoDisposed) return;

    if (_videoController.value.hasError) {
      debugPrint("❌ Video error: ${_videoController.value.errorDescription}");
      _safeSetState(() {
        _videoError = true;
        _isVideoPlaying = false;
      });
    } else if (_videoController.value.isPlaying) {
      _safeSetState(() {
        _isVideoPlaying = true;
        _videoError = false;
      });
    } else if (_videoController.value.isInitialized && !_videoController.value.isPlaying) {
      if (!_isDisposed) {
        _safeSetState(() {
          _videoError = false;
        });
      }
    }
  }

  // ==================== DANCE STEPS & SCORING ====================

  void _loadDanceSteps() {
    try {
      switch (widget.danceId) {
        case 1: // JUMBO HOTDOG
          _danceSteps = [
            {
              'name': 'Intro Sway',
              'description': 'Gentle side-to-side sway with arms',
              'duration': 8,
              'originalDuration': 8,
              'scoringLogic': _scoreIntroSway,
              'poseType': 'intro_sway',
            },
            {
              'name': 'Chacha Step',
              'description': 'Side chacha with arm movements',
              'duration': 9.5,
              'originalDuration': 9.5,
              'scoringLogic': _scoreChachaStep,
              'poseType': 'chacha_step',
            },
            {
              'name': 'Jumbo Pose',
              'description': 'Arms wide open, then pointing forward',
              'duration': 10,
              'originalDuration': 10,
              'scoringLogic': _scoreJumboPose,
              'poseType': 'jumbo_pose',
            },
            {
              'name': 'Hotdog Point',
              'description': 'Pointing forward with alternating arms',
              'duration': 10,
              'originalDuration': 10,
              'scoringLogic': _scoreHotdogPoint,
              'poseType': 'hotdog_point',
            },
            {
              'name': 'Final Celebration',
              'description': 'Hands on hips with confident stance',
              'duration': 5,
              'originalDuration': 5,
              'scoringLogic': _scoreFinalCelebration,
              'poseType': 'final_celebration',
            },
          ];
          break;

        case 2: // MODELO
          _danceSteps = [
            {
              'name': 'Model Pose',
              'description': 'Strike a model pose with confidence',
              'duration': 10,
              'originalDuration': 10,
              'scoringLogic': _scoreModelPose,
              'poseType': 'model_pose',
            },
            {
              'name': 'Arms Wave',
              'description': 'Wave arms gracefully side to side',
              'duration': 8,
              'originalDuration': 8,
              'scoringLogic': _scoreArmsWave,
              'poseType': 'arms_wave',
            },
            {
              'name': 'Hip Sway',
              'description': 'Sway hips from side to side',
              'duration': 8,
              'originalDuration': 8,
              'scoringLogic': _scoreHipSway,
              'poseType': 'hip_sway',
            },
            {
              'name': 'Star Pose',
              'description': 'Form a star shape with arms and legs',
              'duration': 3.2,
              'originalDuration': 3.2,
              'scoringLogic': _scoreStarPose,
              'poseType': 'star_pose',
            },
            {
              'name': 'Final Pose',
              'description': 'End with a dramatic finishing pose',
              'duration': 3,
              'originalDuration': 3,
              'scoringLogic': _scoreFinalPose,
              'poseType': 'final_pose',
            },
          ];
          break;

        case 3: // AVA MAX - SALT (PRECISE MUSIC TIMING)
          _danceSteps = [
            {
              'name': 'Intro Confidence',
              'description': "Strong stance with hands on hips - feel the beat",
              'duration': 8,
              'originalDuration': 8,
              'scoringLogic': _scoreSaltIntroPose,
              'poseType': 'salt_intro',
            },
            {
              'name': 'Verse Flow',
              'description': "Smooth body waves with shoulder rolls",
              'duration': 7,
              'originalDuration': 7,
              'scoringLogic': _scoreShoulderShimmer,
              'poseType': 'shoulder_shimmer',
            },
            {
              'name': 'Pre-Chorus Build',
              'description': "Arms rising with dramatic tension",
              'duration': 8,
              'originalDuration': 8,
              'scoringLogic': _scoreSaltPointCombo,
              'poseType': 'salt_point_combo',
            },
            {
              'name': 'Chorus Explosion',
              'description': "Big X-shaped arm crosses with powerful chest pops",
              'duration': 12,
              'originalDuration': 12,
              'scoringLogic': _scoreHipCircleFlow,
              'poseType': 'hip_circle_flow',
            },
            {
              'name': 'Arms Wave',
              'description': "Arms Wave",
              'duration': 8,
              'originalDuration': 8,
              'scoringLogic': _scoreArmsWave,
              'poseType': 'arms_wave_salt',
            },
            {
              'name': 'Verse 2 Texture',
              'description': "Isolated movements with attitude",
              'duration': 8,
              'originalDuration': 8,
              'scoringLogic': _scoreSaltSpinPrep,
              'poseType': 'salt_spin_prep',
            },
            {
              'name': 'Bridge Intensity',
              'description': "Dynamic level changes and sharp accents",
              'duration': 10,
              'originalDuration': 10,
              'scoringLogic': _scoreSaltIntroPose,
              'poseType': 'bridge_intensity',
            },
            {
              'name': 'Final Chorus Power',
              'description': "Full body engagement with big movements",
              'duration': 16,
              'originalDuration': 16,
              'scoringLogic': _scorePowerPoseHold,
              'poseType': 'power_pose_hold',
            },

          ];
          break;

        default:
          _danceSteps = [
            {
              'name': 'Basic Move',
              'description': 'Follow the rhythm',
              'duration': 10,
              'originalDuration': 10,
              'scoringLogic': _scoreIntroSway,
              'poseType': 'basic_move',
            },
          ];
      }

      _stepScores = List.filled(_danceSteps.length, 0);
      _totalPossibleScore = _danceSteps.length * 1000;
    } catch (e) {
      debugPrint("Dance steps load error: $e");
      _danceSteps = [
        {
          'name': 'Basic Move',
          'description': 'Follow the rhythm',
          'duration': 10,
          'originalDuration': 10,
          'scoringLogic': _scoreIntroSway,
          'poseType': 'basic_move',
        },
      ];
      _stepScores = [0];
      _totalPossibleScore = 1000;
    }
  }

  // ==================== ENHANCED SCORING SYSTEM ====================

  double get _alignmentMultiplier {
    try {
      // Prevent scoring when too close to camera
      if (_bodyScale > MAX_SCALE_FOR_SCORING) return 0.0;

      if (_isPerfectlyAligned) return 1.0;
      final dx = _bodyAlignment.x.abs();
      final dy = _bodyAlignment.y.abs();
      final scale = _bodyScale;

      // Prevent scoring when too close to camera or off frame
      final tooClose = scale > MAX_SCALE_FOR_SCORING;
      final offFrame = !(scale >= 0.4 && scale <= 1.8) || dx > 0.7 || dy > 0.7;

      if (offFrame || tooClose) return 0.0;

      final okAligned = (dx <= 0.4 && dy <= 0.4 && scale >= 0.5 && scale <= 1.6);
      if (okAligned) return 0.6;
      return 0.3;
    } catch (e) {
      return 0.5;
    }
  }

  int _detectWaistMovement(Pose pose) {
    try {
      final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
      final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

      if (leftHip == null || rightHip == null || leftShoulder == null || rightShoulder == null) {
        return 0;
      }

      // Calculate hip movement (side-to-side sway)
      final hipDifference = (leftHip.y - rightHip.y).abs();

      // Calculate shoulder-hip alignment difference (torso twist)
      final leftSideAlignment = (leftShoulder.x - leftHip.x).abs();
      final rightSideAlignment = (rightShoulder.x - rightHip.x).abs();
      final torsoTwist = (leftSideAlignment - rightSideAlignment).abs();

      // Check for significant waist movement
      final hasHipSway = hipDifference > 15;
      final hasTorsoTwist = torsoTwist > 20;

      if (hasHipSway || hasTorsoTwist) {
        _hasWaistMovement = true;
        return 100; // Additional points for waist movement
      }

      _hasWaistMovement = false;
      return 0;
    } catch (e) {
      debugPrint("Waist movement detection error: $e");
      return 0;
    }
  }

  // Enhanced scoring wrapper with distance control and pose cooldown
  void _safeScorePose(Pose pose, Function(Pose) scoringFunction, String poseType) {
    try {
      // Check if user is too close to camera - prevent ALL scoring
      if (_bodyScale > MAX_SCALE_FOR_SCORING) {
        _updateFeedback("Move back slightly!", Colors.orange);
        _poseMatched = false;
        return;
      }

      // Prevent immediate re-scoring of same pose
      if (_poseCooldownTimer != null && _poseCooldownTimer!.isActive && _currentPoseType == poseType) {
        return;
      }

      // Store original pose matched state
      final wasPoseMatched = _poseMatched;

      // Call the original scoring function
      scoringFunction(pose);

      // If pose was successfully matched
      if (_poseMatched && !wasPoseMatched) {
        // Set cooldown for this pose type
        _currentPoseType = poseType;
        _safeCancelTimer(_poseCooldownTimer);
        _poseCooldownTimer = Timer(const Duration(seconds: 2), () {
          _currentPoseType = "";
        });

        // Check for waist movement bonus
        final waistBonus = _detectWaistMovement(pose);
        if (waistBonus > 0) {
          _addToScore(waistBonus);
          _updateFeedback("+$waistBonus for waist movement!", Colors.lightGreen);
        }
      }
    } catch (e) {
      debugPrint("Scoring function error: $e");
    }
  }

  // Scoring function wrappers with pose types
  void _scoreModelPose(Pose pose) => _safeScorePose(pose, _scoreModelPoseImpl, 'model_pose');
  void _scoreArmsWave(Pose pose) => _safeScorePose(pose, _scoreArmsWaveImpl, 'arms_wave');
  void _scoreHipSway(Pose pose) => _safeScorePose(pose, _scoreHipSwayImpl, 'hip_sway');
  void _scoreStarPose(Pose pose) => _safeScorePose(pose, _scoreStarPoseImpl, 'star_pose');
  void _scoreFinalPose(Pose pose) => _safeScorePose(pose, _scoreFinalPoseImpl, 'final_pose');
  void _scoreIntroSway(Pose pose) => _safeScorePose(pose, _scoreIntroSwayImpl, 'intro_sway');
  void _scoreChachaStep(Pose pose) => _safeScorePose(pose, _scoreChachaStepImpl, 'chacha_step');
  void _scoreJumboPose(Pose pose) => _safeScorePose(pose, _scoreJumboPoseImpl, 'jumbo_pose');
  void _scoreHotdogPoint(Pose pose) => _safeScorePose(pose, _scoreHotdogPointImpl, 'hotdog_point');
  void _scoreFinalCelebration(Pose pose) => _safeScorePose(pose, _scoreFinalCelebrationImpl, 'final_celebration');

  // Ava Max Salt scoring functions
  void _scoreSaltIntroPose(Pose pose) => _safeScorePose(pose, _scoreSaltIntroPoseImpl, 'salt_intro');
  void _scoreShoulderShimmer(Pose pose) => _safeScorePose(pose, _scoreShoulderShimmerImpl, 'shoulder_shimmer');
  void _scoreSaltPointCombo(Pose pose) => _safeScorePose(pose, _scoreSaltPointComboImpl, 'salt_point_combo');
  void _scoreHipCircleFlow(Pose pose) => _safeScorePose(pose, _scoreHipCircleFlowImpl, 'hip_circle_flow');
  void _scoreArmWaveCascade(Pose pose) => _safeScorePose(pose, _scoreArmWaveCascadeImpl, 'arm_wave_cascade');
  void _scoreSaltSpinPrep(Pose pose) => _safeScorePose(pose, _scoreSaltSpinPrepImpl, 'salt_spin_prep');
  void _scoreQuickTurn(Pose pose) => _safeScorePose(pose, _scoreQuickTurnImpl, 'quick_turn');
  void _scorePowerPoseHold(Pose pose) => _safeScorePose(pose, _scorePowerPoseHoldImpl, 'power_pose_hold');
  void _scoreSaltEnding(Pose pose) => _safeScorePose(pose, _scoreSaltEndingImpl, 'salt_ending');

  // ==================== AVA MAX SALT SCORING IMPLEMENTATIONS ====================

  void _scoreSaltIntroPoseImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftWrist == null || rightWrist == null || leftHip == null || rightHip == null) {
      _poseMatched = false;
      _updateFeedback("Show your confident stance!", Colors.orange);
      return;
    }

    final leftHandOnHip = _distance(leftWrist, leftHip) < 60;
    final rightHandOnHip = _distance(rightWrist, rightHip) < 60;
    final handsOnHips = leftHandOnHip && rightHandOnHip;

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final shoulderConfidence = leftShoulder != null && rightShoulder != null ?
    (leftShoulder.x - rightShoulder.x).abs() > 50 : false;

    if (handsOnHips && shoulderConfidence) {
      if (!_poseMatched) {
        final base = 200 + Random().nextInt(100);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Perfect intro confidence! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
        Timer(const Duration(milliseconds: 1500), () => _poseMatched = false);
      }
    } else {
      _updateFeedback("Hands on hips, stand confident!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreShoulderShimmerImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
      return;
    }

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftShoulder == null || rightShoulder == null || leftWrist == null || rightWrist == null) {
      _poseMatched = false;
      _updateFeedback("Show your flow!", Colors.orange);
      return;
    }

    final shoulderDifference = (leftShoulder.y - rightShoulder.y).abs();
    final wristHeightDifference = (leftWrist.y - rightWrist.y).abs();
    final isFlowing = shoulderDifference > 20 || wristHeightDifference > 40;

    if (isFlowing) {
      if (!_poseMatched) {
        final base = 180 + Random().nextInt(120);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Beautiful flow! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
        Timer(const Duration(milliseconds: 1200), () => _poseMatched = false);
      }
    } else {
      _updateFeedback("Flow with the music!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreSaltPointComboImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) {
      _poseMatched = false;
      _updateFeedback("Arms up for drama!", Colors.orange);
      return;
    }

    final leftArmRaised = leftWrist.y < leftShoulder.y - 30;
    final rightArmRaised = rightWrist.y < rightShoulder.y - 30;
    final armsRising = leftArmRaised && rightArmRaised;

    final leftArmAngle = leftArmRaised ? (leftWrist.y - leftShoulder.y).abs() : 0;
    final rightArmAngle = rightArmRaised ? (rightWrist.y - rightShoulder.y).abs() : 0;
    final hasTension = leftArmAngle > 50 && rightArmAngle > 50;

    if (armsRising && hasTension) {
      if (!_poseMatched) {
        final base = 220 + Random().nextInt(130);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Dramatic build! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
        Timer(const Duration(milliseconds: 1000), () => _poseMatched = false);
      }
    } else {
      _updateFeedback("Arms up with tension!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreHipCircleFlowImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null || leftHip == null || rightHip == null) {
      _poseMatched = false;
      _updateFeedback("Big X-arms for chorus!", Colors.orange);
      return;
    }

    // Check for X-shaped arm crosses (arms crossing body midline)
    final leftArmCrossed = leftWrist.x > rightShoulder.x;
    final rightArmCrossed = rightWrist.x < leftShoulder.x;
    final armsCrossed = leftArmCrossed && rightArmCrossed;

    // Check for wide arm positions (alternative scoring)
    final leftArmWide = (leftWrist.x - leftShoulder.x).abs() > 100;
    final rightArmWide = (rightWrist.x - rightShoulder.x).abs() > 100;
    final armsWide = leftArmWide && rightArmWide;

    // Check for chest engagement (shoulder movement)
    final shoulderMovement = (leftShoulder.y - rightShoulder.y).abs() > 20;

    // Check for powerful stance (wide base)
    final hipWidth = (leftHip.x - rightHip.x).abs();
    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    final powerfulStance = hipWidth > 40 && shoulderWidth > 60;

    if ((armsCrossed || armsWide) && (shoulderMovement || powerfulStance)) {
      if (!_poseMatched) {
        final base = 280 + Random().nextInt(170);
        final score = (base * m).round();
        _addToScore(score);
        if (armsCrossed) {
          _updateFeedback("Perfect X-cross! +$score", Colors.green);
        } else {
          _updateFeedback("Chorus power! +$score", Colors.green);
        }
        _consecutiveGoodPoses++;
        _poseMatched = true;
        Timer(const Duration(milliseconds: 800), () => _poseMatched = false);
      }
    } else {
      _updateFeedback("Big X-arms with power!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreArmWaveCascadeImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
      return;
    }

    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftHip == null || rightHip == null || leftWrist == null || rightWrist == null) {
      _poseMatched = false;
      _updateFeedback("Groove with the beat!", Colors.orange);
      return;
    }

    final hipDifference = (leftHip.y - rightHip.y).abs();
    final isSwaying = hipDifference > 20;

    final wristHeightDifference = (leftWrist.y - rightWrist.y).abs();
    final isGrooving = wristHeightDifference > 30;

    if (isSwaying && isGrooving) {
      if (!_poseMatched) {
        final base = 190 + Random().nextInt(110);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Perfect groove! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
        Timer(const Duration(milliseconds: 1100), () => _poseMatched = false);
      }
    } else {
      _updateFeedback("Sway and groove!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreSaltSpinPrepImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftElbow = pose.landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = pose.landmarks[PoseLandmarkType.rightElbow];

    if (leftWrist == null || rightWrist == null || leftElbow == null || rightElbow == null) {
      _poseMatched = false;
      _updateFeedback("Show attitude!", Colors.orange);
      return;
    }

    final leftArmIsolated = (leftWrist.x - leftElbow.x).abs() < 40;
    final rightArmIsolated = (rightWrist.x - rightElbow.x).abs() < 40;
    final isIsolated = leftArmIsolated || rightArmIsolated;

    final wristHeight = (leftWrist.y - rightWrist.y).abs();
    final hasTexture = wristHeight > 35;

    if (isIsolated && hasTexture) {
      if (!_poseMatched) {
        final base = 210 + Random().nextInt(120);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Great texture! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
        Timer(const Duration(milliseconds: 900), () => _poseMatched = false);
      }
    } else {
      _updateFeedback("Sharp, isolated moves!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreQuickTurnImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
      return;
    }

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    if (leftShoulder == null || rightShoulder == null || leftHip == null || rightHip == null || leftWrist == null || rightWrist == null) {
      _poseMatched = false;
      _updateFeedback("Dynamic moves for bridge!", Colors.orange);
      return;
    }

    final shoulderHipDifference = ((leftShoulder.y + rightShoulder.y) / 2) - ((leftHip.y + rightHip.y) / 2);
    final levelChange = shoulderHipDifference.abs() > 30;

    final wristMovement = (leftWrist.y - rightWrist.y).abs();
    final hasAccents = wristMovement > 45;

    if (levelChange || hasAccents) {
      if (!_poseMatched) {
        final base = 230 + Random().nextInt(140);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Bridge intensity! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
        Timer(const Duration(milliseconds: 700), () => _poseMatched = false);
      }
    } else {
      _updateFeedback("Dynamic level changes!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scorePowerPoseHoldImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null || leftHip == null || rightHip == null) {
      _poseMatched = false;
      _updateFeedback("Full power for final chorus!", Colors.orange);
      return;
    }

    final leftArmExtended = (leftWrist.x - leftShoulder.x).abs() > 70;
    final rightArmExtended = (rightWrist.x - rightShoulder.x).abs() > 70;
    final armsBig = leftArmExtended || rightArmExtended;

    final shoulderWidth = (leftShoulder.x - rightShoulder.x).abs();
    final hipWidth = (leftHip.x - rightHip.x).abs();
    final strongStance = shoulderWidth > hipWidth * 0.8;

    if (armsBig && strongStance) {
      if (!_poseMatched) {
        final base = 280 + Random().nextInt(170);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Final chorus power! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
        Timer(const Duration(milliseconds: 600), () => _poseMatched = false);
      }
    } else {
      _updateFeedback("Big movements! Own the stage!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreSaltEndingImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null || leftHip == null || rightHip == null || leftShoulder == null || rightShoulder == null) {
      _poseMatched = false;
      _updateFeedback("Own the final moment!", Colors.orange);
      return;
    }

    final leftHandOnHip = _distance(leftWrist, leftHip) < 60;
    final rightHandOnHip = _distance(rightWrist, rightHip) < 60;
    final handsOnHips = leftHandOnHip && rightHandOnHip;

    final oneHandOnHip = leftHandOnHip != rightHandOnHip;
    final victoryArm = !leftHandOnHip ? leftWrist.y < leftShoulder.y - 50 : rightWrist.y < rightShoulder.y - 50;

    final shoulderConfidence = (leftShoulder.x - rightShoulder.x).abs() > 55;

    if ((handsOnHips || (oneHandOnHip && victoryArm)) && shoulderConfidence) {
      if (!_poseMatched) {
        final base = 400 + Random().nextInt(200);
        final score = (base * m).round();
        _addToScore(score);
        _updateFeedback("Perfect Salt finale! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
      }
    } else {
      _updateFeedback("Confident ending - own it!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  // ==================== EXISTING SCORING FUNCTIONS ====================

  void _scoreModelPoseImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
      return;
    }

    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    final upperBodyLandmarks = [leftHip, rightHip, leftShoulder, rightShoulder, leftWrist, rightWrist];
    final visibleLandmarks = upperBodyLandmarks.where((lm) => lm != null).length;

    if (visibleLandmarks < 4) {
      _poseMatched = false;
      _updateFeedback("Show your upper body!", Colors.orange);
      return;
    }

    bool handOnHip = false;
    if (leftWrist != null && leftHip != null) handOnHip = handOnHip || _distance(leftWrist, leftHip) < 60;
    if (rightWrist != null && rightHip != null) handOnHip = handOnHip || _distance(rightWrist, rightHip) < 60;

    final shoulderWidth = leftShoulder != null && rightShoulder != null ? (leftShoulder.x - rightShoulder.x).abs() : 0;
    final hipWidth = leftHip != null && rightHip != null ? (leftHip.x - rightHip.x).abs() : 0;
    final confidentStance = shoulderWidth > hipWidth * 0.7;

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
        _updateFeedback(handOnHip && armsInPosition ? "Perfect model pose! +$score" : "Good stance! +$score", Colors.green);
        _consecutiveGoodPoses++;
        _poseMatched = true;
        Timer(const Duration(milliseconds: 1000), () => _poseMatched = false);
      }
    } else {
      _updateFeedback("Strike a model pose!", Colors.orange);
      _consecutiveGoodPoses = 0;
      _poseMatched = false;
    }
  }

  void _scoreArmsWaveImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
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

  void _scoreHipSwayImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
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
        Timer(const Duration(milliseconds: 800), () => _poseMatched = false);
      }
    } else {
      if (_poseMatched) _updateFeedback("Keep swaying!", Colors.orange);
      _consecutiveGoodPoses = 0;
    }
  }

  void _scoreStarPoseImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
      return;
    }

    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null || rightWrist == null || leftAnkle == null || rightAnkle == null || leftShoulder == null || rightShoulder == null) {
      _poseMatched = false;
      _updateFeedback("Show your full body!", Colors.orange);
      return;
    }

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

  void _scoreFinalPoseImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
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

  void _scoreIntroSwayImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
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

  void _scoreChachaStepImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
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

  void _scoreJumboPoseImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
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

  void _scoreHotdogPointImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
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

  void _scoreFinalCelebrationImpl(Pose pose) {
    final m = _alignmentMultiplier;
    // Prevent scoring when too close to camera
    if (m == 0.0 || _bodyScale > MAX_SCALE_FOR_SCORING) {
      _poseMatched = false;
      _updateFeedback("Move into frame and maintain distance!", Colors.red);
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
    if (points <= 0 || _isDisposed) return;
    try {
      _safeSetState(() {
        _currentStepScore = min(_currentStepScore + points, 1000);
        _totalScore += points;
        _lastScoreIncrement = points;
        _showScoreAnimation = true;
        _noPoseDetectedCount = 0;
      });

      _updateStarRating();
      _triggerScoreAnimation();

      Timer(const Duration(milliseconds: 800), () {
        if (!_isDisposed) {
          _safeSetState(() {
            _showScoreAnimation = false;
          });
        }
      });
    } catch (e) {
      debugPrint("Add to score error: $e");
    }
  }

  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    try {
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
    } catch (e) {
      return 90.0;
    }
  }

  double _distance(PoseLandmark a, PoseLandmark b) {
    try {
      return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
    } catch (e) {
      return 100.0;
    }
  }

  void _updateFeedback(String text, Color color) {
    try {
      _safeSetState(() {
        _feedbackText = text;
        _feedbackColor = color;
      });

      _safeCancelTimer(_feedbackTimer);
      _feedbackTimer = Timer(const Duration(seconds: 2), () {
        if (!_isDisposed) {
          _safeSetState(() {
            _feedbackText = "";
          });
        }
      });
    } catch (e) {
      debugPrint("Update feedback error: $e");
    }
  }

  // ==================== GAME FLOW ====================

  void _startCountdown() {
    _safeCancelTimer(_countdownTimer);
    _countdown = 3;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      _safeSetState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          timer.cancel();
          _startGame();
        }
      });
    });
  }

  Future<void> _startGame() async {
    try {
      MusicService().playGameMusic(danceId: widget.danceId);
    } catch (e) {
      debugPrint("Music play error: $e");
    }

    if (!_videoPreloaded || _videoInitializationCompleter == null) {
      await _preloadVideo();
    }

    if (_videoInitializationCompleter != null) {
      try {
        await _videoInitializationCompleter!.future;
      } catch (e) {
        debugPrint("Video init failed: $e");
        _safeSetState(() => _videoError = true);
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    await _playVideoSafely();

    _safeSetState(() {
      _isGameStarted = true;
      _currentStep = 0;
      _timeRemaining = 120; // 2 minutes for longer dance
      _totalScore = 0;
      _currentStepScore = 0;
      _currentStars = 0;
      _stepScores = List.filled(_danceSteps.length, 0);
      _poseDetectionEnabled = true;
      _showAlignmentGuide = true;
      _isPerfectlyAligned = false;
      _currentPoseType = "";

      for (var step in _danceSteps) {
        step['duration'] = step['originalDuration'];
      }
    });

    _safeCancelTimer(_gameTimer);
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      _safeSetState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;

          if (_danceSteps[_currentStep]['duration'] > 0) {
            _danceSteps[_currentStep]['duration'] = _danceSteps[_currentStep]['duration'] - 1;
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
    try {
      debugPrint("🔄 Moving from step $_currentStep to ${_currentStep + 1}");

      _stepScores[_currentStep] = _currentStepScore;

      if (_currentStep < _danceSteps.length - 1) {
        _safeSetState(() {
          _currentStep++;
          _currentStepScore = 0;
          _poseMatched = false;
          _showAlignmentGuide = true;
          _isPerfectlyAligned = false;
          _currentPoseType = "";
          _danceSteps[_currentStep]['duration'] = _danceSteps[_currentStep]['originalDuration'];
        });
      } else {
        _endGame();
      }
    } catch (e) {
      debugPrint("Next step error: $e");
      _endGame();
    }
  }

  Future<void> _updateUserXP(int xpGained) async {
    try {
      final result = await ApiService.updateUserXP(widget.userId, xpGained);

      if (result['status'] == 'success' && result['leveled_up'] == true) {
        if (!_isDisposed && mounted) {
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
      debugPrint("❌ Error updating XP: $e");
    }
  }

  void _endGame() {
    try {
      _safeCancelTimer(_gameTimer);
      _safeCancelTimer(_poseCooldownTimer);

      try {
        MusicService().stopMusic();
      } catch (e) {
        debugPrint("Music stop error: $e");
      }

      if (!_isVideoDisposed && _videoController.value.isInitialized) {
        _videoController.pause();
      }

      final maxPossibleScore = _danceSteps.length * 1000;
      final percentage = maxPossibleScore == 0 ? 0 : (_totalScore / maxPossibleScore * 100).round();

      int xpGained = 0;
      if (percentage >= 250) xpGained = 100;
      else if (percentage >= 200) xpGained = 75;
      else if (percentage >= 100) xpGained = 50;
      else xpGained = 25;

      xpGained += (_consecutiveGoodPoses ~/ 10) * 10;

      if (!_isDisposed && mounted) {
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
      }

      _updateUserXP(xpGained);
    } catch (e, stack) {
      debugPrint("End game error: $e\n$stack");
      if (!_isDisposed && mounted) {
        Navigator.maybePop(context);
      }
    }
  }

  // ==================== CAMERA AND POSE DETECTION ====================

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
        if (_isDisposed) return;

        final previewSize = _controller!.value.previewSize!;
        _imageSize = Size(previewSize.height, previewSize.width);

        _controller!.startImageStream(_processCameraImage);

        _safeSetState(() => _isCameraInitialized = true);
      });
    } catch (e) {
      debugPrint("❌ Camera error: $e");
      if (!_isDisposed && mounted) {
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
        ).then((_) {
          if (!_isDisposed && mounted) {
            Navigator.pop(context);
          }
        });
      }
    }
  }

  void _calculateAlignment(Pose pose) {
    try {
      final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
      final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
      final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
      final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
      final nose = pose.landmarks[PoseLandmarkType.nose];

      final List<PoseLandmark?> keyLandmarks = [leftShoulder, rightShoulder, leftHip, rightHip, nose];
      final int visibleLandmarks = keyLandmarks.where((lm) => lm != null).length;

      if (visibleLandmarks < 3) {
        _safeSetState(() {
          _alignmentFeedback = "Show more of your body";
          _isPerfectlyAligned = false;
          _bodyAlignment = Alignment.center;
          _bodyScale = 1.0;
        });
        return;
      }

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

      // Enhanced feedback with distance awareness
      if (_bodyScale > MAX_SCALE_FOR_SCORING) {
        feedback = "Too close - move back";
      } else if (alignX.abs() > 0.3) {
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

      _safeSetState(() {
        _bodyAlignment = Alignment(alignX, alignY);
        _bodyScale = scale;
        _alignmentFeedback = feedback;
        _isPerfectlyAligned = isAligned;

        if (isAligned) {
          _safeCancelTimer(_alignmentTimer);
          _alignmentTimer = Timer(const Duration(seconds: 2), () {
            if (!_isDisposed) _safeSetState(() => _showAlignmentGuide = false);
          });
        } else {
          _showAlignmentGuide = true;
        }
      });
    } catch (e) {
      debugPrint("Alignment calculation error: $e");
    }
  }

  Pose _smoothPose(Pose newPose) {
    try {
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
    } catch (e) {
      debugPrint("Pose smoothing error: $e");
      return newPose;
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isBusy || _isDisposed || !_isGameStarted || !_poseDetectionEnabled) return;
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
          final String poseType = _danceSteps[_currentStep]['poseType'] as String;
          fn(smoothedPose);
        }

      } else {
        _customPaint = null;
        _noPoseDetectedCount++;

        if (_noPoseDetectedCount > 5) {
          _updateFeedback("Can't see you! Move into frame", Colors.red);
        }

        if (_noPoseDetectedCount > 15) {
          _safeSetState(() => _poseDetectionEnabled = false);
          Timer(const Duration(seconds: 2), () {
            if (!_isDisposed) _safeSetState(() => _poseDetectionEnabled = true);
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Pose detection error: $e");
      _customPaint = null;

      try {
        await _poseDetector.close();
        _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.accurate));
      } catch (e) {
        debugPrint("❌ Error reinitializing pose detector: $e");
      }
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
      debugPrint("❌ InputImage error: $e");
      return null;
    }
  }

  // ==================== APP LIFECYCLE ====================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;

    debugPrint("🔄 App lifecycle state: $state");

    if (state == AppLifecycleState.inactive) {
      try {
        _controller?.stopImageStream();
      } catch (e) {
        debugPrint("Camera stream stop error: $e");
      }
    }
    else if (state == AppLifecycleState.paused) {
      try {
        _controller?.stopImageStream();
      } catch (e) {
        debugPrint("Camera stream stop error: $e");
      }
    }
    else if (state == AppLifecycleState.resumed) {
      if (_controller != null && !_controller!.value.isInitialized) {
        _initializeCamera();
      } else if (_controller != null && !_controller!.value.isStreamingImages) {
        _controller!.startImageStream(_processCameraImage);
      }

      if (_isGameStarted && _showVideo && _isVideoInitialized && !_isVideoPlaying) {
        _playVideoSafely();
      }
    }
    else if (state == AppLifecycleState.detached) {
      _safeDisposeEverything();
    }
  }

  // ==================== ENHANCED DISPOSAL ====================

  Future<void> _safeDisposeEverything() async {
    _isDisposed = true;

    WidgetsBinding.instance.removeObserver(this);

    try {
      _controller?.dispose();
    } catch (e) {
      debugPrint("Controller dispose error: $e");
    }

    try {
      _poseDetector.close();
    } catch (e) {
      debugPrint("Pose detector close error: $e");
    }

    _safeCancelTimer(_countdownTimer);
    _safeCancelTimer(_gameTimer);
    _safeCancelTimer(_feedbackTimer);
    _safeCancelTimer(_alignmentTimer);
    _safeCancelTimer(_poseCooldownTimer);

    try {
      _scoreAnimationController?.dispose();
    } catch (e) {
      debugPrint("Score animation dispose error: $e");
    }

    for (var controller in _starControllers) {
      try {
        controller.dispose();
      } catch (e) {
        debugPrint("Star controller dispose error: $e");
      }
    }

    await _safeVideoDispose();

    try {
      MusicService().stopMusic();
    } catch (e) {
      debugPrint("Music stop error: $e");
    }
  }

  @override
  void dispose() {
    _safeDisposeEverything();
    super.dispose();
  }

  // ==================== UI WIDGETS ====================

  Widget _buildStarRating() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Overall Rating",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_maxStars, (index) {
              return AnimatedBuilder(
                animation: _starAnimations[index],
                builder: (context, child) {
                  return Transform.scale(
                    scale: _starAnimations[index].value,
                    child: Icon(
                      Icons.star,
                      color: index < _currentStars ? _getStarColor(index, _currentStars) : Colors.grey,
                      size: 24,
                    ),
                  );
                },
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            "$_currentStars/$_maxStars Stars",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStarColor(int index, int stars) {
    if (index >= stars) return Colors.grey;

    final List<Color> starColors = [
      Colors.amber,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.purpleAccent,
    ];

    return index < starColors.length ? starColors[index] : Colors.amber;
  }

  Widget _buildScoreAnimation() {
    if (_scoreAnimationController == null || _scoreScaleAnimation == null || _scorePositionAnimation == null) {
      return const SizedBox();
    }

    return AnimatedBuilder(
      animation: _scoreAnimationController!,
      builder: (context, child) {
        return Transform.translate(
          offset: _scorePositionAnimation!.value * 100,
          child: Transform.scale(
            scale: _scoreScaleAnimation!.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                "+$_lastScoreIncrement",
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text(
                "Initializing...",
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

          if (_usingCachedVideo && _showVideo)
            Positioned(
              top: 180,
              left: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.download_done, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      "CACHED",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_videoError)
            Positioned(
              top: 180,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      "Video Error",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

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

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
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
                          shadows: [
                            Shadow(blurRadius: 8, color: Colors.black),
                          ],
                        ),
                      ),
                      Text(
                        "Step Score: $_currentStepScore/1000",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          shadows: [
                            Shadow(blurRadius: 5, color: Colors.black),
                          ],
                        ),
                      ),
                    ],
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FutureBuilder<String>(
                        future: _getDanceName(widget.danceId),
                        builder: (context, snapshot) {
                          String danceName = "Dance Challenge";
                          if (snapshot.hasData) {
                            danceName = snapshot.data!;
                          }
                          return Text(
                            danceName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyanAccent,
                              shadows: [
                                Shadow(blurRadius: 5, color: Colors.black),
                              ],
                            ),
                          );
                        },
                      ),
                      Text(
                        "Room: ${widget.roomCode}",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          shadows: [
                            Shadow(blurRadius: 5, color: Colors.black),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (_showVideo)
                        Container(
                          width: 120,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _isVideoInitialized && !_videoError
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: AspectRatio(
                              aspectRatio: _videoController.value.aspectRatio,
                              child: VideoPlayer(_videoController),
                            ),
                          )
                              : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 8),
                                Text(
                                  "Loading...",
                                  style: TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_showStarRating && _isGameStarted)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: _buildStarRating(),
              ),
            ),

          if (_showScoreAnimation && _isGameStarted)
            Positioned.fill(
              child: Center(
                child: _buildScoreAnimation(),
              ),
            ),

          Center(
            child: !_isGameStarted
                ? Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 20),
                if (!_videoPreloaded)
                  const Column(
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 10),
                      Text(
                        "Preparing video...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
              ],
            )
                : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
              ],
            ),
          ),

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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return await _showExitConfirmationDialog();
      },
      child: _buildMainContent(),
    );
  }
}