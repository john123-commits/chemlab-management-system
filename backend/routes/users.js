const express = require('express');
const User = require('../models/User');
const { authenticateToken, requireAdmin } = require('../middleware/auth');

const router = express.Router();

// Get all users (admin only)
router.get('/', authenticateToken, requireAdmin, async (req, res) => {
  try {
    console.log('=== USERS ROUTE: GET ALL USERS ===');
    console.log('User making request:', req.user);
    
    const users = await User.findAll();
    console.log(`Found ${users.length} users`);
    
    // Return only necessary user information
    const sanitizedUsers = users.map(user => ({
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      created_at: user.created_at
    }));
    
    res.json(sanitizedUsers);
  } catch (error) {
    console.error('Error in Users.findAll:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get user by ID (authenticated users can get their own info, admins can get any)
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    console.log('=== USERS ROUTE: GET USER BY ID ===');
    console.log('Requested user ID:', req.params.id);
    console.log('Authenticated user:', req.user);
    
    // Check permissions - users can only get their own info unless admin
    if (req.user.userId != req.params.id && req.user.role !== 'admin') {
      console.log('Permission denied: User trying to access another user\'s data');
      return res.status(403).json({ error: 'Permission denied' });
    }

    const user = await User.findById(req.params.id);
    if (!user) {
      console.log('User not found');
      return res.status(404).json({ error: 'User not found' });
    }
    
    console.log('User found:', user.id);
    
    // Return sanitized user information
    const sanitizedUser = {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      created_at: user.created_at
    };
    
    res.json(sanitizedUser);
  } catch (error) {
    console.error('Error in Users.findById:', error);
    res.status(500).json({ error: error.message });
  }
});

// Update user (users can update their own info, admins can update any)
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    console.log('=== USERS ROUTE: UPDATE USER ===');
    console.log('Updating user ID:', req.params.id);
    console.log('Authenticated user:', req.user);
    console.log('Update data:', req.body);
    
    // Check permissions - users can only update their own info unless admin
    if (req.user.userId != req.params.id && req.user.role !== 'admin') {
      console.log('Permission denied: User trying to update another user\'s data');
      return res.status(403).json({ error: 'Permission denied' });
    }

    // Prevent role changes unless admin
    if (req.body.role && req.user.role !== 'admin') {
      console.log('Permission denied: Non-admin trying to change role');
      return res.status(403).json({ error: 'Permission denied: Only admins can change roles' });
    }

    // Prevent password changes through this endpoint
    if (req.body.password) {
      console.log('Password change attempt through user update endpoint');
      return res.status(400).json({ error: 'Password cannot be changed through this endpoint' });
    }

    const user = await User.update(req.params.id, req.body);
    if (!user) {
      console.log('User not found for update');
      return res.status(404).json({ error: 'User not found' });
    }
    
    console.log('User updated successfully:', user.id);
    
    // Return sanitized user information
    const sanitizedUser = {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      created_at: user.created_at
    };
    
    res.json(sanitizedUser);
  } catch (error) {
    console.error('Error in Users.update:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete user (admin only)
router.delete('/:id', authenticateToken, requireAdmin, async (req, res) => {
  try {
    console.log('=== USERS ROUTE: DELETE USER ===');
    console.log('Deleting user ID:', req.params.id);
    console.log('Authenticated admin:', req.user);
    
    // Prevent users from deleting themselves
    if (req.user.userId == req.params.id) {
      console.log('Admin trying to delete themselves');
      return res.status(400).json({ error: 'Cannot delete your own account' });
    }

    const user = await User.delete(req.params.id);
    if (!user) {
      console.log('User not found for deletion');
      return res.status(404).json({ error: 'User not found' });
    }
    
    console.log('User deleted successfully:', user.id);
    
    res.json({ message: 'User deleted successfully' });
  } catch (error) {
    console.error('Error in Users.delete:', error);
    res.status(500).json({ error: error.message });
  }
});

// ✅ NEW: Admin-only staff user creation
router.post('/staff', authenticateToken, requireAdmin, async (req, res) => {
  try {
    console.log('=== USERS ROUTE: CREATE STAFF USER ===');
    console.log('Creating staff user by admin:', req.user.userId);
    console.log('Staff user data:', req.body);

    const { name, email, password, role } = req.body;
    
    // Validate role for staff creation
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

// ✅ NEW: Get pending requests count (for dashboard alerts)
router.get('/pending/count', authenticateToken, requireAdmin, async (req, res) => {
  try {
    console.log('=== USERS ROUTE: GET PENDING REQUESTS COUNT ===');
    console.log('User making request:', req.user);

    const count = await User.getPendingRequestsCount();
    console.log('Pending requests count:', count);

    res.json({ count });
  } catch (error) {
    console.error('Error in Users.getPendingRequestsCount:', error);
    res.status(500).json({ error: error.message });
  }
});

// ✅ NEW: Get pending requests (for admin/technician review)
router.get('/pending', authenticateToken, requireAdmin, async (req, res) => {
  try {
    console.log('=== USERS ROUTE: GET PENDING REQUESTS ===');
    console.log('User making request:', req.user);

    const pendingRequests = await User.getPendingRequests();
    console.log(`Found ${pendingRequests.length} pending requests`);

    res.json(pendingRequests);
  } catch (error) {
    console.error('Error in Users.getPendingRequests:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;