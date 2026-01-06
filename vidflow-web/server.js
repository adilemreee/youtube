const express = require('express');
const cors = require('cors');
const path = require('path');
const apiRoutes = require('./routes/api');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// API Routes
app.use('/api', apiRoutes);

// Serve index.html for root
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
    console.log(`
╔══════════════════════════════════════════════╗
║           VidFlow Web Started                ║
╠══════════════════════════════════════════════╣
║  Local:    http://localhost:${PORT}             ║
║  Network:  http://0.0.0.0:${PORT}               ║
╚══════════════════════════════════════════════╝
    `);
});
