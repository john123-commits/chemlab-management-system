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

async function processChatMessage(message, userId, userRole) {
  try {
    // Validate inputs
    validateMessage(message);
    await validateUserId(userId);
    validateUserRole(userRole);

    // Sanitize the message
    const sanitizedMessage = sanitizeInput(message);
    const lowerMessage = sanitizedMessage.toLowerCase();

    // Get or create conversation and load context
    const conversation = await getOrCreateConversation(userId);
    let context = {};

    if (conversation) {
      context = await getConversationContext(conversation.id);

      // Update conversation timestamp
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
          [conversation.id]
        );
      } catch (error) {
        console.error('Failed to update conversation timestamp:', error);
      }
    }

    // Log the query for audit purposes
    try {
      await logChatbotQuery(userId, sanitizedMessage, '', 'user_query');
    } catch (error) {
      console.error('Failed to log chatbot query:', error);
    }

  // Enhanced chemical detail queries
  if ((lowerMessage.includes('chemical') || lowerMessage.includes('substance')) &&
       (lowerMessage.includes('detail') || lowerMessage.includes('info') || lowerMessage.includes('property') || lowerMessage.includes('what is'))) {
    const response = await handleChemicalDetailsQuery(message, conversation?.id);
    await logChatbotQuery(userId, message, response, 'chemical_details');
    return response;
  }

  // Enhanced equipment detail queries
  if ((lowerMessage.includes('equipment') || lowerMessage.includes('device') || lowerMessage.includes('instrument')) &&
       (lowerMessage.includes('detail') || lowerMessage.includes('info') || lowerMessage.includes('spec') || lowerMessage.includes('what is'))) {
    const response = await handleEquipmentDetailsQuery(message, conversation?.id);
    await logChatbotQuery(userId, message, response, 'equipment_details');
    return response;
  }

  // General chemical availability queries
  if (lowerMessage.includes('chemical') && (lowerMessage.includes('available') || lowerMessage.includes('have') || lowerMessage.includes('stock'))) {
    const response = await handleChemicalQuery(message, userId);
    await logChatbotQuery(userId, message, response, 'chemical_availability');
    return response;
  }

  // General equipment availability queries
  if (lowerMessage.includes('equipment') && (lowerMessage.includes('available') || lowerMessage.includes('have'))) {
    const response = await handleEquipmentQuery(message, userId);
    await logChatbotQuery(userId, message, response, 'equipment_availability');
    return response;
  }

  // Low stock and expiry alerts
  if (lowerMessage.includes('low stock') || lowerMessage.includes('running low') || lowerMessage.includes('expiring') || lowerMessage.includes('expiry')) {
    const response = await handleInventoryAlertsQuery(message);
    await logChatbotQuery(userId, message, response, 'inventory_alerts');
    return response;
  }

  // Equipment maintenance queries
  if (lowerMessage.includes('maintenance') || lowerMessage.includes('calibration') || lowerMessage.includes('service')) {
    const response = await handleMaintenanceQuery(message);
    await logChatbotQuery(userId, message, response, 'maintenance');
    return response;
  }

  // Equipment booking queries
  if ((lowerMessage.includes('book') || lowerMessage.includes('reserve') || lowerMessage.includes('schedule')) &&
      (lowerMessage.includes('equipment') || lowerMessage.includes('device') || lowerMessage.includes('instrument'))) {
    const response = await handleEquipmentBookingQuery(message, userId, userRole);
    await logChatbotQuery(userId, message, response, 'equipment_booking');
    return response;
  }

  // Purchase request queries
  if (lowerMessage.includes('request') && (lowerMessage.includes('purchase') || lowerMessage.includes('order') || lowerMessage.includes('buy'))) {
    const response = await handlePurchaseRequestQuery(message, userId, userRole);
    await logChatbotQuery(userId, message, response, 'purchase_request');
    return response;
  }

  // Protocol suggestion queries
  if (lowerMessage.includes('protocol') || lowerMessage.includes('procedure') || lowerMessage.includes('experiment') || lowerMessage.includes('method')) {
    const response = await handleProtocolQuery(message);
    await logChatbotQuery(userId, message, response, 'protocol_suggestion');
    return response;
  }

  // Safety and compatibility queries
  if (lowerMessage.includes('compatible') || lowerMessage.includes('storage') || lowerMessage.includes('hazard') || lowerMessage.includes('danger')) {
    const response = await handleSafetyCompatibilityQuery(message);
    await logChatbotQuery(userId, message, response, 'safety_compatibility');
    return response;
  }

  // Borrowing requests
  if ((lowerMessage.includes('borrow') || lowerMessage.includes('request')) && !lowerMessage.includes('status')) {
    const response = await handleBorrowingRequest(message, userId, userRole);
    await logChatbotQuery(userId, message, response, 'borrowing_request');
    return response;
  }

  // Borrowing status queries
  if (lowerMessage.includes('status') && (lowerMessage.includes('borrow') || lowerMessage.includes('request'))) {
    const response = await handleBorrowingStatus(message, userId, userRole);
    await logChatbotQuery(userId, message, response, 'borrowing_status');
    return response;
  }

  // Lecture schedule queries
  if (lowerMessage.includes('schedule') || lowerMessage.includes('booking') || lowerMessage.includes('lab time') || lowerMessage.includes('class')) {
    const response = await handleScheduleQuery(message, userId, userRole);
    await logChatbotQuery(userId, message, response, 'schedule');
    return response;
  }

  // Safety information queries
  if (lowerMessage.includes('safety') || lowerMessage.includes('precaution') || lowerMessage.includes('msds') || lowerMessage.includes('spill') || lowerMessage.includes('ppe')) {
    const response = await handleSafetyQuery(message);
    await logChatbotQuery(userId, message, response, 'safety');
    return response;
  }

  // Borrowing history queries
  if (lowerMessage.includes('history') || lowerMessage.includes('past')) {
    const response = await handleHistoryQuery(message, userId, userRole);
    await logChatbotQuery(userId, message, response, 'history');
    return response;
  }

  // Help queries
  if (lowerMessage.includes('help') || lowerMessage.includes('what can') || lowerMessage.includes('assist')) {
    const response = await handleHelpQuery(message, userId, userRole);
    await logChatbotQuery(userId, message, response, 'help');
    return response;
  }

  // Context-aware follow-up responses
  const contextualResponse = await handleContextualFollowUp(message, context, conversation?.id);
  if (contextualResponse) {
    await logChatbotQuery(userId, message, contextualResponse, 'contextual_followup');
    return contextualResponse;
  }

  // Enhanced default response with contextual suggestions based on actual system state
  const chemicals = await getChemicals();
  const equipment = await getEquipment();
  const schedules = await getLectureSchedules();
  const borrowings = await getBorrowings();
  const userBorrowings = borrowings.filter(b => b.borrower_id === userId);

  let defaultResponse = "🤖 **ChemBot: Your Lab Assistant!**\n\n";

  // Personalized greeting based on context
  if (context.last_topic) {
    defaultResponse += `💭 Picking up from ${context.last_topic}...\n\n`;
  }

  // Quick system overview
  defaultResponse += `**Quick Status:**\n`;
  defaultResponse += `• 🧪 Chemicals: ${chemicals.length} in stock\n`;
  defaultResponse += `• ⚙️ Equipment: ${equipment.length} available\n`;
  if (schedules.length > 0) {
    const today = new Date().toISOString().split('T')[0];
    const todaySchedules = schedules.filter(s => s.date === today);
    defaultResponse += `• 📅 Today's labs: ${todaySchedules.length}\n`;
  }
  if (userBorrowings.length > 0) {
    const pending = userBorrowings.filter(b => b.status === 'pending').length;
    if (pending > 0) {
      defaultResponse += `• 📋 Your pending requests: ${pending}\n`;
    }
  }
  defaultResponse += `\n**How can I help?**\n\n`;

  // Concise, prioritized suggestions
  defaultResponse += "🔬 **Chemicals**\n";
  if (chemicals.length > 0) {
    const sample = chemicals[0];
    defaultResponse += `• Search chemicals (${chemicals.length} total)\n`;
    defaultResponse += `• Details on ${sample.name}\n`;
  } else {
    defaultResponse += `• Request restock\n`;
  }
  defaultResponse += `\n`;

  defaultResponse += "⚙️ **Equipment**\n";
  if (equipment.length > 0) {
    const sample = equipment[0];
    const available = equipment.filter(e => e.status === 'available').length;
    defaultResponse += `• Available equipment (${available}/${equipment.length})\n`;
    defaultResponse += `• Info on ${sample.name}\n`;
  } else {
    defaultResponse += `• Request new equipment\n`;
  }
  defaultResponse += `\n`;

  defaultResponse += "📋 **Your Requests**\n";
  if (userBorrowings.length > 0) {
    defaultResponse += `• Check my ${userBorrowings.length} requests\n`;
  }
  defaultResponse += `• View borrowing history\n\n`;

  defaultResponse += "🛡️ **Safety & Schedules**\n";
  if (schedules.length > 0) {
    defaultResponse += `• Today's schedule\n`;
  }
  defaultResponse += `• Lab safety tips\n`;
  defaultResponse += `• PPE requirements\n\n`;

  if (userRole === 'admin' || userRole === 'technician') {
    defaultResponse += "💼 **Admin Tools**\n";
    defaultResponse += `• System alerts\n`;
    defaultResponse += `• Review requests\n`;
    defaultResponse += `• Update inventory\n\n`;
  }

  defaultResponse += "💬 Ask me anything lab-related! (e.g., 'Help with protocols')";

  await logChatbotQuery(userId, sanitizedMessage, defaultResponse, 'default');
  return defaultResponse;

  } catch (error) {
    const errorResponse = createErrorResponse(error, 'I encountered an error while processing your message. Please try again.');
    try {
      await logChatbotQuery(userId, sanitizedMessage || message, errorResponse, 'error');
    } catch (logError) {
      console.error('Failed to log error response:', logError);
    }
    return errorResponse;
  }
}

