-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role VARCHAR(20) DEFAULT 'borrower' CHECK (role IN ('admin', 'technician', 'borrower')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Chemicals table
CREATE TABLE chemicals (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    quantity DECIMAL(10,2) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    storage_location VARCHAR(100) NOT NULL,
    expiry_date DATE NOT NULL,
    safety_data_sheet TEXT,

    -- Enhanced chemical properties for chatbot
    c_number VARCHAR(20), -- CAS Number
    molecular_formula VARCHAR(100),
    molecular_weight DECIMAL(10,3),
    physical_state VARCHAR(20) CHECK (physical_state IN ('solid', 'liquid', 'gas')),
    color VARCHAR(50),
    density DECIMAL(10,3),
    melting_point DECIMAL(8,2),
    boiling_point DECIMAL(8,2),
    solubility VARCHAR(200),

    -- Safety information
    storage_conditions TEXT,
    hazard_class VARCHAR(100),
    safety_precautions TEXT,
    safety_info TEXT,
    msds_link VARCHAR(500),

    -- Stock tracking fields
    initial_quantity DECIMAL(10,2) DEFAULT 0,
    reorder_level DECIMAL(10,2) DEFAULT 10,
    supplier VARCHAR(100),
    purchase_date DATE,
    cost_per_unit DECIMAL(10,2),

    -- Usage tracking fields
    last_used_date TIMESTAMP,
    total_used DECIMAL(10,2) DEFAULT 0,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Equipment table
CREATE TABLE equipment (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    condition VARCHAR(50) NOT NULL,
    last_maintenance_date DATE NOT NULL,
    location VARCHAR(100) NOT NULL,
    maintenance_schedule INTEGER NOT NULL,

    -- Enhanced equipment details for chatbot
    serial_number VARCHAR(100),
    manufacturer VARCHAR(100),
    model VARCHAR(100),
    purchase_date DATE,
    warranty_expiry DATE,
    calibration_date DATE,
    next_calibration_date DATE,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Borrowings table
CREATE TABLE borrowings (
    id SERIAL PRIMARY KEY,
    borrower_id INTEGER REFERENCES users(id),
    technician_id INTEGER REFERENCES users(id),
    admin_id INTEGER REFERENCES users(id),
    chemicals JSONB,
    equipment JSONB,
    purpose TEXT NOT NULL,
    research_details TEXT,
    borrow_date DATE NOT NULL,
    return_date DATE NOT NULL,
    visit_date DATE NOT NULL,
    visit_time VARCHAR(10) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'returned')),
    notes TEXT,
    rejection_reason TEXT,
    technician_approved_at TIMESTAMP,
    admin_approved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Lecture Schedules table
CREATE TABLE lecture_schedules (
    id SERIAL PRIMARY KEY,
    admin_id INTEGER REFERENCES users(id),
    technician_id INTEGER REFERENCES users(id),
    title VARCHAR(200) NOT NULL,
    description TEXT,
    required_chemicals JSONB,
    required_equipment JSONB,
    scheduled_date DATE NOT NULL,
    scheduled_time VARCHAR(10) NOT NULL,
    duration INTEGER,
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'in_progress', 'completed', 'cancelled')),
    technician_notes TEXT,
    confirmation_date TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Chemical Usage Logs table for tracking chemical consumption
CREATE TABLE chemical_usage_logs (
   id SERIAL PRIMARY KEY,
   chemical_id INTEGER NOT NULL REFERENCES chemicals(id) ON DELETE CASCADE,
   user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
   quantity_used DECIMAL(10,2) NOT NULL,
   remaining_quantity DECIMAL(10,2) NOT NULL,
   usage_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
   purpose VARCHAR(255),
   notes TEXT,
   experiment_reference VARCHAR(100),
   created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
   updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX idx_chemicals_category ON chemicals(category);
CREATE INDEX idx_chemicals_expiry ON chemicals(expiry_date);
CREATE INDEX idx_chemical_usage_chemical_id ON chemical_usage_logs(chemical_id);
CREATE INDEX idx_chemical_usage_user_id ON chemical_usage_logs(user_id);
CREATE INDEX idx_chemical_usage_date ON chemical_usage_logs(usage_date);
CREATE INDEX idx_equipment_category ON equipment(category);
CREATE INDEX idx_equipment_maintenance ON equipment(last_maintenance_date);
CREATE INDEX idx_borrowings_status ON borrowings(status);
CREATE INDEX idx_borrowings_borrower ON borrowings(borrower_id);
CREATE INDEX idx_borrowings_dates ON borrowings(borrow_date, return_date);
CREATE INDEX idx_borrowings_technician ON borrowings(technician_id);
CREATE INDEX idx_borrowings_admin ON borrowings(admin_id);
CREATE INDEX idx_borrowings_pending ON borrowings(status) WHERE status = 'pending';
CREATE INDEX idx_borrowings_overdue ON borrowings(status, return_date) 
WHERE status = 'approved' AND return_date < CURRENT_DATE;
CREATE INDEX idx_lecture_schedules_admin ON lecture_schedules(admin_id);
CREATE INDEX idx_lecture_schedules_technician ON lecture_schedules(technician_id);
CREATE INDEX idx_lecture_schedules_date ON lecture_schedules(scheduled_date);
CREATE INDEX idx_lecture_schedules_status ON lecture_schedules(status);

-- Create a function to automatically update the updated_at field
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for automatic timestamp updates
CREATE TRIGGER update_borrowings_updated_at 
    BEFORE UPDATE ON borrowings 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_lecture_schedules_updated_at
    BEFORE UPDATE ON lecture_schedules
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create trigger to update chemicals table when usage is logged
CREATE OR REPLACE FUNCTION update_chemical_after_usage()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE chemicals
    SET
        quantity = NEW.remaining_quantity,
        last_used_date = NEW.usage_date,
        total_used = COALESCE(total_used, 0) + NEW.quantity_used,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.chemical_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_chemical_after_usage
    AFTER INSERT ON chemical_usage_logs
    FOR EACH ROW
    EXECUTE FUNCTION update_chemical_after_usage();

-- Create trigger for chemical_usage_logs updated_at
CREATE TRIGGER update_chemical_usage_logs_updated_at
    BEFORE UPDATE ON chemical_usage_logs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Chat conversations and messages tables for live chat feature
CREATE TABLE chat_conversations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    admin_id INTEGER REFERENCES users(id),
    conversation_type VARCHAR(20) DEFAULT 'bot' CHECK (conversation_type IN ('bot', 'live', 'support')),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'closed', 'archived')),
    title VARCHAR(200),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE TABLE chat_messages (
    id SERIAL PRIMARY KEY,
    conversation_id INTEGER REFERENCES chat_conversations(id) ON DELETE CASCADE,
    sender_type VARCHAR(20) NOT NULL CHECK (sender_type IN ('user', 'bot', 'admin', 'technician')),
    sender_id INTEGER REFERENCES users(id),
    message_text TEXT NOT NULL,
    message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'file', 'image', 'system')),
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Chat quick actions table
CREATE TABLE chat_quick_actions (
    id SERIAL PRIMARY KEY,
    action_name VARCHAR(50) NOT NULL,
    display_text VARCHAR(100) NOT NULL,
    icon VARCHAR(50) NOT NULL,
    role_required VARCHAR(20) DEFAULT 'borrower' CHECK (role_required IN ('admin', 'technician', 'borrower')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for chat tables
CREATE INDEX idx_chat_conversations_user ON chat_conversations(user_id);
CREATE INDEX idx_chat_conversations_admin ON chat_conversations(admin_id);
CREATE INDEX idx_chat_conversations_status ON chat_conversations(status);
CREATE INDEX idx_chat_messages_conversation ON chat_messages(conversation_id);
CREATE INDEX idx_chat_messages_sender ON chat_messages(sender_id);
CREATE INDEX idx_chat_messages_created ON chat_messages(created_at);
CREATE INDEX idx_chat_quick_actions_role ON chat_quick_actions(role_required, is_active);

-- Chat conversation context table for enhanced conversational intelligence
CREATE TABLE chat_context (
    id SERIAL PRIMARY KEY,
    conversation_id INTEGER REFERENCES chat_conversations(id) ON DELETE CASCADE,
    context_key VARCHAR(100) NOT NULL,
    context_value TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(conversation_id, context_key)
);

-- Create indexes for chat context
CREATE INDEX idx_chat_context_conversation ON chat_context(conversation_id);
CREATE INDEX idx_chat_context_key ON chat_context(context_key);

-- Create trigger for chat context updated_at
CREATE TRIGGER update_chat_context_updated_at
    BEFORE UPDATE ON chat_context
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for chat conversations updated_at
CREATE TRIGGER update_chat_conversations_updated_at
    BEFORE UPDATE ON chat_conversations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Chatbot audit log table for tracking queries and responses
CREATE TABLE chatbot_audit_log (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    query_text TEXT NOT NULL,
    response_text TEXT NOT NULL,
    query_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for chatbot audit log
CREATE INDEX idx_chatbot_audit_user ON chatbot_audit_log(user_id);
CREATE INDEX idx_chatbot_audit_type ON chatbot_audit_log(query_type);
CREATE INDEX idx_chatbot_audit_created ON chatbot_audit_log(created_at);

-- Update existing records to have default values
UPDATE borrowings SET status = 'pending' WHERE status IS NULL;

-- Update existing chemicals records with initial_quantity = current quantity
UPDATE chemicals SET initial_quantity = quantity WHERE initial_quantity = 0;