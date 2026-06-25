const router = require('express').Router();
const pool = require('../db');
const auth = require('../middleware/auth');

// ── Asegurar columnas extra en orders ────────────────────────────
async function ensureOrderColumns() {
    try {
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_method VARCHAR(30) DEFAULT \'cash\'');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS client_id INTEGER DEFAULT NULL');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT NULL');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS items JSONB DEFAULT \'[]\'');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_proof_url TEXT DEFAULT NULL');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_code VARCHAR(10) DEFAULT NULL');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS service_fee DECIMAL(10,2) DEFAULT 0.00');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMP DEFAULT NULL');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS restaurant_commission DECIMAL(10,2) DEFAULT 0.00');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS restaurant_payout DECIMAL(10,2) DEFAULT 0.00');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS client_lat DECIMAL(10,7) DEFAULT NULL');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS tip DECIMAL(10,2) DEFAULT 0.00');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_address TEXT DEFAULT NULL');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_lat DECIMAL(10,7) DEFAULT NULL');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_lng DECIMAL(10,7) DEFAULT NULL');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS recipient_name VARCHAR(255) DEFAULT NULL');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS recipient_phone VARCHAR(20) DEFAULT NULL');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS sender_name VARCHAR(255) DEFAULT NULL');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS sender_phone VARCHAR(20) DEFAULT NULL');
        await pool.query('ALTER TABLE orders ADD COLUMN IF NOT EXISTS discount DECIMAL(10,2) DEFAULT 0.00');
    } catch (e) { }
}

function generateOrderCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Avoid confusing O/0, I/1
    let code = '';
    for (let i = 0; i < 6; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
}

// ── Auto-cancelar pedidos expirados (49 min) ─────────────────────
async function autoCancelOldOrders() {
    try {
        // 1. Pendientes por más de 49 min
        await pool.query(
            "UPDATE orders SET status = 'cancelled' WHERE status = 'pending' AND created_at < NOW() - INTERVAL '49 minutes'"
        );
        // 2. Aceptados/En preparación por más de 2 horas desde que fueron aceptados
        await pool.query(
            "UPDATE orders SET status = 'cancelled' WHERE status IN ('accepted', 'preparing') AND accepted_at < NOW() - INTERVAL '2 hours'"
        );
    } catch (e) {
        console.error("Error in autoCancelOldOrders:", e);
    }
}

// Asegurar que las columnas existan al cargar el módulo
ensureOrderColumns();

