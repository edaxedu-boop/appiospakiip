const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../db');
const auth = require('../middleware/auth');

const sign = (payload) =>
    jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || '7d' });

// ── POST /auth/login/admin ───────────────────────────────────────
router.post('/login/admin', async (req, res) => {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Email y contraseña requeridos' });

    const { rows } = await pool.query('SELECT * FROM admins WHERE email=$1', [email]);
    const admin = rows[0];
    if (!admin) return res.status(401).json({ error: 'Credenciales incorrectas' });

    const ok = await bcrypt.compare(password, admin.password);
    if (!ok) return res.status(401).json({ error: 'Credenciales incorrectas' });

    const token = sign({ id: admin.id, role: 'admin', name: admin.name });
    res.json({ token, role: 'admin', name: admin.name });
});

// ── POST /auth/login/restaurant ──────────────────────────────────
router.post('/login/restaurant', async (req, res) => {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Email y contraseña requeridos' });

    const { rows } = await pool.query(
        `SELECT r.*, p.name AS plan_name FROM restaurants r
     LEFT JOIN plans p ON r.plan_id = p.id
     WHERE r.email=$1`, [email]);
    const rest = rows[0];
    if (!rest) return res.status(401).json({ error: 'Credenciales incorrectas' });
    if (!rest.active) return res.status(403).json({ error: 'Restaurante suspendido' });

    const ok = await bcrypt.compare(password, rest.password);
    if (!ok) return res.status(401).json({ error: 'Credenciales incorrectas' });

    const token = sign({ id: rest.id, role: 'restaurant', name: rest.name, plan: rest.plan_name });
    res.json({ token, role: 'restaurant', name: rest.name, plan: rest.plan_name });
});

// ── POST /auth/login/rider ───────────────────────────────────────
router.post('/login/rider', async (req, res) => {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Email y contraseña requeridos' });

    const { rows } = await pool.query('SELECT * FROM riders WHERE email=$1', [email]);
    const rider = rows[0];
    if (!rider) return res.status(401).json({ error: 'Credenciales incorrectas' });
    if (!rider.active) return res.status(403).json({ error: 'Cuenta desactivada' });

    const ok = await bcrypt.compare(password, rider.password);
    if (!ok) return res.status(401).json({ error: 'Credenciales incorrectas' });

    const token = sign({ id: rider.id, role: 'rider', name: rider.name });
    res.json({ token, role: 'rider', name: rider.name });
});

// ── POST /auth/login/client ─────────────────────────────────────
router.post('/login/client', async (req, res) => {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'Email y contraseña requeridos' });

    const { rows } = await pool.query('SELECT * FROM clients WHERE email=$1', [email]);
    const client = rows[0];
    if (!client) return res.status(401).json({ error: 'Credenciales incorrectas' });
    if (!client.active) return res.status(403).json({ error: 'Cuenta desactivada' });

    const ok = await bcrypt.compare(password, client.password);
    if (!ok) return res.status(401).json({ error: 'Credenciales incorrectas' });

    const token = sign({ id: client.id, role: 'client', name: client.name });
    res.json({ token, role: 'client', name: client.name });
});

// ── POST /auth/register/client ───────────────────────────────────
router.post('/register/client', async (req, res) => {
    const { name, email, password, phone } = req.body;
    if (!name || !email || !password || !phone) {
        return res.status(400).json({ error: 'Nombre, email, contraseña y teléfono son requeridos' });
    }

    const hash = await bcrypt.hash(password, 10);
    try {
        const { rows } = await pool.query(
            'INSERT INTO clients (name, email, password, phone) VALUES ($1,$2,$3,$4) RETURNING id, name, email',
            [name, email, hash, phone || null]);
        const token = sign({ id: rows[0].id, role: 'client', name: rows[0].name });
        res.status(201).json({ message: 'Cliente registrado', token, role: 'client', name: rows[0].name });
    } catch (e) {
        if (e.code === '23505') return res.status(409).json({ error: 'El correo ya existe' });
        throw e;
    }
});

