import 'package:techdancing/screens/achievements_screen.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techdancing/screens/pactice_mode_screen.dart';
import 'package:techdancing/screens/profile_Screen.dart';
import 'login_screen.dart';
import 'multiplayer_screen.dart';
import 'leaderboard_screen.dart';
import '../services/music_service.dart';
import 'quickplay_screen.dart';
import '../services/api_service.dart';




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

  // Carousel controller and state
  final PageController _carouselController = PageController(viewportFraction: 0.8);
  int _currentCarouselIndex = 0;
  Timer? _carouselTimer;

  // Featured dance carousel
  final PageController _featuredDanceController = PageController(viewportFraction: 0.85);
  int _currentFeaturedDanceIndex = 0;

  // User data management
  Map<String, dynamic> _currentUser = {};
  bool _showLevelUp = false;
  int _previousLevel = 0;
  Timer? _autoRefreshTimer;
  Timer? _levelUpTimer;

  // Scroll controller
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize with the passed user data
    _currentUser = Map.from(widget.user);
    _ensureCorrectDataTypes();

    _previousLevel = _currentUser['level'] is int
        ? _currentUser['level']
        : int.tryParse(_currentUser['level']?.toString() ?? '1') ?? 1;

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Start auto-refresh after initial animation completes
        _startAutoRefresh();
        // Start carousel auto-scroll
        _startCarouselAutoScroll();
      }
    });

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

    _animationController.forward();
    _initializeMusic();
  }

  // Start automatic carousel scroll
  void _startCarouselAutoScroll() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_carouselController.hasClients) {
        int nextPage = _currentCarouselIndex + 1;
        if (nextPage >= 3) nextPage = 0;

        _carouselController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // Start automatic background refresh
  void _startAutoRefresh() {
    _fetchUserStats();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchUserStats();
    });
  }

  // Ensure all numeric values are properly converted to integers
  void _ensureCorrectDataTypes() {
    if (_currentUser['level'] is String) {
      _currentUser['level'] = int.tryParse(_currentUser['level']) ?? 1;
    }

    if (_currentUser['xp'] is String) {
      _currentUser['xp'] = int.tryParse(_currentUser['xp']) ?? 0;
    }

    if (_currentUser['xp_required'] is String) {
      _currentUser['xp_required'] = int.tryParse(_currentUser['xp_required']) ?? 100;
    }

    if (_currentUser['progress'] is String) {
      _currentUser['progress'] = double.tryParse(_currentUser['progress']) ?? 0.0;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _musicService.resumeMusic(screenName: 'menu');
      _fetchUserStats();
    } else if (state == AppLifecycleState.paused) {
      _musicService.pauseMusic();
    }
  }

  void _startPracticeMode(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PracticeModeScreen(user: _currentUser),
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

  @override
  void didUpdateWidget(MainMenuScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      setState(() {
        _currentUser = Map.from(widget.user);
        _ensureCorrectDataTypes();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _carouselController.dispose();
    _featuredDanceController.dispose();
    _scrollController.dispose();
    _carouselTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _levelUpTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeMusic() async {
    await _musicService.initialize();
    _musicService.playMenuMusic(screenName: 'menu');
    setState(() {
      _isMuted = _musicService.isMuted;
    });
  }

  // Fetch updated user stats from the server
  Future<void> _fetchUserStats() async {
    try {
      final response = await ApiService.getUserStats(_currentUser['id'].toString());

      if (response['status'] == 'success') {
        Map<String, dynamic> updatedUser = response['user'];

        if (updatedUser['level'] is String) {
          updatedUser['level'] = int.tryParse(updatedUser['level']) ?? 1;
        }

        if (updatedUser['xp'] is String) {
          updatedUser['xp'] = int.tryParse(updatedUser['xp']) ?? 0;
        }

        if (updatedUser['xp_required'] is String) {
          updatedUser['xp_required'] = int.tryParse(updatedUser['xp_required']) ?? 100;
        }

        if (updatedUser['progress'] is String) {
          updatedUser['progress'] = double.tryParse(updatedUser['progress']) ?? 0.0;
        }

        final newLevel = updatedUser['level'];

        if (newLevel > _previousLevel) {
          setState(() {
            _showLevelUp = true;
            _previousLevel = newLevel;
          });

          _levelUpTimer?.cancel();
          _levelUpTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _showLevelUp = false;
              });
            }
          });
        }

        if (_hasUserDataChanged(updatedUser)) {
          setState(() {
            _currentUser = updatedUser;
          });
          _updateStoredUserData();
        }
      }
    } catch (e) {
      print('Error fetching user stats: $e');
    }
  }

  bool _hasUserDataChanged(Map<String, dynamic> newData) {
    return newData['level'] != _currentUser['level'] ||
        newData['xp'] != _currentUser['xp'] ||
        newData['xp_required'] != _currentUser['xp_required'] ||
        newData['progress'] != _currentUser['progress'];
  }

  Future<void> _updateStoredUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(_currentUser));
  }

  Future<void> logout(BuildContext context) async {
    _autoRefreshTimer?.cancel();
    _levelUpTimer?.cancel();
    _carouselTimer?.cancel();
    await _musicService.stopMusic();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void goToAchievements(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AchievementsScreen(user: _currentUser),
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
      _fetchUserStats();
    });
  }

  void _startQuickPlay(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            QuickPlayScreen(user: _currentUser),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = (Offset.zero);
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
      _fetchUserStats();
    });
  }

  void goToMultiplayer(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            MultiplayerScreen(user: _currentUser),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = (Offset.zero);
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
      _fetchUserStats();
    });
  }

  void goToProfile(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ProfileScreen(user: _currentUser),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = (Offset.zero);
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  void goToLeaderboard(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            LeaderboardScreen(userId: _currentUser['id'].toString()),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = (Offset.zero);
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
      _fetchUserStats();
    });
  }

  void _toggleMute() {
    _musicService.toggleMute();
    setState(() {
      _isMuted = _musicService.isMuted;
    });
  }

  // Build featured dance card
  Widget _buildFeaturedDanceCard(int index) {
    final List<Map<String, dynamic>> featuredDances = [
      {
        'title': 'JUMBO HOTDOG',
        'artist': 'Masculados',
        'difficulty': 'Easy',
        'coaches': '1 Coach • 13132',
        'rating': 5,
        'gradient': [const Color(0xFF8A2387), const Color(0xFFE94057), const Color(0xFFF27121)],
      },
      {
        'title': 'ELECTRIC SLIDE',
        'artist': 'Beat Masters',
        'difficulty': 'Medium',
        'coaches': '2 Coaches • 24567',
        'rating': 4,
        'gradient': [const Color(0xFF2193b0), const Color(0xFF6dd5ed)],
      },
      {
        'title': 'MOONWALK',
        'artist': 'Space Dancers',
        'difficulty': 'Hard',
        'coaches': '3 Coaches • 39812',
        'rating': 5,
        'gradient': [const Color(0xFF834d9b), const Color(0xFFd04ed6)],
      },
    ];

    final dance = featuredDances[index];

    return GestureDetector(
      onTap: () {
        _startPracticeMode(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: dance['gradient'] as List<Color>,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: CustomPaint(
                  painter: _DancePatternPainter(),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Song title and artist
                  Text(
                    dance['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    dance['artist'] as String,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Difficulty and coach info
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor(dance['difficulty'] as String),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          dance['difficulty'] as String,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dance['coaches'] as String,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Score and rating
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "Best High Score",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),

                      const Spacer(),
                      const Text(
                        "IDSE",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Row(
                        children: List.generate(dance['rating'] as int, (index) => const Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 12,
                        )),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Play button
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 18,
                      ),
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

  // Helper method to get difficulty color
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.amber;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    int level = _currentUser['level'] is int
        ? _currentUser['level']
        : int.tryParse(_currentUser['level']?.toString() ?? '1') ?? 1;

    int xp = _currentUser['xp'] is int
        ? _currentUser['xp']
        : int.tryParse(_currentUser['xp']?.toString() ?? '0') ?? 0;

    int xpRequired = _currentUser['xp_required'] is int
        ? _currentUser['xp_required']
        : int.tryParse(_currentUser['xp_required']?.toString() ?? '100') ?? 100;

    double progress = _currentUser['progress'] is double
        ? _currentUser['progress']
        : double.tryParse(_currentUser['progress']?.toString() ?? '0.0') ?? 0.0;

    String name = _currentUser['name']?.toString() ?? '';

    return Scaffold(
      body: Stack(
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

          // Main content with fixed bottom navigation
          Column(
            children: [
              // Top section with user info and mute button
              const SizedBox(height: 40),

              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // Game title
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: const Text(
                            "BEAT BREAKER",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
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

                      const SizedBox(height: 8),

                      // Subtitle
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: const Text(
                          "Feel the rhythm of the game",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Announcements/Events carousel
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.43,
                        child: PageView.builder(
                          controller: _carouselController,
                          itemCount: 3,
                          onPageChanged: (index) {
                            setState(() {
                              _currentCarouselIndex = index;
                            });
                          },
                          itemBuilder: (context, index) {
                            return AnimatedBuilder(
                              animation: _carouselController,
                              builder: (context, child) {
                                double value = 1.0;
                                if (_carouselController.position.haveDimensions) {
                                  value = _carouselController.page! - index;
                                  value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                                }

                                return Transform.scale(
                                  scale: Curves.easeOut.transform(value),
                                  child: Opacity(
                                    opacity: value.clamp(0.7, 1.0),
                                    child: child,
                                  ),
                                );
                              },
                              child: _buildAnnouncementCard(index),
                            );
                          },
                        ),
                      ),

                      // Carousel indicators
                      Container(
                        height: 10,
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            return Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _currentCarouselIndex == index
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.4),
                              ),
                            );
                          }),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Quick Practice Section
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section Title
                            const Text(
                              "GAME MODE",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Quick practice cards
                            Row(
                              children: [
                                // Quick Play Card
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      _startQuickPlay(context);
                                    },
                                    child: Container(
                                      height: 120,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          // Background pattern
                                          Positioned.fill(
                                            child: Opacity(
                                              opacity: 0.1,
                                              child: CustomPaint(
                                                painter: _DancePatternPainter(),
                                              ),
                                            ),
                                          ),

                                          // Content
                                          Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(
                                                  Icons.flash_on,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  "Quick Play",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  "Jump right in",
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.8),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Practice Card
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      _startPracticeMode(context);
                                    },
                                    child: Container(
                                      height: 120,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Stack(
                                        children: [
                                          // Background pattern
                                          Positioned.fill(
                                            child: Opacity(
                                              opacity: 0.1,
                                              child: CustomPaint(
                                                painter: _DancePatternPainter(),
                                              ),
                                            ),
                                          ),

                                          // Content
                                          Padding(
                                            padding: const EdgeInsets.all(12.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(
                                                  Icons.school,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                                const SizedBox(height: 8),
                                                const Text(
                                                  "Practice",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  "Improve your skills",
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.8),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Multiplayer Card (functional)
                            GestureDetector(
                              onTap: () {
                                goToMultiplayer(context);
                              },
                              child: Container(
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    // Background pattern
                                    Positioned.fill(
                                      child: Opacity(
                                        opacity: 0.1,
                                        child: CustomPaint(
                                          painter: _DancePatternPainter(),
                                        ),
                                      ),
                                    ),

                                    // Content
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.group,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            "Multiplayer",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            "Play with friends",
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.8),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Featured Dance Section (carousel)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section Title
                            const Text(
                              "FEATURED DANCES",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Featured Dance Carousel
                            SizedBox(
                              height: 160,
                              child: PageView.builder(
                                controller: _featuredDanceController,
                                itemCount: 3,
                                onPageChanged: (index) {
                                  setState(() {
                                    _currentFeaturedDanceIndex = index;
                                  });
                                },
                                itemBuilder: (context, index) {
                                  return _buildFeaturedDanceCard(index);
                                },
                              ),
                            ),

                            // Carousel indicators
                            Container(
                              height: 10,
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (index) {
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _currentFeaturedDanceIndex == index
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.4),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Add some bottom padding to ensure content doesn't get hidden behind navigation
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Fixed bottom navigation
          // Fixed bottom navigation
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBottomButton(
                    icon: Icons.home,
                    label: "Home",
                    onPressed: () => _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                    ),
                  ),
                  _buildBottomButton(
                    icon: Icons.leaderboard,
                    label: "Ranking",
                    onPressed: () => goToLeaderboard(context),
                  ),
                  _buildBottomButton(
                    icon: Icons.emoji_events,
                    label: "Achievements",
                    onPressed: () => goToAchievements(context),
                  ),
                  _buildBottomButton(
                    icon: Icons.person,
                    label: "Profile",
                    onPressed: () => goToProfile(context),
                  ),
                  _buildBottomButton(
                    icon: Icons.exit_to_app,
                    label: "Logout",
                    onPressed: () => logout(context),
                  ),
                ],
              ),
            ),
          ),

          // Level up notification
          if (_showLevelUp)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 80,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "LEVEL UP!",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                          shadows: [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.orange,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "You've reached Level $level!",
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(int index) {
    final List<Map<String, dynamic>> announcements = [
      {
        'title': 'GAME DEPLOYMENT',
        'subtitle': 'Join the biggest dance event of the year!',
        'date': 'Comming soon...',
        'gradient': [const Color(0xFFFFD700), const Color(0xFFFF8C00)], // Gold to Orange
      },
      {
        'title': 'SONGS ADDED',
        'subtitle': 'Always check the updates New dance comming soon ',
        'date': 'Comming soon...',
        'gradient': [const Color(0xFF00BFFF), const Color(0xFF1E90FF)], // Deep Sky Blue to Dodger Blue
      },
      {
        'title': 'COMPETITION',
        'subtitle': 'Weekly challenges with amazing prizes',
        'date': 'Comming soon...',
        'gradient': [const Color(0xFF32CD32), const Color(0xFF228B22)], // Lime Green to Forest Green
      },
    ];

    final announcement = announcements[index];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            (announcement['gradient'][0] as Color).withOpacity(0.9),
            (announcement['gradient'][1] as Color).withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (announcement['gradient'][0] as Color).withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 3,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background pattern with reduced opacity
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: CustomPaint(
                  painter: _DancePatternPainter(),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    announcement['title'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    announcement['subtitle'] as String,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Date
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        announcement['date'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileCard(int level, int xp, int xpRequired, double progress, String name) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.purple.withOpacity(0.6), Colors.blue.withOpacity(0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            // Level badge
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Colors.amber, Colors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  level.toString(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // XP progress bar
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Container(
                        height: 6,
                        width: MediaQuery.of(context).size.width * 0.5 * progress,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.lightBlueAccent, Colors.blueAccent],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$xp/$xpRequired XP",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
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

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white, size: 24),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _DancePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw some dance pattern lines
    final path = Path();
    final step = 20.0;

    for (double i = 0; i < size.width; i += step) {
      path.moveTo(i, 0);
      path.lineTo(i, size.height);
    }

    for (double i = 0; i < size.height; i += step) {
      path.moveTo(0, i);
      path.lineTo(size.width, i);
    }

    canvas.drawPath(path, paint);

    // Draw some random dance icons
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final rng = Random();
    for (int i = 0; i < 15; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final radius = 2 + rng.nextDouble() * 3;

      canvas.drawCircle(Offset(x, y), radius, iconPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// Custom painter for carousel glow effect
class _CarouselGlowPainter extends CustomPainter {
  final int index;
  final double opacity;

  _CarouselGlowPainter({required this.index, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Define different glow colors for each carousel item
    final List<Color> glowColors = [
      const Color(0x30FFD700), // Gold for first item
      const Color(0x3000BFFF), // Blue for second item
      const Color(0x30FF4500), // Orange-red for third item
    ];

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [glowColors[index], Colors.transparent],
        stops: const [0.0, 0.8],
      ).createShader(Rect.fromCircle(
        center: Offset(centerX, centerY),
        radius: size.width * 0.4,
      ))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawCircle(
      Offset(centerX, centerY),
      size.width * 0.4,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CarouselGlowPainter oldDelegate) {
    return oldDelegate.index != index || oldDelegate.opacity != opacity;
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