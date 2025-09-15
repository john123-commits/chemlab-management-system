const express = require('express');
const Borrowing = require('../models/Borrowing');
const Equipment = require('../models/Equipment'); // ✅ Keep Equipment import
const { authenticateToken, requireAdminOrTechnician } = require('../middleware/auth');

const router = express.Router();

// Get all borrowings - Allow borrowers to see their own requests
router.get('/', authenticateToken, async (req, res) => {
  try {
    const filters = {};
    
    // Borrowers can only see their own requests
    if (req.user.role === 'borrower') {
      filters.borrower_id = req.user.userId;
    }
    
    // Admins and technicians can filter by borrower_id and status
    if (req.user.role !== 'borrower') {
      if (req.query.borrower_id) {
        filters.borrower_id = req.query.borrower_id;
      }
      if (req.query.status) {
        filters.status = req.query.status;
      }
    } else {
      // Borrowers can only filter by their own status
      if (req.query.status) {
        filters.status = req.query.status;
      }
    }
    
    const borrowings = await Borrowing.findAll(filters);
    res.json(borrowings);
  } catch (error) {
    console.error('Error in Borrowing.findAll:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get borrowing by ID - Allow borrowers to see their own requests
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
    console.error('Error in Borrowing.findById:', error);
    res.status(500).json({ error: error.message });
  }
});

// Create borrowing request - Allow borrowers to create requests
router.post('/', authenticateToken, async (req, res) => {
  try {
    const borrowingData = {
      ...req.body,
      borrower_id: req.user.userId
    };
    const borrowing = await Borrowing.create(borrowingData);
    res.status(201).json(borrowing);
  } catch (error) {
    console.error('Error in Borrowing.create:', error);
    res.status(500).json({ error: error.message });
  }
});

// Update borrowing status (admin/technician only)
router.put('/:id/status', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
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

// Get pending requests count (for dashboard alerts) - Admin/Technician only
router.get('/pending/count', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    const count = await Borrowing.getPendingRequestsCount();
    res.json({ count });
  } catch (error) {
    console.error('Error in Borrowing.getPendingRequestsCount:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get pending requests (for admin/technician review) - Admin/Technician only
router.get('/pending', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    const pendingRequests = await Borrowing.getPendingRequests();
    res.json(pendingRequests);
  } catch (error) {
    console.error('Error in Borrowing.getPendingRequests:', error);
    res.status(500).json({ error: error.message });
  }
});

// ✅ FIXED: Mark borrowing as returned with proper error handling
router.post('/:id/return', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    const { equipmentCondition, returnNotes } = req.body;
    const borrowingId = req.params.id;
    const confirmedByUserId = req.user.userId;
    
    console.log('=== RETURN REQUEST RECEIVED ===');
    console.log('Borrowing ID:', borrowingId);
    console.log('Equipment Condition:', equipmentCondition);
    console.log('Return Notes:', returnNotes);
    console.log('Confirmed By User ID:', confirmedByUserId);
    
    // ✅ VALIDATE: Check if required data exists
    if (!equipmentCondition) {
      console.error('Equipment condition data is missing');
      return res.status(400).json({ 
        error: 'Equipment condition data is required' 
      });
    }

    // ✅ VALIDATE: Check if equipmentCondition is an object
    if (typeof equipmentCondition !== 'object' || equipmentCondition === null) {
      console.error('Equipment condition must be an object');
      return res.status(400).json({ 
        error: 'Equipment condition must be a valid object' 
      });
    }

    // Mark borrowing as returned
    const updatedBorrowing = await Borrowing.markAsReturned(
      borrowingId, 
      { equipmentCondition, returnNotes }, 
      confirmedByUserId
    );
    
    // ✅ Update equipment quantities back in inventory (if Equipment model exists)
    try {
      if (typeof Equipment !== 'undefined' && Equipment.updateCondition) {
        for (const [equipmentId, condition] of Object.entries(equipmentCondition)) {
          // Update equipment status/condition in inventory
          await Equipment.updateCondition(equipmentId, condition.status);
        }
      }
    } catch (equipmentError) {
      console.warn('Warning: Could not update equipment inventory:', equipmentError);
      // Don't fail the whole operation if equipment update fails
    }
    
    console.log('Successfully updated borrowing:', updatedBorrowing);
    res.json(updatedBorrowing);
  } catch (error) {
    console.error('Error marking borrowing as returned:', error);
    res.status(500).json({ 
      error: `Failed to mark borrowing as returned: ${error.message}` 
    });
  }
});

// ✅ FIXED: Get active (not returned) borrowings
router.get('/active', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    console.log('Fetching active borrowings for user:', req.user.userId);
    const borrowings = await Borrowing.getActiveBorrowings();
    console.log('Found active borrowings:', borrowings.length);
    res.json(borrowings);
  } catch (error) {
    console.error('Error fetching active borrowings:', error);
    res.status(500).json({ error: `Failed to load active borrowings: ${error.message}` });
  }
});

// Delete borrowing request - Admin/Technician only for pending/rejected requests
router.delete('/:id', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    const borrowingId = req.params.id;
    const deletedByUserId = req.user.userId;
    const deletedByRole = req.user.role;
    
    console.log('Delete request received:', { borrowingId, deletedByUserId, deletedByRole });
    
    // Delete the borrowing using the model method
    const deletedBorrowing = await Borrowing.deleteById(borrowingId, deletedByUserId, deletedByRole);
    
    if (!deletedBorrowing) {
      return res.status(404).json({ error: 'Borrowing not found or cannot be deleted' });
    }
    
    console.log('Successfully deleted borrowing:', deletedBorrowing.id);
    res.json({
      message: 'Borrowing request deleted successfully',
      deletedBorrowing: {
        id: deletedBorrowing.id,
        borrower_name: deletedBorrowing.borrower_name,
        status: deletedBorrowing.status,
        created_at: deletedBorrowing.created_at
      }
    });
  } catch (error) {
    console.error('Error deleting borrowing:', error);
    if (error.message.includes('Cannot delete approved or returned')) {
      return res.status(400).json({ error: 'Cannot delete approved or returned borrowing requests' });
    }
    if (error.message.includes('Permission denied')) {
      return res.status(403).json({ error: 'Permission denied: insufficient role to delete this request' });
    }
    res.status(500).json({ error: `Failed to delete borrowing request: ${error.message}` });
  }
});

module.exports = router;