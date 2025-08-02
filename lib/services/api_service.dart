import 'dart:convert';
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
