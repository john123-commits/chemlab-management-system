const db = require('./config/db');
const bcrypt = require('bcryptjs');

async function fixAdminUser() {
  try {
    console.log('=== FIXING ADMIN USER ===');

    // First, get the current admin user
    const currentAdminResult = await db.query(
      'SELECT id, name, email, password FROM users WHERE email = $1',
      ['admin@example.com']
    );

    if (currentAdminResult.rows.length === 0) {
      console.log('❌ No admin user found with email admin@example.com');
      return;
    }

    const currentAdmin = currentAdminResult.rows[0];
    console.log('Current admin user:', {
      id: currentAdmin.id,
      name: currentAdmin.name,
      email: currentAdmin.email,
      currentHash: currentAdmin.password
    });

    // Generate the correct password hash for "password"
    const correctHash = '$2a$10$8K1p/a0dhrxiowP.dnkgNORTWgdEDHn5L2/xjpEWuC.QQv4rKO9jO';
    console.log('Correct hash for "password":', correctHash);

    // Update the user with correct email and password hash
    const updateResult = await db.query(
      'UPDATE users SET email = $1, password = $2 WHERE id = $3 RETURNING *',
      ['admin@university.edu', correctHash, currentAdmin.id]
    );

    if (updateResult.rows.length === 0) {
      console.log('❌ Failed to update admin user');
      return;
    }

    const updatedAdmin = updateResult.rows[0];
    console.log('✅ Admin user updated successfully!');
    console.log('Updated admin user:', {
      id: updatedAdmin.id,
      name: updatedAdmin.name,
      email: updatedAdmin.email,
      role: updatedAdmin.role,
      status: updatedAdmin.status
    });

    // Verify the password works
    const isValidPassword = await bcrypt.compare('password', correctHash);
    console.log('✅ Password verification:', isValidPassword ? 'SUCCESS' : 'FAILED');

    console.log('\n=== LOGIN SHOULD NOW WORK ===');
    console.log('Email: admin@university.edu');
    console.log('Password: password');

  } catch (error) {
    console.error('❌ Error fixing admin user:', error);
  } finally {
    process.exit(0);
  }
}

fixAdminUser();