# ChemLab Management System API Documentation

## Base URL
`http://localhost:5000/api`

## Authentication

### POST /auth/login
Login to the system

**Request:**
```json
{
  "email": "user@example.com",
  "password": "password123"
}