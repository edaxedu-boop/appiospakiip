const router = require('express').Router();
const pool = require('../db');
const auth = require('../middleware/auth');

// ── GET /riders/me (mi perfil) ───────────────────────────────────
router.get('/me', auth, async (req, res) => {
    if (req.user.role !== 'rider') return res.status(403).json({ error: 'Solo repartidores' });
    try { await pool.query('ALTER TABLE riders ADD COLUMN IF NOT EXISTS image_url TEXT DEFAULT NULL'); } catch (e) { }
    const { rows } = await pool.query(
        'SELECT id, name, email, phone, vehicle, commission, image_url, status, created_at FROM riders WHERE id = $1',
        [req.user.id]
    );
    res.json(rows[0]);
});

// ── PATCH /riders/me (actualizar mi perfil) ──────────────────────
router.patch('/me', auth, async (req, res) => {
    if (req.user.role !== 'rider') return res.status(403).json({ error: 'Solo repartidores' });
    const { name, phone, email, image_url } = req.body;
    try { await pool.query('ALTER TABLE riders ADD COLUMN IF NOT EXISTS image_url TEXT DEFAULT NULL'); } catch (e) { }
    await pool.query(
        'UPDATE riders SET name=COALESCE($1, name), phone=COALESCE($2, phone), email=COALESCE($3, email), image_url=COALESCE($4, image_url) WHERE id=$5',
        [name, phone, email, image_url, req.user.id]
    );
    res.json({ message: 'Perfil actualizado' });
});

// ── GET /riders ───────────────────────────────────────────────────
router.get('/', auth, async (req, res) => {
    try { await pool.query('ALTER TABLE riders ADD COLUMN IF NOT EXISTS image_url TEXT DEFAULT NULL'); } catch (e) { }
    const { rows } = await pool.query(
        `SELECT id, name, email, phone, status, active, vehicle, commission, image_url, created_at
     FROM riders ORDER BY created_at DESC`);
    res.json(rows);
});

// ── POST /riders  (admin crea repartidor) ─────────────────────────
router.post('/', auth, async (req, res) => {
    const bcrypt = require('bcryptjs');
    const { name, email, password, phone, vehicle, commission } = req.body;
    if (!name || !email || !password) return res.status(400).json({ error: 'Nombre, email y contraseña requeridos' });

    const hash = await bcrypt.hash(password, 10);
    try {
        let finalComm = commission;
        if (finalComm === undefined) {
            const conf = await pool.query('SELECT rider_commission FROM app_config LIMIT 1');
            finalComm = conf.rows.length > 0 ? parseFloat(conf.rows[0].rider_commission || 60) : 60;
        }

        const { rows } = await pool.query(
            `INSERT INTO riders (name, email, password, phone, vehicle, commission)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING id, name, email, status, active`,
            [name, email, hash, phone || null, vehicle || 'moto', finalComm]);
        res.status(201).json({ message: 'Repartidor creado', rider: rows[0] });
    } catch (e) {
        if (e.code === '23505') return res.status(409).json({ error: 'El correo ya existe' });
        throw e;
    }
});

// ── PATCH /riders/:id/status ──────────────────────────────────────
router.patch('/:id/status', auth, async (req, res) => {
    const { status, active } = req.body;
    // console.log(`[DEBUG] Updating rider ${req.params.id} - status: ${status}, active: ${active}`);
    if (status !== undefined) {
        await pool.query('UPDATE riders SET status=$1 WHERE id=$2', [status, req.params.id]);
    }
    if (active !== undefined) {
        await pool.query('UPDATE riders SET active=$1 WHERE id=$2', [active, req.params.id]);
    }
    res.json({ message: 'Estado actualizado' });
});

// ── PATCH /riders/:id/location  (el repartidor actualiza su GPS) ──
router.patch('/:id/location', auth, async (req, res) => {
    const { lat, lng } = req.body;
    await pool.query(
        'UPDATE riders SET location=ST_MakePoint($1,$2)::geography WHERE id=$3',
        [parseFloat(lng), parseFloat(lat), req.params.id]);
    res.json({ message: 'Ubicación actualizada' });
});

