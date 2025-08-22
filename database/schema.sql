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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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

-- Create indexes for better performance
CREATE INDEX idx_chemicals_category ON chemicals(category);
CREATE INDEX idx_chemicals_expiry ON chemicals(expiry_date);
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

-- Update existing records to have default values
UPDATE borrowings SET status = 'pending' WHERE status IS NULL;