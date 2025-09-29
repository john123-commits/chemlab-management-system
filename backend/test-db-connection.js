const db = require('./config/db');

async function testDatabaseConnection() {
  try {
    console.log('=== DATABASE CONNECTION TEST ===');
    console.log('Testing database connection...');

    // Test basic connection
    const result = await db.query('SELECT NOW() as current_time');
    console.log('✅ Database connection successful');
    console.log('Current database time:', result.rows[0].current_time);

    // Check if users table exists
    console.log('\n=== CHECKING TABLES ===');
    const tablesResult = await db.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE'
    `);

    const tableNames = tablesResult.rows.map(row => row.table_name);
    console.log('Available tables:', tableNames);

    if (!tableNames.includes('users')) {
      console.log('❌ Users table does not exist');
      return;
    }

    console.log('✅ Users table exists');

    // Check if admin user exists
    console.log('\n=== CHECKING FOR ADMIN USER ===');
    const adminResult = await db.query(
      'SELECT id, name, email, role, status, password FROM users WHERE email = $1',
      ['admin@university.edu']
    );

    if (adminResult.rows.length === 0) {
      console.log('❌ Admin user NOT FOUND');
      console.log('Expected admin user: admin@university.edu');

      // Check all users in database
      const allUsersResult = await db.query('SELECT id, name, email, role FROM users');
      console.log('All users in database:', allUsersResult.rows.length);
      if (allUsersResult.rows.length > 0) {
        console.log('Existing users:');
        allUsersResult.rows.forEach(user => {
          console.log(`  - ${user.name} (${user.email}) - Role: ${user.role}`);
        });

        // Check the existing admin user
        const existingAdminResult = await db.query(
          'SELECT id, name, email, role, status, password FROM users WHERE email = $1',
          ['admin@example.com']
        );

        if (existingAdminResult.rows.length > 0) {
          const existingAdmin = existingAdminResult.rows[0];
          console.log('\n=== EXISTING ADMIN USER FOUND ===');
          console.log('This admin user exists but with different email:');
          console.log('Email:', existingAdmin.email);
          console.log('Name:', existingAdmin.name);
          console.log('Role:', existingAdmin.role);
          console.log('Status:', existingAdmin.status);
          console.log('Stored password hash:', existingAdmin.password);
          console.log('Expected hash for "password": $2a$10$8K1p/a0dhrxiowP.dnkgNORTWgdEDHn5L2/xjpEWuC.QQv4rKO9jO');
          console.log('Hash matches expected:', existingAdmin.password === '$2a$10$8K1p/a0dhrxiowP.dnkgNORTWgdEDHn5L2/xjpEWuC.QQv4rKO9jO');
        }
      } else {
        console.log('Database is empty - no users found');
      }
    } else {
      const admin = adminResult.rows[0];
      console.log('✅ Admin user FOUND');
      console.log('Admin details:', {
        id: admin.id,
        name: admin.name,
        email: admin.email,
        role: admin.role,
        status: admin.status
      });

      // Check password hash
      console.log('\n=== CHECKING PASSWORD HASH ===');
      console.log('Stored password hash:', admin.password);

      // Test if password actually works
      const bcrypt = require('bcryptjs');
      const isValidPassword = await bcrypt.compare('password', admin.password);
      console.log('✅ Password "password" works with stored hash:', isValidPassword);
    }

  } catch (error) {
    console.error('❌ Database connection failed:', error.message);
    console.error('Error details:', error);
  } finally {
    process.exit(0);
  }
}

testDatabaseConnection();