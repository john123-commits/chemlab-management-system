// backend/tests/chatbot.test.js
// Testing framework for ChemBot functionality

const { processChatMessage } = require('../services/chatbotService');
const { ValidationError, DatabaseError } = require('../utils/chatbotValidation');

// Mock database functions to avoid actual database calls during testing
jest.mock('../services/apiService', () => ({
  getOrCreateConversation: jest.fn(),
  getConversationContext: jest.fn(),
  setConversationContext: jest.fn(),
  clearConversationContext: jest.fn(),
  logChatbotQuery: jest.fn(),
  getChemicals: jest.fn(),
  getEquipment: jest.fn(),
  searchChemicals: jest.fn(),
  searchEquipment: jest.fn(),
  findChemicalFlexible: jest.fn(),
  findEquipmentFlexible: jest.fn(),
  getLowStockChemicals: jest.fn(),
  getExpiringChemicals: jest.fn(),
  getExpiredChemicals: jest.fn(),
  getAvailableEquipment: jest.fn(),
  getEquipmentDueForMaintenance: jest.fn(),
  getEquipmentNeedingCalibration: jest.fn(),
  checkEquipmentAvailability: jest.fn(),
  getEquipmentBookings: jest.fn()
}));

const {
  getOrCreateConversation,
  getConversationContext,
  setConversationContext,
  logChatbotQuery,
  getChemicals,
  searchChemicals,
  findChemicalFlexible,
  getLowStockChemicals,
  getExpiringChemicals
} = require('../services/apiService');

