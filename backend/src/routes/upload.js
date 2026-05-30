const router = require('express').Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const auth = require('../middleware/auth');

// --- Configuración de almacenamiento ---
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        const dir = 'uploads/restaurants';
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        cb(null, dir);
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'hero-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({
    storage: storage,
    limits: { fileSize: 5 * 1024 * 1024 } // Máx 5MB
});

// --- POST /upload/restaurant/hero ---
router.post('/restaurant/hero', auth, upload.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).json({ error: 'No se subió ninguna imagen' });

    // URL absoluta para devolver al frontend
    // En desarrollo es localhost:3000, en producción será tu IP/Dominio
    const imageUrl = `/uploads/restaurants/${req.file.filename}`;

    res.json({ imageUrl });
});

// --- Configuración para productos ---
const productStorage = multer.diskStorage({
    destination: (req, file, cb) => {
        const dir = 'uploads/products';
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        cb(null, dir);
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'prod-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const uploadProduct = multer({
    storage: productStorage,
    limits: { fileSize: 5 * 1024 * 1024 }
});

// --- POST /upload/product ---
router.post('/product', auth, uploadProduct.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).json({ error: 'No se subió ninguna imagen' });
    const imageUrl = `/uploads/products/${req.file.filename}`;
    res.json({ imageUrl });
});

// --- Configuración para promociones ---
const promoStorage = multer.diskStorage({
    destination: (req, file, cb) => {
        const dir = 'uploads/promos';
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        cb(null, dir);
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'promo-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const uploadPromo = multer({
    storage: promoStorage,
    limits: { fileSize: 5 * 1024 * 1024 }
});

// --- POST /upload/promo ---
router.post('/promo', auth, uploadPromo.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).json({ error: 'No se subió ninguna imagen' });
    const imageUrl = `/uploads/promos/${req.file.filename}`;
    res.json({ imageUrl });
});

// --- Configuración para perfiles (repartidores, clientes) ---
const profileStorage = multer.diskStorage({
    destination: (req, file, cb) => {
        const dir = 'uploads/profiles';
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        cb(null, dir);
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'avatar-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const uploadProfile = multer({
    storage: profileStorage,
    limits: { fileSize: 2 * 1024 * 1024 } // 2MB max
});

router.post('/profile', auth, uploadProfile.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).json({ error: 'No se subió ninguna imagen' });
    const imageUrl = `/uploads/profiles/${req.file.filename}`;
    res.json({ imageUrl });
});

// --- Configuración para comprobantes de pago ---
const proofStorage = multer.diskStorage({
    destination: (req, file, cb) => {
        const dir = 'uploads/proofs';
        if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
        cb(null, dir);
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, 'proof-' + uniqueSuffix + path.extname(file.originalname));
    }
});

const uploadProof = multer({
    storage: proofStorage,
    limits: { fileSize: 5 * 1024 * 1024 } // 5MB max
});

router.post('/payment-proof', auth, uploadProof.single('image'), async (req, res) => {
    if (!req.file) return res.status(400).json({ error: 'No se subió ninguna imagen' });
    const imageUrl = `/uploads/proofs/${req.file.filename}`;
    res.json({ imageUrl });
});

module.exports = router;

