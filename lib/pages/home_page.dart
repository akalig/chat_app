import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HomePage extends StatefulWidget {
  final int chatId;
  final int recipientId;

  const HomePage({
    super.key,
    required this.chatId,
    required this.recipientId,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late WebSocketChannel _channel;
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  String? _currentUserId;
  String? _username;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _connectToWebSocket();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('userId');
      _username = prefs.getString('username');
    });
  }

  void _connectToWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://192.168.1.160:8080/ws'),
      );

      // Authenticate with the server
      _channel.sink.add(json.encode({
        'type': 'auth',
        'userId': _currentUserId,
        'chatId': widget.chatId,
      }));

      _channel.stream.listen(
            (message) {
          final decoded = json.decode(message);

          if (decoded['type'] == 'history') {
            setState(() {
              _messages.addAll(decoded['messages']);
            });
          }
          else if (decoded['type'] == 'message') {
            setState(() {
              _messages.add({
                ...decoded,
                'is_me': decoded['sender_id'] == _currentUserId,
              });
            });
          }

          _scrollToBottom();
        },
        onError: (error) => print('WebSocket error: $error'),
        onDone: () => print('WebSocket connection closed'),
      );
    } catch (e) {
      print('Error connecting to WebSocket: $e');
    }
  }

  void _sendMessage() {
    if (_messageController.text.isEmpty) return;

    final message = {
      'type': 'message',
      'chat_id': widget.chatId,
      'sender_id': _currentUserId,
      'recipient_id': widget.recipientId,
      'content': _messageController.text,
      'timestamp': DateTime.now().toIso8601String(),
    };

    _channel.sink.add(json.encode(message));
    _messageController.clear();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _channel.sink.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logoutDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message['is_me'] ?? false;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue[200] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Text(
                            '${message['firstname']} ${message['lastname']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        Text(message['content']),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(message['timestamp'] ?? message['sent_at']),
                          style: const TextStyle(fontSize: 10, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  void _logoutDialog(BuildContext context) {
    // Your existing logout implementation
  }
}