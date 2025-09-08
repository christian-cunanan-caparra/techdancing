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

  Future<void> _loadAchievements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      print('Loading achievements for user: ${_currentUser['id']}');

      // Fetch achievements from API
      final response = await ApiService.getUserAchievements(_currentUser['id'].toString());

      print('API Response: $response');

      if (response['status'] == 'success') {
        setState(() {
          _achievements = List<Map<String, dynamic>>.from(response['achievements'] ?? []);
        });
        print('Loaded ${_achievements.length} achievements');
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load achievements';
        });
        print('Error: $_errorMessage');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load achievements: ${e.toString()}';
      });
      print('Exception: $_errorMessage');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  Future<void> _unlockAchievement(String achievementId) async {
    try {
      final response = await ApiService.unlockAchievement(
          _currentUser['id'].toString(),
          achievementId
      );

      if (response['status'] == 'success') {
        // Refresh achievements
        _loadAchievements();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Achievement unlocked! +${response['xp_gained']} XP'),
              backgroundColor: Colors.green,
            )
        );

        // Show level up notification if applicable
        if (response['leveled_up'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎉 Level Up! You\'re now level ${response['new_level']}!'),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 3),
              )
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to unlock achievement'),
              backgroundColor: Colors.red,
            )
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          )
      );
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
                _getIconFromString(achievement['icon']),
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
            onTap: () {
              if (!isCompleted && progress >= target) {
                _unlockAchievement(achievement['id'].toString());
              }
            },
          ),
        );
      },
    );
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'star': return Icons.star;
      case 'trophy': return Icons.emoji_events;
      case 'celebration': return Icons.celebration;
      case 'grade': return Icons.grade;
      case 'check_circle': return Icons.check_circle;
      case 'local_activity': return Icons.local_activity;
      case 'military_tech': return Icons.military_tech;
      case 'trending_up': return Icons.trending_up;
      case 'leaderboard': return Icons.leaderboard;
      case 'people': return Icons.people;
      case 'calendar_today': return Icons.calendar_today;
      case 'calendar_view_month': return Icons.calendar_view_month;
      case 'person_add': return Icons.person_add;
      default: return Icons.star_border;
    }
  }
}