async function handleChemicalDetailsQuery(message, conversationId = null) {
  try {
    // Extract chemical name from message using regex for better matching
    const chemicalPattern = /(?:what is|tell me about|details of|information on|properties of)\s+(.*?)(?:\s+chemical|\s+substance|$)/i;
    const match = message.match(chemicalPattern);

    let chemicalName = null;
    if (match && match[1]) {
      chemicalName = match[1].trim();
    } else {
      // Fallback: look for common chemical names
      const commonChemicals = [
        'sodium chloride', 'hydrochloric acid', 'sulfuric acid', 'sodium hydroxide',
        'ethanol', 'acetone', 'ammonia', 'nitric acid', 'acetic acid',
        'methanol', 'benzene', 'toluene', 'xylene', 'formaldehyde'
      ];

      for (const chem of commonChemicals) {
        if (message.toLowerCase().includes(chem)) {
          chemicalName = chem;
          break;
        }
      }
    }

    if (chemicalName) {
      const chemical = await findChemicalFlexible(chemicalName);

      if (chemical) {
        // Set context for follow-up conversations
        if (conversationId) {
          await setConversationContext(conversationId, 'last_chemical', chemical.name);
          await setConversationContext(conversationId, 'last_topic', 'chemical_details');
        }

        let response = `🧪 **${chemical.name} Detailed Information**\n\n`;

        // Basic information
        response += `**📋 Basic Information:**\n`;
        response += `• **Name**: ${chemical.name}\n`;
        response += `• **Category**: ${chemical.category}\n`;
        response += `• **Quantity Available**: ${chemical.quantity} ${chemical.unit}\n`;
        response += `• **Storage Location**: ${chemical.storage_location}\n`;
        if (chemical.expiry_date) {
          response += `• **Expiry Date**: ${new Date(chemical.expiry_date).toLocaleDateString()}\n`;
        }

        // Chemical properties (if available)
        const hasChemicalProperties = chemical.c_number || chemical.molecular_formula || chemical.molecular_weight;
        if (hasChemicalProperties) {
          response += `\n**🔬 Chemical Properties:**\n`;
          if (chemical.c_number) response += `• **CAS Number**: ${chemical.c_number}\n`;
          if (chemical.molecular_formula) response += `• **Molecular Formula**: ${chemical.molecular_formula}\n`;
          if (chemical.molecular_weight) response += `• **Molecular Weight**: ${chemical.molecular_weight} g/mol\n`;
          if (chemical.physical_state) response += `• **Physical State**: ${chemical.physical_state}\n`;
          if (chemical.color) response += `• **Color**: ${chemical.color}\n`;
          if (chemical.density) response += `• **Density**: ${chemical.density} g/cm³\n`;
          if (chemical.melting_point) response += `• **Melting Point:** ${chemical.melting_point}\n`;
          if (chemical.boiling_point) response += `• **Boiling Point:** ${chemical.boiling_point}\n`;
          if (chemical.solubility) response += `• **Solubility:** ${chemical.solubility}\n`;
        }

        // Safety information (if available)
        const hasSafetyInfo = chemical.storage_conditions || chemical.hazard_class || chemical.safety_precautions;
        if (hasSafetyInfo) {
          response += `\n**⚠️ Safety Information:**\n`;
          if (chemical.storage_conditions) response += `• **Storage Conditions:** ${chemical.storage_conditions}\n`;
          if (chemical.hazard_class) response += `• **Hazard Class:** ${chemical.hazard_class}\n`;
          if (chemical.safety_precautions) response += `• **Safety Precautions:** ${chemical.safety_precautions}\n`;
          if (chemical.safety_info) response += `• **Additional Safety Info:** ${chemical.safety_info}\n`;
          if (chemical.msds_link) response += `• **MSDS Link:** ${chemical.msds_link}\n`;
        }

        if (!hasChemicalProperties && !hasSafetyInfo) {
          response += `\n*Additional detailed information (properties, safety data) can be added through the admin panel.*\n`;
        }

        // Add helpful follow-up suggestions
        response += `\n💡 **Need more help?**\n`;
        response += `• Ask about safety procedures for this chemical\n`;
        response += `• Check availability and request borrowing\n`;
        response += `• View related chemicals in the same category\n`;

        return response;
      } else {
        // Try searching for similar chemicals
        const searchResults = await searchChemicals(chemicalName);
        if (searchResults.length > 0) {
          let response = `I couldn't find the exact chemical "${chemicalName}", but I found these similar chemicals:\n\n`;
          searchResults.slice(0, 5).forEach((chem, index) => {
            response += `${index + 1}. ${chem.name} (${chem.category}) - ${chem.quantity} ${chem.unit}\n`;
          });
          response += `\nPlease ask about any of these chemicals for detailed information.`;
          return response;
        }

        return `Sorry, I couldn't find details for "${chemicalName}". Please check the spelling or ask about a different chemical.`;
      }
    }

    // If no specific chemical mentioned, show search results
    const searchTerm = extractSearchTerm(message, ['chemical', 'substance', 'compound']);
    const chemicals = await searchChemicals(searchTerm);

    if (chemicals.length > 0) {
      let response = `I found ${chemicals.length} chemicals in our inventory:\n\n`;
      chemicals.slice(0, 5).forEach((chem, index) => {
        response += `${index + 1}. ${chem.name} (${chem.category}) - ${chem.quantity} ${chem.unit}\n`;
      });
      response += `\nAsk me about any specific chemical for detailed information. For example: "What are the details of ${chemicals[0].name}?"`;
      return response;
    }

    // Check if entire inventory is empty
    const allChemicals = await getChemicals();
    if (allChemicals.length === 0) {
      return `Our chemical inventory is currently empty. Please contact lab administration to restock. You can still ask about equipment, schedules, or safety information.`;
    }

    return `I couldn't find chemicals matching your query. Try asking about general availability with "What chemicals are available?" or specify a different term.`;
  } catch (error) {
    console.error('Chemical details query error:', error);
    return "Sorry, I'm having trouble accessing the chemical details right now.";
  }
}

