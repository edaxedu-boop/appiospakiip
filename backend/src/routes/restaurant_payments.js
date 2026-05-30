const router = require('express').Router();
const pool = require('../db');
const auth = require('../middleware/auth');

// Listar liquidaciones de restaurantes
router.get('/', auth, async (req, res) => {
    try {
        const { rows } = await pool.query(`
            SELECT s.*, r.name as restaurant_name, r.plan_id
            FROM restaurant_settlements s
            JOIN restaurants r ON s.restaurant_id = r.id
            ORDER BY s.period_year DESC, s.period_month DESC, s.created_at DESC
        `);
        res.json(rows);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Generar liquidaciones para un mes específico
router.post('/generate', auth, async (req, res) => {
    const { month, year } = req.body;
    if (!month || !year) return res.status(400).json({ error: 'month y year requeridos' });

    try {
        // Buscar ventas del mes para restaurantes en plan Emprende (ID 1)
        const { rows: summaries } = await pool.query(`
            SELECT 
                r.id as restaurant_id,
                r.commission_rate,
                SUM(o.total) as total_sales,
                SUM(o.restaurant_commission) as total_commission
            FROM restaurants r
            JOIN orders o ON r.id = o.restaurant_id
            WHERE r.plan_id = 1
              AND o.status = 'delivered'
              AND EXTRACT(MONTH FROM o.delivered_at) = $1
              AND EXTRACT(YEAR FROM o.delivered_at) = $2
            GROUP BY r.id, r.commission_rate
        `, [month, year]);

        const inserted = [];
        for (const s of summaries) {
            const { rows } = await pool.query(`
                INSERT INTO restaurant_settlements (restaurant_id, period_month, period_year, total_sales, commission_rate, commission_amount)
                VALUES ($1, $2, $3, $4, $5, $6)
                ON CONFLICT (restaurant_id, period_month, period_year) DO UPDATE SET
                    total_sales = EXCLUDED.total_sales,
                    commission_amount = EXCLUDED.commission_amount
                RETURNING id
            `, [s.restaurant_id, month, year, s.total_sales, s.commission_rate, s.total_commission]);
            inserted.push(rows[0].id);
        }

        res.json({ message: `Se procesaron ${summaries.length} liquidaciones.`, count: inserted.length });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// Marcar como pagada
router.patch('/:id/pay', auth, async (req, res) => {
    try {
        await pool.query('UPDATE restaurant_settlements SET status = \'paid\', paid_at = NOW() WHERE id = $1', [req.params.id]);
        res.json({ message: 'Liquidación marcada como pagada ✅' });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

module.exports = router;
