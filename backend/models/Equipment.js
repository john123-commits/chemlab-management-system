const db = require('../config/db');

class Equipment {
  static async create(equipmentData) {
    const {
      name, category, condition, last_maintenance_date, location, maintenance_schedule,
      serial_number, manufacturer, model, purchase_date, warranty_expiry,
      calibration_date, next_calibration_date
    } = equipmentData;

    const result = await db.query(
      `INSERT INTO equipment (name, category, condition, last_maintenance_date, location, maintenance_schedule,
        serial_number, manufacturer, model, purchase_date, warranty_expiry,
        calibration_date, next_calibration_date)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13) RETURNING *`,
      [name, category, condition, last_maintenance_date, location, maintenance_schedule,
       serial_number, manufacturer, model, purchase_date, warranty_expiry,
       calibration_date, next_calibration_date]
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
    const {
      name, category, condition, last_maintenance_date, location, maintenance_schedule,
      serial_number, manufacturer, model, purchase_date, warranty_expiry,
      calibration_date, next_calibration_date
    } = equipmentData;

    const result = await db.query(
      `UPDATE equipment SET name = $1, category = $2, condition = $3,
        last_maintenance_date = $4, location = $5, maintenance_schedule = $6,
        serial_number = $7, manufacturer = $8, model = $9, purchase_date = $10,
        warranty_expiry = $11, calibration_date = $12, next_calibration_date = $13
        WHERE id = $14 RETURNING *`,
      [name, category, condition, last_maintenance_date, location, maintenance_schedule,
       serial_number, manufacturer, model, purchase_date, warranty_expiry,
       calibration_date, next_calibration_date, id]
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