// ── GET /riders/orders/available (pedidos listos para tomar) ──────
router.get('/orders/available', auth, async (req, res) => {
    if (req.user.role !== 'rider') return res.status(403).json({ error: 'Solo repartidores' });

    try {
        // 1. Obtener datos del repartidor (estado y ubicación)
        const { rows: riderRows } = await pool.query('SELECT status, location FROM riders WHERE id = $1', [req.user.id]);
        if (riderRows.length === 0) return res.status(404).json({ error: 'Repartidor no encontrado' });

        const rider = riderRows[0];
        if ((rider.status !== 'online' && rider.status !== 'busy') || !rider.location) return res.json([]);

        // 2. Buscar pedidos cerca (radius configurable) y sin repartidor asignado, ordenados por cercanía
        const { rows: configRows } = await pool.query('SELECT rider_view_radius FROM app_config LIMIT 1');
        const radiusKm = parseFloat(configRows[0]?.rider_view_radius || 10) * 1000;

        const { rows: nearbyOrders } = await pool.query(
            `SELECT o.*, 
                    COALESCE(r.name, 'Pakiip Favor') as restaurant_name, 
                    COALESCE(r.address, o.pickup_address) as restaurant_address, 
                    COALESCE(r.phone, o.sender_phone) as restaurant_phone,
                    COALESCE(ST_X(r.location::geometry), o.pickup_lng::float) as restaurant_lng,
                    COALESCE(ST_Y(r.location::geometry), o.pickup_lat::float) as restaurant_lat,
                    CASE 
                      WHEN r.location IS NOT NULL THEN ST_Distance(r.location, $1)
                      WHEN o.pickup_lng IS NOT NULL AND o.pickup_lat IS NOT NULL 
                        THEN ST_Distance(ST_MakePoint(o.pickup_lng::float, o.pickup_lat::float)::geography, $1)
                      ELSE NULL
                    END as distance_m
             FROM orders o
             LEFT JOIN restaurants r ON o.restaurant_id = r.id
             WHERE o.status IN ('accepted', 'preparing', 'ready') 
               AND o.rider_id IS NULL
               AND (
                 (r.id IS NOT NULL AND (r.location IS NULL OR ST_DWithin(r.location, $1, $2)))
                 OR 
                 (r.id IS NULL)
               )
             ORDER BY distance_m ASC NULLS LAST, o.created_at DESC`,
            [rider.location, radiusKm]
        );

        // Obtener la comisión del repartidor para calcular su ganancia
        const { rows: riderCommRows } = await pool.query('SELECT commission FROM riders WHERE id = $1', [req.user.id]);
        const riderCommission = parseFloat(riderCommRows[0]?.commission || 60);

        // Añadir rider_earning a cada pedido
        const ordersWithEarning = nearbyOrders.map(o => ({
            ...o,
            rider_earning: parseFloat(((parseFloat(o.delivery_fee || 0) * riderCommission) / 100).toFixed(2)),
            rider_commission_pct: riderCommission
        }));

        res.json(ordersWithEarning);
    } catch (e) {
        console.error(e);
        res.status(500).json({ error: 'Error al buscar pedidos' });
    }
});

