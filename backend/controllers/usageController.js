const ChemicalUsageLog = require('../models/ChemicalUsageLog');
const Chemical = require('../models/Chemical');

class UsageController {
    static async logUsage(req, res) {
        try {
            const { chemical_id } = req.params;
            const {
                quantity_used,
                purpose,
                notes,
                experiment_reference,
                usage_date
            } = req.body;

            // Validate input
            if (!quantity_used || quantity_used <= 0) {
                return res.status(400).json({
                    success: false,
                    message: 'Quantity used must be greater than 0'
                });
            }

            const usageData = {
                chemical_id: parseInt(chemical_id),
                user_id: req.user.id,
                quantity_used: parseFloat(quantity_used),
                purpose,
                notes,
                experiment_reference,
                usage_date: usage_date ? new Date(usage_date) : new Date()
            };

            const result = await ChemicalUsageLog.create(usageData);

            // Also return updated chemical information
            const updatedChemical = await Chemical.findById(chemical_id);
            const usageStats = await ChemicalUsageLog.getUsageStats(chemical_id);

            res.json({
                ...result,
                updatedChemical: {
                    id: updatedChemical.id,
                    name: updatedChemical.name,
                    current_quantity: updatedChemical.quantity,
                    unit: updatedChemical.unit,
                    total_used: updatedChemical.total_used,
                    last_used_date: updatedChemical.last_used_date
                },
                usageStats: usageStats
            });

        } catch (error) {
            console.error('Error logging chemical usage:', error);
            res.status(500).json({
                success: false,
                message: error.message || 'Failed to log chemical usage'
            });
        }
    }

    static async getChemicalUsageHistory(req, res) {
        try {
            const { chemical_id } = req.params;
            const { limit = 50, offset = 0 } = req.query;

            const usageLogs = await ChemicalUsageLog.getByChemicalId(
                parseInt(chemical_id),
                parseInt(limit),
                parseInt(offset)
            );

            const stats = await ChemicalUsageLog.getUsageStats(parseInt(chemical_id));

            res.json({
                success: true,
                data: {
                    usage_logs: usageLogs,
                    statistics: stats,
                    pagination: {
                        limit: parseInt(limit),
                        offset: parseInt(offset)
                    }
                }
            });

        } catch (error) {
            console.error('Error fetching usage history:', error);
            res.status(500).json({
                success: false,
                message: 'Failed to fetch usage history'
            });
        }
    }

    static async getAllUsageLogs(req, res) {
        try {
            const { limit = 100, offset = 0 } = req.query;

            const usageLogs = await ChemicalUsageLog.getAllUsage(
                parseInt(limit),
                parseInt(offset)
            );

            res.json({
                success: true,
                data: {
                    usage_logs: usageLogs,
                    pagination: {
                        limit: parseInt(limit),
                        offset: parseInt(offset)
                    }
                }
            });

        } catch (error) {
            console.error('Error fetching all usage logs:', error);
            res.status(500).json({
                success: false,
                message: 'Failed to fetch usage logs'
            });
        }
    }

    static async getUsageSummary(req, res) {
        try {
            const summary = await ChemicalUsageLog.getUsageSummary();

            res.json({
                success: true,
                data: summary
            });

        } catch (error) {
            console.error('Error fetching usage summary:', error);
            res.status(500).json({
                success: false,
                message: 'Failed to fetch usage summary'
            });
        }
    }
}

module.exports = UsageController;