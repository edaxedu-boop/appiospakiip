const router = require('express').Router();
const pool = require('../db');
const auth = require('../middleware/auth');

// ── Asegurar tabla ────────────────────────────────────────────────
async function ensureTable() {
    await pool.query(`
        CREATE TABLE IF NOT EXISTS promotions (
            id            SERIAL PRIMARY KEY,
            title         VARCHAR(120) NOT NULL,
            description   TEXT,
            image_url     TEXT NOT NULL,
            restaurant_id INTEGER REFERENCES restaurants(id) ON DELETE SET NULL,
            link          TEXT,
            active        BOOLEAN DEFAULT true,
            created_at    TIMESTAMP DEFAULT NOW()
        )
    `);
}
ensureTable().catch(console.error);

// ── GET /promotions/public  (sin auth — clientes) ─────────────────
router.get('/public', async (req, res) => {
    let { lat, lng, radius } = req.query;
    
    let radiusCondition = '';
    const sqlParams = [];

    if (lat && lng) {
        if (!radius) {
            const { rows: configRows } = await pool.query('SELECT client_view_radius FROM app_config LIMIT 1');
            radius = parseFloat(configRows[0]?.client_view_radius || 10) * 1000;
        } else {
            radius = parseFloat(radius);
        }
        
        radiusCondition = `AND (p.restaurant_id IS NULL OR (r.location IS NOT NULL AND ST_DWithin(r.location, ST_MakePoint($1,$2)::geography, $3)))`;
        sqlParams.push(lng, lat, radius);
    }

    const { rows } = await pool.query(`
        SELECT p.id, p.title, p.description, p.image_url,
               p.restaurant_id, p.link,
               r.name AS restaurant_name,
               r.logo_url AS restaurant_logo,
               r.address  AS restaurant_address,
               r.category AS restaurant_category,
               r.rating   AS restaurant_rating,
               r.min_time AS restaurant_min_time,
               r.max_time AS restaurant_max_time,
               r.schedule AS restaurant_schedule,
               r.is_open_override, r.is_open_override_date,
               ST_Y(r.location::geometry) as restaurant_lat,
               ST_X(r.location::geometry) as restaurant_lng
        FROM promotions p
        LEFT JOIN restaurants r ON r.id = p.restaurant_id
        WHERE p.active = true
          AND (p.restaurant_id IS NULL OR r.active = true)
          ${radiusCondition}
        ORDER BY p.created_at DESC
    `, sqlParams);

    // Filtrar por horario de apertura y override (Lima, Perú)
    const now = new Date();
    const timeZone = 'America/Lima';
    
    // 1. Día de la semana en Lima (Lunes, Martes...)
    const dayName = now.toLocaleDateString('es-ES', { timeZone, weekday: 'long' });
    const todayName = dayName.charAt(0).toUpperCase() + dayName.slice(1);
    
    // 2. Minutos actuales en Lima (manejando caso h=24 que ocurre en algunos entornos)
    const rawH = parseInt(now.toLocaleTimeString('en-US', { timeZone, hour: 'numeric', hour12: false }));
    const m = parseInt(now.toLocaleTimeString('en-US', { timeZone, minute: 'numeric' }));
    const h = rawH % 24;
    const currentMinutes = h * 60 + m;
    
    const todayDate = new Intl.DateTimeFormat('en-CA', {
        timeZone,
        year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(now);

    const validPromos = [];

    for (const row of rows) {
        if (row.restaurant_id === null) {
            validPromos.push(row);
            continue;
        }

        let isOpen = false;

        // 1. Override manual
        if (row.is_open_override !== null && row.is_open_override_date === todayDate) {
            isOpen = row.is_open_override;
        } else {
            // 2. Horario
            const schedule = row.restaurant_schedule;
            if (schedule && Array.isArray(schedule) && schedule.length > 0) {
                const todayConfig = schedule.find(s => s.day === todayName);
                if (todayConfig && todayConfig.enabled) {
                    const [openH, openM] = (todayConfig.open || '00:00').split(':').map(Number);
                    const [closeH, closeM] = (todayConfig.close || '23:59').split(':').map(Number);
                    const openMins = openH * 60 + openM;
                    const closeMins = closeH * 60 + closeM;
                    isOpen = currentMinutes >= openMins && currentMinutes <= closeMins;
                }
            } else {
                isOpen = false; // Default cerrado si no tiene horario
            }
        }
        
        if (isOpen) {
            // Ocultar datos sensibles/innecesarios para el front de banners
            delete row.restaurant_schedule;
            delete row.is_open_override;
            delete row.is_open_override_date;
            validPromos.push(row);
        }
    }

    res.json(validPromos);
});

// ── GET /promotions  (admin) ──────────────────────────────────────
router.get('/', auth, async (_req, res) => {
    const { rows } = await pool.query(`
        SELECT p.*, r.name AS restaurant_name
        FROM promotions p
        LEFT JOIN restaurants r ON r.id = p.restaurant_id
        ORDER BY p.created_at DESC
    `);
    res.json(rows);
});

// ── POST /promotions  (admin crea) ────────────────────────────────
router.post('/', auth, async (req, res) => {
    const { title, description, image_url, restaurant_id, link } = req.body;
    if (!title || !image_url) return res.status(400).json({ error: 'título e imagen requeridos' });

    const { rows } = await pool.query(
        `INSERT INTO promotions (title, description, image_url, restaurant_id, link)
         VALUES ($1,$2,$3,$4,$5) RETURNING *`,
        [title, description || null, image_url, restaurant_id || null, link || null]
    );
    res.status(201).json(rows[0]);
});

// ── PUT /promotions/:id  (admin edita) ────────────────────────────
router.put('/:id', auth, async (req, res) => {
    const { title, description, image_url, restaurant_id, link, active } = req.body;
    await pool.query(
        `UPDATE promotions
         SET title=$1, description=$2, image_url=$3, restaurant_id=$4, link=$5, active=$6
         WHERE id=$7`,
        [title, description || null, image_url, restaurant_id || null, link || null,
            active !== undefined ? active : true, req.params.id]
    );
    res.json({ message: 'Promoción actualizada' });
});

// ── DELETE /promotions/:id ────────────────────────────────────────
router.delete('/:id', auth, async (req, res) => {
    await pool.query('DELETE FROM promotions WHERE id=$1', [req.params.id]);
    res.json({ message: 'Promoción eliminada' });
});

module.exports = router;
