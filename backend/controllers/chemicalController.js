const Chemical = require('../models/Chemical');
const multer = require('multer');
const path = require('path');

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

const getAllChemicals = async (req, res) => {
  try {
    const chemicals = await Chemical.findAll(req.query);
    res.json(chemicals);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const getChemicalById = async (req, res) => {
  try {
    const chemical = await Chemical.findById(req.params.id);
    if (!chemical) {
      return res.status(404).json({ error: 'Chemical not found' });
    }
    res.json(chemical);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const createChemical = async (req, res) => {
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
};

const updateChemical = async (req, res) => {
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
};

const deleteChemical = async (req, res) => {
  try {
    const chemical = await Chemical.delete(req.params.id);
    if (!chemical) {
      return res.status(404).json({ error: 'Chemical not found' });
    }
    res.json({ message: 'Chemical deleted successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

module.exports = {
  getAllChemicals,
  getChemicalById,
  createChemical,
  updateChemical,
  deleteChemical,
  upload
};