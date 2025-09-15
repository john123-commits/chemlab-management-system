// backend/utils/queryOptimizer.js
// Database query optimization utilities for ChemBot

const { Pool } = require('pg');

// Connection pool for better performance
let pool = null;

function getPool() {
  if (!pool) {
    pool = new Pool({
      user: process.env.DB_USER,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      password: process.env.DB_PASSWORD,
      port: process.env.DB_PORT,
      max: 20, // Maximum number of clients in the pool
      idleTimeoutMillis: 30000, // Close idle clients after 30 seconds
      connectionTimeoutMillis: 2000, // Return an error after 2 seconds if connection could not be established
    });

    // Handle pool errors
    pool.on('error', (err, client) => {
      console.error('Unexpected error on idle client', err);
    });
  }
  return pool;
}

/**
 * Simple in-memory cache for frequently accessed data
 */
class QueryCache {
  constructor(maxSize = 100, ttl = 300000) { // 5 minutes TTL
    this.cache = new Map();
    this.maxSize = maxSize;
    this.ttl = ttl;
  }

  set(key, value) {
    if (this.cache.size >= this.maxSize) {
      // Remove oldest entry
      const firstKey = this.cache.keys().next().value;
      this.cache.delete(firstKey);
      console.log(`[CACHE] Evicted oldest entry from ${this.constructor.name}`);
    }

    this.cache.set(key, {
      value,
      timestamp: Date.now()
    });
    console.log(`[CACHE] Set ${key} in ${this.constructor.name} (size: ${this.cache.size})`);
  }

  get(key) {
    const entry = this.cache.get(key);
    if (!entry) {
      console.log(`[CACHE] Miss for ${key} in ${this.constructor.name}`);
      return null;
    }

    // Check if entry has expired
    if (Date.now() - entry.timestamp > this.ttl) {
      this.cache.delete(key);
      console.log(`[CACHE] Expired ${key} in ${this.constructor.name}`);
      return null;
    }

    console.log(`[CACHE] Hit for ${key} in ${this.constructor.name}`);
    return entry.value;
  }

  clear() {
    this.cache.clear();
  }

  size() {
    return this.cache.size;
  }
}

// Global cache instances
const chemicalCache = new QueryCache(50, 300000); // 5 minutes for chemicals
const equipmentCache = new QueryCache(50, 300000); // 5 minutes for equipment
const searchCache = new QueryCache(30, 180000); // 3 minutes for search results

/**
 * Optimized chemical queries with caching
 */
async function getChemicalsOptimized(filters = {}) {
  const cacheKey = `chemicals_${JSON.stringify(filters)}`;
  const cached = chemicalCache.get(cacheKey);

  if (cached) {
    return cached;
  }

  const pool = getPool();
  try {
    let query = `
      SELECT
        id, name, category, quantity, unit, storage_location,
        expiry_date, hazard_class, safety_precautions
      FROM chemicals
      WHERE 1=1
    `;
    const values = [];
    let paramCount = 1;

    // Add filters
    if (filters.category) {
      query += ` AND LOWER(category) = LOWER($${paramCount})`;
      values.push(filters.category);
      paramCount++;
    }

    if (filters.status) {
      query += ` AND status = $${paramCount}`;
      values.push(filters.status);
      paramCount++;
    }

    // Add ordering for consistent results
    query += ' ORDER BY name';

    // Add LIMIT for performance
    if (!filters.limit) {
      query += ' LIMIT 100';
    } else {
      query += ` LIMIT $${paramCount}`;
      values.push(Math.min(filters.limit, 500)); // Max 500 records
    }

    const result = await pool.query(query, values);
    const chemicals = result.rows;

    // Cache the result
    chemicalCache.set(cacheKey, chemicals);

    return chemicals;
  } catch (error) {
    console.error('Optimized chemicals query error:', error);
    throw error;
  }
}

/**
 * Optimized equipment queries with caching
 */
