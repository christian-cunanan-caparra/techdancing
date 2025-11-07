import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? email;
  final String? resetToken;

  const ResetPasswordScreen({super.key, this.email, this.resetToken});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final resetTokenController = TextEditingController();

  bool isLoading = false;
  bool isOnline = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Pre-fill email and token if provided
    if (widget.email != null) {
      emailController.text = widget.email!;
    }
    if (widget.resetToken != null) {
      resetTokenController.text = widget.resetToken!;
    }

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Set up animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    resetTokenController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final result = await ApiService.resetPassword(
        emailController.text.trim(),
        newPasswordController.text.trim(),
        resetTokenController.text.trim(),
      );

      if (result['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password reset successfully!'),
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        // Navigate back to login screen after successful reset
        Timer(const Duration(seconds: 2), () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to reset password'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Network error. Please try again.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildTextField({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    bool obscureText = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.pinkAccent.withOpacity(0.7),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(icon, color: Colors.cyanAccent),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  obscureText: obscureText,
                  style: const TextStyle(color: Colors.cyanAccent),
                  cursorColor: Colors.pinkAccent,
                  keyboardType: keyboardType,
                  validator: validator,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.cyanAccent),
                    border: InputBorder.none,
                    errorStyle: const TextStyle(color: Colors.pinkAccent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Back button and title
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      SlideTransition(
                        position: _slideAnimation,
                        child: const Text(
                          "Reset Password",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      "BEAT\nBREAKER",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.pinkAccent,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SlideTransition(
                    position: _slideAnimation,
                    child: const Text(
                      "Set your new password",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Email field
                  SlideTransition(
                    position: _slideAnimation,
                    child: _buildTextField(
                      icon: Icons.email,
                      hint: 'EMAIL',
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Reset Token field
                  SlideTransition(
                    position: _slideAnimation,
                    child: _buildTextField(
                      icon: Icons.vpn_key,
                      hint: 'RESET TOKEN',
                      controller: resetTokenController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the reset token from your email';
                        }
                        return null;
                      },
                    ),
                  ),

                  // New Password field
                  SlideTransition(
                    position: _slideAnimation,
                    child: _buildTextField(
                      icon: Icons.lock,
                      hint: 'NEW PASSWORD',
                      controller: newPasswordController,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter new password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Confirm Password field
                  SlideTransition(
                    position: _slideAnimation,
                    child: _buildTextField(
                      icon: Icons.lock_outline,
                      hint: 'CONFIRM PASSWORD',
                      controller: confirmPasswordController,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Reset Password Button
                  SlideTransition(
                    position: _slideAnimation,
                    child: Center(
                      child: isLoading
                          ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
                      )
                          : ElevatedButton(
                        onPressed: _resetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 60,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                          shadowColor: Colors.pinkAccent.withOpacity(0.5),
                        ),
                        child: const Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Back to Login
                  SlideTransition(
                    position: _slideAnimation,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Remember your password? ",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                            );
                          },
                          child: const Text(
                            "Login",
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Instructions
                  SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Instructions:",
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "1. Enter the email associated with your account\n"
                                "2. Copy the reset token from the email we sent you\n"
                                "3. Create a new password (at least 6 characters)\n"
                                "4. Confirm your new password",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}