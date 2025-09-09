const express = require('express');
const LectureSchedule = require('../models/LectureSchedule');
const { authenticateToken, requireAdmin, requireAdminOrTechnician } = require('../middleware/auth');
const emailService = require('../services/emailService');
const User = require('../models/User');

// Server-Sent Events for real-time lecture schedule updates
let scheduleClients = new Map(); // Store connected clients by user ID

// Function to broadcast schedule updates to connected clients
function broadcastScheduleUpdate(schedule, action) {
  const eventData = {
    type: 'schedule_update',
    action: action,
    schedule: {
      id: schedule.id,
      title: schedule.title,
      status: schedule.status,
      scheduled_date: schedule.scheduled_date,
      scheduled_time: schedule.scheduled_time,
      technician_notes: schedule.technician_notes,
      confirmation_date: schedule.confirmation_date,
      updated_at: schedule.updated_at
    }
  };

  // Send to admin who created the schedule
  if (schedule.admin_id && scheduleClients.has(schedule.admin_id)) {
    const adminClients = scheduleClients.get(schedule.admin_id);
    adminClients.forEach(client => {
      try {
        client.write(`data: ${JSON.stringify(eventData)}\n\n`);
      } catch (error) {
        console.error('Error sending to admin client:', error);
        adminClients.delete(client);
      }
    });
  }

  // Send to technician if assigned
  if (schedule.technician_id && scheduleClients.has(schedule.technician_id)) {
    const techClients = scheduleClients.get(schedule.technician_id);
    techClients.forEach(client => {
      try {
        client.write(`data: ${JSON.stringify(eventData)}\n\n`);
      } catch (error) {
        console.error('Error sending to technician client:', error);
        techClients.delete(client);
      }
    });
  }

  console.log(`Broadcasted ${action} for schedule ${schedule.id} to ${schedule.admin_id}, ${schedule.technician_id}`);
}

const router = express.Router();

// SSE endpoint for real-time schedule updates (must be after router declaration)
router.get('/events/:userId', authenticateToken, (req, res) => {
  const userId = req.params.userId;
  
  // Verify user can access their own events
  if (req.user.userId !== parseInt(userId)) {
    return res.status(403).json({ error: 'Access denied' });
  }

  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Cache-Control'
  });

  // Store client connection
  if (!scheduleClients.has(userId)) {
    scheduleClients.set(userId, new Set());
  }
  scheduleClients.get(userId).add(res);

  req.on('close', () => {
    scheduleClients.get(userId)?.delete(res);
    if (scheduleClients.get(userId)?.size === 0) {
      scheduleClients.delete(userId);
    }
  });

  // Send initial connection confirmation
  res.write(`data: ${JSON.stringify({ type: 'connected', message: 'Connected to lecture schedule updates' })}\n\n`);

  console.log(`User ${userId} connected to schedule events`);
});