async function getEquipmentOptimized(filters = {}) {
  const cacheKey = `equipment_${JSON.stringify(filters)}`;
  const cached = equipmentCache.get(cacheKey);

  if (cached) {
    return cached;
  }

  const pool = getPool();
  try {
    let query = `
      SELECT
        id, name, category, condition, location,
        maintenance_schedule, last_maintenance_date
      FROM equipment
      WHERE 1=1
    `;
    const values = [];
    let paramCount = 1;

    // Add filters
    if (filters.category) {
      query += ` AND LOWER(category) = LOWER($${paramCount})`;
      values.push(filters.category);
      paramCount++;
    }

    if (filters.condition) {
      query += ` AND LOWER(condition) = LOWER($${paramCount})`;
      values.push(filters.condition);
      paramCount++;
    }

    if (filters.availableOnly) {
      query += ` AND id NOT IN (
        SELECT DISTINCT equipment_id
        FROM borrowings
        WHERE status = 'approved'
        AND return_date >= CURRENT_DATE
        AND equipment_id IS NOT NULL
      )`;
    }

    // Add ordering for consistent results
    query += ' ORDER BY name';

    // Add LIMIT for performance
    if (!filters.limit) {
      query += ' LIMIT 100';
    } else {
      query += ` LIMIT $${paramCount}`;
      values.push(Math.min(filters.limit, 500));
    }

    const result = await pool.query(query, values);
    const equipment = result.rows;

    // Cache the result
    equipmentCache.set(cacheKey, equipment);

    return equipment;
  } catch (error) {
    console.error('Optimized equipment query error:', error);
    throw error;
  }
}

/**
 * Optimized search with caching and full-text search
 */
async function searchChemicalsOptimized(searchTerm, filters = {}) {
  if (!searchTerm || searchTerm.trim().length < 2) {
    return [];
  }

  const cacheKey = `search_chemicals_${searchTerm}_${JSON.stringify(filters)}`;
  const cached = searchCache.get(cacheKey);

  if (cached) {
    return cached;
  }

  const pool = getPool();
  try {
    const searchPattern = `%${searchTerm.trim()}%`;

    let query = `
      SELECT
        id, name, category, quantity, unit, storage_location, expiry_date,
        ts_rank_cd(to_tsvector('english', name || ' ' || category || ' ' || COALESCE(c_number, '')), plainto_tsquery('english', $1)) as rank
      FROM chemicals
      WHERE to_tsvector('english', name || ' ' || category || ' ' || COALESCE(c_number, '')) @@ plainto_tsquery('english', $1)
    `;

    const values = [searchTerm];
    let paramCount = 2;

    // Add additional filters
    if (filters.category) {
      query += ` AND LOWER(category) = LOWER($${paramCount})`;
      values.push(filters.category);
      paramCount++;
    }

    if (filters.minQuantity !== undefined) {
      query += ` AND quantity >= $${paramCount}`;
      values.push(filters.minQuantity);
      paramCount++;
    }

    // Order by relevance and limit results
    query += ' ORDER BY rank DESC, name LIMIT 20';

    const result = await pool.query(query, values);
    const results = result.rows;

    // Cache the result
    searchCache.set(cacheKey, results);

    return results;
  } catch (error) {
    console.error('Optimized chemical search error:', error);
    // Fallback to simple LIKE search
    return await fallbackChemicalSearch(searchTerm, filters);
  }
}

/**
 * Fallback search method for when full-text search fails
 */
async function fallbackChemicalSearch(searchTerm, filters = {}) {
  const pool = getPool();
  try {
    const result = await pool.query(
      'SELECT id, name, category, quantity, unit, storage_location, expiry_date FROM chemicals WHERE LOWER(name) LIKE LOWER($1) OR LOWER(category) LIKE LOWER($1) ORDER BY name LIMIT 20',
      [`%${searchTerm}%`]
    );
    return result.rows;
  } catch (error) {
    console.error('Fallback chemical search error:', error);
    return [];
  }
}

/**
 * Optimized equipment search
 */
