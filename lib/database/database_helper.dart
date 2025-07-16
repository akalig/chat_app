import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class DatabaseHelper {
  static const String _baseUrl = 'https://api.bael11.shop/chat_app_restful_api/';

  // Authenticate User Account
  Future<Map<String, dynamic>?> authenticateUser(String username, String password) async {
    try {

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/authenticate.php'),
        body: jsonEncode({
          'username': username,
          'password': password
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data != null ? Map<String, dynamic>.from(data) : null;
      }
      return null;
    } catch (e) {
      print('Auth error: $e');
      return null;
    }
  }

  // Register User
  Future<String?> registerUser({
    required String firstName,
    required String lastName,
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register.php'),
        body: jsonEncode({
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'username': username,
          'password': password
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['userId'].toString(); // Ensure we return as String
        }
      }
      return null;
    } catch (e) {
      print('Registration error: $e');
      return null;
    }
  }

  // Check if Username is Taken
  Future<bool> isUsernameTaken(String username) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/check_username.php'),
        body: jsonEncode({'username': username}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isTaken'] ?? true;
      }
      return true;
    } catch (e) {
      print('Error checking username: $e');
      return true;
    }
  }

  // Validate User Exists
  Future<bool> validateUserExists(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/validate.php'),
        body: jsonEncode({'userId': userId}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['exists'] ?? false;
      }
      return false;
    } catch (e) {
      print('Validation error: $e');
      return false;
    }
  }

  // Get User Chats
  Future<List<Map<String, dynamic>>> getUserChats(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chats/list.php'),
        body: jsonEncode({'userId': userId}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting user chats: $e');
      return [];
    }
  }

  // Create Chat
  Future<String?> createChat(List<String> participantIds, String chatName) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chats/create.php'),
        body: jsonEncode({
          'participantIds': participantIds,
          'chatName': chatName
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['chatId'];
      }
      return null;
    } catch (e) {
      print('Error creating chat: $e');
      return null;
    }
  }

  // Get All Users Except Current
  Future<List<Map<String, dynamic>>> getAllUsersExceptCurrent(String currentUserId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/all_except.php'),
        body: jsonEncode({'currentUserId': currentUserId}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

}