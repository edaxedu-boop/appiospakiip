const router = require('express').Router();
const pool = require('../db');
const auth = require('../middleware/auth');

// ── Crear tabla products si no existe (llamado en app startup) ───
async function ensureProductsTable() {
    await pool.query(`
    CREATE TABLE IF NOT EXISTS products (
      id            SERIAL PRIMARY KEY,
      restaurant_id INTEGER REFERENCES restaurants(id) ON DELETE CASCADE,
      name          VARCHAR(255) NOT NULL,
      description   TEXT,
      price         DECIMAL(10,2) NOT NULL,
      category      VARCHAR(100),
      image_url     TEXT,
      available     BOOLEAN DEFAULT true,
      groups        JSONB DEFAULT '[]'::jsonb,
      created_at    TIMESTAMP DEFAULT NOW()
    )
  `);
    // Asegurar que la columna 'groups' exista si la tabla ya fue creada antes
    try {
        await pool.query("ALTER TABLE products ADD COLUMN IF NOT EXISTS groups JSONB DEFAULT '[]'::jsonb");
    } catch (e) { }
}
ensureProductsTable().catch(console.error);

// ── GET /products/restaurant/:id  (público — para clientes) ──────
router.get('/restaurant/:id', async (req, res) => {
    const { rows } = await pool.query(
        `SELECT id, name, description, price, category, image_url, available, groups
     FROM products
     WHERE restaurant_id = $1 AND available = true
     ORDER BY category, name`,
        [req.params.id]);
    res.json(rows);
});

// ── GET /products/my  (restaurante ve sus propios productos) ──────
router.get('/my', auth, async (req, res) => {
    if (req.user.role !== 'restaurant') return res.status(403).json({ error: 'Solo restaurantes' });
    const { rows } = await pool.query(
        `SELECT * FROM products WHERE restaurant_id = $1 ORDER BY category, name`,
        [req.user.id]);
    res.json(rows);
});

// ── POST /products  (restaurante crea producto) ───────────────────
router.post('/', auth, async (req, res) => {
    if (req.user.role !== 'restaurant') return res.status(403).json({ error: 'Solo restaurantes' });
    const { name, description, price, category, image_url, groups } = req.body;
    if (!name || !price) return res.status(400).json({ error: 'Nombre y precio requeridos' });

    const { rows } = await pool.query(
        `INSERT INTO products (restaurant_id, name, description, price, category, image_url, groups)
     VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
        [req.user.id, name, description || null, price, category || 'General', image_url || null, JSON.stringify(groups || [])]);
    res.status(201).json({ message: 'Producto creado', product: rows[0] });
});

// ── PUT /products/:id ─────────────────────────────────────────────
router.put('/:id', auth, async (req, res) => {
    if (req.user.role !== 'restaurant') return res.status(403).json({ error: 'Solo restaurantes' });
    const { name, description, price, category, image_url, available, groups } = req.body;
    await pool.query(
        `UPDATE products SET name=$1, description=$2, price=$3, category=$4,
     image_url=$5, available=$6, groups=$7 WHERE id=$8 AND restaurant_id=$9`,
        [name, description, price, category, image_url, available ?? true, JSON.stringify(groups || []), req.params.id, req.user.id]);
    res.json({ message: 'Producto actualizado' });
});

// ── DELETE /products/:id ──────────────────────────────────────────
router.delete('/:id', auth, async (req, res) => {
    if (req.user.role !== 'restaurant') return res.status(403).json({ error: 'Solo restaurantes' });
    await pool.query(
        'DELETE FROM products WHERE id=$1 AND restaurant_id=$2',
        [req.params.id, req.user.id]);
    res.json({ message: 'Producto eliminado' });
});

module.exports = router;
