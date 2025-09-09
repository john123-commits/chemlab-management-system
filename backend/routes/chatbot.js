// routes/chatbot.js
const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');

const { processChatMessage } = require('../services/chatbotService');
const { getQuickActionsForRole, getUserChatHistory } = require('../services/chatbotHelpers');
const { healthCheck, getCacheStats, clearAllCaches } = require('../utils/queryOptimizer');

// Chat message endpoint
router.post('/message', authenticateToken, async (req, res) => {
  try {
    const { message, userId, userRole } = req.body;
    
    // Validate required fields
    if (!message || !userId || !userRole) {
      return res.status(400).json({ 
        success: false, 
        error: 'Missing required fields: message, userId, userRole' 
      });
    }
    
    console.log('Chat message received:', { message, userId, userRole });
    
    // Process message and generate response
    const response = await processChatMessage(message, userId, userRole);
    
    res.json({
      success: true,
      response: response,
      timestamp: new Date()
    });
  } catch (error) {
    console.error('Chat message error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message || 'Internal server error' 
    });
  }
});

// Quick actions endpoint
router.get('/quick-actions/:role', authenticateToken, async (req, res) => {
  try {
    const { role } = req.params;
    
    // Validate role parameter
    if (!role) {
      return res.status(400).json({ 
        success: false, 
        error: 'Missing role parameter' 
      });
    }
    
    const actions = await getQuickActionsForRole(role);
    res.json({ success: true, actions });
  } catch (error) {
    console.error('Quick actions error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

// User chat history
router.get('/history', authenticateToken, async (req, res) => {
  try {
    // Note: req.user.id comes from authenticateToken middleware
    const userId = req.user.id;
    
    // Validate user ID
    if (!userId) {
      return res.status(400).json({ 
        success: false, 
        error: 'User ID not found in request' 
      });
    }
    
    const history = await getUserChatHistory(userId);
    res.json({ success: true, history });
  } catch (error) {
    console.error('Chat history error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

// Enhanced endpoint for user recent activity
router.get('/user-activity', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    
    if (!userId) {
      return res.status(400).json({ 
        success: false, 
        error: 'User ID not found in request' 
      });
    }
    
    // Import the function here to avoid circular dependencies
    const { getUserRecentActivity } = require('../services/chatbotHelpers');
    const activity = await getUserRecentActivity(userId);
    res.json({ success: true, activity });
  } catch (error) {
    console.error('User activity error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

// Enhanced endpoint for upcoming schedules
router.get('/upcoming-schedules', authenticateToken, async (req, res) => {
  try {
    const { getUser } = require('../services/apiService');
    const userRole = req.user.role;
    
    // Only allow staff to access this endpoint
    if (userRole !== 'admin' && userRole !== 'technician') {
      return res.status(403).json({ 
        success: false, 
        error: 'Access denied: Staff only' 
      });
    }
    
    const { getUpcomingSchedules } = require('../services/chatbotHelpers');
    const schedules = await getUpcomingSchedules(10);
    res.json({ success: true, schedules });
  } catch (error) {
    console.error('Upcoming schedules error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

// Enhanced endpoint for system alerts
router.get('/system-alerts', authenticateToken, async (req, res) => {
  try {
    const { getUser } = require('../services/apiService');
    const userRole = req.user.role;

    // Only allow staff to access this endpoint
    if (userRole !== 'admin' && userRole !== 'technician') {
      return res.status(403).json({
        success: false,
        error: 'Access denied: Staff only'
      });
    }

    const { getSystemAlerts } = require('../services/chatbotHelpers');
    const alerts = await getSystemAlerts(10);
    res.json({ success: true, alerts });
  } catch (error) {
    console.error('System alerts error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

// Live Chat endpoints for admin-to-user communication
router.post('/live-chat/start', authenticateToken, async (req, res) => {
  try {
    const { userId, title } = req.body;
    const adminId = req.user.id;
    const adminRole = req.user.role;

    // Only allow admin and technician to start live chats
    if (adminRole !== 'admin' && adminRole !== 'technician') {
      return res.status(403).json({
        success: false,
        error: 'Access denied: Admin or technician only'
      });
    }

    const { Pool } = require('pg');
    const pool = new Pool({
      user: process.env.DB_USER,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      password: process.env.DB_PASSWORD,
      port: process.env.DB_PORT,
    });

    // Check if conversation already exists between these users
    const existingConv = await pool.query(
      `SELECT * FROM chat_conversations
       WHERE (user_id = $1 AND admin_id = $2) OR (user_id = $2 AND admin_id = $1)
         AND conversation_type = 'live' AND deleted_at IS NULL`,
      [userId, adminId]
    );

    if (existingConv.rows.length > 0) {
      return res.status(409).json({
        success: false,
        error: 'Live chat already exists between these users',
        conversation: existingConv.rows[0]
      });
    }

    const result = await pool.query(
      'INSERT INTO chat_conversations (user_id, admin_id, conversation_type, status, title) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [userId, adminId, 'live', 'active', title || 'Live Support']
    );

    // Send initial message (unread for the user)
    await pool.query(
      `INSERT INTO chat_messages (conversation_id, sender_type, sender_id, message_text, message_type, is_read)
       VALUES ($1, $2, $3, $4, $5, false)`,
      [result.rows[0].id, adminRole, adminId, 'Hello! How can I help you today?', 'text']
    );

    res.json({
      success: true,
      conversation: result.rows[0],
      message: 'Live chat started successfully'
    });
  } catch (error) {
    console.error('Start live chat error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

router.post('/live-chat/message', authenticateToken, async (req, res) => {
  try {
    const { conversationId, message } = req.body;
    const senderId = req.user.id;
    const senderType = req.user.role;

    const { Pool } = require('pg');
    const pool = new Pool({
      user: process.env.DB_USER,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      password: process.env.DB_PASSWORD,
      port: process.env.DB_PORT,
    });

    // Insert message
    const result = await pool.query(
      'INSERT INTO chat_messages (conversation_id, sender_type, sender_id, message_text, message_type) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [conversationId, senderType, senderId, message, 'text']
    );

    // Update conversation timestamp
    await pool.query(
      'UPDATE chat_conversations SET updated_at = CURRENT_TIMESTAMP WHERE id = $1',
      [conversationId]
    );

    res.json({
      success: true,
      message: result.rows[0]
    });
  } catch (error) {
    console.error('Send live chat message error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

router.get('/live-chat/conversations', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;

    const { Pool } = require('pg');
    const pool = new Pool({
      user: process.env.DB_USER,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      password: process.env.DB_PASSWORD,
      port: process.env.DB_PORT,
    });

    let conversationsQuery, unreadQuery, values;
    if (userRole === 'admin' || userRole === 'technician') {
      // Admin/technician sees all conversations with unread counts from all users
      conversationsQuery = `
        SELECT cc.*,
               COALESCE(unread_count, 0) as unread_count,
               u.name as other_user_name,
               u.role as other_user_role
        FROM chat_conversations cc
        LEFT JOIN LATERAL (
          SELECT COUNT(*) as unread_count
          FROM chat_messages cm
          WHERE cm.conversation_id = cc.id
            AND cm.sender_type != 'admin'
            AND cm.sender_type != 'technician'
            AND cm.is_read = false
        ) unread ON true
        LEFT JOIN users u ON (
          CASE
            WHEN cc.user_id != $1 THEN cc.user_id
            ELSE NULL
          END = u.id
        )
        WHERE cc.conversation_type = $2
          AND cc.deleted_at IS NULL
        ORDER BY cc.updated_at DESC
      `;
      values = [userId, 'live'];
    } else {
      // User sees only their conversations with their unread counts
      conversationsQuery = `
        SELECT cc.*,
               COALESCE(unread_count, 0) as unread_count
        FROM chat_conversations cc
        LEFT JOIN LATERAL (
          SELECT COUNT(*) as unread_count
          FROM chat_messages cm
          WHERE cm.conversation_id = cc.id
            AND cm.sender_type != 'user'
            AND cm.is_read = false
        ) unread ON true
        WHERE cc.user_id = $1
          AND cc.conversation_type = $2
          AND cc.deleted_at IS NULL
        ORDER BY cc.updated_at DESC
      `;
      values = [userId, 'live'];
    }

    const result = await pool.query(conversationsQuery, values);
    
    // Add last message preview for each conversation
    const conversationsWithPreview = await Promise.all(
      result.rows.map(async (conv) => {
        const lastMessage = await pool.query(
          `SELECT cm.message_text, cm.sender_type, cm.created_at, u.name as sender_name
           FROM chat_messages cm
           LEFT JOIN users u ON cm.sender_id = u.id
           WHERE cm.conversation_id = $1 AND cm.deleted_at IS NULL
           ORDER BY cm.created_at DESC
           LIMIT 1`,
          [conv.id]
        );
        
        return {
          ...conv,
          last_message: lastMessage.rows[0] || null,
          last_message_time: lastMessage.rows[0]?.created_at || conv.updated_at
        };
      })
    );

    res.json({
      success: true,
      conversations: conversationsWithPreview
    });
  } catch (error) {
    console.error('Get live chat conversations error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

router.get('/live-chat/messages/:conversationId', authenticateToken, async (req, res) => {
  try {
    const { conversationId } = req.params;
    const userId = req.user.id;
    const userRole = req.user.role;

    const { Pool } = require('pg');
    const pool = new Pool({
      user: process.env.DB_USER,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      password: process.env.DB_PASSWORD,
      port: process.env.DB_PORT,
    });

    // Check if user has access to this conversation
    const convResult = await pool.query(
      'SELECT * FROM chat_conversations WHERE id = $1',
      [conversationId]
    );

    if (convResult.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Conversation not found' });
    }

    const conversation = convResult.rows[0];
    if (conversation.user_id !== userId && conversation.admin_id !== userId &&
        (userRole !== 'admin' && userRole !== 'technician')) {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    // Get messages
    const messagesResult = await pool.query(
      'SELECT cm.*, u.name as sender_name FROM chat_messages cm LEFT JOIN users u ON cm.sender_id = u.id WHERE cm.conversation_id = $1 AND cm.deleted_at IS NULL ORDER BY cm.created_at ASC',
      [conversationId]
    );

    res.json({
      success: true,
      conversation: conversation,
      messages: messagesResult.rows
    });
  } catch (error) {
    console.error('Get live chat messages error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

router.put('/live-chat/conversations/:conversationId/close', authenticateToken, async (req, res) => {
  try {
    const { conversationId } = req.params;
    const userId = req.user.id;
    const userRole = req.user.role;

    const { Pool } = require('pg');
    const pool = new Pool({
      user: process.env.DB_USER,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      password: process.env.DB_PASSWORD,
      port: process.env.DB_PORT,
    });

    // Check if user has permission to close this conversation
    const convResult = await pool.query(
      'SELECT * FROM chat_conversations WHERE id = $1',
      [conversationId]
    );

    if (convResult.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Conversation not found' });
    }

    const conversation = convResult.rows[0];
    if (conversation.admin_id !== userId && (userRole !== 'admin' && userRole !== 'technician')) {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    // Close conversation
    await pool.query(
      'UPDATE chat_conversations SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2',
      ['ended', conversationId]
    );

    res.json({ success: true, message: 'Conversation closed successfully' });
  } catch (error) {
    console.error('Close live chat conversation error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

// Delete live chat conversation endpoint
router.delete('/live-chat/conversations/:conversationId', authenticateToken, async (req, res) => {
  try {
    const { conversationId } = req.params;
    const userId = req.user.id;
    const userRole = req.user.role;

    const { Pool } = require('pg');
    const pool = new Pool({
      user: process.env.DB_USER,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      password: process.env.DB_PASSWORD,
      port: process.env.DB_PORT,
    });

    // Check if user has permission to delete this conversation
    const convResult = await pool.query(
      'SELECT * FROM chat_conversations WHERE id = $1',
      [conversationId]
    );

    if (convResult.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Conversation not found' });
    }

    const conversation = convResult.rows[0];
    if (conversation.user_id !== userId && conversation.admin_id !== userId &&
        (userRole !== 'admin' && userRole !== 'technician')) {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    // Soft delete by setting deleted_at timestamp
    await pool.query(
      'UPDATE chat_conversations SET deleted_at = CURRENT_TIMESTAMP WHERE id = $1',
      [conversationId]
    );

    // Optionally, also delete associated messages if hard delete is preferred
    // await pool.query('DELETE FROM chat_messages WHERE conversation_id = $1', [conversationId]);

    res.json({ success: true, message: 'Conversation deleted successfully' });
  } catch (error) {
    console.error('Delete live chat conversation error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

// Delete live chat message endpoint
router.delete('/live-chat/messages/:messageId', authenticateToken, async (req, res) => {
  try {
    const { messageId } = req.params;
    const userId = req.user.id;
    const userRole = req.user.role;

    const { Pool } = require('pg');
    const pool = new Pool({
      user: process.env.DB_USER,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      password: process.env.DB_PASSWORD,
      port: process.env.DB_PORT,
    });

    // Check if user has access to this message
    const messageResult = await pool.query(`
      SELECT cm.*, cc.user_id, cc.admin_id
      FROM chat_messages cm
      JOIN chat_conversations cc ON cm.conversation_id = cc.id
      WHERE cm.id = $1 AND cm.deleted_at IS NULL
    `, [messageId]);

    if (messageResult.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Message not found' });
    }

    const message = messageResult.rows[0];
    
    // Permission check: user can only delete their own messages or if they own the conversation
    const canDelete = (message.sender_id === userId) ||
                     (message.user_id === userId) ||
                     (message.admin_id === userId) ||
                     (userRole === 'admin' || userRole === 'technician');

    if (!canDelete) {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    // Soft delete message
    await pool.query(
      'UPDATE chat_messages SET deleted_at = CURRENT_TIMESTAMP WHERE id = $1',
      [messageId]
    );

    res.json({ success: true, message: 'Message deleted successfully' });
  } catch (error) {
    console.error('Delete live chat message error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

// Performance monitoring endpoints (admin only)
router.get('/health', authenticateToken, async (req, res) => {
  try {
    const userRole = req.user.role;

    // Only allow admin and technician to access health metrics
    if (userRole !== 'admin' && userRole !== 'technician') {
      return res.status(403).json({
        success: false,
        error: 'Access denied: Admin or technician only'
      });
    }

    const health = await healthCheck();
    res.json({ success: true, health });
  } catch (error) {
    console.error('Health check error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

router.get('/performance', authenticateToken, async (req, res) => {
  try {
    const userRole = req.user.role;

    // Only allow admin and technician to access performance metrics
    if (userRole !== 'admin' && userRole !== 'technician') {
      return res.status(403).json({
        success: false,
        error: 'Access denied: Admin or technician only'
      });
    }

    const cacheStats = getCacheStats();
    const health = await healthCheck();

    res.json({
      success: true,
      performance: {
        cache: cacheStats,
        database: health,
        timestamp: new Date().toISOString()
      }
    });
  } catch (error) {
    console.error('Performance check error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

router.post('/cache/clear', authenticateToken, async (req, res) => {
  try {
    const userRole = req.user.role;

    // Only allow admin to clear cache
    if (userRole !== 'admin') {
      return res.status(403).json({
        success: false,
        error: 'Access denied: Admin only'
      });
    }

    clearAllCaches();
    res.json({ success: true, message: 'All caches cleared successfully' });
  } catch (error) {
    console.error('Cache clear error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

router.post('/live-chat/mark-read/:conversationId', authenticateToken, async (req, res) => {
  try {
    const { conversationId } = req.params;
    const userId = req.user.id;
    const userRole = req.user.role;

    const { Pool } = require('pg');
    const pool = new Pool({
      user: process.env.DB_USER,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      password: process.env.DB_PASSWORD,
      port: process.env.DB_PORT,
    });

    // Check if user has access to this conversation
    const convResult = await pool.query(
      'SELECT * FROM chat_conversations WHERE id = $1',
      [conversationId]
    );

    if (convResult.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Conversation not found' });
    }

    const conversation = convResult.rows[0];
    
    // Determine who can mark messages as read
    let senderCondition;
    if (userRole === 'admin' || userRole === 'technician') {
      // Staff can mark user messages as read
      senderCondition = "cm.sender_type != 'admin' AND cm.sender_type != 'technician'";
    } else {
      // Users can mark staff messages as read
      senderCondition = "cm.sender_type != 'user'";
    }

    // Check if user is part of this conversation
    const isParticipant = conversation.user_id === userId || conversation.admin_id === userId ||
                         (userRole === 'admin' || userRole === 'technician');
    
    if (!isParticipant) {
      return res.status(403).json({ success: false, error: 'Access denied' });
    }

    // Mark unread messages as read
    const updateResult = await pool.query(
      `UPDATE chat_messages
       SET is_read = true, read_at = CURRENT_TIMESTAMP
       WHERE conversation_id = $1
         AND is_read = false
         AND (${senderCondition})
       RETURNING id`,
      [conversationId]
    );

    // Get updated unread count
    const unreadCountResult = await pool.query(
      `SELECT COUNT(*) as unread_count
       FROM chat_messages cm
       WHERE cm.conversation_id = $1
         AND cm.is_read = false
         AND (${senderCondition})`,
      [conversationId]
    );

    res.json({
      success: true,
      messages_marked_read: updateResult.rowCount,
      remaining_unread: parseInt(unreadCountResult.rows[0].unread_count),
      message: `Marked ${updateResult.rowCount} message(s) as read`
    });
  } catch (error) {
    console.error('Mark messages as read error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

router.get('/live-chat/unread-count', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const userRole = req.user.role;

    const { Pool } = require('pg');
    const pool = new Pool({
      user: process.env.DB_USER,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      password: process.env.DB_PASSWORD,
      port: process.env.DB_PORT,
    });

    let unreadQuery, values;
    if (userRole === 'admin' || userRole === 'technician') {
      // Staff gets total unread from all users
      unreadQuery = `
        SELECT
          cc.id as conversation_id,
          cc.title,
          u.name as user_name,
          COUNT(cm.id) as unread_count,
          MAX(cm.created_at) as last_message_time
        FROM chat_conversations cc
        JOIN users u ON cc.user_id = u.id
        LEFT JOIN chat_messages cm ON cm.conversation_id = cc.id
          AND cm.is_read = false
          AND cm.sender_type != 'admin'
          AND cm.sender_type != 'technician'
        WHERE cc.conversation_type = 'live'
          AND cc.deleted_at IS NULL
          AND cc.status = 'active'
        GROUP BY cc.id, cc.title, u.name
        HAVING COUNT(cm.id) > 0
        ORDER BY last_message_time DESC
      `;
      values = [];
    } else {
      // Users get their unread count
      unreadQuery = `
        SELECT
          cc.id as conversation_id,
          cc.title,
          COUNT(cm.id) as unread_count,
          MAX(cm.created_at) as last_message_time
        FROM chat_conversations cc
        LEFT JOIN chat_messages cm ON cm.conversation_id = cc.id
          AND cm.is_read = false
          AND cm.sender_type != 'user'
        WHERE cc.user_id = $1
          AND cc.conversation_type = 'live'
          AND cc.deleted_at IS NULL
          AND cc.status = 'active'
        GROUP BY cc.id, cc.title
        HAVING COUNT(cm.id) > 0
        ORDER BY last_message_time DESC
      `;
      values = [userId];
    }

    const result = await pool.query(unreadQuery, values);
    
    // Get total unread count
    const totalUnread = result.rows.reduce((sum, row) => sum + row.unread_count, 0);

    res.json({
      success: true,
      total_unread: totalUnread,
      conversations_with_unread: result.rows,
      last_checked: new Date().toISOString()
    });
  } catch (error) {
    console.error('Get unread count error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

router.get('/live-chat/users', authenticateToken, async (req, res) => {
  try {
    const userRole = req.user.role;
    
    // Only allow admin and technician to load users for live chat
    if (userRole !== 'admin' && userRole !== 'technician') {
      return res.status(403).json({
        success: false,
        error: 'Access denied: Admin or technician only'
      });
    }

    const { Pool } = require('pg');
    const pool = new Pool({
      user: process.env.DB_USER,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      password: process.env.DB_PASSWORD,
      port: process.env.DB_PORT,
    });

    // Load users who can be chatted with (regular users/students, excluding staff)
    const usersResult = await pool.query(
      `SELECT id, name, email, role, created_at
       FROM users
       WHERE role = 'user'
         AND deleted_at IS NULL
       ORDER BY name ASC`,
      []
    );

    // Sanitize and return users
    const sanitizedUsers = usersResult.rows.map(user => ({
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      created_at: user.created_at
    }));

    res.json({
      success: true,
      users: sanitizedUsers,
      count: sanitizedUsers.length
    });
  } catch (error) {
    console.error('Load live chat users error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to load users: ' + (error.message || 'Internal server error')
    });
  }
});

module.exports = router;