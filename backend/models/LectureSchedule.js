const db = require('../config/db');

class LectureSchedule {
  static async create(scheduleData) {
    const { 
      admin_id, 
      technician_id, 
      title, 
      description, 
      required_chemicals, 
      required_equipment, 
      scheduled_date, 
      scheduled_time, 
      duration, 
      priority 
    } = scheduleData;
    
    const result = await db.query(
      `INSERT INTO lecture_schedules 
       (admin_id, technician_id, title, description, required_chemicals, required_equipment, 
        scheduled_date, scheduled_time, duration, priority)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) 
       RETURNING *`,
      [admin_id, technician_id, title, description, required_chemicals, required_equipment, 
       scheduled_date, scheduled_time, duration, priority]
    );
    
    return result.rows[0];
  }

  static async findAll(filters = {}) {
    let query = 'SELECT ls.*, u1.name as admin_name, u2.name as technician_name FROM lecture_schedules ls JOIN users u1 ON ls.admin_id = u1.id JOIN users u2 ON ls.technician_id = u2.id WHERE 1=1';
    const params = [];
    let paramIndex = 1;

    if (filters.admin_id) {
      query += ` AND ls.admin_id = $${paramIndex}`;
      params.push(filters.admin_id);
      paramIndex++;
    }

    if (filters.technician_id) {
      query += ` AND ls.technician_id = $${paramIndex}`;
      params.push(filters.technician_id);
      paramIndex++;
    }

    if (filters.status) {
      query += ` AND ls.status = $${paramIndex}`;
      params.push(filters.status);
      paramIndex++;
    }

    if (filters.scheduled_date) {
      query += ` AND ls.scheduled_date = $${paramIndex}`;
      params.push(filters.scheduled_date);
      paramIndex++;
    }

    query += ' ORDER BY ls.scheduled_date DESC, ls.scheduled_time DESC';

    const result = await db.query(query, params);
    return result.rows;
  }

  static async findById(id) {
    const result = await db.query(
      `SELECT ls.*, u1.name as admin_name, u2.name as technician_name 
       FROM lecture_schedules ls 
       JOIN users u1 ON ls.admin_id = u1.id 
       JOIN users u2 ON ls.technician_id = u2.id 
       WHERE ls.id = $1`,
      [id]
    );
    return result.rows[0];
  }

  static async update(id, updateData) {
    const fields = [];
    const values = [];
    let index = 1;

    Object.keys(updateData).forEach(key => {
      if (key !== 'id') {
        fields.push(`${key} = $${index}`);
        values.push(updateData[key]);
        index++;
      }
    });

    if (fields.length === 0) return null;

    values.push(id);
    const query = `UPDATE lecture_schedules SET ${fields.join(', ')}, updated_at = NOW() WHERE id = $${index} RETURNING *`;
    
    const result = await db.query(query, values);
    return result.rows[0];
  }

  static async delete(id) {
    const result = await db.query('DELETE FROM lecture_schedules WHERE id = $1 RETURNING *', [id]);
    return result.rows[0];
  }

  static async getPendingForTechnician(technicianId) {
    const result = await db.query(
      `SELECT * FROM lecture_schedules 
       WHERE technician_id = $1 AND status = 'pending' 
       ORDER BY scheduled_date ASC, scheduled_time ASC`,
      [technicianId]
    );
    return result.rows;
  }

  static async getUpcomingForAdmin(adminId, days = 30) {
    const result = await db.query(
      `SELECT * FROM lecture_schedules 
       WHERE admin_id = $1 AND scheduled_date >= CURRENT_DATE 
       AND scheduled_date <= CURRENT_DATE + INTERVAL '${days} days'
       ORDER BY scheduled_date ASC, scheduled_time ASC`,
      [adminId]
    );
    return result.rows;
  }
}

module.exports = LectureSchedule;