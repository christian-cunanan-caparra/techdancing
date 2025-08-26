// main_menu_screen.dart (XP removed)
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'multiplayer_screen.dart';
import 'leaderboard_screen.dart';
import '../services/music_service.dart';

class MainMenuScreen extends StatefulWidget {
  final Map user;

  const MainMenuScreen({super.key, required this.user});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final MusicService _musicService = MusicService();
  bool _isMuted = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
    _initializeMusic();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _musicService.resumeMusic(screenName: 'menu');
    } else if (state == AppLifecycleState.paused) {
      _musicService.pauseMusic();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeMusic() async {
    await _musicService.initialize();
    _musicService.playMenuMusic(screenName: 'menu');
    setState(() {
      _isMuted = _musicService.isMuted;
    });
  }

  Future<void> logout(BuildContext context) async {
    await _musicService.stopMusic();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void startGame(BuildContext context) {

    _musicService.pauseMusic();

    // Show a more stylish dialog instead of snackbar
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.black.withOpacity(0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.pinkAccent.withOpacity(0.7), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Coming Soon!",
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Single player mode is under development",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _musicService.resumeMusic(screenName: 'menu');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "OK",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void goToMultiplayer(BuildContext context) {

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MultiplayerScreen(user: widget.user),
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
      ),
    ).then((_) {
      _musicService.resumeMusic(screenName: 'menu');
    });
  }

  void goToLeaderboard(BuildContext context) {

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            LeaderboardScreen(userId: widget.user['id'].toString()),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    ).then((_) {
      _musicService.resumeMusic(screenName: 'menu');
    });
  }

  void _toggleMute() {

    _musicService.toggleMute();
    setState(() {
      _isMuted = _musicService.isMuted;
    });
  }

  @override
  Widget build(BuildContext context) {
    String name = widget.user['name'] ?? '';
    String level = widget.user['level']?.toString() ?? '1';


    return Scaffold(
      body: Stack(
        children: [
          // Background with gradient and animated particles
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
              painter: _BackgroundPainter(animation: _animationController),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Header with user info and mute button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // User info with glassmorphic effect
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.pinkAccent.withOpacity(0.7),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.person, color: Colors.cyanAccent, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.pinkAccent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "Lvl $level",
                                    style: const TextStyle(
                                      color: Colors.pinkAccent,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Mute button with glassmorphic effect
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.pinkAccent.withOpacity(0.7),
                                width: 1.5,
                              ),
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isMuted ? Icons.volume_off : Icons.volume_up,
                                color: Colors.cyanAccent,
                              ),
                              onPressed: _toggleMute,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Game title with animation
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        "BEAT\nBREAKER",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                              blurRadius: 15.0,
                              color: Colors.pinkAccent,
                              offset: Offset(0, 0),
                            ),
                            Shadow(
                              blurRadius: 20.0,
                              color: Colors.blueAccent,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtitle with animation
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: const Text(
                        "Feel the rhythm of the game",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  // Menu buttons with staggered animations
                  Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildAnimatedButton(
                          index: 0,
                          icon: Icons.play_arrow,
                          label: "QUICK PLAY",
                          onPressed: () => startGame(context),
                          gradientColors: [Colors.greenAccent, Colors.cyanAccent],
                        ),
                        _buildAnimatedButton(
                          index: 1,
                          icon: Icons.people,
                          label: "MULTIPLAYER",
                          onPressed: () => goToMultiplayer(context),
                          gradientColors: [Colors.blueAccent, Colors.purpleAccent],
                        ),
                        _buildAnimatedButton(
                          index: 2,
                          icon: Icons.leaderboard,
                          label: "RANKING",
                          onPressed: () => goToLeaderboard(context),
                          gradientColors: [Colors.amberAccent, Colors.orangeAccent],
                        ),
                        // _buildAnimatedButton(
                        //   index: 3,
                        //   icon: Icons.settings,
                        //   label: "SETTINGS",
                        //   onPressed: () {
                        //
                        //     // Add settings screen navigation
                        //   },
                        //   gradientColors: [Colors.deepPurpleAccent, Colors.pinkAccent],
                        // ),
                        _buildAnimatedButton(
                          index: 4,
                          icon: Icons.exit_to_app,
                          label: "LOGOUT",
                          onPressed: () => logout(context),
                          gradientColors: [Colors.redAccent, Colors.deepOrangeAccent],
                        ),
                      ],
                    ),
                  ),

                  // Footer with status only (XP removed)
                  SlideTransition(
                    position: _slideAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [

                          const SizedBox(height: 10),

                        ],
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

  Widget _buildAnimatedButton({
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required List<Color> gradientColors,
  }) {
    // Stagger the animation based on index
    final delayedAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.5 + (index * 0.1), 1.0, curve: Curves.easeOut),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FadeTransition(
        opacity: delayedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Interval(0.5 + (index * 0.1), 1.0, curve: Curves.easeOut),
            ),
          ),
          child: _buildGlassButton(
            icon: icon,
            label: label,
            onPressed: onPressed,
            gradientColors: gradientColors,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required List<Color> gradientColors,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                gradientColors[0].withOpacity(0.7),
                gradientColors[1].withOpacity(0.7),
              ],
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
                color: gradientColors[0].withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.white.withOpacity(0.2),
              highlightColor: Colors.white.withOpacity(0.1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
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
}

// Custom painter for background animation
class _BackgroundPainter extends CustomPainter {
  final Animation<double> animation;

  _BackgroundPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x20E91E63), Color(0x000D0B1E)],
        stops: [0.0, 0.8],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.25, size.height * 0.25),
        radius: size.width * 0.5 * animation.value,
      ));

    canvas.drawCircle(
      Offset(size.width * 0.25, size.height * 0.25),
      size.width * 0.5 * animation.value,
      paint,
    );

    final paint2 = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x2000BCD4), Color(0x000D0B1E)],
        stops: [0.0, 0.8],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.75, size.height * 0.75),
        radius: size.width * 0.4 * animation.value,
      ));

    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.75),
      size.width * 0.4 * animation.value,
      paint2,
    );

    // Draw some animated particles
    final particleCount = 20;
    final particlePaint = Paint()..color = Colors.white.withOpacity(0.1);

    for (var i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 3.1416 * 2;
      final radius = size.width * 0.4 * animation.value;
      final x = size.width / 2 + radius * cos(angle + animation.value * 3.1416);
      final y = size.height / 2 + radius * sin(angle + animation.value * 3.1416);

      canvas.drawCircle(Offset(x, y), 2.0, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}