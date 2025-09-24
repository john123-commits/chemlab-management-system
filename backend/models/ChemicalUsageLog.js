const db = require('../config/db');

class ChemicalUsageLog {
    static async create(usageData) {
        try {
            // Start transaction for data consistency
            await db.query('BEGIN');

            // Get current chemical data
            const chemicalResult = await db.query(
                'SELECT quantity, unit, name FROM chemicals WHERE id = $1',
                [usageData.chemical_id]
            );

            if (chemicalResult.rows.length === 0) {
                throw new Error('Chemical not found');
            }

            const chemical = chemicalResult.rows[0];
            const currentQuantity = parseFloat(chemical.quantity);
            const quantityUsed = parseFloat(usageData.quantity_used);
            const newRemainingQuantity = currentQuantity - quantityUsed;

            // Validate sufficient quantity
            if (newRemainingQuantity < 0) {
                throw new Error(`Insufficient quantity. Available: ${currentQuantity}${chemical.unit}, Requested: ${quantityUsed}${chemical.unit}`);
            }

            // Insert usage log
            const result = await db.query(
                `INSERT INTO chemical_usage_logs
                 (chemical_id, user_id, quantity_used, remaining_quantity, usage_date, purpose, notes, experiment_reference)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
                [
                    usageData.chemical_id,
                    usageData.user_id,
                    quantityUsed,
                    newRemainingQuantity,
                    usageData.usage_date || new Date(),
                    usageData.purpose || '',
                    usageData.notes || '',
                    usageData.experiment_reference || ''
                ]
            );

            await db.query('COMMIT');

            return {
                success: true,
                data: result.rows[0],
                message: `Successfully logged usage of ${quantityUsed}${chemical.unit} of ${chemical.name}. Remaining: ${newRemainingQuantity}${chemical.unit}`
            };

        } catch (error) {
            await db.query('ROLLBACK');
            throw error;
        }
    }

    static async getByChemicalId(chemicalId, limit = 50, offset = 0) {
        const result = await db.query(
            `SELECT cul.*, u.name as user_name, c.name as chemical_name, c.unit
             FROM chemical_usage_logs cul
             JOIN users u ON cul.user_id = u.id
             JOIN chemicals c ON cul.chemical_id = c.id
             WHERE cul.chemical_id = $1
             ORDER BY cul.usage_date DESC
             LIMIT $2 OFFSET $3`,
            [chemicalId, limit, offset]
        );

        // Ensure numeric fields are properly typed
        return result.rows.map(row => ({
            ...row,
            quantity_used: parseFloat(row.quantity_used),
            remaining_quantity: parseFloat(row.remaining_quantity)
        }));
    }

    static async getAllUsage(limit = 100, offset = 0) {
        const result = await db.query(
            `SELECT cul.*, u.name as user_name, c.name as chemical_name, c.unit
             FROM chemical_usage_logs cul
             JOIN users u ON cul.user_id = u.id
             JOIN chemicals c ON cul.chemical_id = c.id
             ORDER BY cul.usage_date DESC
             LIMIT $1 OFFSET $2`,
            [limit, offset]
        );

        // Ensure numeric fields are properly typed
        return result.rows.map(row => ({
            ...row,
            quantity_used: parseFloat(row.quantity_used),
            remaining_quantity: parseFloat(row.remaining_quantity)
        }));
    }

    static async getUsageStats(chemicalId) {
        const result = await db.query(
            `SELECT
                COUNT(*) as total_usage_entries,
                SUM(quantity_used) as total_quantity_used,
                AVG(quantity_used) as average_usage,
                MIN(usage_date) as first_usage_date,
                MAX(usage_date) as last_usage_date
             FROM chemical_usage_logs
             WHERE chemical_id = $1`,
            [chemicalId]
        );

        const stats = result.rows[0];
        if (stats) {
            return {
                ...stats,
                total_usage_entries: parseInt(stats.total_usage_entries),
                total_quantity_used: parseFloat(stats.total_quantity_used || 0),
                average_usage: parseFloat(stats.average_usage || 0)
            };
        }
        return stats;
    }

    static async getUsageSummary() {
        const todayResult = await db.query(`
            SELECT
                COUNT(DISTINCT chemical_id) as chemicals_used_today,
                SUM(quantity_used) as total_quantity_used_today,
                COUNT(*) as total_usage_entries_today
            FROM chemical_usage_logs
            WHERE DATE(usage_date) = CURRENT_DATE
        `);

        const topChemicalsResult = await db.query(`
            SELECT
                c.name,
                c.unit,
                SUM(cul.quantity_used) as total_used_this_week,
                COUNT(cul.id) as usage_count
            FROM chemical_usage_logs cul
            JOIN chemicals c ON cul.chemical_id = c.id
            WHERE cul.usage_date >= CURRENT_DATE - INTERVAL '7 days'
            GROUP BY c.id, c.name, c.unit
            ORDER BY total_used_this_week DESC
            LIMIT 5
        `);

        const recentUsageResult = await db.query(`
            SELECT
                c.name as chemical_name,
                u.name as user_name,
                cul.quantity_used,
                c.unit,
                cul.purpose,
                cul.usage_date
            FROM chemical_usage_logs cul
            JOIN chemicals c ON cul.chemical_id = c.id
            JOIN users u ON cul.user_id = u.id
            ORDER BY cul.usage_date DESC
            LIMIT 10
        `);

        // Ensure numeric fields are properly typed
        const todaySummary = todayResult.rows[0] ? {
            ...todayResult.rows[0],
            total_quantity_used_today: parseFloat(todayResult.rows[0].total_quantity_used_today || 0)
        } : { chemicals_used_today: 0, total_quantity_used_today: 0, total_usage_entries_today: 0 };

        const topChemicals = topChemicalsResult.rows.map(row => ({
            ...row,
            total_used_this_week: parseFloat(row.total_used_this_week || 0)
        }));

        const recentUsage = recentUsageResult.rows.map(row => ({
            ...row,
            quantity_used: parseFloat(row.quantity_used || 0)
        }));

        return {
            today_summary: todaySummary,
            top_used_chemicals: topChemicals,
            recent_usage: recentUsage
        };
    }
}

module.exports = ChemicalUsageLog;