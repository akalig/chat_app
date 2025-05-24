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
        // '192.168.1.34',
        '10.0.2.2',
        5432,
        'chat_application',
        username: 'postgres',
        password: 'postgres',
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
      await connect();
      final encodedPassword = base64.encode(utf8.encode(password));

      final result = await _connection!.query('''
      SELECT ua.user_id::text, u.emailaddress 
      FROM users_account ua
      JOIN users u ON ua.user_id = u.id
      WHERE ua.account_username = @username 
        AND ua.account_password = @encodedPassword
    ''', substitutionValues: {
        'username': username,
        'encodedPassword': encodedPassword,
      });

      if (result.isEmpty) return null;

      final userData = result.first.toColumnMap();
      return {
        'user_id': userData['user_id']?.toString(),
        'email': userData['emailaddress']?.toString(),
      };
    } catch (e) {
      print('Auth error: $e');
      return null;
    } finally {
      await close();
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
      await connect();

      return await _connection!.transaction((ctx) async {
        // 1. Insert into users table
        final userResult = await ctx.query('''
        INSERT INTO users (firstname, lastname, emailaddress)
        VALUES (@firstName, @lastName, @email)
        RETURNING id
      ''', substitutionValues: {
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
        });

        final userId = userResult.first[0].toString();

        // 2. Encode password
        final encodedPassword = base64.encode(utf8.encode(password));

        // 3. Insert into users_account
        await ctx.query('''
        INSERT INTO users_account (user_id, account_username, account_password)
        VALUES (@userId, @username, @encodedPassword)
      ''', substitutionValues: {
          'userId': userId,
          'username': username,
          'encodedPassword': encodedPassword,
        });

        return userId;
      });
    } catch (e) {
      print('Registration error: $e');
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

  Future<bool> validateUserExists(String userId) async {
    try {
      await connect();
      final result = await _connection!.query(
        'SELECT 1 FROM users WHERE id = @userId',
        substitutionValues: {'userId': userId},
      );
      return result.isNotEmpty;
    } catch (e) {
      print('Validation error: $e');
      return false;
    } finally {
      await close();
    }
  }

  Future<List<Map<String, dynamic>>> getUserChats(String userId) async {
    try {
      await connect();
      final result = await _connection!.query('''
      SELECT DISTINCT ON (c.id) c.id, c.chat_name, 
        u.firstname || ' ' || u.lastname as other_user_name,
        m.content as last_message
      FROM chats c
      JOIN chat_users cu ON c.id = cu.chat_id
      JOIN users u ON cu.user_id = u.id
      LEFT JOIN messages m ON c.last_message_id = m.id
      WHERE c.id IN (
        SELECT chat_id FROM chat_users 
        WHERE user_id = @userId
      )
      AND cu.user_id != @userId
      AND c.chat_type = 'direct'
      ORDER BY c.id, m.sent_at DESC
    ''', substitutionValues: {'userId': userId});

      return result.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      print('Error getting user chats: $e');
      return [];
    } finally {
      await close();
    }
  }

  Future<List<Map<String, dynamic>>> getChatParticipants(String chatId) async {
    try {
      await connect();
      final result = await _connection!.query('''
      SELECT user_id FROM chat_users WHERE chat_id = @chatId
    ''', substitutionValues: {'chatId': chatId});

      return result.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      print('Error getting participants: $e');
      return [];
    } finally {
      await close();
    }
  }

  Future<String?> createChat(List<String> participantIds, String chatName) async {
    try {
      await connect();

      // Check for existing direct chat between exactly these participants
      final existingChat = await _findExistingDirectChat(participantIds);
      if (existingChat != null) {
        print('Found existing chat: ${existingChat['id']}');
        return existingChat['id'];
      }

      return await _connection!.transaction((ctx) async {
        // Create new chat
        final chatResult = await ctx.query('''
        INSERT INTO chats (chat_name, chat_type, created_by)
        VALUES (@chatName, 'direct', @createdBy)
        RETURNING id
      ''', substitutionValues: {
          'chatName': chatName,
          'createdBy': participantIds.first,
        });

        final chatId = chatResult.first[0].toString();

        // Add participants
        for (final userId in participantIds) {
          await ctx.query('''
          INSERT INTO chat_users (chat_id, user_id)
          VALUES (@chatId, @userId)
        ''', substitutionValues: {
            'chatId': chatId,
            'userId': userId,
          });
        }

        return chatId;
      });
    } catch (e) {
      print('Error creating chat: $e');
      return null;
    } finally {
      await close();
    }
  }

  Future<Map<String, dynamic>?> _findExistingDirectChat(List<String> participantIds) async {
    try {
      final result = await _connection!.query('''
      SELECT c.id 
      FROM chats c
      JOIN chat_users cu ON c.id = cu.chat_id
      WHERE c.chat_type = 'direct'
        AND cu.user_id IN (@user1, @user2)
      GROUP BY c.id
      HAVING COUNT(DISTINCT cu.user_id) = 2
      LIMIT 1
    ''', substitutionValues: {
        'user1': participantIds[0],
        'user2': participantIds[1],
      });

      return result.isNotEmpty ? result.first.toColumnMap() : null;
    } catch (e) {
      print('Error finding existing chat: $e');
      return null;
    }
  }

  Future<void> updateChatLastMessage(String chatId, String messageId) async {
    try {
      await connect();
      await _connection!.query(
        'UPDATE chats SET last_message_id = @messageId WHERE id = @chatId',
        substitutionValues: {
          'chatId': chatId,
          'messageId': messageId,
        },
      );
    } catch (e) {
      print('Error updating last message: $e');
    } finally {
      await close();
    }
  }

  Future<String?> saveMessage(String chatId, String senderId, String content) async {
    try {
      await connect();
      final result = await _connection!.query('''
      INSERT INTO messages (chat_id, sender_id, content, sent_at)
      VALUES (@chatId, @senderId, @content, NOW())
      RETURNING id
    ''', substitutionValues: {
        'chatId': chatId,
        'senderId': senderId,
        'content': content,
      });

      return result.first[0].toString();
    } catch (e) {
      print('Error saving message: $e');
      return null;
    } finally {
      await close();
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsersExceptCurrent(String currentUserId) async {
    try {
      await connect();
      final result = await _connection!.query('''
      SELECT id, firstname, lastname, emailaddress 
      FROM users
      WHERE id != @currentUserId
    ''', substitutionValues: {'currentUserId': currentUserId});

      return result.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      print('Error getting users: $e');
      return [];
    } finally {
      await close();
    }
  }

  Future<List<Map<String, dynamic>>> getChatMessages(String chatId) async {
    try {
      await connect();
      final result = await _connection!.query('''
      SELECT m.id, m.content, m.sender_id, m.sent_at,
             u.firstname, u.lastname
      FROM messages m
      JOIN users u ON m.sender_id = u.id
      WHERE m.chat_id = @chatId
      ORDER BY m.sent_at ASC
    ''', substitutionValues: {'chatId': chatId});

      return result.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    } finally {
      await close();
    }
  }

  // In DatabaseHelper class
  Future<void> updateMessageStatuses(List<String> messageIds, String status) async {
    try {
      await connect();

      if (messageIds.isEmpty) return;

      // Generate numbered placeholders for IN clause
      final params = List.generate(messageIds.length, (i) => '@id${i + 1}');
      final paramsMap = {for (var i = 0; i < messageIds.length; i++) 'id${i + 1}': messageIds[i]};

      await _connection!.query('''
      UPDATE messages 
      SET status = @status
      WHERE id IN (${params.join(', ')})
    ''', substitutionValues: {
        'status': status,
        ...paramsMap
      });

    } catch (e) {
      print('Error updating message statuses: $e');
      throw Exception('Failed to update message statuses');
    } finally {
      await close();
    }
  }

  Future<void> close() async {
    try {
      await _connection!.close();
      print('Database connection closed');
    } catch (e) {
      print('Error closing database connection: $e');
    }
  }

}