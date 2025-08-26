import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'game_waiting_screen.dart';
import '../services/music_service.dart';

class MultiplayerScreen extends StatefulWidget {
  final Map user;

  const MultiplayerScreen({super.key, required this.user});

  @override
  State<MultiplayerScreen> createState() => _MultiplayerScreenState();
}

class _MultiplayerScreenState extends State<MultiplayerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final joinCodeController = TextEditingController();
  bool isLoading = false;
  String? roomCode;
  final MusicService _musicService = MusicService();
  bool _isMuted = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  // Focus node to manage keyboard
  final FocusNode _codeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
      _musicService.resumeMusic(screenName: 'multiplayer');
    } else if (state == AppLifecycleState.paused) {
      _musicService.pauseMusic();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _codeFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeMusic() async {
    await _musicService.initialize();
    _musicService.playMenuMusic(screenName: 'multiplayer');
    setState(() {
      _isMuted = _musicService.isMuted;
    });
  }

  Future<void> createRoom() async {
    setState(() => isLoading = true);
    final result = await ApiService.createRoom(widget.user['id'].toString());
    setState(() => isLoading = false);

    if (result['status'] == 'success') {
      roomCode = result['room_code'];
      // Don't pause music here, let the waiting screen handle it
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              GameWaitingScreen(
                user: widget.user,
                roomCode: roomCode!,
                isHost: true,
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
        ),
      );
    } else {
      _showError(result['message']);
    }
  }

  Future<void> joinRoom() async {
    final code = joinCodeController.text.trim();
    if (code.isEmpty) return _showError("Please enter a room code.");

    setState(() => isLoading = true);
    final result = await ApiService.joinRoom(code, widget.user['id'].toString());
    setState(() => isLoading = false);

    if (result['status'] == 'success') {
      // Don't pause music here, let the waiting screen handle it
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              GameWaitingScreen(
                user: widget.user,
                roomCode: code,
                isHost: false,
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
        ),
      );
    } else {
      _showError(result['message']);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _toggleMute() {
    _musicService.toggleMute();
    setState(() {
      _isMuted = _musicService.isMuted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Multiplayer"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          // Mute button with glassmorphic effect
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ClipRRect(
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
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            // Background with gradient
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

            // Content with SingleChildScrollView to prevent overflow
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height -
                        MediaQuery.of(context).padding.vertical -
                        48, // 48 is total vertical padding
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Title with animation
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: const Text(
                            "MULTIPLAYER",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              shadows: [
                                Shadow(
                                  blurRadius: 10.0,
                                  color: Colors.pinkAccent,
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
                        child: const Text(
                          "Battle with other players",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Create Room Button
                      _buildAnimatedButton(
                        index: 0,
                        label: "CREATE ROOM",
                        icon: Icons.add,
                        onPressed: createRoom,
                        gradientColors: [Colors.greenAccent, Colors.cyanAccent],
                      ),

                      const SizedBox(height: 30),

                      // Divider with "OR" text
                      SlideTransition(
                        position: _slideAnimation,
                        child: Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withOpacity(0.3),
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                "OR",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withOpacity(0.3),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Join Room Section
                      SlideTransition(
                        position: _slideAnimation,
                        child: const Text(
                          "Join an existing room",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Room Code Input Field
                      SlideTransition(
                        position: _slideAnimation,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
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
                                  const SizedBox(width: 16),
                                  const Icon(Icons.meeting_room, color: Colors.cyanAccent),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextField(
                                      controller: joinCodeController,
                                      focusNode: _codeFocusNode,
                                      style: const TextStyle(color: Colors.cyanAccent),
                                      cursorColor: Colors.pinkAccent,
                                      decoration: const InputDecoration(
                                        hintText: 'ENTER ROOM CODE',
                                        hintStyle: TextStyle(color: Colors.cyanAccent),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Join Room Button
                      _buildAnimatedButton(
                        index: 1,
                        label: "JOIN ROOM",
                        icon: Icons.login,
                        onPressed: joinRoom,
                        gradientColors: [Colors.deepPurpleAccent, Colors.purpleAccent],
                      ),

                      // Add some extra space at the bottom for keyboard
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedButton({
    required int index,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required List<Color> gradientColors,
  }) {
    // Stagger the animation based on index
    final delayedAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.5 + (index * 0.2), 1.0, curve: Curves.easeOut),
      ),
    );

    return FadeTransition(
      opacity: delayedAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Interval(0.5 + (index * 0.2), 1.0, curve: Curves.easeOut),
          ),
        ),
        child: _buildGlassButton(
          label: label,
          icon: icon,
          onPressed: isLoading ? null : onPressed,
          gradientColors: gradientColors,
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
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
                    if (isLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 2,
                        ),
                      )
                    else
                      Icon(icon, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      isLoading ? "PROCESSING..." : label,
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