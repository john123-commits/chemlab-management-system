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