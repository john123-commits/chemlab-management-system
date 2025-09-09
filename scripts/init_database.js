const fs = require('fs');
const path = require('path');
const { Pool } = require('../backend/node_modules/pg');

async function initDatabase() {
  const pool = new Pool({
    user: process.env.DB_USER || 'postgres',
    host: process.env.DB_HOST || 'localhost',
    database: process.env.DB_NAME || 'chemlab_db',
    password: process.env.DB_PASSWORD || 'password',
    port: process.env.DB_PORT || 5432,
  });

  try {
    console.log('Connecting to database...');

    // Read the schema file
    const schemaPath = path.join(__dirname, '..', 'database', 'schema.sql');
    const schemaSQL = fs.readFileSync(schemaPath, 'utf8');

    // Split the schema into individual statements
    const statements = schemaSQL
      .split(';')
      .map(stmt => stmt.trim())
      .filter(stmt => stmt.length > 0 && !stmt.startsWith('--'));

    console.log(`Found ${statements.length} SQL statements to execute...`);

    // Execute each statement
    for (let i = 0; i < statements.length; i++) {
      const statement = statements[i];
      if (statement.trim()) {
        console.log(`Executing statement ${i + 1}/${statements.length}...`);
        try {
          await pool.query(statement);
        } catch (error) {
          // Log the error but continue with other statements
          console.error(`Error executing statement ${i + 1}:`, error.message);
          console.error('Statement:', statement.substring(0, 100) + '...');
        }
      }
    }

    // Check if chat tables exist and ensure they have all required columns
    console.log('Checking for chat tables...');
    const chatTablesExist = await pool.query(`
      SELECT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'chat_conversations'
      )
    `);

    if (!chatTablesExist.rows[0].exists) {
      console.log('Creating chat tables...');

      // Create chat_conversations table
      await pool.query(`
        CREATE TABLE chat_conversations (
          id SERIAL PRIMARY KEY,
          user_id INTEGER REFERENCES users(id),
          admin_id INTEGER REFERENCES users(id),
          conversation_type VARCHAR(20) DEFAULT 'bot' CHECK (conversation_type IN ('bot', 'live', 'support')),
          status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'closed', 'archived')),
          title VARCHAR(200),
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);

      // Create chat_messages table
      await pool.query(`
        CREATE TABLE chat_messages (
          id SERIAL PRIMARY KEY,
          conversation_id INTEGER REFERENCES chat_conversations(id) ON DELETE CASCADE,
          sender_type VARCHAR(20) NOT NULL CHECK (sender_type IN ('user', 'bot', 'admin', 'technician')),
          sender_id INTEGER REFERENCES users(id),
          message_text TEXT NOT NULL,
          message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'file', 'image', 'system')),
          is_read BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);

      console.log('Chat tables created successfully!');
    } else {
      console.log('Chat tables already exist. Checking for missing columns...');

      // Check if conversation_type column exists
      const convTypeExists = await pool.query(`
        SELECT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'chat_conversations' AND column_name = 'conversation_type'
        )
      `);

      if (!convTypeExists.rows[0].exists) {
        console.log('Adding conversation_type column to chat_conversations...');
        await pool.query(`
          ALTER TABLE chat_conversations
          ADD COLUMN conversation_type VARCHAR(20) DEFAULT 'bot' CHECK (conversation_type IN ('bot', 'live', 'support'))
        `);
      }

      // Check if admin_id column exists
      const adminIdExists = await pool.query(`
        SELECT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'chat_conversations' AND column_name = 'admin_id'
        )
      `);

      if (!adminIdExists.rows[0].exists) {
        console.log('Adding admin_id column to chat_conversations...');
        await pool.query(`
          ALTER TABLE chat_conversations
          ADD COLUMN admin_id INTEGER REFERENCES users(id)
        `);
      }

      // Check if sender_id column exists in chat_messages
      const senderIdExists = await pool.query(`
        SELECT EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'chat_messages' AND column_name = 'sender_id'
        )
      `);

      if (!senderIdExists.rows[0].exists) {
        console.log('Adding sender_id column to chat_messages...');
        await pool.query(`
          ALTER TABLE chat_messages
          ADD COLUMN sender_id INTEGER REFERENCES users(id)
        `);
      }

      console.log('Chat tables updated successfully!');
    }

    // Create indexes (these will be skipped if they already exist)
    console.log('Creating indexes...');
    try { await pool.query(`CREATE INDEX idx_chat_conversations_user ON chat_conversations(user_id)`); } catch (e) {}
    try { await pool.query(`CREATE INDEX idx_chat_conversations_admin ON chat_conversations(admin_id)`); } catch (e) {}
    try { await pool.query(`CREATE INDEX idx_chat_conversations_status ON chat_conversations(status)`); } catch (e) {}
    try { await pool.query(`CREATE INDEX idx_chat_messages_conversation ON chat_messages(conversation_id)`); } catch (e) {}
    try { await pool.query(`CREATE INDEX idx_chat_messages_sender ON chat_messages(sender_id)`); } catch (e) {}
    try { await pool.query(`CREATE INDEX idx_chat_messages_created ON chat_messages(created_at)`); } catch (e) {}

    console.log('Database initialization completed successfully!');
  } catch (error) {
    console.error('Database initialization failed:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

// Run the initialization
if (require.main === module) {
  initDatabase();
}

module.exports = { initDatabase };