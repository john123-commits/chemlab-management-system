// Enhanced screens/chatbot_screen.dart - WITH QUICK ACTIONS REMOVED
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
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isSending = false;
  String _selectedQueryType = 'general';

  // Query types for better categorization
  final List<Map<String, dynamic>> _queryTypes = [
    {'value': 'general', 'label': 'General', 'icon': Icons.chat},
    {'value': 'chemical_inquiry', 'label': 'Chemicals', 'icon': Icons.science},
    {'value': 'equipment_inquiry', 'label': 'Equipment', 'icon': Icons.build},
    {'value': 'safety_query', 'label': 'Safety', 'icon': Icons.security},
    {
      'value': 'borrowing_request',
      'label': 'Borrowing',
      'icon': Icons.assignment
    },
    {
      'value': 'schedule_query',
      'label': 'Schedule',
      'icon': Icons.calendar_today
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Add welcome message with user context
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userRole = authProvider.userRole;

    String welcomeMessage = 'Hello! I\'m ChemBot, your lab assistant. ';
    switch (userRole) {
      case 'technician':
        welcomeMessage +=
            'I can help you manage inventory, check equipment status, and handle safety procedures.';
        break;
      case 'student':
        welcomeMessage +=
            'I can help you find chemicals, book equipment, check schedules, and provide safety information.';
        break;
      case 'admin':
        welcomeMessage +=
            'I can provide system status, manage requests, and generate reports.';
        break;
      default:
        welcomeMessage += 'How can I help you today?';
    }

    _addMessage(welcomeMessage, false, queryType: 'system');
    // REMOVED: await _loadQuickActions();
  }

  void _addMessage(
    String text,
    bool isUser, {
    String? queryType,
    int? processingTime,
    bool isError = false,
  }) {
    setState(() {
      _messages.add({
        'text': text,
        'isUser': isUser,
        'timestamp': DateTime.now(),
        'queryType': queryType,
        'processingTime': processingTime,
        'isError': isError,
      });
    });

    // Auto-scroll to bottom
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

  Future<void> _sendMessage({String? predefinedMessage}) async {
    final message = predefinedMessage ?? _messageController.text.trim();
    if (message.isEmpty) return;

    if (predefinedMessage == null) {
      _messageController.clear();
    }

    // Add user message with query type
    _addMessage(message, true, queryType: _selectedQueryType);

    setState(() {
      _isSending = true;
    });

    // Add typing indicator
    _addMessage('ChemBot is thinking...', false, queryType: 'typing');

    final startTime = DateTime.now();

    try {
      // Get user data from auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.userId;
      final userRole = authProvider.userRole;

      // Enhanced API call with query type
      final response = await ApiService.sendChatbotMessage(
        message,
        userId,
        userRole,
      );

      // Remove typing indicator
      setState(() {
        _messages.removeWhere((msg) => msg['queryType'] == 'typing');
      });

      final processingTime =
          DateTime.now().difference(startTime).inMilliseconds;

      // Add bot response with metadata
      _addMessage(
        response['response'] ?? response['message'],
        false,
        queryType: response['detectedQueryType'] ?? _selectedQueryType,
        processingTime: processingTime,
      );

      // REMOVED: _updateContextualActions(response);
    } catch (error) {
      // Remove typing indicator
      setState(() {
        _messages.removeWhere((msg) => msg['queryType'] == 'typing');
      });

      _addMessage(
        'Sorry, I encountered an error. Please try again.',
        false,
        isError: true,
      );

      // Log error for debugging
      debugPrint('ChatBot Error: $error');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Color _getQueryTypeColor(String? queryType) {
    switch (queryType) {
      case 'chemical_inquiry':
        return Colors.blue.shade100;
      case 'equipment_inquiry':
        return Colors.green.shade100;
      case 'safety_query':
        return Colors.red.shade100;
      case 'borrowing_request':
        return Colors.purple.shade100;
      case 'schedule_query':
        return Colors.orange.shade100;
      case 'system':
        return Colors.grey.shade100;
      case 'typing':
        return Colors.grey.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  IconData _getQueryTypeIcon(String? queryType) {
    switch (queryType) {
      case 'chemical_inquiry':
        return Icons.science;
      case 'equipment_inquiry':
        return Icons.build;
      case 'safety_query':
        return Icons.security;
      case 'borrowing_request':
        return Icons.assignment;
      case 'schedule_query':
        return Icons.calendar_today;
      case 'system':
        return Icons.android;
      case 'typing':
        return Icons.more_horiz;
      default:
        return Icons.chat;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ChemBot Assistant'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          // User role indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getRoleColor(authProvider.userRole),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              authProvider.userRole.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Query type selector
          _buildQueryTypeSelector(),

          // Chat messages area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),

          // REMOVED: Quick actions section
          // if (_quickActions.isNotEmpty) _buildQuickActions(),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildQueryTypeSelector() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _queryTypes.length,
        itemBuilder: (context, index) {
          final queryType = _queryTypes[index];
          final isSelected = _selectedQueryType == queryType['value'];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    queryType['icon'],
                    size: 16,
                    color: isSelected ? Colors.white : Colors.blue,
                  ),
                  const SizedBox(width: 4),
                  Text(queryType['label']),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedQueryType = queryType['value'];
                });
              },
              selectedColor: Colors.blue,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isUser = message['isUser'] as bool;
    final isError = message['isError'] ?? false;
    final queryType = message['queryType'] as String?;
    final processingTime = message['processingTime'] as int?;
    final timestamp = message['timestamp'] as DateTime;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Message metadata
          if (!isUser && queryType != 'typing')
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getQueryTypeIcon(queryType),
                    size: 12,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                    ),
                  ),
                  if (processingTime != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${processingTime}ms',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Message bubble
          Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? Colors.blue[600]
                    : isError
                        ? Colors.red.shade50
                        : _getQueryTypeColor(queryType),
                borderRadius: BorderRadius.circular(12),
                border: isError ? Border.all(color: Colors.red.shade200) : null,
              ),
              child: queryType == 'typing'
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.grey[600]!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          message['text'],
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    )
                  : Text(
                      message['text'],
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : isError
                                ? Colors.red.shade800
                                : Colors.black87,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -1),
            blurRadius: 4,
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Ask about chemicals, equipment, safety...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              onPressed: _isSending ? null : () => _sendMessage(),
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.red;
      case 'technician':
        return Colors.orange;
      case 'student':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
