const bcrypt = require('bcryptjs');

// The exact hash from your database
const storedHash = '$2a$10$rPmYwteGyh5lGS/EtIJSYuP7I/Or3Y4sSXaAr3CRueZ4Oj./Q1Nre';
const testPassword = 'password123';

console.log('Testing stored hash:', storedHash);
console.log('Testing password:', JSON.stringify(testPassword));

// Test 1: Direct comparison
bcrypt.compare(testPassword, storedHash).then(result => {
  console.log('Stored hash test result:', result);
  
  // Test 2: Try to recreate the exact same hash
  // Extract salt correctly (first 29 characters)
  const saltPart = storedHash.substring(0, 29); // $2a$10$rPmYwteGyh5lGS/EtIJSY
  console.log('Extracted salt (29 chars):', saltPart);
  console.log('Salt length:', saltPart.length);
  
  // Hash with the same salt
  bcrypt.hash(testPassword, saltPart).then(recreatedHash => {
    console.log('Recreated hash:', recreatedHash);
    console.log('Original hash: ', storedHash);
    console.log('Matches original:', recreatedHash === storedHash);
    
    // Test recreated hash
    bcrypt.compare(testPassword, recreatedHash).then(recreatedResult => {
      console.log('Recreated hash test result:', recreatedResult);
    });
  });
  
  // Test 3: With a new hash
  bcrypt.hash(testPassword, 10).then(newHash => {
    console.log('New hash:', newHash);
    bcrypt.compare(testPassword, newHash).then(newResult => {
      console.log('New hash test result:', newResult);
    });
  });
});