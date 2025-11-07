import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'custom_dance_gameplay_screen.dart';

class CustomDanceSelectionScreen extends StatefulWidget {
  final Map user;

  const CustomDanceSelectionScreen({super.key, required this.user});

  @override
  State<CustomDanceSelectionScreen> createState() => _CustomDanceSelectionScreenState();
}

class _CustomDanceSelectionScreenState extends State<CustomDanceSelectionScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _customDances = [];
  bool _isLoading = true;
  String _errorMessage = '';

  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    _loadCustomDances();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadCustomDances() async {
    try {
      final result = await ApiService.getCustomDances(widget.user['id'].toString());

      if (result['status'] == 'success') {
        setState(() {
          _customDances = result['dances'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load custom dances';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading custom dances: $e';
        _isLoading = false;
      });
    }
  }

  void _deleteCustomDance(Map<String, dynamic> dance) async {
    // Show confirmation dialog
    bool? shouldDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1D054A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 2),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Delete Dance',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            'Delete "${dance['name'] ?? 'Unnamed Dance'}"? This cannot be undone.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.cyanAccent,
              ),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'DELETE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      try {
        // Call API to delete the dance
        final result = await ApiService.deleteCustomDance(dance['id'].toString());

        if (result['status'] == 'success') {
          // Remove from local list
          setState(() {
            _customDances.removeWhere((item) => item['id'] == dance['id']);
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('"${dance['name']}" deleted'),
                ],
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        } else {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red,
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Delete failed: ${result['message']}'),
                ],
              ),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Error: ${e.toString()}'),
              ],
            ),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildDanceCard(Map<String, dynamic> dance, int index) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            elevation: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF2D1070).withOpacity(0.9),
                    Color(0xFF4A1DA3).withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.2),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.cyanAccent.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Dance Icon
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Dance Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dance Name
                          Text(
                            dance['name'] ?? 'Unnamed Dance',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),

                          // Dance Description
                          Text(
                            dance['description']?.isNotEmpty == true
                                ? dance['description']
                                : 'No description provided',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.8),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),

                          // Chips Row
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            children: [
                              _buildInfoChip(
                                Icons.calendar_today,
                                _formatDate(dance['created_at']),
                                Colors.purpleAccent,
                              ),
                              _buildInfoChip(
                                Icons.auto_awesome,
                                'Custom Routine',
                                Colors.cyanAccent,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Delete Button
                    Tooltip(
                      message: 'Delete this dance',
                      child: Material(
                        borderRadius: BorderRadius.circular(20),
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _deleteCustomDance(dance),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.redAccent.withOpacity(0.8),
                                  Colors.red.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.redAccent.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                              border: Border.all(
                                color: Colors.redAccent.withOpacity(0.6),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Widget _buildEmptyState() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2D1070).withOpacity(0.9),
                Color(0xFF4A1DA3).withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 3,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: Colors.cyanAccent.withOpacity(0.4),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.library_music_outlined,
                size: 70,
                color: Colors.cyanAccent.withOpacity(0.7),
              ),
              const SizedBox(height: 20),
              const Text(
                'NO CUSTOM DANCES',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Start creating your own dance routines to see them here',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text(
                    'CREATE DANCE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2D1070).withOpacity(0.9),
                Color(0xFF4A1DA3).withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 3,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(
              color: Colors.redAccent.withOpacity(0.4),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: Colors.redAccent.withOpacity(0.8),
              ),
              const SizedBox(height: 20),
              const Text(
                'LOADING ERROR',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _loadCustomDances,
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                  label: const Text(
                    'TRY AGAIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'MY CUSTOM DANCES',
          style: TextStyle(
            color: Colors.cyanAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(2, 2),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          Tooltip(
            message: 'Refresh',
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: Colors.cyanAccent, size: 22),
              onPressed: _isLoading ? null : _loadCustomDances,
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0523), Color(0xFF1D054A), Color(0xFF2D1070)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background decorative elements
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.purple.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.cyan.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: _isLoading
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                      strokeWidth: 4,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading dances...',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
                  : RefreshIndicator(
                backgroundColor: const Color(0xFF2D1070),
                color: Colors.cyanAccent,
                onRefresh: _loadCustomDances,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 20, bottom: 20),
                  child: Column(
                    children: [
                      if (_errorMessage.isNotEmpty)
                        _buildErrorState()
                      else if (_customDances.isEmpty)
                        _buildEmptyState()
                      else
                        ..._customDances.asMap().entries.map(
                              (entry) => _buildDanceCard(entry.value, entry.key),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}