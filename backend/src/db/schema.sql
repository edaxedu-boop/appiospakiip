-- ═══════════════════════════════════════════════════════════════
--  PAKIIP — Schema SQL
--  Ejecutar con: node src/db/setup.js
-- ═══════════════════════════════════════════════════════════════

-- Extensión geoespacial
CREATE EXTENSION IF NOT EXISTS postgis;

-- ── ADMINS ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS admins (
  id         SERIAL PRIMARY KEY,
  name       VARCHAR(150) NOT NULL,
  email      VARCHAR(255) UNIQUE NOT NULL,
  password   VARCHAR(255) NOT NULL,
  role       VARCHAR(50)  DEFAULT 'admin',
  created_at TIMESTAMP    DEFAULT NOW()
);

-- ── PLANS ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS plans (
  id           SERIAL PRIMARY KEY,
  name         VARCHAR(50)    NOT NULL UNIQUE,  -- Pakiip Emprende, Pakiip Empresarial
  price        DECIMAL(10,2)  NOT NULL,
  commission_rate DECIMAL(5,2)  DEFAULT 0.00,    -- % de comisión sobre ventas
  duration_days INTEGER       DEFAULT 30,
  features     TEXT[]         DEFAULT '{}',
  created_at   TIMESTAMP      DEFAULT NOW()
);

-- ── RESTAURANTS ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS restaurants (
  id          SERIAL PRIMARY KEY,
  name        VARCHAR(255) NOT NULL,
  email       VARCHAR(255) UNIQUE NOT NULL,
  password    VARCHAR(255) NOT NULL,
  plan_id     INTEGER REFERENCES plans(id),
  plan_expiry DATE,
  active      BOOLEAN      DEFAULT true,
  phone       VARCHAR(20),
  address     TEXT,
  location    GEOGRAPHY(POINT, 4326),          -- lat/lng para geolocalización
  logo_url    TEXT,
  created_at  TIMESTAMP    DEFAULT NOW()
);

-- Índice espacial para búsquedas por cercanía
CREATE INDEX IF NOT EXISTS restaurants_location_idx
  ON restaurants USING GIST(location);

-- ── RIDERS (repartidores) ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS riders (
  id          SERIAL PRIMARY KEY,
  name        VARCHAR(150) NOT NULL,
  email       VARCHAR(255) UNIQUE NOT NULL,
  password    VARCHAR(255) NOT NULL,
  phone       VARCHAR(20),
  status      VARCHAR(20)  DEFAULT 'available',  -- available, busy, offline
  active      BOOLEAN      DEFAULT true,
  location    GEOGRAPHY(POINT, 4326),
  vehicle     VARCHAR(50)  DEFAULT 'moto',
  commission  DECIMAL(5,2) DEFAULT 60.00,        -- % comisión
  created_at  TIMESTAMP    DEFAULT NOW()
);

-- ── ORDERS (pedidos) ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS orders (
  id            SERIAL PRIMARY KEY,
  restaurant_id INTEGER REFERENCES restaurants(id),
  rider_id      INTEGER REFERENCES riders(id),
  client_name   VARCHAR(150),
  client_phone  VARCHAR(20),
  client_address TEXT,
  status        VARCHAR(30) DEFAULT 'pending',  -- pending, accepted, in_delivery, delivered, cancelled
  total         DECIMAL(10,2) NOT NULL,
  delivery_fee  DECIMAL(10,2) DEFAULT 0.00,
  distance_km   DECIMAL(8,2)  DEFAULT 0.00,
  created_at    TIMESTAMP DEFAULT NOW(),
  delivered_at  TIMESTAMP
);

-- ── PAYMENTS (liquidaciones) ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS payments (
  id            SERIAL PRIMARY KEY,
  rider_id      INTEGER REFERENCES riders(id),
  period_start  DATE NOT NULL,
  period_end    DATE NOT NULL,
  total_billing DECIMAL(10,2) DEFAULT 0.00,
  total_orders  INTEGER       DEFAULT 0,
  commission    DECIMAL(5,2)  DEFAULT 60.00,
  total_payout  DECIMAL(10,2) DEFAULT 0.00,
  status        VARCHAR(20)   DEFAULT 'pending',  -- pending, paid
  paid_at       TIMESTAMP,
  created_at    TIMESTAMP DEFAULT NOW()
);

