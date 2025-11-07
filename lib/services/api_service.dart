import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "https://admin-beatbreaker.site/flutter";

  static Future<Map<String, dynamic>> sendForceLogoutCode(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/send_force_logout_code.php"),
        body: jsonEncode({'email': email}),
        headers: {'Content-Type': 'application/json'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> submitGameScore(
      String roomCode,
      String userId,
      int score
      ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/submit_game_score.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'room_code': roomCode,
          'user_id': userId,
          'score': score,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> checkPlayerRoomStatus(
      String roomCode,
      String userId
      ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/check_player_roomstatus.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'room_code': roomCode,
          'user_id': userId,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> verifyForceLogoutCode(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/verify_force_logout_code.php"),
        body: jsonEncode({
          'email': email,
          'code': code,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }


  static Future<Map<String, dynamic>> forceLogout(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/force_logout.php"),
        body: jsonEncode({'email': email}),
        headers: {'Content-Type': 'application/json'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/forgot_password.php"),
        body: jsonEncode({'email': email}),
        headers: {'Content-Type': 'application/json'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> resetPassword(String email, String newPassword, String resetToken) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/reset_password.php"),
        body: jsonEncode({
          'email': email,
          'new_password': newPassword,
          'reset_token': resetToken
        }),
        headers: {'Content-Type': 'application/json'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<List<dynamic>> getAnnouncements() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/announcements.php'),
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
    result['requires_verification'] = result['requires_verification'] ?? false;
    result['email'] = result['email'] ?? email;
    result['already_logged_in'] = result['already_logged_in'] ?? false;
    return result;
  }

  static Future<Map<String, dynamic>> getLeaderboard(String userId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/leaderboard.php"),
        body: jsonEncode({'user_id': userId}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        debugPrint('Leaderboard API response type: ${decoded.runtimeType}');
        debugPrint('Leaderboard API response: $decoded');

        if (decoded is Map) {
          final Map<String, dynamic> result = {};
          decoded.forEach((key, value) {
            result[key.toString()] = value;
          });

          if (!result.containsKey('leaderboard') || result['leaderboard'] is! List) {
            result['leaderboard'] = [];
          }
          if (!result.containsKey('season_info') || result['season_info'] is! Map) {
            result['season_info'] = {};
          }
          if (!result.containsKey('previous_season')) {
            result['previous_season'] = null;
          }

          return result;
        }
        else if (decoded is List) {

          return {
            'leaderboard': decoded,
            'season_info': {
              'season_number': 1,
              'season_name': 'Season 1',
              'days_until_end': 245,
              'is_active': true
            },
            'previous_season': null
          };
        }
        else if (decoded is bool) {

          debugPrint('Received boolean response: $decoded');
          return {
            'leaderboard': [],
            'season_info': {
              'season_number': 1,
              'season_name': 'Season 1',
              'days_until_end': 245,
              'is_active': true
            },
            'previous_season': null
          };
        }
        else if (decoded == null) {

          debugPrint('Received null response');
          return {
            'leaderboard': [],
            'season_info': {
              'season_number': 1,
              'season_name': 'Season 1',
              'days_until_end': 245,
              'is_active': true
            },
            'previous_season': null
          };
        }
        else {

          debugPrint('Unexpected response type: ${decoded.runtimeType}');
          return {
            'leaderboard': [],
            'season_info': {
              'season_number': 1,
              'season_name': 'Season 1',
              'days_until_end': 245,
              'is_active': true
            },
            'previous_season': null
          };
        }
      } else {
        debugPrint('Leaderboard API error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load leaderboard. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Leaderboard error: $e');
      rethrow;
    }
  }

  static Future<void> endCurrentSeason() async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/leaderboard.php"),
        body: jsonEncode({'action': 'end_season'}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == 'success') {
          debugPrint('Season ended successfully');
        } else {
          throw Exception(result['message'] ?? 'Failed to end season');
        }
      } else {
        throw Exception('Failed to end season. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('End season error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getUserPreviousSeason(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/user/$userId/previous-season'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Previous season API raw response: $data');
        return data;
      } else {
        debugPrint('Previous season API error: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        throw Exception('Failed to load previous season data. Status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Previous season network error: $e');
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> updateUserXP(String userId, int xpGained) async {
    final response = await http.post(
      Uri.parse('$baseUrl/update_level.php'), headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'xp_gained': xpGained}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final response = await http.post(Uri.parse("$baseUrl/get_user_stats.php"),
        body: jsonEncode({'user_id': userId}), headers: {'Content-Type': 'application/json'},
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Error getting user stats: $e");
      return {'status': 'error', 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> updateGameStats(String userId, int score) async {
    final response = await http.post(Uri.parse('$baseUrl/update_game_stats.php'),
      headers: {'Content-Type': 'application/json'}, body: jsonEncode({'user_id': userId, 'score': score}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> quickPlayMatch(String userId) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/quickplay_match.php'),
        headers: {'Content-Type': 'application/json'}, body: json.encode({'user_id': userId}),
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


  static Future<Map<String, dynamic>> checkRoomStatusWithUser(String roomCode, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/check_room_status.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'room_code': roomCode, 'user_id': userId}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'error', 'message': 'Server error: ${response.statusCode}'};
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
      final response = await http.post(Uri.parse('$baseUrl/cancel_quickplay.php'),
        headers: {'Content-Type': 'application/json'}, body: json.encode({'user_id': userId}),
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

  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await http.post(Uri.parse("$baseUrl/register.php"),
      body: jsonEncode({'name': name, 'email': email, 'password': password}), headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> verifyAccount(String email, String verificationCode) async {
    final response = await http.post(Uri.parse("$baseUrl/verify_account.php"),
      body: jsonEncode({'email': email, 'verification_code': verificationCode,
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

  static Future<Map<String, dynamic>> createRoom(String playerId) async {
    final response = await http.post(Uri.parse("$baseUrl/create_room.php"),
      body: jsonEncode({'player1_id': playerId}), headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> joinRoom(String roomCode, String playerId) async {
    final response = await http.post(Uri.parse("$baseUrl/join_room.php"),
      body: jsonEncode({'room_code': roomCode, 'player2_id': playerId}), headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> checkRoomStatus(String roomCode) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/check_room_status.php'),
        headers: {'Content-Type': 'application/json'}, body: json.encode({'room_code': roomCode}),
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

  static Future<Map<String, dynamic>> selectDance(String roomCode, int danceId) async {
    final response = await http.post(Uri.parse("$baseUrl/select_dance.php"),
      body: jsonEncode({'room_code': roomCode, 'dance_id': danceId}), headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getSelectedDance(String roomCode) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/room/$roomCode/selected-dance'), headers: {'Content-Type': 'application/json'},
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

  static Future<Map<String, dynamic>> saveRhythmScore(
      String userId,
      int score,
      int maxCombo,
      int arrowsHit,
      String difficulty,
      ) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/api/rhythm/save-score'), headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'score': score,
          'max_combo': maxCombo,
          'arrows_hit': arrowsHit,
          'difficulty': difficulty,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      throw Exception('Failed to save rhythm score: $e');
    }
  }

  static Future<Map<String, dynamic>> logout(String userId, String sessionToken) async {
    final response = await http.post(Uri.parse("$baseUrl/logout.php"),
      body: jsonEncode({
        'user_id': userId,
        'session_token': sessionToken,
      }),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> checkLoginStatus(String userId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/check_login_status.php"),
        body: jsonEncode({'user_id': userId}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'status': 'error', 'message': 'Failed to check login status'};
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }


  static Future<Map<String, dynamic>> evictLog(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/evict_log.php"), // Changed filename
        body: jsonEncode({'email': email}),
        headers: {'Content-Type': 'application/json'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }


  static Future<Map<String, dynamic>> selectRandomDance(String roomCode) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/room/$roomCode/select-random-dance'), headers: {'Content-Type': 'application/json'},
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

  static Future<Map<String, dynamic>> selectRandomDanceMulti(String roomCode) async {
    final response = await http.post(Uri.parse('$baseUrl/select-dance-multi'), body: {'room_code': roomCode},
    );
    return json.decode(response.body);
  }

  static Future<Map<String, dynamic>> selectDanceMulti(String roomCode, int danceId) async {
    final response = await http.post(Uri.parse('$baseUrl/select-dance-multi'),
      body: {
        'room_code': roomCode,
        'dance_id': danceId.toString(),
      },
    );
    return json.decode(response.body);
  }

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

  static Future<Map<String, dynamic>> deleteCustomDance(String danceId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delete_custom_dance.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'dance_id': danceId,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
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
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get_custom_dances.php'),
        body: {'user_id': userId},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'status': 'error', 'message': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getCustomDanceSteps(String danceId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/get_custom_dance_steps.php'),
        body: {'dance_id': danceId},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'status': 'error', 'message': 'HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }


  static Future<Map<String, dynamic>> getMultiplayerResults(String roomCode, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/multiplayer_results.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'room_code': roomCode,
          'user_id': userId,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> waitForOpponentScore(String roomCode, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/wait_opponent_score.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'room_code': roomCode,
          'user_id': userId,
        }),
      ).timeout(const Duration(seconds: 30));

      return jsonDecode(response.body);
    } on TimeoutException {
      return {'status': 'timeout', 'message': 'Waiting for opponent timed out'};
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> submitMultiplayerGameScore(
      String roomCode,
      String userId,
      int score,
      int totalScore,
      int percentage,
      int xpGained,
      List<int> stepScores,
      List<Map<String, dynamic>> danceSteps,
      ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/submit_game_score.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'room_code': roomCode,
          'user_id': userId,
          'score': score,
          'total_score': totalScore,
          'percentage': percentage,
          'xp_gained': xpGained,
          'step_scores': stepScores,
          'dance_steps': danceSteps,
        }),
      );

      return jsonDecode(response.body);
    } catch (e) {
      return {'status': 'error', 'message': 'Network error: $e'};
    }
  }

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

  static Future<Map<String, dynamic>> updateUserAchievements(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/update_user_achievements.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
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