import 'package:flutter/material.dart';
import 'package:techdancing/screens/main_menu_screen.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _currentUser;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;
  String _errorMessage = '';
  int _userRank = 0;
  List<dynamic> _rankingData = [];
  bool _isPopping = false; // Added flag to track if we're popping

  @override
  void initState() {
    super.initState();
    _currentUser = Map.from(widget.user);

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
    _loadUserStats();
    _loadRankingData();
  }

  // Helper function to get dancer title based on level
  String getDancerTitle(dynamic level) {
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
    return 'Beginner Dancer';
  }

  int getLevelAsInt(dynamic level) {
    if (level is String) {
      return int.tryParse(level) ?? 1;
    } else if (level is int) {
      return level;
    }
    return 1;
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

  // Check if user data belongs to current user by comparing IDs
  bool _isCurrentUser(dynamic userData) {
    if (userData == null) return false;

    // Try to get user ID from different possible field names
    final userId = _safeParseInt(userData['id'] ?? userData['user_id'] ?? userData['userId']);
    return userId == _safeParseInt(_currentUser['id']);
  }

  Future<void> _loadUserStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await ApiService.getUserStats(_currentUser['id'].toString());

      if (result['status'] == 'success' && result['user'] != null) {
        final userData = result['user'];

        setState(() {
          _currentUser = {
            'id': _safeParseInt(userData['id']),
            'name': _safeParseString(userData['name']),
            'email': _safeParseString(userData['email']),
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
          _errorMessage = result['message'] ?? 'Failed to load user statistics';
        });
      }
    } catch (e) {
      debugPrint('Error loading user stats: $e');
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRankingData() async {
    try {
      final data = await ApiService.getLeaderboard(_currentUser['id'].toString());

      // Find the user's rank by comparing IDs
      int userRank = 0;
      for (int i = 0; i < data.length; i++) {
        if (_isCurrentUser(data[i])) {
          userRank = i + 1;
          break;
        }
      }

      setState(() {
        _rankingData = data;
        _userRank = userRank;
      });
    } catch (e) {
      debugPrint('Error loading ranking data: $e');
      // Set default values to avoid UI errors
      setState(() {
        _userRank = 0;
        _rankingData = [];
      });
    }
  }

  Widget _buildRankingCard() {
    final displayRank = _userRank > 0 ? '#$_userRank' : 'Unranked';
    final totalPlayers = _rankingData.isNotEmpty ? _rankingData.length.toString() : '0';
    final topPercent = _userRank > 0 ? _calculateTopPercent().toStringAsFixed(1) + '%' : '0%';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GLOBAL RANKING',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 15),

          // Ranking information
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRankStatItem('Your Rank', displayRank, Icons.leaderboard),
              _buildRankStatItem('Total Players', totalPlayers, Icons.people),
              _buildRankStatItem('Top Percent', topPercent, Icons.trending_up),
            ],
          ),

          const SizedBox(height: 20),

          // Progress to next rank - only show if user is ranked
          if (_userRank > 1)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Progress to Next Rank',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        width: (MediaQuery.of(context).size.width - 80) * (_calculateRankProgress() / 100),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.pinkAccent, Colors.purpleAccent],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_calculateRankProgress().toStringAsFixed(1)}% to Rank #${_userRank - 1}",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
              ],
            ),

          // Show message if user is not ranked
          if (_userRank == 0)
            const Text(
              'Complete more games to get ranked!',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  double _calculateTopPercent() {
    if (_rankingData.isEmpty || _userRank == 0) return 0.0;
    return (_userRank / _rankingData.length) * 100;
  }

  double _calculateRankProgress() {
    if (_rankingData.isEmpty || _userRank <= 1) return 0.0;

    int currentLevel = _safeParseInt(_currentUser['level'], defaultValue: 1);
    int currentXP = _safeParseInt(_currentUser['xp']);
    int xpRequired = _safeParseInt(_currentUser['xp_required'], defaultValue: 100);

    double levelProgress = (currentXP / xpRequired) * 100;

    return (levelProgress * 0.7) + (30 * (1 - (_userRank / _rankingData.length)));
  }

  Widget _buildRankStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.purpleAccent, size: 24),
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

  // Modified back button handler with reverse animation
  Future<void> _handleBackButton() async {
    if (_isPopping) return; // Prevent multiple pops

    setState(() {
      _isPopping = true;
    });

    // Reverse the animation before popping
    await _animationController.reverse();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainMenuScreen(user: _currentUser),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int level = _safeParseInt(_currentUser['level'], defaultValue: 1);
    int xp = _safeParseInt(_currentUser['xp']);
    int xpRequired = _safeParseInt(_currentUser['xp_required'], defaultValue: 100);
    double progress = _safeParseDouble(_currentUser['progress']);
    String name = _safeParseString(_currentUser['name'], defaultValue: 'User');
    String email = _safeParseString(_currentUser['email'], defaultValue: 'No email');
    int gamesPlayed = _safeParseInt(_currentUser['games_played']);
    int highScore = _safeParseInt(_currentUser['high_score']);
    int totalScore = _safeParseInt(_currentUser['total_score']);
    String joinDate = _safeParseString(_currentUser['created_at'], defaultValue: 'Unknown');

    return PopScope(
      canPop: false, // Disable default back button behavior
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackButton();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0B1E),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D0B1E), Color(0xFF1A093B)],
            ),
          ),
          child: SafeArea(
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
                                onPressed: _handleBackButton,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'PROFILE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white),
                                onPressed: () {
                                  _showEditProfileDialog(context);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.white),
                                onPressed: () {
                                  _loadUserStats();
                                  _loadRankingData();
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

                          // User Profile Card
                          _buildProfileCard(name, email, joinDate, level, xp, xpRequired, progress),

                          const SizedBox(height: 20),

                          // Ranking Section
                          _buildRankingCard(),

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
      ),
    );
  }

  Widget _buildProfileCard(String name, String email, String joinDate, int level, int xp, int xpRequired, double progress) {
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
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(width: 20),

          // User Info with Level and XP
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

                // Email
                Text(
                  email,
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
            'GAME STATISTICS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
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
              _buildStatItem('Level', _safeParseInt(_currentUser['level']).toString(), Icons.leaderboard),
              _buildStatItem('XP', _safeParseInt(_currentUser['xp']).toString(), Icons.bolt),
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
    int gamesPlayed = _safeParseInt(_currentUser['games_played']);
    int level = _safeParseInt(_currentUser['level']);
    int highScore = _safeParseInt(_currentUser['high_score']);
    int totalScore = _safeParseInt(_currentUser['total_score']);

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
            'ACHIEVEMENTS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
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

  void _showEditProfileDialog(BuildContext context) {
    TextEditingController nameController = TextEditingController(
        text: _safeParseString(_currentUser['name'])
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1A093B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.purpleAccent),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.pinkAccent),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () {
                        // Update user name
                        setState(() {
                          _currentUser['name'] = nameController.text;
                        });
                        Navigator.pop(context);

                        // Show success message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile updated successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}