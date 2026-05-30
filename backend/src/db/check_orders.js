const { Client } = require('pg');
const client = new Client({
    host: 'localhost',
    database: 'pakiip_db',
    user: 'postgres',
    password: 'Pakiip2026@',
    port: 5432
});

async function check() {
    try {
        await client.connect();
        const res = await client.query('SELECT id, delivery_fee, tip, rider_id, status, rider_paid FROM orders ORDER BY id DESC LIMIT 20');
        console.log(JSON.stringify(res.rows, null, 2));
        await client.end();
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
}

check();
