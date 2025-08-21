-- Insert sample users
INSERT INTO users (name, email, password, role) VALUES
('Admin User', 'admin@university.edu', '$2a$10$8K1p/a0dhrxiowP.dnkgNORTWgdEDHn5L2/xjpEWuC.QQv4rKO9jO', 'admin'),
('Lab Technician', 'tech@university.edu', '$2a$10$8K1p/a0dhrxiowP.dnkgNORTWgdEDHn5L2/xjpEWuC.QQv4rKO9jO', 'technician'),
('Student Borrower', 'student@university.edu', '$2a$10$8K1p/a0dhrxiowP.dnkgNORTWgdEDHn5L2/xjpEWuC.QQv4rKO9jO', 'borrower');

-- Insert sample chemicals
INSERT INTO chemicals (name, category, quantity, unit, storage_location, expiry_date) VALUES
('Hydrochloric Acid', 'Acids', 500.0, 'mL', 'Shelf A1', '2025-12-31'),
('Sodium Chloride', 'Salts', 1000.0, 'g', 'Shelf B2', '2026-06-30'),
('Ethanol', 'Alcohols', 250.0, 'mL', 'Shelf C3', '2024-03-15'),
('Hydrogen Peroxide', 'Oxidizers', 100.0, 'mL', 'Refrigerator R1', '2024-01-30'),
('Acetone', 'Solvents', 500.0, 'mL', 'Flammable Cabinet F1', '2025-09-20');

-- Insert sample equipment
INSERT INTO equipment (name, category, condition, last_maintenance_date, location, maintenance_schedule) VALUES
('pH Meter', 'Analytical', 'Good', '2024-01-15', 'Bench 1', 90),
('Centrifuge', 'Separation', 'Excellent', '2023-12-01', 'Room 202', 180),
('Spectrophotometer', 'Analytical', 'Good', '2024-02-10', 'Bench 3', 120),
('Autoclave', 'Sterilization', 'Fair', '2023-11-20', 'Room 205', 60),
('Fume Hood', 'Safety', 'Excellent', '2024-01-05', 'Bay A', 365);

-- Insert sample borrowing
INSERT INTO borrowings (borrower_id, chemicals, equipment, purpose, research_details, borrow_date, return_date, visit_date, visit_time, status) VALUES
(3, '[{"id": 1, "name": "Hydrochloric Acid", "quantity": 50.0, "unit": "mL"}]', '[{"id": 1, "name": "pH Meter", "quantity": 1}]', 'Acid-base titration experiment', 'General Chemistry Lab', '2024-02-01', '2024-02-08', '2024-02-02', '10:00', 'approved');