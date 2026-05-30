const router = require('express').Router();
const pool = require('../db');
const auth = require('../middleware/auth');

// ── Asegurar tablas ───────────────────────────────────────────────
async function ensureTables() {
    // 1. Tabla de categorías globales (Ej: Pollo, Parrillas, Pizza)
    await pool.query(`
        CREATE TABLE IF NOT EXISTS global_categories (
            id    SERIAL PRIMARY KEY,
            name  VARCHAR(100) NOT NULL UNIQUE,
            image_url TEXT,
            active BOOLEAN DEFAULT true,
            created_at TIMESTAMP DEFAULT NOW()
        )
    `);

    // 2. Tabla intermedia (Muchos a Muchos)
    await pool.query(`
        CREATE TABLE IF NOT EXISTS restaurant_category_map (
            restaurant_id INTEGER REFERENCES restaurants(id) ON DELETE CASCADE,
            category_id   INTEGER REFERENCES global_categories(id) ON DELETE CASCADE,
            PRIMARY KEY (restaurant_id, category_id)
        )
    `);
}
ensureTables().catch(console.error);

// ── GET /restaurant-categories/public (Clientes) ──────────────────
router.get('/public', async (req, res) => {
    try {
        const { rows } = await pool.query('SELECT * FROM global_categories WHERE active = true ORDER BY name');
        res.json(rows);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ── GET /restaurant-categories (Admin) ────────────────────────────
router.get('/', auth, async (req, res) => {
    try {
        const { rows } = await pool.query('SELECT * FROM global_categories ORDER BY id DESC');
        res.json(rows);
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ── POST /restaurant-categories (Admin crea) ──────────────────────
router.post('/', auth, async (req, res) => {
    const { name, image_url } = req.body;
    if (!name) return res.status(400).json({ error: 'Nombre requerido' });

    try {
        const { rows } = await pool.query(
            'INSERT INTO global_categories (name, image_url) VALUES ($1, $2) RETURNING *',
            [name, image_url || null]
        );
        res.status(201).json(rows[0]);
    } catch (e) {
        if (e.code === '23505') return res.status(409).json({ error: 'La categoría ya existe' });
        res.status(500).json({ error: e.message });
    }
});

// ── PUT /restaurant-categories/:id (Admin edita) ──────────────────
router.put('/:id', auth, async (req, res) => {
    const { name, image_url, active } = req.body;
    try {
        await pool.query(
            'UPDATE global_categories SET name=$1, image_url=$2, active=$3 WHERE id=$4',
            [name, image_url, active ?? true, req.params.id]
        );
        res.json({ message: 'Categoría actualizada' });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// ── DELETE /restaurant-categories/:id ─────────────────────────────
router.delete('/:id', auth, async (req, res) => {
    try {
        await pool.query('DELETE FROM global_categories WHERE id=$1', [req.params.id]);
        res.json({ message: 'Categoría eliminada' });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

module.exports = router;
