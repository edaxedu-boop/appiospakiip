const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

pool.on('connect', (client) => {
  client.query("SET TIME ZONE 'America/Lima'");
  console.log('✅ Conectado a PostgreSQL (TZ: Lima)');
});

pool.on('error', (err) => {
  console.error('❌ Error en PostgreSQL:', err.message);
});

module.exports = pool;