async function searchEquipmentOptimized(searchTerm, filters = {}) {
  if (!searchTerm || searchTerm.trim().length < 2) {
    return [];
  }

  const cacheKey = `search_equipment_${searchTerm}_${JSON.stringify(filters)}`;
  const cached = searchCache.get(cacheKey);

  if (cached) {
    return cached;
  }

  const pool = getPool();
  try {
    const searchPattern = `%${searchTerm.trim()}%`;

    let query = `
      SELECT
        id, name, category, condition, location, last_maintenance_date,
        ts_rank_cd(to_tsvector('english', name || ' ' || category || ' ' || COALESCE(manufacturer, '') || ' ' || COALESCE(model, '')), plainto_tsquery('english', $1)) as rank
      FROM equipment
      WHERE to_tsvector('english', name || ' ' || category || ' ' || COALESCE(manufacturer, '') || ' ' || COALESCE(model, '')) @@ plainto_tsquery('english', $1)
    `;

    const values = [searchTerm];
    let paramCount = 2;

    // Add filters
    if (filters.category) {
      query += ` AND LOWER(category) = LOWER($${paramCount})`;
      values.push(filters.category);
      paramCount++;
    }

    if (filters.condition) {
      query += ` AND LOWER(condition) = LOWER($${paramCount})`;
      values.push(filters.condition);
      paramCount++;
    }

    if (filters.availableOnly) {
      query += ` AND id NOT IN (
        SELECT DISTINCT equipment_id
        FROM borrowings
        WHERE status = 'approved'
        AND return_date >= CURRENT_DATE
        AND equipment_id IS NOT NULL
      )`;
    }

    query += ' ORDER BY rank DESC, name LIMIT 20';

    const result = await pool.query(query, values);
    const results = result.rows;

    // Cache the result
    searchCache.set(cacheKey, results);

    return results;
  } catch (error) {
    console.error('Optimized equipment search error:', error);
    // Fallback to simple LIKE search
    return await fallbackEquipmentSearch(searchTerm, filters);
  }
}

/**
 * Fallback equipment search
 */
async function fallbackEquipmentSearch(searchTerm, filters = {}) {
  const pool = getPool();
  try {
    const result = await pool.query(
      'SELECT id, name, category, condition, location, last_maintenance_date FROM equipment WHERE LOWER(name) LIKE LOWER($1) OR LOWER(category) LIKE LOWER($1) ORDER BY name LIMIT 20',
      [`%${searchTerm}%`]
    );
    return result.rows;
  } catch (error) {
    console.error('Fallback equipment search error:', error);
    return [];
  }
}

/**
 * Batch query optimizer for multiple related queries
 */
async function executeBatchQueries(queries) {
  const pool = getPool();
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const results = [];
    for (const query of queries) {
      const result = await client.query(query.text, query.values);
      results.push(result.rows);
    }

    await client.query('COMMIT');
    return results;
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Batch query error:', error);
    throw error;
  } finally {
    client.release();
  }
}

/**
 * Clear all caches (useful for testing or when data is updated)
 */
function clearAllCaches() {
  chemicalCache.clear();
  equipmentCache.clear();
  searchCache.clear();
}

/**
 * Get cache statistics
 */
function getCacheStats() {
  return {
    chemicals: {
      size: chemicalCache.size(),
      maxSize: chemicalCache.maxSize
    },
    equipment: {
      size: equipmentCache.size(),
      maxSize: equipmentCache.maxSize
    },
    search: {
      size: searchCache.size(),
      maxSize: searchCache.maxSize
    }
  };
}

/**
 * Health check for database connection
 */
async function healthCheck() {
  const pool = getPool();
  try {
    const client = await pool.connect();
    await client.query('SELECT 1');
    client.release();
    return { status: 'healthy', pool: { totalCount: pool.totalCount, idleCount: pool.idleCount, waitingCount: pool.waitingCount } };
  } catch (error) {
    console.error('Database health check failed:', error);
    return { status: 'unhealthy', error: error.message };
  }
}

module.exports = {
  getPool,
  getChemicalsOptimized,
  getEquipmentOptimized,
  searchChemicalsOptimized,
  searchEquipmentOptimized,
  executeBatchQueries,
  clearAllCaches,
  getCacheStats,
  healthCheck,
  QueryCache
};