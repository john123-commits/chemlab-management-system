const bcrypt = require('bcryptjs');

async function generateCorrectHash() {
  try {
    console.log('=== GENERATING CORRECT PASSWORD HASH ===');

    const password = 'password';
    console.log('Generating hash for password:', password);

    // Generate a new hash with the same salt rounds (10) as in the seed file
    const newHash = await bcrypt.hash(password, 10);
    console.log('New hash generated:', newHash);

    // Test that the password matches this new hash
    const isValid = await bcrypt.compare(password, newHash);
    console.log('Password matches new hash:', isValid);

    console.log('\n=== UPDATING DATABASE WITH CORRECT HASH ===');
    const db = require('./config/db');

    // Update the admin user with the correct hash
    const updateResult = await db.query(
      'UPDATE users SET password = $1 WHERE email = $2 RETURNING *',
      [newHash, 'admin@university.edu']
    );

    if (updateResult.rows.length === 0) {
      console.log('❌ No admin user found to update');
      return;
    }

    const updatedUser = updateResult.rows[0];
    console.log('✅ Admin user password updated successfully!');
    console.log('User:', updatedUser.name, '(', updatedUser.email, ')');

    // Final verification
    const finalTest = await bcrypt.compare(password, newHash);
    console.log('✅ Final password verification:', finalTest ? 'SUCCESS' : 'FAILED');

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit(0);
  }
}

generateCorrectHash();