// ── POST /orders  (cliente o restaurante crea pedido) ──────────────────
router.post('/', auth, async (req, res) => {
    if (req.user.role !== 'client' && req.user.role !== 'restaurant' && req.user.role !== 'rider') {
        return res.status(403).json({ error: 'No autorizado' });
    }

    // console.log(`[Orders] Creando nuevo pedido...`);

    let {
        restaurant_id: bodyRestId,
        items,           // [{ name, qty, price, options: [{name,price}] }]
        total,
        delivery_fee = 3.50,
        payment_method = 'cash',  // 'cash' | 'yape'
        client_address,
        client_phone,
        client_name,
        notes,
        payment_proof_url,
        service_fee = 0.00,
        tip = 0.00,
        pickup_address,
        pickup_lat,
        pickup_lng,
        recipient_name,
        recipient_phone,
        sender_name,
        sender_phone,
        discount = 0.00,
        coupon_code = null,
    } = req.body;
    tip = parseFloat(tip) || 0;

    // Si no viene service_fee, traer el default de app_config
    if (!service_fee || service_fee === 0) {
        try {
            const { rows: configRows } = await pool.query('SELECT service_fee FROM app_config LIMIT 1');
            if (configRows.length > 0) {
                service_fee = parseFloat(configRows[0].service_fee || 0);
            }
        } catch (e) { console.error('Error fetching global service fee:', e); }
    }

    // Para Pakiip Favor (cliente sin restaurante) solo requerimos items y total
    if (req.user.role === 'client' && (!items || !total)) {
        return res.status(400).json({ error: 'items y total son requeridos' });
    }

    const restaurant_id = req.user.role === 'restaurant' ? req.user.id : (bodyRestId || null);
    const final_client_name = req.user.role === 'client' ? (req.user.name || 'Cliente') : (client_name || 'Cliente Manual');
    const final_client_id = req.user.role === 'client' ? req.user.id : null;

    const orderCode = generateOrderCode();

    // Obtener comisión del restaurante según su configuración específica
    let restaurant_commission = 0;
    let restaurant_payout = parseFloat(total) + parseFloat(discount);
    try {
        if (!restaurant_id) throw new Error('No restaurant'); // Pakiip Favor - sin comisión
        const resData = await pool.query(
            `SELECT r.commission_rate as custom_rate, r.plan_id
             FROM restaurants r 
             WHERE r.id = $1`,
             [restaurant_id]
        );
        if (resData.rows.length > 0) {
            const planId = parseInt(resData.rows[0].plan_id);
            let rate = 0;

            // Si es Pakiip Emprende (ID 1), usamos su tasa personalizada
            if (planId === 1) {
                rate = parseFloat(resData.rows[0].custom_rate || 0);
            }
            // Si es Pakiip Empresarial (ID 2), la comisión es 0%
            else if (planId === 2) {
                rate = 0;
            }

            // La comisión se cobra SOLO sobre el valor de los productos (total - delivery - service)
            // O mejor aún, la suma de los items para ser exactos.
            const productSubtotal = items.reduce((acc, item) => {
                const optionsTotal = (item.options || []).reduce((sum, opt) => sum + (parseFloat(opt.price) || 0), 0);
                const itemTotal = (parseFloat(item.price) || 0) + optionsTotal;
                const qty = item.qty || item.quantity || 1;
                return acc + (itemTotal * qty);
            }, 0);

            restaurant_commission = productSubtotal * (rate / 100);
            restaurant_payout = (parseFloat(total) + parseFloat(discount)) - restaurant_commission;
        }
    } catch (e) {
        console.error('Error calculating restaurant commission:', e);
    }

    const { rows } = await pool.query(
        `INSERT INTO orders
            (restaurant_id, client_id, client_name, client_phone, client_address,
             status, total, delivery_fee, service_fee, payment_method, items, notes, payment_proof_url, order_code,
             restaurant_commission, restaurant_payout, client_lat, client_lng, tip,
             pickup_address, pickup_lat, pickup_lng, recipient_name, recipient_phone,
             sender_name, sender_phone, discount, coupon_code)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26, $27, $28)
         RETURNING id, status, created_at, order_code`,
        [
            restaurant_id,
            final_client_id,
            final_client_name,
            client_phone || null,
            client_address || null,
            (req.body.status && (req.user.role === 'restaurant' || req.user.role === 'client' || req.user.role === 'rider')) ? req.body.status : 'pending',
            total,
            delivery_fee,
            service_fee,
            payment_method,
            JSON.stringify(items),
            notes || null,
            payment_proof_url || null,
            orderCode,
            restaurant_commission,
            restaurant_payout,
            req.body.client_lat || null,
            req.body.client_lng || null,
            tip,
            pickup_address || null,
            pickup_lat || null,
            pickup_lng || null,
            recipient_name || null,
            recipient_phone || null,
            sender_name || null,
            sender_phone || null,
            parseFloat(discount) || 0.00,
            coupon_code || null,
        ]
    );

    console.log(`[Orders] Pedido insertado con éxito, ID: ${rows[0].id}`);

    // Enviar notificación push al restaurante
    try {
        if (restaurant_id) {
            const { sendPushNotification } = require('../services/notificationService');
            sendPushNotification(
                'restaurant',
                restaurant_id,
                '¡Nuevo pedido recibido!',
                `Tienes un nuevo pedido #${rows[0].order_code || rows[0].id}. ¡Confírmalo ahora!`,
                { orderId: rows[0].id.toString(), type: 'new_order' }
            );
        }
    } catch (err) {
        console.error('Error sending new order notification:', err);
    }

    res.status(201).json({
        message: 'Pedido creado',
        order_id: rows[0].id,
        order_code: rows[0].order_code,
        status: rows[0].status,
        created_at: rows[0].created_at,
    });
});

