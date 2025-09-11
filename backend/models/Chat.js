const db = require('../config/db');

class Chat {
  // Create a new conversation between technician and borrower
  static async createConversation(technicianId, borrowerId) {
    console.log('=== CHAT MODEL: CREATE CONVERSATION ===');
    console.log('Technician ID:', technicianId);
    console.log('Borrower ID:', borrowerId);
    
    try {
      // Check if conversation already exists
      const existing = await db.query(
        `SELECT id FROM conversations 
         WHERE (technician_id = $1 AND borrower_id = $2) 
         OR (technician_id = $2 AND borrower_id = $1)`,
        [technicianId, borrowerId]
      );
      
      if (existing.rows.length > 0) {
        console.log('Conversation already exists:', existing.rows[0].id);
        return existing.rows[0];
      }
      
      // Create new conversation
      const result = await db.query(
        `INSERT INTO conversations (technician_id, borrower_id, created_at) 
         VALUES ($1, $2, NOW()) 
         RETURNING *`,
        [technicianId, borrowerId]
      );
      
      console.log('New conversation created:', result.rows[0].id);
      return result.rows[0];
    } catch (error) {
      console.error('Error creating conversation:', error);
      throw new Error('Failed to create conversation');
    }
  }

  // Send a message in a conversation
  static async sendMessage(conversationId, senderId, message, messageType = 'text') {
    console.log('=== CHAT MODEL: SEND MESSAGE ===');
    console.log('Conversation ID:', conversationId);
    console.log('Sender ID:', senderId);
    console.log('Message length:', message.length);
    
    try {
      const result = await db.query(
        `INSERT INTO messages (conversation_id, sender_id, message, message_type, created_at) 
         VALUES ($1, $2, $3, $4, NOW()) 
         RETURNING *`,
        [conversationId, senderId, message, messageType]
      );
      
      console.log('Message sent:', result.rows[0].id);
      return result.rows[0];
    } catch (error) {
      console.error('Error sending message:', error);
      throw new Error('Failed to send message');
    }
  }

  // Get all conversations for a user (technician or borrower)
  static async getConversations(userId, userRole) {
    console.log('=== CHAT MODEL: GET CONVERSATIONS ===');
    console.log('User ID:', userId);
    console.log('User Role:', userRole);
    
    try {
      let query;
      if (userRole === 'technician') {
        query = `
          SELECT DISTINCT ON (c.id) 
            c.id, c.created_at,
            b.id as other_user_id, b.name as other_user_name, b.email as other_user_email,
            b.student_id as other_user_student_id,
            m.message as last_message,
            m.created_at as last_message_time,
            CASE 
              WHEN m.sender_id = $1 THEN 'sent'
              ELSE 'received'
            END as message_direction
          FROM conversations c
          JOIN users b ON c.borrower_id = b.id
          LEFT JOIN messages m ON c.id = m.conversation_id
          WHERE c.technician_id = $1
          ORDER BY c.id, m.created_at DESC
        `;
      } else if (userRole === 'borrower') {
        query = `
          SELECT DISTINCT ON (c.id) 
            c.id, c.created_at,
            t.id as other_user_id, t.name as other_user_name, t.email as other_user_email,
            m.message as last_message,
            m.created_at as last_message_time,
            CASE 
              WHEN m.sender_id = $1 THEN 'sent'
              ELSE 'received'
            END as message_direction
          FROM conversations c
          JOIN users t ON c.technician_id = t.id
          LEFT JOIN messages m ON c.id = m.conversation_id
          WHERE c.borrower_id = $1
          ORDER BY c.id, m.created_at DESC
        `;
      } else {
        throw new Error('Invalid user role for conversations');
      }
      
      const result = await db.query(query, [userId]);
      
      // Format the results
      const conversations = result.rows.map(conv => ({
        id: conv.id,
        createdAt: conv.created_at,
        otherUser: {
          id: conv.other_user_id,
          name: conv.other_user_name,
          email: conv.other_user_email,
          studentId: conv.other_user_student_id
        },
        lastMessage: conv.last_message,
        lastMessageTime: conv.last_message_time,
        messageDirection: conv.message_direction,
        unreadCount: 0 // This would need to be calculated separately
      }));
      
      console.log(`Found ${conversations.length} conversations`);
      return conversations;
    } catch (error) {
      console.error('Error getting conversations:', error);
      throw new Error('Failed to get conversations');
    }
  }

  // Get messages for a specific conversation
  static async getMessages(conversationId, limit = 50, offset = 0) {
    console.log('=== CHAT MODEL: GET MESSAGES ===');
    console.log('Conversation ID:', conversationId);
    console.log('Limit:', limit, 'Offset:', offset);
    
    try {
      const result = await db.query(
        `SELECT 
           m.id, m.conversation_id, m.sender_id, m.message, m.message_type,
           m.created_at, u.name as sender_name
         FROM messages m
         JOIN users u ON m.sender_id = u.id
         WHERE m.conversation_id = $1
         ORDER BY m.created_at ASC
         LIMIT $2 OFFSET $3`,
        [conversationId, limit, offset]
      );
      
      console.log(`Found ${result.rows.length} messages`);
      return result.rows;
    } catch (error) {
      console.error('Error getting messages:', error);
      throw new Error('Failed to get messages');
    }
  }

  // Get unread message count for a user in a conversation
  static async getUnreadCount(conversationId, userId) {
    console.log('=== CHAT MODEL: GET UNREAD COUNT ===');
    console.log('Conversation ID:', conversationId);
    console.log('User ID:', userId);
    
    try {
      // This is a simplified version - in a real app you'd track read receipts
      const result = await db.query(
        `SELECT COUNT(*) as count
         FROM messages m
         WHERE m.conversation_id = $1 
         AND m.sender_id != $2
         AND m.created_at > (
           SELECT COALESCE(MAX(created_at), '1970-01-01'::timestamp) 
           FROM message_reads 
           WHERE conversation_id = $1 AND user_id = $2
         )`,
        [conversationId, userId]
      );
      
      return parseInt(result.rows[0].count);
    } catch (error) {
      console.error('Error getting unread count:', error);
      return 0;
    }
  }

  // Mark messages as read (for real-time chat)
  static async markAsRead(conversationId, userId) {
    console.log('=== CHAT MODEL: MARK AS READ ===');
    console.log('Conversation ID:', conversationId);
    console.log('User ID:', userId);
    
    try {
      const result = await db.query(
        `INSERT INTO message_reads (conversation_id, user_id, created_at)
         VALUES ($1, $2, NOW())
         ON CONFLICT (conversation_id, user_id) 
         DO UPDATE SET created_at = NOW()
         RETURNING *`,
        [conversationId, userId]
      );
      
      console.log('Messages marked as read');
      return result.rows[0];
    } catch (error) {
      console.error('Error marking as read:', error);
      throw new Error('Failed to mark messages as read');
    }
  }

  // Get user details for chat (sanitized)
  static async getChatUser(userId) {
    console.log('=== CHAT MODEL: GET CHAT USER ===');
    console.log('User ID:', userId);
    
    try {
      const result = await db.query(
        `SELECT id, name, email, phone, student_id, role 
         FROM users 
         WHERE id = $1`,
        [userId]
      );
      
      if (result.rows.length === 0) {
        throw new Error('User not found');
      }
      
      return result.rows[0];
    } catch (error) {
      console.error('Error getting chat user:', error);
      throw new Error('Failed to get user details');
    }
  }
}

module.exports = Chat;