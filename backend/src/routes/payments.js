const router = require('express').Router();
const pool = require('../db');
const auth = require('../middleware/auth');

// ── GET /payments  (listado de liquidaciones pendientes) ──────────
router.get('/', auth, async (req, res) => {
    const { rows } = await pool.query(
        `SELECT p.*, r.name AS rider_name, r.commission AS rider_commission
     FROM payments p
     JOIN riders r ON p.rider_id = r.id
     ORDER BY p.created_at DESC`);
    res.json(rows);
});

// ── POST /payments/generate  (generar liquidaciones del mes) ──────
router.post('/generate', auth, async (req, res) => {
    const { period_start, period_end } = req.body;
    if (!period_start || !period_end) return res.status(400).json({ error: 'period_start y period_end requeridos' });

    // Calcular totales por repartidor en ese período
    const { rows: summaries } = await pool.query(
        `SELECT o.rider_id,
            COUNT(*)        AS total_orders,
            SUM(o.total)    AS total_billing,
            r.commission    AS commission
     FROM orders o
     JOIN riders r ON o.rider_id = r.id
     WHERE o.status = 'delivered'
       AND o.delivered_at BETWEEN $1 AND $2
       AND o.rider_id IS NOT NULL
     GROUP BY o.rider_id, r.commission`,
        [period_start, period_end]);

    const inserted = [];
    for (const s of summaries) {
        const payout = (s.total_billing * s.commission) / 100;
        const { rows } = await pool.query(
            `INSERT INTO payments (rider_id, period_start, period_end, total_billing, total_orders, commission, total_payout)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
            [s.rider_id, period_start, period_end, s.total_billing, s.total_orders, s.commission, payout]);
        inserted.push(rows[0].id);
    }

    res.status(201).json({ message: `${inserted.length} liquidaciones generadas`, ids: inserted });
});

// ── PATCH /payments/:id/pay  (procesar pago) ──────────────────────
router.patch('/:id/pay', auth, async (req, res) => {
    await pool.query(
        `UPDATE payments SET status='paid', paid_at=NOW() WHERE id=$1`,
        [req.params.id]);
    res.json({ message: 'Pago procesado ✅' });
});

module.exports = router;
