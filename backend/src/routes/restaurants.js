const router = require('express').Router();
const bcrypt = require('bcryptjs');
const pool = require('../db');
const auth = require('../middleware/auth');

// ── Asegurar estructura de tablas ─────────────────────────────────
async function ensureRestaurantColumns() {
    try {
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS region VARCHAR(50) DEFAULT \'Otras\'');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS commission_rate DECIMAL(5,2) DEFAULT 0.00');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS google_maps_url TEXT DEFAULT NULL');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS description TEXT DEFAULT NULL');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS logo_url TEXT DEFAULT NULL');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS is_open_override BOOLEAN DEFAULT NULL');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS is_open_override_date TEXT DEFAULT NULL');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS min_time INTEGER DEFAULT 20');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS max_time INTEGER DEFAULT 40');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS rating INTEGER DEFAULT 5');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT \'Otros\'');
        await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS schedule JSONB DEFAULT NULL');
        await pool.query('ALTER TABLE app_config ADD COLUMN IF NOT EXISTS client_view_radius DECIMAL(10,2) DEFAULT 10.00');
    } catch (e) {
        console.error('Error ensuring restaurant columns:', e);
    }
}

// ── GET /restaurants  (admin) ────────────────────────────────────
router.get('/', auth, async (req, res) => {
    const { rows } = await pool.query(
        `SELECT r.id, r.name, r.email, r.phone, r.address, r.active, r.region,
            r.plan_expiry, r.created_at, r.commission_rate,
            p.name AS plan,
            ARRAY(
                SELECT gc.id 
                FROM global_categories gc
                JOIN restaurant_category_map rcm ON rcm.category_id = gc.id
                WHERE rcm.restaurant_id = r.id
            ) as category_ids
     FROM restaurants r
     LEFT JOIN plans p ON r.plan_id = p.id
     ORDER BY r.created_at DESC`);
    res.json(rows);
});

// ── GET /restaurants/me (Perfil propio) ──────────────────────────
router.get('/me', auth, async (req, res) => {
    if (req.user.role !== 'restaurant') return res.status(403).json({ error: 'Prohibido' });

    const { rows } = await pool.query(
        `SELECT r.id, r.name, r.email, r.phone, r.address, r.logo_url, r.google_maps_url, r.description, r.region,
            r.is_open_override, r.is_open_override_date, r.schedule,
            r.plan_id, p.name as plan_name, r.plan_expiry, r.commission_rate,
            ST_Y(r.location::geometry) as lat, ST_X(r.location::geometry) as lng,
            ARRAY(
                SELECT gc.id 
                FROM global_categories gc
                JOIN restaurant_category_map rcm ON rcm.category_id = gc.id
                WHERE rcm.restaurant_id = r.id
            ) as category_ids
         FROM restaurants r 
         LEFT JOIN plans p ON r.plan_id = p.id
         WHERE r.id = $1`,
        [req.user.id]
    );
    res.json(rows[0]);
});

// ── PATCH /restaurants/me/open-status (Toggle abrir/cerrar - solo por hoy) ──
router.patch('/me/open-status', auth, async (req, res) => {
    if (req.user.role !== 'restaurant') return res.status(403).json({ error: 'Prohibido' });
    const { is_open } = req.body;
    if (typeof is_open !== 'boolean') return res.status(400).json({ error: 'is_open debe ser booleano' });

    // Calcular la fecha de hoy en Lima (YYYY-MM-DD)
    const todayLima = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'America/Lima',
        year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(new Date()); // Devuelve YYYY-MM-DD

    await pool.query(
        'UPDATE restaurants SET is_open_override = $1, is_open_override_date = $2 WHERE id = $3',
        [is_open, todayLima, req.user.id]
    );
    res.json({ message: is_open ? 'Abierto hasta el cierre del horario' : 'Cerrado por hoy', is_open, date: todayLima });
});

