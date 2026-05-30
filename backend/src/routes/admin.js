const router = require('express').Router();
const pool = require('../db');
const auth = require('../middleware/auth');

// ── GET /admin/stats ─────────────────────────────────────────────
router.get('/stats', auth, async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Prohibido' });

    try {
        // 1. Facturación por mes de delivery y tarifa de servicio
        // Asumimos que queremos el mes actual
        const now = new Date();
        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

        // Asegurar tablas y columnas de configuración
        try {
            await pool.query(`
                CREATE TABLE IF NOT EXISTS app_config (
                    id SERIAL PRIMARY KEY,
                    service_fee DECIMAL(10,2) DEFAULT 1.50,
                    rider_commission DECIMAL(10,2) DEFAULT 60.00,
                    base_cost_1km DECIMAL(10,2) DEFAULT 4.00,
                    price_per_km_intermediate DECIMAL(10,2) DEFAULT 1.00,
                    price_per_km_long DECIMAL(10,2) DEFAULT 2.00,
                    rider_view_radius DECIMAL(10,2) DEFAULT 10.00,
                    client_view_radius DECIMAL(10,2) DEFAULT 10.00,
                    maintenance_mode BOOLEAN DEFAULT FALSE,
                    maintenance_message TEXT DEFAULT 'Mantenimiento del sistema',
                    updated_at TIMESTAMP DEFAULT NOW()
                )
            `);

            await pool.query(`
                INSERT INTO app_config (id) SELECT 1 WHERE NOT EXISTS (SELECT 1 FROM app_config WHERE id = 1)
            `);

            // Asegurar tabla de liquidaciones de restaurantes
            await pool.query(`
                CREATE TABLE IF NOT EXISTS restaurant_settlements (
                    id SERIAL PRIMARY KEY,
                    restaurant_id INTEGER NOT NULL REFERENCES restaurants(id) ON DELETE CASCADE,
                    period_month INTEGER NOT NULL,
                    period_year INTEGER NOT NULL,
                    total_sales DECIMAL(10,2) DEFAULT 0.00,
                    commission_rate DECIMAL(5,2) DEFAULT 0.00,
                    commission_amount DECIMAL(10,2) DEFAULT 0.00,
                    status VARCHAR(20) DEFAULT 'pending', -- pending, paid
                    paid_at TIMESTAMP,
                    created_at TIMESTAMP DEFAULT NOW(),
                    UNIQUE(restaurant_id, period_month, period_year)
                )
            `);

            // Asegurar tabla de clientes
            await pool.query(`
                CREATE TABLE IF NOT EXISTS clients (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(150) NOT NULL,
                    email VARCHAR(255) UNIQUE NOT NULL,
                    password VARCHAR(255) NOT NULL,
                    phone VARCHAR(20),
                    delivery_address TEXT,
                    avatar_url TEXT,
                    location GEOGRAPHY(POINT, 4326),
                    active BOOLEAN DEFAULT true,
                    created_at TIMESTAMP DEFAULT NOW()
                )
            `);

            // Asegurar columnas nuevas si la tabla ya existía
            await pool.query('ALTER TABLE app_config ADD COLUMN IF NOT EXISTS rider_view_radius DECIMAL(10,2) DEFAULT 10.00');
            await pool.query('ALTER TABLE app_config ADD COLUMN IF NOT EXISTS client_view_radius DECIMAL(10,2) DEFAULT 10.00');

            await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS service_fee DECIMAL(10,2) DEFAULT 0.00');
            await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS restaurant_commission DECIMAL(10,2) DEFAULT 0.00');
            await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS region VARCHAR(50) DEFAULT \'Otras\'');
            await pool.query('ALTER TABLE restaurants ADD COLUMN IF NOT EXISTS commission_rate DECIMAL(5,2) DEFAULT 10.00');
            await pool.query('ALTER TABLE clients ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT true');

            // ACTUALIZACIÓN: Si la tasa está en 0 o vacía en el config, ponerle 1.50 como salvaguarda
            await pool.query('UPDATE app_config SET service_fee = 1.50 WHERE service_fee IS NULL OR service_fee <= 0');

            // ACTUALIZACIÓN DE PEDIDOS: 
            // Si hay pedidos con service_fee = 0, aplicar el default actual para que el admin vea data
            await pool.query(`
                UPDATE orders 
                SET service_fee = (SELECT service_fee FROM app_config LIMIT 1)
                WHERE (service_fee = 0 OR service_fee IS NULL) AND status != 'cancelled'
            `);
        } catch (e) {
            console.error('Migration error in admin/stats:', e);
        }

        const statsQuery = await pool.query(`
            SELECT 
                COUNT(id) as total_orders,
                SUM(total) as total_billing,
                SUM(delivery_fee) as total_delivery_revenue,
                SUM(service_fee) as total_service_fee,
                SUM(restaurant_commission) as total_restaurant_commission
            FROM orders
            WHERE created_at >= $1 AND status IN ('delivered', 'completed')
        `, [startOfMonth]);

        const stats = statsQuery.rows[0];

        // 2. Cantidad de restaurantes
        const restaurantsCountQuery = await pool.query('SELECT COUNT(*) as count FROM restaurants');
        const totalRestaurants = parseInt(restaurantsCountQuery.rows[0].count || '0');

        // 3. Cantidad de restaurantes por región
        const regionsQuery = await pool.query(`
            SELECT COALESCE(region, 'Otras') as region, COUNT(*) as count 
            FROM restaurants 
            GROUP BY region 
            ORDER BY count DESC
        `);

        // 4. Cantidad de clientes
        const clientsCountQuery = await pool.query('SELECT COUNT(*) as count FROM clients');

        const responseData = {
            orders_month: parseInt(stats.total_orders || '0'),
            billing_month: parseFloat(stats.total_billing || '0'),
            delivery_revenue_month: parseFloat(stats.total_delivery_revenue || '0'),
            service_fee_month: parseFloat(stats.total_service_fee || '0'),
            restaurant_commission_month: parseFloat(stats.total_restaurant_commission || '0'),
            total_restaurants: totalRestaurants,
            total_clients: parseInt(clientsCountQuery.rows[0].count || '0'),
            restaurants_by_region: regionsQuery.rows.map(r => ({
                region: r.region,
                count: parseInt(r.count || '0')
            }))
        };

        // console.log('📊 Admin Stats Response:', responseData);
        res.json(responseData);

    } catch (e) {
        console.error('Error fetching admin stats:', e);
        res.status(500).json({ error: e.message });
    }
});

