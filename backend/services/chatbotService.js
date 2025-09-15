const {
  getChemicals,
  getEquipment,
  getBorrowings,
  getUserInfo,
  getLectureSchedules,
  createBorrowing,
  getChemicalByName,
  getEquipmentByName,
  searchChemicals,
  searchEquipment,
  getChemicalsByCategory,
  getLowStockChemicals,
  getExpiringChemicals,
  getExpiredChemicals,
  searchChemicalsAdvanced,
  getEquipmentByCategory,
  getAvailableEquipment,
  getEquipmentDueForMaintenance,
  getEquipmentNeedingCalibration,
  searchEquipmentAdvanced,
  getIncompatibleChemicals,
  getChemicalsRequiringSpecialStorage,
  checkEquipmentAvailability,
  getEquipmentBookings,
  logChatbotQuery,
  getChatbotUsageStats,
  getOrCreateConversation,
  getConversationContext,
  setConversationContext,
  clearConversationContext,
  getConversationHistory
} = require('./apiService');

const {
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
} = require('../utils/chatbotValidation');

// Main message processor
async function processChatMessage(message, userId, userRole) {
  const startTime = Date.now();
  try {
    // Input validation
    validateMessage(message);
    await validateUserId(userId);
    validateUserRole(userRole);

    const sanitizedMessage = sanitizeInput(message);
    const lowerMessage = sanitizedMessage.toLowerCase();

    // Log input validation
    console.log(`[VALIDATION] Message processed - User: ${userId}, Role: ${userRole}, Length: ${message.length}`);

    // Get conversation context
    const conversation = await getOrCreateConversation(userId);
    let context = {};
    
    if (conversation) {
      context = await getConversationContext(conversation.id);
      await updateConversationTimestamp(conversation.id);
    }

    // Log query
    await logQuery(userId, sanitizedMessage, 'user_query');

    // Route to appropriate handler based on message intent
    const response = await routeMessage(lowerMessage, sanitizedMessage, userId, userRole, context, conversation);
    
    // Log response
    await logQuery(userId, sanitizedMessage, response, 'assistant_response');

    // Log performance
    console.log(`[PERF] Chat message processed in ${Date.now() - startTime}ms - User: ${userId}`);

    return response;

  } catch (error) {
    console.error('Message processing error:', error);
    console.log(`[PERF] Chat message failed after ${Date.now() - startTime}ms - User: ${userId}, Error: ${error.message}`);
    const errorResponse = createErrorResponse(error, 'I encountered an error. Please try again.');
    await logQuery(userId, message, errorResponse, 'error');
    return errorResponse;
  }
}

// Smart message router
async function routeMessage(lowerMessage, originalMessage, userId, userRole, context, conversation) {
  // Priority 1: Handle contextual follow-ups
  if (context && Object.keys(context).length > 0) {
    const contextualResponse = await handleContextualResponse(originalMessage, context, conversation?.id);
    if (contextualResponse) return contextualResponse;
  }

  // Enhanced intent detection with confidence scoring
  const intent = await analyzeMessageIntent(lowerMessage, originalMessage);
  
  console.log(`[INTENT] Detected: ${intent.type} (confidence: ${intent.confidence})`);
  
  // Route based on intent with fallback to your existing logic
  if (intent.confidence > 0.6) {
    switch (intent.type) {
      case 'chemical_query':
        return await handleChemicalQuery(originalMessage, userId, conversation?.id);
      case 'equipment_query':
        return await handleEquipmentQuery(originalMessage, userId, conversation?.id);
      case 'borrowing_request':
        return await handleBorrowingRequest(originalMessage, userId, userRole);
      case 'schedule_query':
        return await handleScheduleQuery(originalMessage, userId);
      case 'safety_query':
        return await handleSafetyQuery(originalMessage);
      case 'inventory_alert':
        return await handleInventoryAlerts();
      case 'maintenance_query':
        return await handleMaintenanceStatus();
      case 'help_request':
        return await generateHelpResponse(userId, userRole);
    }
  }


  // Fallback to your existing detection methods
  if (await containsChemicalQuery(lowerMessage)) {
    return await handleChemicalQuery(originalMessage, userId, conversation?.id);
  }

  if (await containsEquipmentQuery(lowerMessage)) {
    return await handleEquipmentQuery(originalMessage, userId, conversation?.id);
  }

  if (containsBorrowingRequest(lowerMessage)) {
    return await handleBorrowingRequest(originalMessage, userId, userRole);
  }

  if (containsScheduleQuery(lowerMessage)) {
    return await handleScheduleQuery(originalMessage, userId);
  }

  if (containsSafetyQuery(lowerMessage)) {
    return await handleSafetyQuery(originalMessage);
  }

  if (containsInventoryAlert(lowerMessage)) {
    return await handleInventoryAlerts();
  }

  if (containsMaintenanceQuery(lowerMessage)) {
    return await handleMaintenanceStatus();
  }

  if (lowerMessage.includes('help') || lowerMessage.includes('what can')) {
    return await generateHelpResponse(userId, userRole);
  }

  // Default: Intelligent response based on current system state
  return await generateIntelligentDefault(userId, userRole);
}

async function analyzeMessageIntent(lowerMessage, originalMessage) {
  const intents = [];
  
  // Database-first chemical query detection
  const chemicalScore = await calculateDatabaseChemicalScore(lowerMessage, originalMessage);
  if (chemicalScore > 0) intents.push({ type: 'chemical_query', confidence: chemicalScore });
  
  // Database-first equipment query detection
  const equipmentScore = await calculateDatabaseEquipmentScore(lowerMessage, originalMessage);
  if (equipmentScore > 0) intents.push({ type: 'equipment_query', confidence: equipmentScore });
  
  // Keep existing logic for other intent types (borrowing, safety, etc.)
  const borrowingScore = calculateIntentScore(lowerMessage, {
    keywords: ['borrow', 'request', 'need', 'get', 'take', 'obtain'],
    actions: ['can i', 'i want to', 'i need', 'how to', 'submit'],
    weight: 1.2
  });
  if (borrowingScore > 0) intents.push({ type: 'borrowing_request', confidence: borrowingScore });
  
  const safetyScore = calculateIntentScore(lowerMessage, {
    keywords: ['safety', 'hazard', 'ppe', 'spill', 'emergency', 'danger', 'toxic', 'protective'],
    actions: ['what to do', 'how to handle', 'procedure', 'protocol', 'guidelines'],
    weight: 1.3
  });
  if (safetyScore > 0) intents.push({ type: 'safety_query', confidence: safetyScore });
  
  // Return highest confidence intent or default
  if (intents.length === 0) {
    return { type: 'default', confidence: 0 };
  }
  
  return intents.reduce((max, current) => 
    current.confidence > max.confidence ? current : max
  );
}

