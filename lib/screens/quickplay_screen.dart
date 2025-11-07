import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/music_service.dart';
import 'select_dance_screen.dart';

class QuickPlayScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const QuickPlayScreen({super.key, required this.user});

  @override
  State<QuickPlayScreen> createState() => _QuickPlayScreenState();
}

class _QuickPlayScreenState extends State<QuickPlayScreen>
    with SingleTickerProviderStateMixin {
  final MusicService _musicService = MusicService();
  late AnimationController _controller;

  bool _isSearching = false;
  String _statusMessage = "Finding opponent...";
  Timer? _searchTimer;
  Timer? _timeoutTimer;
  Timer? _syncTimer;
  String? _roomCode;
  int _secondsRemaining = 25;
  bool _matchFound = false;
  int? _matchStartTime;
  String? _opponentName;
  int? _playerNumber;
  bool _shouldNavigate = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRealTimeMatchmaking();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchTimer?.cancel();
    _timeoutTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  void _startRealTimeMatchmaking() async {
    setState(() {
      _isSearching = true;
      _statusMessage = "Finding opponent...";
      _secondsRemaining = 25;
      _matchFound = false;
      _opponentName = null;
      _playerNumber = null;
      _shouldNavigate = false;
    });

    _startTimeoutTimer();

    try {
      final result = await ApiService.quickPlayMatch(widget.user['id'].toString());

      if (result['status'] == 'success') {
        _handleBothPlayersMatch(
          result['room_code'],
          result['match_start_time'],
          result['player_number'],
        );
      } else if (result['status'] == 'waiting') {
        _roomCode = result['room_code'];
        _playerNumber = result['player_number'];
        _matchStartTime = result['match_start_time'];
        setState(() {
          _statusMessage = "Waiting for opponent...\nRoom: $_roomCode";
        });
        _startBothPlayersPolling();
      } else {
        _handleMatchmakingError(result['message'] ?? "Failed to find match");
      }
    } catch (e) {
      _handleMatchmakingError("Connection error");
    }
  }

  void _handleBothPlayersMatch(String roomCode, int matchStartTime, int playerNumber) async {
    if (!mounted) return;

    _timeoutTimer?.cancel();
    _searchTimer?.cancel();

    // Get opponent info
    try {
      final status = await ApiService.checkRoomStatusWithUser(roomCode, widget.user['id'].toString());
      if (status['status'] == 'success' && status['room'] != null) {
        final room = status['room'];
        final opponentName = playerNumber == 1 ? room['player2_name'] : room['player1_name'];

        setState(() {
          _opponentName = opponentName ?? 'Opponent';
          _playerNumber = playerNumber;
          _statusMessage = "Matched with $_opponentName!";
        });
      }
    } catch (e) {
      print('Error fetching room details: $e');
    }

    setState(() {
      _roomCode = roomCode;
      _matchFound = true;
      _matchStartTime = matchStartTime;
    });

    _startBothPlayersSync();
  }

  void _startBothPlayersSync() {
    _syncTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final timeUntilStart = _matchStartTime! - now;

      if (timeUntilStart <= 0) {
        timer.cancel();
        _navigateBothPlayers();
      } else {
        setState(() {
          _statusMessage = _opponentName != null
              ? "Matched with $_opponentName!\nStarting in $timeUntilStart..."
              : "Match found!\nStarting in $timeUntilStart...";
        });
      }
    });
  }

  void _handleMatchmakingError(String message) {
    if (!mounted) return;

    _timeoutTimer?.cancel();
    _searchTimer?.cancel();
    _syncTimer?.cancel();

    setState(() {
      _isSearching = false;
      _statusMessage = message;
    });
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _secondsRemaining--;
      });

      if (_secondsRemaining <= 0) {
        timer.cancel();
        _searchTimer?.cancel();
        if (mounted) {
          setState(() {
            _isSearching = false;
            _statusMessage = "No match found\nTry again";
          });
        }
      }
    });
  }

  void _startBothPlayersPolling() {
    _searchTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!mounted || _roomCode == null) {
        timer.cancel();
        return;
      }

      try {
        final status = await ApiService.checkRoomStatusWithUser(_roomCode!, widget.user['id'].toString());

        if (status['status'] == 'success' && status['room'] != null) {
          final room = status['room'];

          // Check if BOTH players are present
          if (room['player1_id'] != null && room['player2_id'] != null) {
            timer.cancel();
            _timeoutTimer?.cancel();

            if (mounted) {
              // Use the synchronized match_start_time from database
              final matchStartTime = room['match_start_time'] ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 2;
              final playerNumber = status['player_number'] ?? (_playerNumber ?? 1);

              _handleBothPlayersMatch(_roomCode!, matchStartTime, playerNumber);
            }
          }

          // Check if we should navigate immediately (for late joiners)
          if (status['navigate_immediately'] == true) {
            timer.cancel();
            _timeoutTimer?.cancel();
            if (mounted) {
              _navigateBothPlayers();
            }
          }
        }
      } catch (e) {
        print('Polling error: $e');
      }
    });
  }

  void _navigateBothPlayers() {
    if (!mounted || _roomCode == null) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SelectDanceScreen(
          user: widget.user,
          roomCode: _roomCode!,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _cancelSearch() async {
    _searchTimer?.cancel();
    _timeoutTimer?.cancel();
    _syncTimer?.cancel();

    try {
      await ApiService.cancelQuickPlay(widget.user['id'].toString());
    } catch (e) {
      // Handle error silently
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _tryAgain() {
    _startRealTimeMatchmaking();
  }

  Widget _buildStatusIcon() {
    if (_matchFound) {
      return Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.check_circle,
            size: 80,
            color: Colors.greenAccent,
          ),
          if (_matchStartTime != null)
            FutureBuilder<int>(
              future: _getCountdown(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data! > 0) {
                  return Text(
                    '${snapshot.data}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
        ],
      );
    } else if (_isSearching) {
      return ScaleTransition(
        scale: Tween(begin: 0.9, end: 1.1).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
        ),
        child: const Icon(
          Icons.search,
          size: 80,
          color: Colors.cyanAccent,
        ),
      );
    } else {
      return const Icon(
        Icons.search_off,
        size: 80,
        color: Colors.redAccent,
      );
    }
  }

  Future<int> _getCountdown() async {
    if (_matchStartTime == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return _matchStartTime! - now;
  }

  Widget _buildActionButtons() {
    if (_isSearching) {
      return ElevatedButton(
        onPressed: _cancelSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent.withOpacity(0.8),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          "CANCEL",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    } else {
      return ElevatedButton(
        onPressed: _tryAgain,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyanAccent.withOpacity(0.8),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: const Text(
          "TRY AGAIN",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: WillPopScope(
        onWillPop: () async {
          _cancelSearch();
          return false;
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D0B1E), Color(0xFF1A093B), Color(0xFF2D0A5C)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatusIcon(),

                const SizedBox(height: 30),

                Text(
                  _statusMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                if (_roomCode != null)
                  Text(
                    "Room: $_roomCode",
                    style: const TextStyle(
                      color: Colors.pinkAccent,
                      fontSize: 16,
                    ),
                  ),

                if (_opponentName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      "vs $_opponentName",
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                if (_playerNumber != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      "Player $_playerNumber",
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 14,
                      ),
                    ),
                  ),

                const SizedBox(height: 40),

                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}