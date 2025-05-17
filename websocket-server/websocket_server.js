const WebSocket = require('ws');
const { Pool } = require('pg');

const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'chat_application',
  password: 'postgres',
  port: 5432,
  // Add connection timeout
  connectionTimeoutMillis: 5000,
  idleTimeoutMillis: 30000,
});

const wss = new WebSocket.Server({ port: 8080 });
const activeConnections = new Map();

async function checkDatabaseConnection() {
  try {
    await pool.query('SELECT NOW()');
    console.log('Database connection successful');
  } catch (err) {
    console.error('Database connection error:', err);
    process.exit(1);
  }
}

wss.on('connection', (ws) => {
  console.log('New client connected');

  ws.on('message', async (message) => {
    try {
      const data = JSON.parse(message);

      // Handle authentication
      if (data.type === 'auth' && data.userId) {
        activeConnections.set(data.userId, ws);
        console.log(`User ${data.userId} authenticated`);

        if (data.chatId) {
          try {
            const history = await getChatHistory(data.chatId);
            ws.send(JSON.stringify({
              type: 'history',
              messages: history
            }));
          } catch (err) {
            console.error('Error sending history:', err);
          }
        }
        return;
      }

      // Handle messages
      if (data.type === 'message' && data.sender_id && data.content && data.chat_id) {
        try {
          const messageId = await saveMessage(data.chat_id, data.sender_id, data.content);
          const sender = await getSenderDetails(data.sender_id);
          const participants = await getChatParticipants(data.chat_id);

          participants.forEach(participantId => {
            const connection = activeConnections.get(participantId);
            if (connection && connection.readyState === WebSocket.OPEN) {
              connection.send(JSON.stringify({
                type: 'message',
                id: messageId,
                content: data.content,
                sender_id: data.sender_id,
                firstname: sender.firstname,
                lastname: sender.lastname,
                sent_at: new Date().toISOString()
              }));
            }
          });
        } catch (err) {
          console.error('Error handling message:', err);
          ws.send(JSON.stringify({
            type: 'error',
            message: 'Failed to send message'
          }));
        }
      }
    } catch (error) {
      console.error('Message handling error:', error);
    }
  });

  ws.on('close', () => {
    for (const [userId, connection] of activeConnections.entries()) {
      if (connection === ws) {
        activeConnections.delete(userId);
        console.log(`User ${userId} disconnected`);
        break;
      }
    }
  });

  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

async function saveMessage(chatId, senderId, content) {
  const client = await pool.connect();
  try {
    const res = await client.query(
      `INSERT INTO messages (chat_id, sender_id, content, sent_at, status)
       VALUES ($1, $2, $3, NOW(), 'delivered')
       RETURNING id`,
      [chatId, senderId, content]
    );
    return res.rows[0].id;
  } finally {
    client.release();
  }
}

async function getSenderDetails(userId) {
  const client = await pool.connect();
  try {
    const res = await client.query(
      'SELECT firstname, lastname FROM users WHERE id = $1',
      [userId]
    );
    return res.rows[0];
  } finally {
    client.release();
  }
}

async function getChatHistory(chatId) {
  const client = await pool.connect();
  try {
    const res = await client.query(
      `SELECT m.id, m.content, m.sent_at, m.status,
              u.firstname, u.lastname, u.id as sender_id
       FROM messages m
       JOIN users u ON m.sender_id = u.id
       WHERE m.chat_id = $1
       ORDER BY m.sent_at ASC`,
      [chatId]
    );
    return res.rows;
  } finally {
    client.release();
  }
}

async function getChatParticipants(chatId) {
  const client = await pool.connect();
  try {
    const res = await client.query(
      'SELECT user_id FROM chat_users WHERE chat_id = $1',
      [chatId]
    );
    return res.rows.map(row => row.user_id);
  } finally {
    client.release();
  }
}

checkDatabaseConnection().then(() => {
  console.log('WebSocket server running on ws://localhost:8080');
});