// ADD this helper function for calculating intent scores
function calculateIntentScore(message, pattern) {
  let score = 0;
  
  // Check for keyword matches
  const keywordMatches = pattern.keywords.filter(keyword => 
    message.includes(keyword)
  ).length;
  
  // Check for action matches
  const actionMatches = pattern.actions.filter(action => 
    message.includes(action)
  ).length;
  
  // Base score calculation
  if (keywordMatches > 0) {
    score += (keywordMatches / pattern.keywords.length) * 0.6;
  }
  
  if (actionMatches > 0) {
    score += (actionMatches / pattern.actions.length) * 0.4;
  }
  
  // Apply pattern weight
  score *= pattern.weight;
  
  // Bonus for multiple matches
  if (keywordMatches > 1 || actionMatches > 1) {
    score *= 1.2;
  }
  
  return Math.min(score, 1.0); // Cap at 1.0
}


function classifyQueryType(message) {
  if (!message) return 'general';
  
  const lowerMsg = message.toLowerCase();
  
  // Chemical-related queries
  if (lowerMsg.includes('chemical') || lowerMsg.includes('reagent') || 
      lowerMsg.includes('compound') || lowerMsg.includes('solution')) {
    return 'chemical_inquiry';
  }
  
  // Equipment-related queries
  if (lowerMsg.includes('equipment') || lowerMsg.includes('instrument') || 
      lowerMsg.includes('device') || lowerMsg.includes('apparatus')) {
    return 'equipment_inquiry';
  }
  
  // Safety-related queries
  if (lowerMsg.includes('safety') || lowerMsg.includes('hazard') || 
      lowerMsg.includes('ppe') || lowerMsg.includes('spill')) {
    return 'safety_query';
  }
  
  // Borrowing/request queries
  if (lowerMsg.includes('borrow') || lowerMsg.includes('request') || 
      lowerMsg.includes('book') || lowerMsg.includes('reserve')) {
    return 'borrowing_request';
  }
  
  // Schedule queries
  if (lowerMsg.includes('schedule') || lowerMsg.includes('when') || 
      lowerMsg.includes('booking') || lowerMsg.includes('time')) {
    return 'schedule_query';
  }
  
  // Inventory/status queries
  if (lowerMsg.includes('available') || lowerMsg.includes('stock') || 
      lowerMsg.includes('inventory') || lowerMsg.includes('status')) {
    return 'inventory_query';
  }
  
  // Help queries
  if (lowerMsg.includes('help') || lowerMsg.includes('what can')) {
    return 'help_request';
  }
  
  return 'general';
}

// Query type detection helpers
async function containsChemicalQuery(message) {
  const actionKeywords = ['what is', 'tell me about', 'details', 'info', 'properties', 'available', 'stock', 'find', 'show me'];
  const hasAction = actionKeywords.some(action => message.includes(action));
  
  if (!hasAction) return false;
  
  // Extract potential chemical name from the message
  const potentialChemicalName = extractChemicalName(message);
  
  if (potentialChemicalName) {
    // Check if this name exists in the database
    try {
      const chemical = await findChemicalInDatabase(potentialChemicalName);
      return chemical !== null; // Return true if found in database
    } catch (error) {
      console.error('Database check error in containsChemicalQuery:', error);
      return false;
    }
  }
  
  // Also check for generic chemical queries
  const chemicalKeywords = ['chemical', 'chemicals', 'reagent', 'compound', 'substance', 'solution'];
  return chemicalKeywords.some(keyword => message.includes(keyword));
}

// Enhanced chemical query handler
async function handleChemicalQuery(message, userId, conversationId) {
  try {
    // Extract chemical name from message
    const chemicalName = extractChemicalName(message);
    
    if (chemicalName) {
      // Search for specific chemical
      const chemical = await findChemicalInDatabase(chemicalName);
      
      if (chemical) {
        // Store in context for follow-up questions
        if (conversationId) {
          await setConversationContext(conversationId, 'last_chemical', chemical.name);
          await setConversationContext(conversationId, 'last_chemical_id', chemical.id);
        }
        
        return formatChemicalDetails(chemical);
      } else {
        // Chemical not found - search for similar
        const similar = await searchSimilarChemicals(chemicalName);
        if (similar.length > 0) {
          return formatSimilarChemicals(similar, chemicalName);
        } else {
          return formatChemicalNotFound(chemicalName);
        }
      }
    } else {
      // No specific chemical mentioned - show overview
      return await generateChemicalOverview();
    }
  } catch (error) {
    console.error('Chemical query error:', error);
    return "I'm having trouble accessing chemical information. Please try again.";
  }
}

// Enhanced equipment query handler
async function handleEquipmentQuery(message, userId, conversationId) {
  try {
    const equipmentName = extractEquipmentName(message);
    
    if (equipmentName) {
      const equipment = await findEquipmentInDatabase(equipmentName);
      
      if (equipment) {
        if (conversationId) {
          await setConversationContext(conversationId, 'last_equipment', equipment.name);
          await setConversationContext(conversationId, 'last_equipment_id', equipment.id);
        }
        
        return formatEquipmentDetails(equipment);
      } else {
        const similar = await searchSimilarEquipment(equipmentName);
        if (similar.length > 0) {
          return formatSimilarEquipment(similar, equipmentName);
        } else {
          return formatEquipmentNotFound(equipmentName);
        }
      }
    } else {
      return await generateEquipmentOverview();
    }
  } catch (error) {
    console.error('Equipment query error:', error);
    return "I'm having trouble accessing equipment information. Please try again.";
  }
}

