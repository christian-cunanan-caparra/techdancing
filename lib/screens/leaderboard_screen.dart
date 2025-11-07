import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'player_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  final String userId;

  const LeaderboardScreen({super.key, required this.userId});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<dynamic> leaderboardData = [];
  Map<String, dynamic> seasonInfo = {};
  Map<String, dynamic>? previousSeasonRecord;
  bool isLoading = true;
  String? errorMessage;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _fetchLeaderboard();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final data = await ApiService.getLeaderboard(widget.userId);
      if (mounted) {
        setState(() {
          // Safe data extraction with type checking
          final dynamic leaderboardDataRaw = data['leaderboard'];
          final dynamic seasonInfoRaw = data['season_info'];
          final dynamic previousSeasonRecordRaw = data['previous_season'];

          // Ensure leaderboardData is a List
          if (leaderboardDataRaw is List) {
            leaderboardData = leaderboardDataRaw;
          } else {
            leaderboardData = [];
          }

          // Ensure seasonInfo is a Map<String, dynamic>
          if (seasonInfoRaw is Map) {
            try {
              seasonInfo = seasonInfoRaw.cast<String, dynamic>();
            } catch (e) {
              seasonInfo = {};
            }
          } else {
            seasonInfo = {};
          }

          // Handle previousSeasonRecord (can be null)
          if (previousSeasonRecordRaw is Map) {
            try {
              previousSeasonRecord = previousSeasonRecordRaw.cast<String, dynamic>();
            } catch (e) {
              previousSeasonRecord = null;
            }
          } else {
            previousSeasonRecord = null;
          }

          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString().replaceAll('Exception: ', '');
          isLoading = false;
        });
      }
      debugPrint('Leaderboard error: $e');
    }
  }

  int getLevelAsInt(dynamic level) {
    if (level is String) {
      return int.tryParse(level) ?? 1;
    } else if (level is int) {
      return level;
    }
    return 1;
  }

  bool _parseIsCurrentUser(dynamic isCurrentUserValue) {
    if (isCurrentUserValue == null) return false;
    if (isCurrentUserValue is bool) return isCurrentUserValue;
    if (isCurrentUserValue is int) return isCurrentUserValue == 1;
    if (isCurrentUserValue is String) {
      return isCurrentUserValue == '1' || isCurrentUserValue.toLowerCase() == 'true';
    }
    return false;
  }

  // Safe data extraction methods
  String _safeParseString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    if (value is String) return value;
    return value.toString();
  }

  int _safeParseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is double) return value.toInt();
    return defaultValue;
  }

  // Safe player data extraction
  Map<String, dynamic> _getSafePlayerData(dynamic player) {
    if (player is! Map) {
      return {
        'name': 'Unknown Player',
        'level': 1,
        'rank_title': 'Beginner Dancer',
        'is_current_user': false,
      };
    }

    try {
      return {
        'name': _safeParseString(player['name'], defaultValue: 'Unknown Player'),
        'level': _safeParseInt(player['level'], defaultValue: 1),
        'rank_title': _safeParseString(player['rank_title'], defaultValue: 'Beginner Dancer'),
        'is_current_user': _parseIsCurrentUser(player['is_current_user']),
      };
    } catch (e) {
      return {
        'name': 'Unknown Player',
        'level': 1,
        'rank_title': 'Beginner Dancer',
        'is_current_user': false,
      };
    }
  }

  // Convert Map<dynamic, dynamic> to Map<String, dynamic>
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

  Widget _buildMedalIcon(int rank) {
    const medalSize = 40.0;

    switch (rank) {
      case 1:
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.emoji_events_rounded, color: Colors.amber, size: medalSize),
            Text('1',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  shadows: [
                    Shadow(blurRadius: 2, color: Colors.black.withOpacity(0.5))
                  ],
                )),
          ],
        );
      case 2:
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.emoji_events_rounded, color: Colors.grey[400], size: medalSize),
            Text('2',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  shadows: [
                    Shadow(blurRadius: 2, color: Colors.black.withOpacity(0.5))
                  ],
                )),
          ],
        );
      case 3:
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.emoji_events_rounded, color: Colors.orange[800], size: medalSize),
            Text('3',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  shadows: [
                    Shadow(blurRadius: 2, color: Colors.black.withOpacity(0.5))
                  ],
                )),
          ],
        );
      default:
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple[700]!,
                Colors.purple[900]!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$rank',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
    }
  }

  Widget _buildTopThreePlayers() {
    if (leaderboardData.length < 3) return const SizedBox();

    return Column(
      children: [
        const SizedBox(height: 16),
        Text(
          'TOP DANCERS',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildPlayerPodium(leaderboardData[1], 2, 100),
            _buildPlayerPodium(leaderboardData[0], 1, 140),
            _buildPlayerPodium(leaderboardData[2], 3, 90),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPlayerPodium(dynamic player, int rank, double height) {
    final safePlayer = _getSafePlayerData(player);
    final isCurrentUser = safePlayer['is_current_user'] as bool;
    final playerLevel = safePlayer['level'] as int;
    final playerName = safePlayer['name'] as String;
    final rankTitle = safePlayer['rank_title'] as String;
    final firstName = playerName.split(' ')[0];

    Color podiumColor;
    switch(rank) {
      case 1: podiumColor = Colors.amber; break;
      case 2: podiumColor = Colors.grey[400]!; break;
      case 3: podiumColor = Colors.orange[800]!; break;
      default: podiumColor = Colors.purple[400]!;
    }

    return GestureDetector(
      onTap: () => _navigateToProfile(player),
      child: Column(
        children: [
          // Rank indicator above avatar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: podiumColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Player avatar with highlight
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isCurrentUser ? Colors.yellow : podiumColor,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: podiumColor.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: podiumColor.withOpacity(0.2),
              child: Text(
                playerName.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Podium stand
          Container(
            width: 90,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  podiumColor.withOpacity(0.9),
                  podiumColor.withOpacity(0.6),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: podiumColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    firstName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lvl $playerLevel',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rankTitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousSeasonBadge() {
    if (previousSeasonRecord == null) return const SizedBox();

    final previousLevel = _safeParseInt(previousSeasonRecord?['final_level']);
    final previousRank = _safeParseInt(previousSeasonRecord?['final_rank']);
    final previousRankTitle = _safeParseString(previousSeasonRecord?['rank_title'], defaultValue: 'Unknown');
    final seasonName = _safeParseString(previousSeasonRecord?['season_name'], defaultValue: 'Previous Season');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          Row(
            children: [
              Icon(Icons.history, color: Colors.yellow[200], size: 16),
              const SizedBox(width: 8),
              Text(
                'Previous Season $seasonName',
                style: TextStyle(
                  color: Colors.yellow[200],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You reached $previousRankTitle - Level $previousLevel',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
          if (previousRank > 0)
            Text(
              'Rank: #$previousRank',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeasonEndBanner() {
    final daysUntilEnd = _safeParseInt(seasonInfo['days_until_end'], defaultValue: 245);
    final seasonNumber = _safeParseInt(seasonInfo['season_number'], defaultValue: 1);
    final seasonName = _safeParseString(seasonInfo['season_name'], defaultValue: 'Season 1');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.4),
            Colors.orange.withOpacity(0.4),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer, color: Colors.yellow[200], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Season ends in $daysUntilEnd days',
              style: TextStyle(
                color: Colors.yellow[200],
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              seasonName.toUpperCase(),
              style: TextStyle(
                color: Colors.yellow[200],
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerListItem(dynamic player, int rank) {
    final safePlayer = _getSafePlayerData(player);
    final isCurrentUser = safePlayer['is_current_user'] as bool;
    final playerLevel = safePlayer['level'] as int;
    final playerName = safePlayer['name'] as String;
    final rankTitle = safePlayer['rank_title'] as String;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isCurrentUser
                ? [
              Colors.yellow.withOpacity(0.1),
              Colors.orange.withOpacity(0.05),
            ]
                : [
              Colors.purple.withOpacity(0.3),
              Colors.blue.withOpacity(0.1),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrentUser
                ? Colors.yellow.withOpacity(0.6)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToProfile(player),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  _buildMedalIcon(rank),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playerName,
                          style: TextStyle(
                            color: isCurrentUser ? Colors.yellow : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.yellow[600], size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Level $playerLevel',
                              style: TextStyle(
                                color: isCurrentUser
                                    ? Colors.yellow[200]
                                    : Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          rankTitle,
                          style: TextStyle(
                            color: isCurrentUser
                                ? Colors.yellow[200]
                                : Colors.white60,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCurrentUser
                            ? [Colors.yellow, Colors.orange]
                            : [Colors.purple, Colors.deepPurple],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        color: isCurrentUser ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
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

  void _navigateToProfile(dynamic player) {
    if (player is! Map) return;

    final Map<String, dynamic> safePlayer = _convertToStringKeyMap(player);

    // Ensure we have basic player data
    if (!safePlayer.containsKey('id') && !safePlayer.containsKey('user_id')) {
      // Try to extract from existing data
      if (safePlayer.containsKey('name')) {
        safePlayer['id'] = safePlayer['user_id'] = _extractPlayerId(safePlayer);
      }
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PlayerProfileScreen(player: safePlayer),
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
  }

  String _extractPlayerId(Map<String, dynamic> player) {
    final possibleKeys = ['id', 'user_id', 'userId', 'userID'];
    for (var key in possibleKeys) {
      if (player.containsKey(key) && player[key] != null) {
        return player[key].toString();
      }
    }
    return '';
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[300]!),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading Leaderboard...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red[300], size: 64),
          const SizedBox(height: 16),
          Text(
            'Failed to load leaderboard',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorMessage ?? 'Unknown error occurred',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchLeaderboard,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.leaderboard_outlined, color: Colors.purple[300], size: 64),
          const SizedBox(height: 16),
          Text(
            'No Players Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to join the leaderboard!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0523),
      appBar: AppBar(
        title: const Text(
          'DANCE LEADERBOARD',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F0523), Color(0xFF1D054A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0523), Color(0xFF2D0F6B)],
          ),
        ),
        child: isLoading
            ? _buildLoadingScreen()
            : errorMessage != null
            ? _buildErrorScreen()
            : leaderboardData.isEmpty
            ? _buildEmptyState()
            : RefreshIndicator(
          backgroundColor: Colors.purple,
          color: Colors.white,
          onRefresh: _fetchLeaderboard,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildSeasonEndBanner(),
                    if (previousSeasonRecord != null) _buildPreviousSeasonBadge(),
                    _buildTopThreePlayers(),
                    if (leaderboardData.length > 3) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OTHER DANCERS',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
              if (leaderboardData.length > 3)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final actualIndex = index + 3;
                        if (actualIndex >= leaderboardData.length) return null;
                        return _buildPlayerListItem(
                          leaderboardData[actualIndex],
                          actualIndex + 1,
                        );
                      },
                      childCount: leaderboardData.length - 3,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }
}