// screens/chatbot_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/services/api_service.dart';

class ChatBotScreen extends StatefulWidget {
  const ChatBotScreen({super.key});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isSending = false;
  List<dynamic> _quickActions = [];

  @override
  void initState() {
    super.initState();
    _addMessage(
        'Hello! I\'m ChemBot, your lab assistant. How can I help you today?',
        false);
    _loadQuickActions();
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add({
        'text': text,
        'isUser': isUser,
        'timestamp': DateTime.now(),
      });
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    // Add user message
    _addMessage(message, true);
    setState(() => _isSending = true);

    try {
      // Get user data from auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;
      final userRole = authProvider.userRole;

      // Call your existing API service with proper parameters
      final response =
          await ApiService.sendChatMessage(message, userId, userRole);
      _addMessage(response['response'], false);
    } catch (error) {
      _addMessage('Sorry, I encountered an error. Please try again.', false);
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _loadQuickActions() async {
    try {
      final userRole =
          Provider.of<AuthProvider>(context, listen: false).userRole;
      final actions = await ApiService.getChatQuickActions(userRole);
      setState(() {
        _quickActions = actions;
      });
    } catch (error) {
      // Handle error gracefully
      setState(() {
        // Set default quick actions if API fails
        _quickActions = [
          {'display_text': 'Chemicals', 'icon': 'science'},
          {'display_text': 'Equipment', 'icon': 'build'},
          {'display_text': 'Borrow', 'icon': 'assignment'},
          {'display_text': 'Schedule', 'icon': 'calendar_today'},
        ];
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChemBot Assistant'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Chat messages area
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(
                  message['text'],
                  message['isUser'],
                );
              },
            ),
          ),

          // Quick actions
          _buildQuickActions(),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue[600] : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    if (_quickActions.isEmpty) {
      return Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Center(
          child: Text('Loading quick actions...'),
        ),
      );
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _quickActions.map((action) {
          return _buildQuickActionButton(
            action['display_text'] ?? 'Action',
            _getIconData(action['icon'] ?? 'help'),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton.icon(
        onPressed: () {
          _messageController.text = 'Show me $label';
          _sendMessage();
        },
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[100],
          foregroundColor: Colors.blue[800],
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'science':
        return Icons.science;
      case 'build':
        return Icons.build;
      case 'assignment':
        return Icons.assignment;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      default:
        return Icons.help;
    }
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Ask me anything about the lab...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isSending ? null : _sendMessage,
            icon: _isSending
                ? const CircularProgressIndicator()
                : const Icon(Icons.send),
            style: IconButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
