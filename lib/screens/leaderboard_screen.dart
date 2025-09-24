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
  bool isLoading = true;
  String? errorMessage;
  late ScrollController _scrollController;

  // Cache for dancer titles to avoid recalculating
  final Map<int, String> _dancerTitleCache = {};

  String getDancerTitle(dynamic level) {
    final levelInt = getLevelAsInt(level);
    return _dancerTitleCache.putIfAbsent(levelInt, () {
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
    });
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
          leaderboardData = data;
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

  Widget _buildPlayerPodium(Map<String, dynamic> player, int rank, double height) {
    final isCurrentUser = _parseIsCurrentUser(player['is_current_user']);
    final playerLevel = player['level'] ?? 1;
    final levelInt = getLevelAsInt(playerLevel);
    final playerName = player['name']?.toString() ?? 'Player';
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
                    'Lvl $levelInt',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    getDancerTitle(playerLevel),
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

  Widget _buildSeasonEndBanner() {
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
              'Season ends in 245 days',
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
              'SEASON 1',
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

  Widget _buildPlayerListItem(Map<String, dynamic> player, int rank) {
    final isCurrentUser = _parseIsCurrentUser(player['is_current_user']);
    final playerLevel = player['level'] ?? 1;
    final levelInt = getLevelAsInt(playerLevel);
    final playerName = player['name'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // Added horizontal margin
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
                              'Level $levelInt',
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
                          getDancerTitle(playerLevel),
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

  void _navigateToProfile(Map<String, dynamic> player) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            PlayerProfileScreen(player: player),
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
                    _buildTopThreePlayers(),
                    if (leaderboardData.length > 3) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16), // Added horizontal margin
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
                SliverPadding( // Added SliverPadding for margin
                  padding: const EdgeInsets.symmetric(horizontal: 16), // Horizontal margin
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