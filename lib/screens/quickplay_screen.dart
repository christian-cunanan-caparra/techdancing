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
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _isSearching = false;
  String _statusMessage = "Finding opponent...";
  Timer? _searchTimer;
  Timer? _timeoutTimer;
  String? _roomCode;
  int _secondsRemaining = 60;
  bool _matchFound = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.1), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.7, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.7), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startMatchmaking();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startMatchmaking() async {
    setState(() {
      _isSearching = true;
      _statusMessage = "Finding opponent...";
      _secondsRemaining = 60;
      _matchFound = false;
    });

    _startTimeoutTimer();

    try {
      final result = await ApiService.quickPlayMatch(widget.user['id'].toString());

      if (result['status'] == 'success') {
        _handleMatchFound(result['room_code']);
      } else if (result['status'] == 'waiting') {
        _roomCode = result['room_code'];
        setState(() {
          _statusMessage = "Waiting for opponent...\n$_secondsRemaining seconds remaining";
        });
        _startPollingForOpponent();
      } else {
        _handleMatchmakingError(result['message'] ?? "Failed to find match");
      }
    } catch (e) {
      _handleMatchmakingError("Connection error");
    }
  }

  void _handleMatchFound(String roomCode) {
    if (!mounted) return;

    _timeoutTimer?.cancel();
    _searchTimer?.cancel();

    setState(() {
      _roomCode = roomCode;
      _matchFound = true;
      _statusMessage = "Match found!";
    });

    // Short delay before navigation to show success message
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _navigateToDanceSelection();
      }
    });
  }

  void _handleMatchmakingError(String message) {
    if (!mounted) return;

    _timeoutTimer?.cancel();
    _searchTimer?.cancel();

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
            _statusMessage = "No match found\nPlease try again later";
          });
        }
      } else if (_isSearching && _roomCode != null) {
        if (mounted) {
          setState(() {
            _statusMessage = "Waiting for opponent...\n$_secondsRemaining seconds remaining";
          });
        }
      }
    });
  }

  void _startPollingForOpponent() {
    _searchTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted || _roomCode == null) {
        timer.cancel();
        return;
      }

      try {
        final status = await ApiService.checkRoomStatus(_roomCode!);

        if (status['status'] == 'success' && status['room'] != null) {
          final room = status['room'];

          // Check if room is ready (both players present)
          if (room['player1_id'] != null && room['player2_id'] != null) {
            timer.cancel();
            _timeoutTimer?.cancel();
            if (mounted) {
              _handleMatchFound(_roomCode!);
            }
          }
        }
      } catch (e) {
        print('Polling error: $e');
        // Don't stop polling on error, just try again next cycle
      }
    });
  }

  void _navigateToDanceSelection() {
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
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _cancelSearch() async {
    _searchTimer?.cancel();
    _timeoutTimer?.cancel();

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
    _startMatchmaking();
  }

  Widget _buildStatusIcon() {
    if (_matchFound) {
      return const Icon(
        Icons.check_circle,
        size: 80,
        color: Colors.greenAccent,
      );
    } else if (_isSearching) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: const Icon(
            Icons.search,
            size: 80,
            color: Colors.cyanAccent,
          ),
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
    } else if (_statusMessage.contains("No match found")) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: _tryAgain,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
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
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: _cancelSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              "BACK",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      );
    } else if (_matchFound) {
      return const CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
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