// ── GET /orders/my  (cliente ve sus propios pedidos) ─────────────
router.get('/my', auth, async (req, res) => {
    if (req.user.role !== 'client') return res.status(403).json({ error: 'Solo clientes' });

    const { rows } = await pool.query(
        `SELECT o.id, o.status, o.total, o.delivery_fee, o.service_fee, o.payment_method,
                o.client_address, o.items, o.notes, o.created_at, o.order_code, o.payment_proof_url,
                o.tip::FLOAT, o.pickup_address, o.sender_name, o.recipient_name, o.discount::FLOAT,
                COALESCE(r.name, 'Pakiip Favor') AS restaurant_name, 
                r.logo_url AS restaurant_logo
         FROM orders o
         LEFT JOIN restaurants r ON r.id = o.restaurant_id
         WHERE o.client_id = $1
         ORDER BY o.created_at DESC`,
        [req.user.id]
    );

    res.json(rows);
});

// ── GET /orders/restaurant  (restaurante ve sus pedidos) ─────────
router.get('/restaurant/all', auth, async (req, res) => {
    if (req.user.role !== 'restaurant') return res.status(403).json({ error: 'Solo restaurantes' });

    await autoCancelOldOrders(); // Limpiar expirados antes de listar

    // Fetch all orders for this restaurant, pending first, then accepted, etc
    const { rows } = await pool.query(
        `SELECT o.id, o.status, o.total, o.delivery_fee, o.service_fee, o.payment_method,
                o.restaurant_commission::FLOAT, o.restaurant_payout::FLOAT,
                o.client_address, o.client_name, o.client_phone,
                o.items, o.notes, o.created_at, o.delivered_at,
                o.payment_proof_url, o.order_code, o.tip::FLOAT, o.discount::FLOAT
         FROM orders o
         WHERE o.restaurant_id = $1
         ORDER BY o.created_at DESC`,
        [req.user.id]
    );

    res.json(rows);
});

// ── GET /orders/:id  (detalle de un pedido) ──────────────────────
router.get('/:id', auth, async (req, res) => {

    const { rows } = await pool.query(
        `SELECT o.id, o.status, o.total, o.delivery_fee, o.service_fee, o.payment_method,
                o.client_address, o.client_name, o.client_phone,
                o.items, o.notes, o.created_at, o.delivered_at, o.order_code, o.payment_proof_url,
                o.tip::FLOAT, o.discount::FLOAT,
                COALESCE(r.name, 'Pakiip Favor') AS restaurant_name, 
                r.logo_url AS restaurant_logo, 
                COALESCE(r.phone, o.sender_phone) AS restaurant_phone
         FROM orders o
         LEFT JOIN restaurants r ON r.id = o.restaurant_id
         WHERE o.id = $1`,
        [req.params.id]
    );

    if (rows.length === 0) return res.status(404).json({ error: 'Pedido no encontrado' });

    // Solo el cliente dueño o el restaurante pueden verlo
    const order = rows[0];
    res.json(order);
});