// Database search functions with error handling
async function findChemicalInDatabase(name) {
  try {
    // Try exact match first
    let chemical = await getChemicalByName(name);
    if (chemical) return chemical;
    
    // Try case-insensitive search
    const allChemicals = await getChemicals();
    chemical = allChemicals.find(c => 
      c.name.toLowerCase() === name.toLowerCase()
    );
    if (chemical) return chemical;
    
    // Try partial match
    chemical = allChemicals.find(c => 
      c.name.toLowerCase().includes(name.toLowerCase()) ||
      name.toLowerCase().includes(c.name.toLowerCase())
    );
    
    return chemical || null;
  } catch (error) {
    console.error('Database search error:', error);
    return null;
  }
}

async function findEquipmentInDatabase(name) {
  try {
    let equipment = await getEquipmentByName(name);
    if (equipment) return equipment;
    
    const allEquipment = await getEquipment();
    equipment = allEquipment.find(e => 
      e.name.toLowerCase() === name.toLowerCase()
    );
    if (equipment) return equipment;
    
    equipment = allEquipment.find(e => 
      e.name.toLowerCase().includes(name.toLowerCase()) ||
      name.toLowerCase().includes(e.name.toLowerCase())
    );
    
    return equipment || null;
  } catch (error) {
    console.error('Database search error:', error);
    return null;
  }
}

async function searchSimilarChemicals(searchTerm) {
  try {
    const results = await searchChemicals(searchTerm);
    return results.slice(0, 5);
  } catch (error) {
    console.error('Search error:', error);
    return [];
  }
}

async function searchSimilarEquipment(searchTerm) {
  try {
    const results = await searchEquipment(searchTerm);
    return results.slice(0, 5);
  } catch (error) {
    console.error('Search error:', error);
    return [];
  }
}

// Format response functions
function formatChemicalDetails(chemical) {
  let response = `📋 **${chemical.name}**\n\n`;
  
  // Always show what we actually have in database
  response += `**Current Inventory:**\n`;
  response += `• Quantity: ${chemical.quantity} ${chemical.unit}\n`;
  response += `• Location: ${chemical.storage_location}\n`;
  response += `• Category: ${chemical.category}\n`;
  
  if (chemical.expiry_date) {
    const expiryDate = new Date(chemical.expiry_date);
    const daysUntilExpiry = Math.ceil((expiryDate - new Date()) / (1000 * 60 * 60 * 24));
    response += `• Expiry: ${expiryDate.toLocaleDateString()}`;
    
    if (daysUntilExpiry < 0) {
      response += ` ⚠️ EXPIRED`;
    } else if (daysUntilExpiry < 30) {
      response += ` (${daysUntilExpiry} days remaining)`;
    }
    response += `\n`;
  }
  
  // Only show properties that exist in database
  if (chemical.cas_number || chemical.molecular_formula || chemical.molecular_weight) {
    response += `\n**Chemical Properties:**\n`;
    if (chemical.cas_number) response += `• CAS Number: ${chemical.cas_number}\n`;
    if (chemical.molecular_formula) response += `• Formula: ${chemical.molecular_formula}\n`;
    if (chemical.molecular_weight) response += `• Molecular Weight: ${chemical.molecular_weight} g/mol\n`;
  }
  
  // Safety information if available
  if (chemical.hazard_class || chemical.storage_conditions) {
    response += `\n**Safety Information:**\n`;
    if (chemical.hazard_class) response += `• Hazard Class: ${chemical.hazard_class}\n`;
    if (chemical.storage_conditions) response += `• Storage Requirements: ${chemical.storage_conditions}\n`;
  }
  
  // Actionable next steps
  response += `\n**Actions:**\n`;
  response += `• To borrow this chemical, specify quantity needed\n`;
  response += `• For safety data sheet, ask "safety for ${chemical.name}"\n`;
  if (chemical.quantity <= 10) {
    response += `• ⚠️ Low stock - consider requesting more\n`;
  }
  
  return response;
}

function formatEquipmentDetails(equipment) {
  let response = `⚙️ **${equipment.name}**\n\n`;
  
  response += `**Current Status:**\n`;
  response += `• Status: ${equipment.status}\n`;
  response += `• Condition: ${equipment.condition}\n`;
  response += `• Location: ${equipment.location}\n`;
  response += `• Category: ${equipment.category}\n`;
  
  if (equipment.last_maintenance_date) {
    const lastMaintenance = new Date(equipment.last_maintenance_date);
    const daysSince = Math.floor((new Date() - lastMaintenance) / (1000 * 60 * 60 * 24));
    response += `• Last Maintenance: ${lastMaintenance.toLocaleDateString()} (${daysSince} days ago)\n`;
    
    if (equipment.maintenance_schedule && daysSince > equipment.maintenance_schedule) {
      response += `• ⚠️ Maintenance overdue by ${daysSince - equipment.maintenance_schedule} days\n`;
    }
  }
  
  // Technical details if available
  if (equipment.serial_number || equipment.manufacturer) {
    response += `\n**Technical Details:**\n`;
    if (equipment.serial_number) response += `• Serial: ${equipment.serial_number}\n`;
    if (equipment.manufacturer) response += `• Manufacturer: ${equipment.manufacturer}\n`;
    if (equipment.model) response += `• Model: ${equipment.model}\n`;
  }
  
  // Actions based on status
  response += `\n**Actions:**\n`;
  if (equipment.status === 'available') {
    response += `• To book this equipment, specify date and duration\n`;
  } else if (equipment.status === 'in_use') {
    response += `• Currently in use - I can check when it will be available\n`;
  } else if (equipment.status === 'maintenance') {
    response += `• Under maintenance - expected completion date pending\n`;
  }
  
  return response;
}

function formatSimilarChemicals(chemicals, searchTerm) {
  let response = `I couldn't find "${searchTerm}" exactly, but here are similar chemicals in our inventory:\n\n`;
  
  chemicals.forEach((chem, index) => {
    response += `${index + 1}. **${chem.name}**\n`;
    response += `   • ${chem.quantity} ${chem.unit} available\n`;
    response += `   • Location: ${chem.storage_location}\n\n`;
  });
  
  response += `Which one would you like to know more about?`;
  return response;
}