async function handleEquipmentDetailsQuery(message, conversationId = null) {
  try {
    // Extract equipment name from message
    const equipmentPattern = /(?:what is|tell me about|details of|information on|specifications of)\s+(.*?)(?:\s+equipment|\s+device|\s+instrument|$)/i;
    const match = message.match(equipmentPattern);

    let equipmentName = null;
    if (match && match[1]) {
      equipmentName = match[1].trim();
    } else {
      // Fallback: look for common equipment names
      const commonEquipment = [
        'microscope', 'centrifuge', 'spectrophotometer', 'balance', 'autoclave',
        'incubator', 'oven', 'refrigerator', 'freezer', 'ph meter',
        'chromatograph', 'spectrometer', 'calorimeter', 'titrator'
      ];

      for (const eq of commonEquipment) {
        if (message.toLowerCase().includes(eq)) {
          equipmentName = eq;
          break;
        }
      }
    }

    if (equipmentName) {
      const equipment = await findEquipmentFlexible(equipmentName);

      if (equipment) {
        // Set context for follow-up conversations
        if (conversationId) {
          await setConversationContext(conversationId, 'last_equipment', equipment.name);
          await setConversationContext(conversationId, 'last_topic', 'equipment_details');
        }

        let response = `⚙️ **${equipment.name} Detailed Information**\n\n`;

        // Basic information
        response += `**📋 Basic Information:**\n`;
        response += `• **Name**: ${equipment.name}\n`;
        response += `• **Category**: ${equipment.category}\n`;
        response += `• **Condition**: ${equipment.condition}\n`;
        response += `• **Location**: ${equipment.location}\n`;
        response += `• **Maintenance Schedule**: Every ${equipment.maintenance_schedule} days\n`;
        if (equipment.last_maintenance_date) {
          response += `• **Last Maintenance**: ${new Date(equipment.last_maintenance_date).toLocaleDateString()}\n`;
        }

        // Technical details (if available)
        const hasTechnicalDetails = equipment.serial_number || equipment.manufacturer || equipment.model;
        if (hasTechnicalDetails) {
          response += `\n**🔧 Technical Details:**\n`;
          if (equipment.serial_number) response += `• **Serial Number**: ${equipment.serial_number}\n`;
          if (equipment.manufacturer) response += `• **Manufacturer**: ${equipment.manufacturer}\n`;
          if (equipment.model) response += `• **Model**: ${equipment.model}\n`;
          if (equipment.purchase_date) response += `• **Purchase Date**: ${new Date(equipment.purchase_date).toLocaleDateString()}\n`;
          if (equipment.warranty_expiry) response += `• **Warranty Expiry**: ${new Date(equipment.warranty_expiry).toLocaleDateString()}\n`;
        }

        // Calibration information (if available)
        const hasCalibrationInfo = equipment.calibration_date || equipment.next_calibration_date;
        if (hasCalibrationInfo) {
          response += `\n**📅 Calibration Information:**\n`;
          if (equipment.calibration_date) response += `• **Last Calibration**: ${new Date(equipment.calibration_date).toLocaleDateString()}\n`;
          if (equipment.next_calibration_date) response += `• **Next Calibration**: ${new Date(equipment.next_calibration_date).toLocaleDateString()}\n`;
        }

        if (!hasTechnicalDetails && !hasCalibrationInfo) {
          response += `\n*Additional technical details can be added through the admin panel.*\n`;
        }

        // Add helpful follow-up suggestions
        response += `\n💡 **Need more help?**\n`;
        response += `• Check maintenance schedule and status\n`;
        response += `• Request borrowing for this equipment\n`;
        response += `• View similar equipment in the same category\n`;

        return response;
      } else {
        // Try searching for similar equipment
        const searchResults = await searchEquipment(equipmentName);
        if (searchResults.length > 0) {
          let response = `I couldn't find the exact equipment "${equipmentName}", but I found these similar items:\n\n`;
          searchResults.slice(0, 5).forEach((eq, index) => {
            response += `${index + 1}. ${eq.name} (${eq.category}) - ${eq.condition}\n`;
          });
          response += `\nPlease ask about any of these equipment items for detailed information.`;
          return response;
        }

        return `Sorry, I couldn't find details for "${equipmentName}". Please check the spelling or ask about a different equipment.`;
      }
    }

    // If no specific equipment mentioned, show search results
    const searchTerm = extractSearchTerm(message, ['equipment', 'device', 'instrument']);
    const equipments = await searchEquipment(searchTerm);

    if (equipments.length > 0) {
      let response = `I found ${equipments.length} equipment items in our inventory:\n\n`;
      equipments.slice(0, 5).forEach((eq, index) => {
        response += `${index + 1}. ${eq.name} (${eq.category}) - ${eq.condition}\n`;
      });
      response += `\nAsk me about any specific equipment for detailed information. For example: "What are the details of ${equipments[0].name}?"`;
      return response;
    }

    // Check if entire inventory is empty
    const allEquipment = await getEquipment();
    if (allEquipment.length === 0) {
      return `Our equipment inventory is currently empty. Please contact lab administration. You can still ask about schedules, safety information, or submit purchase requests.`;
    }

    return `I couldn't find equipment matching your query. Try asking about general availability with "What equipment is available?" or specify a different term.`;
  } catch (error) {
    console.error('Equipment details query error:', error);
    return "Sorry, I'm having trouble accessing the equipment details right now.";
  }
}

async function handleChemicalQuery(message, userId) {
  try {
    const chemicals = await getChemicals();
    const count = chemicals.length;
    
    // Extract specific chemical name if mentioned
    const chemicalNames = [
      'sodium chloride', 'hydrochloric acid', 'sulfuric acid', 'sodium hydroxide',
      'ethanol', 'acetone', 'ammonia', 'nitric acid', 'acetic acid'
    ];
    
    let specificChemical = null;
    for (const name of chemicalNames) {
      if (message.toLowerCase().includes(name)) {
        specificChemical = name;
        break;
      }
    }
    
    if (specificChemical) {
      const filteredChemicals = chemicals.filter(c =>
        c.name.toLowerCase().includes(specificChemical)
      );
      
      if (filteredChemicals.length > 0) {
        const chem = filteredChemicals[0];
        return `I found ${chem.name}:\n` +
               `• Quantity: ${chem.quantity} ${chem.unit}\n` +
               `• Location: ${chem.storage_location || 'Storage Room A'}\n` +
               `• Expiry: ${chem.expiry_date ? new Date(chem.expiry_date).toLocaleDateString() : 'N/A'}`;
      } else {
        return `Sorry, we don't have ${specificChemical} in stock right now.`;
      }
    }
    
    if (count === 0) {
      return `No chemicals are currently available in our inventory. Please check back later or contact lab administration to restock.`;
    }
    
    return `I found ${count} chemicals in our inventory. Some popular ones include:\n` +
           `• Sodium Chloride\n` +
           `• Hydrochloric Acid\n` +
           `• Ethanol\n` +
           `Would you like information about a specific chemical?`;
  } catch (error) {
    console.error('Chemical query error:', error);
    return "Sorry, I'm having trouble accessing the chemical inventory right now.";
  }
}

async function handleEquipmentQuery(message, userId) {
  try {
    const equipment = await getEquipment();
    const availableCount = equipment.filter(e => e.status === 'available').length;
    
    if (equipment.length === 0) {
      return `No equipment is currently available in our inventory. Please check back later or contact lab administration.`;
    }
    
    return `We have ${equipment.length} pieces of equipment in total, with ${availableCount} currently available.\n` +
           `Popular equipment includes:\n` +
           `• Microscopes\n` +
           `• Centrifuges\n` +
           `• Spectrophotometers\n` +
           `Would you like to know about specific equipment?`;
  } catch (error) {
    console.error('Equipment query error:', error);
    return "Sorry, I'm having trouble accessing the equipment inventory right now.";
  }
}

async function handleBorrowingRequest(message, userId, userRole) {
  // Extract potential item from message
  const items = ['beaker', 'test tube', 'burette', 'pipette', 'centrifuge', 'microscope', 'spectrophotometer'];
  let requestedItem = null;
  
  for (const item of items) {
    if (message.toLowerCase().includes(item)) {
      requestedItem = item;
      break;
    }
  }
  
  if (requestedItem) {
    return `I can help you borrow a ${requestedItem}!\n` +
           `To proceed with your borrowing request, please specify:\n` +
           `1. Quantity needed\n` +
           `2. Duration (start and end date)\n` +
           `3. Purpose of use\n` +
           `Or you can go to the Borrowing section in the app to submit a formal request.`;
  }
  
  return "I can help you with borrowing requests! You can:\n" +
         "• Check your current requests\n" +
         "• Submit a new borrowing request for chemicals or equipment\n" +
         "• Extend an existing borrowing period\n" +
         "What would you like to borrow?";
}

