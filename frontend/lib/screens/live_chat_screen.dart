import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chemlab_frontend/providers/auth_provider.dart';
import 'package:chemlab_frontend/services/api_service.dart';
import 'package:chemlab_frontend/models/user.dart';

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({super.key});

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  List<User> _users = [];
  List<User> _borrowers = []; // New: List of borrowers for technicians
  bool _isLoadingUsers = false;
  bool _isLoadingBorrowers = false; // New: Loading state for borrowers
  List<dynamic> _conversations = [];
  Map<String, dynamic>? _selectedConversation;
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _showStartChat = false;
  bool _showBorrowerList = false; // New: Show borrower list for technicians

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadUsers();
    _loadBorrowers(); // New: Load borrowers for technicians
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() => _isLoadingUsers = true);
    try {
      final List<User> users = await ApiService.getUsers();
      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    } catch (error) {
      setState(() => _isLoadingUsers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $error')),
        );
      }
    }
  }

  // New: Load active borrowers for technicians
  Future<void> _loadBorrowers() async {
    final userRole = Provider.of<AuthProvider>(context, listen: false).userRole;
    if (userRole != 'technician') return;

    if (!mounted) return;
    setState(() => _isLoadingBorrowers = true);
    try {
      // Call the new backend endpoint for active borrowers
      final List<User> borrowersData = await ApiService.getUsers();
      final List<User> borrowers =
          borrowersData.where((user) => user.role == 'borrower').toList();

      setState(() {
        _borrowers = borrowers;
        _isLoadingBorrowers = false;
      });
    } catch (error) {
      setState(() => _isLoadingBorrowers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load borrowers: $error')),
        );
      }
    }
  }

  Future<void> _loadConversations() async {
    try {
      // Use new chat conversations endpoint
      final conversations = await ApiService.getChatConversations();
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
    final userRole = Provider.of<AuthProvider>(context, listen: false).userRole;

    if (userRole == 'technician' && _borrowers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No borrowers available to chat with')),
      );
      return;
    }

    if (userRole == 'technician') {
      // For technicians, select from borrower list
      final selectedBorrower = _borrowers.firstWhere(
        (borrower) => borrower.id == int.parse(_userIdController.text),
        orElse: () => User(
            id: 0,
            name: '',
            email: '',
            role: 'borrower',
            createdAt: DateTime.now()),
      );

      if (selectedBorrower.id == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a valid borrower')),
        );
        return;
      }

      try {
        // Use the new chat API endpoint
        final result =
            await ApiService.createChatConversation(selectedBorrower.id);

        _userIdController.clear();
        _titleController.clear();
        setState(() {
          _showStartChat = false;
          _showBorrowerList = false;
        });

        // Load the new conversation
        await _loadConversations();
        _selectConversation(result['conversation']);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Chat started successfully with ${selectedBorrower.name}')),
        );
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat: $error')),
        );
      }
    } else {
      // Original logic for admins
      if (_userIdController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a user ID')),
        );
        return;
      }

      try {
        final result = await ApiService.startLiveChat(
          int.parse(_userIdController.text),
          title:
              _titleController.text.isNotEmpty ? _titleController.text : null,
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
  }

  Future<void> _selectConversation(Map<String, dynamic> conversation) async {
    setState(() {
      _selectedConversation = conversation;
      _messages = [];
    });

    try {
      // Use new chat messages endpoint
      final messages = await ApiService.getChatMessages(conversation['id']);
      setState(() {
        _messages = messages;
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
      // Use new chat message endpoint
      if (_selectedConversation?['id'] != null) {
        await ApiService.sendChatMessage(_selectedConversation!['id'], message);
      } else {
        throw Exception('Invalid conversation ID');
      }

      // Reload messages
      final messages =
          await ApiService.getChatMessages(_selectedConversation!['id']);
      setState(() {
        _messages = messages;
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
        title: Text(
            userRole == 'technician' ? 'Technician Chat' : 'Live Chat Support'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadConversations();
              if (userRole == 'technician') {
                _loadBorrowers();
              }
            },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                if (userRole == 'technician') {
                  _showBorrowerList = true;
                  _showStartChat = false;
                } else {
                  _showStartChat = !_showStartChat;
                }
              });
            },
            tooltip: userRole == 'technician'
                ? 'Start Chat with Borrower'
                : 'Start New Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // New: Borrower list for technicians
          if (userRole == 'technician' && _showBorrowerList) ...[
            Container(
              height: 400,
              margin: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Select Borrower to Chat With',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showBorrowerList = false;
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _isLoadingBorrowers
                            ? const Center(child: CircularProgressIndicator())
                            : _borrowers.isEmpty
                                ? const Center(
                                    child:
                                        Text('No active borrowers available'),
                                  )
                                : ListView.builder(
                                    itemCount: _borrowers.length,
                                    itemBuilder: (context, index) {
                                      final borrower = _borrowers[index];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          child: Text(borrower.name.isNotEmpty
                                              ? borrower.name[0].toUpperCase()
                                              : '?'),
                                        ),
                                        title: Text(borrower.name),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(borrower.email),
                                            if (borrower.studentId != null)
                                              Text('ID: ${borrower.studentId}'),
                                            if (borrower.institution != null)
                                              Text(borrower.institution!),
                                          ],
                                        ),
                                        trailing: ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _userIdController.text =
                                                  borrower.id.toString();
                                              _showBorrowerList = false;
                                              _showStartChat = true;
                                            });
                                          },
                                          child: const Text('Start Chat'),
                                        ),
                                        onTap: () {
                                          setState(() {
                                            _userIdController.text =
                                                borrower.id.toString();
                                            _showBorrowerList = false;
                                            _showStartChat = true;
                                          });
                                        },
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          // Start new chat form (for admins or technicians after borrower selection)
          if (_showStartChat) ...[
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userRole == 'technician'
                          ? 'Start Chat with Selected Borrower'
                          : 'Start New Live Chat',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    if (userRole != 'technician' && _isLoadingUsers)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (userRole != 'technician') ...[
                      DropdownButtonFormField<int>(
                        value: null,
                        decoration: const InputDecoration(
                          labelText: 'Select User',
                          hintText: 'Choose a user to start chat with',
                          helperText:
                              'Select from the list of registered users',
                        ),
                        items: _users.map<DropdownMenuItem<int>>((User user) {
                          return DropdownMenuItem<int>(
                            value: user.id,
                            child: Text(
                              '${user.name} (${user.email}) - ID: ${user.id}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _userIdController.text = value.toString();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tip: Select a user from the dropdown. The User ID will be automatically filled for the chat.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.start,
                      ),
                    ] else ...[
                      TextField(
                        controller: _userIdController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Selected Borrower ID',
                          hintText: 'ID will be filled from borrower selection',
                        ),
                      ),
                    ],
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
                              if (userRole == 'technician') {
                                _userIdController.clear();
                                _titleController.clear();
                              }
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
                                          onLongPress: () =>
                                              _showDeleteDialog(conversation),
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

                                    return GestureDetector(
                                      onLongPress: () =>
                                          _showMessageDeleteDialog(message),
                                      child: Align(
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

  Future<void> _showDeleteDialog(Map<String, dynamic> conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Conversation'),
          content: Text(
            'Are you sure you want to delete the conversation "${conversation['title'] ?? 'Live Support'}"? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteLiveChatConversation(conversation['id']);
        await _loadConversations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conversation deleted successfully')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete conversation: $error')),
          );
        }
      }
    }
  }

  Future<void> _showMessageDeleteDialog(Map<String, dynamic> message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Message'),
          content: const Text(
            'Are you sure you want to delete this message? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true && _selectedConversation != null) {
      try {
        await ApiService.deleteLiveChatMessage(message['id']);
        // Reload messages for the current conversation
        final result =
            await ApiService.getLiveChatMessages(_selectedConversation!['id']);
        setState(() {
          _messages = result['messages'];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message deleted successfully')),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete message: $error')),
          );
        }
      }
    }
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
