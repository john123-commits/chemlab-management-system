const db = require('../config/db');

class Borrowing {
  static async create(borrowingData) {
    const { borrower_id, chemicals, equipment, purpose, research_details, borrow_date, return_date, visit_date, visit_time } = borrowingData;
    
    const result = await db.query(
      `INSERT INTO borrowings (borrower_id, chemicals, equipment, purpose, research_details, borrow_date, return_date, visit_date, visit_time, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'pending') RETURNING *`,
      [borrower_id, chemicals, equipment, purpose, research_details, borrow_date, return_date, visit_date, visit_time]
    );
    
    return result.rows[0];
  }

  static async findAll(filters = {}) {
    let query = `
      SELECT b.*, u.name as borrower_name, u.email as borrower_email 
      FROM borrowings b 
      JOIN users u ON b.borrower_id = u.id 
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

    const result = await db.query(query, params);
    return result.rows;
  }

  static async findById(id) {
    const result = await db.query(
      `SELECT b.*, u.name as borrower_name, u.email as borrower_email 
       FROM borrowings b 
       JOIN users u ON b.borrower_id = u.id 
       WHERE b.id = $1`,
      [id]
    );
    return result.rows[0];
  }

  static async updateStatus(id, status, notes = null) {
    const result = await db.query(
      'UPDATE borrowings SET status = $1, notes = $2, updated_at = NOW() WHERE id = $3 RETURNING *',
      [status, notes, id]
    );
    return result.rows[0];
  }

  static async getOverdue() {
    const result = await db.query(
      `SELECT b.*, u.name as borrower_name, u.email as borrower_email 
       FROM borrowings b 
       JOIN users u ON b.borrower_id = u.id 
       WHERE b.status = 'approved' AND b.return_date < CURRENT_DATE`
    );
    return result.rows;
  }
}

module.exports = Borrowing;