import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat_app/database/database_helper.dart';
import 'package:chat_app/pages/home_page.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  List<Map<String, dynamic>> _chats = [];
  String? _currentUserId;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadChats();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('userId');
    });
  }

  Future<void> _loadChats() async {
    if (_currentUserId == null) return;

    try {
      final chats = await _dbHelper.getUserChats(_currentUserId!);
      setState(() {
        _chats = chats.where((chat) => chat['id'] != null).toList();
      });
    } catch (e) {
      print('Error loading chats: $e');
      // Show error to user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error loading chats')),
      );
    }
  }

  Future<void> _createNewChat() async {
    try {
      final users = await _dbHelper.getAllUsersExceptCurrent(_currentUserId!);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('New Chat'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  title: Text('${user['firstname']} ${user['lastname']}'),
                  onTap: () async {
                    final chatId = await _dbHelper.createChat(
                      [_currentUserId!, user['id']],
                      'Direct Chat',
                    );

                    if (chatId != null) {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomePage(
                            chatId: chatId,
                            chatName: '${user['firstname']} ${user['lastname']}',
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: ListView.builder(
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return ListTile(
            title: Text(chat['chat_name'] ?? chat['other_user_name']),
            subtitle: Text(chat['last_message'] ?? 'No messages yet'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(
                    chatId: chat['id'],
                    chatName: chat['chat_name'] ?? chat['other_user_name'],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: _createNewChat,
      ),
    );
  }
}