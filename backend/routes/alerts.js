const express = require('express');
const Chemical = require('../models/Chemical');
const Equipment = require('../models/Equipment');
const Borrowing = require('../models/Borrowing');
const { authenticateToken } = require('../middleware/auth');
const router = express.Router();



// Get all alerts
router.get('/', authenticateToken, async (req, res) => {
  try {
    const expiringChemicals = await Chemical.getExpiringSoon();
    const lowStockChemicals = await Chemical.getLowStock();
    const dueEquipment = await Equipment.getDueForMaintenance();
    const overdueBorrowings = await Borrowing.getOverdue();
    
    const alerts = [
      ...expiringChemicals.map(chem => ({
        type: 'chemical_expiry',
        message: `Chemical "${chem.name}" expires on ${new Date(chem.expiry_date).toLocaleDateString()}`,
        priority: 'high',
        item_id: chem.id
      })),
      ...lowStockChemicals.map(chem => ({
        type: 'low_stock',
        message: `Low stock for "${chem.name}" (${chem.quantity} ${chem.unit} remaining)`,
        priority: 'medium',
        item_id: chem.id
      })),
      ...dueEquipment.map(eq => ({
        type: 'equipment_maintenance',
        message: `Equipment "${eq.name}" needs maintenance`,
        priority: 'medium',
        item_id: eq.id
      })),
      ...overdueBorrowings.map(borrow => ({
        type: 'overdue_borrowing',
        message: `Overdue borrowing by ${borrow.borrower_name}`,
        priority: 'high',
        item_id: borrow.id
      }))
    ];
    
    res.json(alerts);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;