// ── GET /admin/orders (Todos los pedidos con paginación) ──────────
router.get('/orders', auth, async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Prohibido' });

    try {
        const limit = parseInt(req.query.limit) || 20;
        const page = parseInt(req.query.page) || 1;
        const offset = (page - 1) * limit;

        // Obtener pedidos con nombre de restaurante
        const { rows } = await pool.query(`
            SELECT 
                o.id,
                o.order_code,
                o.total::FLOAT,
                o.delivery_fee::FLOAT,
                o.service_fee::FLOAT,
                o.restaurant_commission::FLOAT,
                o.restaurant_payout::FLOAT,
                o.tip::FLOAT,
                o.rider_id,
                o.status,
                o.created_at,
                o.restaurant_id,
                o.client_name,
                o.client_phone,
                o.client_address,
                o.items,
                o.payment_method,
                o.payment_proof_url,
                r.name as restaurant_name,
                r.commission_rate as restaurant_commission_rate,
                r.plan_id as restaurant_plan_id,
                rid.name as rider_name,
                rid.commission as rider_commission_rate
            FROM orders o
            LEFT JOIN restaurants r ON o.restaurant_id = r.id
            LEFT JOIN riders rid ON o.rider_id = rid.id
            ORDER BY o.created_at DESC
            LIMIT $1 OFFSET $2
        `, [limit, offset]);

        // Obtener total para paginación
        const countRes = await pool.query('SELECT COUNT(*) FROM orders');
        const total = parseInt(countRes.rows[0].count);

        res.json({
            orders: rows,
            pagination: {
                total,
                page,
                limit,
                pages: Math.ceil(total / limit)
            }
        });
    } catch (e) {
        console.error('Error fetching global orders:', e);
        res.status(500).json({ error: e.message });
    }
});