// ── GET /riders/orders/active (pedidos actuales del repartidor) ──────
router.get('/orders/active', auth, async (req, res) => {
    if (req.user.role !== 'rider') return res.status(403).json({ error: 'Solo repartidores' });

    const { rows: riderRows } = await pool.query('SELECT commission FROM riders WHERE id = $1', [req.user.id]);
    const riderCommission = parseFloat(riderRows[0]?.commission || 60);

    const { rows } = await pool.query(
        `SELECT o.*, o.tip::FLOAT, o.service_fee::FLOAT, 
                COALESCE(r.name, 'Pakiip Favor') as restaurant_name, 
                COALESCE(r.address, o.pickup_address) as restaurant_address, 
                COALESCE(r.phone, o.sender_phone) as restaurant_phone,
                COALESCE(ST_X(r.location::geometry), o.pickup_lng) as restaurant_lng,
                COALESCE(ST_Y(r.location::geometry), o.pickup_lat) as restaurant_lat
         FROM orders o
         LEFT JOIN restaurants r ON o.restaurant_id = r.id
         WHERE o.rider_id = $1 AND o.status IN ('rider_assigned', 'ready', 'in_delivery', 'preparing')
         ORDER BY o.created_at ASC`,
        [req.user.id]
    );

    const activeOrders = rows.map(o => {
        o.rider_earning = parseFloat(((parseFloat(o.delivery_fee || 0) * riderCommission) / 100).toFixed(2));
        o.rider_commission_pct = riderCommission;
        return o;
    });

    res.json(activeOrders);
});

// ── PATCH /riders/orders/:id/take (tomar un pedido) ────────────────
router.patch('/orders/:id/take', auth, async (req, res) => {
    if (req.user.role !== 'rider') return res.status(403).json({ error: 'Solo repartidores' });

    const orderId = req.params.id;
    const riderId = req.user.id;

    // Verificar si ya tiene el límite máximo de pedidos activos (5)
    const { rows: active } = await pool.query("SELECT id FROM orders WHERE rider_id=$1 AND status IN ('rider_assigned', 'ready', 'in_delivery', 'preparing')", [riderId]);
    if (active.length >= 5) return res.status(400).json({ error: 'Has alcanzado el límite máximo de 5 pedidos simultáneos.' });

    // Verificar si el pedido sigue disponible
    const { rows: order } = await pool.query("SELECT status, rider_id FROM orders WHERE id=$1", [orderId]);
    if (order.length === 0) return res.status(404).json({ error: 'Pedido no encontrado' });
    if (order[0].rider_id) return res.status(400).json({ error: 'Este pedido ya fue tomado' });

    // Cuando el motorizado acepta, el estado pasa a 'rider_assigned'
    await pool.query(
        "UPDATE orders SET rider_id=$1, status='rider_assigned' WHERE id=$2",
        [riderId, orderId]
    );

    // Cambiar estado del repartidor a 'busy'
    await pool.query("UPDATE riders SET status='busy' WHERE id=$1", [riderId]);

    // Enviar notificaciones
    try {
        const { rows: updatedOrder } = await pool.query("SELECT client_id, restaurant_id, order_code FROM orders WHERE id=$1", [orderId]);
        if (updatedOrder.length > 0) {
            const o = updatedOrder[0];
            const { sendPushNotification } = require('../services/notificationService');
            if (o.restaurant_id) {
                sendPushNotification('restaurant', o.restaurant_id, 'Repartidor asignado', `El repartidor ha aceptado el pedido #${o.order_code || orderId}.`, { orderId: orderId.toString(), type: 'rider_assigned' });
            }
            if (o.client_id) {
                sendPushNotification('client', o.client_id, 'Repartidor en camino', `Un repartidor ha sido asignado para tu pedido #${o.order_code || orderId}.`, { orderId: orderId.toString(), type: 'rider_assigned' });
            }
        }
    } catch (err) {
        console.error('Error sending rider assigned notifications:', err);
    }

    res.json({ message: 'Pedido tomado con éxito.', status: 'rider_assigned' });
});

