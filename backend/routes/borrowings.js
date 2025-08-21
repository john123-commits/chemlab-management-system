const express = require('express');
const Borrowing = require('../models/Borrowing');
const { authenticateToken } = require('../middleware/auth'); // Keep only this import
const router = express.Router();

// Get all borrowings
router.get('/', authenticateToken, async (req, res) => {
  try {
    const filters = {};
    if (req.user.role !== 'admin' && req.user.role !== 'technician') {
      filters.borrower_id = req.user.userId;
    }
    if (req.query.status) {
      filters.status = req.query.status;
    }
    
    const borrowings = await Borrowing.findAll(filters);
    res.json(borrowings);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get borrowing by ID
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const borrowing = await Borrowing.findById(req.params.id);
    if (!borrowing) {
      return res.status(404).json({ error: 'Borrowing not found' });
    }
    
    // Check permissions
    if (req.user.role !== 'admin' && req.user.role !== 'technician' && 
        borrowing.borrower_id != req.user.userId) {
      return res.status(403).json({ error: 'Permission denied' });
    }
    
    res.json(borrowing);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create borrowing request
router.post('/', authenticateToken, async (req, res) => {
  try {
    const borrowingData = {
      ...req.body,
      borrower_id: req.user.userId
    };
    const borrowing = await Borrowing.create(borrowingData);
    res.status(201).json(borrowing);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update borrowing status (admin/technician only)
router.put('/:id/status', authenticateToken, async (req, res) => {
  try {
    if (req.user.role !== 'admin' && req.user.role !== 'technician') {
      return res.status(403).json({ error: 'Permission denied' });
    }
    
    const { status, notes } = req.body;
    const borrowing = await Borrowing.updateStatus(req.params.id, status, notes);
    if (!borrowing) {
      return res.status(404).json({ error: 'Borrowing not found' });
    }
    res.json(borrowing);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;