// ── GET /admin/liquidations (Gestión de pagos a repartidores) ──────
router.get('/liquidations', auth, async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Prohibido' });

    try {
        // Asegurar columna rider_paid
        try {
            await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS rider_paid BOOLEAN DEFAULT FALSE');
        } catch (e) { }

        // 1. Facturación mensual total (Solo delivery fees de entregados)
        const now = new Date();
        const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

        const { rows: totalRes } = await pool.query(
            "SELECT (SUM(delivery_fee) + COALESCE(SUM(tip), 0))::FLOAT as total FROM orders WHERE status IN ('delivered', 'completed') AND created_at >= $1",
            [startOfMonth]
        );

        // 2. Agrupar por repartidor los pagos pendientes
        const { rows: ridersRes } = await pool.query(`
            SELECT 
                r.id,
                r.name,
                COUNT(o.id) as deliveries_count,
                SUM(o.delivery_fee::FLOAT) as total_delivery_fee,
                SUM(COALESCE(o.tip, 0)::FLOAT) as total_tips,
                r.commission
            FROM orders o
            JOIN riders r ON o.rider_id = r.id
            WHERE o.status IN ('delivered', 'completed') 
              AND (o.rider_paid = FALSE OR o.rider_paid IS NULL)
            GROUP BY r.id, r.name, r.commission
        `);

        // Calcular payout real por repartidor (Comisión sobre envío + 100% de propina)
        const liquidations = ridersRes.map(r => {
            const billing = parseFloat(r.total_delivery_fee || 0);
            const tips = parseFloat(r.total_tips || 0);
            const comm = parseFloat(r.commission || 60) / 100;
            return {
                id: r.id,
                name: r.name,
                billing: billing,
                tips: tips,
                deliveries: parseInt(r.deliveries_count),
                commission: comm,
                payout: (billing * comm) + tips
            };
        });

        res.json({
            total_monthly_billing: parseFloat(totalRes[0].total || 0),
            liquidations
        });
    } catch (e) {
        console.error('Error liquidations:', e);
        res.status(500).json({ error: e.message });
    }
});

