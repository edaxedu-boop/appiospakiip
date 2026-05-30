const router = require('express').Router();
const pool = require('../db');
const auth = require('../middleware/auth');

// --- Asegurar columnas ---
async function ensureDeliveryColumns() {
    try {
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS delivery_cost DECIMAL(10,2) DEFAULT 0.00');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS free_delivery_from DECIMAL(10,2) DEFAULT NULL');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS max_delivery_km DECIMAL(10,2) DEFAULT 5.00');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS base_delivery_time VARCHAR(20) DEFAULT \'30-45 min\'');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS logo_url TEXT DEFAULT NULL');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS min_time INTEGER DEFAULT 25');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS max_time INTEGER DEFAULT 45');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS schedule JSONB DEFAULT NULL');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS rating INTEGER DEFAULT 5');
    } catch (e) { console.error('Error adding columns to restaurants:', e); }
}

async function ensureAppConfigColumns() {
    try {
        await pool.query('ALTER TABLE app_config ADD COLUMN IF NOT EXISTS base_cost_1km DECIMAL(10,2) DEFAULT 4.00');
        await pool.query('ALTER TABLE app_config ADD COLUMN IF NOT EXISTS price_per_km_intermediate DECIMAL(10,2) DEFAULT 1.00');
        await pool.query('ALTER TABLE app_config ADD COLUMN IF NOT EXISTS price_per_km_long DECIMAL(10,2) DEFAULT 2.00');
        await pool.query('ALTER TABLE app_config ADD COLUMN IF NOT EXISTS rider_view_radius DECIMAL(10,2) DEFAULT 10.00');
        await pool.query('ALTER TABLE app_config ADD COLUMN IF NOT EXISTS client_view_radius DECIMAL(10,2) DEFAULT 10.00');
    } catch (e) { console.error('Error adding columns to app_config:', e); }
}

ensureDeliveryColumns().catch(console.error);
ensureAppConfigColumns().catch(console.error);

// --- GET /config/delivery ---
router.get('/delivery', auth, async (req, res) => {
    if (req.user.role !== 'restaurant') return res.status(403).json({ error: 'Prohibido' });
    const { rows } = await pool.query(
        `SELECT delivery_cost, free_delivery_from, max_delivery_km, base_delivery_time,
                min_time, max_time, schedule, rating
         FROM restaurants WHERE id = $1`,
        [req.user.id]
    );
    res.json(rows[0] || {});
});

// --- PUT /config/delivery ---
router.put('/delivery', auth, async (req, res) => {
    if (req.user.role !== 'restaurant') return res.status(403).json({ error: 'Prohibido' });
    const {
        delivery_cost, free_delivery_from, max_delivery_km, base_delivery_time,
        min_time, max_time, schedule, rating
    } = req.body;

    // Siempre sobrescribir el schedule si viene en el body (no usar COALESCE para evitar que el valor antiguo quede pegado)
    const query = schedule
        ? `UPDATE restaurants
           SET delivery_cost      = COALESCE($1, delivery_cost),
               free_delivery_from = $2,
               max_delivery_km    = COALESCE($3, max_delivery_km),
               base_delivery_time = COALESCE($4, base_delivery_time),
               min_time           = COALESCE($5, min_time),
               max_time           = COALESCE($6, max_time),
               schedule           = $7::jsonb,
               rating             = COALESCE($8, rating)
           WHERE id = $9`
        : `UPDATE restaurants
           SET delivery_cost      = COALESCE($1, delivery_cost),
               free_delivery_from = $2,
               max_delivery_km    = COALESCE($3, max_delivery_km),
               base_delivery_time = COALESCE($4, base_delivery_time),
               min_time           = COALESCE($5, min_time),
               max_time           = COALESCE($6, max_time),
               rating             = COALESCE($8, rating)
           WHERE id = $9`;

    await pool.query(query, [
        delivery_cost ?? null,
        free_delivery_from ?? null,
        max_delivery_km ?? null,
        base_delivery_time ?? null,
        min_time ?? null,
        max_time ?? null,
        schedule ? JSON.stringify(schedule) : null,
        rating ?? null,
        req.user.id
    ]);
    res.json({ message: 'Configuraci\u00f3n guardada' });
});

// --- GET /config/public (Public global config) ---
router.get('/public', async (req, res) => {
    try {
        const { rows } = await pool.query('SELECT service_fee, maintenance_mode, maintenance_message, base_cost_1km, price_per_km_intermediate, price_per_km_long, rider_view_radius, client_view_radius FROM app_config LIMIT 1');
        res.json(rows[0] || {
            service_fee: 1.50,
            maintenance_mode: false,
            maintenance_message: 'Mantenimiento del sistema',
            base_cost_1km: 4.00,
            price_per_km_intermediate: 1.00,
            price_per_km_long: 2.00,
            rider_view_radius: 10.00,
            client_view_radius: 10.00
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

module.exports = router;
