const db = require('../config/db');

class Equipment {
  static async create(equipmentData) {
    const { name, category, condition, last_maintenance_date, location, maintenance_schedule } = equipmentData;
    
    const result = await db.query(
      `INSERT INTO equipment (name, category, condition, last_maintenance_date, location, maintenance_schedule)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [name, category, condition, last_maintenance_date, location, maintenance_schedule]
    );
    
    return result.rows[0];
  }

  static async findAll() {
    const result = await db.query('SELECT * FROM equipment ORDER BY created_at DESC');
    return result.rows;
  }

  static async findById(id) {
    const result = await db.query('SELECT * FROM equipment WHERE id = $1', [id]);
    return result.rows[0];
  }

  static async update(id, equipmentData) {
    const { name, category, condition, last_maintenance_date, location, maintenance_schedule } = equipmentData;
    
    const result = await db.query(
      `UPDATE equipment SET name = $1, category = $2, condition = $3, 
       last_maintenance_date = $4, location = $5, maintenance_schedule = $6 
       WHERE id = $7 RETURNING *`,
      [name, category, condition, last_maintenance_date, location, maintenance_schedule, id]
    );
    
    return result.rows[0];
  }

  static async delete(id) {
    const result = await db.query('DELETE FROM equipment WHERE id = $1 RETURNING *', [id]);
    return result.rows[0];
  }

  static async getDueForMaintenance(days = 30) {
    const result = await db.query(
      `SELECT * FROM equipment 
       WHERE last_maintenance_date + INTERVAL '1 day' * maintenance_schedule <= CURRENT_DATE + INTERVAL '${days} days'
       ORDER BY last_maintenance_date ASC`
    );
    return result.rows;
  }
}

module.exports = Equipment;