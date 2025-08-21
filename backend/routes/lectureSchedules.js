const express = require('express');
const LectureSchedule = require('../models/LectureSchedule');
const { authenticateToken, requireAdmin, requireAdminOrTechnician } = require('../middleware/auth');

const router = express.Router();

// Get all lecture schedules (admin/technician only)
router.get('/', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    const filters = {};
    
    if (req.user.role === 'admin') {
      filters.admin_id = req.user.userId;
    } else if (req.user.role === 'technician') {
      filters.technician_id = req.user.userId;
    }

    if (req.query.status) {
      filters.status = req.query.status;
    }

    if (req.query.date) {
      filters.scheduled_date = req.query.date;
    }

    const schedules = await LectureSchedule.findAll(filters);
    res.json(schedules);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get lecture schedule by ID
router.get('/:id', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    const schedule = await LectureSchedule.findById(req.params.id);
    
    if (!schedule) {
      return res.status(404).json({ error: 'Lecture schedule not found' });
    }

    // Check permissions
    if (req.user.role === 'admin' && schedule.admin_id !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    if (req.user.role === 'technician' && schedule.technician_id !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    res.json(schedule);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create lecture schedule (admin only)
router.post('/', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const scheduleData = {
      ...req.body,
      admin_id: req.user.userId
    };

    const schedule = await LectureSchedule.create(scheduleData);
    res.status(201).json(schedule);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update lecture schedule (admin can update, technician can confirm)
router.put('/:id', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    const schedule = await LectureSchedule.findById(req.params.id);
    
    if (!schedule) {
      return res.status(404).json({ error: 'Lecture schedule not found' });
    }

    // Admin can update everything, technician can only confirm
    let updateData = {};
    
    if (req.user.role === 'admin') {
      // Admin can update all fields
      updateData = { ...req.body };
    } else if (req.user.role === 'technician') {
      // Technician can only update status and notes
      if (req.body.status) {
        updateData.status = req.body.status;
      }
      if (req.body.technician_notes) {
        updateData.technician_notes = req.body.technician_notes;
      }
      if (req.body.status === 'confirmed') {
        updateData.confirmation_date = new Date();
      }
    }

    // Check permissions
    if (req.user.role === 'admin' && schedule.admin_id !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    if (req.user.role === 'technician' && schedule.technician_id !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const updatedSchedule = await LectureSchedule.update(req.params.id, updateData);
    if (!updatedSchedule) {
      return res.status(404).json({ error: 'Lecture schedule not found' });
    }

    res.json(updatedSchedule);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete lecture schedule (admin only)
router.delete('/:id', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const schedule = await LectureSchedule.findById(req.params.id);
    
    if (!schedule) {
      return res.status(404).json({ error: 'Lecture schedule not found' });
    }

    // Check permissions
    if (schedule.admin_id !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const deletedSchedule = await LectureSchedule.delete(req.params.id);
    if (!deletedSchedule) {
      return res.status(404).json({ error: 'Lecture schedule not found' });
    }

    res.json({ message: 'Lecture schedule deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;