// ── PUT /restaurants/me (Actualizar perfil propio) ───────────────
router.put('/me', auth, async (req, res) => {
    const { name, phone, address, logo_url, google_maps_url, description, category_ids, region, lat, lng } = req.body;

    let locationQuery = '';
    let params = [name, phone, address, logo_url, google_maps_url, description, region || 'Otras', req.user.id];

    if (lat !== undefined && lng !== undefined) {
        locationQuery = ', location = ST_MakePoint($9, $10)::geography';
        params.push(lng, lat);
    }

    await pool.query(
        `UPDATE restaurants SET name=$1, phone=$2, address=$3, logo_url=$4, google_maps_url=$5, description=$6, region=$7 ${locationQuery} WHERE id=$8`,
        params
    );

    // Actualizar categorías muchos a muchos
    if (category_ids && Array.isArray(category_ids)) {
        await pool.query('DELETE FROM restaurant_category_map WHERE restaurant_id = $1', [req.user.id]);
        for (const catId of category_ids) {
            await pool.query('INSERT INTO restaurant_category_map (restaurant_id, category_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [req.user.id, catId]);
        }
    }

    res.json({ message: 'Perfil actualizado' });
});

// ── GET /restaurants/nearby?lat=&lng=&radius=&category=  (clientes) ────────
router.get('/nearby', async (req, res) => {
    let { lat, lng, radius, category } = req.query;
    if (!lat || !lng) return res.status(400).json({ error: 'lat y lng requeridos' });

    // Si no mandan radius, usar el global config
    if (!radius) {
        const { rows: configRows } = await pool.query('SELECT client_view_radius FROM app_config LIMIT 1');
        radius = parseFloat(configRows[0]?.client_view_radius || 10) * 1000; // a metros
    } else {
        radius = parseFloat(radius);
    }

    let query = `
        SELECT r.id, r.name, r.address, r.logo_url, r.min_time, r.max_time, r.rating,
               r.schedule,
               ST_Y(r.location::geometry) as lat, ST_X(r.location::geometry) as lng,
               ST_Distance(r.location, ST_MakePoint($1,$2)::geography) AS distance_m,
               r.is_open_override, r.is_open_override_date,
               ARRAY(
                   SELECT gc.name 
                   FROM global_categories gc
                   JOIN restaurant_category_map rcm ON rcm.category_id = gc.id
                   WHERE rcm.restaurant_id = r.id
               ) as categories
        FROM restaurants r
        WHERE r.active = true
          AND r.location IS NOT NULL
          AND ST_DWithin(r.location, ST_MakePoint($1,$2)::geography, $3)
    `;

    const params = [lng, lat, radius];
    if (category && category !== 'Todos') {
        query += ` AND EXISTS (
            SELECT 1 FROM global_categories gc
            JOIN restaurant_category_map rcm ON rcm.category_id = gc.id
            WHERE rcm.restaurant_id = r.id AND gc.name ILIKE $4
        )`;
        params.push(category);
    }

    query += ` ORDER BY distance_m ASC`;

    const { rows } = await pool.query(query, params);

    // ── Calcular si está abierto (Horario Lima) ─────────────────
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

    // Fecha de hoy en Lima para el override (YYYY-MM-DD)
    const todayDate = new Intl.DateTimeFormat('en-CA', {
        timeZone,
        year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(now);

    const enriched = rows.map(r => {
        let isOpen = false;

        // 1. Prioridad: Override manual (solo si es de la fecha de hoy)
        if (r.is_open_override !== null && r.is_open_override_date === todayDate) {
            isOpen = r.is_open_override;
        } else {
            // 2. Segundo: Horario programado
            const hasSchedule = r.schedule && Array.isArray(r.schedule) && r.schedule.length > 0;
            if (hasSchedule) {
                const todayConfig = r.schedule.find(s => s.day === todayName);
                if (todayConfig && todayConfig.enabled) {
                    const [openH, openM] = (todayConfig.open || '00:00').split(':').map(Number);
                    const [closeH, closeM] = (todayConfig.close || '23:59').split(':').map(Number);
                    const openMins = openH * 60 + openM;
                    const closeMins = closeH * 60 + closeM;
                    isOpen = currentMinutes >= openMins && currentMinutes <= closeMins;
                }
            } else {
                // Si no tiene horario configurado, podemos elegir si es Abierto o Cerrado por defecto.
                // Dado que el usuario dice que "siguen abiertos", pondremos false por defecto si no hay horario.
                isOpen = false; 
            }
        }

        const { schedule, is_open_override, is_open_override_date, ...rest } = r;
        return { ...rest, is_open: isOpen };
    });

    // Ordenar primero los abiertos
    enriched.sort((a, b) => (b.is_open ? 1 : 0) - (a.is_open ? 1 : 0));

    res.json(enriched);
});

// ── GET /restaurants/categories (Público - Globales) ───────────
router.get('/categories', async (req, res) => {
    const { lat, lng, radius } = req.query;
    try {
        let query = `
            SELECT DISTINCT gc.name 
            FROM global_categories gc
            JOIN restaurant_category_map rcm ON rcm.category_id = gc.id
            JOIN restaurants r ON r.id = rcm.restaurant_id
            WHERE gc.active = true AND r.active = true
        `;
        const params = [];

        if (lat && lng) {
            let rad;
            if (radius) {
                rad = parseFloat(radius) * 1000;
            } else {
                const { rows: configRows } = await pool.query('SELECT client_view_radius FROM app_config LIMIT 1');
                rad = parseFloat(configRows[0]?.client_view_radius || 10) * 1000;
            }
            query += ` AND r.location IS NOT NULL 
                       AND ST_DWithin(r.location, ST_MakePoint($1, $2)::geography, $3)`;
            params.push(parseFloat(lng), parseFloat(lat), rad);
        }

        query += ` ORDER BY gc.name`;

        const { rows } = await pool.query(query, params);
        res.json(rows.map(r => r.name));
    } catch (e) {
        res.json([]);
    }
});

// ── GET /restaurants/public  (clientes — sin auth) ───────────────
router.get('/public', async (req, res) => {
    const { category } = req.query;

    let query = `
        SELECT r.id, r.name, r.address, r.logo_url, r.phone, r.region,
               r.schedule, r.min_time, r.max_time, r.rating,
               r.is_open_override, r.is_open_override_date,
               p.name AS plan_name,
               ARRAY(
                   SELECT gc.name 
                   FROM global_categories gc
                   JOIN restaurant_category_map rcm ON rcm.category_id = gc.id
                   WHERE rcm.restaurant_id = r.id
               ) as categories
        FROM restaurants r
        LEFT JOIN plans p ON r.plan_id = p.id
        WHERE r.active = true
    `;

    const params = [];
    if (category && category !== 'Todos') {
        query += ` AND EXISTS (
            SELECT 1 FROM global_categories gc
            JOIN restaurant_category_map rcm ON rcm.category_id = gc.id
            WHERE rcm.restaurant_id = r.id AND gc.name ILIKE $1
        )`;
        params.push(category);
    }

    query += ` ORDER BY r.created_at DESC`;

    const { rows } = await pool.query(query, params);

    // ── Fecha y hora actual en Lima ─────────────────────────────────
    const now = new Date();
    const timeZone = 'America/Lima';

    // 1. Día de la semana (Lunes, Martes...)
    const dayName = now.toLocaleDateString('es-ES', { timeZone, weekday: 'long' });
    const todayName = dayName.charAt(0).toUpperCase() + dayName.slice(1);

    // 2. Minutos actuales (manejo h=24)
    const rawH = parseInt(now.toLocaleTimeString('en-US', { timeZone, hour: 'numeric', hour12: false }));
    const m = parseInt(now.toLocaleTimeString('en-US', { timeZone, minute: 'numeric' }));
    const h = rawH % 24;
    const currentMinutes = h * 60 + m;

    // 3. Fecha (YYYY-MM-DD)
    const todayDate = new Intl.DateTimeFormat('en-CA', {
        timeZone,
        year: 'numeric', month: '2-digit', day: '2-digit',
    }).format(now);

    const enriched = rows.map(r => {
        let isOpen = false;

        // 1. Override manual
        if (r.is_open_override !== null && r.is_open_override_date === todayDate) {
            isOpen = r.is_open_override;
        } else {
            // 2. Horario
            const hasSchedule = r.schedule && Array.isArray(r.schedule) && r.schedule.length > 0;
            if (hasSchedule) {
                const todayConfig = r.schedule.find(s => s.day === todayName);
                if (todayConfig && todayConfig.enabled) {
                    const [openH, openM] = (todayConfig.open || '00:00').split(':').map(Number);
                    const [closeH, closeM] = (todayConfig.close || '23:59').split(':').map(Number);
                    const openMins = openH * 60 + openM;
                    const closeMins = closeH * 60 + closeM;
                    isOpen = currentMinutes >= openMins && currentMinutes <= closeMins;
                }
            } else {
                isOpen = false;
            }
        }

        const { schedule, is_open_override, is_open_override_date, ...rest } = r;
        return { ...rest, is_open: isOpen };
    });

    // Ordenar: abiertos primero, cerrados al final
    enriched.sort((a, b) => (b.is_open ? 1 : 0) - (a.is_open ? 1 : 0));

    res.json(enriched);
});

// ── GET /restaurants/public/:id (clientes) ───────────────
router.get('/public/:id', async (req, res) => {
    try {
        const { rows } = await pool.query(
            `SELECT id, name, address, logo_url, phone, region,
                    schedule, min_time, max_time, rating,
                    is_open_override, is_open_override_date,
                    ST_Y(location::geometry) as lat, ST_X(location::geometry) as lng
             FROM restaurants WHERE id = $1 AND active = true`,
            [req.params.id]
        );

        if (rows.length === 0) return res.status(404).json({ error: 'No encontrado' });

        const r = rows[0];

        const now = new Date();
        const timeZone = 'America/Lima';

        // 1. Día
        const dayName = now.toLocaleDateString('es-ES', { timeZone, weekday: 'long' });
        const todayName = dayName.charAt(0).toUpperCase() + dayName.slice(1);

        // 2. Horas/Minutos (h=24)
        const rawH = parseInt(now.toLocaleTimeString('en-US', { timeZone, hour: 'numeric', hour12: false }));
        const m = parseInt(now.toLocaleTimeString('en-US', { timeZone, minute: 'numeric' }));
        const h = rawH % 24;
        const currentMinutes = h * 60 + m;

        // 3. Fecha Lima
        const todayDateStr = new Intl.DateTimeFormat('en-CA', {
            timeZone,
            year: 'numeric', month: '2-digit', day: '2-digit',
        }).format(now);

        let isOpen = false;
        if (r.is_open_override !== null && r.is_open_override_date === todayDateStr) {
            isOpen = r.is_open_override;
        } else {
            if (r.schedule && Array.isArray(r.schedule) && r.schedule.length > 0) {
                const todayConfig = r.schedule.find(s => s.day === todayName);
                if (todayConfig && todayConfig.enabled) {
                    const [openH, openM] = (todayConfig.open || '00:00').split(':').map(Number);
                    const [closeH, closeM] = (todayConfig.close || '23:59').split(':').map(Number);
                    const openMins = openH * 60 + openM;
                    const closeMins = closeH * 60 + closeM;
                    isOpen = currentMinutes >= openMins && currentMinutes <= closeMins;
                }
            }
        }

        const { schedule, is_open_override, is_open_override_date, ...rest } = r;
        res.json({ ...rest, is_open: isOpen });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ── POST /restaurants  (admin crea restaurante) ──────────────────
router.post('/', auth, async (req, res) => {
    const { name, email, password, plan_id, phone, address, lat, lng, region } = req.body;
    if (!name || !email || !password) return res.status(400).json({ error: 'Nombre, email y contraseña requeridos' });

    const hash = await bcrypt.hash(password, 10);
    const expiry = new Date();
    expiry.setDate(expiry.getDate() + 30);

    const location = lat && lng
        ? `ST_MakePoint(${parseFloat(lng)}, ${parseFloat(lat)})::geography`
        : null;

    try {
        const isEmprende = parseInt(plan_id) === 1;
        // Pakiip Emprende (ID 1) no tiene fecha limite (null)
        const finalExpiry = isEmprende ? null : expiry;
        const finalCommission = req.body.commission_rate || 0;

        const q = location
            ? `INSERT INTO restaurants (name, email, password, plan_id, phone, address, plan_expiry, location, region, commission_rate)
         VALUES ($1,$2,$3,$4,$5,$6,$7, ST_MakePoint($8,$9)::geography, $10, $11)
         RETURNING id, name, email, active, plan_id`
            : `INSERT INTO restaurants (name, email, password, plan_id, phone, address, plan_expiry, region, commission_rate)
         VALUES ($1,$2,$3,$4,$5,$6,$7, $8, $9) RETURNING id, name, email, active, plan_id`;

        const params = location
            ? [name, email, hash, plan_id || null, phone || null, address || null, finalExpiry, parseFloat(lng), parseFloat(lat), region || 'Otras', finalCommission]
            : [name, email, hash, plan_id || null, phone || null, address || null, finalExpiry, region || 'Otras', finalCommission];

        const { rows } = await pool.query(q, params);
        const restId = rows[0].id;

        // Si mandan categorías al crear (opcional)
        const { category_ids } = req.body;
        if (category_ids && Array.isArray(category_ids)) {
            for (const catId of category_ids) {
                await pool.query('INSERT INTO restaurant_category_map (restaurant_id, category_id) VALUES ($1, $2)', [restId, catId]);
            }
        }

        res.status(201).json({ message: 'Restaurante creado', restaurant: rows[0] });
    } catch (e) {
        if (e.code === '23505') return res.status(409).json({ error: 'El correo ya existe' });
        throw e;
    }
});

// ── PATCH /restaurants/:id/status  (suspender/reactivar) ─────────
router.patch('/:id/status', auth, async (req, res) => {
    const { active } = req.body;
    await pool.query('UPDATE restaurants SET active=$1 WHERE id=$2', [active, req.params.id]);
    res.json({ message: `Restaurante ${active ? 'reactivado' : 'suspendido'}` });
});

// ── PUT /restaurants/:id  (editar) ───────────────────────────────
router.put('/:id', auth, async (req, res) => {
    const { name, email, password, plan_id, region, commission_rate, category_ids } = req.body;
    const isEmprende = parseInt(plan_id) === 1;
    const finalCommission = commission_rate || 0;

    let query, params;
    if (password) {
        const hash = await bcrypt.hash(password, 10);
        query = `UPDATE restaurants SET name=$1, email=$2, password=$3, plan_id=$4, region=$5, commission_rate=$6 
                 ${isEmprende ? ', plan_expiry = NULL' : ''} WHERE id=$7`;
        params = [name, email, hash, plan_id, region || 'Otras', finalCommission, req.params.id];
    } else {
        query = `UPDATE restaurants SET name=$1, email=$2, plan_id=$3, region=$4, commission_rate=$5 
                 ${isEmprende ? ', plan_expiry = NULL' : ''} WHERE id=$6`;
        params = [name, email, plan_id, region || 'Otras', finalCommission, req.params.id];
    }

    await pool.query(query, params);

    // Actualizar categorías muchos a muchos
    if (category_ids && Array.isArray(category_ids)) {
        await pool.query('DELETE FROM restaurant_category_map WHERE restaurant_id = $1', [req.params.id]);
        for (const catId of category_ids) {
            await pool.query('INSERT INTO restaurant_category_map (restaurant_id, category_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [req.params.id, catId]);
        }
    }

    res.json({ message: 'Restaurante actualizado' });
});

// ── DELETE /restaurants/:id ───────────────────────────────────────
router.delete('/:id', auth, async (req, res) => {
    await pool.query('DELETE FROM restaurants WHERE id=$1', [req.params.id]);
    res.json({ message: 'Restaurante eliminado' });
});

ensureRestaurantColumns();

module.exports = router;
