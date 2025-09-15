// Enhanced routes/chatbot.js - Aligned with existing structure
const express = require('express');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');

const { processChatMessage } = require('../services/chatbotService');
const { getQuickActionsForRole, getUserChatHistory } = require('../services/chatbotHelpers');
const { healthCheck, getCacheStats, clearAllCaches } = require('../utils/queryOptimizer');

// Enhanced performance logging utility
const logPerformance = (operation, startTime, metadata = {}) => {
  const duration = Date.now() - startTime;
  console.log(`[PERF] ${operation}: ${duration}ms`, metadata);
  
  // Log slow queries for optimization
  if (duration > 1000) {
    console.warn(`[PERF] SLOW_QUERY: ${operation} took ${duration}ms`, metadata);
  }
};

// Enhanced security logging utility
const logSecurity = (event, details) => {
  console.warn(`[SECURITY] ${event}:`, details);
};

// Enhanced query type classification function
function classifyQueryType(message) {
  const lowerMsg = message.toLowerCase();
  
  // Chemical-related queries
  if (lowerMsg.includes('chemical') || lowerMsg.includes('reagent') || 
      lowerMsg.includes('compound') || lowerMsg.includes('solution')) {
    return 'chemical_inquiry';
  }
  
  // Equipment-related queries
  if (lowerMsg.includes('equipment') || lowerMsg.includes('instrument') || 
      lowerMsg.includes('device') || lowerMsg.includes('apparatus')) {
    return 'equipment_inquiry';
  }
  
  // Safety-related queries
  if (lowerMsg.includes('safety') || lowerMsg.includes('hazard') || 
      lowerMsg.includes('ppe') || lowerMsg.includes('spill')) {
    return 'safety_query';
  }
  
  // Borrowing/request queries
  if (lowerMsg.includes('borrow') || lowerMsg.includes('request') || 
      lowerMsg.includes('book') || lowerMsg.includes('reserve')) {
    return 'borrowing_request';
  }
  
  // Schedule queries
  if (lowerMsg.includes('schedule') || lowerMsg.includes('when') || 
      lowerMsg.includes('booking') || lowerMsg.includes('time')) {
    return 'schedule_query';
  }
  
  // Inventory/status queries
  if (lowerMsg.includes('available') || lowerMsg.includes('stock') || 
      lowerMsg.includes('inventory') || lowerMsg.includes('status')) {
    return 'inventory_query';
  }
  
  // Help queries
  if (lowerMsg.includes('help') || lowerMsg.includes('what can')) {
    return 'help_request';
  }
  
  return 'general';
}

// Generate contextual suggestions based on response
function generateSuggestedActions(response, userRole) {
  const suggestions = [];
  const lowerResponse = response.toLowerCase();
  
  // Generate contextual suggestions based on response content
  if (lowerResponse.includes('low stock') || lowerResponse.includes('expiring')) {
    suggestions.push({
      display_text: 'View Details',
      icon: 'info',
      message: 'Show me more details about these items'
    });
    
    if (userRole === 'admin' || userRole === 'technician') {
      suggestions.push({
        display_text: 'Create Purchase Order',
        icon: 'assignment',
        message: 'Help me create a purchase order'
      });
    }
  }
  
  if (lowerResponse.includes('available') && lowerResponse.includes('chemical')) {
    suggestions.push({
      display_text: 'Borrow Chemical',
      icon: 'assignment',
      message: 'I want to borrow a chemical'
    });
    suggestions.push({
      display_text: 'Safety Info',
      icon: 'security',
      message: 'Show safety information for chemicals'
    });
  }
  
  if (lowerResponse.includes('equipment') && lowerResponse.includes('available')) {
    suggestions.push({
      display_text: 'Book Equipment',
      icon: 'build',
      message: 'I want to book equipment'
    });
    suggestions.push({
      display_text: 'Check Schedule',
      icon: 'calendar_today',
      message: 'When is this equipment available?'
    });
  }
  
  if (lowerResponse.includes('maintenance') || lowerResponse.includes('calibration')) {
    if (userRole === 'admin' || userRole === 'technician') {
      suggestions.push({
        display_text: 'Schedule Maintenance',
        icon: 'build',
        message: 'Schedule maintenance for equipment'
      });
    }
  }
  
  // Return default suggestions if none generated
  if (suggestions.length === 0) {
    return getDefaultQuickActionsByRole(userRole).slice(0, 3);
  }
  
  return suggestions.slice(0, 4);
}

