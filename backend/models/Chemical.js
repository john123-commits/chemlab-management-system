const db = require('../config/db');

class Chemical {
  static async create(chemicalData) {
    const {
      name, category, quantity, unit, storage_location, expiry_date, safety_data_sheet,
      c_number, molecular_formula, molecular_weight, physical_state, color, density,
      melting_point, boiling_point, solubility, storage_conditions, hazard_class,
      safety_precautions, safety_info, msds_link,
      initial_quantity, reorder_level, supplier, purchase_date, cost_per_unit
    } = chemicalData;

    console.log('Creating chemical with raw data:', { name, category, quantity, unit, storage_location, expiry_date, safety_data_sheet });
    console.log('Quantity type:', typeof quantity, 'Value:', quantity);

    // Ensure quantity is properly converted to number
    let numericQuantity;
    if (typeof quantity === 'string') {
      numericQuantity = parseFloat(quantity);
    } else if (typeof quantity === 'number') {
      numericQuantity = quantity;
    } else {
      numericQuantity = 0;
    }

    console.log('Converted quantity:', numericQuantity, 'Type:', typeof numericQuantity);

    // Validate the conversion
    if (isNaN(numericQuantity)) {
      throw new Error('Invalid quantity value: must be a valid number');
    }

    const result = await db.query(
      `INSERT INTO chemicals (name, category, quantity, unit, storage_location, expiry_date, safety_data_sheet,
        c_number, molecular_formula, molecular_weight, physical_state, color, density,
        melting_point, boiling_point, solubility, storage_conditions, hazard_class,
        safety_precautions, safety_info, msds_link,
        initial_quantity, reorder_level, supplier, purchase_date, cost_per_unit)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26) RETURNING *`,
      [name, category, numericQuantity, unit, storage_location, expiry_date, safety_data_sheet,
       c_number, molecular_formula, molecular_weight, physical_state, color, density,
       melting_point, boiling_point, solubility, storage_conditions, hazard_class,
       safety_precautions, safety_info, msds_link,
       initial_quantity || numericQuantity, reorder_level || 10, supplier, purchase_date, cost_per_unit]
    );

    console.log('Chemical created successfully:', result.rows[0]);
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
    const {
      name, category, quantity, unit, storage_location, expiry_date, safety_data_sheet,
      c_number, molecular_formula, molecular_weight, physical_state, color, density,
      melting_point, boiling_point, solubility, storage_conditions, hazard_class,
      safety_precautions, safety_info, msds_link,
      initial_quantity, reorder_level, supplier, purchase_date, cost_per_unit
    } = chemicalData;

    // Ensure quantity is properly converted to number
    let numericQuantity;
    if (typeof quantity === 'string') {
      numericQuantity = parseFloat(quantity);
    } else if (typeof quantity === 'number') {
      numericQuantity = quantity;
    } else {
      numericQuantity = 0;
    }

    // Validate the conversion
    if (isNaN(numericQuantity)) {
      throw new Error('Invalid quantity value: must be a valid number');
    }

    const result = await db.query(
      `UPDATE chemicals SET name = $1, category = $2, quantity = $3, unit = $4,
        storage_location = $5, expiry_date = $6, safety_data_sheet = $7,
        c_number = $8, molecular_formula = $9, molecular_weight = $10, physical_state = $11,
        color = $12, density = $13, melting_point = $14, boiling_point = $15, solubility = $16,
        storage_conditions = $17, hazard_class = $18, safety_precautions = $19, safety_info = $20, msds_link = $21,
        initial_quantity = $22, reorder_level = $23, supplier = $24, purchase_date = $25, cost_per_unit = $26
        WHERE id = $27 RETURNING *`,
      [name, category, numericQuantity, unit, storage_location, expiry_date, safety_data_sheet,
       c_number, molecular_formula, molecular_weight, physical_state, color, density,
       melting_point, boiling_point, solubility, storage_conditions, hazard_class,
       safety_precautions, safety_info, msds_link,
       initial_quantity, reorder_level, supplier, purchase_date, cost_per_unit, id]
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
// Add these methods to your Chemical class

static async getFilteredChemicals(filters = {}) {
  let query = `
    SELECT *, 
           (initial_quantity - quantity) as quantity_used,
           CASE 
             WHEN quantity <= reorder_level THEN true 
             ELSE false 
           END as is_low_stock,
           CASE 
             WHEN expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN true 
             ELSE false 
           END as is_expiring_soon
    FROM chemicals 
    WHERE 1=1`;
  
  const params = [];
  let paramIndex = 1;

  // Apply filters
  if (filters.category && filters.category !== 'All') {
    query += ` AND category = $${paramIndex}`;
    params.push(filters.category);
    paramIndex++;
  }

  if (filters.lowStockOnly) {
    query += ` AND quantity <= reorder_level`;
  }

  if (filters.expiringSoon) {
    query += ` AND expiry_date <= CURRENT_DATE + INTERVAL '${filters.expiringSoon} days'`;
  }

  if (filters.search) {
    query += ` AND (name ILIKE $${paramIndex} OR category ILIKE $${paramIndex} OR c_number ILIKE $${paramIndex})`;
    params.push(`%${filters.search}%`);
    paramIndex++;
  }

  query += ' ORDER BY created_at DESC';
  
  const result = await db.query(query, params);
  return result.rows;
}

static async getStockAnalysis() {
  const result = await db.query(`
    SELECT
      COUNT(*) as total_chemicals,
      COUNT(*) FILTER (WHERE quantity <= reorder_level) as low_stock_count,
      COUNT(*) FILTER (WHERE expiry_date <= CURRENT_DATE + INTERVAL '30 days') as expiring_soon_count,
      COUNT(*) FILTER (WHERE expiry_date < CURRENT_DATE) as expired_count,
      SUM(quantity * COALESCE(cost_per_unit, 0)) as total_inventory_value
    FROM chemicals
  `);
  return result.rows[0];
}

static async count(filters = {}) {
  let query = 'SELECT COUNT(*) as count FROM chemicals WHERE 1=1';
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

module.exports = Chemical;