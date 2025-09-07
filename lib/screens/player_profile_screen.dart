import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PlayerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> player;

  const PlayerProfileScreen({super.key, required this.player});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _player;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isPopping = false; // Added flag to track if we're popping

  @override
  void initState() {
    super.initState();
    _player = Map.from(widget.player);

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _animationController.forward();
    _loadPlayerStats();
  }

  // Helper function to get dancer title based on level
  String getDancerTitle(dynamic level) {
    // Convert level to int if it's a string
    int levelInt;
    if (level is String) {
      levelInt = int.tryParse(level) ?? 1;
    } else {
      levelInt = level as int? ?? 1;
    }

    if (levelInt >= 1 && levelInt <= 9) return 'Beginner Dancer';
    if (levelInt >= 10 && levelInt <= 19) return 'Rookie Groover';
    if (levelInt >= 20 && levelInt <= 29) return 'Rhythm Explorer';
    if (levelInt >= 30 && levelInt <= 39) return 'Step Master';
    if (levelInt >= 40 && levelInt <= 49) return 'Beat Rider';
    if (levelInt >= 50 && levelInt <= 59) return 'Groove Specialist';
    if (levelInt >= 60 && levelInt <= 69) return 'Dance Performer';
    if (levelInt >= 70 && levelInt <= 79) return 'Choreo Expert';
    if (levelInt >= 80 && levelInt <= 89) return 'Freestyle Pro';
    if (levelInt >= 90 && levelInt <= 94) return 'Dance Master';
    if (levelInt >= 95 && levelInt <= 98) return 'Stage Icon';
    if (levelInt == 99) return 'Legendary Dancer';
    return 'Beginner Dancer'; // default
  }

  // Helper function to safely get level as int
  int getLevelAsInt(dynamic level) {
    if (level is String) {
      return int.tryParse(level) ?? 1;
    } else if (level is int) {
      return level;
    }
    return 1; // default
  }

  // Safe parsing function to handle different data types
  int _safeParseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is double) return value.toInt();
    return defaultValue;
  }

  double _safeParseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  String _safeParseString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  Future<void> _loadPlayerStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await ApiService.getUserStats(_player['id'].toString());

      if (result['status'] == 'success' && result['user'] != null) {
        final userData = result['user'];

        setState(() {
          _player = {
            'id': _safeParseInt(userData['id']),
            'name': _safeParseString(userData['name']),
            'level': _safeParseInt(userData['level'], defaultValue: 1),
            'xp': _safeParseInt(userData['xp']),
            'xp_required': _safeParseInt(userData['xp_required'], defaultValue: 100),
            'progress': _safeParseDouble(userData['progress']),
            'games_played': _safeParseInt(userData['games_played']),
            'high_score': _safeParseInt(userData['high_score']),
            'total_score': _safeParseInt(userData['total_score']),
            'created_at': _safeParseString(userData['created_at'], defaultValue: 'Unknown'),
          };
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load player statistics';
        });
      }
    } catch (e) {
      debugPrint('Error loading player stats: $e');
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Modified back button handler with reverse animation
  Future<void> _handleBackButton() async {
    if (_isPopping) return; // Prevent multiple pops

    setState(() {
      _isPopping = true;
    });

    // Reverse the animation before popping
    await _animationController.reverse();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use safe parsing for all values
    int level = _safeParseInt(_player['level'], defaultValue: 1);
    int xp = _safeParseInt(_player['xp']);
    int xpRequired = _safeParseInt(_player['xp_required'], defaultValue: 100);
    double progress = _safeParseDouble(_player['progress']);
    String name = _safeParseString(_player['name'], defaultValue: 'Player');
    int gamesPlayed = _safeParseInt(_player['games_played']);
    int highScore = _safeParseInt(_player['high_score']);
    int totalScore = _safeParseInt(_player['total_score']);
    String joinDate = _safeParseString(_player['created_at'], defaultValue: 'Unknown');

    return PopScope(
      canPop: false, // Disable default back button behavior
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackButton();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0B1E),
        body: SafeArea(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with back button
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: _handleBackButton, // Use the new handler
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Player Profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              onPressed: () {
                                _loadPlayerStats();
                              },
                              tooltip: 'Refresh Stats',
                            ),
                          ],
                        ),

                        // Error message
                        if (_errorMessage.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.red),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _errorMessage = '';
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Player Profile Card
                        _buildProfileCard(name, joinDate, level, xp, xpRequired, progress),

                        const SizedBox(height: 20),

                        // Statistics Section
                        _buildStatisticsCard(gamesPlayed, highScore, totalScore),

                        const SizedBox(height: 20),

                        // Achievements Section
                        _buildAchievementsCard(),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),

                  // Loading overlay
                  if (_isLoading)
                    Container(
                      color: Colors.black.withOpacity(0.7),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                            ),
                            SizedBox(height: 20),
                            Text(
                              "Loading profile...",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
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
      ),
    );
  }

  Widget _buildProfileCard(String name, String joinDate, int level, int xp, int xpRequired, double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.purpleAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Colors.pinkAccent, Colors.purpleAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'P',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 20),

          // Player Info with Level and XP
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // Level and XP
                Row(
                  children: [
                    // Level Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.pinkAccent, Colors.purpleAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'LEVEL $level',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // XP
                    Text(
                      '$xp/$xpRequired XP',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // XP Progress Bar
                Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        height: 6,
                        width: (MediaQuery.of(context).size.width - 160) * (progress / 100),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.cyanAccent, Colors.blueAccent],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Progress Percentage
                Text(
                  "${progress.toStringAsFixed(1)}% to Level ${level + 1}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),

                const SizedBox(height: 8),

                // Dancer Title
                Text(
                  getDancerTitle(level),
                  style: TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),

                const SizedBox(height: 8),

                // Join Date
                Text(
                  'Joined: $joinDate',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(int gamesPlayed, int highScore, int totalScore) {
    // Calculate average score
    double averageScore = gamesPlayed > 0 ? totalScore / gamesPlayed : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amberAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Game Statistics',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 15),

          // Stats Grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Games Played', gamesPlayed.toString(), Icons.videogame_asset),
              _buildStatItem('High Score', highScore.toString(), Icons.emoji_events),
              _buildStatItem('Total Score', totalScore.toString(), Icons.star),
            ],
          ),

          const SizedBox(height: 20),

          // Additional stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Avg. Score', averageScore.toStringAsFixed(0), Icons.trending_up),
              _buildStatItem('Level', _safeParseInt(_player['level']).toString(), Icons.leaderboard),
              _buildStatItem('XP', _safeParseInt(_player['xp']).toString(), Icons.bolt),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.amberAccent, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsCard() {
    // Use safe parsing for achievement conditions
    int gamesPlayed = _safeParseInt(_player['games_played']);
    int level = _safeParseInt(_player['level']);
    int highScore = _safeParseInt(_player['high_score']);
    int totalScore = _safeParseInt(_player['total_score']);

    List<Map<String, dynamic>> achievements = [
      {
        'name': 'First Game',
        'completed': gamesPlayed > 0,
        'icon': Icons.star_border,
        'description': 'Complete your first game'
      },
      {
        'name': 'Level 10',
        'completed': level >= 10,
        'icon': Icons.emoji_events,
        'description': 'Reach level 10'
      },
      {
        'name': '100 Games',
        'completed': gamesPlayed >= 100,
        'icon': Icons.games,
        'description': 'Play 100 games'
      },
      {
        'name': 'High Score 1000',
        'completed': highScore >= 1000,
        'icon': Icons.trending_up,
        'description': 'Score 1000+ points in a game'
      },
      {
        'name': 'Score Master',
        'completed': totalScore >= 5000,
        'icon': Icons.star,
        'description': 'Reach 5000 total score'
      },
      {
        'name': 'Dedicated Dancer',
        'completed': gamesPlayed >= 50,
        'icon': Icons.celebration,
        'description': 'Play 50 games'
      },
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.greenAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Achievements',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 15),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 2.5,
            ),
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final achievement = achievements[index];
              return Tooltip(
                message: achievement['description'],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: achievement['completed']
                        ? Colors.green.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: achievement['completed']
                          ? Colors.greenAccent
                          : Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        achievement['icon'],
                        color: achievement['completed']
                            ? Colors.greenAccent
                            : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          achievement['name'],
                          style: TextStyle(
                            color: achievement['completed']
                                ? Colors.white
                                : Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(
                        achievement['completed']
                            ? Icons.check_circle
                            : Icons.lock,
                        color: achievement['completed']
                            ? Colors.greenAccent
                            : Colors.grey,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}