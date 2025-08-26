// select_dance_screen.dart (enhanced)
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'gameplay_screen.dart';
import '../services/music_service.dart';
import 'package:flutter/scheduler.dart' show timeDilation;

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
  late Animation<Offset> _slideAnimation;

  int? _selectedDanceId;
  bool _isLoading = false;
  String _errorMessage = '';

  // List of dance names with their IDs
  final List<Map<String, dynamic>> dances = const [
    {'id': 1, 'name': 'HOTDOG NI JHUNIEL', 'difficulty': 'Easy', 'duration': '...'},
    {'id': 2, 'name': 'PAA TUHOD BALIKAT', 'difficulty': 'Easy', 'duration': '...'},
    // {'id': 3, 'name': 'ELECTRIC SLIDE', 'difficulty': 'Easy', 'duration': '2:00'},
    // {'id': 4, 'name': 'COTTON EYED JOE', 'difficulty': 'Medium', 'duration': '2:45'},
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

    final result = await ApiService.selectDance(widget.roomCode, danceId);

    if (result['status'] == 'success') {
      // Add a small delay to show the loading state
      await Future.delayed(const Duration(milliseconds: 500));

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
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['message'] ?? "Failed to select dance";
      });

      // If failed, resume music
      _musicService.resumeMusic(screenName: 'select_dance');

      // Clear error after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _errorMessage = '';
          });
        }
      });
    }
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
      case 3:
        return 'A classic line dance that never goes out of style. Great for groups!';
      case 4:
        return 'An upbeat country dance that will get everyone moving and having fun.';
      default:
        return 'A fantastic dance choice that will test your skills and provide great entertainment.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Select a Dance"),
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
                    "Pick a Dance for the Match",
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
                  Text(
                    "Room Code: ${widget.roomCode}",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.7),
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