// ── PATCH /orders/:id/status  (restaurante actualiza estado) ─────
router.patch('/:id/status', auth, async (req, res) => {
    const { status } = req.body;
    const orderId = req.params.id;

    // Estados válidos:
    // pending -> accepted/preparing -> rider_assigned -> ready -> in_delivery -> delivered
    const validStatuses = ['pending', 'accepted', 'preparing', 'rider_assigned', 'ready', 'in_delivery', 'delivered', 'cancelled'];
    if (!validStatuses.includes(status)) {
        return res.status(400).json({ error: `Estado inválido. Válidos: ${validStatuses.join(', ')}` });
    }

    // Check current status and permissions
    const { rows: currentOrder } = await pool.query('SELECT status, client_id, restaurant_id, rider_id, order_code FROM orders WHERE id = $1', [orderId]);
    if (currentOrder.length === 0) return res.status(404).json({ error: 'Pedido no encontrado' });

    const order = currentOrder[0];

    // If order is already cancelled, it cannot be moved to any other status
    if (order.status === 'cancelled') {
        return res.status(400).json({ error: 'El pedido ya está cancelado y no puede ser modificado' });
    }

    // Client can only cancel if pending
    if (req.user.role === 'client') {
        if (order.client_id !== req.user.id) return res.status(403).json({ error: 'No tienes permiso' });
        if (status !== 'cancelled') return res.status(400).json({ error: 'Solo puedes cancelar tu pedido' });
        if (order.status !== 'pending') return res.status(400).json({ error: 'No se puede cancelar un pedido ya aceptado' });
    }

    // Restaurant restrictions
    if (req.user.role === 'restaurant') {
        if (order.restaurant_id !== req.user.id) return res.status(403).json({ error: 'No tienes permiso' });
        
        // El restaurante NO puede marcar como entregado al motorizado (in_delivery) 
        // ni como entregado final (delivered). Eso lo hace el motorizado.
        if (status === 'in_delivery' || status === 'delivered') {
            return res.status(403).json({ error: 'El restaurante no puede marcar el pedido como recogido o entregado. Debe hacerlo el motorizado.' });
        }
    }

    let extra = '';
    if (status === 'delivered') {
        extra = ', delivered_at = NOW()';
    } else if (status === 'accepted' || status === 'preparing') {
        extra = ', accepted_at = COALESCE(accepted_at, NOW())';
    }

    await pool.query(
        `UPDATE orders SET status = $1 ${extra} WHERE id = $2`,
        [status, orderId]
    );

    // Enviar notificaciones correspondientes al cambio de estado
    try {
        const { sendPushNotification, notifyAllAvailableRiders } = require('../services/notificationService');
        
        // Notificaciones al cliente
        if (order.client_id) {
            let title = '';
            let body = '';
            if (status === 'accepted' || status === 'preparing') {
                title = 'Pedido aceptado';
                body = `¡Tu pedido #${order.order_code || orderId} ha sido aceptado por el restaurante y está en preparación!`;
            } else if (status === 'ready') {
                title = 'Pedido listo';
                body = `¡Tu pedido #${order.order_code || orderId} ya está listo y a la espera de ser recogido!`;
            } else if (status === 'cancelled') {
                title = 'Pedido cancelado';
                body = `Tu pedido #${order.order_code || orderId} ha sido cancelado.`;
            }
            if (title && body) {
                sendPushNotification('client', order.client_id, title, body, { orderId: orderId.toString(), type: status });
            }
        }

        // Notificaciones a los repartidores
        if (status === 'ready') {
            if (order.rider_id) {
                // Si ya tiene motorizado asignado, notificarle a él directamente
                sendPushNotification('rider', order.rider_id, 'Pedido listo para recoger', `El pedido #${order.order_code || orderId} ya está listo para ser recogido en el restaurante.`, { orderId: orderId.toString(), type: 'ready' });
            } else {
                // Si no tiene motorizado asignado, notificar a todos los motorizados disponibles
                notifyAllAvailableRiders('¡Pedido disponible!', `Hay un pedido listo para entregar. ¡Acéptalo ahora!`, { orderId: orderId.toString(), type: 'available_order' });
            }
        }
    } catch (err) {
        console.error('Error sending status change notifications:', err);
    }

    res.json({ message: 'Estado actualizado', status });
});

// ── Llamada inicial para asegurar estructura ─────────────────────
ensureOrderColumns();

module.exports = router;
