const db = require('../config/db');

class Chemical {
  static async create(chemicalData) {
    const { name, category, quantity, unit, storage_location, expiry_date, safety_data_sheet } = chemicalData;
    
    const result = await db.query(
      `INSERT INTO chemicals (name, category, quantity, unit, storage_location, expiry_date, safety_data_sheet)
       VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
      [name, category, quantity, unit, storage_location, expiry_date, safety_data_sheet]
    );
    
    return result.rows[0];
  }

  static async findAll(filters = {}) {
    let query = 'SELECT * FROM chemicals WHERE 1=1';
    const params = [];
    let paramIndex = 1;

    if (filters.category) {
      query += ` AND category = $${paramIndex}`;
      params.push(filters.category);
      paramIndex++;
    }

    if (filters.search) {
      query += ` AND (name ILIKE $${paramIndex} OR category ILIKE $${paramIndex})`;
      params.push(`%${filters.search}%`);
      paramIndex++;
    }

    query += ' ORDER BY created_at DESC';

    const result = await db.query(query, params);
    return result.rows;
  }

  static async findById(id) {
    const result = await db.query('SELECT * FROM chemicals WHERE id = $1', [id]);
    return result.rows[0];
  }

  static async update(id, chemicalData) {
    const { name, category, quantity, unit, storage_location, expiry_date, safety_data_sheet } = chemicalData;
    
    const result = await db.query(
      `UPDATE chemicals SET name = $1, category = $2, quantity = $3, unit = $4, 
       storage_location = $5, expiry_date = $6, safety_data_sheet = $7 
       WHERE id = $8 RETURNING *`,
      [name, category, quantity, unit, storage_location, expiry_date, safety_data_sheet, id]
    );
    
    return result.rows[0];
  }

  static async delete(id) {
    const result = await db.query('DELETE FROM chemicals WHERE id = $1 RETURNING *', [id]);
    return result.rows[0];
  }

  static async getExpiringSoon(days = 30) {
    const result = await db.query(
      `SELECT * FROM chemicals 
       WHERE expiry_date <= CURRENT_DATE + INTERVAL '${days} days' 
       AND expiry_date >= CURRENT_DATE
       ORDER BY expiry_date ASC`
    );
    return result.rows;
  }

  static async getLowStock(threshold = 10) {
    const result = await db.query(
      `SELECT * FROM chemicals 
       WHERE quantity <= $1 
       ORDER BY quantity ASC`,
      [threshold]
    );
    return result.rows;
  }
}

module.exports = Chemical;