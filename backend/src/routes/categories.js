const router = require('express').Router();
const pool = require('../db');
const auth = require('../middleware/auth');

// --- Crear tabla categories si no existe ---
async function ensureCategoriesTable() {
    // Primero asegurar la tabla
    await pool.query(`
    CREATE TABLE IF NOT EXISTS categories (
      id SERIAL PRIMARY KEY,
      restaurant_id INTEGER REFERENCES restaurants(id) ON DELETE CASCADE,
      name VARCHAR(100) NOT NULL,
      position INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT NOW()
    )
  `);
    // Asegurar que la columna position existe (por si se creó antes)
    try {
        await pool.query('ALTER TABLE categories ADD COLUMN IF NOT EXISTS position INTEGER DEFAULT 0');
    } catch (e) { }
}
ensureCategoriesTable().catch(console.error);

// --- GET /categories (propias del restaurante) ---
router.get('/', auth, async (req, res) => {
    if (req.user.role !== 'restaurant') return res.status(403).json({ error: 'Solo restaurantes' });
    const { rows } = await pool.query(
        'SELECT * FROM categories WHERE restaurant_id = $1 ORDER BY position ASC, name ASC',
        [req.user.id]
    );
    res.json(rows);
});

// --- GET /categories/restaurant/:id (Público) ---
router.get('/restaurant/:id', async (req, res) => {
    const { rows } = await pool.query(
        'SELECT * FROM categories WHERE restaurant_id = $1 ORDER BY position ASC, name ASC',
        [req.params.id]
    );
    res.json(rows);
});

// --- POST /categories ---
router.post('/', auth, async (req, res) => {
    if (req.user.role !== 'restaurant') return res.status(403).json({ error: 'Solo restaurantes' });
    const { name } = req.body;
    // Obtener la posición más alta
    const posRes = await pool.query('SELECT MAX(position) FROM categories WHERE restaurant_id = $1', [req.user.id]);
    const nextPos = (posRes.rows[0].max || 0) + 1;

    const { rows } = await pool.query(
        'INSERT INTO categories (restaurant_id, name, position) VALUES ($1, $2, $3) RETURNING *',
        [req.user.id, name, nextPos]
    );
    res.status(201).json(rows[0]);
});

// --- PUT /categories/:id ---
router.put('/:id', auth, async (req, res) => {
    if (req.user.role !== 'restaurant') return res.status(403).json({ error: 'Solo restaurantes' });
    const { name } = req.body;
    await pool.query(
        'UPDATE categories SET name = $1 WHERE id = $2 AND restaurant_id = $3',
        [name, req.params.id, req.user.id]
    );
    res.json({ message: 'Actualizado' });
});

// --- POST /categories/reorder ---
router.post('/reorder', auth, async (req, res) => {
    if (req.user.role !== 'restaurant') return res.status(403).json({ error: 'Solo restaurantes' });
    const { ids } = req.body;
    if (!ids || !Array.isArray(ids)) return res.status(400).json({ error: 'Lista de IDs requerida' });

    try {
        for (let i = 0; i < ids.length; i++) {
            await pool.query(
                'UPDATE categories SET position = $1 WHERE id = $2 AND restaurant_id = $3',
                [i, ids[i], req.user.id]
            );
        }
        res.json({ message: 'Orden guardado' });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// --- DELETE /categories/:id ---
router.delete('/:id', auth, async (req, res) => {
    await pool.query('DELETE FROM categories WHERE id = $1 AND restaurant_id = $2', [req.params.id, req.user.id]);
    res.json({ message: 'Categoría eliminada' });
});

module.exports = router;
