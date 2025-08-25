const db = require('../config/db');

class Borrowing {
  static async create(borrowingData) {
    const { 
      borrower_id, 
      chemicals, 
      equipment, 
      purpose, 
      research_details, 
      borrow_date, 
      return_date, 
      visit_date, 
      visit_time,
      // Add student information fields
      university,
      education_level,
      registration_number,
      student_number,
      current_year,
      semester,
      borrower_email,
      borrower_contact
    } = borrowingData;
    
    // Ensure chemicals and equipment are properly formatted as JSON
    const formattedChemicals = Array.isArray(chemicals) ? JSON.stringify(chemicals) : '[]';
    const formattedEquipment = Array.isArray(equipment) ? JSON.stringify(equipment) : '[]';
    
    console.log('Creating borrowing with data:', {
      borrower_id,
      chemicals: formattedChemicals,
      equipment: formattedEquipment,
      purpose,
      research_details,
      borrow_date,
      return_date,
      visit_date,
      visit_time,
      university,
      education_level,
      registration_number,
      student_number,
      current_year,
      semester,
      borrower_email,
      borrower_contact
    });
    
    const result = await db.query(
      `INSERT INTO borrowings (
         borrower_id, chemicals, equipment, purpose, research_details, 
         borrow_date, return_date, visit_date, visit_time, status,
         university, education_level, registration_number, student_number,
         current_year, semester, borrower_email, borrower_contact
       )
       VALUES (
         $1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending',
         $10, $11, $12, $13, $14, $15, $16, $17
       ) RETURNING *`,
      [
        borrower_id, formattedChemicals, formattedEquipment, purpose, research_details,
        borrow_date, return_date, visit_date, visit_time,
        university, education_level, registration_number, student_number,
        current_year, semester, borrower_email, borrower_contact
      ]
    );
    
    return result.rows[0];
  }

  static async findAll(filters = {}) {
    let query = `
      SELECT b.*, 
             u.name as borrower_name, 
             u.email as borrower_email,
             t.name as technician_name,
             a.name as admin_name
      FROM borrowings b 
      JOIN users u ON b.borrower_id = u.id 
      LEFT JOIN users t ON b.technician_id = t.id
      LEFT JOIN users a ON b.admin_id = a.id
      WHERE 1=1
    `;
    const params = [];
    let paramIndex = 1;

    if (filters.status) {
      query += ` AND b.status = $${paramIndex}`;
      params.push(filters.status);
      paramIndex++;
    }

    if (filters.borrower_id) {
      query += ` AND b.borrower_id = $${paramIndex}`;
      params.push(filters.borrower_id);
      paramIndex++;
    }

    query += ' ORDER BY b.created_at DESC';

    try {
      const result = await db.query(query, params);
      
      // Parse JSON fields
      const borrowings = result.rows.map(row => ({
        ...row,
        chemicals: typeof row.chemicals === 'string' ? JSON.parse(row.chemicals) : row.chemicals || [],
        equipment: typeof row.equipment === 'string' ? JSON.parse(row.equipment) : row.equipment || [],
        // Include student information fields
        university: row.university,
        education_level: row.education_level,
        registration_number: row.registration_number,
        student_number: row.student_number,
        current_year: row.current_year,
        semester: row.semester,
        borrower_email: row.borrower_email,
        borrower_contact: row.borrower_contact,
        // ✅ Parse equipment_condition if it exists
        equipment_condition: row.equipment_condition ? 
          (typeof row.equipment_condition === 'string' ? JSON.parse(row.equipment_condition) : row.equipment_condition) : null
      }));
      
      return borrowings;
    } catch (error) {
      console.error('Error in Borrowing.findAll:', error);
      throw error;
    }
  }

