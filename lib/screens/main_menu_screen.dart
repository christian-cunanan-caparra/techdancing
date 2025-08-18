import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'multiplayer_screen.dart';
import 'leaderboard_screen.dart';

class MainMenuScreen extends StatelessWidget {
  final Map user;

  const MainMenuScreen({super.key, required this.user});

  Future<void> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  void startGame(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Start game coming soon!")),
    );
  }

  void goToMultiplayer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MultiplayerScreen(user: user)),
    );
  }

  void goToLeaderboard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LeaderboardScreen(userId: user['id'].toString())),
    );
  }

  Widget buildGradientButton({
    required IconData icon,
    required String label,
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
        onPressed: onPressed,
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
    String name = user['name'] ?? '';
    String level = user['level']?.toString() ?? '1';
    String status = user['status'] ?? 'active';


    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0523), Color(0xFF1D054A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "BEAT\n",
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [Colors.pinkAccent, Colors.lightBlueAccent],
                            ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                        ),
                      ),
                      TextSpan(
                        text: "BREAKER",
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [Colors.greenAccent, Colors.purpleAccent],
                            ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Feel the rhythm of the game",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 40),
                buildGradientButton(
                  icon: Icons.play_arrow,
                  label: "SINGLE PLAYER",
                  onPressed: () => startGame(context),
                  gradientColors: [Colors.greenAccent, Colors.cyanAccent],
                ),
                buildGradientButton(
                  icon: Icons.people,
                  label: "MULTIPLAYER",
                  onPressed: () => goToMultiplayer(context),
                  gradientColors: [Colors.blueAccent, Colors.deepPurpleAccent],
                ),
                buildGradientButton(
                  icon: Icons.leaderboard,
                  label: "LEADERBOARD",
                  onPressed: () => goToLeaderboard(context),
                  gradientColors: [Colors.amberAccent, Colors.orangeAccent],
                ),
                buildGradientButton(
                  icon: Icons.exit_to_app,
                  label: "LOGOUT",
                  onPressed: () => logout(context),
                  gradientColors: [Colors.redAccent, Colors.deepOrangeAccent],
                ),
                const SizedBox(height: 40),
                Text(
                  "Logged in as: $name\nLevel: $level | Status: $status",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}