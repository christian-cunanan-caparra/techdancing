import 'dart:math';
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/api_service.dart';

class GameResultScreen extends StatefulWidget {
  final int totalScore;
  final int percentage;
  final int xpGained;
  final List<int> stepScores;
  final List<Map<String, dynamic>> danceSteps;
  final String userId;

  const GameResultScreen({
    super.key,
    required this.totalScore,
    required this.percentage,
    required this.xpGained,
    required this.stepScores,
    required this.danceSteps,
    required this.userId,
  });

  @override
  State<GameResultScreen> createState() => _GameResultScreenState();
}

class _GameResultScreenState extends State<GameResultScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _statsUpdated = false;
  bool _isOnline = true;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  @override
  void initState() {
    super.initState();

    _checkConnectivity();

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        _isOnline = result != ConnectivityResult.none;
      });

      // If we just came back online, try to update stats again
      if (_isOnline && !_statsUpdated) {
        _updateGameStats();
      }
    });

    _updateGameStats();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = connectivityResult != ConnectivityResult.none;
    });
  }

  Future<void> _updateGameStats() async {
    if (_statsUpdated || !_isOnline) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Update XP first
      final xpResult = await ApiService.updateUserXP(
          widget.userId,
          widget.xpGained
      );

      if (xpResult['status'] == 'success') {
        // Then update game statistics
        final statsResult = await ApiService.updateGameStats(
            widget.userId,
            widget.totalScore
        );

        if (statsResult['status'] == 'success') {
          // Update achievements
          final achievementsResult = await ApiService.updateUserAchievements(widget.userId);

          if (achievementsResult['status'] == 'success') {
            setState(() {
              _statsUpdated = true;
            });
          } else {
            // Handle achievement update failure
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(achievementsResult['message'] ?? "Failed to update achievements"),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        } else {
          // Handle game stats update failure
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(statsResult['message'] ?? "Failed to update game statistics"),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // Handle XP update failure
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(xpResult['message'] ?? "Failed to update XP"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error updating game stats: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update statistics. Please check your connection."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _retryUpdateStats() {
    if (_isOnline) {
      _updateGameStats();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No internet connection. Please check your network."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String resultText;
    Color resultColor;
    int stars;

    if (widget.percentage >= 90) {
      resultText = "LEGENDARY! (${widget.percentage}%)";
      resultColor = Colors.purpleAccent;
      stars = 8;
    } else if (widget.percentage >= 80) {
      resultText = "PHENOMENAL! (${widget.percentage}%)";
      resultColor = Colors.deepPurple;
      stars = 7;
    } else if (widget.percentage >= 70) {
      resultText = "EXCELLENT! (${widget.percentage}%)";
      resultColor = Colors.blueAccent;
      stars = 6;
    } else if (widget.percentage >= 60) {
      resultText = "GREAT! (${widget.percentage}%)";
      resultColor = Colors.green;
      stars = 5;
    } else if (widget.percentage >= 50) {
      resultText = "GOOD JOB! (${widget.percentage}%)";
      resultColor = Colors.lightGreen;
      stars = 4;
    } else if (widget.percentage >= 40) {
      resultText = "NOT BAD (${widget.percentage}%)";
      resultColor = Colors.amber;
      stars = 3;
    } else if (widget.percentage >= 30) {
      resultText = "KEEP PRACTICING (${widget.percentage}%)";
      resultColor = Colors.orange;
      stars = 2;
    } else if (widget.percentage >= 20) {
      resultText = "NEEDS WORK (${widget.percentage}%)";
      resultColor = Colors.deepOrange;
      stars = 1;
    } else {
      resultText = "TRY AGAIN (${widget.percentage}%)";
      resultColor = Colors.red;
      stars = 0;
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background with gradient matching MainMenuScreen
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D0B1E), Color(0xFF1A093B), Color(0xFF2D0A5C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Animated background elements
          Positioned.fill(
            child: CustomPaint(
              painter: _ResultBackgroundPainter(),
            ),
          ),

          // Online/Offline indicator
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _isOnline ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isOnline ? "Online" : "Offline",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isOnline ? "Updating your stats..." : "Waiting for connection...",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    "Game Over",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.pinkAccent,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Connection status message
                  if (!_isOnline && !_statsUpdated)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: const Text(
                        "Offline - Stats will update when connected",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 10),

                  // 8-Star Rating Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(8, (index) {
                      return Icon(
                        index < stars ? Icons.star : Icons.star_border,
                        color: _getStarColor(index, stars),
                        size: 40,
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "$stars/8 Stars",
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Score display with glassmorphic effect
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.pinkAccent.withOpacity(0.7),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Total Score: ${widget.totalScore}",
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "XP Gained: +${widget.xpGained}",
                              style: const TextStyle(
                                fontSize: 24,
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!_statsUpdated && _isOnline)
                              const SizedBox(height: 10),
                            if (!_statsUpdated && _isOnline)
                              TextButton(
                                onPressed: _retryUpdateStats,
                                child: const Text(
                                  "Retry Update",
                                  style: TextStyle(
                                    color: Colors.cyanAccent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Result text with glassmorphic effect
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: resultColor.withOpacity(0.7),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          resultText,
                          style: TextStyle(
                            fontSize: 24,
                            color: resultColor,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 10.0,
                                color: resultColor.withOpacity(0.5),
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Step scores with glassmorphic effect
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.cyanAccent.withOpacity(0.7),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
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
                              Expanded(
                                child: ListView(
                                  children: [
                                    ...widget.danceSteps.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final step = entry.value;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.03),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.1),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      step['name'],
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  ),
                                                  Text(
                                                    "${widget.stepScores[idx]} pts",
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // OK button with glassmorphic effect
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.cyanAccent, Colors.blueAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(20),
                            splashColor: Colors.white.withOpacity(0.2),
                            highlightColor: Colors.white.withOpacity(0.1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                              child: const Text(
                                "OK",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
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

  // Helper function to determine star colors based on position and earned status
  Color _getStarColor(int index, int stars) {
    if (index >= stars) return Colors.grey; // Not earned

    // Gradient of colors from first to last star
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

    return starColors[index];
  }
}

// Custom painter for background animation in results screen
class _ResultBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x20E91E63), Color(0x000D0B1E)],
        stops: [0.0, 0.8],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.25, size.height * 0.25),
        radius: size.width * 0.5,
      ));

    canvas.drawCircle(
      Offset(size.width * 0.25, size.height * 0.25),
      size.width * 0.5,
      paint,
    );

    final paint2 = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x2000BCD4), Color(0x000D0B1E)],
        stops: [0.0, 0.8],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.75, size.height * 0.75),
        radius: size.width * 0.4,
      ));

    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.75),
      size.width * 0.4,
      paint2,
    );

    // Draw some particles
    final particleCount = 20;
    final particlePaint = Paint()..color = Colors.white.withOpacity(0.1);

    for (var i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 3.1416 * 2;
      final radius = size.width * 0.4;
      final x = size.width / 2 + radius * cos(angle);
      final y = size.height / 2 + radius * sin(angle);

      canvas.drawCircle(Offset(x, y), 2.0, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}