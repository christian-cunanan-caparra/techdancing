import 'package:flutter/material.dart';
import 'package:techdancing/services/api_service.dart';

class AchievementsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const AchievementsScreen({super.key, required this.user});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late Map<String, dynamic> _currentUser;
  bool _isLoading = false;
  String _errorMessage = '';
  List<dynamic> _achievements = [];
  List<dynamic> _userAchievements = [];

  @override
  void initState() {
    super.initState();
    _currentUser = Map.from(widget.user);
    _loadAchievements();
  }

  // Safe parsing functions
  int _safeParseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is double) return value.toInt();
    return defaultValue;
  }

  String _safeParseString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print("Loading achievements for user: ${_currentUser['id']}");

      // First update achievements based on current user stats
      final updateResult = await ApiService.updateUserAchievements(
          _currentUser['id'].toString()
      );

      print("Update result: ${updateResult['status']}");
      if (updateResult['status'] == 'success') {
        print("Awarded achievements: ${updateResult['awarded_achievements']?.length ?? 0}");

        if (updateResult['awarded_achievements'] != null) {
          // Show notification for newly awarded achievements
          final awarded = updateResult['awarded_achievements'] as List;
          if (awarded.isNotEmpty) {
            _showNewAchievementsNotification(awarded);
          }
        }
      }

      // Then load all available achievements
      final achievementsResult = await ApiService.getAchievements();
      print("Achievements loaded: ${achievementsResult['achievements']?.length ?? 0}");

      // Load user's achievement progress
      final userAchievementsResult = await ApiService.getUserAchievements(
          _currentUser['id'].toString()
      );
      print("User achievements: ${userAchievementsResult['user_achievements']?.length ?? 0}");

      // Debug: Print all achievements and their status
      if (achievementsResult['status'] == 'success' && achievementsResult['achievements'] != null) {
        for (var achievement in achievementsResult['achievements']) {
          final progress = _getUserAchievementProgress(achievement);
          print("Achievement ${achievement['name']}: completed=${progress['completed']}, progress=${progress['progress']}");
        }
      }

      if (achievementsResult['status'] == 'success') {
        setState(() {
          _achievements = achievementsResult['achievements'] ?? [];
        });
      } else {
        setState(() {
          _errorMessage = achievementsResult['message'] ?? 'Failed to load achievements';
        });
      }

      if (userAchievementsResult['status'] == 'success') {
        setState(() {
          _userAchievements = userAchievementsResult['user_achievements'] ?? [];
        });

        // Debug: Print user achievements data
        print("User achievements raw data:");
        for (var ua in _userAchievements) {
          print("ID: ${ua['achievement_id']}, Completed: ${ua['completed']}, Type: ${ua['completed'].runtimeType}");
        }
      }
    } catch (e) {
      debugPrint('Error loading achievements: $e');
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showNewAchievementsNotification(List<dynamic> newAchievements) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Earned ${newAchievements.length} new achievement(s)!',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Scroll to top to show new achievements
            Scrollable.ensureVisible(context);
          },
        ),
      ),
    );
  }

  // Get user's progress for a specific achievement - FIXED VERSION
  Map<String, dynamic> _getUserAchievementProgress(Map<String, dynamic> achievement) {
    final int achievementId = _safeParseInt(achievement['id']);

    // First check if we have a record in user_achievements
    for (var userAchievement in _userAchievements) {
      if (_safeParseInt(userAchievement['achievement_id']) == achievementId) {
        // Return the actual database record
        return userAchievement;
      }
    }

    // If no record exists, check if user already meets the criteria
    final String category = _safeParseString(achievement['category']);
    final int targetValue = _safeParseInt(achievement['target_value']);

    int currentValue = 0;

    switch (category) {
      case 'level':
        currentValue = _safeParseInt(_currentUser['level'], defaultValue: 1);
        break;
      case 'games_played':
        currentValue = _safeParseInt(_currentUser['games_played']);
        break;
      case 'total_score':
        currentValue = _safeParseInt(_currentUser['total_score']);
        break;
      case 'high_score':
        currentValue = _safeParseInt(_currentUser['high_score']);
        break;
      default:
        currentValue = 0;
    }

    final bool isCompleted = currentValue >= targetValue;

    // Return virtual progress for achievements that should be completed but aren't in DB yet
    return {
      'progress': isCompleted ? targetValue : currentValue,
      'completed': isCompleted ? 1 : 0, // Use 1/0 instead of true/false
      'completed_at': isCompleted ? DateTime.now().toString() : null
    };
  }

  // Calculate progress percentage for an achievement - FIXED
  double _calculateProgressPercentage(Map<String, dynamic> achievement) {
    final Map<String, dynamic> userProgress = _getUserAchievementProgress(achievement);

    // Check for 1 instead of true
    if (userProgress['completed'] == 1) {
      return 100.0;
    }

    int targetValue = _safeParseInt(achievement['target_value']);
    int currentProgress = _safeParseInt(userProgress['progress']);

    // Otherwise calculate normal progress
    return (currentProgress / targetValue) * 100;
  }

  // Get appropriate icon for each achievement category
  IconData _getAchievementIcon(String category) {
    switch (category) {
      case 'level':
        return Icons.leaderboard;
      case 'games_played':
        return Icons.videogame_asset;
      case 'total_score':
        return Icons.star;
      case 'high_score':
        return Icons.emoji_events;
      default:
        return Icons.ac_unit_sharp;
    }
  }

  // Get appropriate color for each achievement category
  Color _getAchievementColor(String category) {
    switch (category) {
      case 'level':
        return Colors.purpleAccent;
      case 'games_played':
        return Colors.blueAccent;
      case 'total_score':
        return Colors.amberAccent;
      case 'high_score':
        return Colors.pinkAccent;
      default:
        return Colors.greenAccent;
    }
  }

  Widget _buildAchievementCard(Map<String, dynamic> achievement) {
    final int achievementId = _safeParseInt(achievement['id']);
    final String name = _safeParseString(achievement['name']);
    final String description = _safeParseString(achievement['description']);
    final String category = _safeParseString(achievement['category']);
    final int targetValue = _safeParseInt(achievement['target_value']);
    final int xpReward = _safeParseInt(achievement['xp_reward']);

    final Map<String, dynamic> userProgress = _getUserAchievementProgress(achievement);
    final bool isCompleted = userProgress['completed'] == 1; // Check for 1 instead of true
    final double progressPercentage = _calculateProgressPercentage(achievement);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getAchievementColor(category).withOpacity(isCompleted ? 0.7 : 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getAchievementColor(category).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getAchievementIcon(category),
                  color: _getAchievementColor(category),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    decoration: isCompleted ? TextDecoration.underline : null,
                  ),
                ),
              ),
              if (isCompleted)
                const Icon(
                  Icons.verified,
                  color: Colors.greenAccent,
                  size: 24,
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 16),

          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${progressPercentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
                      width: (MediaQuery.of(context).size.width - 64) * (progressPercentage / 100),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getAchievementColor(category),
                            _getAchievementColor(category).withOpacity(0.7),
                          ],
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getProgressText(category, targetValue),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'Target: $targetValue',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Reward section
          // Container(
          //   padding: const EdgeInsets.all(8),
          //   decoration: BoxDecoration(
          //     color: Colors.black.withOpacity(0.2),
          //     borderRadius: BorderRadius.circular(8),
          //   ),
          //   child: Row(
          //     children: [
          //       const Icon(
          //         Icons.bolt,
          //         color: Colors.amberAccent,
          //         size: 16,
          //       ),
          //       const SizedBox(width: 4),
          //       Text(
          //         '+$xpReward XP Reward',
          //         style: const TextStyle(
          //           color: Colors.amberAccent,
          //           fontSize: 14,
          //           fontWeight: FontWeight.bold,
          //         ),
          //       ),
          //       const Spacer(),
          //       if (isCompleted)
          //         Text(
          //           'Completed on ${_formatDate(userProgress['completed_at'])}',
          //           style: TextStyle(
          //             color: Colors.greenAccent,
          //             fontSize: 12,
          //           ),
          //         ),
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }

  String _getProgressText(String category, int targetValue) {
    int currentValue = 0;

    switch (category) {
      case 'level':
        currentValue = _safeParseInt(_currentUser['level'], defaultValue: 1);
        break;
      case 'games_played':
        currentValue = _safeParseInt(_currentUser['games_played']);
        break;
      case 'total_score':
        currentValue = _safeParseInt(_currentUser['total_score']);
        break;
      case 'high_score':
        currentValue = _safeParseInt(_currentUser['high_score']);
        break;
      default:
        currentValue = 0;
    }

    return '$currentValue/$targetValue';
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown date';

    try {
      final DateTime dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildCategorySection(String categoryName, List<dynamic> achievements) {
    final categoryAchievements = achievements.where((a) =>
    _safeParseString(a['category']) == categoryName).toList();

    if (categoryAchievements.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getCategoryDisplayName(categoryName),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...categoryAchievements.map((achievement) =>
            _buildAchievementCard(achievement)
        ).toList(),
        const SizedBox(height: 24),
      ],
    );
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'level':
        return 'Level Achievements';
      case 'games_played':
        return 'Gameplay Achievements';
      case 'total_score':
        return 'Scoring Achievements';
      case 'high_score':
        return 'High Score Achievements';
      default:
        return 'Other Achievements';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group achievements by category
    final categories = ['level', 'games_played', 'total_score', 'high_score'];

    return Scaffold(
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
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
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
                          onPressed: _loadAchievements,
                          tooltip: 'Refresh Achievements',
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

                    const SizedBox(height: 16),

                    // Progress summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.purpleAccent.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            'Total',
                            _achievements.length.toString(),
                            Icons.dashboard_customize,
                          ),
                          _buildSummaryItem(
                            'Completed',
                            _userAchievements.where((a) => a['completed'] == 1).length.toString(),
                            Icons.verified,
                          ),
                          _buildSummaryItem(
                            'In Progress',
                            _userAchievements.where((a) => a['completed'] != 1).length.toString(),
                            Icons.timelapse,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Achievements list
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...categories.map((category) =>
                                _buildCategorySection(category, _achievements)
                            ).toList(),

                            // Show any achievements that don't fit the main categories
                            if (_achievements.any((a) => !categories.contains(a['category'])))
                              _buildCategorySection('other', _achievements),
                          ],
                        ),
                      ),
                    ),
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
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon) {
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
}