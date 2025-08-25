const db = require('../config/db');
const bcrypt = require('bcryptjs');

class User {
  // ✅ ENHANCED CREATE - Support all new fields
  static async create(userData) {
    const { 
      name, 
      email, 
      password, 
      role = 'borrower',
      status = 'active',
      phone = null,
      student_id = null,
      institution = null,
      education_level = null,
      semester = null,
      department = null
    } = userData;
    
    console.log('=== USER MODEL: CREATE USER ===');
    console.log('Creating user with data:', {
      name,
      email,
      role,
      status,
      institution,
      department,
      student_id: student_id ? 'PROVIDED' : 'NULL'
    });
    
    // Don't hash here - password should already be hashed by the caller
    const result = await db.query(
      `INSERT INTO users (
        name, email, password, role, status, phone, 
        student_id, institution, education_level, 
        semester, department
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) 
      RETURNING *`,
      [
        name, email, password, role, status, phone, 
        student_id, institution, education_level, 
        semester, department
      ]
    );
    
    console.log('User created with ID:', result.rows[0].id);
    return result.rows[0];
  }

  static async findByEmail(email) {
    const result = await db.query('SELECT * FROM users WHERE email = $1', [email]);
    return result.rows[0];
  }

  // ✅ NEW: Find user by student ID
  static async findByStudentId(studentId) {
    console.log('=== USER MODEL: FIND BY STUDENT ID ===');
    console.log('Looking for student ID:', studentId);
    
    const result = await db.query(
      'SELECT * FROM users WHERE student_id = $1', 
      [studentId]
    );
    
    console.log('Found user with student ID:', result.rows.length > 0 ? 'YES' : 'NO');
    return result.rows[0];
  }

  static async findById(id) {
    const result = await db.query('SELECT * FROM users WHERE id = $1', [id]);
    return result.rows[0];
  }

  // ✅ ENHANCED: Include all fields in findAll
  static async findAll() {
    const result = await db.query(`
      SELECT 
        id, name, email, role, status, phone, student_id, 
        institution, education_level, semester, department, 
        created_at 
      FROM users 
      ORDER BY created_at DESC
    `);
    return result.rows;
  }

  // ✅ NEW: Find pending users for admin approval
  static async findPendingUsers() {
    console.log('=== USER MODEL: FIND PENDING USERS ===');
    
    const result = await db.query(`
      SELECT 
        id, name, email, phone, student_id, institution, 
        education_level, semester, department, created_at, status
      FROM users 
      WHERE status = 'pending' AND role = 'borrower'
      ORDER BY created_at ASC
    `);
    
    console.log('Found pending users:', result.rows.length);
    return result.rows;
  }

  // ✅ NEW: Update user status (for approval/rejection)
  static async updateStatus(id, status, rejectionReason = null) {
    console.log('=== USER MODEL: UPDATE STATUS ===');
    console.log('User ID:', id);
    console.log('New status:', status);
    console.log('Rejection reason:', rejectionReason);
    
    let query, params;
    
    if (status === 'rejected' && rejectionReason) {
      query = `
        UPDATE users 
        SET status = $1, rejection_reason = $2 
        WHERE id = $3 
        RETURNING *
      `;
      params = [status, rejectionReason, id];
    } else {
      query = `
        UPDATE users 
        SET status = $1, rejection_reason = NULL 
        WHERE id = $2 
        RETURNING *
      `;
      params = [status, id];
    }
    
    const result = await db.query(query, params);
    
    if (result.rows.length === 0) {
      throw new Error('User not found');
    }
    
    console.log('Status updated successfully for user:', result.rows[0].id);
    return result.rows[0];
  }

  // ✅ ENHANCED: Update with more fields
  static async update(id, userData) {
    const { 
      name, 
      email, 
      role,
      phone = null,
      institution = null,
      education_level = null,
      semester = null,
      department = null
    } = userData;
    
    console.log('=== USER MODEL: UPDATE USER ===');
    console.log('Updating user ID:', id);
    
    const result = await db.query(`
      UPDATE users 
      SET 
        name = $1, 
        email = $2, 
        role = $3,
        phone = $4,
        institution = $5,
        education_level = $6,
        semester = $7,
        department = $8
      WHERE id = $9 
      RETURNING *`,
      [name, email, role, phone, institution, education_level, semester, department, id]
    );
    
    if (result.rows.length === 0) {
      throw new Error('User not found');
    }
    
    console.log('User updated successfully');
    return result.rows[0];
  }

