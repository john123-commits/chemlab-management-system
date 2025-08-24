const db = require('../config/db');
const bcrypt = require('bcryptjs');

class User {
  static async create(userData) {
    const { name, email, password, role = 'borrower' } = userData;
    const hashedPassword = await bcrypt.hash(password, 10);
    
    const result = await db.query(
      'INSERT INTO users (name, email, password, role) VALUES ($1, $2, $3, $4) RETURNING *',
      [name, email, hashedPassword, role]
    );
    
    return result.rows[0];
  }

  static async findByEmail(email) {
    const result = await db.query('SELECT * FROM users WHERE email = $1', [email]);
    return result.rows[0];
  }

  static async findById(id) {
    const result = await db.query('SELECT * FROM users WHERE id = $1', [id]);
    return result.rows[0];
  }

  static async findAll() {
    const result = await db.query('SELECT id, name, email, role, created_at FROM users ORDER BY created_at DESC');
    return result.rows;
  }

  static async update(id, userData) {
    const { name, email, role } = userData;
    const result = await db.query(
      'UPDATE users SET name = $1, email = $2, role = $3 WHERE id = $4 RETURNING *',
      [name, email, role, id]
    );
    return result.rows[0];
  }

  // Add to User model:
  static async getPendingRequestsCount() {
    try {
      console.log('=== USER MODEL: GET PENDING REQUESTS COUNT ===');
      
      const result = await db.query(
        `SELECT COUNT(*) as count
         FROM borrowings 
         WHERE status = 'pending'`
      );
      
      console.log('Pending requests count result:', result.rows[0].count);
      
      return parseInt(result.rows[0].count);
    } catch (error) {
      console.error('Error in User.getPendingRequestsCount:', error);
      return 0; // Return 0 instead of throwing error
    }
  }

  static async getPendingRequests() {
    try {
      console.log('=== USER MODEL: GET PENDING REQUESTS ===');
      
      const result = await db.query(
        `SELECT b.*, u.name as borrower_name, u.email as borrower_email 
         FROM borrowings b 
         JOIN users u ON b.borrower_id = u.id 
         WHERE b.status = 'pending'
         ORDER BY b.created_at ASC`
      );
      
      console.log('Found pending requests:', result.rows.length);
      
      // Parse JSON fields
      const pendingRequests = result.rows.map(row => ({
        ...row,
        chemicals: typeof row.chemicals === 'string' ? JSON.parse(row.chemicals) : row.chemicals || [],
        equipment: typeof row.equipment === 'string' ? JSON.parse(row.equipment) : row.equipment || []
      }));
      
      return pendingRequests;
    } catch (error) {
      console.error('Error in User.getPendingRequests:', error);
      return []; // Return empty array instead of throwing error
    }
  }

  // ✅ FIXED DELETE METHOD:
  static async delete(id) {
    try {
      // First, handle dependent lecture schedules to avoid foreign key constraint
      await db.query(
        'UPDATE lecture_schedules SET technician_id = NULL WHERE technician_id = $1',
        [id]
      );
      
      // Handle any borrowing requests if needed
      await db.query(
        'UPDATE borrowings SET technician_id = NULL WHERE technician_id = $1',
        [id]
      );
      
      // Then delete the user
      const result = await db.query('DELETE FROM users WHERE id = $1 RETURNING *', [id]);
      
      if (result.rows.length === 0) {
        throw new Error('User not found');
      }
      
      return result.rows[0];
    } catch (error) {
      console.error('Error in Users.delete:', error);
      throw new Error('Failed to delete user: ' + error.message);
    }
  }
}

module.exports = User;