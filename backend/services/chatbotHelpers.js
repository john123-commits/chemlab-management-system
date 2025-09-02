// services/chatbotHelpers.js
const { Pool } = require('pg');
const pool = new Pool({
  user: process.env.DB_USER,
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  password: process.env.DB_PASSWORD,
  port: process.env.DB_PORT,
});

async function getQuickActionsForRole(role) {
  try {
    // Query database for quick actions based on role
    const result = await pool.query(
      'SELECT action_name, display_text, icon, role_required FROM chat_quick_actions WHERE is_active = true AND (role_required = $1 OR role_required = $2) ORDER BY id',
      [role, 'borrower']
    );
    
    // If database query succeeds and returns data, use it
    if (result.rows.length > 0) {
      return result.rows;
    }
    
    // Fallback to default actions if database query fails or returns no data
    return getDefaultQuickActions(role);
  } catch (error) {
    console.error('Quick actions database query error:', error);
    // Return default actions if database query fails
    return getDefaultQuickActions(role);
  }
}

function getDefaultQuickActions(role) {
  switch (role) {
    case 'admin':
      return [
        { action_name: 'view_chemicals', display_text: 'Chemicals', icon: 'science', role_required: 'borrower' },
        { action_name: 'view_equipment', display_text: 'Equipment', icon: 'build', role_required: 'borrower' },
        { action_name: 'my_requests', display_text: 'My Requests', icon: 'assignment', role_required: 'borrower' },
        { action_name: 'lab_schedule', display_text: 'Lab Schedule', icon: 'calendar_today', role_required: 'borrower' },
        { action_name: 'safety_info', display_text: 'Safety Info', icon: 'warning', role_required: 'borrower' },
        { action_name: 'borrow_equipment', display_text: 'Borrow Items', icon: 'add_shopping_cart', role_required: 'borrower' },
        { action_name: 'manage_chemicals', display_text: 'Manage Chemicals', icon: 'science', role_required: 'admin' },
        { action_name: 'manage_equipment', display_text: 'Manage Equipment', icon: 'build', role_required: 'admin' },
        { action_name: 'review_requests', display_text: 'Review Requests', icon: 'assignment', role_required: 'admin' },
        { action_name: 'view_alerts', display_text: 'System Alerts', icon: 'warning', role_required: 'admin' },
        { action_name: 'manage_users', display_text: 'Manage Users', icon: 'people', role_required: 'admin' }
      ];
    case 'technician':
      return [
        { action_name: 'view_chemicals', display_text: 'Chemicals', icon: 'science', role_required: 'borrower' },
        { action_name: 'view_equipment', display_text: 'Equipment', icon: 'build', role_required: 'borrower' },
        { action_name: 'my_requests', display_text: 'My Requests', icon: 'assignment', role_required: 'borrower' },
        { action_name: 'lab_schedule', display_text: 'Lab Schedule', icon: 'calendar_today', role_required: 'borrower' },
        { action_name: 'safety_info', display_text: 'Safety Info', icon: 'warning', role_required: 'borrower' },
        { action_name: 'borrow_equipment', display_text: 'Borrow Items', icon: 'add_shopping_cart', role_required: 'borrower' },
        { action_name: 'manage_chemicals', display_text: 'Manage Chemicals', icon: 'science', role_required: 'technician' },
        { action_name: 'manage_equipment', display_text: 'Manage Equipment', icon: 'build', role_required: 'technician' },
        { action_name: 'review_requests', display_text: 'Review Requests', icon: 'assignment', role_required: 'technician' },
        { action_name: 'view_alerts', display_text: 'System Alerts', icon: 'warning', role_required: 'technician' }
      ];
    default: // borrower
      return [
        { action_name: 'view_chemicals', display_text: 'Chemicals', icon: 'science', role_required: 'borrower' },
        { action_name: 'view_equipment', display_text: 'Equipment', icon: 'build', role_required: 'borrower' },
        { action_name: 'my_requests', display_text: 'My Requests', icon: 'assignment', role_required: 'borrower' },
        { action_name: 'lab_schedule', display_text: 'Lab Schedule', icon: 'calendar_today', role_required: 'borrower' },
        { action_name: 'safety_info', display_text: 'Safety Info', icon: 'warning', role_required: 'borrower' },
        { action_name: 'borrow_equipment', display_text: 'Borrow Items', icon: 'add_shopping_cart', role_required: 'borrower' }
      ];
  }
}

async function getUserChatHistory(userId) {
  try {
    const result = await pool.query(
      'SELECT message_text, sender_type, created_at FROM chat_messages cm JOIN chat_conversations cc ON cm.conversation_id = cc.id WHERE cc.user_id = $1 ORDER BY cm.created_at DESC LIMIT 20',
      [userId]
    );
    
    return result.rows;
  } catch (error) {
    console.error('Chat history query error:', error);
    return [];
  }
}

// Enhanced function to get user's recent borrowing activity
async function getUserRecentActivity(userId) {
  try {
    const result = await pool.query(
      `SELECT 
        b.id,
        b.status,
        b.created_at,
        c.name as chemical_name,
        e.name as equipment_name
      FROM borrowings b
      LEFT JOIN chemicals c ON b.chemical_id = c.id
      LEFT JOIN equipment e ON b.equipment_id = e.id
      WHERE b.borrower_id = $1
      ORDER BY b.created_at DESC
      LIMIT 5`,
      [userId]
    );
    
    return result.rows;
  } catch (error) {
    console.error('User recent activity query error:', error);
    return [];
  }
}

// Enhanced function to get upcoming schedules
async function getUpcomingSchedules(limit = 5) {
  try {
    const today = new Date().toISOString().split('T')[0];
    const result = await pool.query(
      `SELECT 
        ls.id,
        ls.lab_name,
        ls.course_name,
        ls.date,
        ls.start_time,
        ls.end_time
      FROM lecture_schedules ls
      WHERE ls.date >= $1
      ORDER BY ls.date, ls.start_time
      LIMIT $2`,
      [today, limit]
    );
    
    return result.rows;
  } catch (error) {
    console.error('Upcoming schedules query error:', error);
    return [];
  }
}

// Enhanced function to get system alerts
async function getSystemAlerts(limit = 5) {
  try {
    const result = await pool.query(
      `SELECT 
        message,
        type,
        created_at
      FROM alerts
      WHERE created_at >= NOW() - INTERVAL '30 days'
      ORDER BY created_at DESC
      LIMIT $1`,
      [limit]
    );
    
    return result.rows;
  } catch (error) {
    console.error('System alerts query error:', error);
    return [];
  }
}

module.exports = {
  getQuickActionsForRole,
  getUserChatHistory,
  getUserRecentActivity,
  getUpcomingSchedules,
  getSystemAlerts
};