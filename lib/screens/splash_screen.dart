import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'login_screen.dart';
import 'main_menu_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuad,
    ));

    _colorAnimation = ColorTween(
      begin: Colors.purple[800],
      end: Colors.deepPurpleAccent,
    ).animate(_controller);

    _controller.forward();

    // ⏳ Wait 3s then check login state
    Future.delayed(const Duration(seconds: 3), () async {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user');

      if (!mounted) return;

      if (userData != null) {
        // ✅ user logged in → parse JSON and go to MainMenu
        final user = jsonDecode(userData);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainMenuScreen(user: user)),
        );
      } else {
        // ❌ no session → go to Login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated background gradient
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.5,
                    colors: [
                      Colors.black,
                      _colorAnimation.value ?? Colors.deepPurpleAccent,
                    ],
                    stops: const [0.1, 1.0],
                  ),
                ),
              );
            },
          ),

          // Pulsing circle effect
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _controller.value * 0.5 + 0.8,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.purple.withOpacity(0.1 * _controller.value),
                    ),
                  ),
                );
              },
            ),
          ),

          // Main content
          Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _opacityAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // App icon/logo
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Colors.purpleAccent, Colors.deepPurple],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.music_note,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // App title
                      const Text(
                        "BEAT BREAKER",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2.0,
                          shadows: [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.purpleAccent,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Tagline
                      const Text(
                        "Feel the rhythm",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Loading indicator
                      SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.purple[900],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.purpleAccent,
                          ),
                          minHeight: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
