// websocket_server.js
const WebSocket = require('ws');
const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: '192.168.1.160',
  database: 'chat_application',
  password: 'admin',
  port: 5432,
});

const wss = new WebSocket.Server({ port: 8080 });

// Store active connections by user ID
const activeConnections = new Map();

wss.on('connection', async (ws) => {
  console.log('New client connected');

  // First message should be authentication with user ID
  ws.on('message', async (message) => {
    try {
      const data = JSON.parse(message);

      // Handle authentication
      if (data.type === 'auth' && data.userId) {
        activeConnections.set(data.userId, ws);
        console.log(`User ${data.userId} authenticated`);

        // Send chat history if requested
        if (data.chatId) {
          const history = await getChatHistory(data.chatId);
          ws.send(JSON.stringify({
            type: 'history',
            messages: history
          }));
        }
        return;
      }

      // Handle regular messages
      if (data.type === 'message' && data.sender_id && data.content && data.chat_id) {
        // Save to database
        await saveMessage(
          data.chat_id,
          data.sender_id,
          data.content
        );

        // Broadcast to recipient if online
        const recipientWs = activeConnections.get(data.recipient_id);
        if (recipientWs) {
          recipientWs.send(JSON.stringify({
            type: 'message',
            ...data
          }));
        }

        // Also send back to sender for UI update
        ws.send(JSON.stringify({
          type: 'message',
          ...data,
          status: 'delivered'
        }));
      }
    } catch (error) {
      console.error('Error handling message:', error);
    }
  });

  ws.on('close', () => {
    // Remove from active connections
    for (const [userId, connection] of activeConnections.entries) {
      if (connection === ws) {
        activeConnections.delete(userId);
        console.log(`User ${userId} disconnected`);
        break;
      }
    }
  });
});

async function saveMessage(chatId, senderId, content) {
  const query = `
    INSERT INTO messages (chat_id, sender_id, content, sent_at, status)
    VALUES ($1, $2, $3, NOW(), 'delivered')
    RETURNING id`;

  const values = [chatId, senderId, content];

  try {
    const res = await pool.query(query, values);
    return res.rows[0].id;
  } catch (err) {
    console.error('Error saving message:', err);
    throw err;
  }
}

async function getChatHistory(chatId) {
  const query = `
    SELECT m.id, m.content, m.sent_at, m.status,
           u.firstname, u.lastname
    FROM messages m
    JOIN users u ON m.sender_id = u.id
    WHERE m.chat_id = $1
    ORDER BY m.sent_at ASC`;

  try {
    const res = await pool.query(query, [chatId]);
    return res.rows;
  } catch (err) {
    console.error('Error fetching chat history:', err);
    return [];
  }
}

console.log('WebSocket server running on ws://localhost:8080');