  static async findById(id) {
    try {
      const result = await db.query(
        `SELECT b.*, 
                u.name as borrower_name, 
                u.email as borrower_email,
                t.name as technician_name,
                a.name as admin_name
         FROM borrowings b 
         JOIN users u ON b.borrower_id = u.id 
         LEFT JOIN users t ON b.technician_id = t.id
         LEFT JOIN users a ON b.admin_id = a.id
         WHERE b.id = $1`,
        [id]
      );
      
      if (result.rows.length === 0) {
        return null;
      }
      
      const row = result.rows[0];
      return {
        ...row,
        chemicals: typeof row.chemicals === 'string' ? JSON.parse(row.chemicals) : row.chemicals || [],
        equipment: typeof row.equipment === 'string' ? JSON.parse(row.equipment) : row.equipment || [],
        // Include student information fields
        university: row.university,
        education_level: row.education_level,
        registration_number: row.registration_number,
        student_number: row.student_number,
        current_year: row.current_year,
        semester: row.semester,
        borrower_email: row.borrower_email,
        borrower_contact: row.borrower_contact,
        // ✅ Parse equipment_condition if it exists
        equipment_condition: row.equipment_condition ? 
          (typeof row.equipment_condition === 'string' ? JSON.parse(row.equipment_condition) : row.equipment_condition) : null
      };
    } catch (error) {
      console.error('Error in Borrowing.findById:', error);
      throw error;
    }
  }

  static async updateStatus(id, status, updaterId, updaterRole, notes = null, rejectionReason = null) {
    let query;
    let params;
    
    console.log('Updating borrowing status:', { id, status, updaterId, updaterRole, notes, rejectionReason });
    
    try {
      if (status === 'approved' && updaterRole === 'technician') {
        // Technician approval - set technician info
        query = `UPDATE borrowings 
                 SET status = $1, 
                     technician_id = $2, 
                     technician_approved_at = NOW(),
                     notes = $3,
                     updated_at = NOW() 
                 WHERE id = $4 RETURNING *`;
        params = [status, updaterId, notes, id];
      } else if (status === 'approved' && updaterRole === 'admin') {
        // Admin approval - set admin info (final approval)
        query = `UPDATE borrowings 
                 SET status = $1, 
                     admin_id = $2, 
                     admin_approved_at = NOW(),
                     notes = $3,
                     updated_at = NOW() 
                 WHERE id = $4 RETURNING *`;
        params = [status, updaterId, notes, id];
      } else if (status === 'rejected') {
        // Rejection by either technician or admin
        const roleField = updaterRole === 'technician' ? 'technician_id' : 'admin_id';
        const timeField = updaterRole === 'technician' ? 'technician_approved_at' : 'admin_approved_at';
        
        query = `UPDATE borrowings 
                 SET status = $1, 
                     ${roleField} = $2, 
                     ${timeField} = NOW(),
                     rejection_reason = $3,
                     notes = $4,
                     updated_at = NOW() 
                 WHERE id = $5 RETURNING *`;
        params = [status, updaterId, rejectionReason, notes, id];
      } else {
        // Other status updates (returned, etc.)
        query = `UPDATE borrowings 
                 SET status = $1, 
                     notes = $2,
                     updated_at = NOW() 
                 WHERE id = $3 RETURNING *`;
        params = [status, notes, id];
      }

      const result = await db.query(query, params);
      
      if (result.rows.length === 0) {
        return null;
      }
      
      const row = result.rows[0];
      return {
        ...row,
        chemicals: typeof row.chemicals === 'string' ? JSON.parse(row.chemicals) : row.chemicals || [],
        equipment: typeof row.equipment === 'string' ? JSON.parse(row.equipment) : row.equipment || [],
        // Include student information fields
        university: row.university,
        education_level: row.education_level,
        registration_number: row.registration_number,
        student_number: row.student_number,
        current_year: row.current_year,
        semester: row.semester,
        borrower_email: row.borrower_email,
        borrower_contact: row.borrower_contact,
        // ✅ Parse equipment_condition if it exists
        equipment_condition: row.equipment_condition ? 
          (typeof row.equipment_condition === 'string' ? JSON.parse(row.equipment_condition) : row.equipment_condition) : null
      };
    } catch (error) {
      console.error('Error in Borrowing.updateStatus:', error);
      throw error;
    }
  }

