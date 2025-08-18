import 'package:flutter/material.dart';
import '../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final data = await ApiService.getLeaderboard(widget.userId);
      setState(() {
        leaderboardData = data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString().replaceAll('Exception: ', '');
        isLoading = false;
      });
      debugPrint('Leaderboard error: $e');
    }
  }

  Widget _buildMedalIcon(int rank) {
    const medalSize = 36.0;

    if (rank == 1) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.star, color: Colors.amber, size: medalSize),
          Text('1', style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12
          )),
        ],
      );
    } else if (rank == 2) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.star, color: Colors.grey[400], size: medalSize),
          Text('2', style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12
          )),
        ],
      );
    } else if (rank == 3) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.star, color: Colors.orange[800], size: medalSize),
          Text('3', style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12
          )),
        ],
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.purple[700],
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTopThreePlayers() {
    if (leaderboardData.length < 3) return const SizedBox();

    return Column(
      children: [
        // 2nd place
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPlayerPodium(leaderboardData[1], 2, 90),
            const SizedBox(width: 8),
            // 1st place
            _buildPlayerPodium(leaderboardData[0], 1, 120),
            const SizedBox(width: 8),
            // 3rd place
            _buildPlayerPodium(leaderboardData[2], 3, 80),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPlayerPodium(Map<String, dynamic> player, int rank, double height) {
    final isCurrentUser = player['is_current_user'] ?? false;
    Color podiumColor;

    switch(rank) {
      case 1: podiumColor = Colors.amber; break;
      case 2: podiumColor = Colors.grey[400]!; break;
      case 3: podiumColor = Colors.orange[800]!; break;
      default: podiumColor = Colors.purple[400]!;
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: isCurrentUser ? Colors.yellow : Colors.purple[300],
          child: Text(
            player['name']?.toString().substring(0, 1).toUpperCase() ?? '?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isCurrentUser ? Colors.black : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                podiumColor.withOpacity(0.8),
                podiumColor.withOpacity(0.4),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                player['name']?.toString().split(' ')[0] ?? 'Player',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Lvl ${player['level'] ?? '1'}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: podiumColor.withOpacity(0.9),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Text(
            '#$rank',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSeasonEndBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.5), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer, color: Colors.yellow[200], size: 18),
          const SizedBox(width: 8),
          Text(
            'Season ends in 245 days',
            style: TextStyle(
              color: Colors.yellow[200],
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LEADERBOARD',
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
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0523), Color(0xFF1D054A)],
          ),
        ),
        child: isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        )
            : errorMessage != null
            ? Center(
          child: Text(
            errorMessage!,
            style: const TextStyle(color: Colors.white),
          ),
        )
            : Column(
          children: [
            const SizedBox(height: 8),
            _buildSeasonEndBanner(),
            const SizedBox(height: 8),
            _buildTopThreePlayers(),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: leaderboardData.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index < 3) return const SizedBox(); // Skip top 3 as they're shown in podium

                  final player = leaderboardData[index];
                  final rank = index + 1;
                  final isCurrentUser = player['is_current_user'] ?? false;

                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.withOpacity(0.5),
                          Colors.blue.withOpacity(0.3),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrentUser
                            ? Colors.yellow.withOpacity(0.5)
                            : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: _buildMedalIcon(rank),
                      title: Text(
                        player['name'] ?? 'Unknown',
                        style: TextStyle(
                          color: isCurrentUser ? Colors.yellow : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Icon(Icons.star, color: Colors.yellow[600], size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Level ${player['level'] ?? '1'}',
                            style: TextStyle(
                              color: isCurrentUser ? Colors.yellow[200] : Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCurrentUser
                                  ? Colors.yellow.withOpacity(0.2)
                                  : Colors.purple.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '#$rank',
                              style: TextStyle(
                                color: isCurrentUser ? Colors.yellow : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}