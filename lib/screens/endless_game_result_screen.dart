import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

class EndlessGameResultScreen extends StatelessWidget {
  final int totalScore;
  final int maxCombo;
  final int levelReached;
  final int posesCompleted;
  final int customPosesCount;
  final bool useCustomPoses;

  const EndlessGameResultScreen({
    super.key,
    required this.totalScore,
    required this.maxCombo,
    required this.levelReached,
    required this.posesCompleted,
    required this.customPosesCount,
    required this.useCustomPoses,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate performance rating based on score and level
    int performanceRating = _calculatePerformanceRating();

    String resultText;
    Color resultColor;
    int stars;

    if (performanceRating >= 90) {
      resultText = "LEGENDARY!";
      resultColor = Colors.purpleAccent;
      stars = 8;
    } else if (performanceRating >= 80) {
      resultText = "PHENOMENAL!";
      resultColor = Colors.deepPurple;
      stars = 7;
    } else if (performanceRating >= 70) {
      resultText = "EXCELLENT!";
      resultColor = Colors.blueAccent;
      stars = 6;
    } else if (performanceRating >= 60) {
      resultText = "GREAT!";
      resultColor = Colors.green;
      stars = 5;
    } else if (performanceRating >= 50) {
      resultText = "GOOD JOB!";
      resultColor = Colors.lightGreen;
      stars = 4;
    } else if (performanceRating >= 40) {
      resultText = "NOT BAD";
      resultColor = Colors.amber;
      stars = 3;
    } else if (performanceRating >= 30) {
      resultText = "KEEP PRACTICING";
      resultColor = Colors.orange;
      stars = 2;
    } else if (performanceRating >= 20) {
      resultText = "NEEDS WORK";
      resultColor = Colors.deepOrange;
      stars = 1;
    } else {
      resultText = "TRY AGAIN";
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
              painter: _EndlessResultBackgroundPainter(),
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
                  const SizedBox(height: 20),

                  // Mode indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: useCustomPoses ? Colors.purple : Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      useCustomPoses ? "CUSTOM MODE" : "NORMAL MODE",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

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
                              "Total Score: $totalScore",
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Performance: $performanceRating%",
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
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
                  const SizedBox(height: 20),

                  // Game stats with glassmorphic effect
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
                                "Game Statistics:",
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
                                    _buildStatRow("Max Combo", "$maxCombo", Colors.orange),
                                    _buildStatRow("Level Reached", "$levelReached", Colors.cyan),
                                    _buildStatRow("Poses Completed", "$posesCompleted", Colors.green),
                                    if (useCustomPoses)
                                      _buildStatRow("Custom Poses Used", "$customPosesCount", Colors.purpleAccent),
                                    _buildStatRow("Performance Rating", "$performanceRating%", Colors.amber),
                                    _buildStatRow("Game Mode", useCustomPoses ? "Custom" : "Normal",
                                        useCustomPoses ? Colors.purple : Colors.blue),
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

                  // Action buttons
                  Row(
                    children: [
                      // Play Again button
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.greenAccent, Colors.green],
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
                                    color: Colors.greenAccent.withOpacity(0.3),
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
                                    Navigator.pop(context); // Goes back to restart the game
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  splashColor: Colors.white.withOpacity(0.2),
                                  highlightColor: Colors.white.withOpacity(0.1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                    child: const Text(
                                      "PLAY AGAIN",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Main Menu button
                      Expanded(
                        child: ClipRRect(
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
                                    Navigator.popUntil(context, (route) => route.isFirst);
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  splashColor: Colors.white.withOpacity(0.2),
                                  highlightColor: Colors.white.withOpacity(0.1),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                    child: const Text(
                                      "MAIN MENU",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
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
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
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

  // Calculate performance rating based on game statistics
  int _calculatePerformanceRating() {
    // Base performance calculation
    double performance = 0.0;

    // Score component (up to 50 points)
    performance += (totalScore / 5000).clamp(0.0, 0.5) * 100;

    // Level component (up to 30 points)
    performance += (levelReached / 10).clamp(0.0, 0.3) * 100;

    // Combo component (up to 20 points)
    performance += (maxCombo / 50).clamp(0.0, 0.2) * 100;

    return performance.round().clamp(0, 100);
  }
}

// Custom painter for background animation in endless results screen
class _EndlessResultBackgroundPainter extends CustomPainter {
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
    final random = Random(DateTime.now().millisecondsSinceEpoch);

    for (var i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 3.1416 * 2;
      final radius = size.width * 0.4;
      final x = size.width / 2 + radius * cos(angle);
      final y = size.height / 2 + radius * sin(angle);

      canvas.drawCircle(Offset(x, y), random.nextDouble() * 3 + 1, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}