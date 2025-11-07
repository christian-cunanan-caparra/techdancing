import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../services/music_service.dart';
import '../services/api_service.dart';
import 'practice_gameplay_screen.dart';

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
  late Animation<double> _fadeAnimation;

  int? _selectedDanceId;
  bool _isLoading = false;
  String _errorMessage = '';

  // List of dance names with their IDs
  final List<Map<String, dynamic>> dances = const [
    {'id': 1, 'name': 'JUMBO HOTDOG', 'difficulty': 'Easy', 'duration': '1:30'},
    {'id': 2, 'name': 'MODERNONG CHARING', 'difficulty': 'Easy', 'duration': '1:45'},
    {'id': 3, 'name': 'SALT', 'difficulty': 'Easy', 'duration': '1:45'},
  ];

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

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
    await Future.delayed(const Duration(milliseconds: 1500));

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
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  Widget _buildDanceCard(Map<String, dynamic> dance) {
    final bool isSelected = _selectedDanceId == dance['id'];
    final bool isSelecting = _isLoading && isSelected;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2D1070), Color(0xFF4A1DA3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? Colors.cyanAccent.withOpacity(0.4)
                    : Colors.black.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: isSelected ? Colors.cyanAccent : Colors.purpleAccent.withOpacity(0.5),
              width: isSelected ? 2 : 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(25),
              onTap: () => _selectDance(dance['id']),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            dance['name'],
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
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
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildInfoChip(
                          Icons.speed,
                          dance['difficulty'],
                          _getDifficultyColor(dance['difficulty']),
                        ),
                        const SizedBox(width: 15),
                        _buildInfoChip(
                          Icons.timer,
                          dance['duration'],
                          Colors.purpleAccent,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getDanceDescription(dance['id']),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 14,
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
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Title
                    const Text(
                      "Practice Mode",
                      style: TextStyle(
                        fontSize: 32,
                        color: Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
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

                    const SizedBox(height: 8),

                    const Text(
                      "No pressure, just practice!",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Dance cards
                    ...dances.map((dance) => _buildDanceCard(dance)).toList(),

                    // Error message
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
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