  static async getPendingRequests() {
    try {
      const result = await db.query(
        `SELECT b.*, u.name as borrower_name, u.email as borrower_email 
         FROM borrowings b 
         JOIN users u ON b.borrower_id = u.id 
         WHERE b.status = 'pending'
         ORDER BY b.created_at ASC`
      );
      
      const pendingRequests = result.rows.map(row => ({
        ...row,
        chemicals: typeof row.chemicals === 'string' ? JSON.parse(row.chemicals) : row.chemicals || [],
        equipment: typeof row.equipment === 'string' ? JSON.parse(row.equipment) : row.equipment || [],
        // Include student information fields
        university: row.university,
        education_level: row.education_level,
        registration_number: row.registration_number,
        student_number: row.student_number,
        current_year: row.current_year,
        semester: row.semester,
        borrower_email: row.borrower_email,
        borrower_contact: row.borrower_contact,
        // ✅ Parse equipment_condition if it exists
        equipment_condition: row.equipment_condition ? 
          (typeof row.equipment_condition === 'string' ? JSON.parse(row.equipment_condition) : row.equipment_condition) : null
      }));
      
      return pendingRequests;
    } catch (error) {
      console.error('Error in Borrowing.getPendingRequests:', error);
      // Return empty array instead of throwing error
      return [];
    }
  }

  static async getPendingRequestsCount() {
    try {
      const result = await db.query(
        `SELECT COUNT(*) as count
         FROM borrowings 
         WHERE status = 'pending'`
      );
      
      return parseInt(result.rows[0].count);
    } catch (error) {
      console.error('Error in Borrowing.getPendingRequestsCount:', error);
      // Return 0 instead of throwing error
      return 0;
    }
  }

  // ✅ FIXED: markAsReturned method with proper validation and error handling
  static async markAsReturned(borrowingId, returnData, confirmedByUserId) {
    const { equipmentCondition, returnNotes } = returnData;
    
    console.log('=== MARK AS RETURNED METHOD CALLED ===');
    console.log('Borrowing ID:', borrowingId);
    console.log('Equipment Condition:', equipmentCondition);
    console.log('Return Notes:', returnNotes);
    console.log('Confirmed By User ID:', confirmedByUserId);
    
    // ✅ VALIDATE: Check if required data exists
    if (!borrowingId) {
      throw new Error('Borrowing ID is required');
    }
    
    if (!equipmentCondition) {
      throw new Error('Equipment condition data is required');
    }
    
    if (!confirmedByUserId) {
      throw new Error('Confirmed by user ID is required');
    }

    // ✅ VALIDATE: Check if equipmentCondition is an object
    if (typeof equipmentCondition !== 'object' || equipmentCondition === null) {
      throw new Error('Equipment condition must be a valid object');
    }

    try {
      const result = await db.query(
        `UPDATE borrowings 
         SET returned = true,
             actual_return_date = NOW(),
             equipment_condition = $1,
             return_notes = $2,
             return_confirmed_by = $3,
             status = 'returned',
             updated_at = NOW()
         WHERE id = $4 
         RETURNING *`,
        [
          JSON.stringify(equipmentCondition), 
          returnNotes || '', 
          confirmedByUserId, 
          borrowingId
        ]
      );
      
      console.log('Database update result rows:', result.rows.length);

      if (result.rows.length === 0) {
        throw new Error('Borrowing not found');
      }
      
      const row = result.rows[0];
      console.log('Successfully updated borrowing:', row);
      
      return {
        ...row,
        chemicals: typeof row.chemicals === 'string' ? JSON.parse(row.chemicals) : row.chemicals || [],
        equipment: typeof row.equipment === 'string' ? JSON.parse(row.equipment) : row.equipment || [],
        equipment_condition: row.equipment_condition ? 
          (typeof row.equipment_condition === 'string' ? JSON.parse(row.equipment_condition) : row.equipment_condition) : null
      };
    } catch (error) {
      console.error('Database error in markAsReturned:', error);
      throw new Error(`Database operation failed: ${error.message}`);
    }
  }

