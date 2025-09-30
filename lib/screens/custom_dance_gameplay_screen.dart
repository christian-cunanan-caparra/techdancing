import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../services/api_service.dart';
import 'game_result_screen.dart';

class CustomDanceGameplayScreen extends StatefulWidget {
  final Map<String, dynamic> dance;
  final String userId;

  const CustomDanceGameplayScreen({
    super.key,
    required this.dance,
    required this.userId,
  });

  @override
  State<CustomDanceGameplayScreen> createState() => _CustomDanceGameplayScreenState();
}

class _CustomDanceGameplayScreenState extends State<CustomDanceGameplayScreen>
    with WidgetsBindingObserver {
  // Camera and Pose Detection
  CameraController? _controller;
  bool _isCameraInitialized = false;
  late PoseDetector _poseDetector;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  Size _imageSize = Size.zero;

  // Game State
  bool _isGameStarted = false;
  int _currentStep = 0;
  List<Map<String, dynamic>> _danceSteps = [];
  int _countdown = 3;
  Timer? _countdownTimer;
  Timer? _stepTimer;
  int _stepTimeRemaining = 0;
  bool _isLoadingSteps = true;

  // Scoring
  int _totalScore = 0;
  int _currentStepScore = 0;
  List<int> _stepScores = [];
  String _feedbackText = "";
  Color _feedbackColor = Colors.white;
  Timer? _feedbackTimer;
  bool _poseMatched = false;
  int _poseDetectionCount = 0;
  double _poseAccuracy = 0.0;

  // Enhanced scoring system
  final int _baseScore = 5000;
  final int _perfectScore = 100;
  final int _goodScore = 80;
  final int _okScore = 60;
  final int _minScore = 40;
  final double _accuracyThreshold = 0.6;

  // Pose comparison
  Pose? _currentPose;
  Map<String, dynamic>? _currentStepPoseData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _poseDetector = PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.accurate));
    _loadDanceSteps();
  }

  Future<void> _loadDanceSteps() async {
    try {
      final result = await ApiService.getCustomDanceSteps(widget.dance['id'].toString());

      if (result['status'] == 'success') {
        setState(() {
          _danceSteps = List<Map<String, dynamic>>.from(result['steps'] ?? []);
          _isLoadingSteps = false;
        });

        if (_danceSteps.isNotEmpty) {
          _startCountdown();
        } else {
          _showError('No steps found for this dance');
        }
      } else {
        _showError('Failed to load dance steps: ${result['message']}');
      }
    } catch (e) {
      _showError('Error loading dance steps: $e');
    }
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
    setState(() {
      _isGameStarted = true;
      _currentStep = 0;
      _totalScore = 0;
      _stepScores = List.filled(_danceSteps.length, 0);
      _loadCurrentStepPoseData();
      _startStepTimer();
    });
  }

  void _loadCurrentStepPoseData() {
    if (_currentStep < _danceSteps.length) {
      final step = _danceSteps[_currentStep];
      _currentStepPoseData = step['pose_data'];
    }
  }

  void _startStepTimer() {
    if (_currentStep >= _danceSteps.length) {
      _endGame();
      return;
    }

    final step = _danceSteps[_currentStep];
    final duration = step['duration'] is int ? step['duration'] : 8;

    setState(() {
      _stepTimeRemaining = duration;
      _currentStepScore = 0;
      _poseMatched = false;
      _poseDetectionCount = 0;
      _poseAccuracy = 0.0;
      _currentPose = null;
    });

    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_stepTimeRemaining > 0) {
          _stepTimeRemaining--;
        } else {
          timer.cancel();
          _nextStep();
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
      });
      _loadCurrentStepPoseData();
      _startStepTimer();
    } else {
      _endGame();
    }
  }

  void _endGame() {
    _stepTimer?.cancel();

    final maxPossibleScore = _danceSteps.length * _baseScore;
    final percentage = maxPossibleScore > 0 ? ((_totalScore / maxPossibleScore) * 100).round() : 0;
    final xpGained = (percentage ~/ 10) * 10 + 10;

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

  // ENHANCED POSE COMPARISON
  void _scoreCurrentPose(Pose currentPose) {
    if (_currentStep >= _danceSteps.length || !_isGameStarted) return;

    setState(() {
      _currentPose = currentPose;
      _poseDetectionCount++;
    });

    // Calculate accuracy if we have saved pose data
    if (_currentStepPoseData != null) {
      final accuracy = _calculatePoseAccuracy(currentPose, _currentStepPoseData!);

      setState(() {
        _poseAccuracy = accuracy;
      });

      if (accuracy >= _accuracyThreshold && !_poseMatched) {
        final score = _calculateScoreBasedOnAccuracy(accuracy);
        _addToScore(score);

        String feedback;
        Color color;
        if (accuracy >= 0.8) {
          feedback = "Perfect! +$score";
          color = Colors.green;
        } else if (accuracy >= 0.6) {
          feedback = "Great! +$score";
          color = Colors.lightGreen;
        } else {
          feedback = "Good! +$score";
          color = Colors.orange;
        }

        _updateFeedback(feedback, color);
        _poseMatched = true;

        // Allow scoring again after 1.5 seconds
        Timer(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _poseMatched = false;
            });
          }
        });
      } else if (accuracy < _accuracyThreshold && _poseMatched) {
        _updateFeedback("Keep the pose!", Colors.orange);
      }
    } else {
      // Fallback scoring if no pose data
      if (!_poseMatched) {
        final score = _calculateTimeBasedScore();
        _addToScore(score);
        _updateFeedback("Pose detected! +$score", Colors.green);
        _poseMatched = true;

        Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _poseMatched = false;
            });
          }
        });
      }
    }
  }

  double _calculatePoseAccuracy(Pose currentPose, Map<String, dynamic> savedPoseData) {
    double totalConfidence = 0.0;
    int landmarkCount = 0;

    for (final landmark in currentPose.landmarks.values) {
      final landmarkType = landmark.type.name;
      if (savedPoseData.containsKey(landmarkType)) {
        // Simple confidence-based accuracy
        totalConfidence += landmark.likelihood;
        landmarkCount++;
      }
    }

    if (landmarkCount == 0) return 0.0;

    final averageConfidence = totalConfidence / landmarkCount;

    // Additional check for key landmarks presence
    final keyLandmarks = ['left_shoulder', 'right_shoulder', 'left_hip', 'right_hip'];
    final keyLandmarksFound = keyLandmarks.where((landmark) =>
        currentPose.landmarks.values.any((l) => l.type.name == landmark)
    ).length;

    final keyLandmarkBonus = keyLandmarksFound / keyLandmarks.length * 0.3;

    return min(averageConfidence + keyLandmarkBonus, 1.0);
  }

  int _calculateScoreBasedOnAccuracy(double accuracy) {
    final step = _danceSteps[_currentStep];
    final totalDuration = step['duration'] is int ? step['duration'] : 8;
    final timeLeftRatio = _stepTimeRemaining / totalDuration;

    int baseScore;
    if (accuracy >= 0.8) baseScore = _perfectScore;
    else if (accuracy >= 0.7) baseScore = _goodScore;
    else if (accuracy >= 0.6) baseScore = _okScore;
    else baseScore = _minScore;

    // Time bonus for early completion
    if (timeLeftRatio > 0.7) {
      baseScore = (baseScore * 1.2).round();
    }

    return min(baseScore, _perfectScore);
  }

  int _calculateTimeBasedScore() {
    final step = _danceSteps[_currentStep];
    final totalDuration = step['duration'] is int ? step['duration'] : 8;
    final timeLeftRatio = _stepTimeRemaining / totalDuration;

    if (timeLeftRatio > 0.7) return _perfectScore;
    if (timeLeftRatio > 0.4) return _goodScore;
    if (timeLeftRatio > 0.1) return _okScore;
    return _minScore;
  }

  void _addToScore(int points) {
    setState(() {
      _currentStepScore = min(_currentStepScore + points, _baseScore);
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

  // Camera initialization
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
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
    if (_isBusy || !mounted || !_isGameStarted) return;
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        _scoreCurrentPose(poses.first);

        setState(() {
          _customPaint = CustomPaint(
            painter: PosePainter(
              poses,
              _imageSize,
              _controller!.description.lensDirection == CameraLensDirection.front,
            ),
          );
        });
      } else {
        setState(() => _customPaint = null);
        if (_feedbackText.isEmpty) {
          _updateFeedback("Move into frame", Colors.orange);
        }
      }
    } catch (e) {
      debugPrint("Pose detection error: $e");
      setState(() => _customPaint = null);
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
      debugPrint("InputImage error: $e");
      return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller != null) {
        _initializeCamera();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _poseDetector.close();
    _countdownTimer?.cancel();
    _stepTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isCameraInitialized && !_isLoadingSteps
          ? Stack(
        children: [
          // Camera Preview with better overlay
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
                    // Pose accuracy overlay
                    if (_currentPose != null && _poseAccuracy > 0)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: _getAccuracyColor(_poseAccuracy),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${(_poseAccuracy * 100).toInt()}%',
                                style: TextStyle(
                                  color: _getAccuracyColor(_poseAccuracy),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Enhanced Game UI
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with progress
                  _buildHeader(),

                  const Spacer(),

                  // Main game content
                  if (!_isGameStarted)
                    _buildCountdown()
                  else
                    _buildGameContent(),

                  const Spacer(),

                  // Bottom section with score and feedback
                  _buildBottomSection(),
                ],
              ),
            ),
          ),
        ],
      )
          : const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
            SizedBox(height: 16),
            Text(
              'Loading Dance Steps...',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.dance['name'] ?? 'Custom Dance',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(blurRadius: 8, color: Colors.black87)],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Step ${_currentStep + 1}/${_danceSteps.length}',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white70,
            shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
          ),
        ),
        // Progress bar
        if (_isGameStarted)
          Container(
            height: 6,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      width: constraints.maxWidth * ((_currentStep + 1) / _danceSteps.length),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blue, Colors.purple],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCountdown() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Center(
              child: Text(
                _countdown.toString(),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Get Ready!',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 5, color: Colors.black)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent() {
    final currentStepData = _danceSteps[_currentStep];

    return Column(
      children: [
        // Current step card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white30),
          ),
          child: Column(
            children: [
              Text(
                currentStepData['name'] ?? 'Step ${_currentStep + 1}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              if (currentStepData['description'] != null)
                Text(
                  currentStepData['description'],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Timer and score
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildInfoCard(
              icon: Icons.timer,
              value: '$_stepTimeRemaining s',
              label: 'Time Left',
            ),
            _buildInfoCard(
              icon: Icons.score,
              value: '$_currentStepScore',
              label: 'Step Score',
            ),
            _buildInfoCard(
              icon: Icons.auto_awesome,
              value: '$_poseDetectionCount',
              label: 'Poses',
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Accuracy indicator
        if (_poseAccuracy > 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: _getAccuracyColor(_poseAccuracy),
                ),
                const SizedBox(width: 8),
                Text(
                  'Accuracy: ${(_poseAccuracy * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 16,
                    color: _getAccuracyColor(_poseAccuracy),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard({required IconData icon, required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        // Total Score
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Text(
                'Total Score',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$_totalScore',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 5, color: Colors.black45)],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Feedback
        if (_feedbackText.isNotEmpty)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _feedbackColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: _feedbackColor.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getFeedbackIcon(),
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _feedbackText,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.8) return Colors.green;
    if (accuracy >= 0.6) return Colors.orange;
    return Colors.red;
  }

  IconData _getFeedbackIcon() {
    if (_feedbackColor == Colors.green) return Icons.check_circle;
    if (_feedbackColor == Colors.orange) return Icons.warning;
    return Icons.info;
  }
}

// Enhanced PosePainter with better visualization
class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size absoluteImageSize;
  final bool isFrontCamera;

  PosePainter(this.poses, this.absoluteImageSize, this.isFrontCamera);

  @override
  void paint(Canvas canvas, Size size) {
    final jointPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.blue;

    final landmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.red;

    final connectionPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.green;

    for (final pose in poses) {
      // Draw connections between landmarks
      _drawConnections(canvas, pose, size, connectionPaint);

      // Draw landmarks
      for (final landmark in pose.landmarks.values) {
        final point = _transformPoint(
          landmark.x,
          landmark.y,
          size,
        );

        // Draw landmark point
        canvas.drawCircle(point, 4, landmarkPaint);

        // Draw confidence circle
        final confidencePaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.white.withOpacity(landmark.likelihood);

        canvas.drawCircle(point, 6, confidencePaint);
      }
    }
  }

  void _drawConnections(Canvas canvas, Pose pose, Size size, Paint paint) {
    // Define pose connections (simplified skeleton)
    final connections = [
      ['left_shoulder', 'right_shoulder'],
      ['left_shoulder', 'left_elbow'],
      ['left_elbow', 'left_wrist'],
      ['right_shoulder', 'right_elbow'],
      ['right_elbow', 'right_wrist'],
      ['left_shoulder', 'left_hip'],
      ['right_shoulder', 'right_hip'],
      ['left_hip', 'right_hip'],
      ['left_hip', 'left_knee'],
      ['left_knee', 'left_ankle'],
      ['right_hip', 'right_knee'],
      ['right_knee', 'right_ankle'],
    ];

    for (final connection in connections) {
      final startLandmark = pose.landmarks[PoseLandmarkType.values.firstWhere(
            (e) => e.name == connection[0],
        orElse: () => PoseLandmarkType.nose,
      )];

      final endLandmark = pose.landmarks[PoseLandmarkType.values.firstWhere(
            (e) => e.name == connection[1],
        orElse: () => PoseLandmarkType.nose,
      )];

      if (startLandmark != null && endLandmark != null) {
        final start = _transformPoint(startLandmark.x, startLandmark.y, size);
        final end = _transformPoint(endLandmark.x, endLandmark.y, size);

        canvas.drawLine(start, end, paint);
      }
    }
  }

  Offset _transformPoint(double x, double y, Size size) {
    return Offset(
      isFrontCamera
          ? size.width - (x / absoluteImageSize.width * size.width)
          : x / absoluteImageSize.width * size.width,
      y / absoluteImageSize.height * size.height,
    );
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.poses != poses;
  }
}