describe('ChemBot Core Functionality', () => {
  beforeEach(() => {
    // Reset all mocks before each test
    jest.clearAllMocks();

    // Set up default mock returns
    getOrCreateConversation.mockResolvedValue({ id: 1 });
    getConversationContext.mockResolvedValue({});
    setConversationContext.mockResolvedValue();
    logChatbotQuery.mockResolvedValue();
  });

  describe('Basic Message Processing', () => {
    test('should handle empty message', async () => {
      await expect(processChatMessage('', 1, 'borrower')).rejects.toThrow(ValidationError);
    });

    test('should handle null message', async () => {
      await expect(processChatMessage(null, 1, 'borrower')).rejects.toThrow(ValidationError);
    });

    test('should handle message too long', async () => {
      const longMessage = 'a'.repeat(1001);
      await expect(processChatMessage(longMessage, 1, 'borrower')).rejects.toThrow(ValidationError);
    });

    test('should handle invalid user ID', async () => {
      await expect(processChatMessage('hello', 'invalid', 'borrower')).rejects.toThrow(ValidationError);
    });

    test('should handle invalid user role', async () => {
      await expect(processChatMessage('hello', 1, 'invalid')).rejects.toThrow(ValidationError);
    });
  });

  describe('Help Queries', () => {
    test('should return improved help response for "help"', async () => {
      getChemicals.mockResolvedValue([{ name: 'Test Chemical' }]);
      getEquipment.mockResolvedValue([{ name: 'Test Equipment', status: 'available' }]);
      getLectureSchedules.mockResolvedValue([{ date: new Date().toISOString().split('T')[0] }]);
      getBorrowings.mockResolvedValue([]);
  
      const response = await processChatMessage('help', 1, 'borrower');
      expect(response).toContain('ChemBot Help: Your Lab Assistant!');
      expect(response).toContain('Lab Inventory');
      expect(response).toContain('Test Chemical');
      expect(response).toContain('Available items');
      expect(response).toContain('Examples');
      expect(response).toMatch(/Search chemicals \(\d+ available\)/);
    });
  
    test('should return help response for "what can you do"', async () => {
      const response = await processChatMessage('what can you do', 1, 'borrower');
      expect(response).toContain('ChemBot Help: Your Lab Assistant!');
      expect(response).toContain('What I Can Do');
    });
  });

  describe('Chemical Queries', () => {
    test('should handle chemical details query', async () => {
      findChemicalFlexible.mockResolvedValue({
        id: 1,
        name: 'Sodium Chloride',
        category: 'Salt',
        quantity: 100,
        unit: 'g',
        storage_location: 'Cabinet A',
        expiry_date: '2024-12-31'
      });

      const response = await processChatMessage('What are the details of sodium chloride?', 1, 'borrower');
      expect(response).toContain('Sodium Chloride');
      expect(response).toContain('Salt');
      expect(response).toContain('100 g');
    });

    test('should handle chemical not found', async () => {
      findChemicalFlexible.mockResolvedValue(null);
      searchChemicals.mockResolvedValue([]);

      const response = await processChatMessage('What are the details of nonexistent chemical?', 1, 'borrower');
      expect(response).toContain('couldn\'t find details');
    });

    test('should handle empty chemical inventory with improved default response', async () => {
      getChemicals.mockResolvedValue([]);
      getEquipment.mockResolvedValue([{ name: 'Test Equipment' }]);
      getLectureSchedules.mockResolvedValue([]);
      getBorrowings.mockResolvedValue([]);
  
      const response = await processChatMessage('What chemicals are available?', 1, 'borrower');
      expect(response).toContain('ChemBot: Your Lab Assistant!');
      expect(response).toContain('Request restock');
      expect(response).not.toContain('ChemBot at your service');
    });
  });

  describe('Equipment Queries', () => {
    test('should handle equipment details query', async () => {
      findEquipmentFlexible.mockResolvedValue({
        id: 1,
        name: 'Microscope',
        category: 'Optical Equipment',
        condition: 'Good',
        location: 'Lab 1',
        maintenance_schedule: 30,
        last_maintenance_date: '2024-01-01'
      });

      const response = await processChatMessage('What are the details of microscope?', 1, 'borrower');
      expect(response).toContain('Microscope');
      expect(response).toContain('Optical Equipment');
      expect(response).toContain('Good');
    });

    test('should handle empty equipment inventory with improved default response', async () => {
      getChemicals.mockResolvedValue([{ name: 'Test Chemical' }]);
      getEquipment.mockResolvedValue([]);
      getLectureSchedules.mockResolvedValue([]);
      getBorrowings.mockResolvedValue([]);
  
      const response = await processChatMessage('What equipment is available?', 1, 'borrower');
      expect(response).toContain('ChemBot: Your Lab Assistant!');
      expect(response).toContain('Request new equipment');
      expect(response).not.toContain('No equipment is currently available');
    });
  });

  describe('Inventory Alerts', () => {
    test('should handle low stock query', async () => {
      getLowStockChemicals.mockResolvedValue([
        { id: 1, name: 'Chemical A', quantity: 5, unit: 'g' },
        { id: 2, name: 'Chemical B', quantity: 3, unit: 'mL' }
      ]);

      const response = await processChatMessage('What chemicals are running low?', 1, 'borrower');
      expect(response).toContain('Low Stock Chemicals');
      expect(response).toContain('Chemical A');
      expect(response).toContain('Chemical B');
    });

    test('should handle expiring chemicals query', async () => {
      getExpiringChemicals.mockResolvedValue([
        { id: 1, name: 'Chemical A', expiry_date: '2024-02-15' }
      ]);

      const response = await processChatMessage('What chemicals are expiring?', 1, 'borrower');
      expect(response).toContain('Expiring Soon');
      expect(response).toContain('Chemical A');
    });
  });

  describe('Safety Queries', () => {
    test('should handle acid safety query', async () => {
      const response = await processChatMessage('Safety precautions for acids', 1, 'borrower');
      expect(response).toContain('Acid Handling Safety');
      expect(response).toContain('wear safety goggles');
    });

    test('should handle PPE query', async () => {
      const response = await processChatMessage('What PPE should I wear?', 1, 'borrower');
      expect(response).toContain('Required PPE');
      expect(response).toContain('safety goggles');
    });
  });

  describe('Equipment Booking', () => {
    test('should handle equipment booking request', async () => {
      findEquipmentFlexible.mockResolvedValue({
        id: 1,
        name: 'Centrifuge',
        location: 'Lab 2',
        condition: 'Excellent',
        last_maintenance_date: '2024-01-01'
      });

      const response = await processChatMessage('Book the centrifuge for tomorrow', 1, 'borrower');
      expect(response).toContain('Centrifuge');
      expect(response).toContain('available for booking');
    });
  });

  describe('Purchase Requests', () => {
    test('should handle purchase request', async () => {
      findChemicalFlexible.mockResolvedValue(null);
      findEquipmentFlexible.mockResolvedValue(null);

      const response = await processChatMessage('Request purchase of methanol', 1, 'borrower');
      expect(response).toContain('Purchase Request Created');
      expect(response).toContain('methanol');
    });
  });

  describe('Protocol Suggestions', () => {
    test('should handle titration protocol query', async () => {
      getAvailableEquipment.mockResolvedValue([
        { id: 1, name: 'Burette', category: 'Glassware' },
        { id: 2, name: 'Pipette', category: 'Glassware' }
      ]);

      const response = await processChatMessage('Suggest protocol for titration', 1, 'borrower');
      expect(response).toContain('Titration Protocol');
      expect(response).toContain('Acid-base titration');
    });
  });

  describe('Error Handling', () => {
    test('should handle database errors with improved error response', async () => {
      getChemicals.mockRejectedValue(new DatabaseError('Database connection failed'));
  
      const response = await processChatMessage('Show me available chemicals', 1, 'borrower');
      expect(response).toContain('System Busy');
      expect(response).toContain('try again in a moment');
      expect(response).toContain('lab database');
    });
  
    test('should handle validation errors with user-friendly messages', async () => {
      const longMessage = 'a'.repeat(1001);
      const response = await processChatMessage(longMessage, 1, 'borrower');
      expect(response).toContain('Message Too Long');
      expect(response).toContain('under 1000 characters');
  
      // Test invalid input
      const response2 = await processChatMessage('', 1, 'borrower');
      expect(response2).toContain('Missing Info');
      expect(response2).toContain('more details');
    });
  });

  describe('Context Management', () => {
    test('should maintain conversation context', async () => {
      // Set up context
      getConversationContext.mockResolvedValue({
        last_chemical: 'Sodium Chloride',
        last_topic: 'chemical_details'
      });

      const response = await processChatMessage('Tell me about its safety', 1, 'borrower');
      expect(setConversationContext).toHaveBeenCalled();
      expect(logChatbotQuery).toHaveBeenCalled();
    });

    test('should handle follow-up questions', async () => {
      getConversationContext.mockResolvedValue({
        last_chemical: 'Hydrochloric Acid'
      });

      findChemicalFlexible.mockResolvedValue({
        id: 1,
        name: 'Hydrochloric Acid',
        hazard_class: 'Corrosive',
        safety_precautions: 'Handle with care',
        storage_conditions: 'Cool, dry place'
      });

      const response = await processChatMessage('What about its safety?', 1, 'borrower');
      expect(response).toContain('Safety Information');
      expect(response).toContain('Corrosive');
    });
  });
});

// Test utilities
describe('Test Utilities', () => {
  test('should validate test data structure', () => {
    const testChemical = {
      id: 1,
      name: 'Test Chemical',
      category: 'Test Category',
      quantity: 100,
      unit: 'g'
    };

    expect(testChemical).toHaveProperty('id');
    expect(testChemical).toHaveProperty('name');
    expect(testChemical).toHaveProperty('quantity');
    expect(typeof testChemical.quantity).toBe('number');
  });
});

// Performance tests
describe('Performance Tests', () => {
  test('should respond within reasonable time', async () => {
    const startTime = Date.now();

    await processChatMessage('What chemicals do we have?', 1, 'borrower');

    const endTime = Date.now();
    const responseTime = endTime - startTime;

    // Should respond within 5 seconds (reasonable for database operations)
    expect(responseTime).toBeLessThan(5000);
  });
});

module.exports = {
  runTests: () => {
    console.log('🧪 Running ChemBot Tests...');
    // This would be called to run all tests
    // In a real implementation, you'd use a test runner like Jest
  }
};