// ── PATCH /riders/orders/:id/pickup (recoger el pedido) ──────────────
router.patch('/orders/:id/pickup', auth, async (req, res) => {
    if (req.user.role !== 'rider') return res.status(403).json({ error: 'Solo repartidores' });

    const orderId = req.params.id;
    const riderId = req.user.id;

    // Verificar que el pedido le pertenece y está listo
    const { rows: order } = await pool.query("SELECT status, rider_id, restaurant_id FROM orders WHERE id=$1", [orderId]);
    if (order.length === 0) return res.status(404).json({ error: 'Pedido no encontrado' });
    
    if (order[0].rider_id !== riderId) {
        return res.status(403).json({ error: 'Este pedido no te pertenece' });
    }

    // No restringir que tenga que estar en 'ready'. Permitir si está en 'rider_assigned', 'preparing', 'accepted' o 'ready'
    const isFavor = order[0].restaurant_id === null;
    const allowedStatusForPickup = ['rider_assigned', 'preparing', 'accepted', 'ready'];
    if (!isFavor && !allowedStatusForPickup.includes(order[0].status)) {
        return res.status(400).json({ error: 'El pedido no se encuentra en un estado válido para ser recogido' });
    }

    await pool.query(
        "UPDATE orders SET status='in_delivery' WHERE id=$1",
        [orderId]
    );

    // Enviar notificación al cliente
    try {
        const { rows: updatedOrder } = await pool.query("SELECT client_id, order_code FROM orders WHERE id=$1", [orderId]);
        if (updatedOrder.length > 0 && updatedOrder[0].client_id) {
            const o = updatedOrder[0];
            const { sendPushNotification } = require('../services/notificationService');
            sendPushNotification('client', o.client_id, 'Pedido en camino', `Tu pedido #${o.order_code || orderId} ya está en camino a tu dirección.`, { orderId: orderId.toString(), type: 'in_delivery' });
        }
    } catch (err) {
        console.error('Error sending pickup notification:', err);
    }

    res.json({ message: 'Pedido recogido, ¡en camino!', status: 'in_delivery' });
});

// ── PATCH /riders/orders/:id/deliver (marcar como entregado) ──────
router.patch('/orders/:id/deliver', auth, async (req, res) => {
    if (req.user.role !== 'rider') return res.status(403).json({ error: 'Solo repartidores' });

    const orderId = req.params.id;
    const riderId = req.user.id;

    await pool.query(
        "UPDATE orders SET status='delivered', delivered_at=NOW() WHERE id=$1 AND rider_id=$2",
        [orderId, riderId]
    );

    // Volver a poner al repartidor como disponible solo si no le quedan pedidos activos
    try {
        const { rows: remainingActive } = await pool.query(
            "SELECT id FROM orders WHERE rider_id = $1 AND status IN ('rider_assigned', 'ready', 'in_delivery', 'preparing')",
            [riderId]
        );
        if (remainingActive.length === 0) {
            await pool.query("UPDATE riders SET status='online' WHERE id=$1", [riderId]);
        }
    } catch (err) {
        console.error('Error checking remaining active orders for rider:', err);
    }

    // Enviar notificaciones de entrega
    try {
        const { rows: updatedOrder } = await pool.query("SELECT client_id, restaurant_id, order_code FROM orders WHERE id=$1", [orderId]);
        if (updatedOrder.length > 0) {
            const o = updatedOrder[0];
            const { sendPushNotification } = require('../services/notificationService');
            if (o.client_id) {
                sendPushNotification('client', o.client_id, 'Pedido entregado', `¡Tu pedido #${o.order_code || orderId} ha sido entregado! ¡Buen provecho!`, { orderId: orderId.toString(), type: 'delivered' });
            }
            if (o.restaurant_id) {
                sendPushNotification('restaurant', o.restaurant_id, 'Pedido entregado', `El pedido #${o.order_code || orderId} ha sido entregado al cliente.`, { orderId: orderId.toString(), type: 'delivered' });
            }
        }
    } catch (err) {
        console.error('Error sending delivery notifications:', err);
    }

    res.json({ message: 'Pedido entregado' });
});