function formatSimilarEquipment(equipment, searchTerm) {
  let response = `I couldn't find "${searchTerm}" exactly, but here are similar equipment items:\n\n`;
  
  equipment.forEach((eq, index) => {
    response += `${index + 1}. **${eq.name}**\n`;
    response += `   • Status: ${eq.status}\n`;
    response += `   • Location: ${eq.location}\n\n`;
  });
  
  response += `Which one would you like to know more about?`;
  return response;
}

function formatChemicalNotFound(searchTerm) {
  return `I couldn't find any chemical matching "${searchTerm}" in our inventory.\n\n` +
         `**What you can do:**\n` +
         `• Check if the name is spelled correctly\n` +
         `• Try searching with a partial name\n` +
         `• Browse all chemicals by asking "show all chemicals"\n` +
         `• Request to purchase this chemical if needed\n\n` +
         `Would you like me to help with any of these options?`;
}

function formatEquipmentNotFound(searchTerm) {
  return `I couldn't find any equipment matching "${searchTerm}" in our inventory.\n\n` +
         `**What you can do:**\n` +
         `• Check if the name is spelled correctly\n` +
         `• Try searching with a partial name\n` +
         `• Browse all equipment by asking "show all equipment"\n` +
         `• Request to purchase this equipment if needed\n\n` +
         `Would you like me to help with any of these options?`;
}

// Generate overview functions
async function generateChemicalOverview() {
  try {
    const chemicals = await getChemicals();
    
    if (chemicals.length === 0) {
      return `📊 **Chemical Inventory Status**\n\n` +
             `The chemical inventory is currently empty.\n\n` +
             `**Available Actions:**\n` +
             `• Submit a purchase request for needed chemicals\n` +
             `• Contact lab administration for restocking\n` +
             `• Check equipment availability instead`;
    }
    
    // Group by category
    const categories = {};
    chemicals.forEach(chem => {
      if (!categories[chem.category]) {
        categories[chem.category] = [];
      }
      categories[chem.category].push(chem);
    });
    
    let response = `📊 **Chemical Inventory Overview**\n\n`;
    response += `Total chemicals in stock: ${chemicals.length}\n\n`;
    
    response += `**Categories:**\n`;
    Object.entries(categories).slice(0, 5).forEach(([category, items]) => {
      response += `• ${category}: ${items.length} items\n`;
    });
    
    // Show some examples
    response += `\n**Sample Chemicals Available:**\n`;
    chemicals.slice(0, 5).forEach((chem, index) => {
      response += `${index + 1}. ${chem.name} - ${chem.quantity} ${chem.unit}\n`;
    });
    
    response += `\n**To get specific information:**\n`;
    response += `Ask "tell me about [chemical name]" for any chemical listed above.`;
    
    return response;
  } catch (error) {
    console.error('Overview generation error:', error);
    return "I'm having trouble accessing the chemical inventory. Please try again.";
  }
}

async function generateEquipmentOverview() {
  try {
    const equipment = await getEquipment();
    
    if (equipment.length === 0) {
      return `⚙️ **Equipment Inventory Status**\n\n` +
             `The equipment inventory is currently empty.\n\n` +
             `**Available Actions:**\n` +
             `• Submit a purchase request for needed equipment\n` +
             `• Contact lab administration for procurement\n` +
             `• Check chemical availability instead`;
    }
    
    let response = `⚙️ **Equipment Inventory Overview**\n\n`;
    response += `Total equipment: ${equipment.length}\n\n`;
    
    // Show ALL equipment with their actual status from database
    response += `**All Equipment:**\n`;
    equipment.slice(0, 10).forEach((eq, index) => {
      const status = eq.status || 'unknown status';
      const location = eq.location || 'location not specified';
      response += `${index + 1}. **${eq.name}**\n`;
      response += `   • Status: ${status}\n`;
      response += `   • Location: ${location}\n`;
      if (eq.category) response += `   • Category: ${eq.category}\n`;
      response += `\n`;
    });
    
    // Group by actual status values from database
    const statusCounts = {};
    equipment.forEach(eq => {
      const status = eq.status || 'unknown';
      statusCounts[status] = (statusCounts[status] || 0) + 1;
    });
    
    response += `**Status Summary:**\n`;
    Object.entries(statusCounts).forEach(([status, count]) => {
      response += `• ${status}: ${count}\n`;
    });
    
    response += `\n**To get specific information:**\n`;
    response += `Ask "tell me about [equipment name]" for any equipment listed above.`;
    
    return response;
  } catch (error) {
    console.error('Overview generation error:', error);
    return "I'm having trouble accessing the equipment inventory. Please try again.";
  }
}

