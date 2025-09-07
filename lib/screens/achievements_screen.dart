import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techdancing/screens/main_menu_screen.dart';
import '../services/api_service.dart';

class AchievementsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const AchievementsScreen({super.key, required this.user});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _currentUser;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _achievements = [];

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
    _loadAchievements();
  }

  // Helper function to parse values safely
  int _safeParseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is double) return value.toInt();
    return defaultValue;
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // In a real app, you would fetch achievements from your API
      // For now, we'll simulate with local data
      await Future.delayed(const Duration(milliseconds: 500));

      int gamesPlayed = _safeParseInt(_currentUser['games_played']);
      int level = _safeParseInt(_currentUser['level']);
      int highScore = _safeParseInt(_currentUser['high_score']);
      int totalScore = _safeParseInt(_currentUser['total_score']);
      int multiplayerWins = _safeParseInt(_currentUser['multiplayer_wins']);
      int perfectScores = _safeParseInt(_currentUser['perfect_scores']);

      setState(() {
        _achievements = [
          {
            'id': 'first_game',
            'name': 'First Steps',
            'description': 'Complete your first dance game',
            'icon': Icons.star_border,
            'completed': gamesPlayed > 0,
            'progress': gamesPlayed > 0 ? 1 : 0,
            'target': 1,
            'reward': '10 XP',
            'category': 'General',
            'unlockedAt': gamesPlayed > 0 ? DateTime.now() : null,
          },
          {
            'id': 'level_10',
            'name': 'Rising Star',
            'description': 'Reach level 10',
            'icon': Icons.emoji_events,
            'completed': level >= 10,
            'progress': level > 10 ? 10 : level,
            'target': 10,
            'reward': 'Special Avatar Frame',
            'category': 'Progression',
            'unlockedAt': level >= 10 ? DateTime.now() : null,
          },
          {
            'id': 'level_25',
            'name': 'Dance Expert',
            'description': 'Reach level 25',
            'icon': Icons.workspace_premium,
            'completed': level >= 25,
            'progress': level > 25 ? 25 : level,
            'target': 25,
            'reward': 'Exclusive Dance Move',
            'category': 'Progression',
            'unlockedAt': level >= 25 ? DateTime.now() : null,
          },
          {
            'id': 'level_50',
            'name': 'Master Dancer',
            'description': 'Reach level 50',
            'icon': Icons.celebration,
            'completed': level >= 50,
            'progress': level > 50 ? 50 : level,
            'target': 50,
            'reward': 'Legendary Title',
            'category': 'Progression',
            'unlockedAt': level >= 50 ? DateTime.now() : null,
          },
          {
            'id': 'games_10',
            'name': 'Consistent Groover',
            'description': 'Play 10 games',
            'icon': Icons.repeat,
            'completed': gamesPlayed >= 10,
            'progress': gamesPlayed > 10 ? 10 : gamesPlayed,
            'target': 10,
            'reward': '25 XP',
            'category': 'General',
            'unlockedAt': gamesPlayed >= 10 ? DateTime.now() : null,
          },
          {
            'id': 'games_50',
            'name': 'Dedicated Dancer',
            'description': 'Play 50 games',
            'icon': Icons.local_activity,
            'completed': gamesPlayed >= 50,
            'progress': gamesPlayed > 50 ? 50 : gamesPlayed,
            'target': 50,
            'reward': 'Special Emote',
            'category': 'General',
            'unlockedAt': gamesPlayed >= 50 ? DateTime.now() : null,
          },
          {
            'id': 'games_100',
            'name': 'Dance Marathoner',
            'description': 'Play 100 games',
            'icon': Icons.military_tech,
            'completed': gamesPlayed >= 100,
            'progress': gamesPlayed > 100 ? 100 : gamesPlayed,
            'target': 100,
            'reward': 'Golden Avatar',
            'category': 'General',
            'unlockedAt': gamesPlayed >= 100 ? DateTime.now() : null,
          },
          {
            'id': 'score_1000',
            'name': 'Score Champion',
            'description': 'Score 1000+ points in a single game',
            'icon': Icons.trending_up,
            'completed': highScore >= 1000,
            'progress': highScore > 1000 ? 1000 : highScore,
            'target': 1000,
            'reward': 'Score Boost',
            'category': 'Performance',
            'unlockedAt': highScore >= 1000 ? DateTime.now() : null,
          },
          {
            'id': 'score_5000',
            'name': 'High Score Hero',
            'description': 'Score 5000+ points in a single game',
            'icon': Icons.leaderboard,
            'completed': highScore >= 5000,
            'progress': highScore > 5000 ? 5000 : highScore,
            'target': 5000,
            'reward': 'Score Multiplier',
            'category': 'Performance',
            'unlockedAt': highScore >= 5000 ? DateTime.now() : null,
          },
          {
            'id': 'total_10000',
            'name': 'Point Collector',
            'description': 'Reach 10,000 total points',
            'icon': Icons.star,
            'completed': totalScore >= 10000,
            'progress': totalScore > 10000 ? 10000 : totalScore,
            'target': 10000,
            'reward': '100 XP',
            'category': 'Performance',
            'unlockedAt': totalScore >= 10000 ? DateTime.now() : null,
          },
          {
            'id': 'total_50000',
            'name': 'Point Master',
            'description': 'Reach 50,000 total points',
            'icon': Icons.stars,
            'completed': totalScore >= 50000,
            'progress': totalScore > 50000 ? 50000 : totalScore,
            'target': 50000,
            'reward': 'Special Effects',
            'category': 'Performance',
            'unlockedAt': totalScore >= 50000 ? DateTime.now() : null,
          },
          {
            'id': 'multiplayer_win',
            'name': 'First Victory',
            'description': 'Win your first multiplayer match',
            'icon': Icons.people,
            'completed': multiplayerWins > 0,
            'progress': multiplayerWins > 0 ? 1 : 0,
            'target': 1,
            'reward': 'Multiplayer Badge',
            'category': 'Multiplayer',
            'unlockedAt': multiplayerWins > 0 ? DateTime.now() : null,
          },
          {
            'id': 'multiplayer_10',
            'name': 'Party Champion',
            'description': 'Win 10 multiplayer matches',
            'icon': Icons.emoji_events,
            'completed': multiplayerWins >= 10,
            'progress': multiplayerWins > 10 ? 10 : multiplayerWins,
            'target': 10,
            'reward': 'Victory Dance',
            'category': 'Multiplayer',
            'unlockedAt': multiplayerWins >= 10 ? DateTime.now() : null,
          },
          {
            'id': 'perfect_score',
            'name': 'Flawless Performance',
            'description': 'Get a perfect score on any song',
            'icon': Icons.grade,
            'completed': perfectScores > 0,
            'progress': perfectScores > 0 ? 1 : 0,
            'target': 1,
            'reward': 'Perfect Score Badge',
            'category': 'Performance',
            'unlockedAt': perfectScores > 0 ? DateTime.now() : null,
          },
          {
            'id': 'all_songs_easy',
            'name': 'Easy Master',
            'description': 'Complete all songs on Easy difficulty',
            'icon': Icons.check_circle,
            'completed': false, // This would need to be calculated based on actual game data
            'progress': 0,
            'target': 15, // Assuming 15 songs
            'reward': 'Easy Master Title',
            'category': 'Completion',
            'unlockedAt': null,
          },
          {
            'id': 'all_songs_medium',
            'name': 'Medium Master',
            'description': 'Complete all songs on Medium difficulty',
            'icon': Icons.check_circle_outline,
            'completed': false,
            'progress': 0,
            'target': 15,
            'reward': 'Medium Master Title',
            'category': 'Completion',
            'unlockedAt': null,
          },
          {
            'id': 'all_songs_hard',
            'name': 'Hard Master',
            'description': 'Complete all songs on Hard difficulty',
            'icon': Icons.check_circle_outlined,
            'completed': false,
            'progress': 0,
            'target': 15,
            'reward': 'Hard Master Title',
            'category': 'Completion',
            'unlockedAt': null,
          },
          {
            'id': 'daily_login_7',
            'name': 'Weekly Dancer',
            'description': 'Log in for 7 consecutive days',
            'icon': Icons.calendar_today,
            'completed': false,
            'progress': 3, // This would come from actual login tracking
            'target': 7,
            'reward': 'Login Streak Bonus',
            'category': 'General',
            'unlockedAt': null,
          },
          {
            'id': 'daily_login_30',
            'name': 'Monthly Dancer',
            'description': 'Log in for 30 consecutive days',
            'icon': Icons.calendar_view_month,
            'completed': false,
            'progress': 3,
            'target': 30,
            'reward': 'Exclusive Avatar',
            'category': 'General',
            'unlockedAt': null,
          },
          {
            'id': 'friend_invite',
            'name': 'Social Butterfly',
            'description': 'Invite a friend to play',
            'icon': Icons.person_add,
            'completed': false,
            'progress': 0,
            'target': 1,
            'reward': 'Friend Bonus',
            'category': 'Social',
            'unlockedAt': null,
          },
        ];
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load achievements: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Group achievements by category
  Map<String, List<Map<String, dynamic>>> _groupAchievementsByCategory() {
    Map<String, List<Map<String, dynamic>>> grouped = {};

    for (var achievement in _achievements) {
      String category = achievement['category'];
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(achievement);
    }

    return grouped;
  }

  // Calculate completion statistics
  Map<String, int> _calculateCompletionStats() {
    int total = _achievements.length;
    int completed = _achievements.where((a) => a['completed'] == true).length;
    int inProgress = _achievements.where((a) =>
    a['completed'] == false && a['progress'] > 0).length;
    int locked = _achievements.where((a) =>
    a['completed'] == false && a['progress'] == 0).length;

    return {
      'total': total,
      'completed': completed,
      'inProgress': inProgress,
      'locked': locked,
    };
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Map<String, int> stats = _calculateCompletionStats();
    Map<String, List<Map<String, dynamic>>> groupedAchievements = _groupAchievementsByCategory();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0523),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0523), Color(0xFF1D054A)],
          ),
        ),
        child: SafeArea(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MainMenuScreen(user: _currentUser),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'ACHIEVEMENTS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              onPressed: () {
                                _loadAchievements();
                              },
                              tooltip: 'Refresh',
                            ),
                          ],
                        ),
                      ),

                      // Stats Overview
                      _buildStatsOverview(stats),

                      // Tab Bar for Categories
                      DefaultTabController(
                        length: groupedAchievements.keys.length,
                        child: Expanded(
                          child: Column(
                            children: [
                              TabBar(
                                isScrollable: true,
                                indicatorColor: Colors.purpleAccent,
                                labelColor: Colors.white,
                                unselectedLabelColor: Colors.white70,
                                tabs: groupedAchievements.keys.map((category) {
                                  return Tab(text: category.toUpperCase());
                                }).toList(),
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: groupedAchievements.keys.map((category) {
                                    return _buildAchievementsList(groupedAchievements[category]!);
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                              "Loading achievements...",
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

  Widget _buildStatsOverview(Map<String, int> stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.withOpacity(0.5), Colors.blue.withOpacity(0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', stats['total']!.toString(), Icons.emoji_events),
          _buildStatItem('Completed', stats['completed']!.toString(), Icons.check_circle),
          _buildStatItem('In Progress', stats['inProgress']!.toString(), Icons.timelapse),
          _buildStatItem('Locked', stats['locked']!.toString(), Icons.lock),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.purpleAccent, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsList(List<Map<String, dynamic>> achievements) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        bool isCompleted = achievement['completed'];
        int progress = achievement['progress'];
        int target = achievement['target'];
        double progressPercent = progress / target;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.green.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted
                  ? Colors.greenAccent
                  : (progress > 0 ? Colors.blueAccent : Colors.grey),
              width: 1,
            ),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                achievement['icon'],
                color: isCompleted
                    ? Colors.greenAccent
                    : (progress > 0 ? Colors.blueAccent : Colors.grey),
              ),
            ),
            title: Text(
              achievement['name'],
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                decoration: isCompleted ? TextDecoration.underline : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement['description'],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                if (!isCompleted)
                  LinearProgressIndicator(
                    value: progressPercent,
                    backgroundColor: Colors.grey.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress > 0 ? Colors.blueAccent : Colors.grey,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  isCompleted
                      ? "Completed!"
                      : "$progress/$target (${(progressPercent * 100).toStringAsFixed(0)}%)",
                  style: TextStyle(
                    color: isCompleted
                        ? Colors.greenAccent
                        : Colors.white70,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Reward: ${achievement['reward']}",
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            trailing: isCompleted
                ? const Icon(Icons.check_circle, color: Colors.greenAccent)
                : const Icon(Icons.lock, color: Colors.grey),
          ),
        );
      },
    );
  }
}