// generate-hash.js
const bcrypt = require('bcryptjs');

const password = 'password';
const saltRounds = 10;

bcrypt.hash(password, saltRounds, (err, hash) => {
  if (err) {
    console.log('Error:', err);
  } else {
    console.log('Generated hash for "password":');
    console.log(hash);
  }
});