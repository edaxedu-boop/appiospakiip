const router = require('express').Router();
const pool = require('../db');
const auth = require('../middleware/auth');

// ── Asegurar Tabla de Cupones ──────────────────────────────────────
async function ensureTable() {
    await pool.query(`
        CREATE TABLE IF NOT EXISTS coupons (
            id SERIAL PRIMARY KEY,
            code VARCHAR(50) UNIQUE NOT NULL,
            discount_type VARCHAR(20) NOT NULL, -- 'fixed' o 'percent'
            discount_value DECIMAL(10,2) NOT NULL,
            min_order_value DECIMAL(10,2) DEFAULT 0.00,
            restaurant_scope VARCHAR(20) DEFAULT 'all', -- 'all' o 'specific'
            applicable_restaurants INT[] DEFAULT '{}',
            active BOOLEAN DEFAULT true,
            created_at TIMESTAMP DEFAULT NOW()
        )
    `);
    await pool.query(`
        ALTER TABLE coupons ADD COLUMN IF NOT EXISTS usage_limit INT DEFAULT NULL;
    `);
    await pool.query(`
        ALTER TABLE orders ADD COLUMN IF NOT EXISTS coupon_code VARCHAR(50)
    `);
}
ensureTable().catch(console.error);

// ── GET /coupons (Admin: listar todos) ─────────────────────────────
router.get('/', auth, async (req, res) => {
    try {
        const { rows } = await pool.query(`
            SELECT c.*, 
                   (SELECT COUNT(*)::int FROM orders o WHERE o.coupon_code = c.code) AS usage_count,
                   ARRAY(
                       SELECT r.name 
                       FROM restaurants r 
                       WHERE r.id = ANY(c.applicable_restaurants)
                   ) AS restaurant_names
            FROM coupons c
            ORDER BY c.created_at DESC
        `);
        // Mapear applicable_restaurants a enteros simples en js
        const mapped = rows.map(r => ({
            ...r,
            discount_value: parseFloat(r.discount_value),
            min_order_value: parseFloat(r.min_order_value),
            usage_limit: r.usage_limit !== null ? parseInt(r.usage_limit) : null,
            usage_count: parseInt(r.usage_count || 0),
            applicable_restaurants: r.applicable_restaurants || []
        }));
        res.json(mapped);
    } catch (e) {
        console.error(e);
        res.status(500).json({ error: 'Error al listar cupones' });
    }
});

// ── POST /coupons (Admin: crear cupón) ──────────────────────────────
router.post('/', auth, async (req, res) => {
    try {
        let { code, discount_type, discount_value, min_order_value, restaurant_scope, applicable_restaurants, usage_limit } = req.body;
        
        if (!code || !discount_type || discount_value === undefined) {
            return res.status(400).json({ error: 'Código, tipo de descuento y valor son requeridos' });
        }

        code = code.trim().toUpperCase();
        if (discount_type !== 'fixed' && discount_type !== 'percent') {
            return res.status(400).json({ error: 'Tipo de descuento inválido (debe ser fixed o percent)' });
        }

        const value = parseFloat(discount_value);
        if (isNaN(value) || value <= 0) {
            return res.status(400).json({ error: 'El valor de descuento debe ser mayor a 0' });
        }

        const minVal = parseFloat(min_order_value) || 0.00;
        const scope = restaurant_scope === 'specific' ? 'specific' : 'all';
        const restIds = Array.isArray(applicable_restaurants) ? applicable_restaurants.map(Number) : [];
        const limitVal = usage_limit !== undefined && usage_limit !== null && usage_limit !== '' ? parseInt(usage_limit) : null;

        // Insertar
        const { rows } = await pool.query(
            `INSERT INTO coupons (code, discount_type, discount_value, min_order_value, restaurant_scope, applicable_restaurants, usage_limit)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             RETURNING *`,
            [code, discount_type, value, minVal, scope, restIds, limitVal]
        );

        res.status(201).json(rows[0]);
    } catch (e) {
        if (e.code === '23505') { // Llave duplicada en postgres
            return res.status(400).json({ error: 'El código de cupón ya existe' });
        }
        console.error(e);
        res.status(500).json({ error: 'Error al crear cupón' });
    }
});

