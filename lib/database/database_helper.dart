import 'dart:typed_data';
import 'package:postgres/postgres.dart';
import 'dart:convert';

class DatabaseHelper {
  PostgreSQLConnection? _connection;

  // Connect to the database
  Future<void> connect() async {
    try {
      // If there's an existing connection, close it
      if (_connection != null && !_connection!.isClosed) {
        await _connection!.close();
      }

      // Create a new connection
      _connection = PostgreSQLConnection(
        '192.168.1.160',
        5432,
        'chat_application',
        username: 'postgres',
        password: 'admin',
        timeoutInSeconds: 15,
      );

      await _connection!.open();
      print('Connected to the database');
    } catch (e) {
      print('Error connecting to the database: $e');
      rethrow;
    }
  }

  // Authenticate User Account
  Future<Map<String, dynamic>?> authenticateUser(String username, String password) async {
    try {
      List<int> bytes = utf8.encode(password);
      String base64Encoded = base64.encode(bytes);

      final result = await _connection!.query(
        "SELECT id, account_apppassword FROM users_account WHERE account_username = '$username' ORDER BY id DESC",
      );

      if (result.isNotEmpty) {
        final user = result.first.toColumnMap();
        if (user['account_apppassword'] == base64Encoded) {
          print("User: $user");
          return user;
        } else {
          return null;
        }
      }

    } catch (e) {
      print('Error during authentication: $e');
      return null;
    }
    return null;
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
      await connect();

      final result = await _connection!.transaction((ctx) async {
        // Insert into users table
        final userResult = await ctx.query(
          "INSERT INTO users (firstname, lastname, emailaddress) "
              "VALUES (@firstName, @lastName, @email) "
              "RETURNING id",
          substitutionValues: {
            'firstName': firstName,
            'lastName': lastName,
            'email': email,
          },
        );

        final userId = userResult.first[0].toString();  // just keep it as string

        // Encode password
        List<int> bytes = utf8.encode(password);
        String base64Encoded = base64.encode(bytes);

        // Insert into users_account table
        await ctx.query(
          "INSERT INTO users_account (user_id, account_username, account_apppassword) "
              "VALUES (@userId, @username, @encodedPassword)",
          substitutionValues: {
            'userId': userId,
            'username': username,
            'encodedPassword': base64Encoded,
          },
        );

        return userId;
      });

      return result;
    } catch (e) {
      print('Error during registration: $e');
      return null;
    } finally {
      await close();
    }
  }

  // Check is Username is Taken
  Future<bool> isUsernameTaken(String username) async {
    try {
      await connect();
      final result = await _connection!.query(
        "SELECT COUNT(*) FROM users_account WHERE account_username = @username",
        substitutionValues: {'username': username},
      );
      return (result.first[0] as int) > 0;
    } catch (e) {
      print('Error checking username: $e');
      return true; // Assume taken if error occurs
    } finally {
      await close();
    }
  }

  // Close the database connection
  Future<void> close() async {
    try {
      await _connection!.close();
      print('Database connection closed');
    } catch (e) {
      print('Error closing database connection: $e');
    }
  }

}