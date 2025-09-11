const express = require('express');
const Chat = require('../models/Chat');
const { authenticateToken } = require('../middleware/auth');
const User = require('../models/User');
const db = require('../config/db');

const router = express.Router();

// Get all conversations for the authenticated user
router.get('/conversations', authenticateToken, async (req, res) => {
  try {
    console.log('=== CHAT ROUTE: GET CONVERSATIONS ===');
    console.log('User ID:', req.user.userId);
    console.log('User Role:', req.user.role);
    
    // Allow admins, technicians, and borrowers to access conversations
    if (!['admin', 'technician', 'borrower'].includes(req.user.role)) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    let conversations;
    
    if (req.user.role === 'admin') {
      // Admins can see all conversations
      const result = await db.query(`
        SELECT DISTINCT ON (c.id) 
          c.id, c.created_at,
          t.id as technician_id, t.name as technician_name, t.email as technician_email,
          b.id as borrower_id, b.name as borrower_name, b.email as borrower_email,
          b.student_id as borrower_student_id,
          m.message as last_message,
          m.created_at as last_message_time,
          m.sender_id as last_sender_id
        FROM conversations c
        JOIN users t ON c.technician_id = t.id
        JOIN users b ON c.borrower_id = b.id
        LEFT JOIN messages m ON c.id = m.conversation_id
        ORDER BY c.id, m.created_at DESC
      `);
      
      conversations = result.rows.map(conv => ({
        id: conv.id,
        createdAt: conv.created_at,
        technician: {
          id: conv.technician_id,
          name: conv.technician_name,
          email: conv.technician_email
        },
        borrower: {
          id: conv.borrower_id,
          name: conv.borrower_name,
          email: conv.borrower_email,
          studentId: conv.borrower_student_id
        },
        lastMessage: conv.last_message,
        lastMessageTime: conv.last_message_time,
        lastSenderId: conv.last_sender_id,
        unreadCount: 0
      }));
    } else {
      // For technicians and borrowers, use existing logic
      conversations = await Chat.getConversations(req.user.userId, req.user.role);
      
      // Add unread count for each conversation
      for (let conv of conversations) {
        conv.unreadCount = await Chat.getUnreadCount(conv.id, req.user.userId);
      }
    }
    
    console.log(`Returning ${conversations.length} conversations`);
    res.json(conversations);
  } catch (error) {
    console.error('Error getting conversations:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get messages for a specific conversation
router.get('/conversations/:conversationId/messages', authenticateToken, async (req, res) => {
  try {
    console.log('=== CHAT ROUTE: GET MESSAGES ===');
    console.log('Conversation ID:', req.params.conversationId);
    console.log('User ID:', req.user.userId);
    
    // Verify user has access to this conversation
    const conversation = await db.query(
      `SELECT id, technician_id, borrower_id FROM conversations WHERE id = $1`,
      [req.params.conversationId]
    );
    
    if (conversation.rows.length === 0) {
      return res.status(404).json({ error: 'Conversation not found' });
    }
    
    const conv = conversation.rows[0];
    
    // Allow access for admins, or if user is part of the conversation
    const isAdmin = req.user.role === 'admin';
    const isParticipant = (conv.technician_id === req.user.userId) || (conv.borrower_id === req.user.userId);
    
    if (!isAdmin && !isParticipant) {
      return res.status(403).json({ error: 'Access denied to this conversation' });
    }
    
    const limit = parseInt(req.query.limit) || 50;
    const offset = parseInt(req.query.offset) || 0;
    
    const messages = await Chat.getMessages(req.params.conversationId, limit, offset);
    
    // Mark messages as read (only for participants, not admins viewing)
    if (isParticipant) {
      await Chat.markAsRead(req.params.conversationId, req.user.userId);
    }
    
    console.log(`Returning ${messages.length} messages`);
    res.json(messages);
  } catch (error) {
    console.error('Error getting messages:', error);
    res.status(500).json({ error: error.message });
  }
});

// Send a message in a conversation
router.post('/conversations/:conversationId/messages', authenticateToken, async (req, res) => {
  try {
    console.log('=== CHAT ROUTE: SEND MESSAGE ===');
    console.log('Conversation ID:', req.params.conversationId);
    console.log('User ID:', req.user.userId);
    console.log('Message:', req.body.message);
    
    // Verify user has access to this conversation
    const conversation = await db.query(
      `SELECT id, technician_id, borrower_id FROM conversations WHERE id = $1`,
      [req.params.conversationId]
    );
    
    if (conversation.rows.length === 0) {
      return res.status(404).json({ error: 'Conversation not found' });
    }
    
    const conv = conversation.rows[0];
    
    // Allow access for admins, or if user is part of the conversation
    const isAdmin = req.user.role === 'admin';
    const isParticipant = (conv.technician_id === req.user.userId) || (conv.borrower_id === req.user.userId);
    
    if (!isAdmin && !isParticipant) {
      return res.status(403).json({ error: 'Access denied to this conversation' });
    }
    
    const { message, messageType = 'text' } = req.body;
    
    if (!message || message.trim().length === 0) {
      return res.status(400).json({ error: 'Message cannot be empty' });
    }
    
    const sentMessage = await Chat.sendMessage(
      req.params.conversationId, 
      req.user.userId, 
      message.trim(), 
      messageType
    );
    
    // Get sender details
    sentMessage.sender = await Chat.getChatUser(req.user.userId);
    
    console.log('Message sent successfully:', sentMessage.id);
    res.status(201).json(sentMessage);
  } catch (error) {
    console.error('Error sending message:', error);
    res.status(500).json({ error: error.message });
  }
});

// Start a new conversation (technicians can start with borrowers, borrowers can request technician)
router.post('/conversations', authenticateToken, async (req, res) => {
  try {
    console.log('=== CHAT ROUTE: CREATE CONVERSATION ===');
    console.log('User ID:', req.user.userId);
    console.log('User Role:', req.user.role);
    console.log('Target User ID:', req.body.targetUserId);
    
    const { targetUserId } = req.body;
    
    if (!targetUserId) {
      return res.status(400).json({ error: 'Target user ID is required' });
    }
    
    // Get target user details
    const targetUser = await User.findById(targetUserId);
    if (!targetUser) {
      return res.status(404).json({ error: 'Target user not found' });
    }
    
    // Validate role compatibility (admins can create conversations too)
    if (req.user.role === 'technician' && targetUser.role !== 'borrower') {
      return res.status(403).json({ error: 'Technicians can only chat with borrowers' });
    }
    
    if (req.user.role === 'borrower' && targetUser.role !== 'technician') {
      return res.status(403).json({ error: 'Borrowers can only chat with technicians' });
    }
    
    if (req.user.role === 'admin') {
      // Admins can create conversations between technicians and borrowers
      if (!((req.user.role === 'admin' && targetUser.role === 'technician') ||
            (req.user.role === 'admin' && targetUser.role === 'borrower'))) {
        // For admin, we need both a technician and borrower
        return res.status(400).json({ error: 'Admin needs to specify both technician and borrower for conversation' });
      }
    }
    
    // Create conversation (ensure technician is always first, borrower second for consistency)
    let technicianId, borrowerId;
    
    if (req.user.role === 'technician') {
      technicianId = req.user.userId;
      borrowerId = targetUser.id;
    } else if (req.user.role === 'borrower') {
      technicianId = targetUser.id;
      borrowerId = req.user.userId;
    } else if (req.user.role === 'admin') {
      // For admin, assume they're creating a conversation for the target user
      if (targetUser.role === 'technician') {
        technicianId = targetUser.id;
        // You might need to specify borrower ID differently for admin
        return res.status(400).json({ error: 'Admin must specify both technician and borrower IDs' });
      } else {
        borrowerId = targetUser.id;
        // You might need to specify technician ID differently for admin
        return res.status(400).json({ error: 'Admin must specify both technician and borrower IDs' });
      }
    }
    
    const conversation = await Chat.createConversation(technicianId, borrowerId);
    
    // Get other user details for response
    const otherUserId = req.user.role === 'technician' ? borrowerId : technicianId;
    const otherUser = await Chat.getChatUser(otherUserId);
    
    const response = {
      conversation: {
        id: conversation.id,
        createdAt: conversation.created_at
      },
      otherUser: {
        id: otherUser.id,
        name: otherUser.name,
        email: otherUser.email,
        role: otherUser.role,
        phone: otherUser.phone,
        studentId: otherUser.student_id
      }
    };
    
    console.log('Conversation created successfully:', conversation.id);
    res.status(201).json(response);
  } catch (error) {
    console.error('Error creating conversation:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get chat user details (for displaying contact info)
router.get('/users/:userId', authenticateToken, async (req, res) => {
  try {
    console.log('=== CHAT ROUTE: GET USER DETAILS ===');
    console.log('Requested user ID:', req.params.userId);
    console.log('Current user ID:', req.user.userId);
    
    // Users can only get details of people they can chat with
    const currentUser = await User.findById(req.user.userId);
    const targetUser = await User.findById(req.params.userId);
    
    if (!targetUser) {
      return res.status(404).json({ error: 'User not found' });
    }
    
    // Check if they can chat (technician-borrower relationship or admin access)
    const isAdmin = currentUser.role === 'admin';
    const canChat = isAdmin || 
                   (currentUser.role === 'technician' && targetUser.role === 'borrower') ||
                   (currentUser.role === 'borrower' && targetUser.role === 'technician');
    
    if (!canChat) {
      return res.status(403).json({ error: 'Cannot access this user\'s details' });
    }
    
    // Sanitize user info
    const sanitizedUser = {
      id: targetUser.id,
      name: targetUser.name,
      email: targetUser.email,
      role: targetUser.role,
      phone: targetUser.phone,
      studentId: targetUser.student_id,
      institution: targetUser.institution,
      department: targetUser.department
    };
    
    res.json(sanitizedUser);
  } catch (error) {
    console.error('Error getting user details:', error);
    res.status(500).json({ error: error.message });
  }
});

// Mark conversation as read
router.post('/conversations/:conversationId/read', authenticateToken, async (req, res) => {
  try {
    console.log('=== CHAT ROUTE: MARK AS READ ===');
    console.log('Conversation ID:', req.params.conversationId);
    console.log('User ID:', req.user.userId);
    
    // Verify access
    const conversation = await db.query(
      `SELECT id, technician_id, borrower_id FROM conversations WHERE id = $1`,
      [req.params.conversationId]
    );
    
    if (conversation.rows.length === 0) {
      return res.status(404).json({ error: 'Conversation not found' });
    }
    
    const conv = conversation.rows[0];
    
    // Allow access for admins, or if user is part of the conversation
    const isAdmin = req.user.role === 'admin';
    const isParticipant = (conv.technician_id === req.user.userId) || (conv.borrower_id === req.user.userId);
    
    if (!isAdmin && !isParticipant) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    // Only mark as read for participants, not admins viewing
    if (isParticipant) {
      await Chat.markAsRead(req.params.conversationId, req.user.userId);
    }
    
    res.json({ message: 'Messages marked as read' });
  } catch (error) {
    console.error('Error marking as read:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;