// DELETE THIS ENTIRE SECTION FROM gameplay_screen.dart
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://192.168.1.113/dancing";

  // LOGIN
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login.php"),
      body: jsonEncode({'email': email, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
  }











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
          throw Exception('Unexpected response format');
        }
      } else {
        throw Exception('Failed to load leaderboard. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Leaderboard error: $e');
      rethrow;
    }
  }

  // UPDATE USER LEVEL
  static Future<Map<String, dynamic>> updateUserLevel(String userId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/update_level.php"),
        body: jsonEncode({
          'user_id': userId,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Error updating level: $e");
      return {'status': 'error', 'message': 'Network error'};
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
    final response = await http.post(
      Uri.parse("$baseUrl/check_room_status.php"),
      body: jsonEncode({'room_code': roomCode}),
      headers: {'Content-Type': 'application/json'},
    );
    return jsonDecode(response.body);
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
}