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

  // Add to Equipment class in backend/models/Equipment.js

static async getFilteredEquipment(filters = {}) {
  let query = `
    SELECT *, 
           CASE 
             WHEN last_maintenance_date + INTERVAL '1 day' * maintenance_schedule <= CURRENT_DATE + INTERVAL '${filters.maintenanceDueWithin || 30} days'
             THEN true ELSE false 
           END as is_maintenance_due,
           CASE 
             WHEN next_calibration_date <= CURRENT_DATE + INTERVAL '${filters.calibrationDueWithin || 30} days' AND next_calibration_date IS NOT NULL
             THEN true ELSE false 
           END as is_calibration_due,
           CASE 
             WHEN warranty_expiry <= CURRENT_DATE + INTERVAL '90 days' AND warranty_expiry IS NOT NULL
             THEN true ELSE false 
           END as is_warranty_expiring,
           (last_maintenance_date + INTERVAL '1 day' * maintenance_schedule) as next_maintenance_date
    FROM equipment 
    WHERE 1=1`;
  
  const params = [];
  let paramIndex = 1;

  // Apply filters
  if (filters.category && filters.category !== 'All') {
    query += ` AND category = $${paramIndex}`;
    params.push(filters.category);
    paramIndex++;
  }

  if (filters.condition && filters.condition !== 'All') {
    query += ` AND condition = $${paramIndex}`;
    params.push(filters.condition);
    paramIndex++;
  }

  if (filters.maintenanceDueOnly) {
    query += ` AND last_maintenance_date + INTERVAL '1 day' * maintenance_schedule <= CURRENT_DATE + INTERVAL '${filters.maintenanceDueWithin || 30} days'`;
  }

  if (filters.calibrationDueOnly) {
    query += ` AND next_calibration_date <= CURRENT_DATE + INTERVAL '${filters.calibrationDueWithin || 30} days' AND next_calibration_date IS NOT NULL`;
  }

  if (filters.warrantyExpiringOnly) {
    query += ` AND warranty_expiry <= CURRENT_DATE + INTERVAL '90 days' AND warranty_expiry IS NOT NULL`;
  }

  if (filters.search) {
    query += ` AND (name ILIKE $${paramIndex} OR category ILIKE $${paramIndex} OR manufacturer ILIKE $${paramIndex} OR model ILIKE $${paramIndex})`;
    params.push(`%${filters.search}%`);
    paramIndex++;
  }

  query += ' ORDER BY created_at DESC';
  
  const result = await db.query(query, params);
  return result.rows;
}

static async getEquipmentAnalysis() {
  const result = await db.query(`
    SELECT 
      COUNT(*) as total_equipment,
      COUNT(*) FILTER (WHERE condition = 'poor' OR condition = 'needs_repair') as needs_attention_count,
      COUNT(*) FILTER (WHERE last_maintenance_date + INTERVAL '1 day' * maintenance_schedule <= CURRENT_DATE + INTERVAL '30 days') as maintenance_due_count,
      COUNT(*) FILTER (WHERE next_calibration_date <= CURRENT_DATE + INTERVAL '30 days' AND next_calibration_date IS NOT NULL) as calibration_due_count,
      COUNT(*) FILTER (WHERE warranty_expiry <= CURRENT_DATE + INTERVAL '90 days' AND warranty_expiry IS NOT NULL) as warranty_expiring_count,
      COUNT(*) FILTER (WHERE last_maintenance_date + INTERVAL '1 day' * maintenance_schedule <= CURRENT_DATE) as overdue_maintenance_count
    FROM equipment
  `);
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

  static async count(filters = {}) {
    let query = 'SELECT COUNT(*) as count FROM equipment WHERE 1=1';
    const params = [];
    let paramIndex = 1;

    if (filters.where) {
      if (filters.where.deleted_at) {
        query += ` AND deleted_at IS NULL`;
      }
    }

    const result = await db.query(query, params);
    return parseInt(result.rows[0].count);
  }
}

module.exports = Equipment;