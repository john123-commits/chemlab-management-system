const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { authenticateToken, requireAdmin } = require('../middleware/auth');

const router = express.Router();

// Register - PUBLIC endpoint (borrowers only)
router.post('/register', async (req, res) => {
  try {
    const { name, email, password } = req.body;
    
    // SECURITY FIX: Only allow borrower registration through public endpoint
    // Force role to 'borrower' regardless of what's sent
    const role = 'borrower';
    
    console.log('=== PUBLIC REGISTRATION ATTEMPT ===');
    console.log('Name:', name);
    console.log('Email:', email);
    console.log('Role (forced):', role);

    // Check if user exists
    const existingUser = await User.findByEmail(email);
    if (existingUser) {
      console.log('Registration failed: User already exists');
      return res.status(400).json({ error: 'User already exists' });
    }

    // Validate password strength
    if (!password || password.length < 6) {
      console.log('Registration failed: Weak password');
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);
    console.log('Password hashed successfully');

    // Create user with forced borrower role
    const user = await User.create({ 
      name, 
      email, 
      password: hashedPassword, 
      role 
    });
    
    console.log('User created successfully:', user.id);

    // Generate token
    const token = jwt.sign(
      { userId: user.id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    console.log('Token generated successfully');

    res.status(201).json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ADMIN-ONLY USER CREATION - For technicians and admins
router.post('/register/staff', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { name, email, password, role } = req.body;
    
    console.log('=== ADMIN STAFF CREATION ATTEMPT ===');
    console.log('Creator ID:', req.user.userId);
    console.log('New user data:', { name, email, role });

    // Validate role (only allow technician or admin)
    if (role !== 'technician' && role !== 'admin') {
      console.log('Staff creation failed: Invalid role');
      return res.status(400).json({ 
        error: 'Only technician or admin roles can be created by admins' 
      });
    }

    // Check if user exists
    const existingUser = await User.findByEmail(email);
    if (existingUser) {
      console.log('Staff creation failed: User already exists');
      return res.status(400).json({ error: 'User already exists' });
    }

    // Validate password strength
    if (!password || password.length < 6) {
      console.log('Staff creation failed: Weak password');
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);
    console.log('Password hashed successfully');

    // Create staff user
    const user = await User.create({ 
      name, 
      email, 
      password: hashedPassword, 
      role 
    });
    
    console.log('Staff user created successfully:', user.id);

    // Generate token
    const token = jwt.sign(
      { userId: user.id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    console.log('Token generated successfully');

    res.status(201).json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Staff creation error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    console.log('=== LOGIN ATTEMPT ===');
    console.log('Email:', email);

    // Find user
    const user = await User.findByEmail(email);
    if (!user) {
      console.log('Login failed: User not found');
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Check password
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      console.log('Login failed: Invalid password');
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Generate token
    const token = jwt.sign(
      { userId: user.id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    // Add this route to your auth routes:
// Get current user (for auto-login)
router.get('/me', authenticateToken, async (req, res) => {
  try {
    console.log('=== AUTH ME REQUEST ===');
    console.log('User ID:', req.user.userId);
    console.log('User Role:', req.user.role);

    const user = await User.findById(req.user.userId);
    if (!user) {
      console.log('User not found for ID:', req.user.userId);
      return res.status(404).json({ error: 'User not found' });
    }
    
    console.log('User found:', user.id);
    
    res.json({
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role
    });
  } catch (error) {
    console.error('=== AUTH ME ERROR ===');
    console.error('Error:', error);
    res.status(500).json({ error: error.message });
  }
});

    console.log('Login successful for user:', user.id);

    res.json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;