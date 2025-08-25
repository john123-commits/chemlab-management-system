const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const { authenticateToken, requireAdmin } = require('../middleware/auth');
const authController = require('../controllers/authController');

const router = express.Router();

// ✅ ENHANCED PUBLIC REGISTRATION - With institutional details
router.post('/register', async (req, res) => {
  try {
    const { 
      name, 
      email, 
      password, 
      phone, 
      studentId, 
      institution, 
      educationLevel, 
      semester, 
      department 
    } = req.body;
    
    // Force role and status for security
    const role = 'borrower';
    const status = 'pending'; // Require admin approval
    
    console.log('=== ENHANCED PUBLIC REGISTRATION ATTEMPT ===');
    console.log('Name:', name);
    console.log('Email:', email);
    console.log('Institution:', institution);
    console.log('Student ID:', studentId);
    console.log('Department:', department);
    console.log('Role (forced):', role);
    console.log('Status (forced):', status);

    // Enhanced validation
    if (!name || name.trim().length < 2) {
      return res.status(400).json({ error: 'Full name is required' });
    }

    if (!email || !email.includes('@')) {
      return res.status(400).json({ error: 'Valid email is required' });
    }

    // Institutional email validation
    const emailLower = email.toLowerCase();
    if (!emailLower.endsWith('.edu') && !emailLower.endsWith('.ac.ug') && !emailLower.endsWith('.edu.ug')) {
      return res.status(400).json({ 
        error: 'Please use your institutional email (.edu, .ac.ug, or .edu.ug)' 
      });
    }

    // Phone validation (Uganda format)
    if (!phone || !phone.match(/^(\+256|0)[0-9]{9}$/)) {
      return res.status(400).json({ 
        error: 'Please enter a valid phone number (+256XXXXXXXXX or 07XXXXXXXX)' 
      });
    }

    // Required institutional fields
    if (!studentId || studentId.trim().length < 3) {
      return res.status(400).json({ error: 'Student ID is required' });
    }

    if (!institution) {
      return res.status(400).json({ error: 'Institution is required' });
    }

    if (!educationLevel) {
      return res.status(400).json({ error: 'Education level is required' });
    }

    if (!semester) {
      return res.status(400).json({ error: 'Current semester/year is required' });
    }

    if (!department) {
      return res.status(400).json({ error: 'Department is required' });
    }

    // Check if user already exists
    const existingUser = await User.findByEmail(email);
    if (existingUser) {
      console.log('Registration failed: User already exists');
      return res.status(400).json({ error: 'User with this email already exists' });
    }

    // Check if student ID is already registered
    const existingStudentId = await User.findByStudentId(studentId);
    if (existingStudentId) {
      console.log('Registration failed: Student ID already exists');
      return res.status(400).json({ error: 'Student ID already registered' });
    }

    // Enhanced password validation
    if (!password || password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }

    if (!/^(?=.*[a-zA-Z])(?=.*\d)/.test(password)) {
      return res.status(400).json({ 
        error: 'Password must contain both letters and numbers' 
      });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);
    console.log('Password hashed successfully');

    // Create user with enhanced data
    const userData = { 
      name: name.trim(), 
      email: email.toLowerCase().trim(), 
      password: hashedPassword, 
      role,
      status,
      phone: phone.trim(),
      student_id: studentId.trim(),
      institution,
      education_level: educationLevel,
      semester,
      department
    };

    const user = await User.create(userData);
    console.log('Enhanced user created successfully:', user.id);

    // Don't generate token for pending users - they need admin approval
    res.status(201).json({
      message: 'Registration successful! Your account is pending admin approval.',
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        status: user.status,
        institution: user.institution,
        department: user.department
      }
    });

  } catch (error) {
    console.error('Enhanced registration error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ✅ ADMIN ROUTE: Approve pending users
router.post('/approve-user/:userId', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { userId } = req.params;
    
    console.log('=== ADMIN USER APPROVAL ===');
    console.log('Admin ID:', req.user.userId);
    console.log('Approving user ID:', userId);

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (user.status !== 'pending') {
      return res.status(400).json({ error: 'User is not pending approval' });
    }

    // Update user status to active
    const updatedUser = await User.updateStatus(userId, 'active');
    
    console.log('User approved successfully:', updatedUser.id);

    res.json({
      message: 'User approved successfully',
      user: {
        id: updatedUser.id,
        name: updatedUser.name,
        email: updatedUser.email,
        status: updatedUser.status
      }
    });

  } catch (error) {
    console.error('User approval error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ✅ ADMIN ROUTE: Get pending users for approval
router.get('/pending-users', authenticateToken, requireAdmin, async (req, res) => {
  try {
    console.log('=== ADMIN: GET PENDING USERS ===');
    
    const pendingUsers = await User.findPendingUsers();
    
    console.log('Found pending users:', pendingUsers.length);

    res.json({
      users: pendingUsers.map(user => ({
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        student_id: user.student_id,
        institution: user.institution,
        education_level: user.education_level,
        semester: user.semester,
        department: user.department,
        created_at: user.created_at,
        status: user.status
      }))
    });

  } catch (error) {
    console.error('Get pending users error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ✅ ADMIN ROUTE: Reject pending user
router.post('/reject-user/:userId', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { userId } = req.params;
    const { reason } = req.body;
    
    console.log('=== ADMIN USER REJECTION ===');
    console.log('Admin ID:', req.user.userId);
    console.log('Rejecting user ID:', userId);
    console.log('Reason:', reason);

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    if (user.status !== 'pending') {
      return res.status(400).json({ error: 'User is not pending approval' });
    }

    // Update user status to rejected
    const updatedUser = await User.updateStatus(userId, 'rejected', reason);
    
    console.log('User rejected successfully:', updatedUser.id);

    res.json({
      message: 'User rejected successfully',
      user: {
        id: updatedUser.id,
        name: updatedUser.name,
        email: updatedUser.email,
        status: updatedUser.status
      }
    });

  } catch (error) {
    console.error('User rejection error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ADMIN-ONLY STAFF CREATION - For technicians and admins
router.post('/register/staff', authenticateToken, requireAdmin, async (req, res) => {
  try {
    const { name, email, password, role } = req.body;
    
    console.log('=== ADMIN STAFF CREATION DEBUG ===');
    console.log('Password received:', JSON.stringify(password));
    console.log('Password length:', password ? password.length : 0);

    // Validate role
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
    console.log('About to hash password...');
    const hashedPassword = await bcrypt.hash(password, 10);
    console.log('Password hashed to:', hashedPassword);
    
    // Test the hash immediately
    const testMatch = await bcrypt.compare(password, hashedPassword);
    console.log('Immediate test of hash - should be TRUE:', testMatch);

    // Create staff user with active status (no approval needed for staff)
    const user = await User.create({ 
      name, 
      email, 
      password: hashedPassword, 
      role,
      status: 'active' // Staff accounts are immediately active
    });
    
    console.log('Stored user password in DB:', user.password);

    // Generate token
    const token = jwt.sign(
      { userId: user.id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

    res.status(201).json({
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        status: user.status
      }
    });
  } catch (error) {
    console.error('Staff creation error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ✅ USE CONTROLLER FOR LOGIN (with status check)
router.post('/login', authController.login);

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
      role: user.role,
      status: user.status,
      phone: user.phone,
      student_id: user.student_id,
      institution: user.institution,
      education_level: user.education_level,
      semester: user.semester,
      department: user.department
    });
  } catch (error) {
    console.error('=== AUTH ME ERROR ===');
    console.error('Error:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;