-- ── CLIENTS ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS clients (
  id               SERIAL PRIMARY KEY,
  name             VARCHAR(150) NOT NULL,
  email            VARCHAR(255) UNIQUE NOT NULL,
  password         VARCHAR(255) NOT NULL,
  phone            VARCHAR(20),
  delivery_address TEXT,
  avatar_url       TEXT,
  location         GEOGRAPHY(POINT, 4326),
  active           BOOLEAN      DEFAULT true,
  created_at       TIMESTAMP    DEFAULT NOW()
);

-- ── GLOBAL CATEGORIES (para los comercios/restaurantes) ───────────
CREATE TABLE IF NOT EXISTS global_categories (
  id         SERIAL PRIMARY KEY,
  name       VARCHAR(100) NOT NULL UNIQUE,
  image_url  TEXT,
  active     BOOLEAN      DEFAULT true,
  created_at TIMESTAMP    DEFAULT NOW()
);

-- ── RESTAURANT CATEGORY MAP (Tabla intermedia) ────────────────────
CREATE TABLE IF NOT EXISTS restaurant_category_map (
  restaurant_id INTEGER REFERENCES restaurants(id) ON DELETE CASCADE,
  category_id   INTEGER REFERENCES global_categories(id) ON DELETE CASCADE,
  PRIMARY KEY (restaurant_id, category_id)
);

-- ── MENU CATEGORIES (dentro de cada restaurante) ─────────────────
CREATE TABLE IF NOT EXISTS categories (
  id            SERIAL PRIMARY KEY,
  restaurant_id INTEGER REFERENCES restaurants(id) ON DELETE CASCADE,
  name          VARCHAR(100) NOT NULL,
  position      INTEGER      DEFAULT 0,
  created_at    TIMESTAMP    DEFAULT NOW()
);

-- ── PRODUCTS ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
  id            SERIAL PRIMARY KEY,
  restaurant_id INTEGER REFERENCES restaurants(id) ON DELETE CASCADE,
  name          VARCHAR(255) NOT NULL,
  description   TEXT,
  price         DECIMAL(10,2) NOT NULL,
  category      VARCHAR(100),
  image_url     TEXT,
  available     BOOLEAN      DEFAULT true,
  groups        JSONB        DEFAULT '[]'::jsonb,
  created_at    TIMESTAMP    DEFAULT NOW()
);

-- ── PROMOTIONS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS promotions (
  id            SERIAL PRIMARY KEY,
  title         VARCHAR(120) NOT NULL,
  description   TEXT,
  image_url     TEXT         NOT NULL,
  restaurant_id INTEGER      REFERENCES restaurants(id) ON DELETE SET NULL,
  link          TEXT,
  active        BOOLEAN      DEFAULT true,
  created_at    TIMESTAMP    DEFAULT NOW()
);

-- ── APP CONFIG ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS app_config (
  id                    SERIAL PRIMARY KEY,
  service_fee           DECIMAL(10,2) DEFAULT 0.00,
  rider_commission      DECIMAL(5,2)  DEFAULT 60.00,
  price_per_km          DECIMAL(10,2) DEFAULT 0.00,
  maintenance_mode      BOOLEAN       DEFAULT false,
  maintenance_message   TEXT          DEFAULT 'Estamos realizando mejoras en el sistema. Volveremos pronto...',
  emergency_contact     VARCHAR(20),
  updated_at            TIMESTAMP     DEFAULT NOW()
);

-- ── SEED DATA ────────────────────────────────────────────────────

-- Planes iniciales
INSERT INTO plans (name, price, commission_rate, duration_days, features) VALUES
  ('Pakiip Emprende', 0.00,  10.00, 30, ARRAY['Hasta 50 productos en menú','Panel de pedidos completo','10% comisión sobre ventas','Soporte básico']),
  ('Pakiip Empresarial', 149.00, 0.00, 30, ARRAY['Productos ilimitados','Panel de pedidos VIP','0% comisión sobre ventas','Estadísticas avanzadas','Soporte prioritario','Personalización Premium'])
ON CONFLICT (name) DO UPDATE SET price = EXCLUDED.price, commission_rate = EXCLUDED.commission_rate, features = EXCLUDED.features;

-- Config inicial
INSERT INTO app_config (service_fee, rider_commission, price_per_km)
  VALUES (0.00, 60.00, 2.50)
ON CONFLICT DO NOTHING;