  // ✅ FIXED: getActiveBorrowings method
  static async getActiveBorrowings() {
    try {
      const result = await db.query(
        `SELECT b.*, 
                u.name as borrower_name, 
                u.email as borrower_email,
                tech.name as technician_name
         FROM borrowings b
         JOIN users u ON b.borrower_id = u.id
         LEFT JOIN users tech ON b.technician_id = tech.id
         WHERE b.status = 'approved' 
         AND b.returned = false
         ORDER BY b.created_at DESC`
      );
      
      return result.rows.map(row => ({
        ...row,
        chemicals: typeof row.chemicals === 'string' ? JSON.parse(row.chemicals) : row.chemicals || [],
        equipment: typeof row.equipment === 'string' ? JSON.parse(row.equipment) : row.equipment || [],
        equipment_condition: row.equipment_condition ? 
          (typeof row.equipment_condition === 'string' ? JSON.parse(row.equipment_condition) : row.equipment_condition) : null
      }));
    } catch (error) {
      console.error('Error fetching active borrowings:', error);
      throw error;
    }
  }

  static async getOverdue() {
    try {
      // Check if required columns exist
      const columnCheck = await db.query(`
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = 'borrowings' 
        AND column_name IN ('technician_id', 'admin_id', 'rejection_reason', 'university', 'education_level', 'registration_number', 'student_number', 'current_year', 'semester', 'borrower_email', 'borrower_contact')
      `);
      
      const existingColumns = columnCheck.rows.map(row => row.column_name);
      const hasTechId = existingColumns.includes('technician_id');
      const hasAdminId = existingColumns.includes('admin_id');
      const hasRejectionReason = existingColumns.includes('rejection_reason');
      
      let selectClause = 'b.*';
      let joinClause = '';
      
      if (hasTechId) {
        selectClause += ', t.name as technician_name';
        joinClause += ' LEFT JOIN users t ON b.technician_id = t.id';
      }
      
      if (hasAdminId) {
        selectClause += ', a.name as admin_name';
        joinClause += ' LEFT JOIN users a ON b.admin_id = a.id';
      }
      
      const query = `
        SELECT ${selectClause}, u.name as borrower_name, u.email as borrower_email 
        FROM borrowings b 
        JOIN users u ON b.borrower_id = u.id 
        ${joinClause}
        WHERE b.status = 'approved' AND b.return_date < CURRENT_DATE
      `;
      
      const result = await db.query(query);
      
      // Parse JSON fields
      const overdueBorrowings = result.rows.map(row => ({
        ...row,
        chemicals: typeof row.chemicals === 'string' ? JSON.parse(row.chemicals) : row.chemicals || [],
        equipment: typeof row.equipment === 'string' ? JSON.parse(row.equipment) : row.equipment || [],
        // Include student information fields
        university: row.university,
        education_level: row.education_level,
        registration_number: row.registration_number,
        student_number: row.student_number,
        current_year: row.current_year,
        semester: row.semester,
        borrower_email: row.borrower_email,
        borrower_contact: row.borrower_contact,
        // ✅ Parse equipment_condition if it exists
        equipment_condition: row.equipment_condition ? 
          (typeof row.equipment_condition === 'string' ? JSON.parse(row.equipment_condition) : row.equipment_condition) : null
      }));
      
      return overdueBorrowings;
    } catch (error) {
      console.error('Error in Borrowing.getOverdue:', error);
      // Return empty array instead of throwing error
      return [];
    }
  }
}

module.exports = Borrowing;