import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import 'main_menu_screen.dart';
import 'register_screen.dart';
import 'verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool _obscurePassword = true;
  bool isOnline = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  @override
  void initState() {
    super.initState();

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

    // Check for saved credentials
    _loadSavedCredentials();

    // Check connectivity status
    _checkConnectivity();

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        isOnline = result != ConnectivityResult.none;
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isOnline = connectivityResult != ConnectivityResult.none;
    });
  }

  

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('savedEmail');
      final rememberMe = prefs.getBool('rememberMe') ?? false;

      if (rememberMe && savedEmail != null) {
        setState(() {
          emailController.text = savedEmail;
        });
      }
    } catch (e) {
      print("Error loading saved credentials: $e");
    }
  }

  Future<bool> loginUser() async {
    if (!_formKey.currentState!.validate()) return false;

    // Check if we're online before attempting login
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please check your network.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }

    setState(() => isLoading = true);

    try {
      final result = await ApiService.login(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (result['status'] == 'success') {
        // ✅ Save login session
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('user', jsonEncode(result['user']));
        await prefs.setString('session_token', result['session_token'] ?? '');

        // Save email if remember me is enabled
        await prefs.setBool('rememberMe', true);
        await prefs.setString('savedEmail', emailController.text.trim());

        Navigator.of(context).pushReplacement(_createFadeRoute(
          MainMenuScreen(user: result['user']),
        ));
        return true;
      } else {
        // Handle already logged in case
        if (result['message']?.contains('already logged in') == true || result['already_logged_in'] == true) {
          _showAlreadyLoggedInDialog();
        }
        // Handle unverified account
        else if (result['requires_verification'] == true) {
          _showVerificationRequiredDialog(result['email'] ?? emailController.text.trim());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Login failed'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return false;
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
      return false;
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showAlreadyLoggedInDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1539),
        title: const Text(
          "Already Logged In",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        content: const Text(
          "Your account is already logged in on another device. For security, we need to send a verification code to your email to confirm this action.",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.cyanAccent)),
          ),
          TextButton(
            onPressed: () => _sendForceLogoutCode(),
            child: const Text("Send Verification Code", style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendForceLogoutCode() async {
    Navigator.pop(context); // Close the initial dialog

    setState(() => isLoading = true);

    try {
      final result = await ApiService.sendForceLogoutCode(emailController.text.trim());

      if (result['status'] == 'success') {
        _showCodeVerificationDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to send verification code'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send verification code'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showCodeVerificationDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1539),
        title: const Text(
          "Enter Verification Code",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "We've sent a 6-digit verification code to your email. Please enter it below:",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: codeController,
              style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
              textAlign: TextAlign.center,
              maxLength: 6,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                counterText: "",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.pinkAccent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.pinkAccent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.pinkAccent),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _sendForceLogoutCode(),
                  child: const Text(
                    "Resend Code",
                    style: TextStyle(color: Colors.cyanAccent, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.cyanAccent)),
          ),
          TextButton(
            onPressed: () => _verifyForceLogoutCode(codeController.text.trim()),
            child: const Text("Verify", style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyForceLogoutCode(String code) async {
    if (code.isEmpty || code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit code'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await ApiService.verifyForceLogoutCode(
        emailController.text.trim(),
        code,
      );

      if (result['status'] == 'success') {
        Navigator.pop(context); // Close code verification dialog
        await _performForceLogout();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Invalid verification code'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to verify code'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _performForceLogout() async {
    setState(() => isLoading = true);

    try {
      final result = await ApiService.forceLogout(emailController.text.trim());

      if (result['status'] == 'success') {
        // Now try to login again
        await loginUser();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to logout other device'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to logout other device'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => isLoading = false);
    }
  }

  void _showVerificationRequiredDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1539),
        title: const Text(
          "Account Not Verified",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        content: Text(
          "Your account hasn't been verified. Please check your email for the verification code sent to $email",
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.cyanAccent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to verification screen
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => VerificationScreen(
                    email: email,
                    name: "", // We don't have the name here, but it's optional
                  ),
                ),
              );
            },
            child: const Text("Verify Now", style: TextStyle(color: Colors.pinkAccent)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resendVerificationCode(email);
            },
            child: const Text("Resend Code", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationCode(String email) async {
    try {
      final result = await ApiService.resendVerification(email);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['status'] == 'success'
                ? "Verification code resent to $email"
                : "Failed to resend code",
          ),
          backgroundColor: result['status'] == 'success' ? Colors.greenAccent : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to resend verification code'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // Forgot password functionality with independent email field
  void _showForgotPasswordDialog() {
    final forgotPasswordEmailController = TextEditingController(text: emailController.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1539),
        title: const Text(
          "Reset Password",
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter your email address to receive a password reset link:",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: forgotPasswordEmailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: const TextStyle(color: Colors.cyanAccent),
                hintText: 'Enter your email address',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.pinkAccent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.pinkAccent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.pinkAccent),
                ),
              ),
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
            const SizedBox(height: 12),
            const Text(
              "You'll receive an email with a link to reset your password directly in your browser.",
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.cyanAccent)),
          ),
          TextButton(
            onPressed: () => _requestPasswordReset(forgotPasswordEmailController.text.trim()),
            child: const Text("Send Reset Link", style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _requestPasswordReset(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validate email format
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.pop(context); // Close dialog

    setState(() => isLoading = true);

    try {
      final result = await ApiService.forgotPassword(email);

      if (result['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Password reset link sent to $email. Check your email to continue."),
            backgroundColor: Colors.greenAccent,
            duration: const Duration(seconds: 5),
          ),
        );

        // Optionally update the main email field with the entered email
        if (emailController.text.isEmpty) {
          setState(() {
            emailController.text = email;
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to send reset link'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send password reset link'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Route _createFadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  Widget _buildTextField({
    required IconData icon,
    required String hint,
    required TextEditingController controller,
    bool obscureText = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool isEnabled = true,
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
                  obscureText: obscureText && _obscurePassword,
                  style: const TextStyle(color: Colors.cyanAccent),
                  cursorColor: Colors.pinkAccent,
                  keyboardType: keyboardType,
                  validator: validator,
                  enabled: isEnabled,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.cyanAccent),
                    border: InputBorder.none,
                    errorStyle: const TextStyle(color: Colors.pinkAccent),
                  ),
                ),
              ),
              if (obscureText)
                IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: Colors.cyanAccent.withOpacity(0.7),
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
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
                  const SizedBox(height: 30),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        const Text(
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
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isOnline ? "Online" : "Offline",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SlideTransition(
                    position: _slideAnimation,
                    child: const Text(
                      "Feel the rhythm!",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
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
                  SlideTransition(
                    position: _slideAnimation,
                    child: _buildTextField(
                      icon: Icons.lock,
                      hint: 'PASSWORD',
                      controller: passwordController,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  SlideTransition(
                    position: _slideAnimation,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SlideTransition(
                    position: _slideAnimation,
                    child: Center(
                      child: isLoading
                          ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
                      )
                          : ElevatedButton(
                        onPressed: isOnline ? loginUser : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isOnline ? Colors.pinkAccent : Colors.grey,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 60,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 8,
                          shadowColor: isOnline
                              ? Colors.pinkAccent.withOpacity(0.5)
                              : Colors.grey.withOpacity(0.5),
                        ),
                        child: const Text(
                          'Login',
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
                  SlideTransition(
                    position: _slideAnimation,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: isOnline ? () {
                            Navigator.of(context).pushReplacement(
                              _createFadeRoute(const RegisterScreen()),
                            );
                          } : null,
                          child: Text(
                            "Sign Up",
                            style: TextStyle(
                              color: isOnline ? Colors.cyanAccent : Colors.grey,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Help text for users
                  const SizedBox(height: 30),
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
                        children: [
                          Text(
                            "💡 Security Features:",
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "• Force logout requires email verification for security\n• All verification codes expire in 10 minutes\n• You can request password reset even if email field is empty",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.left,
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