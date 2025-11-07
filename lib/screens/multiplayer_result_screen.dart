import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MultiplayerResultScreen extends StatefulWidget {
  final String roomCode;
  final String userId;
  final int playerScore;
  final int totalScore;
  final int percentage;
  final int xpGained;
  final List<int> stepScores;
  final List<Map<String, dynamic>> danceSteps;
  final String playerName;

  const MultiplayerResultScreen({
    super.key,
    required this.roomCode,
    required this.userId,
    required this.playerScore,
    required this.totalScore,
    required this.percentage,
    required this.xpGained,
    required this.stepScores,
    required this.danceSteps,
    required this.playerName,
  });

  @override
  State<MultiplayerResultScreen> createState() => _MultiplayerResultScreenState();
}

class _MultiplayerResultScreenState extends State<MultiplayerResultScreen> {
  Map<String, dynamic>? _results;
  bool _isLoading = true;
  bool _waitingForOpponent = true;
  String _statusMessage = "Waiting for opponent to finish...";
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _submitScoreAndWait();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _submitScoreAndWait() async {
    try {
      // First submit the current player's score
      final submitResult = await ApiService.submitMultiplayerGameScore(
        widget.roomCode,
        widget.userId,
        widget.playerScore,
        widget.totalScore,
        widget.percentage,
        widget.xpGained,
        widget.stepScores,
        widget.danceSteps,
      );

      if (submitResult['status'] != 'success') {
        setState(() {
          _isLoading = false;
          _statusMessage = "Failed to submit score";
        });
        return;
      }

      // Start polling for opponent's score
      _startPollingForResults();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error submitting score";
      });
    }
  }

  void _startPollingForResults() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final results = await ApiService.getMultiplayerResults(
        widget.roomCode,
        widget.userId,
      );

      if (results['status'] == 'success') {
        final bothSubmitted = results['both_players_submitted'] ?? false;

        if (bothSubmitted) {
          timer.cancel();
          setState(() {
            _results = results;
            _isLoading = false;
            _waitingForOpponent = false;
          });
        } else {
          setState(() {
            _statusMessage = "Still waiting for opponent...";
          });
        }
      } else {
        setState(() {
          _statusMessage = "Error fetching results";
          _isLoading = false;
        });
        timer.cancel();
      }
    });

    // Timeout after 30 seconds
    Timer(const Duration(seconds: 30), () {
      if (_waitingForOpponent) {
        _pollingTimer?.cancel();
        setState(() {
          _isLoading = false;
          _waitingForOpponent = false;
          _statusMessage = "Opponent took too long to finish";
        });
      }
    });
  }

  Widget _buildWaitingScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
        ),
        const SizedBox(height: 20),
        Text(
          _statusMessage,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        const Text(
          "Please wait while your opponent finishes...",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildResultScreen() {
    if (_results == null) {
      return _buildErrorScreen();
    }

    final player1 = _results!['player1'];
    final player2 = _results!['player2'];
    final winnerId = _results!['winner_id'];
    final isDraw = _results!['is_draw'] ?? false;

    final isPlayer1 = player1['id'].toString() == widget.userId;
    final currentPlayer = isPlayer1 ? player1 : player2;
    final opponent = isPlayer1 ? player2 : player1;
    final currentPlayerWon = winnerId != null && winnerId.toString() == widget.userId;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D0B1E), Color(0xFF1A093B), Color(0xFF2D0A5C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Result header
              Text(
                isDraw ? "IT'S A DRAW! 🤝" :
                currentPlayerWon ? "VICTORY! 🏆" : "DEFEAT! 💔",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDraw ? Colors.amber :
                  currentPlayerWon ? Colors.green : Colors.red,
                  shadows: const [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              if (isDraw)
                const Text(
                  "Both players scored the same!",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),

              const SizedBox(height: 30),

              // Scores comparison
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPlayerScoreCard(
                    currentPlayer['name'],
                    currentPlayer['score'],
                    true, // isCurrentPlayer
                    currentPlayerWon && !isDraw,
                    currentPlayer['percentage'],
                    currentPlayer['xp_gained'],
                  ),
                  const Column(
                    children: [
                      Text(
                        "VS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Icon(
                        Icons.sports_esports,
                        color: Colors.purpleAccent,
                        size: 30,
                      ),
                    ],
                  ),
                  _buildPlayerScoreCard(
                    opponent['name'],
                    opponent['score'],
                    false, // isCurrentPlayer
                    !currentPlayerWon && !isDraw && winnerId != null,
                    opponent['percentage'],
                    opponent['xp_gained'],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Score details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    if (!isDraw && winnerId != null)
                      Text(
                        "Score Difference: ${(currentPlayer['score'] - opponent['score']).abs()}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              "Your Accuracy",
                              style: TextStyle(color: Colors.white70),
                            ),
                            Text(
                              "${currentPlayer['percentage']}%",
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              "Your XP",
                              style: TextStyle(color: Colors.white70),
                            ),
                            Text(
                              "+${currentPlayer['xp_gained']}",
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Step scores list
              if (widget.stepScores.isNotEmpty)
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        "Your Step Scores:",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView.builder(
                          itemCount: widget.stepScores.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: Text(
                                "${index + 1}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              title: Text(
                                widget.danceSteps[index]['name'] ?? 'Step ${index + 1}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: Text(
                                "${widget.stepScores[index]} pts",
                                style: TextStyle(
                                  color: _getStepScoreColor(widget.stepScores[index]),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "Main Menu",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _requestRematch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "Rematch",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerScoreCard(String name, int score, bool isCurrentPlayer, bool isWinner, int percentage, int xpGained) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isWinner
                  ? [Colors.green.withOpacity(0.3), Colors.green.withOpacity(0.1)]
                  : isCurrentPlayer
                  ? [Colors.blue.withOpacity(0.3), Colors.blue.withOpacity(0.1)]
                  : [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isWinner ? Colors.green :
              isCurrentPlayer ? Colors.blueAccent : Colors.grey,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: isWinner ? Colors.green.withOpacity(0.5) :
                isCurrentPlayer ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                isCurrentPlayer ? "YOU" : name.toUpperCase(),
                style: TextStyle(
                  color: isCurrentPlayer ? Colors.cyanAccent : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "$score",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "$percentage%",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Text(
                "+$xpGained XP",
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                ),
              ),
              if (isWinner)
                const Icon(
                  Icons.emoji_events,
                  color: Colors.amber,
                  size: 30,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStepScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 70) return Colors.blue;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildErrorScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 50,
        ),
        const SizedBox(height: 20),
        Text(
          _statusMessage,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          child: const Text(
            "Go Back",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _requestRematch() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A093B),
        title: const Text(
          "Rematch",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Rematch functionality coming soon!",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "OK",
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading || _waitingForOpponent
          ? Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0B1E), Color(0xFF1A093B), Color(0xFF2D0A5C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(child: _buildWaitingScreen()),
      )
          : _buildResultScreen(),
    );
  }
}