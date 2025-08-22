const express = require('express');
const Borrowing = require('../models/Borrowing');
const { authenticateToken } = require('../middleware/auth');
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
    // Check permissions
    if (req.user.role !== 'admin' && req.user.role !== 'technician') {
      return res.status(403).json({ error: 'Permission denied' });
    }
    
    const { status, notes, rejection_reason } = req.body;
    
    // Validate status
    const validStatuses = ['pending', 'approved', 'rejected', 'returned'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }
    
    // Additional validation for technician vs admin actions
    const borrowing = await Borrowing.findById(req.params.id);
    if (!borrowing) {
      return res.status(404).json({ error: 'Borrowing not found' });
    }
    
    // Prevent technicians from approving already approved requests by admin
    if (req.user.role === 'technician' && borrowing.status === 'approved' && status === 'approved') {
      return res.status(400).json({ error: 'Request already approved' });
    }
    
    // Prevent admin from approving rejected requests
    if (req.user.role === 'admin' && borrowing.status === 'rejected' && status === 'approved') {
      return res.status(400).json({ error: 'Cannot approve rejected request' });
    }
    
    const updatedBorrowing = await Borrowing.updateStatus(
      req.params.id, 
      status, 
      req.user.userId, 
      req.user.role, 
      notes,
      rejection_reason
    );
    
    if (!updatedBorrowing) {
      return res.status(404).json({ error: 'Borrowing not found' });
    }
    
    res.json(updatedBorrowing);
  } catch (error) {
    console.error('Error updating borrowing status:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get pending requests count (for dashboard alerts)
router.get('/pending/count', authenticateToken, async (req, res) => {
  try {
    // Only admin and technician can see pending requests count
    if (req.user.role !== 'admin' && req.user.role !== 'technician') {
      return res.status(403).json({ error: 'Permission denied' });
    }
    
    const count = await Borrowing.getPendingRequestsCount();
    res.json({ count });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get pending requests (for admin/technician review)
router.get('/pending', authenticateToken, async (req, res) => {
  try {
    // Only admin and technician can see pending requests
    if (req.user.role !== 'admin' && req.user.role !== 'technician') {
      return res.status(403).json({ error: 'Permission denied' });
    }
    
    const pendingRequests = await Borrowing.getPendingRequests();
    res.json(pendingRequests);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;