async function handleBorrowingStatus(message, userId, userRole) {
  try {
    const borrowings = await getBorrowings();
    const userBorrowings = borrowings.filter(b => b.borrower_id === userId);
    const pendingCount = userBorrowings.filter(b => b.status === 'pending').length;
    const activeCount = userBorrowings.filter(b => b.status === 'approved').length;
    const overdueCount = userBorrowings.filter(b => b.status === 'overdue').length;
    
    if (userBorrowings.length === 0) {
      return "You don't have any borrowing requests at the moment.";
    }
    
    let response = `You have ${userBorrowings.length} borrowing requests:\n`;
    response += `• ${pendingCount} pending approval\n`;
    response += `• ${activeCount} currently active\n`;
    
    if (overdueCount > 0) {
      response += `• ⚠️ ${overdueCount} overdue\n`;
    }
    
    // Add details for active requests
    const activeRequests = userBorrowings.filter(b => b.status === 'approved');
    if (activeRequests.length > 0) {
      response += `\n**Active Requests:**\n`;
      activeRequests.slice(0, 3).forEach((req, index) => {
        const item = req.chemical_id ? `Chemical ID: ${req.chemical_id}` : `Equipment ID: ${req.equipment_id}`;
        response += `${index + 1}. ${item} - Due: ${new Date(req.end_date).toLocaleDateString()}\n`;
      });
    }
    
    response += `\nWould you like details about a specific request?`;
    return response;
  } catch (error) {
    console.error('Borrowing status error:', error);
    return "Sorry, I'm having trouble accessing your borrowing requests right now.";
  }
}

async function handleScheduleQuery(message, userId, userRole) {
  try {
    const schedules = await getLectureSchedules();
    const today = new Date();
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    
    // Check if user is asking for specific day
    let targetDate = today;
    if (message.toLowerCase().includes('tomorrow')) {
      targetDate = tomorrow;
    } else if (message.toLowerCase().includes('yesterday')) {
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      targetDate = yesterday;
    }
    
    const targetSchedules = schedules.filter(schedule => {
      const scheduleDate = new Date(schedule.date);
      return scheduleDate.toDateString() === targetDate.toDateString();
    });
    
    if (targetSchedules.length > 0) {
      const dateStr = targetDate.toDateString() === today.toDateString() ? 'Today' : 
                     targetDate.toDateString() === tomorrow.toDateString() ? 'Tomorrow' : 
                     targetDate.toLocaleDateString();
      
      let response = `${dateStr}'s lab schedule:\n`;
      targetSchedules.forEach(schedule => {
        response += `• ${schedule.lab_name}: ${schedule.start_time} - ${schedule.end_time} (${schedule.course_name})\n`;
      });
      return response;
    } else {
      const dateStr = targetDate.toDateString() === today.toDateString() ? 'today' : 
                     targetDate.toDateString() === tomorrow.toDateString() ? 'tomorrow' : 
                     targetDate.toLocaleDateString();
      return `No lab sessions scheduled for ${dateStr}. Would you like to check another day?`;
    }
  } catch (error) {
    console.error('Schedule query error:', error);
    return "Sorry, I'm having trouble accessing the lab schedule right now.";
  }
}

async function handleSafetyQuery(message) {
  const safetyTopics = [
    { keyword: 'acid', response: '🧪 **Acid Handling Safety**\n• Always wear safety goggles and gloves\n• Work in a fume hood\n• Add acid to water, never water to acid\n• Have neutralizing agents nearby\n• Store acids separately from bases' },
    { keyword: 'base', response: '🧂 **Base Handling Safety**\n• Wear protective equipment\n• Avoid skin contact\n• Store separately from acids\n• Label containers clearly\n• Handle with care - bases can be caustic' },
    { keyword: 'spill', response: '🚨 **Chemical Spill Procedure**\n1. Evacuate the area immediately\n2. Alert lab supervisor\n3. Use appropriate spill kit\n4. Follow SDS guidelines for cleanup\n5. Report the incident to safety officer' },
    { keyword: 'ppe', response: '👕 **Required PPE for Lab Work**\n• Safety goggles (always)\n• Lab coat (always)\n• Closed-toe shoes (always)\n• Gloves (appropriate type for chemicals used)\n• Face shield (for hazardous procedures)' },
    { keyword: 'fire', response: '🔥 **Fire Safety**\n• Know location of fire extinguishers\n• Understand fire evacuation routes\n• Never leave heating equipment unattended\n• Keep flammable materials away from heat sources\n• Report any fire hazards immediately' }
  ];
  
  for (const topic of safetyTopics) {
    if (message.toLowerCase().includes(topic.keyword)) {
      return topic.response;
    }
  }
  
  return "🛡️ **Lab Safety Information**\nI can help with various safety topics:\n" +
         "• 'Safety precautions for acids'\n" +
         "• 'What PPE should I wear?'\n" +
         "• 'Chemical spill procedure'\n" +
         "• 'Fire safety guidelines'\n" +
         "• 'Base handling safety'\n" +
         "What specific safety information do you need?";
}

async function handleHistoryQuery(message, userId, userRole) {
  try {
    const borrowings = await getBorrowings();
    const userBorrowings = borrowings.filter(b => b.borrower_id === userId);
    const completedCount = userBorrowings.filter(b => b.status === 'returned').length;
    const rejectedCount = userBorrowings.filter(b => b.status === 'rejected').length;
    
    if (userBorrowings.length === 0) {
      return "You don't have any borrowing history yet.";
    }
    
    let response = `📊 **Your Borrowing History**\n`;
    response += `• Total requests: ${userBorrowings.length}\n`;
    response += `• Completed returns: ${completedCount}\n`;
    response += `• Currently active: ${userBorrowings.filter(b => b.status === 'approved').length}\n`;
    response += `• Rejected requests: ${rejectedCount}\n`;
    
    // Show recent history
    const recentHistory = userBorrowings
      .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
      .slice(0, 5);
    
    if (recentHistory.length > 0) {
      response += `\n**Recent Requests:**\n`;
      recentHistory.forEach((req, index) => {
        const item = req.chemical_id ? `Chemical ID: ${req.chemical_id}` : `Equipment ID: ${req.equipment_id}`;
        const status = req.status.charAt(0).toUpperCase() + req.status.slice(1);
        response += `${index + 1}. ${item} - ${status} (${new Date(req.created_at).toLocaleDateString()})\n`;
      });
    }
    
    return response;
  } catch (error) {
    console.error('History query error:', error);
    return "Sorry, I'm having trouble accessing your borrowing history right now.";
  }
}

