const express = require('express');
const Equipment = require('../models/Equipment');
const { authenticateToken } = require('../middleware/auth'); // Keep only this import
const router = express.Router();

// Get all equipment
router.get('/', authenticateToken, async (req, res) => {
  try {
    const equipment = await Equipment.findAll();
    res.json(equipment);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get equipment by ID
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const equipment = await Equipment.findById(req.params.id);
    if (!equipment) {
      return res.status(404).json({ error: 'Equipment not found' });
    }
    res.json(equipment);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create equipment
router.post('/', authenticateToken, async (req, res) => {
  try {
    const equipment = await Equipment.create(req.body);
    res.status(201).json(equipment);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update equipment
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const equipment = await Equipment.update(req.params.id, req.body);
    if (!equipment) {
      return res.status(404).json({ error: 'Equipment not found' });
    }
    res.json(equipment);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete equipment
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const equipment = await Equipment.delete(req.params.id);
    if (!equipment) {
      return res.status(404).json({ error: 'Equipment not found' });
    }
    res.json({ message: 'Equipment deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Generate equipment PDF
router.post('/generate-pdf', authenticateToken, async (req, res) => {
  try {
    const { generateEquipmentPDF } = require('../controllers/equipmentPdfController');
    await generateEquipmentPDF(req, res);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Generate equipment maintenance report
router.post('/generate-maintenance-report', authenticateToken, async (req, res) => {
  try {
    const ExcelController = require('../controllers/excelController');
    await ExcelController.generateEquipmentReport(req, res);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;