// Default quick actions by role
function getDefaultQuickActionsByRole(userRole) {
  switch (userRole) {
    case 'technician':
      return [
        { display_text: 'Inventory Alerts', icon: 'warning', message: 'What inventory alerts do we have?' },
        { display_text: 'Equipment Status', icon: 'build', message: 'Show equipment maintenance status' },
        { display_text: 'Pending Requests', icon: 'assignment', message: 'Show pending borrowing requests' },
        { display_text: 'Safety Protocols', icon: 'security', message: 'Show safety procedures' }
      ];
      
    case 'admin':
      return [
        { display_text: 'System Overview', icon: 'analytics', message: 'Show system status overview' },
        { display_text: 'Usage Statistics', icon: 'info', message: 'Show usage statistics' },
        { display_text: 'All Alerts', icon: 'warning', message: 'Show all system alerts' },
        { display_text: 'Maintenance Schedule', icon: 'build', message: 'What equipment needs maintenance?' }
      ];
      
    default: // student and others
      return [
        { display_text: 'Available Chemicals', icon: 'science', message: 'What chemicals are available?' },
        { display_text: 'Equipment Booking', icon: 'build', message: 'Show available equipment for booking' },
        { display_text: 'Today\'s Schedule', icon: 'calendar_today', message: 'What\'s on the lab schedule today?' },
        { display_text: 'Safety Information', icon: 'security', message: 'Show safety procedures and guidelines' }
      ];
  }
}

// Enhanced chat message endpoint
router.post('/message', authenticateToken, async (req, res) => {
  const startTime = Date.now();
  try {
    const { message, userId, userRole, queryType } = req.body;

    // Validate required fields
    if (!message || !userId || !userRole) {
      logSecurity('MISSING_FIELDS', { 
        message: !!message, 
        userId: !!userId, 
        userRole: !!userRole, 
        ip: req.ip 
      });
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: message, userId, userRole'
      });
    }

    // Enhanced security logging with query type
    logSecurity('CHAT_MESSAGE_RECEIVED', {
      userId,
      userRole,
      messageLength: message.length,
      queryType: queryType || 'unspecified',
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });

    console.log('Chat message received:', { 
      message: message.substring(0, 100), 
      userId, 
      userRole,
      queryType 
    });

    // Classify query type if not provided
    const detectedQueryType = queryType || classifyQueryType(message);

    // Process message and generate response
    const response = await processChatMessage(message, userId, userRole);

    // Generate contextual suggestions
    const suggestedActions = generateSuggestedActions(response, userRole);

    logPerformance('CHAT_MESSAGE_PROCESSING', startTime, {
      userId,
      userRole,
      inputLength: message.length,
      outputLength: response.length,
      queryType: detectedQueryType
    });

    res.json({
      success: true,
      response: response,
      detectedQueryType: detectedQueryType,
      suggestedActions: suggestedActions,
      processingTime: Date.now() - startTime,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    logPerformance('CHAT_MESSAGE_ERROR', startTime, {
      userId: req.body?.userId,
      error: error.message
    });
    console.error('Chat message error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Internal server error',
      processingTime: Date.now() - startTime
    });
  }
});

// Enhanced quick actions endpoint with fallback
router.get('/quick-actions/:role', authenticateToken, async (req, res) => {
  const startTime = Date.now();
  try {
    const { role } = req.params;
    
    // Validate role parameter
    if (!role) {
      return res.status(400).json({ 
        success: false, 
        error: 'Missing role parameter' 
      });
    }
    
    let actions;
    try {
      // Try to get actions from service
      actions = await getQuickActionsForRole(role);
    } catch (serviceError) {
      console.warn('Service quick actions failed, using defaults:', serviceError.message);
      // Fallback to default actions
      actions = getDefaultQuickActionsByRole(role);
    }

    logPerformance('QUICK_ACTIONS_LOAD', startTime, { role, actionCount: actions.length });

    res.json({ 
      success: true, 
      actions,
      role,
      source: actions.length > 0 ? 'service' : 'default'
    });
  } catch (error) {
    console.error('Quick actions error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message || 'Internal server error' 
    });
  }
});

// Enhanced conversation history endpoint
router.get('/history', authenticateToken, async (req, res) => {
  const startTime = Date.now();
  try {
    const userId = req.user.id;
    const limit = parseInt(req.query.limit) || 50;
    const queryType = req.query.queryType; // Optional filter
    
    if (!userId) {
      return res.status(400).json({ 
        success: false, 
        error: 'User ID not found in request' 
      });
    }
    
    // Get filtered history if queryType specified
    let history;
    if (queryType) {
      history = await getUserChatHistory(userId, { limit, queryType });
    } else {
      history = await getUserChatHistory(userId, { limit });
    }

    logPerformance('CHAT_HISTORY_LOAD', startTime, { 
      userId, 
      historyCount: history.length,
      queryType: queryType || 'all'
    });

    res.json({ 
      success: true, 
      history,
      filters: { limit, queryType: queryType || 'all' },
      count: history.length
    });
  } catch (error) {
    console.error('Chat history error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message || 'Internal server error' 
    });
  }
});