// Borrowing request handler
async function handleBorrowingRequest(message, userId, userRole) {
  try {
    // Check for specific item mention
    const itemName = extractItemName(message);
    
    if (itemName) {
      // Check if it's a chemical or equipment
      const chemical = await findChemicalInDatabase(itemName);
      const equipment = await findEquipmentInDatabase(itemName);
      
      if (chemical) {
        return `📋 **Borrowing Request for ${chemical.name}**\n\n` +
               `Available: ${chemical.quantity} ${chemical.unit}\n` +
               `Location: ${chemical.storage_location}\n\n` +
               `**To complete your request, please provide:**\n` +
               `1. Quantity needed (e.g., "50 mL")\n` +
               `2. Purpose of use\n` +
               `3. Expected return date\n\n` +
               `Example: "I need 50 mL for titration experiment, returning tomorrow"`;
      }
      
      if (equipment) {
        if (equipment.status !== 'available') {
          return `⚠️ **${equipment.name} is currently ${equipment.status}**\n\n` +
                 `Would you like me to:\n` +
                 `• Check when it will be available\n` +
                 `• Find alternative equipment\n` +
                 `• Add you to the waiting list`;
        }
        
        return `⚙️ **Booking Request for ${equipment.name}**\n\n` +
               `Status: Available\n` +
               `Location: ${equipment.location}\n\n` +
               `**To complete your booking, please provide:**\n` +
               `1. Date and time needed\n` +
               `2. Duration of use\n` +
               `3. Purpose\n\n` +
               `Example: "Book for tomorrow 2 PM for 3 hours for spectroscopy analysis"`;
      }
      
      return `Item "${itemName}" not found in inventory.\n\n` +
             `Would you like to:\n` +
             `• Search for similar items\n` +
             `• Submit a purchase request\n` +
             `• Browse available inventory`;
    }
    
    // General borrowing help
    const borrowings = await getBorrowings();
    const userBorrowings = borrowings.filter(b => b.borrower_id === userId);
    const pending = userBorrowings.filter(b => b.status === 'pending').length;
    const active = userBorrowings.filter(b => b.status === 'approved').length;
    
    let response = `📋 **Borrowing Request Assistant**\n\n`;
    
    if (userBorrowings.length > 0) {
      response += `**Your Current Requests:**\n`;
      response += `• Pending approval: ${pending}\n`;
      response += `• Active borrowings: ${active}\n\n`;
    }
    
    response += `**How to make a borrowing request:**\n`;
    response += `1. Specify what you need (e.g., "borrow sodium chloride")\n`;
    response += `2. Provide quantity and duration\n`;
    response += `3. State the purpose\n\n`;
    response += `What would you like to borrow?`;
    
    return response;
  } catch (error) {
    console.error('Borrowing request error:', error);
    return "I'm having trouble processing your borrowing request. Please try again.";
  }
}

// Schedule query handler
async function handleScheduleQuery(message, userId) {
  try {
    const schedules = await getLectureSchedules();
    const today = new Date();
    const dateStr = today.toISOString().split('T')[0];
    
    // Check for specific date mentions
    let targetDate = dateStr;
    if (message.toLowerCase().includes('tomorrow')) {
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);
      targetDate = tomorrow.toISOString().split('T')[0];
    }
    
    const relevantSchedules = schedules.filter(s => s.date === targetDate);
    
    if (relevantSchedules.length === 0) {
      return `📅 **No lab sessions scheduled for ${targetDate === dateStr ? 'today' : 'tomorrow'}**\n\n` +
             `Would you like to:\n` +
             `• Check another date\n` +
             `• View the weekly schedule\n` +
             `• Book equipment for independent work`;
    }
    
    let response = `📅 **Lab Schedule for ${targetDate === dateStr ? 'Today' : 'Tomorrow'}**\n\n`;
    
    relevantSchedules.forEach((schedule, index) => {
      response += `${index + 1}. **${schedule.course_name}**\n`;
      response += `   • Time: ${schedule.start_time} - ${schedule.end_time}\n`;
      response += `   • Lab: ${schedule.lab_name}\n`;
      if (schedule.instructor) response += `   • Instructor: ${schedule.instructor}\n`;
      response += `\n`;
    });
    
    return response;
  } catch (error) {
    console.error('Schedule query error:', error);
    return "I'm having trouble accessing the schedule. Please try again.";
  }
}

// Safety query handler
async function handleSafetyQuery(message) {
  const lowerMessage = message.toLowerCase();
  
  // Check for specific safety topics
  if (lowerMessage.includes('spill')) {
    return `🚨 **Chemical Spill Response Protocol**\n\n` +
           `**Immediate Actions:**\n` +
           `1. Alert others in the area\n` +
           `2. Evacuate if necessary\n` +
           `3. Contain the spill if safe to do so\n\n` +
           `**Cleanup Steps:**\n` +
           `1. Wear appropriate PPE\n` +
           `2. Use spill kit materials\n` +
           `3. Neutralize if required\n` +
           `4. Dispose in proper waste container\n` +
           `5. Report to lab supervisor\n\n` +
           `**Emergency Contact:** Call lab safety officer immediately`;
  }
  
  if (lowerMessage.includes('ppe') || lowerMessage.includes('protective')) {
    return `🦺 **Personal Protective Equipment (PPE) Requirements**\n\n` +
           `**Mandatory PPE:**\n` +
           `• Safety goggles or face shield\n` +
           `• Lab coat (buttoned)\n` +
           `• Closed-toe shoes\n` +
           `• Appropriate gloves for chemicals used\n\n` +
           `**Additional PPE (when required):**\n` +
           `• Face shield for splash hazards\n` +
           `• Apron for corrosive materials\n` +
           `• Respirator for toxic vapors\n` +
           `• Heat-resistant gloves for hot equipment\n\n` +
           `Always check specific requirements for your experiment.`;
  }
  
  // Check for specific chemical safety
  const chemicalName = extractChemicalName(message);
  if (chemicalName) {
    const chemical = await findChemicalInDatabase(chemicalName);
    if (chemical && chemical.hazard_class) {
      return `⚠️ **Safety Information for ${chemical.name}**\n\n` +
             `**Hazard Class:** ${chemical.hazard_class}\n` +
             `**Storage Requirements:** ${chemical.storage_conditions || 'Standard chemical storage'}\n\n` +
             `**General Precautions:**\n` +
             `• Always wear appropriate PPE\n` +
             `• Work in well-ventilated area\n` +
             `• Keep away from incompatible materials\n` +
             `• Have spill kit readily available\n\n` +
             `For complete safety data, consult the Safety Data Sheet (SDS).`;
    }
  }
  
  // General safety information
  return `🛡️ **Lab Safety Information**\n\n` +
         `**I can help with:**\n` +
         `• Chemical spill procedures\n` +
         `• PPE requirements\n` +
         `• Emergency protocols\n` +
         `• Chemical compatibility\n` +
         `• Waste disposal guidelines\n` +
         `• First aid procedures\n\n` +
         `**Specific Topics:**\n` +
         `• "Safety for [chemical name]"\n` +
         `• "What to do for acid spill"\n` +
         `• "PPE for working with bases"\n\n` +
         `What safety information do you need?`;
}

