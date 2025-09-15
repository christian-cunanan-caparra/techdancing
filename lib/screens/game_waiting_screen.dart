import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'select_dance_screen.dart';
import 'gameplay_screen.dart';
import '../services/music_service.dart';

class GameWaitingScreen extends StatefulWidget {
  final Map user;
  final String roomCode;
  final bool isHost;

  const GameWaitingScreen({
    super.key,
    required this.user,
    required this.roomCode,
    required this.isHost,
  });

  @override
  State<GameWaitingScreen> createState() => _GameWaitingScreenState();
}

class _GameWaitingScreenState extends State<GameWaitingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _timer;
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  final MusicService _musicService = MusicService();
  bool _isMuted = false;
  bool _isCopied = false;
  Map<String, dynamic> _roomData = {};
  List<dynamic> _players = [];
  bool _isReady = false;
  bool _bothReady = false;
  bool _startingGame = false;
  bool _player1Ready = false;
  bool _player2Ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeMusic();
    _resetReadyStatus().then((_) {
      _startPollingRoom();
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _musicService.resumeMusic(screenName: 'waiting');
    } else if (state == AppLifecycleState.paused) {
      _musicService.pauseMusic();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeMusic() async {
    await _musicService.initialize();
    _musicService.playMenuMusic(screenName: 'waiting');
    setState(() {
      _isMuted = _musicService.isMuted;
    });
  }

  Future<void> _resetReadyStatus() async {
    try {
      await ApiService.resetReadyStatus(widget.roomCode);
      setState(() {
        _isReady = false;
        _bothReady = false;
        _player1Ready = false;
        _player2Ready = false;
      });
    } catch (e) {
      print('Error resetting ready status: $e');
    }
  }

  void _startPollingRoom() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final result = await ApiService.checkRoomStatus(widget.roomCode);

        if (result['status'] == 'success') {
          setState(() {
            _roomData = result['room'] ?? {};
            _players = [];

            if (_roomData['player1_id'] != null) {
              _players.add({
                'id': _roomData['player1_id'],
                'name': _roomData['player1_name'] ?? 'Player 1',
                'isHost': true
              });
            }

            if (_roomData['player2_id'] != null) {
              _players.add({
                'id': _roomData['player2_id'],
                'name': _roomData['player2_name'] ?? 'Player 2',
                'isHost': false
              });
            }
          });

          final player2Id = _roomData['player2_id'];
          final gameType = result['game_type'] ?? 'multiplayer';

          // Check ready status regardless of player count
          final readyResult = await ApiService.checkBothReady(widget.roomCode);
          if (readyResult['status'] == 'success') {
            setState(() {
              _player1Ready = readyResult['player1_ready'] ?? false;
              _player2Ready = readyResult['player2_ready'] ?? false;
              _bothReady = readyResult['both_ready'] ?? false;
            });

            if (readyResult['both_ready'] == true && !_startingGame) {
              _startGameInstantly();
            }
          }
        }
      } catch (e) {
        print('Error in polling: $e');
      }
    });
  }

  Future<void> _setReadyStatus(bool isReady) async {
    try {
      final result = await ApiService.setReadyStatus(
          widget.roomCode,
          widget.user['id'].toString(),
          isReady
      );

      if (result['status'] == 'success') {
        setState(() {
          _isReady = isReady;
        });

        // Immediately check if both players are ready
        final readyResult = await ApiService.checkBothReady(widget.roomCode);
        if (readyResult['status'] == 'success') {
          setState(() {
            _player1Ready = readyResult['player1_ready'] ?? false;
            _player2Ready = readyResult['player2_ready'] ?? false;
            _bothReady = readyResult['both_ready'] ?? false;
          });

          if (readyResult['both_ready'] == true && !_startingGame) {
            _startGameInstantly();
          }
        }
      } else {
        print('Failed to set ready status: ${result['message']}');
      }
    } catch (e) {
      print('Error setting ready status: $e');
    }
  }

  void _startGameInstantly() {
    if (_startingGame) return;

    setState(() {
      _startingGame = true;
    });

    _timer?.cancel();
    _musicService.pauseMusic(rememberToResume: false);

    // Navigate immediately without delay
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SelectDanceScreen(
          user: widget.user,
          roomCode: widget.roomCode,
        ),
      ),
    );
  }

  void _toggleMute() {
    _musicService.toggleMute();
    setState(() {
      _isMuted = _musicService.isMuted;
    });
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    setState(() {
      _isCopied = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  void _leaveRoom() {
    _timer?.cancel();
    _musicService.pauseMusic(rememberToResume: false);
    Navigator.pop(context);
  }

  Widget _buildPlayerStatusIndicator(bool isReady) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: isReady ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.user['name']?.toString() ?? 'Player';
    final userId = widget.user['id']?.toString() ?? '';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("$userName's Waiting Room"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _leaveRoom,
          tooltip: 'Leave Room',
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
            ),
            onPressed: _toggleMute,
            tooltip: _isMuted ? 'Unmute' : 'Mute',
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0523), Color(0xFF1D054A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            // User welcome message
            Container(
              margin: const EdgeInsets.only(top: 80, bottom: 10),
              child: Text(
                "Welcome, $userName!",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Room code section
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                margin: const EdgeInsets.only(bottom: 30),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.purpleAccent.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      "ROOM CODE",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.roomCode,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.cyanAccent,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(
                            _isCopied ? Icons.check : Icons.content_copy,
                            color: _isCopied ? Colors.green : Colors.white70,
                            size: 20,
                          ),
                          onPressed: _copyToClipboard,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isCopied ? "Copied to clipboard!" : "Share this code with friends",
                      style: TextStyle(
                        color: _isCopied ? Colors.green : Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Ready button (only show when both players are present)
            if (_players.length >= 2 && !_bothReady)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton(
                  onPressed: _isReady
                      ? null
                      : () => _setReadyStatus(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isReady
                        ? Colors.green.withOpacity(0.5)
                        : Colors.cyanAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    _isReady ? "READY!" : "I'M READY",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // Players list
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "PLAYERS (${_players.length}/2)",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_players.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_outline,
                                color: Colors.white30,
                                size: 40,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "Waiting for players...",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: _players.length,
                          itemBuilder: (context, index) {
                            final player = _players[index];
                            final playerId = player['id']?.toString() ?? '';
                            final playerName = player['name']?.toString() ?? 'Player';
                            final isCurrentUser = playerId == userId;
                            final isPlayer1 = index == 0;
                            final isReady = isPlayer1 ? _player1Ready : _player2Ready;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: player['isHost']
                                          ? Colors.purpleAccent.withOpacity(0.2)
                                          : Colors.cyanAccent.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      player['isHost'] ? Icons.star : Icons.person,
                                      color: player['isHost']
                                          ? Colors.purpleAccent
                                          : Colors.cyanAccent,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              playerName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            _buildPlayerStatusIndicator(isReady),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          player['isHost'] ? "Room Host" : "Player",
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isCurrentUser)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.cyanAccent.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        "You",
                                        style: TextStyle(
                                          color: Colors.cyanAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Status message and loading
            Container(
              margin: const EdgeInsets.only(top: 20, bottom: 40),
              child: Column(
                children: [
                  Text(
                    _bothReady
                        ? "Starting game now!"
                        : _players.length < 2
                        ? "Waiting for another player to join..."
                        : _isReady
                        ? "Waiting for other player to be ready..."
                        : "Press READY when you're prepared to start!",
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(
                    color: Colors.cyanAccent,
                    strokeWidth: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}