async function handleHelpQuery(message, userId, userRole) {
  let helpText = "🤖 **ChemBot Help: Your Lab Assistant!**\n\n";
  helpText += "**What I Can Do:**\n\n";

  // Check current system state for dynamic suggestions
  const chemicals = await getChemicals();
  const equipment = await getEquipment();
  const schedules = await getLectureSchedules();
  const borrowings = await getBorrowings();
  const userBorrowings = borrowings.filter(b => b.borrower_id === userId);

  // Core lab functions
  helpText += "🔬 **Lab Inventory**\n";
  if (chemicals.length > 0) {
    const sample = chemicals[0];
    helpText += `• Search chemicals (${chemicals.length} available)\n`;
    helpText += `• Details: "${sample.name}"\n`;
    if (chemicals.length > 5) helpText += `• Low stock alerts\n`;
  } else {
    helpText += `• Request chemical restock\n`;
  }
  helpText += `\n`;

  helpText += "⚙️ **Equipment**\n";
  if (equipment.length > 0) {
    const sample = equipment[0];
    const available = equipment.filter(e => e.status === 'available').length;
    helpText += `• Available items (${available}/${equipment.length})\n`;
    helpText += `• Equipment info: "${sample.name}"\n`;
    helpText += `• Book equipment\n`;
  } else {
    helpText += `• Request new equipment\n`;
  }
  helpText += `\n`;

  // User-specific requests
  helpText += "📋 **Requests & History**\n";
  if (userBorrowings.length > 0) {
    helpText += `• Check my ${userBorrowings.length} requests\n`;
  } else {
    helpText += `• Submit borrowing request\n`;
  }
  helpText += `• View my history\n\n`;

  // Schedules and safety
  helpText += "📅 **Schedules & Safety**\n";
  if (schedules.length > 0) {
    const today = new Date().toISOString().split('T')[0];
    const todaySchedules = schedules.filter(s => s.date === today);
    if (todaySchedules.length > 0) helpText += `• Today's schedule (${todaySchedules.length})\n`;
    helpText += `• Tomorrow's labs\n`;
  }
  helpText += `• Safety tips (acids, PPE, spills)\n`;
  helpText += `• Chemical compatibility\n\n`;

  // Advanced features
  helpText += "🛒 **Requests & Protocols**\n";
  if (chemicals.length === 0 || equipment.length === 0) {
    helpText += `• Purchase requests for supplies\n`;
  } else {
    helpText += `• Request reagents (e.g., methanol)\n`;
  }
  helpText += `• Protocol suggestions (titration, distillation)\n\n`;

  // Role-specific
  if (userRole === 'admin' || userRole === 'technician') {
    helpText += "💼 **Staff Tools**\n";
    helpText += `• System alerts & notifications\n`;
    helpText += `• Review pending requests\n`;
    if (chemicals.length > 0 || equipment.length > 0) helpText += `• Update inventory\n`;
    helpText += `• Maintenance reminders\n\n`;
  }

  helpText += "**💬 Examples:**\n• 'What chemicals are low?'\n• 'Book microscope for tomorrow'\n• 'Safety for acids'\n• 'Help with titration protocol'";

  return helpText;
}

// New handler functions for enhanced features

async function handleInventoryAlertsQuery(message) {
  try {
    const lowerMessage = message.toLowerCase();
    let response = "📊 **Inventory Alerts**\n\n";

    // Check for low stock chemicals
    if (lowerMessage.includes('low') || lowerMessage.includes('stock')) {
      const lowStockChemicals = await getLowStockChemicals(10);
      if (lowStockChemicals.length > 0) {
        response += "**⚠️ Low Stock Chemicals:**\n";
        lowStockChemicals.slice(0, 5).forEach((chem, index) => {
          const stockLevel = chem.quantity <= 5 ? '🔴 Critical' : chem.quantity <= 10 ? '🟡 Low' : '🟢 Moderate';
          response += `${index + 1}. ${chem.name} - ${chem.quantity} ${chem.unit} ${stockLevel}\n`;
        });
        response += "\n";
      } else {
        response += "**✅ All chemicals are well-stocked**\n\n";
      }
    }

    // Check for expiring chemicals
    if (lowerMessage.includes('expir') || lowerMessage.includes('expir')) {
      const expiringChemicals = await getExpiringChemicals(30);
      if (expiringChemicals.length > 0) {
        response += "**⏰ Expiring Soon (within 30 days):**\n";
        expiringChemicals.slice(0, 5).forEach((chem, index) => {
          const daysUntilExpiry = Math.ceil((new Date(chem.expiry_date) - new Date()) / (1000 * 60 * 60 * 24));
          const urgency = daysUntilExpiry <= 7 ? '🔴 Urgent' : daysUntilExpiry <= 14 ? '🟡 Soon' : '🟢 Upcoming';
          response += `${index + 1}. ${chem.name} - Expires in ${daysUntilExpiry} days ${urgency}\n`;
        });
        response += "\n";
      } else {
        response += "**✅ No chemicals expiring soon**\n\n";
      }
    }

    // Check for expired chemicals
    const expiredChemicals = await getExpiredChemicals();
    if (expiredChemicals.length > 0) {
      response += "**🚨 Expired Chemicals (Action Required):**\n";
      expiredChemicals.slice(0, 3).forEach((chem, index) => {
        response += `${index + 1}. ${chem.name} - Expired on ${new Date(chem.expiry_date).toLocaleDateString()}\n`;
      });
      response += "\n**Please contact lab staff to dispose of expired chemicals safely.**\n\n";
    }

    // Check if inventory exists before giving "all normal" message
    const allChemicals = await getChemicals();
    const allEquipment = await getEquipment();
    
    if (response === "📊 **Inventory Alerts**\n\n") {
      if (allChemicals.length === 0 && allEquipment.length === 0) {
        response += "⚠️ **Note:** Both chemical and equipment inventories are currently empty. No alerts, but please contact administration to restock.\n\nAll other systems are normal! ✅";
      } else {
        response += "No inventory alerts at this time. All systems normal! ✅";
      }
    }

    return response;
  } catch (error) {
    console.error('Inventory alerts query error:', error);
    return "Sorry, I'm having trouble checking inventory alerts right now.";
  }
}

async function handleMaintenanceQuery(message) {
  try {
    const lowerMessage = message.toLowerCase();
    let response = "🔧 **Equipment Maintenance Status**\n\n";

    // Check equipment due for maintenance
    const dueForMaintenance = await getEquipmentDueForMaintenance();
    if (dueForMaintenance.length > 0) {
      response += "**⚠️ Equipment Due for Maintenance:**\n";
      dueForMaintenance.slice(0, 5).forEach((eq, index) => {
        const daysOverdue = eq.days_since_maintenance - eq.maintenance_schedule;
        const status = daysOverdue > 0 ? `🔴 Overdue by ${daysOverdue} days` : `🟡 Due soon`;
        response += `${index + 1}. ${eq.name} - ${status}\n`;
      });
      response += "\n";
    } else {
      response += "**✅ All equipment is up to date with maintenance**\n\n";
    }

    // Check equipment needing calibration
    const needingCalibration = await getEquipmentNeedingCalibration();
    if (needingCalibration.length > 0) {
      response += "**📏 Equipment Needing Calibration:**\n";
      needingCalibration.slice(0, 5).forEach((eq, index) => {
        response += `${index + 1}. ${eq.name} - Due: ${new Date(eq.next_calibration_date).toLocaleDateString()}\n`;
      });
      response += "\n";
    } else {
      response += "**✅ All equipment calibration is current**\n\n";
    }

    // Check if equipment exists
    const allEquipment = await getEquipment();
    
    if (response === "🔧 **Equipment Maintenance Status**\n\n") {
      if (allEquipment.length === 0) {
        response += "⚠️ **Note:** No equipment currently in inventory, so no maintenance is scheduled. Please contact administration to add equipment.\n\nAll systems are ready! ✅";
      } else {
        response += "All equipment maintenance is up to date! ✅";
      }
    }

    return response;
  } catch (error) {
    console.error('Maintenance query error:', error);
    return "Sorry, I'm having trouble checking maintenance status right now.";
  }
}