// ── POST /auth/register/admin (solo primer setup) ────────────────
router.post('/register/admin', async (req, res) => {
    const { name, email, password } = req.body;
    if (!name || !email || !password) return res.status(400).json({ error: 'Todos los campos requeridos' });

    const hash = await bcrypt.hash(password, 10);
    try {
        const { rows } = await pool.query(
            'INSERT INTO admins (name, email, password) VALUES ($1,$2,$3) RETURNING id, name, email',
            [name, email, hash]);
        res.status(201).json({ message: 'Admin creado', admin: rows[0] });
    } catch (e) {
        if (e.code === '23505') return res.status(409).json({ error: 'El correo ya existe' });
        throw e;
    }
});

// ── GET /auth/clients/me ─────────────────────────────────────────
router.get('/clients/me', async (req, res) => {
    const authHeader = req.headers['authorization'];
    if (!authHeader) return res.status(401).json({ error: 'Sin token' });
    const token = authHeader.split(' ')[1];
    let payload;
    try { payload = jwt.verify(token, process.env.JWT_SECRET); }
    catch { return res.status(401).json({ error: 'Token inválido' }); }
    if (payload.role !== 'client') return res.status(403).json({ error: 'Prohibido' });

    try { await pool.query('ALTER TABLE clients ADD COLUMN IF NOT EXISTS delivery_address TEXT DEFAULT NULL'); } catch { }
    try { await pool.query('ALTER TABLE clients ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT NULL'); } catch { }
    try { await pool.query('ALTER TABLE clients ADD COLUMN IF NOT EXISTS location GEOGRAPHY(POINT, 4326)'); } catch { }

    const { rows } = await pool.query(
        `SELECT id, name, email, phone, delivery_address, avatar_url,
                ST_Y(location::geometry) as lat, ST_X(location::geometry) as lng
         FROM clients WHERE id=$1`,
        [payload.id]
    );
    res.json(rows[0] || {});
});

// ── PUT /auth/clients/me ─────────────────────────────────────────
router.put('/clients/me', async (req, res) => {
    const authHeader = req.headers['authorization'];
    if (!authHeader) return res.status(401).json({ error: 'Sin token' });
    const token = authHeader.split(' ')[1];
    let payload;
    try { payload = jwt.verify(token, process.env.JWT_SECRET); }
    catch { return res.status(401).json({ error: 'Token inválido' }); }
    if (payload.role !== 'client') return res.status(403).json({ error: 'Prohibido' });

    try { await pool.query('ALTER TABLE clients ADD COLUMN IF NOT EXISTS delivery_address TEXT DEFAULT NULL'); } catch { }
    try { await pool.query('ALTER TABLE clients ADD COLUMN IF NOT EXISTS avatar_url TEXT DEFAULT NULL'); } catch { }
    try { await pool.query('ALTER TABLE clients ADD COLUMN IF NOT EXISTS location GEOGRAPHY(POINT, 4326)'); } catch { }

    const { name, phone, delivery_address, avatar_url, lat, lng } = req.body;

    let locationQuery = '';
    let params = [name || null, phone || null, delivery_address || null, avatar_url || null, payload.id];

    if (lat !== undefined && lng !== undefined) {
        locationQuery = ', location = ST_MakePoint($6, $7)::geography';
        params.push(lng, lat);
    }

    await pool.query(
        `UPDATE clients SET name=COALESCE($1,name), phone=COALESCE($2,phone),
                         delivery_address=COALESCE($3,delivery_address), avatar_url=COALESCE($4,avatar_url)
                         ${locationQuery}
         WHERE id=$5`,
        params
    );
    res.json({ message: 'Perfil actualizado' });
});