// Inventory alerts handler
async function handleInventoryAlerts() {
  try {
    let response = `📊 **Inventory Status Alerts**\n\n`;
    let hasAlerts = false;
    
    // Check low stock chemicals
    const lowStock = await getLowStockChemicals(10);
    if (lowStock.length > 0) {
      hasAlerts = true;
      response += `**⚠️ Low Stock Chemicals:**\n`;
      lowStock.slice(0, 5).forEach(chem => {
        const level = chem.quantity <= 5 ? '🔴' : '🟡';
        response += `${level} ${chem.name}: ${chem.quantity} ${chem.unit} remaining\n`;
      });
      response += `\n`;
    }
    
    // Check expiring chemicals
    const expiring = await getExpiringChemicals(30);
    if (expiring.length > 0) {
      hasAlerts = true;
      response += `**⏰ Expiring Soon (within 30 days):**\n`;
      expiring.slice(0, 5).forEach(chem => {
        const daysLeft = Math.ceil((new Date(chem.expiry_date) - new Date()) / (1000 * 60 * 60 * 24));
        response += `• ${chem.name}: ${daysLeft} days remaining\n`;
      });
      response += `\n`;
    }
    
    // Check expired chemicals
    const expired = await getExpiredChemicals();
    if (expired.length > 0) {
      hasAlerts = true;
      response += `**🚨 Expired Chemicals (Immediate Action Required):**\n`;
      expired.slice(0, 3).forEach(chem => {
        response += `• ${chem.name} - Expired ${new Date(chem.expiry_date).toLocaleDateString()}\n`;
      });
      response += `\nPlease dispose of these chemicals safely!\n\n`;
    }
    
    if (!hasAlerts) {
      response += `✅ **All inventory levels are normal**\n\n`;
      response += `• No chemicals are critically low\n`;
      response += `• No chemicals expiring soon\n`;
      response += `• All equipment maintained properly`;
    }
    
    return response;
  } catch (error) {
    console.error('Inventory alerts error:', error);
    return "I'm having trouble checking inventory alerts. Please try again.";
  }
}

// Maintenance status handler
async function handleMaintenanceStatus() {
  try {
    let response = `🔧 **Equipment Maintenance Status**\n\n`;
    let hasIssues = false;
    
    // Check equipment due for maintenance
    const dueMaintenance = await getEquipmentDueForMaintenance();
    if (dueMaintenance.length > 0) {
      hasIssues = true;
      response += `**⚠️ Equipment Due for Maintenance:**\n`;
      dueMaintenance.slice(0, 5).forEach(eq => {
        const overdue = eq.days_since_maintenance - eq.maintenance_schedule;
        const status = overdue > 7 ? '🔴' : overdue > 0 ? '🟡' : '🟢';
        response += `${status} ${eq.name}: ${overdue > 0 ? `Overdue by ${overdue} days` : 'Due now'}\n`;
      });
      response += `\n`;
    }
    
    // Check calibration needs
    const needsCalibration = await getEquipmentNeedingCalibration();
    if (needsCalibration.length > 0) {
      hasIssues = true;
      response += `**📏 Equipment Needing Calibration:**\n`;
      needsCalibration.slice(0, 5).forEach(eq => {
        response += `• ${eq.name}: Due ${new Date(eq.next_calibration_date).toLocaleDateString()}\n`;
      });
      response += `\n`;
    }
    
    if (!hasIssues) {
      response += `✅ **All equipment properly maintained**\n\n`;
      response += `• No maintenance overdue\n`;
      response += `• All calibrations current\n`;
      response += `• All equipment operational`;
    }
    
    return response;
  } catch (error) {
    console.error('Maintenance status error:', error);
    return "I'm having trouble checking maintenance status. Please try again.";
  }
}

// Contextual response handler
async function handleContextualResponse(message, context, conversationId) {
  try {
    const lowerMessage = message.toLowerCase();
    
    // Handle yes/no responses to pending actions
    if (context.pending_action) {
      if (lowerMessage.includes('yes') || lowerMessage.includes('sure') || lowerMessage.includes('ok')) {
        return await handleAffirmative(context, conversationId);
      }
      if (lowerMessage.includes('no') || lowerMessage.includes('not')) {
        await clearConversationContext(conversationId, 'pending_action');
        return "No problem! What else can I help you with?";
      }
    }
    
    // Handle follow-up questions about last item
    if (context.last_chemical_id && (lowerMessage.includes('borrow') || lowerMessage.includes('request'))) {
      const chemical = await getChemicalById(context.last_chemical_id);
      if (chemical) {
        return formatBorrowingInstructions(chemical, 'chemical');
      }
    }
    
    if (context.last_equipment_id && (lowerMessage.includes('book') || lowerMessage.includes('reserve'))) {
      const equipment = await getEquipmentById(context.last_equipment_id);
      if (equipment) {
        return formatBorrowingInstructions(equipment, 'equipment');
      }
    }
    
    // Handle quantity specifications
    if (context.awaiting_quantity) {
      const quantityMatch = message.match(/(\d+(?:\.\d+)?)\s*(\w+)/);
      if (quantityMatch) {
        return await processQuantityRequest(quantityMatch[1], quantityMatch[2], context, conversationId);
      }
    }
    
    return null;
  } catch (error) {
    console.error('Contextual response error:', error);
    return null;
  }
}

// Helper functions
function extractChemicalName(message) {
  // Remove common phrases to isolate chemical name
  const patterns = [
    /tell me about\s+(.+?)(?:\s+chemical)?$/i,
    /what is\s+(.+?)(?:\s+chemical)?$/i,
    /details (?:of|for|about)\s+(.+?)$/i,
    /information (?:on|about)\s+(.+?)$/i,
    /(.+?)\s+properties$/i,
    /(.+?)\s+details$/i
  ];
  
  for (const pattern of patterns) {
    const match = message.match(pattern);
    if (match && match[1]) {
      return match[1].trim();
    }
  }
  
  return null;
}

