// DELETE THIS ENTIRE SECTION FROM gameplay_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://192.168.1.9/dancing";

  // LOGIN
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login.php"),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    final result = jsonDecode(response.body);

    // Add default values for backward compatibility
    result['requires_verification'] = result['requires_verification'] ?? false;
    result['email'] = result['email'] ?? email;

    return result;
  }


  // LEADERBOARD
// LEADERBOARD
  static Future<List<dynamic>> getLeaderboard(String userId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/leaderboard.php"),
        body: jsonEncode({'user_id': userId}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // Handle both array and error object responses
        if (decoded is List) {
          return decoded;
        } else if (decoded is Map && decoded.containsKey('error')) {
          throw Exception(decoded['error']);
        } else {
          // If we get something unexpected, return empty list
          return [];
        }
      } else {
        throw Exception('Failed to load leaderboard. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Leaderboard error: $e');
      // Return empty list instead of throwing to prevent app crash
      return [];
    }
  }




  // In your ApiService class
  static Future<Map<String, dynamic>> updateUserXP(String userId, int xpGained) async {
    final response = await http.post(
      Uri.parse('$baseUrl/update_level.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'xp_gained': xpGained}),
    );
    return jsonDecode(response.body);
  }

  // In your ApiService class
  static Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/get_user_stats.php"),
        body: jsonEncode({'user_id': userId}),
        headers: {'Content-Type': 'application/json'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Error getting user stats: $e");
      return {'status': 'error', 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> updateGameStats(String userId, int score) async {
    final response = await http.post(
      Uri.parse('$baseUrl/update_game_stats.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'score': score}),
    );
    return jsonDecode(response.body);
  }

  // QUICKPLAY - Find or create match with random dance
// QUICKPLAY - Find or create match

  static Future<Map<String, dynamic>> quickPlayMatch(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/quickplay_match.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId}),
      ).timeout(const Duration(seconds: 10));

      print('QuickPlay Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result;
      } else {
        return {
          'status': 'error',
          'message': 'Server error: ${response.statusCode}'
        };
      }
    } on TimeoutException {
      return {'status': 'error', 'message': 'Request timeout'};
    } on http.ClientException catch (e) {
      return {'status': 'error', 'message': 'Network error: ${e.message}'};
    } catch (e) {
      return {'status': 'error', 'message': 'Unexpected error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> cancelQuickPlay(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cancel_quickplay.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Failed to cancel quick play'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // REGISTER
  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/register.php"),
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

// Add these to your ApiService class

  static Future<Map<String, dynamic>> verifyAccount(String email, String verificationCode) async {
    final response = await http.post(
      Uri.parse("$baseUrl/verify_account.php"),
      body: jsonEncode({
        'email': email,
        'verification_code': verificationCode,
      }),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> resendVerification(String email) async {
    final response = await http.post(
      Uri.parse("$baseUrl/resend_verification.php"),
      body: jsonEncode({'email': email}),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  // CREATE ROOM
  static Future<Map<String, dynamic>> createRoom(String playerId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/create_room.php"),
      body: jsonEncode({'player1_id': playerId}),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  // JOIN ROOM
  static Future<Map<String, dynamic>> joinRoom(String roomCode, String playerId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/join_room.php"),
      body: jsonEncode({'room_code': roomCode, 'player2_id': playerId}),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }





  // CHECK ROOM STATUS
  static Future<Map<String, dynamic>> checkRoomStatus(String roomCode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/check_room_status.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'room_code': roomCode}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Failed to check room status'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // SELECT DANCE
  static Future<Map<String, dynamic>> selectDance(String roomCode, int danceId) async {
    final response = await http.post(
      Uri.parse("$baseUrl/select_dance.php"),
      body: jsonEncode({'room_code': roomCode, 'dance_id': danceId}),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getSelectedDance(String roomCode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/room/$roomCode/selected-dance'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Failed to get selected dance'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> selectRandomDance(String roomCode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/room/$roomCode/select-random-dance'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Failed to select random dance'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

}