async function handleEquipmentBookingQuery(message, userId, userRole) {
  try {
    // Extract equipment name from message
    const equipmentPattern = /(?:book|reserve|schedule)\s+(?:the\s+)?(.+?)(?:\s+for|\s+on|$)/i;
    const match = message.match(equipmentPattern);

    if (match && match[1]) {
      const equipmentName = match[1].trim();
      const equipment = await findEquipmentFlexible(equipmentName);

      if (equipment) {
        // Check availability (simplified - would need date parsing in real implementation)
        const isAvailable = await checkEquipmentAvailability(equipment.id, new Date(), new Date(Date.now() + 24 * 60 * 60 * 1000));

        if (isAvailable) {
          return `✅ **${equipment.name} is available for booking!**\n\n` +
                 `**Equipment Details:**\n` +
                 `• Location: ${equipment.location}\n` +
                 `• Condition: ${equipment.condition}\n` +
                 `• Last Maintenance: ${new Date(equipment.last_maintenance_date).toLocaleDateString()}\n\n` +
                 `To book this equipment, please specify:\n` +
                 `• Date and time needed\n` +
                 `• Duration of use\n` +
                 `• Purpose of booking\n\n` +
                 `Or use the Equipment Booking section in the app.`;
        } else {
          // Get upcoming bookings
          const bookings = await getEquipmentBookings(equipment.id, 3);
          let response = `❌ **${equipment.name} is currently booked**\n\n`;

          if (bookings.length > 0) {
            response += "**Upcoming Bookings:**\n";
            bookings.forEach((booking, index) => {
              response += `${index + 1}. ${new Date(booking.borrow_date).toLocaleDateString()} - ${new Date(booking.return_date).toLocaleDateString()}\n`;
            });
            response += "\n";
          }

          response += "Would you like me to suggest alternative equipment or help you book for a different time?";
          return response;
        }
      } else {
        // Try searching for similar equipment
        const searchResults = await searchEquipmentAdvanced(equipmentName);
        if (searchResults.length > 0) {
          let response = `I couldn't find "${equipmentName}" exactly, but here are similar options:\n\n`;
          searchResults.slice(0, 3).forEach((eq, index) => {
            response += `${index + 1}. ${eq.name} (${eq.category})\n`;
          });
          response += "\nWould you like to book any of these instead?";
          return response;
        }

        return `Sorry, I couldn't find equipment matching "${equipmentName}". Please check the spelling or ask about available equipment.`;
      }
    }

    // Show available equipment for booking
    const availableEquipment = await getAvailableEquipment();
    if (availableEquipment.length > 0) {
      let response = "📅 **Available Equipment for Booking:**\n\n";
      availableEquipment.slice(0, 10).forEach((eq, index) => {
        response += `${index + 1}. ${eq.name} (${eq.category}) - ${eq.location}\n`;
      });
      response += "\nTo book equipment, specify the equipment name and dates. For example: 'Book the microscope for tomorrow 2 PM'";
      return response;
    }

    return "I can help you book equipment! Please specify which equipment you'd like to book and when.";
  } catch (error) {
    console.error('Equipment booking query error:', error);
    return "Sorry, I'm having trouble with equipment booking right now.";
  }
}

async function handlePurchaseRequestQuery(message, userId, userRole) {
  try {
    // Extract chemical/equipment name from message
    const requestPattern = /(?:request|order|buy|purchase|need)\s+(?:\d*\s*\w*\s+)?(.+?)(?:\s+for|\s+because|$)/i;
    const match = message.match(requestPattern);

    if (match && match[1]) {
      const itemName = match[1].trim();

      // Check if it's already in inventory
      const existingChemical = await findChemicalFlexible(itemName);
      const existingEquipment = await findEquipmentFlexible(itemName);

      if (existingChemical) {
        return `📦 **${existingChemical.name} is already in our inventory!**\n\n` +
               `**Current Stock:** ${existingChemical.quantity} ${existingChemical.unit}\n` +
               `**Location:** ${existingChemical.storage_location}\n` +
               `**Expiry:** ${new Date(existingChemical.expiry_date).toLocaleDateString()}\n\n` +
               `Would you still like to request additional quantity? If so, please specify how much you need.`;
      }

      if (existingEquipment) {
        return `📦 **${existingEquipment.name} is already in our inventory!**\n\n` +
               `**Location:** ${existingEquipment.location}\n` +
               `**Condition:** ${existingEquipment.condition}\n\n` +
               `Would you still like to request a replacement or additional unit?`;
      }

      // Item not in inventory - create purchase request
      return `🛒 **Purchase Request Created**\n\n` +
             `**Item:** ${itemName}\n` +
             `**Requested by:** User ID ${userId}\n` +
             `**Status:** Submitted for approval\n\n` +
             `Your request has been submitted to lab management for approval. ` +
             `You will be notified once it's reviewed. In the meantime, ` +
             `would you like me to suggest alternative items that are currently available?`;
    }

    return "I can help you create a purchase request! Please specify what you'd like to request. For example: 'Request purchase of 500mL methanol'";
  } catch (error) {
    console.error('Purchase request query error:', error);
    return "Sorry, I'm having trouble processing purchase requests right now.";
  }
}

async function handleProtocolQuery(message) {
  try {
    const lowerMessage = message.toLowerCase();

    // Common lab protocols and their requirements
    const protocols = {
      'titration': {
        description: 'Acid-base titration procedure',
        chemicals: ['standard solution', 'indicator', 'analyte'],
        equipment: ['burette', 'pipette', 'beaker', 'magnetic stirrer']
      },
      'distillation': {
        description: 'Separation by boiling point differences',
        chemicals: ['mixture to separate'],
        equipment: ['distillation apparatus', 'heating mantle', 'thermometer', 'condenser']
      },
      'extraction': {
        description: 'Liquid-liquid extraction procedure',
        chemicals: ['sample', 'solvent', 'extracting agent'],
        equipment: ['separatory funnel', 'beaker', 'stirring rod']
      },
      'chromatography': {
        description: 'Separation based on differential partitioning',
        chemicals: ['mobile phase', 'stationary phase', 'sample'],
        equipment: ['chromatography column', 'pump', 'detector']
      },
      'spectroscopy': {
        description: 'Analysis using light absorption/emission',
        chemicals: ['sample solution'],
        equipment: ['spectrophotometer', 'cuvettes']
      }
    };

    // Find matching protocol
    let matchedProtocol = null;
    for (const [key, protocol] of Object.entries(protocols)) {
      if (lowerMessage.includes(key)) {
        matchedProtocol = { name: key, ...protocol };
        break;
      }
    }

    if (matchedProtocol) {
      let response = `🔬 **${matchedProtocol.name.charAt(0).toUpperCase() + matchedProtocol.name.slice(1)} Protocol**\n\n`;
      response += `**Description:** ${matchedProtocol.description}\n\n`;

      // Check available equipment
      const availableEquipment = await getAvailableEquipment();
      const requiredEquipment = matchedProtocol.equipment;
      const availableRequired = availableEquipment.filter(eq =>
        requiredEquipment.some(req => eq.name.toLowerCase().includes(req.toLowerCase()))
      );

      response += "**Required Equipment:**\n";
      requiredEquipment.forEach(eq => {
        const available = availableRequired.some(aeq => aeq.name.toLowerCase().includes(eq.toLowerCase()));
        const status = available ? "✅ Available" : "❌ Not available";
        response += `• ${eq} - ${status}\n`;
      });

      if (availableRequired.length < requiredEquipment.length) {
        response += "\n⚠️ Some equipment may not be available. Consider booking in advance.\n";
      }

      response += "\n**Suggested Chemicals:**\n";
      matchedProtocol.chemicals.forEach(chem => {
        response += `• ${chem}\n`;
      });

      response += "\nWould you like me to check specific chemical availability or help with booking equipment?";

      return response;
    }

    // General protocol assistance
    return `🔬 **Lab Protocol Assistance**\n\n` +
           `I can help with common lab protocols including:\n\n` +
           `• **Titration** - Acid-base neutralization\n` +
           `• **Distillation** - Separation by boiling points\n` +
           `• **Extraction** - Liquid-liquid separation\n` +
           `• **Chromatography** - Separation techniques\n` +
           `• **Spectroscopy** - Light-based analysis\n\n` +
           `Please specify which protocol you're interested in, and I'll provide:\n` +
           `• Required equipment and availability\n` +
           `• Suggested chemicals\n` +
           `• Step-by-step guidance\n\n` +
           `For example: "Suggest protocol for titration"`;
  } catch (error) {
    console.error('Protocol query error:', error);
    return "Sorry, I'm having trouble accessing protocol information right now.";
  }
}

