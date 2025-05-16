// chats_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chat_app/pages/home_page.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  List<Map<String, dynamic>> _chats = [];
  String? _currentUserId;

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
    // In a real app, you would fetch this from your database
    setState(() {
      _chats = [
        {
          'id': 1,
          'name': 'John Doe',
          'last_message': 'Hey, how are you?',
          'recipient_id': 2,
        },
        {
          'id': 2,
          'name': 'Jane Smith',
          'last_message': 'See you tomorrow!',
          'recipient_id': 3,
        }
      ];
    });
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
            title: Text(chat['name']),
            subtitle: Text(chat['last_message']),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(
                    chatId: chat['id'],
                    recipientId: chat['recipient_id'],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}