// ── GET /riders/orders/history (historial de pedidos entregados) ──────
router.get('/orders/history', auth, async (req, res) => {
    if (req.user.role !== 'rider') return res.status(403).json({ error: 'Solo repartidores' });

    const { rows: riderRows } = await pool.query('SELECT commission FROM riders WHERE id = $1', [req.user.id]);
    const riderCommission = parseFloat(riderRows[0]?.commission || 60);

    try {
        const { rows } = await pool.query(
            `SELECT o.*, o.tip::FLOAT, 
                    COALESCE(r.name, 'Pakiip Favor') as restaurant_name, 
                    COALESCE(r.address, o.pickup_address) as restaurant_address, 
                    COALESCE(r.phone, o.sender_phone) as restaurant_phone
             FROM orders o
             LEFT JOIN restaurants r ON o.restaurant_id = r.id
             WHERE o.rider_id = $1 AND o.status = 'delivered'
             ORDER BY o.delivered_at DESC`,
            [req.user.id]
        );

        const historyWithEarnings = rows.map(o => ({
            ...o,
            rider_earning: parseFloat(((parseFloat(o.delivery_fee || 0) * riderCommission) / 100).toFixed(2)),
            rider_commission_pct: riderCommission
        }));

        res.json(historyWithEarnings);
    } catch (e) {
        console.error(e);
        res.status(500).json({ error: 'Error al obtener el historial' });
    }
});

// ── GET /riders/earnings (resumen de ganancias y porcentaje) ──────
router.get('/earnings', auth, async (req, res) => {
    if (req.user.role !== 'rider') return res.status(403).json({ error: 'Solo repartidores' });

    try {
        // 1. Obtener comisión del repartidor
        const { rows: riderRows } = await pool.query('SELECT commission FROM riders WHERE id = $1', [req.user.id]);
        const commission = parseFloat(riderRows[0].commission || 60);

        // 2. Obtener pedidos entregados y calcular ganancias basadas EN DELIVERY_FEE
        const { rows: orders } = await pool.query(
            `SELECT id, order_code, delivery_fee, tip::FLOAT, service_fee::FLOAT, created_at, delivered_at, total, rider_paid
             FROM orders 
             WHERE rider_id = $1 AND status IN ('delivered', 'completed')
             ORDER BY delivered_at DESC`,
            [req.user.id]
        );

        let totalEarnings = 0;
        let pendingPayout = 0;
        let totalTips = 0;
        const history = orders.map(o => {
            const fee = parseFloat(o.delivery_fee || 0);
            const tip = parseFloat(o.tip || 0);
            const commissionAmount = (fee * commission) / 100;
            const totalPayout = commissionAmount + tip;
            
            totalEarnings += totalPayout;
            if (!o.rider_paid) {
                pendingPayout += totalPayout;
            }
            totalTips += tip;
            
            return {
                ...o,
                commission_amount: commissionAmount.toFixed(2),
                payout: totalPayout.toFixed(2),
                tip: tip.toFixed(2),
                commission_applied: commission,
                rider_paid: o.rider_paid || false
            };
        });

        // 3. Robust timezone-aware matching for "TODAY"
        const todayLima = new Date().toLocaleDateString('en-CA', { timeZone: 'America/Lima' }); 
        
        const todayOrders = history.filter(o => {
            if (!o.delivered_at) return false;
            const deliveredDate = new Date(o.delivered_at).toLocaleDateString('en-CA', { timeZone: 'America/Lima' });
            return deliveredDate === todayLima;
        });

        res.json({
            commission_percentage: commission,
            total_earnings: totalEarnings.toFixed(2),
            pending_payout: pendingPayout.toFixed(2),
            total_tips: totalTips.toFixed(2),
            orders_count: orders.length,
            today: {
                count: todayOrders.length,
                earnings: todayOrders.reduce((acc, o) => acc + parseFloat(o.payout), 0).toFixed(2),
                commission_only: todayOrders.reduce((acc, o) => acc + parseFloat(o.commission_amount), 0).toFixed(2),
                tips_only: todayOrders.reduce((acc, o) => acc + parseFloat(o.tip), 0).toFixed(2)
            },
            history
        });
    } catch (e) {
        console.error(e);
        res.status(500).json({ error: 'Error al calcular ganancias' });
    }
});

// ── DELETE /riders/:id ────────────────────────────────────────────
router.delete('/:id', auth, async (req, res) => {
    await pool.query('DELETE FROM riders WHERE id=$1', [req.params.id]);
    res.json({ message: 'Repartidor eliminado' });
});

module.exports = router;
