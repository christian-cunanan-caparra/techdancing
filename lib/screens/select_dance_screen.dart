// select_dance_screen.dart (updated)
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'gameplay_screen.dart';
import '../services/music_service.dart'; // Add this import

class SelectDanceScreen extends StatelessWidget {
  final Map user;
  final String roomCode;
  final MusicService _musicService = MusicService();

  SelectDanceScreen({
    super.key,
    required this.user,
    required this.roomCode,
  });

  // List of dance names with their IDs
  final List<Map<String, dynamic>> dances = const [
    {'id': 1, 'name': 'JUMBO CHACHA'},
    {'id': 2, 'name': 'PAA TUHOD BALIKAT'},
    {'id': 3, 'name': 'ELECTRIC SLIDE'},
    {'id': 4, 'name': 'COTTON EYED JOE'},
  ];

  void _selectDance(BuildContext context, int danceId) async {
    // Stop music when a dance is selected
    _musicService.pauseMusic(rememberToResume: false);

    final result = await ApiService.selectDance(roomCode, danceId);
    if (result['status'] == 'success') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GameplayScreen(
            danceId: danceId,
            roomCode: roomCode,
            userId: user['id'].toString(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to select dance")),
      );
      // If failed, resume music
      _musicService.resumeMusic(screenName: 'select_dance');
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
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
            // Use dances list instead of hardcoded numbers
            for (var dance in dances)
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
                  onPressed: () => _selectDance(context, dance['id']),
                  child: Text(
                    dance['name'],
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}