const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const login = async (req, res) => {
  try {
    const { email, password } = req.body;
    console.log('=== LOGIN ATTEMPT DEBUG ===');
    console.log('Email provided:', email);
    console.log('Password provided (length):', password ? password.length : 0);
    console.log('Password provided (chars):', JSON.stringify(password));
    
    // Find user
    const user = await User.findByEmail(email);
    console.log('User lookup result:', user ? 'FOUND' : 'NOT FOUND');
    if (user) {
      console.log('User details:', {
        id: user.id,
        email: user.email,
        stored_password_hash: user.password
      });
    }
    
    if (!user) {
      console.log('=== LOGIN FAILED: USER NOT FOUND ===');
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Check password
    console.log('Comparing passwords...');
    console.log('Input password length:', password.length);
    console.log('Input password chars:', JSON.stringify(password));
    console.log('Stored hash:', user.password);
    console.log('Stored hash length:', user.password.length);
    
    const isMatch = await bcrypt.compare(password, user.password);
    console.log('Password match result:', isMatch);
    
    if (!isMatch) {
      console.log('=== LOGIN FAILED: PASSWORD MISMATCH ===');
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    console.log('=== LOGIN SUCCESSFUL ===');
    // Generate token
    const token = jwt.sign(
      { userId: user.id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '24h' }
    );

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
    console.log('=== LOGIN ERROR ===');
    console.log('Error details:', error);
    res.status(500).json({ error: error.message });
  }
};

// ✅ ENHANCED REGISTRATION FUNCTION
const register = async (req, res) => {
  try {
    const {
      name,
      email,
      password,
      phone,
      studentId,
      institution,
      department,
      educationLevel,
      semester
    } = req.body;
    
    console.log('=== ENHANCED REGISTRATION ATTEMPT ===');
    console.log('Registration data:', {
      name,
      email,
      phone,
      studentId,
      institution,
      department,
      educationLevel,
      semester
    });

    // Validate required fields
    if (!name || !email || !password) {
      console.log('Registration failed: Missing required fields');
      return res.status(400).json({ error: 'Name, email, and password are required' });
    }

    // Validate password strength
    if (password.length < 8) {
      console.log('Registration failed: Weak password');
      return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }

    // Check if user exists
    const existingUser = await User.findByEmail(email);
    if (existingUser) {
      console.log('Registration failed: User already exists');
      return res.status(400).json({ error: 'User already exists' });
    }

    // Hash password
    console.log('Hashing password...');
    const hashedPassword = await bcrypt.hash(password, 10);
    console.log('Password hashed successfully');

    // Create user with all institutional fields
    const user = await User.create({
      name,
      email,
      password: hashedPassword,
      phone,
      student_id: studentId,
      institution,
      department,
      education_level: educationLevel,
      semester,
      role: 'borrower' // Force borrower role for public registration
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
        role: user.role,
        phone: user.phone,
        studentId: user.student_id,
        institution: user.institution,
        department: user.department,
        educationLevel: user.education_level,
        semester: user.semester
      }
    });
  } catch (error) {
    console.error('Registration error:', error);
    res.status(500).json({ error: error.message });
  }
};

// ✅ EXPORT BOTH FUNCTIONS
module.exports = {
  login,
  register
};