import 'package:flutter/material.dart';

class GameplayScreen extends StatelessWidget {
  final int danceId;
  final String roomCode;

  const GameplayScreen({
    super.key,
    required this.danceId,
    required this.roomCode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Dance $danceId"),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_note, color: Colors.cyanAccent, size: 60),
              const SizedBox(height: 30),
              const Text(
                "Now Playing",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 20,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Dance $danceId",
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyanAccent,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "Room Code: $roomCode",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Colors.cyanAccent),
              const SizedBox(height: 20),
              const Text(
                "Get ready to dance!",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
