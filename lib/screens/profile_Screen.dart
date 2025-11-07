import 'package:flutter/material.dart';
import 'package:techdancing/screens/main_menu_screen.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Map<String, dynamic> _currentUser;
  bool _isLoading = false;
  String _errorMessage = '';
  int _userRank = 0;
  List<dynamic> _rankingData = [];
  Map<String, dynamic> _seasonInfo = {};
  Map<String, dynamic>? _previousSeasonRecord;

  @override
  void initState() {
    super.initState();
    _currentUser = Map.from(widget.user);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await Future.wait([
        _loadUserStats(),
        _loadRankingData(), // This now loads previous season data from leaderboard API
      ]);
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _errorMessage = 'Failed to load profile data';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPreviousSeasonData() async {
    try {
      debugPrint('Loading previous season for user: ${_currentUser['id']}');
      final previousSeasonData = await ApiService.getUserPreviousSeason(_currentUser['id'].toString());
      debugPrint('Previous season API full response: $previousSeasonData');

      if (previousSeasonData['status'] == 'success' && previousSeasonData['previous_season'] != null) {
        setState(() {
          _previousSeasonRecord = _convertToStringKeyMap(previousSeasonData['previous_season']);
        });
        debugPrint('Previous season record successfully set: $_previousSeasonRecord');
      } else {
        debugPrint('No previous season data found in API response');
        debugPrint('Status: ${previousSeasonData['status']}');
        debugPrint('Message: ${previousSeasonData['message']}');
        debugPrint('Previous season data: ${previousSeasonData['previous_season']}');
        setState(() {
          _previousSeasonRecord = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading previous season data: $e');
      setState(() {
        _previousSeasonRecord = null;
      });
    }
  }

  Map<String, dynamic> _convertToStringKeyMap(dynamic map) {
    if (map is! Map) return {};

    final Map<String, dynamic> result = {};
    try {
      map.forEach((key, value) {
        result[key.toString()] = value;
      });
    } catch (e) {
      debugPrint('Error converting map: $e');
    }
    return result;
  }

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

  bool _isCurrentUser(dynamic userData) {
    if (userData == null) return false;

    final userId = _safeParseInt(userData['id'] ?? userData['user_id'] ?? userData['userId']);
    return userId == _safeParseInt(_currentUser['id']);
  }

  Future<void> _loadUserStats() async {
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
            'rank_title': _safeParseString(userData['rank_title'], defaultValue: 'Beginner Dancer'),
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
    }
  }

  Future<void> _loadRankingData() async {
    try {
      final data = await ApiService.getLeaderboard(_currentUser['id'].toString());

      // Extract data from response - FIXED: Use the same structure as LeaderboardScreen
      final leaderboardData = data['leaderboard'] ?? [];
      final seasonInfo = data['season_info'] ?? {};
      final previousSeasonRecord = data['previous_season'];

      debugPrint('=== DEBUG: Leaderboard API Response ===');
      debugPrint('Leaderboard data length: ${leaderboardData.length}');
      debugPrint('Season info: $seasonInfo');
      debugPrint('Previous season record: $previousSeasonRecord');

      int userRank = 0;
      for (int i = 0; i < leaderboardData.length; i++) {
        if (_isCurrentUser(leaderboardData[i])) {
          userRank = i + 1;
          break;
        }
      }

      // FIXED: Properly handle previous season record from leaderboard API
      if (previousSeasonRecord != null && previousSeasonRecord is Map) {
        setState(() {
          _previousSeasonRecord = _convertToStringKeyMap(previousSeasonRecord);
        });
        debugPrint('=== DEBUG: Previous season loaded successfully ===');
        debugPrint('Previous season data: $_previousSeasonRecord');
      } else {
        debugPrint('=== DEBUG: No previous season record found in API response ===');
        setState(() {
          _previousSeasonRecord = null;
        });
      }

      setState(() {
        _rankingData = leaderboardData;
        _userRank = userRank;
        _seasonInfo = _convertToStringKeyMap(seasonInfo);
      });
    } catch (e) {
      debugPrint('Error loading ranking data: $e');
      setState(() {
        _userRank = 0;
        _rankingData = [];
        _seasonInfo = {};
        _previousSeasonRecord = null;
      });
    }
  }

  Widget _buildSeasonInfoCard() {
    final seasonNumber = _seasonInfo['season_number'] ?? 1;
    final seasonName = _seasonInfo['season_name'] ?? 'Season 1';
    final daysUntilEnd = _seasonInfo['days_until_end'] ?? 245;
    final isActive = _seasonInfo['is_active'] ?? true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.4),
            Colors.blue.withOpacity(0.4),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purpleAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                seasonName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isActive ? 'ACTIVE' : 'ENDED',
                  style: TextStyle(
                    color: isActive ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Season $seasonNumber • Ends in $daysUntilEnd days',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousSeasonCard() {
    // Debug current state
    debugPrint('=== DEBUG: Building previous season card ===');
    debugPrint('_previousSeasonRecord: $_previousSeasonRecord');

    if (_previousSeasonRecord == null || _previousSeasonRecord!.isEmpty) {
      debugPrint('No previous season record to display - showing empty state');
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey.withOpacity(0.2),
              Colors.grey.withOpacity(0.1),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.history, color: Colors.grey[400], size: 32),
            const SizedBox(height: 8),
            Text(
              'No Previous Season Data',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete a season to see your past performance',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Extract data using EXACT field names from your database
    final previousLevel = _safeParseInt(_previousSeasonRecord?['final_level']);
    final previousRank = _safeParseInt(_previousSeasonRecord?['final_rank']);
    final previousRankTitle = _safeParseString(_previousSeasonRecord?['rank_title'], defaultValue: 'Beginner Dancer');
    final seasonName = _safeParseString(_previousSeasonRecord?['season_name'], defaultValue: 'Previous Season');
    final seasonNumber = _safeParseString(_previousSeasonRecord?['season_number'] ?? '?');
    final totalScore = _safeParseInt(_previousSeasonRecord?['final_total_score']);
    final gamesPlayed = _safeParseInt(_previousSeasonRecord?['games_played']);
    final finalXp = _safeParseInt(_previousSeasonRecord?['final_xp']);

    debugPrint('=== DEBUG: Displaying previous season ===');
    debugPrint('Season: $seasonName (Number: $seasonNumber)');
    debugPrint('Level: $previousLevel, Rank: $previousRank, Title: $previousRankTitle');
    debugPrint('Total Score: $totalScore, Games Played: $gamesPlayed, XP: $finalXp');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.4),
            Colors.blue.withOpacity(0.4),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.6), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with season info
          Row(
            children: [
              Icon(Icons.history, color: Colors.yellow[200], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Previous Season: $seasonName',
                  style: TextStyle(
                    color: Colors.yellow[200],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main achievement info
          Text(
            'You reached $previousRankTitle - Level $previousLevel',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 8),

          // Rank info
          if (previousRank > 0)
            Text(
              'Rank: #$previousRank',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),

          const SizedBox(height: 12),

          // Additional stats in a row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildPreviousStatItem('Total Score', totalScore.toString(), Icons.star),
              _buildPreviousStatItem('Games', gamesPlayed.toString(), Icons.videogame_asset),
              _buildPreviousStatItem('XP', finalXp.toString(), Icons.bolt),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // ... (Keep all your existing _buildRankingCard, _buildProfileCard, _buildStatisticsCard, etc. methods exactly as they were)

  Widget _buildRankingCard() {
    final displayRank = _userRank > 0 ? '#$_userRank' : 'Unranked';
    final totalPlayers = _rankingData.isNotEmpty ? _rankingData.length.toString() : '0';
    final topPercent = _userRank > 0 ? _calculateTopPercent().toStringAsFixed(1) + '%' : '0%';
    final currentRankTitle = _safeParseString(_currentUser['rank_title'], defaultValue: 'Beginner Dancer');

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CURRENT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentRankTitle.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.purpleAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
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

  Widget _buildProfileCard(String name, String email, String joinDate, int level, int xp, int xpRequired, double progress, String rankTitle) {
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

                // Dancer Title (from database)
                Text(
                  rankTitle,
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
    String rankTitle = _safeParseString(_currentUser['rank_title'], defaultValue: 'Beginner Dancer');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PROFILE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0F0523),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF0F0523), Color(0xFF1D054A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadUserData,
            tooltip: 'Refresh Stats',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0523), Color(0xFF1D054A)],
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                  // Season Information
                  _buildSeasonInfoCard(),

                  // Previous Season Performance - NOW FIXED
                  _buildPreviousSeasonCard(),

                  // User Profile Card
                  _buildProfileCard(name, email, joinDate, level, xp, xpRequired, progress, rankTitle),

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
    );
  }
}