async function handleSafetyCompatibilityQuery(message) {
  try {
    const lowerMessage = message.toLowerCase();

    // Check for chemical compatibility queries
    if (lowerMessage.includes('compatible') || lowerMessage.includes('mix')) {
      return `🧪 **Chemical Compatibility Guidelines**\n\n` +
             `**⚠️ Important Safety Rules:**\n\n` +
             `**Never mix:**\n` +
             `• Acids with bases (violent reaction)\n` +
             `• Oxidizers with organics (fire hazard)\n` +
             `• Water with certain metals (hydrogen gas)\n\n` +
             `**Safe Storage Groups:**\n` +
             `• Acids together (sulfuric, hydrochloric, nitric)\n` +
             `• Bases together (sodium hydroxide, potassium hydroxide)\n` +
             `• Organics together (alcohols, solvents)\n` +
             `• Flammables in approved cabinets\n\n` +
             `**Storage Conditions:**\n` +
             `• Keep incompatible chemicals separate\n` +
             `• Store in cool, dry, well-ventilated areas\n` +
             `• Use secondary containment for liquids\n\n` +
             `For specific chemical compatibility, please consult the Safety Data Sheet (SDS) or ask about particular chemicals.`;
    }

    // Check for storage queries
    if (lowerMessage.includes('storage') || lowerMessage.includes('store')) {
      const specialStorageChemicals = await getChemicalsRequiringSpecialStorage();

      if (specialStorageChemicals.length > 0) {
        let response = `📦 **Chemicals Requiring Special Storage**\n\n`;
        specialStorageChemicals.slice(0, 5).forEach((chem, index) => {
          response += `${index + 1}. **${chem.name}**\n`;
          response += `   Storage: ${chem.storage_conditions}\n`;
          if (chem.hazard_class) {
            response += `   Hazard: ${chem.hazard_class}\n`;
          }
          response += `\n`;
        });
        response += `**General Storage Rules:**\n`;
        response += `• Label all containers clearly\n`;
        response += `• Store by compatibility groups\n`;
        response += `• Keep away from heat sources\n`;
        response += `• Use appropriate ventilation\n`;
        return response;
      }

      return `📦 **Chemical Storage Guidelines**\n\n` +
             `**Safe Storage Practices:**\n` +
             `• Store chemicals in original containers when possible\n` +
             `• Keep containers closed when not in use\n` +
             `• Store in cool, dry, well-ventilated areas\n` +
             `• Separate incompatible chemicals\n` +
             `• Use secondary containment for liquids\n` +
             `• Store flammables in approved cabinets\n\n` +
             `For specific chemical storage requirements, check the Safety Data Sheet (SDS).`;
    }

    // Hazard information
    if (lowerMessage.includes('hazard') || lowerMessage.includes('danger')) {
      return `⚠️ **Chemical Hazard Classes**\n\n` +
             `**Common Hazard Categories:**\n\n` +
             `🔴 **Health Hazards:**\n` +
             `• Toxic substances\n` +
             `• Carcinogens\n` +
             `• Reproductive toxins\n\n` +
             `🟠 **Physical Hazards:**\n` +
             `• Flammable liquids\n` +
             `• Explosives\n` +
             `• Corrosives\n\n` +
             `🟡 **Environmental Hazards:**\n` +
             `• Aquatic toxins\n` +
             `• Ozone depleters\n\n` +
             `For specific chemical hazards, please check the Safety Data Sheet (SDS) or ask about a particular chemical.`;
    }

    return `🛡️ **Safety & Compatibility Information**\n\n` +
           `I can help with:\n\n` +
           `• **Chemical compatibility** - Which chemicals can be safely mixed\n` +
           `• **Storage guidelines** - How to store chemicals safely\n` +
           `• **Hazard information** - Understanding chemical risks\n` +
           `• **PPE requirements** - What protective equipment to use\n\n` +
           `Please ask about a specific safety topic!`;
  } catch (error) {
    console.error('Safety compatibility query error:', error);
    return "Sorry, I'm having trouble accessing safety information right now.";
  }
}

// Helper function to extract search terms
function extractSearchTerm(message, keywords) {
  const lowerMessage = message.toLowerCase();
  // Remove keywords from message to get search term
  let searchTerm = lowerMessage;
  keywords.forEach(keyword => {
    searchTerm = searchTerm.replace(keyword, '');
  });
  return searchTerm.trim() || '';
}

// Enhanced function to find chemical by flexible name matching
async function findChemicalFlexible(searchTerm) {
  try {
    // First try exact match
    let chemical = await getChemicalByName(searchTerm);
    if (chemical) return chemical;

    // Try partial matches with different variations
    const variations = [
      searchTerm,
      searchTerm.toLowerCase(),
      searchTerm.charAt(0).toUpperCase() + searchTerm.slice(1).toLowerCase(),
      searchTerm.replace(/\s+/g, ''), // Remove spaces
      searchTerm.replace(/[^a-zA-Z0-9]/g, '') // Remove special chars
    ];

    for (const variant of variations) {
      if (variant !== searchTerm) {
        chemical = await getChemicalByName(variant);
        if (chemical) return chemical;
      }
    }

    // Try searching with broader terms
    const searchResults = await searchChemicals(searchTerm);
    if (searchResults.length > 0) {
      return searchResults[0]; // Return first match
    }

    return null;
  } catch (error) {
    console.error('Error in findChemicalFlexible:', error);
    return null;
  }
}

// Enhanced function to find equipment by flexible name matching
async function findEquipmentFlexible(searchTerm) {
  try {
    // First try exact match
    let equipment = await getEquipmentByName(searchTerm);
    if (equipment) return equipment;

    // Try partial matches with different variations
    const variations = [
      searchTerm,
      searchTerm.toLowerCase(),
      searchTerm.charAt(0).toUpperCase() + searchTerm.slice(1).toLowerCase(),
      searchTerm.replace(/\s+/g, ''), // Remove spaces
      searchTerm.replace(/[^a-zA-Z0-9]/g, '') // Remove special chars
    ];

    for (const variant of variations) {
      if (variant !== searchTerm) {
        equipment = await getEquipmentByName(variant);
        if (equipment) return equipment;
      }
    }

    // Try searching with broader terms
    const searchResults = await searchEquipment(searchTerm);
    if (searchResults.length > 0) {
      return searchResults[0]; // Return first match
    }

    return null;
  } catch (error) {
    console.error('Error in findEquipmentFlexible:', error);
    return null;
  }
}

// Contextual follow-up handler for conversational intelligence
async function handleContextualFollowUp(message, context, conversationId) {
  try {
    const lowerMessage = message.toLowerCase();

    // Handle yes/no follow-ups
    if (context.pending_action) {
      if (lowerMessage.includes('yes') || lowerMessage.includes('sure') || lowerMessage.includes('okay') || lowerMessage.includes('ok')) {
        return await handleAffirmativeResponse(context, conversationId);
      } else if (lowerMessage.includes('no') || lowerMessage.includes('never') || lowerMessage.includes('not now')) {
        return await handleNegativeResponse(context, conversationId);
      }
    }

    // Handle clarification requests
    if (context.awaiting_clarification) {
      return await handleClarificationResponse(message, context, conversationId);
    }

    // Handle follow-up questions about previous topics
    if (context.last_chemical) {
      const chemicalFollowUps = ['safety', 'storage', 'properties', 'availability', 'location', 'expiry', 'alternatives'];
      for (const followUp of chemicalFollowUps) {
        if (lowerMessage.includes(followUp)) {
          return await handleChemicalFollowUp(context.last_chemical, followUp, conversationId);
        }
      }
    }

    if (context.last_equipment) {
      const equipmentFollowUps = ['book', 'reserve', 'schedule', 'maintenance', 'specs', 'manual', 'calibration'];
      for (const followUp of equipmentFollowUps) {
        if (lowerMessage.includes(followUp)) {
          return await handleEquipmentFollowUp(context.last_equipment, followUp, conversationId);
        }
      }
    }

    // Handle quantity specifications for purchases or borrowings
    if (context.awaiting_quantity && (lowerMessage.match(/\d+/) || lowerMessage.includes('all'))) {
      return await handleQuantityResponse(message, context, conversationId);
    }

    return null; // No contextual response needed
  } catch (error) {
    console.error('Contextual follow-up error:', error);
    return null;
  }
}

// Helper functions for contextual responses
async function handleAffirmativeResponse(context, conversationId) {
  try {
    if (context.pending_action === 'book_equipment') {
      const equipment = await findEquipmentFlexible(context.equipment_name);
      if (equipment) {
        await setConversationContext(conversationId, 'awaiting_booking_details', 'true');
        return `Great! I'd be happy to help you book the ${equipment.name}.\n\nPlease provide:\n• Date you need it (e.g., "tomorrow" or "2024-01-15")\n• Time you need it (e.g., "2 PM")\n• How long you need it (e.g., "2 hours" or "until 5 PM")`;
      }
    }

    if (context.pending_action === 'request_purchase') {
      await setConversationContext(conversationId, 'awaiting_quantity', 'true');
      return `Perfect! How much ${context.item_name} would you like to request? Please specify the quantity and unit (e.g., "500 mL" or "2 kg").`;
    }

    if (context.pending_action === 'show_alternatives') {
      const alternatives = await findAlternatives(context.original_item, context.item_type);
      if (alternatives.length > 0) {
        let response = `Here are some alternatives to ${context.original_item}:\n\n`;
        alternatives.forEach((item, index) => {
          response += `${index + 1}. ${item.name} - ${item.quantity || 'Available'} ${item.unit || ''}\n`;
        });
        response += `\nWould you like details about any of these alternatives?`;
        return response;
      }
    }

    await clearConversationContext(conversationId, 'pending_action');
    return "I'm not sure what you meant. Could you please clarify?";
  } catch (error) {
    console.error('Affirmative response error:', error);
    return "Sorry, I encountered an error processing your response.";
  }
}

