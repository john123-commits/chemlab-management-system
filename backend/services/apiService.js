// services/apiService.js
const { Pool } = require('pg');
const {
  getPool,
  getChemicalsOptimized,
  getEquipmentOptimized,
  searchChemicalsOptimized,
  searchEquipmentOptimized
} = require('../utils/queryOptimizer');

// Use optimized pool
const pool = getPool();

// Chemical functions
async function getChemicals(filters = {}) {
  try {
    let query = 'SELECT * FROM chemicals WHERE 1=1';
    const values = [];
    let paramCount = 1;

    // Add filters if provided
    if (filters.status) {
      query += ` AND status = $${paramCount}`;
      values.push(filters.status);
      paramCount++;
    }

    const result = await pool.query(query, values);
    return result.rows;
  } catch (error) {
    console.error('Database error in getChemicals:', error);
    return [];
  }
}

// Enhanced chemical function for detailed queries
async function getChemicalByName(name) {
  try {
    const result = await pool.query(
      'SELECT * FROM chemicals WHERE LOWER(name) LIKE LOWER($1) LIMIT 1', 
      [`%${name}%`]
    );
    return result.rows[0];
  } catch (error) {
    console.error('Database error in getChemicalByName:', error);
    return null;
  }
}

// Search chemicals function (optimized)
async function searchChemicals(searchTerm) {
  try {
    return await searchChemicalsOptimized(searchTerm);
  } catch (error) {
    console.error('Database error in searchChemicals:', error);
    return [];
  }
}

// Equipment functions
async function getEquipment() {
  try {
    const result = await pool.query('SELECT * FROM equipment');
    return result.rows;
  } catch (error) {
    console.error('Database error in getEquipment:', error);
    return [];
  }
}

// Enhanced equipment function for detailed queries
async function getEquipmentByName(name) {
  try {
    const result = await pool.query(
      'SELECT * FROM equipment WHERE LOWER(name) LIKE LOWER($1) LIMIT 1', 
      [`%${name}%`]
    );
    return result.rows[0];
  } catch (error) {
    console.error('Database error in getEquipmentByName:', error);
    return null;
  }
}

// Search equipment function (optimized)
async function searchEquipment(searchTerm) {
  try {
    return await searchEquipmentOptimized(searchTerm);
  } catch (error) {
    console.error('Database error in searchEquipment:', error);
    return [];
  }
}

// Borrowing functions
async function getBorrowings() {
  try {
    const result = await pool.query('SELECT * FROM borrowings');
    return result.rows;
  } catch (error) {
    console.error('Database error in getBorrowings:', error);
    return [];
  }
}

// User functions
async function getUserInfo(userId) {
  try {
    const result = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);
    return result.rows[0];
  } catch (error) {
    console.error('Database error in getUserInfo:', error);
    return null;
  }
}

// Lecture schedule functions
async function getLectureSchedules() {
  try {
    const result = await pool.query('SELECT * FROM lecture_schedules');
    return result.rows;
  } catch (error) {
    console.error('Database error in getLectureSchedules:', error);
    return [];
  }
}

// Create borrowing function
async function createBorrowing(borrowingData) {
  try {
    const { borrower_id, chemical_id, equipment_id, quantity, start_date, end_date, purpose } = borrowingData;
    
    // Handle null values for chemical_id or equipment_id
    const result = await pool.query(
      'INSERT INTO borrowings (borrower_id, chemical_id, equipment_id, quantity, start_date, end_date, purpose) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [borrower_id, chemical_id || null, equipment_id || null, quantity, start_date, end_date, purpose]
    );
    
    return result.rows[0];
  } catch (error) {
    console.error('Database error in createBorrowing:', error);
    throw error;
  }
}

// Additional helper functions that might be needed
async function getChemicalById(id) {
  try {
    const result = await pool.query('SELECT * FROM chemicals WHERE id = $1', [id]);
    return result.rows[0];
  } catch (error) {
    console.error('Database error in getChemicalById:', error);
    return null;
  }
}

async function getEquipmentById(id) {
  try {
    const result = await pool.query('SELECT * FROM equipment WHERE id = $1', [id]);
    return result.rows[0];
  } catch (error) {
    console.error('Database error in getEquipmentById:', error);
    return null;
  }
}

async function getUserById(id) {
  try {
    const result = await pool.query('SELECT id, name, email, role, created_at FROM users WHERE id = $1', [id]);
    return result.rows[0];
  } catch (error) {
    console.error('Database error in getUserById:', error);
    return null;
  }
}

// Enhanced borrowing functions for detailed status
async function getBorrowingById(id) {
  try {
    const result = await pool.query('SELECT * FROM borrowings WHERE id = $1', [id]);
    return result.rows[0];
  } catch (error) {
    console.error('Database error in getBorrowingById:', error);
    return null;
  }
}

