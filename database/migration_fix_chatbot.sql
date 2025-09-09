-- Migration to fix chatbot database issues
-- Run this after the main schema.sql if tables exist but are incomplete

-- Create chat_context table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_name = 'chat_context') THEN
        CREATE TABLE chat_context (
            id SERIAL PRIMARY KEY,
            conversation_id INTEGER REFERENCES chat_conversations(id) ON DELETE CASCADE,
            context_key VARCHAR(100) NOT NULL,
            context_value TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
            UNIQUE(conversation_id, context_key)
        );
        
        -- Create indexes
        CREATE INDEX idx_chat_context_conversation ON chat_context(conversation_id);
        CREATE INDEX idx_chat_context_key ON chat_context(context_key);
        
        -- Create trigger for automatic updates
        CREATE TRIGGER update_chat_context_updated_at
            BEFORE UPDATE ON chat_context
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Add updated_at column to chat_conversations if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'chat_conversations' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE chat_conversations
        ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL;
        
        -- Create trigger for automatic updates
        CREATE TRIGGER update_chat_conversations_updated_at
            BEFORE UPDATE ON chat_conversations
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Create chatbot_audit_log table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_name = 'chatbot_audit_log') THEN
        CREATE TABLE chatbot_audit_log (
            id SERIAL PRIMARY KEY,
            user_id INTEGER REFERENCES users(id),
            query_text TEXT NOT NULL,
            response_text TEXT NOT NULL,
            query_type VARCHAR(50) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
        
        -- Create indexes
        CREATE INDEX idx_chatbot_audit_user ON chatbot_audit_log(user_id);
        CREATE INDEX idx_chatbot_audit_type ON chatbot_audit_log(query_type);
        CREATE INDEX idx_chatbot_audit_created ON chatbot_audit_log(created_at);
    END IF;
END $$;

-- Ensure the update_updated_at_column function exists
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Add updated_at column to other tables that might be missing it (borrowings, lecture_schedules)
DO $$
BEGIN
    -- Check and add to borrowings
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'borrowings' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE borrowings
        ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL;
        
        CREATE TRIGGER update_borrowings_updated_at
            BEFORE UPDATE ON borrowings
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
    
    -- Check and add to lecture_schedules
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'lecture_schedules' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE lecture_schedules
        ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL;
        
        CREATE TRIGGER update_lecture_schedules_updated_at
            BEFORE UPDATE ON lecture_schedules
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Verify the changes
SELECT 'Migration completed successfully' as status;