// ── POST /admin/liquidations/:riderId/pay (Procesar pago) ──────────
router.post('/liquidations/:riderId/pay', auth, async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Prohibido' });
    const { riderId } = req.params;

    try {
        await pool.query(
            "UPDATE orders SET rider_paid = TRUE WHERE rider_id = $1 AND status = 'delivered' AND rider_paid = FALSE",
            [riderId]
        );
        res.json({ message: 'Pago procesado correctamente' });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ── GET /admin/config (Parámetros globales) ─────────────────────
router.get('/config', auth, async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Prohibido' });
    try {
        const { rows } = await pool.query('SELECT * FROM app_config LIMIT 1');
        res.json(rows[0] || {
            service_fee: 1.50,
            rider_commission: 60,
            base_cost_1km: 4.00,
            price_per_km_intermediate: 1.00,
            price_per_km_long: 2.00,
            rider_view_radius: 10.00,
            client_view_radius: 10.00,
            maintenance_mode: false,
            maintenance_message: 'Mantenimiento'
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ── PATCH /admin/config (Actualizar parámetros globales) ──────────
router.patch('/config', auth, async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Prohibido' });
    const {
        service_fee,
        rider_commission,
        base_cost_1km,
        price_per_km_intermediate,
        price_per_km_long,
        rider_view_radius,
        client_view_radius,
        maintenance_mode,
        maintenance_message
    } = req.body;
    try {
        const query = `
            UPDATE app_config 
            SET service_fee = COALESCE($1, service_fee),
                rider_commission = COALESCE($2, rider_commission),
                base_cost_1km = COALESCE($3, base_cost_1km),
                price_per_km_intermediate = COALESCE($4, price_per_km_intermediate),
                price_per_km_long = COALESCE($5, price_per_km_long),
                rider_view_radius = COALESCE($6, rider_view_radius),
                client_view_radius = COALESCE($7, client_view_radius),
                maintenance_mode = COALESCE($8, maintenance_mode),
                maintenance_message = COALESCE($9, maintenance_message),
                updated_at = NOW()
            RETURNING *
        `;
        const { rows } = await pool.query(query, [
            service_fee,
            rider_commission,
            base_cost_1km,
            price_per_km_intermediate,
            price_per_km_long,
            rider_view_radius,
            client_view_radius,
            maintenance_mode,
            maintenance_message
        ]);

        if (rider_commission !== undefined) {
            await pool.query('UPDATE riders SET commission = $1', [rider_commission]);
        }

        res.json(rows[0]);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ── GET /admin/clients (Lista de usuarios finales) ───────────────
router.get('/clients', auth, async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Prohibido' });
    try {
        const { rows } = await pool.query('SELECT id, name, email, phone, created_at, active FROM clients ORDER BY created_at DESC');
        res.json(rows);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ── DELETE /admin/clients/:id (Eliminar usuario final) ─────────────
router.delete('/clients/:id', auth, async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Prohibido' });
    try {
        await pool.query('DELETE FROM clients WHERE id = $1', [req.params.id]);
        res.json({ message: 'Usuario eliminado' });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ── GET /admin/restaurants/:id/orders (Historial de pedidos por restaurante con filtros) ──
router.get('/restaurants/:id/orders', auth, async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Prohibido' });
    const { id } = req.params;
    const { month, year, day } = req.query;

    let query = `
        SELECT 
            o.id, o.order_code, o.total::FLOAT, o.delivery_fee::FLOAT, o.service_fee::FLOAT, 
            o.restaurant_commission::FLOAT, o.tip::FLOAT, o.status, o.created_at, 
            o.client_name, o.client_phone, o.client_address, o.items, o.payment_method,
            r.commission_rate as restaurant_commission_rate,
            r.plan_id as restaurant_plan_id
        FROM orders o
        JOIN restaurants r ON o.restaurant_id = r.id
        WHERE o.restaurant_id = $1
    `;
    const params = [id];

    let pCount = 2;
    if (day) {
        query += ` AND (o.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/Lima')::DATE = $${pCount}`;
        params.push(day); // YYYY-MM-DD
        pCount++;
    } else if (month && year) {
        query += ` AND EXTRACT(MONTH FROM o.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/Lima') = $${pCount}`;
        params.push(month);
        pCount++;
        query += ` AND EXTRACT(YEAR FROM o.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/Lima') = $${pCount}`;
        params.push(year);
        pCount++;
    }

    query += ` ORDER BY o.created_at DESC`;

    try {
        const { rows } = await pool.query(query, params);
        res.json(rows);
    } catch (e) {
        console.error('Error fetching restaurant orders:', e);
        res.status(500).json({ error: e.message });
    }
});

// ── GET /admin/riders/:id/pending-orders (Pedidos pendientes de pago para un motorizado) ──
router.get('/riders/:id/pending-orders', auth, async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Prohibido' });
    const { id } = req.params;
    try {
        const { rows } = await pool.query(`
            SELECT 
                o.id, o.order_code, o.total::FLOAT, o.delivery_fee::FLOAT, o.tip::FLOAT, 
                o.status, o.created_at, o.client_name, o.client_address, o.items,
                r.name as restaurant_name
            FROM orders o
            JOIN restaurants r ON o.restaurant_id = r.id
            WHERE o.rider_id = $1 AND o.status IN ('delivered', 'completed') AND (o.rider_paid = FALSE OR o.rider_paid IS NULL)
            ORDER BY o.created_at DESC
        `, [id]);
        res.json(rows);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

module.exports = router;
