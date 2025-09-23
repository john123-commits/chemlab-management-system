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

// Mark alert as resolved
router.put('/:id/resolve', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { alertType } = req.body;

    // In a real implementation, you would store alerts in a database
    // For now, we'll just return success
    console.log(`Alert ${id} of type ${alertType} marked as resolved by user ${req.user.id}`);

    res.json({
      success: true,
      message: 'Alert marked as resolved',
      alertId: id,
      resolvedAt: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Schedule maintenance for equipment
router.post('/equipment/:id/schedule-maintenance', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { scheduledDate, notes } = req.body;

    // Update equipment maintenance schedule
    const result = await db.query(
      'UPDATE equipment SET last_maintenance_date = CURRENT_DATE, next_maintenance_date = $1, notes = COALESCE($2, notes) WHERE id = $3',
      [scheduledDate, notes, id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Equipment not found' });
    }

    console.log(`Maintenance scheduled for equipment ${id} by user ${req.user.id}`);

    res.json({
      success: true,
      message: 'Maintenance scheduled successfully',
      equipmentId: id,
      scheduledDate: scheduledDate,
      scheduledAt: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Order supplies for low stock items
router.post('/chemical/:id/order-supplies', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { quantity, notes } = req.body;

    // Update chemical quantity (simulate ordering)
    const result = await db.query(
      'UPDATE chemicals SET quantity = quantity + $1, notes = COALESCE($2, notes) WHERE id = $3',
      [quantity, notes, id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Chemical not found' });
    }

    console.log(`Supplies ordered for chemical ${id} by user ${req.user.id}`);

    res.json({
      success: true,
      message: 'Supplies ordered successfully',
      chemicalId: id,
      quantityOrdered: quantity,
      orderedAt: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Send reminder for overdue borrowing
router.post('/borrowing/:id/send-reminder', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { message } = req.body;

    // Get borrowing details
    const borrowing = await db.query(
      'SELECT * FROM borrowings WHERE id = $1',
      [id]
    );

    if (borrowing.rows.length === 0) {
      return res.status(404).json({ error: 'Borrowing not found' });
    }

    const borrowingData = borrowing.rows[0];

    // In a real implementation, you would send an email or notification
    // For now, we'll just log it
    console.log(`Reminder sent for overdue borrowing ${id} by user ${req.user.id}`);
    console.log(`Borrower: ${borrowingData.borrower_name}, Item: ${borrowingData.item_name}`);

    res.json({
      success: true,
      message: 'Reminder sent successfully',
      borrowingId: id,
      sentAt: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Contact user for overdue borrowing
router.post('/borrowing/:id/contact-user', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { contactMethod, message } = req.body;

    // Get borrowing details
    const borrowing = await db.query(
      'SELECT * FROM borrowings WHERE id = $1',
      [id]
    );

    if (borrowing.rows.length === 0) {
      return res.status(404).json({ error: 'Borrowing not found' });
    }

    const borrowingData = borrowing.rows[0];

    // In a real implementation, you would send email, SMS, or other notification
    // For now, we'll just log it
    console.log(`User contacted for overdue borrowing ${id} via ${contactMethod} by user ${req.user.id}`);
    console.log(`Borrower: ${borrowingData.borrower_name}, Item: ${borrowingData.item_name}`);

    res.json({
      success: true,
      message: 'User contacted successfully',
      borrowingId: id,
      contactMethod: contactMethod,
      contactedAt: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;