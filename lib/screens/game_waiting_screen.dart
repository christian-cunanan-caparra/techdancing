import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'select_dance_screen.dart';
import 'gameplay_screen.dart';

class GameWaitingScreen extends StatefulWidget {
  final Map user;
  final String roomCode;
  final bool isHost;
//gg
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
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _startPollingRoom();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startPollingRoom() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final result = await ApiService.checkRoomStatus(widget.roomCode);

      if (result['status'] == 'success') {
        final data = result['room'];
        final player2Id = data['player2_id'];
        final danceId = data['dance_id'];

        if (widget.isHost && player2Id != null) {
          _timer?.cancel();
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

        if (!widget.isHost && danceId != null) {
          _timer?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => GameplayScreen(
                danceId: int.parse(danceId.toString()),
                roomCode: widget.roomCode,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Waiting Room"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
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
        child: Center(
          child: ScaleTransition(
            scale: _pulseAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_bottom, color: Colors.cyanAccent, size: 48),
                const SizedBox(height: 20),
                const Text(
                  "Room Code",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 20,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.roomCode,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  widget.isHost
                      ? "Waiting for another player to join..."
                      : "Waiting for host to choose a dance...",
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                const CircularProgressIndicator(color: Colors.cyanAccent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
