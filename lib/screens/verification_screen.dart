// lib/screens/verification_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  final String name;

  const VerificationScreen({super.key, required this.email, required this.name});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool isLoading = false;
  bool isResending = false;

  @override
  void initState() {
    super.initState();
    _setupFocusNodes();
  }

  void _setupFocusNodes() {
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (!_focusNodes[i].hasFocus && _codeControllers[i].text.isEmpty && i > 0) {
          FocusScope.of(context).requestFocus(_focusNodes[i - 1]);
        }
      });
    }
  }

  void _handleCodeInput(String value, int index) {
    if (value.length == 1 && index < _codeControllers.length - 1) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }

    // Auto-submit when all fields are filled
    if (_isAllFieldsFilled()) {
      _verifyCode();
    }
  }

  bool _isAllFieldsFilled() {
    return _codeControllers.every((controller) => controller.text.isNotEmpty);
  }

  String _getVerificationCode() {
    return _codeControllers.map((controller) => controller.text).join();
  }

  void _verifyCode() async {
    if (!_isAllFieldsFilled()) return;

    setState(() => isLoading = true);

    try {
      final result = await ApiService.verifyAccount(
        widget.email,
        _getVerificationCode(),
      );

      if (result['status'] == 'success') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Account verified successfully!"),
            backgroundColor: Colors.greenAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Verification failed'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        // Clear all fields on failure
        for (var controller in _codeControllers) {
          controller.clear();
        }
        FocusScope.of(context).requestFocus(_focusNodes[0]);
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

  void _resendCode() async {
    setState(() => isResending = true);

    try {
      final result = await ApiService.resendVerification(widget.email);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['status'] == 'success'
              ? "New verification code sent!"
              : "Failed to resend code"),
          backgroundColor: result['status'] == 'success' ? Colors.greenAccent : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to resend code'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isResending = false);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B1E),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  "🔐 Verify Your Account",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "We sent a 6-digit code to ${widget.email}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Code Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) {
                    return SizedBox(
                      width: 45,
                      child: TextField(
                        controller: _codeControllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          counterText: "",
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.pinkAccent.withOpacity(0.7),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.pinkAccent.withOpacity(0.7),
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.cyanAccent,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) => _handleCodeInput(value, index),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 30),

                // Verify Button
                isLoading
                    ? const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
                )
                    : ElevatedButton(
                  onPressed: _isAllFieldsFilled() ? _verifyCode : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 8,
                  ),
                  child: const Text(
                    'Verify Account',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Resend Code
                TextButton(
                  onPressed: isResending ? null : _resendCode,
                  child: isResending
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                    ),
                  )
                      : const Text(
                    "Resend Code",
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Help Text
                const Text(
                  "Check your email inbox (and spam folder) for the verification code. "
                      "The code will expire in 1 hour.",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}