// Get all lecture schedules (admin/technician only)
router.get('/', authenticateToken, requireAdminOrTechnician, async (req, res) => {
  try {
    const filters = {};
    
    // Admins can see all schedules, technicians see only theirs
    if (req.user.role === 'technician') {
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
    console.error('Error in LectureSchedule.findAll:', error);
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

    // Check permissions - admins can see all, technicians only theirs
    if (req.user.role === 'technician' && schedule.technician_id !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    res.json(schedule);
  } catch (error) {
    console.error('Error in LectureSchedule.findById:', error);
    res.status(500).json({ error: error.message });
  }
});

// Create lecture schedule (admin only)
router.post('/', authenticateToken, requireAdmin, async (req, res) => {
  try {
    // Format arrays as JSON strings
    const formattedChemicals = Array.isArray(req.body.required_chemicals) 
      ? JSON.stringify(req.body.required_chemicals) 
      : '[]';
    const formattedEquipment = Array.isArray(req.body.required_equipment) 
      ? JSON.stringify(req.body.required_equipment) 
      : '[]';
    
    const scheduleData = {
      ...req.body,
      admin_id: req.user.userId,
      required_chemicals: formattedChemicals,
      required_equipment: formattedEquipment
    };

    console.log('Creating lecture schedule with data:', scheduleData);

    const schedule = await LectureSchedule.create(scheduleData);

    // Send notification to technician if assigned
    if (schedule.technician_id) {
      try {
        const technician = await User.findById(schedule.technician_id);
        if (technician && technician.email) {
          const subject = `New Lecture Schedule Assigned: ${schedule.title}`;
          const message = `
Dear ${technician.name},

A new lecture schedule has been assigned to you:

Title: ${schedule.title}
Description: ${schedule.description || 'No description provided'}
Date: ${schedule.scheduled_date}
Time: ${schedule.scheduled_time}
Duration: ${schedule.duration || 0} minutes
Priority: ${schedule.priority}

Please review and confirm this schedule at your earliest convenience.

Best regards,
Chemistry Lab Management System
          `;

          await emailService.sendLectureScheduleNotification(
            technician.email,
            subject,
            message.trim()
          );
        }
      } catch (emailError) {
        console.error('Failed to send notification email:', emailError);
        // Don't fail the request if email fails
      }
    }

    res.status(201).json(schedule);
  } catch (error) {
    console.error('Error in LectureSchedule.create:', error);
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

    // Check permissions
    if (req.user.role === 'technician' && schedule.technician_id !== req.user.userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Admin can update everything except confirming, technician can only confirm
    let updateData = {};

    if (req.user.role === 'admin') {
      // Prevent admin from confirming the schedule
      if (req.body.status === 'confirmed') {
        return res.status(403).json({ error: 'Only technicians can confirm lecture schedules' });
      }

      // Admin can update all other fields
      updateData = { ...req.body };

      // Format arrays as JSON strings if provided
      if (req.body.required_chemicals !== undefined) {
        updateData.required_chemicals = Array.isArray(req.body.required_chemicals)
          ? JSON.stringify(req.body.required_chemicals)
          : '[]';
      }

      if (req.body.required_equipment !== undefined) {
        updateData.required_equipment = Array.isArray(req.body.required_equipment)
          ? JSON.stringify(req.body.required_equipment)
          : '[]';
      }
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

    const updatedSchedule = await LectureSchedule.update(req.params.id, updateData);
    if (!updatedSchedule) {
      return res.status(404).json({ error: 'Lecture schedule not found' });
    }

    // Send notification to admin when technician confirms/rejects
    if (req.user.role === 'technician' && (req.body.status === 'confirmed' || req.body.status === 'rejected')) {
      try {
        const admin = await User.findById(updatedSchedule.admin_id);
        if (admin && admin.email) {
          const technician = await User.findById(updatedSchedule.technician_id);
          const technicianName = technician ? technician.name : 'Technician';

          const statusText = req.body.status === 'confirmed' ? 'confirmed' : 'rejected';
          const subject = `Lecture Schedule ${statusText.charAt(0).toUpperCase() + statusText.slice(1)}: ${updatedSchedule.title}`;

          let message = `
Dear ${admin.name},

The lecture schedule "${updatedSchedule.title}" has been ${statusText} by ${technicianName}.

Schedule Details:
- Title: ${updatedSchedule.title}
- Date: ${updatedSchedule.scheduled_date}
- Time: ${updatedSchedule.scheduled_time}
- Duration: ${updatedSchedule.duration || 0} minutes
- Priority: ${updatedSchedule.priority}
`;

          if (updatedSchedule.technician_notes) {
            message += `
Technician Notes:
${updatedSchedule.technician_notes}
`;
          }

          if (req.body.status === 'rejected' && updatedSchedule.rejection_reason) {
            message += `
Rejection Reason:
${updatedSchedule.rejection_reason}
`;
          }

          message += `
Please review the schedule details in the system.

Best regards,
Chemistry Lab Management System
          `;

          await emailService.sendLectureScheduleNotification(
            admin.email,
            subject,
            message.trim()
          );
        }
      } catch (emailError) {
        console.error('Failed to send notification email:', emailError);
        // Don't fail the request if email fails
      }

      // Broadcast real-time update to connected clients
      broadcastScheduleUpdate(updatedSchedule, req.body.status);
    }

    res.json(updatedSchedule);
  } catch (error) {
    console.error('Error in LectureSchedule.update:', error);
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
    console.error('Error in LectureSchedule.delete:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;

// Graceful cleanup for SSE connections on server shutdown
process.on('SIGINT', () => {
  console.log('Shutting down server...');
  scheduleClients.forEach(clients => {
    clients.forEach(client => {
      client.end();
    });
  });
  scheduleClients.clear();
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('Server terminated...');
  scheduleClients.forEach(clients => {
    clients.forEach(client => {
      client.end();
    });
  });
  scheduleClients.clear();
  process.exit(0);
});