// ── PUT /coupons/:id (Admin: editar/activar/desactivar) ────────────────
router.put('/:id', auth, async (req, res) => {
    try {
        const { id } = req.params;
        let { code, discount_type, discount_value, min_order_value, restaurant_scope, applicable_restaurants, active, usage_limit } = req.body;

        const { rows: check } = await pool.query('SELECT * FROM coupons WHERE id = $1', [id]);
        if (check.length === 0) return res.status(404).json({ error: 'Cupón no encontrado' });

        code = code ? code.trim().toUpperCase() : check[0].code;
        const type = discount_type || check[0].discount_type;
        const value = discount_value !== undefined ? parseFloat(discount_value) : parseFloat(check[0].discount_value);
        const minVal = min_order_value !== undefined ? parseFloat(min_order_value) : parseFloat(check[0].min_order_value);
        const scope = restaurant_scope || check[0].restaurant_scope;
        const restIds = Array.isArray(applicable_restaurants) ? applicable_restaurants.map(Number) : check[0].applicable_restaurants;
        const isActive = active !== undefined ? !!active : check[0].active;
        const limitVal = usage_limit !== undefined ? (usage_limit !== null && usage_limit !== '' ? parseInt(usage_limit) : null) : check[0].usage_limit;

        await pool.query(
            `UPDATE coupons
             SET code=$1, discount_type=$2, discount_value=$3, min_order_value=$4, restaurant_scope=$5, applicable_restaurants=$6, active=$7, usage_limit=$8
             WHERE id=$9`,
            [code, type, value, minVal, scope, restIds, isActive, limitVal, id]
        );

        res.json({ message: 'Cupón actualizado correctamente' });
    } catch (e) {
        if (e.code === '23505') {
            return res.status(400).json({ error: 'El código de cupón ya existe' });
        }
        console.error(e);
        res.status(500).json({ error: 'Error al actualizar cupón' });
    }
});

// ── DELETE /coupons/:id (Admin: eliminar cupón) ─────────────────────
router.delete('/:id', auth, async (req, res) => {
    try {
        const { id } = req.params;
        const { rowCount } = await pool.query('DELETE FROM coupons WHERE id = $1', [id]);
        if (rowCount === 0) return res.status(404).json({ error: 'Cupón no encontrado' });
        res.json({ message: 'Cupón eliminado correctamente' });
    } catch (e) {
        console.error(e);
        res.status(500).json({ error: 'Error al eliminar cupón' });
    }
});

// ── POST /coupons/validate (Público/Cliente: validar/aplicar cupón) ──────
router.post('/validate', async (req, res) => {
    try {
        let { code, restaurant_id, subtotal } = req.body;

        if (!code || !restaurant_id || subtotal === undefined) {
            return res.status(400).json({ error: 'Código, restaurante y subtotal son requeridos' });
        }

        code = code.trim().toUpperCase();
        const restId = parseInt(restaurant_id);
        const sub = parseFloat(subtotal);

        const { rows } = await pool.query(
            'SELECT * FROM coupons WHERE code = $1 AND active = true',
            [code]
        );

        if (rows.length === 0) {
            return res.json({ valid: false, error: 'El cupón ingresado no existe o no está activo' });
        }

        const coupon = rows[0];

        // 1. Validar monto mínimo
        const minOrder = parseFloat(coupon.min_order_value);
        if (sub < minOrder) {
            return res.json({ 
                valid: false, 
                error: `El pedido mínimo para este cupón es de S/. ${minOrder.toFixed(2)}` 
            });
        }

        // 1.5 Validar límite de uso
        if (coupon.usage_limit !== null && coupon.usage_limit > 0) {
            const { rows: usageRows } = await pool.query(
                'SELECT COUNT(*)::int as count FROM orders WHERE coupon_code = $1',
                [coupon.code]
            );
            const count = usageRows[0]?.count || 0;
            if (count >= coupon.usage_limit) {
                return res.json({
                    valid: false,
                    error: 'Este cupón ha alcanzado el límite máximo de usos permitido'
                });
            }
        }

        // 2. Validar restaurante
        if (coupon.restaurant_scope === 'specific') {
            const allowedRests = coupon.applicable_restaurants || [];
            if (!allowedRests.includes(restId)) {
                return res.json({ 
                    valid: false, 
                    error: 'Este cupón no es válido para este restaurante' 
                });
            }
        }

        // 3. Calcular descuento
        const value = parseFloat(coupon.discount_value);
        let calculated = 0;
        if (coupon.discount_type === 'fixed') {
            calculated = value;
        } else if (coupon.discount_type === 'percent') {
            calculated = (sub * value) / 100;
        }

        // El descuento no puede exceder el subtotal
        if (calculated > sub) {
            calculated = sub;
        }

        res.json({
            valid: true,
            code: coupon.code,
            discount_type: coupon.discount_type,
            discount_value: value,
            calculated_discount: parseFloat(calculated.toFixed(2))
        });
    } catch (e) {
        console.error(e);
        res.status(500).json({ error: 'Error al validar cupón' });
    }
});

module.exports = router;