// Enhanced system status endpoint with query type analytics
router.get('/system-status', authenticateToken, async (req, res) => {
  const startTime = Date.now();
  try {
    const userRole = req.user.role;

    // Only allow staff to access system status
    if (userRole !== 'admin' && userRole !== 'technician') {
      return res.status(403).json({
        success: false,
        error: 'Access denied: Staff only'
      });
    }

    // Get comprehensive system status
    const [health, cacheStats] = await Promise.all([
      healthCheck(),
      Promise.resolve(getCacheStats())
    ]);

    // Get query type analytics for the last 24 hours
    const { Pool } = require('pg');
    const pool = new Pool({
      user: process.env.DB_USER,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      password: process.env.DB_PASSWORD,
      port: process.env.DB_PORT,
    });

    const queryAnalytics = await pool.query(`
      SELECT 
        query_type,
        COUNT(*) as count,
        AVG(EXTRACT(EPOCH FROM (updated_at - created_at)) * 1000) as avg_response_time_ms
      FROM chatbot_audit_log 
      WHERE created_at >= NOW() - INTERVAL '24 hours'
        AND query_type IS NOT NULL
      GROUP BY query_type
      ORDER BY count DESC
    `);

    const topUsers = await pool.query(`
      SELECT 
        user_id,
        COUNT(*) as message_count,
        MAX(created_at) as last_activity
      FROM chatbot_audit_log 
      WHERE created_at >= NOW() - INTERVAL '24 hours'
        AND response_type = 'user_query'
      GROUP BY user_id
      ORDER BY message_count DESC
      LIMIT 10
    `);

    logPerformance('SYSTEM_STATUS_LOAD', startTime, { userRole });

    res.json({
      success: true,
      system_status: {
        health,
        cache: cacheStats,
        analytics: {
          query_types: queryAnalytics.rows,
          top_users: topUsers.rows,
          period: '24 hours'
        },
        timestamp: new Date().toISOString()
      }
    });
  } catch (error) {
    console.error('System status error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message || 'Internal server error' 
    });
  }
});

// Clear conversation context endpoint
router.delete('/context/:userId', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    const requesterId = req.user.id;
    const requesterRole = req.user.role;
    
    // Users can only clear their own context, staff can clear any
    if (userId != requesterId && requesterRole !== 'admin' && requesterRole !== 'technician') {
      return res.status(403).json({
        success: false,
        error: 'Access denied'
      });
    }

    const { clearConversationContext } = require('../services/apiService');
    
    // Clear user's conversation context
    await clearConversationContext(userId);
    
    res.json({
      success: true,
      message: 'Conversation context cleared successfully'
    });
  } catch (error) {
    console.error('Context clearing error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to clear conversation context'
    });
  }
});

// Query type statistics endpoint
router.get('/query-analytics', authenticateToken, async (req, res) => {
  try {
    const userRole = req.user.role;
    const timeframe = req.query.timeframe || '7d'; // 1d, 7d, 30d

    // Only allow staff to access analytics
    if (userRole !== 'admin' && userRole !== 'technician') {
      return res.status(403).json({
        success: false,
        error: 'Access denied: Staff only'
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

    const intervalMap = {
      '1d': '1 day',
      '7d': '7 days',
      '30d': '30 days'
    };

    const interval = intervalMap[timeframe] || '7 days';

    const queryStats = await pool.query(`
      SELECT 
        query_type,
        COUNT(*) as total_queries,
        COUNT(DISTINCT user_id) as unique_users,
        AVG(CASE 
          WHEN response_type = 'assistant_response' THEN 
            EXTRACT(EPOCH FROM (updated_at - created_at)) * 1000 
        END) as avg_response_time_ms,
        DATE_TRUNC('day', created_at) as date
      FROM chatbot_audit_log 
      WHERE created_at >= NOW() - INTERVAL '${interval}'
        AND query_type IS NOT NULL
      GROUP BY query_type, DATE_TRUNC('day', created_at)
      ORDER BY date DESC, total_queries DESC
    `);

    res.json({
      success: true,
      analytics: {
        timeframe,
        data: queryStats.rows,
        generated_at: new Date().toISOString()
      }
    });
  } catch (error) {
    console.error('Query analytics error:', error);
    res.status(500).json({
      success: false,
      error: error.message || 'Internal server error'
    });
  }
});

// Keep all your existing live chat endpoints unchanged
// ... (all the live chat routes from your original file remain the same)

// User recent activity endpoint (unchanged from your original)
router.get('/user-activity', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.id;
    
    if (!userId) {
      return res.status(400).json({ 
        success: false, 
        error: 'User ID not found in request' 
      });
    }
    
    const { getUserRecentActivity } = require('../services/chatbotHelpers');
    const activity = await getUserRecentActivity(userId);
    res.json({ success: true, activity });
  } catch (error) {
    console.error('User activity error:', error);
    res.status(500).json({ success: false, error: error.message || 'Internal server error' });
  }
});

// Performance monitoring endpoints (unchanged from your original)
router.get('/health', authenticateToken, async (req, res) => {
  try {
    const userRole = req.user.role;

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

// Add all your existing live chat endpoints here...
// (I'm not repeating them to keep this focused on the enhancements)

module.exports = router;