async function getUserBorrowings(userId) {
  try {
    const result = await pool.query(
      'SELECT * FROM borrowings WHERE borrower_id = $1 ORDER BY created_at DESC', 
      [userId]
    );
    return result.rows;
  } catch (error) {
    console.error('Database error in getUserBorrowings:', error);
    return [];
  }
}

// Enhanced schedule functions
async function getScheduleById(id) {
  try {
    const result = await pool.query('SELECT * FROM lecture_schedules WHERE id = $1', [id]);
    return result.rows[0];
  } catch (error) {
    console.error('Database error in getScheduleById:', error);
    return null;
  }
}

async function getSchedulesByDate(date) {
  try {
    const result = await pool.query(
      'SELECT * FROM lecture_schedules WHERE date = $1 ORDER BY start_time', 
      [date]
    );
    return result.rows;
  } catch (error) {
    console.error('Database error in getSchedulesByDate:', error);
    return [];
  }
}

// Enhanced chemical functions for advanced queries
async function getChemicalsByCategory(category) {
  try {
    const result = await pool.query(
      'SELECT * FROM chemicals WHERE LOWER(category) = LOWER($1) ORDER BY name',
      [category]
    );
    return result.rows;
  } catch (error) {
    console.error('Database error in getChemicalsByCategory:', error);
    return [];
  }
}

async function getLowStockChemicals(threshold = 10) {
  try {
    const result = await pool.query(
      'SELECT * FROM chemicals WHERE quantity <= $1 AND quantity > 0 ORDER BY quantity ASC',
      [threshold]
    );
    return result.rows;
  } catch (error) {
    console.error('Database error in getLowStockChemicals:', error);
    return [];
  }
}

async function getExpiringChemicals(days = 30) {
  try {
    const result = await pool.query(
      'SELECT * FROM chemicals WHERE expiry_date <= CURRENT_DATE + INTERVAL \'1 day\' * $1 AND expiry_date >= CURRENT_DATE ORDER BY expiry_date ASC',
      [days]
    );
    return result.rows;
  } catch (error) {
    console.error('Database error in getExpiringChemicals:', error);
    return [];
  }
}

async function getExpiredChemicals() {
  try {
    const result = await pool.query(
      'SELECT * FROM chemicals WHERE expiry_date < CURRENT_DATE ORDER BY expiry_date ASC'
    );
    return result.rows;
  } catch (error) {
    console.error('Database error in getExpiredChemicals:', error);
    return [];
  }
}

async function searchChemicalsAdvanced(searchTerm, filters = {}) {
  try {
    let query = `
      SELECT * FROM chemicals
      WHERE (LOWER(name) LIKE LOWER($1)
             OR LOWER(category) LIKE LOWER($1)
             OR LOWER(c_number) LIKE LOWER($1)
             OR LOWER(molecular_formula) LIKE LOWER($1))
    `;
    const values = [`%${searchTerm}%`];
    let paramCount = 2;

    // Add category filter
    if (filters.category) {
      query += ` AND LOWER(category) = LOWER($${paramCount})`;
      values.push(filters.category);
      paramCount++;
    }

    // Add availability filter
    if (filters.minQuantity !== undefined) {
      query += ` AND quantity >= $${paramCount}`;
      values.push(filters.minQuantity);
      paramCount++;
    }

    // Add expiry filter
    if (filters.notExpired === true) {
      query += ` AND expiry_date >= CURRENT_DATE`;
    }

    query += ' ORDER BY name LIMIT 20';

    const result = await pool.query(query, values);
    return result.rows;
  } catch (error) {
    console.error('Database error in searchChemicalsAdvanced:', error);
    return [];
  }
}

// Enhanced equipment functions
async function getEquipmentByCategory(category) {
  try {
    const result = await pool.query(
      'SELECT * FROM equipment WHERE LOWER(category) = LOWER($1) ORDER BY name',
      [category]
    );
    return result.rows;
  } catch (error) {
    console.error('Database error in getEquipmentByCategory:', error);
    return [];
  }
}

async function getAvailableEquipment() {
  try {
    // Get equipment that is not currently borrowed
    const result = await pool.query(`
      SELECT e.* FROM equipment e
      WHERE e.id NOT IN (
        SELECT DISTINCT b.equipment_id
        FROM borrowings b
        WHERE b.status = 'approved'
        AND b.return_date >= CURRENT_DATE
        AND b.equipment_id IS NOT NULL
      )
      ORDER BY e.name
    `);
    return result.rows;
  } catch (error) {
    console.error('Database error in getAvailableEquipment:', error);
    return [];
  }
}

