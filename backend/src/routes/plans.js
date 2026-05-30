const router = require('express').Router();
const pool = require('../db');
const auth = require('../middleware/auth');

// ── GET /plans ───────────────────────────────────────────────────
router.get('/', async (req, res) => {
    const { rows } = await pool.query('SELECT * FROM plans ORDER BY price ASC');
    res.json(rows);
});

// ── PUT /plans/:id ───────────────────────────────────────────────
router.put('/:id', auth, async (req, res) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Prohibido' });

    const { name, price, duration_days, features, commission_rate } = req.body;
    await pool.query(
        'UPDATE plans SET name=$1, price=$2, duration_days=$3, features=$4, commission_rate=$5 WHERE id=$6',
        [name, price, duration_days, features, commission_rate || 0, req.params.id]);
    res.json({ message: 'Plan actualizado' });
});

module.exports = router;
