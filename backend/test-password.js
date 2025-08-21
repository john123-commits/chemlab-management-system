// test-password.js
const bcrypt = require('bcryptjs');

const storedHash = '$2a$10$oLwROVhOVAZvRD6tR9xy0eWwuOPsB.1omSwasaQ0VIE.9lbdwK96C';
const testPassword = 'password';

console.log('Testing password verification...');
console.log('Stored hash:', storedHash);
console.log('Test password:', testPassword);

bcrypt.compare(testPassword, storedHash, (err, result) => {
  if (err) {
    console.log('Error:', err);
  } else {
    console.log('Password match result:', result);
    if (result) {
      console.log('✅ Password matches!');
    } else {
      console.log('❌ Password does NOT match!');
    }
  }
});