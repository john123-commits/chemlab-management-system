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
    
    // Test with known password
    const testMatch = await bcrypt.compare('password123', user.password);
    console.log('Test with "password123":', testMatch);
    
    if (!isMatch) {
      console.log('=== LOGIN FAILED: PASSWORD MISMATCH ===');
      
      // Test with trimmed password
      const trimmedPassword = password.trim();
      if (trimmedPassword !== password) {
        console.log('Testing with trimmed password...');
        const trimmedMatch = await bcrypt.compare(trimmedPassword, user.password);
        console.log('Trimmed password match:', trimmedMatch);
        if (trimmedMatch) {
          console.log('SUCCESS: Password matched after trimming!');
        }
      }
      
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

// ✅ THIS IS THE CRITICAL PART - EXPORT THE FUNCTION
module.exports = {
  login
};