  // ✅ NEW: Get user statistics for admin dashboard
  static async getUserStats() {
    console.log('=== USER MODEL: GET USER STATS ===');
    
    const result = await db.query(`
      SELECT 
        COUNT(*) as total_users,
        COUNT(*) FILTER (WHERE status = 'pending') as pending_users,
        COUNT(*) FILTER (WHERE status = 'active') as active_users,
        COUNT(*) FILTER (WHERE status = 'rejected') as rejected_users,
        COUNT(*) FILTER (WHERE role = 'borrower') as borrowers,
        COUNT(*) FILTER (WHERE role = 'technician') as technicians,
        COUNT(*) FILTER (WHERE role = 'admin') as admins
      FROM users
    `);
    
    const stats = result.rows[0];
    console.log('User statistics:', stats);
    
    return {
      totalUsers: parseInt(stats.total_users),
      pendingUsers: parseInt(stats.pending_users),
      activeUsers: parseInt(stats.active_users),
      rejectedUsers: parseInt(stats.rejected_users),
      borrowers: parseInt(stats.borrowers),
      technicians: parseInt(stats.technicians),
      admins: parseInt(stats.admins)
    };
  }

  // ✅ NEW: Get users by institution (for analytics)
  static async getUsersByInstitution() {
    console.log('=== USER MODEL: GET USERS BY INSTITUTION ===');
    
    const result = await db.query(`
      SELECT 
        institution,
        COUNT(*) as user_count,
        COUNT(*) FILTER (WHERE status = 'active') as active_count
      FROM users 
      WHERE institution IS NOT NULL AND role = 'borrower'
      GROUP BY institution
      ORDER BY user_count DESC
    `);
    
    console.log('Users by institution:', result.rows.length, 'institutions');
    return result.rows;
  }

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
      return 0;
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
      return [];
    }
  }

  // ✅ ENHANCED DELETE: Handle new relationships
  static async delete(id) {
    try {
      console.log('=== USER MODEL: DELETE USER ===');
      console.log('Deleting user ID:', id);
      
      // Get user info first
      const user = await this.findById(id);
      if (!user) {
        throw new Error('User not found');
      }
      
      console.log('Deleting user:', user.name, user.email);
      
      // Handle dependent relationships
      await db.query(
        'UPDATE lecture_schedules SET technician_id = NULL WHERE technician_id = $1',
        [id]
      );
      
      await db.query(
        'UPDATE borrowings SET technician_id = NULL WHERE technician_id = $1',
        [id]
      );
      
      // For borrowers, you might want to handle their borrowing history differently
      if (user.role === 'borrower') {
        // Option 1: Keep borrowing records but anonymize
        await db.query(
          'UPDATE borrowings SET borrower_id = NULL WHERE borrower_id = $1',
          [id]
        );
        
        // Option 2: Or delete their borrowing records entirely
        // await db.query('DELETE FROM borrowings WHERE borrower_id = $1', [id]);
      }
      
      // Finally delete the user
      const result = await db.query('DELETE FROM users WHERE id = $1 RETURNING *', [id]);
      
      if (result.rows.length === 0) {
        throw new Error('User not found during deletion');
      }
      
      console.log('User deleted successfully:', result.rows[0].id);
      return result.rows[0];
      
    } catch (error) {
      console.error('Error in User.delete:', error);
      throw new Error('Failed to delete user: ' + error.message);
    }
  }

  // ✅ NEW: Batch operations for admin
  static async approveMultipleUsers(userIds) {
    console.log('=== USER MODEL: BATCH APPROVE USERS ===');
    console.log('Approving users:', userIds);
    
    const result = await db.query(
      `UPDATE users 
       SET status = 'active', rejection_reason = NULL 
       WHERE id = ANY($1::int[]) AND status = 'pending' 
       RETURNING id, name, email`,
      [userIds]
    );
    
    console.log('Approved users:', result.rows.length);
    return result.rows;
  }

  static async rejectMultipleUsers(userIds, reason) {
    console.log('=== USER MODEL: BATCH REJECT USERS ===');
    console.log('Rejecting users:', userIds);
    console.log('Reason:', reason);
    
    const result = await db.query(
      `UPDATE users 
       SET status = 'rejected', rejection_reason = $2 
       WHERE id = ANY($1::int[]) AND status = 'pending' 
       RETURNING id, name, email`,
      [userIds, reason]
    );
    
    console.log('Rejected users:', result.rows.length);
    return result.rows;
  }
}

module.exports = User;