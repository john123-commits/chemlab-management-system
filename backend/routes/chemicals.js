const express = require('express');
const Chemical = require('../models/Chemical');
const multer = require('multer');
const path = require('path');

const router = express.Router();

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    cb(null, Date.now() + path.extname(file.originalname));
  }
});

const upload = multer({ storage: storage });

// Middleware to verify token
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid token' });
    }
    req.user = user;
    next();
  });
};

// Get all chemicals
router.get('/', authenticateToken, async (req, res) => {
  try {
    const chemicals = await Chemical.findAll(req.query);
    res.json(chemicals);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Get chemical by ID
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const chemical = await Chemical.findById(req.params.id);
    if (!chemical) {
      return res.status(404).json({ error: 'Chemical not found' });
    }
    res.json(chemical);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Create chemical
router.post('/', authenticateToken, upload.single('safety_data_sheet'), async (req, res) => {
  try {
    const chemicalData = {
      ...req.body,
      safety_data_sheet: req.file ? req.file.path : null
    };
    const chemical = await Chemical.create(chemicalData);
    res.status(201).json(chemical);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Update chemical
router.put('/:id', authenticateToken, upload.single('safety_data_sheet'), async (req, res) => {
  try {
    const chemicalData = {
      ...req.body,
      safety_data_sheet: req.file ? req.file.path : req.body.safety_data_sheet
    };
    const chemical = await Chemical.update(req.params.id, chemicalData);
    if (!chemical) {
      return res.status(404).json({ error: 'Chemical not found' });
    }
    res.json(chemical);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Delete chemical
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const chemical = await Chemical.delete(req.params.id);
    if (!chemical) {
      return res.status(404).json({ error: 'Chemical not found' });
    }
    res.json({ message: 'Chemical deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;