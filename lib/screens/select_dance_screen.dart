import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'gameplay_screen.dart';

class SelectDanceScreen extends StatelessWidget {
  final Map user;
  final String roomCode;

  const SelectDanceScreen({
    super.key,
    required this.user,
    required this.roomCode,
  });

  void _selectDance(BuildContext context, int danceId) async {
    final result = await ApiService.selectDance(roomCode, danceId);
    if (result['status'] == 'success') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GameplayScreen(danceId: danceId, roomCode: roomCode),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to select dance")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Select a Dance"),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Pick a Dance for the Match",
              style: TextStyle(
                fontSize: 22,
                color: Colors.cyanAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            for (int i = 1; i <= 4; i++) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.cyanAccent.withOpacity(0.3),
                    elevation: 8,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: const BorderSide(color: Colors.cyanAccent),
                  ),
                  onPressed: () => _selectDance(context, i),
                  child: Text(
                    "Dance $i",
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
