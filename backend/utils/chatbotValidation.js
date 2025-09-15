// backend/utils/chatbotValidation.js
// Validation utilities for ChemBot

const { getChemicalById, getEquipmentById, getUserById } = require('../services/apiService');

class ValidationError extends Error {
  constructor(message, field = null) {
    super(message);
    this.name = 'ValidationError';
    this.field = field;
  }
}

class DatabaseError extends Error {
  constructor(message, originalError = null) {
    super(message);
    this.name = 'DatabaseError';
    this.originalError = originalError;
  }
}

/**
 * Validates user input for chemical names
 * @param {string} chemicalName - The chemical name to validate
 * @returns {boolean} - True if valid
 * @throws {ValidationError} - If validation fails
 */
function validateChemicalName(chemicalName) {
  if (!chemicalName || typeof chemicalName !== 'string') {
    throw new ValidationError('Chemical name is required and must be a string', 'chemicalName');
  }

  const trimmed = chemicalName.trim();
  if (trimmed.length === 0) {
    throw new ValidationError('Chemical name cannot be empty', 'chemicalName');
  }

  if (trimmed.length > 100) {
    throw new ValidationError('Chemical name is too long (max 100 characters)', 'chemicalName');
  }

  // Check for potentially dangerous characters
  const dangerousChars = /[<>\"'&]/;
  if (dangerousChars.test(trimmed)) {
    throw new ValidationError('Chemical name contains invalid characters', 'chemicalName');
  }

  return true;
}

/**
 * Validates user input for equipment names
 * @param {string} equipmentName - The equipment name to validate
 * @returns {boolean} - True if valid
 * @throws {ValidationError} - If validation fails
 */
function validateEquipmentName(equipmentName) {
  if (!equipmentName || typeof equipmentName !== 'string') {
    throw new ValidationError('Equipment name is required and must be a string', 'equipmentName');
  }

  const trimmed = equipmentName.trim();
  if (trimmed.length === 0) {
    throw new ValidationError('Equipment name cannot be empty', 'equipmentName');
  }

  if (trimmed.length > 100) {
    throw new ValidationError('Equipment name is too long (max 100 characters)', 'equipmentName');
  }

  // Check for potentially dangerous characters
  const dangerousChars = /[<>\"'&]/;
  if (dangerousChars.test(trimmed)) {
    throw new ValidationError('Equipment name contains invalid characters', 'equipmentName');
  }

  return true;
}

/**
 * Validates quantity values
 * @param {number|string} quantity - The quantity to validate
 * @param {string} unit - The unit of measurement
 * @returns {boolean} - True if valid
 * @throws {ValidationError} - If validation fails
 */
function validateQuantity(quantity, unit = null) {
  if (quantity === null || quantity === undefined || quantity === '') {
    throw new ValidationError('Quantity is required', 'quantity');
  }

  const numQuantity = typeof quantity === 'string' ? parseFloat(quantity) : quantity;

  if (isNaN(numQuantity)) {
    throw new ValidationError('Quantity must be a valid number', 'quantity');
  }

  if (numQuantity < 0) {
    throw new ValidationError('Quantity cannot be negative', 'quantity');
  }

  if (numQuantity > 999999.99) {
    throw new ValidationError('Quantity is too large (max 999,999.99)', 'quantity');
  }

  if (unit && typeof unit !== 'string') {
    throw new ValidationError('Unit must be a string', 'unit');
  }

  return true;
}

/**
 * Validates date inputs
 * @param {string|Date} date - The date to validate
 * @param {string} fieldName - Name of the field for error messages
 * @returns {boolean} - True if valid
 * @throws {ValidationError} - If validation fails
 */
function validateDate(date, fieldName = 'date') {
  if (!date) {
    throw new ValidationError(`${fieldName} is required`, fieldName);
  }

  let dateObj;
  if (date instanceof Date) {
    dateObj = date;
  } else if (typeof date === 'string') {
    dateObj = new Date(date);
  } else {
    throw new ValidationError(`${fieldName} must be a valid date`, fieldName);
  }

  if (isNaN(dateObj.getTime())) {
    throw new ValidationError(`${fieldName} is not a valid date`, fieldName);
  }

  // Check if date is not too far in the future (100 years)
  const maxDate = new Date();
  maxDate.setFullYear(maxDate.getFullYear() + 100);

  if (dateObj > maxDate) {
    throw new ValidationError(`${fieldName} cannot be more than 100 years in the future`, fieldName);
  }

  return true;
}

/**
 * Validates user ID
 * @param {number|string} userId - The user ID to validate
 * @returns {boolean} - True if valid
 * @throws {ValidationError} - If validation fails
 */
async function validateUserId(userId) {
  if (!userId) {
    throw new ValidationError('User ID is required', 'userId');
  }

  const numUserId = typeof userId === 'string' ? parseInt(userId, 10) : userId;

  if (isNaN(numUserId) || numUserId <= 0) {
    throw new ValidationError('User ID must be a positive integer', 'userId');
  }

  // Check if user exists in database
  try {
    const user = await getUserById(numUserId);
    if (!user) {
      throw new ValidationError('User not found', 'userId');
    }
  } catch (error) {
    if (error instanceof ValidationError) {
      throw error;
    }
    throw new DatabaseError('Failed to validate user ID', error);
  }

  return true;
}

/**
 * Validates chemical ID exists in database
 * @param {number|string} chemicalId - The chemical ID to validate
 * @returns {boolean} - True if valid
 * @throws {ValidationError|DatabaseError} - If validation fails
 */
async function validateChemicalId(chemicalId) {
  if (!chemicalId) {
    throw new ValidationError('Chemical ID is required', 'chemicalId');
  }

  const numChemicalId = typeof chemicalId === 'string' ? parseInt(chemicalId, 10) : chemicalId;

  if (isNaN(numChemicalId) || numChemicalId <= 0) {
    throw new ValidationError('Chemical ID must be a positive integer', 'chemicalId');
  }

  // Check if chemical exists in database
  try {
    const chemical = await getChemicalById(numChemicalId);
    if (!chemical) {
      throw new ValidationError('Chemical not found', 'chemicalId');
    }
  } catch (error) {
    if (error instanceof ValidationError) {
      throw error;
    }
    throw new DatabaseError('Failed to validate chemical ID', error);
  }

  return true;
}

/**
 * Validates equipment ID exists in database
 * @param {number|string} equipmentId - The equipment ID to validate
 * @returns {boolean} - True if valid
 * @throws {ValidationError|DatabaseError} - If validation fails
 */
async function validateEquipmentId(equipmentId) {
  if (!equipmentId) {
    throw new ValidationError('Equipment ID is required', 'equipmentId');
  }

  const numEquipmentId = typeof equipmentId === 'string' ? parseInt(equipmentId, 10) : equipmentId;

  if (isNaN(numEquipmentId) || numEquipmentId <= 0) {
    throw new ValidationError('Equipment ID must be a positive integer', 'equipmentId');
  }

  // Check if equipment exists in database
  try {
    const equipment = await getEquipmentById(numEquipmentId);
    if (!equipment) {
      throw new ValidationError('Equipment not found', 'equipmentId');
    }
  } catch (error) {
    if (error instanceof ValidationError) {
      throw error;
    }
    throw new DatabaseError('Failed to validate equipment ID', error);
  }

  return true;
}

/**
 * Validates message length and content
 * @param {string} message - The message to validate
 * @returns {boolean} - True if valid
 * @throws {ValidationError} - If validation fails
 */
function validateMessage(message) {
  if (!message || typeof message !== 'string') {
    console.warn('[VALIDATION] Invalid message type or missing:', { type: typeof message, value: message });
    throw new ValidationError('Message is required and must be a string', 'message');
  }

  const trimmed = message.trim();
  if (trimmed.length === 0) {
    console.warn('[VALIDATION] Empty message received');
    throw new ValidationError('Message cannot be empty', 'message');
  }

  if (trimmed.length > 1000) {
    console.warn('[VALIDATION] Message too long:', { length: trimmed.length });
    throw new ValidationError('Message is too long (max 1000 characters)', 'message');
  }

  return true;
}

/**
 * Validates user role
 * @param {string} role - The user role to validate
 * @returns {boolean} - True if valid
 * @throws {ValidationError} - If validation fails
 */
function validateUserRole(role) {
  const validRoles = ['admin', 'technician', 'borrower'];

  if (!role || typeof role !== 'string') {
    throw new ValidationError('User role is required and must be a string', 'role');
  }

  if (!validRoles.includes(role.toLowerCase())) {
    throw new ValidationError(`Invalid user role. Must be one of: ${validRoles.join(', ')}`, 'role');
  }

  return true;
}

/**
 * Sanitizes user input to prevent injection attacks
 * @param {string} input - The input to sanitize
 * @returns {string} - Sanitized input
 */
function sanitizeInput(input) {
  if (typeof input !== 'string') {
    return input;
  }

  const original = input;
  const sanitized = input
    .replace(/</g, '<')
    .replace(/>/g, '>')
    .replace(/"/g, '"')
    .replace(/'/g, '&#x27;')
    .replace(/\//g, '&#x2F;');

  // Log if sanitization changed the input (potential security issue)
  if (original !== sanitized) {
    console.warn('[SECURITY] Input sanitization modified content:', {
      originalLength: original.length,
      sanitizedLength: sanitized.length,
      changes: original !== sanitized
    });
  }

  return sanitized;
}

/**
 * Creates a standardized error response
 * @param {Error} error - The error that occurred
 * @param {string} defaultMessage - Default message if error details are not available
 * @returns {string} - Formatted error response
 */
function createErrorResponse(error, defaultMessage = 'An error occurred while processing your request') {
  console.error('ChatBot Error:', error);

  if (error instanceof ValidationError) {
    return `❌ **Validation Error:** ${error.message}`;
  }

  if (error instanceof DatabaseError) {
    return `🔄 **Database Error:** ${error.message}. Please try again later.`;
  }

  return `❌ **Error:** ${defaultMessage}`;
}

module.exports = {
  ValidationError,
  DatabaseError,
  validateChemicalName,
  validateEquipmentName,
  validateQuantity,
  validateDate,
  validateUserId,
  validateChemicalId,
  validateEquipmentId,
  validateMessage,
  validateUserRole,
  sanitizeInput,
  createErrorResponse
};