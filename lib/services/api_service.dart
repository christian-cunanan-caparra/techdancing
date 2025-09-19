import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "https://admin-beatbreaker.site/flutter";


  // In ApiService class




  static Future<List<dynamic>> getAnnouncements() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/announcements.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['announcements'] ?? [];
      }
      return [];
    } catch (e) {
      print('Error fetching announcements: $e');
      return [];
    }
  }

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


  //multi selectdance

  // Multiplayer dance selection
  static Future<Map<String, dynamic>> selectRandomDanceMulti(String roomCode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/select-dance-multi'),
      body: {'room_code': roomCode},
    );

    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> selectDanceMulti(String roomCode, int danceId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/select-dance-multi'),
      body: {
        'room_code': roomCode,
        'dance_id': danceId.toString(),
      },
    );

    return json.decode(response.body);
  }
  
//end


  static Future<Map<String, dynamic>> setStartTime(String roomCode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/set_start_time.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'room_code': roomCode}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Failed to set start time'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getStartTime(String roomCode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get_start_time.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'room_code': roomCode}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Failed to get start time'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> setReadyStatus(String roomCode, String playerId, bool isReady) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/set_ready_status.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'room_code': roomCode,
          'player_id': playerId,
          'is_ready': isReady
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Failed to set ready status'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> checkBothReady(String roomCode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/check_both_ready.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'room_code': roomCode}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Failed to check ready status'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> resetReadyStatus(String roomCode) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset_ready_status.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'room_code': roomCode}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Failed to reset ready status'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  // In your ApiService class
  static Future<Map<String, dynamic>> createCustomDance(String userId, String name, String description) async {
    final response = await http.post(
      Uri.parse('$baseUrl/create_custom_dance.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'name': name,
        'description': description,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addCustomStep(
      String danceId,
      int stepNumber,
      String name,
      String description,
      int duration,
      String lyrics,
      Map<String, dynamic> poseData
      ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/add_custom_step.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'dance_id': danceId,
        'step_number': stepNumber,
        'name': name,
        'description': description,
        'duration': duration,
        'lyrics': lyrics,
        'pose_data': poseData,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCustomDances(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/get_custom_dances.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getCustomDanceSteps(String danceId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/get_custom_dance_steps.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'dance_id': danceId}),
    );
    return jsonDecode(response.body);
  }


  // Get all available achievements
  static Future<Map<String, dynamic>> getAchievements() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/achievements.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'status': 'error', 'message': 'Failed to load achievements'};
      }
    } catch (e) {
      debugPrint('Error fetching achievements: $e');
      return {'status': 'error', 'message': 'Network error'};
    }
  }

// Get user's achievement progress
  static Future<Map<String, dynamic>> getUserAchievements(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/user_achievements.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'status': 'error', 'message': 'Failed to load user achievements'};
      }
    } catch (e) {
      debugPrint('Error fetching user achievements: $e');
      return {'status': 'error', 'message': 'Network error'};
    }
  }


  // Check and update user achievements
// In your ApiService class, update the updateUserAchievements method
  static Future<Map<String, dynamic>> updateUserAchievements(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_user_achievements.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        // Add debug logging
        print('Achievement update result: $result');

        return result;
      } else {
        return {'status': 'error', 'message': 'Failed to update achievements'};
      }
    } catch (e) {
      debugPrint('Error updating achievements: $e');
      return {'status': 'error', 'message': 'Network error'};
    }
  }
}