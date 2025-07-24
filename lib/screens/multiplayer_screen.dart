import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'game_waiting_screen.dart';

class MultiplayerScreen extends StatefulWidget {
  final Map user;

  const MultiplayerScreen({super.key, required this.user});

  @override
  State<MultiplayerScreen> createState() => _MultiplayerScreenState();
}

class _MultiplayerScreenState extends State<MultiplayerScreen> {
  final joinCodeController = TextEditingController();
  bool isLoading = false;
  String? roomCode;

  Future<void> createRoom() async {
    setState(() => isLoading = true);
    final result = await ApiService.createRoom(widget.user['id'].toString());
    setState(() => isLoading = false);

    if (result['status'] == 'success') {
      roomCode = result['room_code'];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameWaitingScreen(
            user: widget.user,
            roomCode: roomCode!,
            isHost: true,
          ),
        ),
      );
    } else {
      _showError(result['message']);
    }
  }

  Future<void> joinRoom() async {
    final code = joinCodeController.text.trim();
    if (code.isEmpty) return _showError("Please enter a room code.");

    setState(() => isLoading = true);
    final result = await ApiService.joinRoom(code, widget.user['id'].toString());
    setState(() => isLoading = false);

    if (result['status'] == 'success') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameWaitingScreen(
            user: widget.user,
            roomCode: code,
            isHost: false,
          ),
        ),
      );
    } else {
      _showError(result['message']);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget buildGradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required List<Color> gradientColors,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(30),
      ),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(fontSize: 18),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Multiplayer"),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildGradientButton(
              label: "Create Room",
              icon: Icons.add,
              onPressed: createRoom,
              gradientColors: [Colors.greenAccent, Colors.cyanAccent],
            ),
            const SizedBox(height: 20),
            const Text(
              "Or join a room",
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: joinCodeController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Enter Room Code',
                labelStyle: const TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.cyanAccent),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 20),
            buildGradientButton(
              label: "Join Room",
              icon: Icons.login,
              onPressed: joinRoom,
              gradientColors: [Colors.deepPurpleAccent, Colors.indigoAccent],
            ),
          ],
        ),
      ),
    );
  }
}