async function getEquipmentDueForMaintenance() {
  try {
    const result = await pool.query(`
      SELECT *,
             CURRENT_DATE - last_maintenance_date as days_since_maintenance,
             maintenance_schedule - (CURRENT_DATE - last_maintenance_date) as days_until_next
      FROM equipment
      WHERE CURRENT_DATE - last_maintenance_date >= maintenance_schedule
      ORDER BY (CURRENT_DATE - last_maintenance_date) - maintenance_schedule DESC
    `);
    return result.rows;
  } catch (error) {
    console.error('Database error in getEquipmentDueForMaintenance:', error);
    return [];
  }
}

async function getEquipmentNeedingCalibration() {
  try {
    const result = await pool.query(`
      SELECT * FROM equipment
      WHERE next_calibration_date IS NOT NULL
      AND next_calibration_date <= CURRENT_DATE
      ORDER BY next_calibration_date ASC
    `);
    return result.rows;
  } catch (error) {
    console.error('Database error in getEquipmentNeedingCalibration:', error);
    return [];
  }
}

async function searchEquipmentAdvanced(searchTerm, filters = {}) {
  try {
    let query = `
      SELECT * FROM equipment
      WHERE (LOWER(name) LIKE LOWER($1)
             OR LOWER(category) LIKE LOWER($1)
             OR LOWER(manufacturer) LIKE LOWER($1)
             OR LOWER(model) LIKE LOWER($1)
             OR LOWER(serial_number) LIKE LOWER($1))
    `;
    const values = [`%${searchTerm}%`];
    let paramCount = 2;

    // Add category filter
    if (filters.category) {
      query += ` AND LOWER(category) = LOWER($${paramCount})`;
      values.push(filters.category);
      paramCount++;
    }

    // Add condition filter
    if (filters.condition) {
      query += ` AND LOWER(condition) = LOWER($${paramCount})`;
      values.push(filters.condition);
      paramCount++;
    }

    // Add availability filter
    if (filters.availableOnly === true) {
      query += ` AND id NOT IN (
        SELECT DISTINCT equipment_id
        FROM borrowings
        WHERE status = 'approved'
        AND return_date >= CURRENT_DATE
        AND equipment_id IS NOT NULL
      )`;
    }

    query += ' ORDER BY name LIMIT 20';

    const result = await pool.query(query, values);
    return result.rows;
  } catch (error) {
    console.error('Database error in searchEquipmentAdvanced:', error);
    return [];
  }
}

// Chemical compatibility and safety functions
async function getIncompatibleChemicals(chemicalId) {
  try {
    // This would require a compatibility table in the database
    // For now, return empty array as placeholder
    return [];
  } catch (error) {
    console.error('Database error in getIncompatibleChemicals:', error);
    return [];
  }
}

async function getChemicalsRequiringSpecialStorage() {
  try {
    const result = await pool.query(`
      SELECT * FROM chemicals
      WHERE storage_conditions IS NOT NULL
      AND storage_conditions != ''
      ORDER BY name
    `);
    return result.rows;
  } catch (error) {
    console.error('Database error in getChemicalsRequiringSpecialStorage:', error);
    return [];
  }
}

// Equipment booking functions
async function checkEquipmentAvailability(equipmentId, startDate, endDate) {
  try {
    const result = await pool.query(`
      SELECT COUNT(*) as conflicts FROM borrowings
      WHERE equipment_id = $1
      AND status = 'approved'
      AND (
        (borrow_date <= $2 AND return_date >= $2) OR
        (borrow_date <= $3 AND return_date >= $3) OR
        (borrow_date >= $2 AND return_date <= $3)
      )
    `, [equipmentId, startDate, endDate]);

    return parseInt(result.rows[0].conflicts) === 0;
  } catch (error) {
    console.error('Database error in checkEquipmentAvailability:', error);
    return false;
  }
}

async function getEquipmentBookings(equipmentId, limit = 10) {
  try {
    const result = await pool.query(`
      SELECT b.*, u.name as borrower_name
      FROM borrowings b
      JOIN users u ON b.borrower_id = u.id
      WHERE b.equipment_id = $1
      AND b.status IN ('approved', 'pending')
      ORDER BY b.borrow_date ASC
      LIMIT $2
    `, [equipmentId, limit]);
    return result.rows;
  } catch (error) {
    console.error('Database error in getEquipmentBookings:', error);
    return [];
  }
}

// Audit logging functions
async function logChatbotQuery(userId, query, response, queryType) {
  try {
    await pool.query(`
      INSERT INTO chatbot_audit_log (user_id, query_text, response_text, query_type, created_at)
      VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
    `, [userId, query, response, queryType]);
  } catch (error) {
    console.error('Database error in logChatbotQuery:', error);
    // Don't throw error for logging failures
  }
}

