const express = require('express');
const router = express.Router();
const axios = require('axios');

const API_KEY = process.env.GOOGLE_MAPS_API_KEY || 'AIzaSyBhewvzlnQb5smBZHjXqJhiTYBL6kFT39Y';

// Proxy para Autocomplete
router.get('/autocomplete', async (req, res) => {
    try {
        const { input } = req.query;
        if (!input) return res.status(400).json({ error: 'Falta input' });

        const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(input)}&components=country:pe&key=${API_KEY}`;

        const response = await axios.get(url);
        res.json(response.data);
    } catch (error) {
        console.error('Error in maps proxy autocomplete:', error.message);
        res.status(500).json({ error: 'Error calling Google Maps API' });
    }
});

// Proxy para Geocode
router.get('/geocode', async (req, res) => {
    try {
        const { address, latlng } = req.query;

        let url = `https://maps.googleapis.com/maps/api/geocode/json?key=${API_KEY}`;
        if (address) url += `&address=${encodeURIComponent(address)}&components=country:PE`;
        if (latlng) url += `&latlng=${latlng}`;

        const response = await axios.get(url);
        res.json(response.data);
    } catch (error) {
        console.error('Error in maps proxy geocode:', error.message);
        res.status(500).json({ error: 'Error calling Google Maps API' });
    }
});

module.exports = router;
