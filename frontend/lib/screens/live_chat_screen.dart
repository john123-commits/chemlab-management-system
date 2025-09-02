import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/services/api_service.dart';

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  List<dynamic> _conversations = [];
  Map<String, dynamic>? _selectedConversation;
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _showStartChat = false;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    try {
      final conversations = await ApiService.getLiveChatConversations();
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load conversations: $error')),
      );
    }
  }

  Future<void> _startNewChat() async {
    if (_userIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a user ID')),
      );
      return;
    }

    try {
      final result = await ApiService.startLiveChat(
        int.parse(_userIdController.text),
        title: _titleController.text.isNotEmpty ? _titleController.text : null,
      );

      _userIdController.clear();
      _titleController.clear();
      setState(() {
        _showStartChat = false;
      });

      // Load the new conversation
      await _loadConversations();
      _selectConversation(result['conversation']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Live chat started successfully')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start chat: $error')),
      );
    }
  }

  Future<void> _selectConversation(Map<String, dynamic> conversation) async {
    setState(() {
      _selectedConversation = conversation;
      _messages = [];
    });

    try {
      final result = await ApiService.getLiveChatMessages(conversation['id']);
      setState(() {
        _messages = result['messages'];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load messages: $error')),
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedConversation == null)
      return;

    final message = _messageController.text.trim();
    _messageController.clear();

    setState(() => _isSending = true);

    try {
      await ApiService.sendLiveChatMessage(
          _selectedConversation!['id'], message);

      // Reload messages
      final result =
          await ApiService.getLiveChatMessages(_selectedConversation!['id']);
      setState(() {
        _messages = result['messages'];
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $error')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _closeConversation() async {
    if (_selectedConversation == null) return;

    try {
      await ApiService.closeLiveChatConversation(_selectedConversation!['id']);
      await _loadConversations();
      setState(() {
        _selectedConversation = null;
        _messages = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation closed successfully')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to close conversation: $error')),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _userIdController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(context).userRole;

    if (userRole != 'admin' && userRole != 'technician') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Access Denied',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Only admins and technicians can access live chat',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Chat Support'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                _showStartChat = !_showStartChat;
              });
            },
            tooltip: 'Start New Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Start new chat form
          if (_showStartChat) ...[
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start New Live Chat',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _userIdController,
                      decoration: const InputDecoration(
                        labelText: 'User ID',
                        hintText: 'Enter user ID to start chat with',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Chat Title (Optional)',
                        hintText: 'Enter chat title',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showStartChat = false;
                            });
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _startNewChat,
                          child: const Text('Start Chat'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Conversations list and chat area
          Expanded(
            child: Row(
              children: [
                // Conversations list
                SizedBox(
                  width: 300,
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Active Conversations',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _conversations.isEmpty
                                  ? const Center(
                                      child: Text('No conversations'))
                                  : ListView.builder(
                                      itemCount: _conversations.length,
                                      itemBuilder: (context, index) {
                                        final conversation =
                                            _conversations[index];
                                        final isSelected =
                                            _selectedConversation?['id'] ==
                                                conversation['id'];

                                        return ListTile(
                                          selected: isSelected,
                                          selectedTileColor:
                                              Colors.blue.withOpacity(0.1),
                                          title: Text(
                                            conversation['title'] ??
                                                'Live Support',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          subtitle: Text(
                                            'User ID: ${conversation['user_id']}',
                                            style: TextStyle(
                                              color: conversation['status'] ==
                                                      'closed'
                                                  ? Colors.grey
                                                  : Colors.green,
                                            ),
                                          ),
                                          trailing: Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: conversation['status'] ==
                                                      'active'
                                                  ? Colors.green
                                                  : Colors.grey,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          onTap: () =>
                                              _selectConversation(conversation),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Chat area
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.all(16),
                    child: _selectedConversation == null
                        ? const Center(
                            child:
                                Text('Select a conversation to start chatting'))
                        : Column(
                            children: [
                              // Chat header
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  border: const Border(
                                    bottom: BorderSide(
                                        color: Colors.blue, width: 1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedConversation!['title'] ??
                                                'Live Support',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          Text(
                                            'Status: ${_selectedConversation!['status']}',
                                            style: TextStyle(
                                              color: _selectedConversation![
                                                          'status'] ==
                                                      'active'
                                                  ? Colors.green
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_selectedConversation!['status'] ==
                                        'active')
                                      ElevatedButton.icon(
                                        onPressed: _closeConversation,
                                        icon: const Icon(Icons.close),
                                        label: const Text('Close Chat'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Messages area
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, index) {
                                    final message = _messages[index];
                                    final isAdmin = message['sender_type'] ==
                                            'admin' ||
                                        message['sender_type'] == 'technician';

                                    return Align(
                                      alignment: isAdmin
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        padding: const EdgeInsets.all(12),
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isAdmin
                                              ? Colors.blue[600]
                                              : Colors.grey[300],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              message['message_text'],
                                              style: TextStyle(
                                                color: isAdmin
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${message['sender_name'] ?? message['sender_type']} • ${_formatTimestamp(message['created_at'])}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isAdmin
                                                    ? Colors.white70
                                                    : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Message input
                              if (_selectedConversation!['status'] == 'active')
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _messageController,
                                          decoration: const InputDecoration(
                                            hintText: 'Type your message...',
                                            border: OutlineInputBorder(),
                                          ),
                                          onSubmitted: (_) => _sendMessage(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed:
                                            _isSending ? null : _sendMessage,
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
                                ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