// ── POST /auth/change-password ────────────────────────────────────
router.post('/change-password', async (req, res) => {
    const authHeader = req.headers['authorization'];
    if (!authHeader) return res.status(401).json({ error: 'Sin token' });
    const token = authHeader.split(' ')[1];
    let payload;
    try { payload = jwt.verify(token, process.env.JWT_SECRET); }
    catch { return res.status(401).json({ error: 'Token inválido' }); }

    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
        return res.status(400).json({ error: 'Contraseña actual y nueva son requeridas' });
    }

    let table = '';
    if (payload.role === 'admin') table = 'admins';
    else if (payload.role === 'restaurant') table = 'restaurants';
    else if (payload.role === 'rider') table = 'riders';
    else if (payload.role === 'client') table = 'clients';
    else return res.status(403).json({ error: 'Rol no soportado' });

    const { rows } = await pool.query(`SELECT password FROM ${table} WHERE id=$1`, [payload.id]);
    if (rows.length === 0) return res.status(404).json({ error: 'Usuario no encontrado' });

    const user = rows[0];
    const ok = await bcrypt.compare(currentPassword, user.password);
    if (!ok) return res.status(401).json({ error: 'La contraseña actual es incorrecta' });

    const newHash = await bcrypt.hash(newPassword, 10);
    await pool.query(`UPDATE ${table} SET password=$1 WHERE id=$2`, [newHash, payload.id]);

    res.json({ message: 'Contraseña actualizada correctamente' });
});

// ── POST /auth/fcm-token ─────────────────────────────────────────
router.post('/fcm-token', auth, async (req, res) => {
    const { token } = req.body;
    if (!token) return res.status(400).json({ error: 'Token es requerido' });

    const role = req.user.role;
    const userId = req.user.id;

    try {
        let table = '';
        if (role === 'admin') table = 'admins';
        else if (role === 'restaurant') table = 'restaurants';
        else if (role === 'rider') table = 'riders';
        else if (role === 'client') table = 'clients';
        else return res.status(400).json({ error: 'Rol inválido' });

        await pool.query(`UPDATE ${table} SET fcm_token = $1 WHERE id = $2`, [token, userId]);
        res.json({ message: 'Token FCM guardado exitosamente' });
    } catch (e) {
        console.error('Error al guardar token FCM:', e);
        res.status(500).json({ error: 'Error al guardar token FCM' });
    }
});

// ── DELETE /auth/delete-account ─────────────────────────────────────
router.delete('/delete-account', auth, async (req, res) => {
    const role = req.user.role;
    const userId = req.user.id;

    try {
        if (role === 'client') {
            // Nullify orders referencing this client
            await pool.query('UPDATE orders SET client_id = NULL WHERE client_id = $1', [userId]);
            // Delete client
            await pool.query('DELETE FROM clients WHERE id = $1', [userId]);
            return res.json({ message: 'Cuenta de cliente eliminada exitosamente' });
        } 
        else if (role === 'rider') {
            // Nullify orders referencing this rider
            await pool.query('UPDATE orders SET rider_id = NULL WHERE rider_id = $1', [userId]);
            // Delete payments
            await pool.query('DELETE FROM payments WHERE rider_id = $1', [userId]);
            // Delete rider
            await pool.query('DELETE FROM riders WHERE id = $1', [userId]);
            return res.json({ message: 'Cuenta de repartidor eliminada exitosamente' });
        } 
        else if (role === 'restaurant') {
            // Nullify orders
            await pool.query('UPDATE orders SET restaurant_id = NULL WHERE restaurant_id = $1', [userId]);
            // Category mapping
            await pool.query('DELETE FROM restaurant_category_map WHERE restaurant_id = $1', [userId]);
            // Categories
            await pool.query('DELETE FROM categories WHERE restaurant_id = $1', [userId]);
            // Products
            await pool.query('DELETE FROM products WHERE restaurant_id = $1', [userId]);
            // Promotions
            await pool.query('DELETE FROM promotions WHERE restaurant_id = $1', [userId]);
            // Delete restaurant
            await pool.query('DELETE FROM restaurants WHERE id = $1', [userId]);
            return res.json({ message: 'Cuenta de restaurante eliminada exitosamente' });
        } 
        else {
            return res.status(400).json({ error: 'Rol no válido para eliminación' });
        }
    } catch (e) {
        console.error('Error al eliminar cuenta:', e);
        return res.status(500).json({ error: 'Error interno del servidor al eliminar la cuenta' });
    }
});

module.exports = router;