async function getChatbotUsageStats(userId = null, days = 30) {
  try {
    let query, values;
    if (userId) {
      query = `
        SELECT query_type, COUNT(*) as count
        FROM chatbot_audit_log
        WHERE user_id = $1 AND created_at >= CURRENT_TIMESTAMP - INTERVAL '${days} days'
        GROUP BY query_type
        ORDER BY count DESC
      `;
      values = [userId];
    } else {
      query = `
        SELECT query_type, COUNT(*) as count
        FROM chatbot_audit_log
        WHERE created_at >= CURRENT_TIMESTAMP - INTERVAL '${days} days'
        GROUP BY query_type
        ORDER BY count DESC
      `;
      values = [];
    }

    const result = await pool.query(query, values);
    return result.rows;
  } catch (error) {
    console.error('Database error in getChatbotUsageStats:', error);
    return [];
  }
}

// Conversation context management functions
async function getOrCreateConversation(userId) {
  try {
    // Try to find existing active conversation
    const existingResult = await pool.query(
      'SELECT * FROM chat_conversations WHERE user_id = $1 AND status = $2 ORDER BY updated_at DESC LIMIT 1',
      [userId, 'active']
    );

    if (existingResult.rows.length > 0) {
      return existingResult.rows[0];
    }

    // Create new conversation
    const newResult = await pool.query(
      'INSERT INTO chat_conversations (user_id, conversation_type, status) VALUES ($1, $2, $3) RETURNING *',
      [userId, 'bot', 'active']
    );

    return newResult.rows[0];
  } catch (error) {
    console.error('Database error in getOrCreateConversation:', error);
    return null;
  }
}

async function getConversationContext(conversationId) {
  try {
    const result = await pool.query(
      'SELECT context_key, context_value FROM chat_context WHERE conversation_id = $1 ORDER BY updated_at DESC',
      [conversationId]
    );

    // Convert to object format
    const context = {};
    result.rows.forEach(row => {
      context[row.context_key] = row.context_value;
    });

    return context;
  } catch (error) {
    console.error('Database error in getConversationContext:', error);
    return {};
  }
}

async function setConversationContext(conversationId, contextKey, contextValue) {
  try {
    await pool.query(`
      INSERT INTO chat_context (conversation_id, context_key, context_value)
      VALUES ($1, $2, $3)
      ON CONFLICT (conversation_id, context_key)
      DO UPDATE SET context_value = EXCLUDED.context_value, updated_at = CURRENT_TIMESTAMP
    `, [conversationId, contextKey, contextValue]);
  } catch (error) {
    console.error('Database error in setConversationContext:', error);
  }
}

async function clearConversationContext(conversationId, contextKey = null) {
  try {
    if (contextKey) {
      await pool.query(
        'DELETE FROM chat_context WHERE conversation_id = $1 AND context_key = $2',
        [conversationId, contextKey]
      );
    } else {
      await pool.query(
        'DELETE FROM chat_context WHERE conversation_id = $1',
        [conversationId]
      );
    }
  } catch (error) {
    console.error('Database error in clearConversationContext:', error);
  }
}

async function getConversationHistory(conversationId, limit = 10) {
  try {
    const result = await pool.query(`
      SELECT cm.message_text, cm.sender_type, cm.created_at, u.name as sender_name
      FROM chat_messages cm
      LEFT JOIN users u ON cm.sender_id = u.id
      WHERE cm.conversation_id = $1
      ORDER BY cm.created_at DESC
      LIMIT $2
    `, [conversationId, limit]);

    return result.rows.reverse(); // Return in chronological order
  } catch (error) {
    console.error('Database error in getConversationHistory:', error);
    return [];
  }
}

// Export all functions
module.exports = {
  getChemicals,
  getChemicalByName,
  searchChemicals,
  getChemicalsByCategory,
  getLowStockChemicals,
  getExpiringChemicals,
  getExpiredChemicals,
  searchChemicalsAdvanced,
  getEquipment,
  getEquipmentByName,
  searchEquipment,
  getEquipmentByCategory,
  getAvailableEquipment,
  getEquipmentDueForMaintenance,
  getEquipmentNeedingCalibration,
  searchEquipmentAdvanced,
  getIncompatibleChemicals,
  getChemicalsRequiringSpecialStorage,
  checkEquipmentAvailability,
  getEquipmentBookings,
  logChatbotQuery,
  getChatbotUsageStats,
  getOrCreateConversation,
  getConversationContext,
  setConversationContext,
  clearConversationContext,
  getConversationHistory,
  getBorrowings,
  getUserBorrowings,
  getBorrowingById,
  getUserInfo,
  getLectureSchedules,
  getSchedulesByDate,
  getScheduleById,
  createBorrowing,
  getChemicalById,
  getEquipmentById,
  getUserById
};