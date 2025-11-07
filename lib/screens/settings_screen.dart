import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techdancing/services/api_service.dart';
import 'package:techdancing/screens/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Map user;
  const SettingsScreen({super.key, required this.user});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  @override
  void initState() {
    super.initState();
  }

  void _showLogoutDialog() {
    showDialog(context: context, builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red,),
        ),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => _logout(context),
            child: const Text("Logout", style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    },
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('user');
      final sessionToken = prefs.getString('session_token');

      print('=== STARTING LOGOUT PROCESS ===');
      print('User data: $userString');
      print('Session token: $sessionToken');

      if (userString != null) {
        final userMap = jsonDecode(userString);
        final userId = userMap['id'].toString();

        print('Calling logout API for user ID: $userId');

        // Call the logout API
        final logoutResult = await ApiService.logout(userId, sessionToken ?? '');
        print('Logout API result: $logoutResult');

        if (logoutResult['status'] == 'success') {
          print('✅ Database logout successful');
        } else {
          print('❌ Database logout failed: ${logoutResult['message']}');
        }
      } else {
        print('❌ No user data found in SharedPreferences');
      }

      // Clear local storage regardless
      await prefs.setBool('is_logged_in', false);
      await prefs.setInt('is_logged_in', 0);
      await prefs.remove('user');
      await prefs.remove('session_token');

      print('✅ Local storage cleared');
      print('=== LOGOUT PROCESS COMPLETED ===');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (e) {
      print('❌ Logout error: $e');
      // Even if API call fails, clear local data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
      await prefs.setInt('is_logged_in', 0);
      await prefs.remove('user');
      await prefs.remove('session_token');

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.withOpacity(0.3), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 10),
                const Text(
                  "Settings",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Settings List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader("SUPPORT"),
                _buildListTile(
                  icon: Icons.help,
                  title: "Help & Support",
                  subtitle: "Get help with the game",
                  onTap: () {},
                ),
                _buildListTile(
                  icon: Icons.star,
                  title: "Rate the App",
                  subtitle: "Share your experience",
                  onTap: () {},
                ),
                _buildListTile(
                  icon: Icons.share,
                  title: "Share App",
                  subtitle: "Tell your friends",
                  onTap: () {},
                ),
                _buildListTile(
                  icon: Icons.info,
                  title: "About",
                  subtitle: "App version and info",
                  onTap: () {},
                ),
                _buildSectionHeader("SIGN OUT"),
                _buildListTile(
                  icon: Icons.exit_to_app,
                  title: "Logout",
                  subtitle: "Sign out of your account",
                  titleColor: Colors.red,
                  iconColor: Colors.red,
                  onTap: _showLogoutDialog,
                ),

                const SizedBox(height: 30),

                Center(
                  child: Text(
                    "Beat Breaker v1.0.0",
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10, left: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? titleColor,
    Color? iconColor,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.white.withOpacity(0.05),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? Colors.white70,),
        title: Text(
          title,
          style: TextStyle(color: titleColor ?? Colors.white, fontSize: 16,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: onTap,
      ),
    );
  }
}