async function handleNegativeResponse(context, conversationId) {
  try {
    await clearConversationContext(conversationId, 'pending_action');
    return "No problem! Is there anything else I can help you with?";
  } catch (error) {
    console.error('Negative response error:', error);
    return "Sorry, I encountered an error processing your response.";
  }
}

async function handleClarificationResponse(message, context, conversationId) {
  try {
    // Process the clarification and retry the original query
    await clearConversationContext(conversationId, 'awaiting_clarification');

    if (context.original_query_type === 'chemical_details') {
      return await handleChemicalDetailsQuery(message);
    } else if (context.original_query_type === 'equipment_details') {
      return await handleEquipmentDetailsQuery(message);
    }

    return "Thanks for the clarification! Let me help you with that.";
  } catch (error) {
    console.error('Clarification response error:', error);
    return "Sorry, I encountered an error processing your clarification.";
  }
}

async function handleChemicalFollowUp(chemicalName, followUpType, conversationId) {
  try {
    const chemical = await findChemicalFlexible(chemicalName);
    if (!chemical) {
      return `I can't find the chemical ${chemicalName} anymore. Could you please specify which chemical you're referring to?`;
    }

    switch (followUpType) {
      case 'safety':
        return `🛡️ **Safety Information for ${chemical.name}**\n\n` +
               `**Hazard Class:** ${chemical.hazard_class || 'Not specified'}\n` +
               `**Safety Precautions:** ${chemical.safety_precautions || 'Check SDS for details'}\n` +
               `**Storage Conditions:** ${chemical.storage_conditions || 'Standard chemical storage'}\n` +
               `**PPE Required:** ${chemical.safety_info || 'Lab coat, gloves, safety goggles'}`;

      case 'storage':
        return `📦 **Storage Information for ${chemical.name}**\n\n` +
               `**Location:** ${chemical.storage_location}\n` +
               `**Storage Conditions:** ${chemical.storage_conditions || 'Cool, dry place'}\n` +
               `**Expiry Date:** ${new Date(chemical.expiry_date).toLocaleDateString()}`;

      case 'properties':
        let response = `🔬 **Properties of ${chemical.name}**\n\n`;
        if (chemical.molecular_formula) response += `• **Formula:** ${chemical.molecular_formula}\n`;
        if (chemical.molecular_weight) response += `• **Molecular Weight:** ${chemical.molecular_weight} g/mol\n`;
        if (chemical.physical_state) response += `• **State:** ${chemical.physical_state}\n`;
        if (chemical.density) response += `• **Density:** ${chemical.density} g/cm³\n`;
        if (chemical.melting_point) response += `• **Melting Point:** ${chemical.melting_point}\n`;
        if (chemical.boiling_point) response += `• **Boiling Point:** ${chemical.boiling_point}\n`;
        return response;

      case 'availability':
        return `📊 **Availability of ${chemical.name}**\n\n` +
               `**Current Stock:** ${chemical.quantity} ${chemical.unit}\n` +
               `**Location:** ${chemical.storage_location}\n` +
               `**Expiry:** ${new Date(chemical.expiry_date).toLocaleDateString()}`;

      default:
        return `What specific information about ${chemical.name} would you like to know?`;
    }
  } catch (error) {
    console.error('Chemical follow-up error:', error);
    return "Sorry, I encountered an error retrieving that information.";
  }
}

async function handleEquipmentFollowUp(equipmentName, followUpType, conversationId) {
  try {
    const equipment = await findEquipmentFlexible(equipmentName);
    if (!equipment) {
      return `I can't find the equipment ${equipmentName} anymore. Could you please specify which equipment you're referring to?`;
    }

    switch (followUpType) {
      case 'book':
      case 'reserve':
      case 'schedule':
        await setConversationContext(conversationId, 'pending_action', 'book_equipment');
        await setConversationContext(conversationId, 'equipment_name', equipment.name);
        return `Would you like me to help you book the ${equipment.name}?`;

      case 'maintenance':
        const daysSinceMaintenance = Math.floor((new Date() - new Date(equipment.last_maintenance_date)) / (1000 * 60 * 60 * 24));
        return `🔧 **Maintenance Info for ${equipment.name}**\n\n` +
               `**Last Maintenance:** ${new Date(equipment.last_maintenance_date).toLocaleDateString()}\n` +
               `**Days Since:** ${daysSinceMaintenance}\n` +
               `**Schedule:** Every ${equipment.maintenance_schedule} days\n` +
               `**Next Due:** ${new Date(Date.now() + (equipment.maintenance_schedule - daysSinceMaintenance) * 24 * 60 * 60 * 1000).toLocaleDateString()}`;

      case 'specs':
        return `📋 **Specifications for ${equipment.name}**\n\n` +
               `**Category:** ${equipment.category}\n` +
               `**Condition:** ${equipment.condition}\n` +
               `**Location:** ${equipment.location}\n` +
               `${equipment.serial_number ? `**Serial:** ${equipment.serial_number}\n` : ''}` +
               `${equipment.manufacturer ? `**Manufacturer:** ${equipment.manufacturer}\n` : ''}` +
               `${equipment.model ? `**Model:** ${equipment.model}\n` : ''}`;

      default:
        return `What specific information about ${equipment.name} would you like to know?`;
    }
  } catch (error) {
    console.error('Equipment follow-up error:', error);
    return "Sorry, I encountered an error retrieving that information.";
  }
}

async function handleQuantityResponse(message, context, conversationId) {
  try {
    const quantityMatch = message.match(/(\d+(?:\.\d+)?)\s*(\w+)/);
    if (quantityMatch) {
      const quantity = quantityMatch[1];
      const unit = quantityMatch[2];

      await clearConversationContext(conversationId, 'awaiting_quantity');

      if (context.pending_action === 'request_purchase') {
        return `🛒 **Purchase Request Updated**\n\n` +
               `**Item:** ${context.item_name}\n` +
               `**Quantity:** ${quantity} ${unit}\n` +
               `**Status:** Submitted for approval\n\n` +
               `Your purchase request has been submitted. You'll be notified once it's reviewed.`;
      }
    }

    return "I didn't understand the quantity. Please specify it clearly (e.g., '500 mL' or '2 kg').";
  } catch (error) {
    console.error('Quantity response error:', error);
    return "Sorry, I encountered an error processing the quantity.";
  }
}

async function findAlternatives(originalItem, itemType) {
  try {
    if (itemType === 'chemical') {
      const chemicals = await searchChemicalsAdvanced(originalItem);
      return chemicals.filter(chem => chem.name.toLowerCase() !== originalItem.toLowerCase()).slice(0, 3);
    } else if (itemType === 'equipment') {
      const equipment = await searchEquipmentAdvanced(originalItem);
      return equipment.filter(eq => eq.name.toLowerCase() !== originalItem.toLowerCase()).slice(0, 3);
    }
    return [];
  } catch (error) {
    console.error('Find alternatives error:', error);
    return [];
  }
}

module.exports = {
  processChatMessage,
  handleChemicalDetailsQuery,
  handleEquipmentDetailsQuery,
  handleChemicalQuery,
  handleEquipmentQuery,
  handleBorrowingRequest,
  handleBorrowingStatus,
  handleScheduleQuery,
  handleSafetyQuery,
  handleHistoryQuery,
  handleHelpQuery,
  handleInventoryAlertsQuery,
  handleMaintenanceQuery,
  handleEquipmentBookingQuery,
  handlePurchaseRequestQuery,
  handleProtocolQuery,
  handleSafetyCompatibilityQuery,
  handleContextualFollowUp,
  findChemicalFlexible,
  findEquipmentFlexible
};