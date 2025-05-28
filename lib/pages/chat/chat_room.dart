import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatRoom extends StatefulWidget {
  final String chatId;
  final String chatName;

  const ChatRoom({
    super.key,
    required this.chatId,
    required this.chatName,
  });

  @override
  State<ChatRoom> createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoom>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late WebSocketChannel _channel;
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  String? _currentUserId;
  String? _username;
  final ScrollController _scrollController = ScrollController();

  final Map<String, Map<String, dynamic>> _typingUsers = {};
  Timer? _typingTimer;
  Timer? _typingDebounce;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  /// Show chats when opened the page
  Future<void> _initializeChat() async {
    print('Initializing chat...');
    await _loadUserData();
    _connectToWebSocket();
  }

  // Handles chat formats
  Map<String, dynamic> _formatMessage(Map<String, dynamic> msg) {
    DateTime sentAt = msg['sent_at'] is String
        ? DateTime.parse(msg['sent_at'])
        : msg['sent_at'] ?? DateTime.now();

    return {
      'id': msg['id'],
      'content': msg['content'],
      'sender_id': msg['sender_id'],
      'firstname': msg['firstname'],
      'lastname': msg['lastname'],
      'sent_at': sentAt.toIso8601String(),
      'is_me': msg['sender_id'] == _currentUserId,
      'status': msg['status'] ?? 'sent', // Add default status
    };
  }

  void _handleIncomingMessage(Map<String, dynamic> message) {
    if (!mounted) return;

    setState(() {
      _messages.add({
        'id': message['id'],
        'content': message['content'],
        'sender_id': message['sender_id'],
        'firstname': message['firstname'],
        'lastname': message['lastname'],
        'sent_at': message['sent_at'].toString(),
        'is_me': message['sender_id'] == _currentUserId,
        'status': message['status'] ?? 'sent', // Add status
      });
    });
    _scrollToBottom();
  }

  // Get User's data
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('userId');
    _username = prefs.getString('username');
    print('Loaded user data: userId=$_currentUserId, username=$_username');
  }

  // Initialization of Web Socket Connection
  void _connectToWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse('ws://10.0.2.2:8080'));
      _channel.sink.add(json.encode({
        'type': 'auth',
        'userId': _currentUserId,
        'chatId': widget.chatId
      }));

      _channel.stream.listen(
            (message) => _handleWebSocketMessage(message),
        onError: _handleWebSocketError,
        onDone: _handleWebSocketDisconnect,
      );
    } catch (e) {
      _showConnectionError();
      _reconnectWebSocket();
    }
  }

  // Handles websocket messages type
  void _handleWebSocketMessage(dynamic message) {
    final decoded = json.decode(message);
    switch (decoded['type']) {
      case 'message':
        _handleIncomingMessage(decoded);
        break;
      case 'history':
        _handleHistory(decoded['messages']);
        break;
      case 'typing':
        _handleTypingIndicator(decoded);
        break;
    }
  }

  // Handles the list of conversations
  void _handleHistory(List<dynamic> messages) {
    if (!mounted) return;

    setState(() {
      _messages.clear();
      _messages.addAll(messages.map((msg) =>
          _formatMessage({
            'id': msg['id'],
            'content': msg['content'],
            'sender_id': msg['sender_id'],
            'firstname': msg['firstname'],
            'lastname': msg['lastname'],
            'sent_at': msg['sent_at'],
            'status': msg['status']
          })));
    });
    _scrollToBottom();
  }

  // Handles sending messages
  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final tempMessageId = DateTime
        .now()
        .millisecondsSinceEpoch
        .toString();
    final messageContent = _messageController.text;

    _scrollToBottom();

    try {
      _channel.sink.add(json.encode({
        'type': 'message',
        'chat_id': widget.chatId,
        'sender_id': _currentUserId,
        'content': messageContent,
        'timestamp': DateTime.now().toIso8601String(),
      }));

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

  // UI interaction for button for scrolling back to bottom
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

  /// Handles Websocket statuses
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

  /// Handles real-time typing indicator
  void _handleTyping(bool isTyping) {
    _typingDebounce?.cancel();

    if (isTyping && _typingTimer == null) {
      _sendTypingEvent(true);
      _typingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        _sendTypingEvent(true);
      });
    } else {
      _typingDebounce = Timer(const Duration(seconds: 2), () {
        _sendTypingEvent(false);
        _typingTimer?.cancel();
        _typingTimer = null;
      });
    }
  }

  void _sendTypingEvent(bool isTyping) {
    _channel.sink.add(json.encode({
      'type': 'typing',
      'chat_id': widget.chatId,  // Make sure this is included
      'sender_id': _currentUserId,
      'is_typing': isTyping
    }));
  }

  void _handleTypingIndicator(Map<String, dynamic> data) {
    if (!mounted) return;

    // Only process typing indicators for the current chat
    if (data['chat_id'] != widget.chatId) return;

    final senderId = data['sender_id']?.toString() ?? 'unknown';
    final firstName = data['firstname']?.toString() ?? 'Someone';

    setState(() {
      if (data['is_typing'] as bool) {
        _typingUsers[senderId] = {
          'name': firstName,
          'timestamp': DateTime.now(),
        };
      } else {
        _typingUsers.remove(senderId);
      }
    });
  }

  Widget _buildTypingIndicator() {
    final activeTypers = _typingUsers.entries.where((entry) =>
    DateTime.now().difference(entry.value['timestamp']) <
        const Duration(seconds: 3)
    ).toList();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: activeTypers.isNotEmpty
          ? Container(
        key: ValueKey(activeTypers.hashCode),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          children: [
            ...activeTypers.take(3).map((entry) => Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Text(
                '${entry.value['name']} is typing',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            )),
            _buildTypingAnimation(),
          ],
        ),
      )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildTypingAnimation() => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(3, (i) => _TypingDot(delay: i * 200)),
  );

  /// Handles Message Status Indicator
  Widget _buildStatusIndicator(String status) {
    final effectiveStatus = status.isNotEmpty ? status : 'sent';
    return Icon(
      effectiveStatus == 'read'
          ? Icons.done_all
          : Icons.done,
      size: 12,
      color: _getStatusColor(effectiveStatus),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'read':
        return Colors.blue;
      case 'delivered':
        return Colors.grey[600]!;
      default: // sent
        return Colors.grey[400]!;
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _typingDebounce?.cancel();
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
            icon: const Icon(Icons.call),
            onPressed: () {},
          ),

          IconButton(
            icon: const Icon(Icons.video_call),
            onPressed: () {},
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

                print('Status::: ${message['status'] }');

                // In ListView.builder itemBuilder
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(message['timestamp'] ?? message['sent_at']),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              _buildStatusIndicator(message['status'] as String),
                            ],
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildTypingIndicator(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: (text) {
                      _handleTyping(text.isNotEmpty);
                    },
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

/// Typing indication UI
class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  _TypingDotState createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.grey[600],
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}