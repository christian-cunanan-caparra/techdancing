import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'gameplay_screen.dart';
import '../services/music_service.dart';

class SelectDanceScreen extends StatefulWidget {
  final Map user;
  final String roomCode;

  const SelectDanceScreen({
    super.key,
    required this.user,
    required this.roomCode,
  });

  @override
  State<SelectDanceScreen> createState() => _SelectDanceScreenState();
}

class _SelectDanceScreenState extends State<SelectDanceScreen>
    with SingleTickerProviderStateMixin {
  final MusicService _musicService = MusicService();
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  int? _selectedDanceId;
  bool _isLoading = true;
  String _statusMessage = 'Waiting for dance selection...';
  final Random _random = Random();

  // List of dance names with their IDs
  final List<Map<String, dynamic>> dances = const [
    {'id': 1, 'name': 'JUMBO HOTDOG', 'difficulty': 'Easy', 'duration': '2:30'},
    {'id': 2, 'name': 'MODELONG CHARING', 'difficulty': 'Medium', 'duration': '3:15'},

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

    // Automatically select a random dance through the server
    _selectRandomDance();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectRandomDance() async {
    if (dances.isEmpty) return;

    try {
      // Immediately select a dance without any waiting
      final result = await ApiService.selectRandomDance(widget.roomCode);

      if (result['status'] == 'success') {
        final danceId = result['dance_id'];
        await _handleDanceSelection(danceId);
      } else {
        // Fallback logic
        final roomCodeHash = widget.roomCode.hashCode;
        final randomIndex = roomCodeHash.abs() % dances.length;
        final selectedDance = dances[randomIndex];

        await ApiService.selectDance(widget.roomCode, selectedDance['id']);
        await _handleDanceSelection(selectedDance['id']);
      }
    } catch (e) {
      // If everything fails, use a fallback that's deterministic based on room code
      final roomCodeHash = widget.roomCode.hashCode;
      final randomIndex = roomCodeHash.abs() % dances.length;
      final selectedDance = dances[randomIndex];

      await _handleDanceSelection(selectedDance['id']);
    }
  }
  Future<void> _handleDanceSelection(int danceId) async {
    setState(() {
      _selectedDanceId = danceId;
      _statusMessage = 'Dance selected!';
    });

    // Stop music when a dance is selected
    _musicService.pauseMusic(rememberToResume: false);

    // Add a small delay to show the selected dance
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => GameplayScreen(
          danceId: danceId,
          roomCode: widget.roomCode,
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

  Widget _buildSelectedDanceCard() {
    if (_selectedDanceId == null) return Container();

    final dance = dances.firstWhere((d) => d['id'] == _selectedDanceId, orElse: () => dances[0]);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2D1070), Color(0xFF4A1DA3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: Colors.cyanAccent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.cyanAccent,
                size: 50,
              ),
              const SizedBox(height: 20),
              Text(
                "DANCE SELECTED!",
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
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              Text(
                dance['name'],
                style: const TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
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
      case 3:
        return 'A classic line dance that never goes out of style. Great for groups!';
      case 4:
        return 'An upbeat dance that will get everyone moving and having fun.';
      case 5:
        return 'A popular 90s dance that everyone knows and loves.';
      default:
        return 'A fantastic dance choice that will test your skills and provide great entertainment.';
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
        automaticallyImplyLeading: false,
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
                      "Dance Match",
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

                    Text(
                      "Room Code: ${widget.roomCode}",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Loading or selected dance
                    if (_isLoading && _selectedDanceId == null)
                      Column(
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                            strokeWidth: 4,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _statusMessage,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      )
                    else if (_selectedDanceId != null)
                      _buildSelectedDanceCard()
                    else
                      Container(),
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