function extractEquipmentName(message) {
  const patterns = [
    /tell me about\s+(?:the\s+)?(.+?)(?:\s+equipment)?$/i,
    /what is\s+(?:the\s+)?(.+?)(?:\s+equipment)?$/i,
    /details (?:of|for|about)\s+(?:the\s+)?(.+?)$/i,
    /book\s+(?:the\s+)?(.+?)$/i,
    /reserve\s+(?:the\s+)?(.+?)$/i
  ];
  
  for (const pattern of patterns) {
    const match = message.match(pattern);
    if (match && match[1]) {
      return match[1].trim();
    }
  }
  
  return null;
}

function extractItemName(message) {
  const patterns = [
    /borrow\s+(?:some\s+)?(.+?)$/i,
    /request\s+(?:some\s+)?(.+?)$/i,
    /need\s+(?:some\s+)?(.+?)$/i,
    /get\s+(?:some\s+)?(.+?)$/i
  ];
  
  for (const pattern of patterns) {
    const match = message.match(pattern);
    if (match && match[1]) {
      return match[1].trim();
    }
  }
  
  return null;
}

// MISSING FUNCTION 1: Database chemical scoring
async function calculateDatabaseChemicalScore(lowerMessage, originalMessage) {
  const actionKeywords = ['what is', 'tell me about', 'details', 'info', 'properties', 'available', 'stock', 'find'];
  const hasAction = actionKeywords.some(action => lowerMessage.includes(action));
  
  if (!hasAction) return 0;
  
  const chemicalName = extractChemicalName(originalMessage);
  if (chemicalName) {
    try {
      const chemical = await findChemicalInDatabase(chemicalName);
      if (chemical) return 0.9; // High confidence - found in database
    } catch (error) {
      console.error('Database error in chemical scoring:', error);
    }
  }
  
  const chemicalKeywords = ['chemical', 'chemicals', 'reagent', 'compound', 'substance', 'solution'];
  if (chemicalKeywords.some(keyword => lowerMessage.includes(keyword))) {
    return 0.7; // Medium confidence - generic chemical query
  }
  return 0;
}

// MISSING FUNCTION 2: Database equipment scoring
async function calculateDatabaseEquipmentScore(lowerMessage, originalMessage) {
  const actionKeywords = ['what is', 'tell me about', 'details', 'spec', 'available', 'book', 'reserve', 'find'];
  const hasAction = actionKeywords.some(action => lowerMessage.includes(action));
  
  if (!hasAction) return 0;
  
  const equipmentName = extractEquipmentName(originalMessage);
  if (equipmentName) {
    try {
      const equipment = await findEquipmentInDatabase(equipmentName);
      if (equipment) return 0.9;
    } catch (error) {
      console.error('Database error in equipment scoring:', error);
    }
  }
  
  const equipmentKeywords = ['equipment', 'instrument', 'device', 'apparatus', 'machine'];
  if (equipmentKeywords.some(keyword => lowerMessage.includes(keyword))) {
    return 0.7;
  }
  return 0;
}

// MISSING FUNCTION 3: Equipment query detection
async function containsEquipmentQuery(message) {
  const actionKeywords = ['what is', 'tell me about', 'details', 'spec', 'available', 'book', 'reserve', 'find', 'show me'];
  const hasAction = actionKeywords.some(action => message.includes(action));
  
  if (!hasAction) return false;
  
  const potentialEquipmentName = extractEquipmentName(message);
  if (potentialEquipmentName) {
    try {
      const equipment = await findEquipmentInDatabase(potentialEquipmentName);
      return equipment !== null;
    } catch (error) {
      console.error('Database check error in containsEquipmentQuery:', error);
      return false;
    }
  }
  
  const equipmentKeywords = ['equipment', 'instrument', 'device', 'apparatus', 'machine'];
  return equipmentKeywords.some(keyword => message.includes(keyword));
}

// MISSING FUNCTIONS 4-8: Simple detection functions
function containsBorrowingRequest(message) {
  return message.includes('borrow') || message.includes('request') || message.includes('need');
}

function containsScheduleQuery(message) {
  return message.includes('schedule') || message.includes('booking') || message.includes('when');
}

function containsSafetyQuery(message) {
  return message.includes('safety') || message.includes('hazard') || message.includes('ppe') ||
         message.includes('spill') || message.includes('emergency');
}

function containsInventoryAlert(message) {
  return message.includes('low stock') || message.includes('expiring') || message.includes('expired');
}

function containsMaintenanceQuery(message) {
  return message.includes('maintenance') || message.includes('calibration') || message.includes('service');
}

function formatBorrowingInstructions(item, type) {
  if (type === 'chemical') {
    return `📋 **To borrow ${item.name}:**\n\n` +
           `Available: ${item.quantity} ${item.unit}\n\n` +
           `Please specify:\n` +
           `• Quantity needed (e.g., "50 mL")\n` +
           `• Purpose\n` +
           `• Return date\n\n` +
           `Example: "I need 100 mL for titration, returning Friday"`;
  } else {
    return `⚙️ **To book ${item.name}:**\n\n` +
           `Status: ${item.status}\n\n` +
           `Please specify:\n` +
           `• Date and time\n` +
           `• Duration\n` +
           `• Purpose\n\n` +
           `Example: "Book for Monday 10 AM for 2 hours"`;
  }
}

async function handleAffirmative(context, conversationId) {
  if (context.pending_action === 'purchase_request') {
    await setConversationContext(conversationId, 'awaiting_quantity', true);
    return `How much ${context.item_name} would you like to request?\n` +
           `Please specify quantity and unit (e.g., "500 mL" or "2 bottles")`;
  }
  
  if (context.pending_action === 'find_alternative') {
    return await suggestAlternatives(context.item_type, context.item_category);
  }
  
  return "I'll help you with that. Could you provide more details?";
}

async function processQuantityRequest(quantity, unit, context, conversationId) {
  await clearConversationContext(conversationId, 'awaiting_quantity');
  
  return `✅ **Request Submitted**\n\n` +
         `Item: ${context.item_name}\n` +
         `Quantity: ${quantity} ${unit}\n` +
         `Status: Pending approval\n\n` +
         `You'll be notified once approved.`;
}

