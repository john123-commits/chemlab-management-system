const login = async (req, res) => {
  try {
    const { email, password } = req.body;
    console.log('=== LOGIN ATTEMPT DEBUG ===');
    console.log('Email provided:', email);
    console.log('Password provided:', password ? '[PROVIDED]' : '[MISSING]');
    
    // Find user
    const user = await User.findByEmail(email);
    console.log('User lookup result:', user ? 'FOUND' : 'NOT FOUND');
    if (user) {
      console.log('User details:', {
        id: user.id,
        email: user.email,
        stored_password_hash: user.password ? user.password.substring(0, 20) + '...' : '[MISSING]'
      });
    }
    
    if (!user) {
      console.log('=== LOGIN FAILED: USER NOT FOUND ===');
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    // Check password
    console.log('Comparing passwords...');
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