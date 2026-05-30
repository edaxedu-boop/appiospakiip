// Seed: crea usuarios de prueba reales (admin + clientes + restaurantes + repartidores)
require('dotenv').config();
const { Client } = require('pg');
const bcrypt = require('bcryptjs');

async function seed() {
    const db = new Client({
        host: process.env.DB_HOST,
        port: process.env.DB_PORT,
        database: process.env.DB_NAME,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
    });

    await db.connect();
    console.log('\n🌱 Iniciando seed de usuarios...\n');

    // ── 1. ADMINS ─────────────────────────────────────────────────────
    const admins = [
        { name: 'Super Admin', email: 'admin@pakiip.com', password: 'admin123' },
        { name: 'Rossell Admin', email: 'rossell@pakiip.com', password: 'rossell123' },
    ];

    for (const a of admins) {
        const hash = await bcrypt.hash(a.password, 10);
        await db.query(
            `INSERT INTO admins (name, email, password) VALUES ($1,$2,$3)
       ON CONFLICT (email) DO UPDATE SET password=$3`,
            [a.name, a.email, hash]);
        console.log(`✅ Admin:       ${a.email}  /  ${a.password}`);
    }

    // La tabla 'clients' ya se crea en schema.sql, no es necesario aquí.


    const clients = [
        { name: 'Carlos Mendoza', email: 'carlos@pakiip.com', password: 'carlos123', phone: '987654321' },
        { name: 'María López', email: 'maria@pakiip.com', password: 'maria123', phone: '912345678' },
        { name: 'Luis Fernández', email: 'luis@pakiip.com', password: 'luis123', phone: '956781234' },
        { name: 'Ana García', email: 'ana@pakiip.com', password: 'ana123', phone: '934567890' },
        { name: 'Jorge Quispe', email: 'jorge@pakiip.com', password: 'jorge123', phone: '978901234' },
    ];

    for (const c of clients) {
        const hash = await bcrypt.hash(c.password, 10);
        await db.query(
            `INSERT INTO clients (name, email, password, phone) VALUES ($1,$2,$3,$4)
       ON CONFLICT (email) DO UPDATE SET password=$3`,
            [c.name, c.email, hash, c.phone]);
        console.log(`✅ Cliente:     ${c.email}  /  ${c.password}`);
    }

    // ── 3. RESTAURANTES de prueba ─────────────────────────────────────
    // Primero obtenemos los IDs de planes
    const { rows: plans } = await db.query('SELECT id, name FROM plans ORDER BY price ASC');
    const planMap = {};
    plans.forEach(p => planMap[p.name] = p.id);

    const restaurants = [
        { name: 'Parrillas El Gaucho', email: 'gaucho@pakiip.com', password: 'gaucho123', plan: 'Pakiip Empresarial', lat: -12.0464, lng: -77.0428 },
        { name: 'Pollería La Brasa', email: 'labrasa@pakiip.com', password: 'labrasa123', plan: 'Pakiip Emprende', lat: -12.0510, lng: -77.0410 },
        { name: 'Sabor Marino', email: 'sabormarin@pakiip.com', password: 'marino123', plan: 'Pakiip Empresarial', lat: -12.0480, lng: -77.0450 },
    ];

    for (const r of restaurants) {
        const hash = await bcrypt.hash(r.password, 10);
        const planId = planMap[r.plan];
        const expiry = new Date();
        expiry.setDate(expiry.getDate() + 30);
        await db.query(
            `INSERT INTO restaurants (name, email, password, plan_id, plan_expiry, location)
       VALUES ($1,$2,$3,$4,$5, ST_MakePoint($6,$7)::geography)
       ON CONFLICT (email) DO UPDATE SET password=$3`,
            [r.name, r.email, hash, planId, expiry, r.lng, r.lat]);
        console.log(`✅ Restaurante: ${r.email}  /  ${r.password}`);
    }

    // ── 4. REPARTIDORES de prueba ─────────────────────────────────────
    const riders = [
        { name: 'Juan Perez Rodriguez', email: 'juan@pakiip.com', password: 'juan123', phone: '999001122' },
        { name: 'Maria Fernanda Solis', email: 'fernanda@pakiip.com', password: 'fernanda123', phone: '999003344' },
        { name: 'Carlos Alberto Ruiz', email: 'cruiz@pakiip.com', password: 'cruiz123', phone: '999005566' },
    ];

    for (const r of riders) {
        const hash = await bcrypt.hash(r.password, 10);
        await db.query(
            `INSERT INTO riders (name, email, password, phone) VALUES ($1,$2,$3,$4)
       ON CONFLICT (email) DO UPDATE SET password=$3`,
            [r.name, r.email, hash, r.phone]);
        console.log(`✅ Repartidor:  ${r.email}  /  ${r.password}`);
    }

    // ── Agregar login de clientes al auth ──────────────────────────────
    console.log('\n✨ Seed completado exitosamente!\n');
    console.log('═══════════════════════════════════════════════════');
    console.log('  CREDENCIALES DE ACCESO');
    console.log('═══════════════════════════════════════════════════');
    console.log('  ADMIN');
    console.log('    admin@pakiip.com       / admin123');
    console.log('    rossell@pakiip.com     / rossell123');
    console.log('\n  CLIENTES');
    console.log('    carlos@pakiip.com      / carlos123');
    console.log('    maria@pakiip.com       / maria123');
    console.log('    luis@pakiip.com        / luis123');
    console.log('\n  RESTAURANTES');
    console.log('    gaucho@pakiip.com      / gaucho123');
    console.log('    labrasa@pakiip.com     / labrasa123');
    console.log('    sabormarin@pakiip.com  / marino123');
    console.log('\n  REPARTIDORES');
    console.log('    juan@pakiip.com        / juan123');
    console.log('    fernanda@pakiip.com    / fernanda123');
    console.log('    cruiz@pakiip.com       / cruiz123');
    console.log('═══════════════════════════════════════════════════\n');

    await db.end();
}

seed().catch(err => {
    console.error('❌ Error en seed:', err.message);
    process.exit(1);
});
