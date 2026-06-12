require('dotenv').config();
process.env.TZ = 'America/Lima';
const express = require('express');
const cors = require('cors');
const pool = require('./db');

const app = express();

// ── Middleware ────────────────────────────────────────────────────
app.use(cors());
app.use(express.json());

// ── Logging simple ────────────────────────────────────────────────
app.use((req, _res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
    next();
});

// ── Rutas ─────────────────────────────────────────────────────────
app.use('/auth', require('./routes/auth'));
app.use('/restaurants', require('./routes/restaurants'));
app.use('/riders', require('./routes/riders'));
app.use('/payments', require('./routes/payments'));
app.use('/plans', require('./routes/plans'));
app.use('/config', require('./routes/config'));
app.use('/products', require('./routes/products'));
app.use('/categories', require('./routes/categories'));
app.use('/upload', require('./routes/upload'));
app.use('/restaurant-categories', require('./routes/restaurant_categories'));
app.use('/promotions', require('./routes/promotions'));
app.use('/orders', require('./routes/orders'));
app.use('/admin', require('./routes/admin'));
app.use('/restaurant-payments', require('./routes/restaurant_payments'));
app.use('/maps', require('./routes/maps'));
app.use('/coupons', require('./routes/coupons'));


// Servir archivos estáticos
app.use('/uploads', express.static('uploads'));

// ── Health check ──────────────────────────────────────────────────
app.get('/health', (_req, res) => {
    res.json({ status: 'ok', time: new Date().toISOString() });
});

// ── Error handler ─────────────────────────────────────────────────
app.use((err, _req, res, _next) => {
    console.error('❌ Error:', err.message);
    res.status(500).json({ error: 'Error interno del servidor' });
});

// ── Arrancar ──────────────────────────────────────────────────────
// ── Auto-Disconnect Riders at Midnight ──────────────────────────────
function scheduleMidnightOffline() {
    const now = new Date();
    // Lima is UTC-5
    const limaTime = new Date(now.toLocaleString("en-US", { timeZone: "America/Lima" }));
    const nextMidnight = new Date(limaTime);
    nextMidnight.setHours(24, 0, 0, 0); // Next midnight
    let delay = nextMidnight.getTime() - limaTime.getTime();

    // Prevent negative delay just in case
    if (delay < 0) delay += 24 * 60 * 60 * 1000;

    console.log(`[Riders] Programado auto-offline a medianoche (en ${Math.floor(delay / 1000 / 60)} minutos)`);
    setTimeout(async () => {
        try {
            const { rowCount } = await pool.query("UPDATE riders SET status = 'offline' WHERE status != 'offline'");
            console.log(`[Riders] Auto-offline ejecutado a medianoche. ${rowCount} motorizados desconectados.`);
        } catch (e) {
            console.error('[Riders] Error en auto-offline:', e);
        }
        // Reschedule for next day
        scheduleMidnightOffline();
    }, delay);
}
scheduleMidnightOffline();

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n🚀 Pakiip Backend corriendo en http://localhost:${PORT}`);
    console.log('📋 Endpoints disponibles:');
    console.log('   POST /auth/login/admin');
    console.log('   POST /auth/login/restaurant');
    console.log('   POST /auth/login/rider');
    console.log('   GET  /restaurants');
    console.log('   GET  /restaurants/nearby?lat=&lng=&radius=');
    console.log('   POST /restaurants');
    console.log('   GET  /riders');
    console.log('   GET  /payments');
    console.log('   GET  /plans');
    console.log('   GET  /config\n');
});