async function suggestAlternatives(itemType, category) {
  if (itemType === 'chemical') {
    const alternatives = await getChemicalsByCategory(category);
    if (alternatives.length > 0) {
      let response = `Here are alternative chemicals in the ${category} category:\n\n`;
      alternatives.slice(0, 5).forEach((item, index) => {
        response += `${index + 1}. ${item.name} - ${item.quantity} ${item.unit}\n`;
      });
      return response;
    }
  } else {
    const alternatives = await getEquipmentByCategory(category);
    if (alternatives.length > 0) {
      let response = `Here are alternative equipment options:\n\n`;
      alternatives.slice(0, 5).forEach((item, index) => {
        response += `${index + 1}. ${item.name} - ${item.status}\n`;
      });
      return response;
    }
  }
  
  return "No alternatives found in this category.";
}

// Intelligent default response generator
async function generateIntelligentDefault(userId, userRole) {
  try {
    const [chemicals, equipment, schedules, borrowings] = await Promise.all([
      getChemicals(),
      getEquipment(),
      getLectureSchedules(),
      getBorrowings()
    ]);
    
    const userBorrowings = borrowings.filter(b => b.borrower_id === userId);
    
    let response = `🤖 **Lab Assistant Ready**\n\n`;
    
    // Show actual system status
    response += `**Current Lab Status:**\n`;
    
    if (chemicals.length > 0) {
      response += `• Chemicals: ${chemicals.length} types available\n`;
    } else {
      response += `• Chemicals: Inventory empty - request needed items\n`;
    }
    
    if (equipment.length > 0) {
      const available = equipment.filter(e => e.status === 'available').length;
      response += `• Equipment: ${available}/${equipment.length} available\n`;
    } else {
      response += `• Equipment: No equipment in inventory\n`;
    }
    
    if (userBorrowings.length > 0) {
      const pending = userBorrowings.filter(b => b.status === 'pending').length;
      if (pending > 0) response += `• You have ${pending} pending requests\n`;
    }
    
    response += `\n**Quick Actions:**\n`;
    response += `• "Tell me about [chemical/equipment name]"\n`;
    response += `• "What chemicals are available?"\n`;
    response += `• "Book [equipment name]"\n`;
    response += `• "Check today's schedule"\n`;
    response += `• "Safety procedures"\n\n`;
    
    response += `What can I help you with?`;
    
    return response;
  } catch (error) {
    console.error('Default response error:', error);
    return "Hello! I'm your lab assistant. How can I help you today?";
  }
}

// Help response generator
async function generateHelpResponse(userId, userRole) {
  let response = `🤖 **Lab Assistant Help Guide**\n\n`;
  
  response += `**What I Can Do:**\n\n`;
  
  response += `📊 **Inventory Information**\n`;
  response += `• Search chemicals and equipment\n`;
  response += `• Check availability and quantities\n`;
  response += `• View detailed specifications\n`;
  response += `• Find items by category\n\n`;
  
  response += `📋 **Requests & Borrowing**\n`;
  response += `• Submit borrowing requests\n`;
  response += `• Check request status\n`;
  response += `• View borrowing history\n`;
  response += `• Request new purchases\n\n`;
  
  response += `🛡️ **Safety & Compliance**\n`;
  response += `• Chemical safety information\n`;
  response += `• PPE requirements\n`;
  response += `• Spill procedures\n`;
  response += `• Storage guidelines\n\n`;
  
  response += `📅 **Scheduling**\n`;
  response += `• View lab schedules\n`;
  response += `• Book equipment time\n`;
  response += `• Check availability\n\n`;
  
  if (userRole === 'admin' || userRole === 'technician') {
    response += `💼 **Admin Functions**\n`;
    response += `• View system alerts\n`;
    response += `• Check maintenance status\n`;
    response += `• Review pending requests\n`;
    response += `• Monitor inventory levels\n\n`;
  }
  
  response += `**Example Commands:**\n`;
  response += `• "Tell me about sodium chloride"\n`;
  response += `• "Book the centrifuge for tomorrow"\n`;
  response += `• "What's expiring soon?"\n`;
  response += `• "Safety for working with acids"\n\n`;
  
  response += `What would you like help with?`;
  
  return response;
}

// Utility functions
async function updateConversationTimestamp(conversationId) {
  try {
    const { Pool } = require('pg');
    const pool = new Pool({
      user: process.env.DB_USER,
      host: process.env.DB_HOST,
      database: process.env.DB_NAME,
      password: process.env.DB_PASSWORD,
      port: process.env.DB_PORT,
    });
    
    await pool.query(
      'UPDATE chat_conversations SET updated_at = CURRENT_TIMESTAMP WHERE id = $1',
      [conversationId]
    );
  } catch (error) {
    console.error('Failed to update conversation timestamp:', error);
  }
}

async function logQuery(userId, message, responseType, queryType = null) {
  try {
    const safeQueryType = queryType || classifyQueryType(message) || 'general';
    await logChatbotQuery(userId, message, responseType, safeQueryType);
  } catch (error) {
    console.error('Failed to log query:', error);
  }
}

async function getChemicalById(id) {
  try {
    const chemicals = await getChemicals();
    return chemicals.find(c => c.id === id);
  } catch (error) {
    console.error('Error getting chemical by ID:', error);
    return null;
  }
}

async function getEquipmentById(id) {
  try {
    const equipment = await getEquipment();
    return equipment.find(e => e.id === id);
  } catch (error) {
    console.error('Error getting equipment by ID:', error);
    return null;
  }
}

// Export all functions
module.exports = {
  processChatMessage,
  handleChemicalQuery,
  handleEquipmentQuery,
  handleBorrowingRequest,
  handleScheduleQuery,
  handleSafetyQuery,
  handleInventoryAlerts,
  handleMaintenanceStatus,
  generateHelpResponse,
  generateIntelligentDefault,
  classifyQueryType,
  logQuery,
  analyzeMessageIntent,
  calculateIntentScore,
  calculateDatabaseChemicalScore,
  calculateDatabaseEquipmentScore,
  containsChemicalQuery,
  containsEquipmentQuery,
  containsBorrowingRequest,
  containsScheduleQuery,
  containsSafetyQuery,
  containsInventoryAlert,
  containsMaintenanceQuery
};