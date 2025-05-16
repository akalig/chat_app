import 'dart:async';
import 'dart:convert';
import 'package:chat_app/database/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class HomePage extends StatefulWidget {
  final String chatId;
  final String chatName;

  const HomePage({
    super.key,
    required this.chatId,
    required this.chatName,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late WebSocketChannel _channel;
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  String? _currentUserId;
  String? _username;
  final ScrollController _scrollController = ScrollController();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _loadUserData();
    await _loadInitialMessages();
    _connectToWebSocket();
  }

  Future<void> _loadInitialMessages() async {
    try {
      final messages = await _dbHelper.getChatMessages(widget.chatId);
      print('Get Messages: $messages');

      if (mounted) {
        setState(() {
          _messages.addAll(messages.map((msg) => _formatMessage(msg)));
        });
      }

      print('Received Messages: $_messages');
      _scrollToBottom();
    } catch (e) {
      print('Error loading messages: $e');
    }
  }

  // In the _formatMessage method:
  Map<String, dynamic> _formatMessage(Map<String, dynamic> msg) {
    return {
      'id': msg['id'],
      'content': msg['content'],
      'sender_id': msg['sender_id'],
      'firstname': msg['firstname'],
      'lastname': msg['lastname'],
      // Convert DateTime to ISO String
      'sent_at': (msg['sent_at'] as DateTime).toIso8601String(),
      'is_me': msg['sender_id'] == _currentUserId,
    };
  }

// In the _handleIncomingMessage method:
  void _handleIncomingMessage(Map<String, dynamic> message) {
    if (!mounted) return;

    setState(() {
      _messages.add({
        'id': message['id'],
        'content': message['content'],
        'sender_id': message['sender_id'],
        'firstname': message['firstname'],
        'lastname': message['lastname'],
        // Ensure 'sent_at' is a string (adjust if server sends DateTime)
        'sent_at': message['sent_at'].toString(),
        'is_me': message['sender_id'] == _currentUserId,
      });
    });
    _scrollToBottom();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('userId');
      _username = prefs.getString('username');
    });
  }

  // Modify _connectToWebSocket():
  void _connectToWebSocket() {
    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('ws://10.0.2.2:8080/ws'),
      );

      // Send authentication first
      _channel.sink.add(json.encode({
        'type': 'auth',
        'userId': _currentUserId,
        'chatId': widget.chatId
      }));

      _channel.stream.listen(
            (message) {
          final decoded = json.decode(message);
          if (decoded['type'] == 'message') {
            _handleIncomingMessage(decoded);
          } else if (decoded['type'] == 'history') {
            _handleHistory(decoded['messages']);
          }
        },
        onError: (error) => _handleWebSocketError(error),
        onDone: () => _handleWebSocketDisconnect(),
      );
    } catch (e) {
      _showConnectionError();
      _reconnectWebSocket();
    }
  }

// Add history handler:
  void _handleHistory(List<dynamic> messages) {
    if (!mounted) return;

    setState(() {
      _messages.clear();
      _messages.addAll(messages.map((msg) => _formatMessage({
        'id': msg['id'],
        'content': msg['content'],
        'sender_id': msg['sender_id'],
        'firstname': msg['firstname'],
        'lastname': msg['lastname'],
        'sent_at': msg['sent_at']
      })));
    });
    _scrollToBottom();
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final tempMessageId = DateTime.now().millisecondsSinceEpoch.toString();
    final messageContent = _messageController.text;

    // Add message optimistically
    setState(() {
      _messages.add({
        'id': tempMessageId,
        'content': messageContent,
        'sender_id': _currentUserId,
        'is_me': true,
        'sent_at': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    try {
      final messageId = await _dbHelper.saveMessage(
        widget.chatId,
        _currentUserId!,
        messageContent,
      );

      await _dbHelper.updateChatLastMessage(widget.chatId, messageId!);

      _channel.sink.add(json.encode({
        'type': 'message',
        'chat_id': widget.chatId,
        'sender_id': _currentUserId,
        'content': messageContent,
        'timestamp': DateTime.now().toIso8601String(),
      }));

      // Update message with real ID
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == tempMessageId);
        if (index != -1) _messages[index]['id'] = messageId;
      });

    } catch (e) {
      // Remove optimistic message on error
      setState(() {
        _messages.removeWhere((m) => m['id'] == tempMessageId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }

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

  void _handleWebSocketError(dynamic error) {
    print('WebSocket error: $error');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection error. Trying to reconnect...'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    _reconnectWebSocket();
  }

  void _handleWebSocketDisconnect() {
    print('WebSocket connection closed');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection lost. Reconnecting...'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    _reconnectWebSocket();
  }

  void _showConnectionError() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect to server'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _reconnectWebSocket() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        print('Attempting WebSocket reconnection...');
        _connectToWebSocket();
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
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatName),
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
                    margin: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
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
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
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
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
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