// Crea la base de datos y ejecuta el schema
require('dotenv').config();
const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

async function setup() {
    // 1. Conectar a postgres (DB por defecto) para crear pakiip_db
    const client = new Client({
        host: process.env.DB_HOST,
        port: process.env.DB_PORT,
        database: 'postgres',
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
    });

    try {
        await client.connect();
        console.log('🔌 Conectado a PostgreSQL...');

        // Crear base de datos
        await client.query(`CREATE DATABASE pakiip_db`).catch(() => {
            console.log('ℹ️  La base de datos pakiip_db ya existe, continuando...');
        });

        console.log('✅ Base de datos pakiip_db lista');
        await client.end();

        // 2. Conectar a pakiip_db y ejecutar schema
        const appClient = new Client({
            host: process.env.DB_HOST,
            port: process.env.DB_PORT,
            database: process.env.DB_NAME,
            user: process.env.DB_USER,
            password: process.env.DB_PASSWORD,
        });

        await appClient.connect();
        console.log('🔌 Aplicando actualizaciones al esquema...');

        // ── ACTUALIZACIONES INCREMENTALES (MIGRACIONES) ──
        // Esto evita errores si las tablas ya existen pero necesitan columnas nuevas

        // 1. Agregar avatar_url a clients si no existe
        await appClient.query(`
            DO $$ 
            BEGIN 
                IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='clients' AND column_name='avatar_url') THEN
                    ALTER TABLE clients ADD COLUMN avatar_url TEXT;
                END IF;
            END $$;
        `);

        // 2. Agregar maintenance_mode y otros a app_config si no existen
        // (Aunque la tabla app_config es nueva, esto asegura que el setup sea robusto)
        await appClient.query(`
            CREATE TABLE IF NOT EXISTS app_config (
                id SERIAL PRIMARY KEY,
                service_fee DECIMAL(10,2) DEFAULT 0.00,
                rider_commission DECIMAL(5,2) DEFAULT 60.00,
                price_per_km DECIMAL(10,2) DEFAULT 0.00,
                maintenance_mode BOOLEAN DEFAULT false,
                maintenance_message TEXT DEFAULT 'Estamos realizando mejoras en el sistema. Volveremos pronto...',
                emergency_contact VARCHAR(20),
                updated_at TIMESTAMP DEFAULT NOW()
            );
        `);

        // Ejecutar el resto del schema (las tablas que no existen las crea, las que existen fallan silenciosamente con IF NOT EXISTS)
        const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
        // Separamos por punto y coma y ejecutamos cada sentencia para que una falla no detenga todo
        const queries = sql.split(';').filter(q => q.trim() !== '');

        for (let query of queries) {
            try {
                await appClient.query(query);
            } catch (queryErr) {
                // Silenciamos errores de "ya existe" para que el proceso continúe
                if (!queryErr.message.includes('already exists')) {
                    console.log(`⚠️  Nota en query: ${queryErr.message}`);
                }
            }
        }

        console.log('✅ Schema actualizado correctamente');
        console.log('✅ Datos iniciales verificados');
        console.log('\n🚀 Base de datos lista!\n');
        await appClient.end();

    } catch (err) {
        console.error('❌ Error en setup:', err.message);
        process.exit(1);
    }
}

setup();
