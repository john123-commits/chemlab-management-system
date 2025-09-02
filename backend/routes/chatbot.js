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

    const result = await pool.query(
      'INSERT INTO chat_conversations (user_id, admin_id, conversation_type, status, title) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [userId, adminId, 'live', 'active', title || 'Live Support']
    );

    // Send initial message
    await pool.query(
      'INSERT INTO chat_messages (conversation_id, sender_type, sender_id, message_text, message_type) VALUES ($1, $2, $3, $4, $5)',
      [result.rows[0].id, 'admin', adminId, 'Hello! How can I help you today?', 'text']
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
    const senderType = req.user.role === 'admin' || req.user.role === 'technician' ? 'admin' : 'user';

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

    let query, values;
    if (userRole === 'admin' || userRole === 'technician') {
      // Admin/technician sees all conversations
      query = 'SELECT * FROM chat_conversations WHERE conversation_type = $1 ORDER BY updated_at DESC';
      values = ['live'];
    } else {
      // User sees only their conversations
      query = 'SELECT * FROM chat_conversations WHERE user_id = $1 AND conversation_type = $2 ORDER BY updated_at DESC';
      values = [userId, 'live'];
    }

    const result = await pool.query(query, values);
    res.json({ success: true, conversations: result.rows });
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
      'SELECT cm.*, u.name as sender_name FROM chat_messages cm LEFT JOIN users u ON cm.sender_id = u.id WHERE cm.conversation_id = $1 ORDER BY cm.created_at ASC',
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
      ['closed', conversationId]
    );

    res.json({ success: true, message: 'Conversation closed successfully' });
  } catch (error) {
    console.error('Close live chat conversation error:', error);
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

module.exports = router;