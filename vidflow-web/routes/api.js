const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const ytdlp = require('../services/ytdlp');
const downloadManager = require('../services/downloadManager');

// Store SSE clients
const sseClients = new Map();

/**
 * POST /api/info - Get video information
 */
router.post('/info', async (req, res) => {
    try {
        const { url } = req.body;

        if (!url) {
            return res.status(400).json({ error: 'URL is required' });
        }

        const info = await ytdlp.getVideoInfo(url);
        res.json(info);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

/**
 * POST /api/download - Start a download
 */
router.post('/download', (req, res) => {
    try {
        const { url, format = 'mp4', quality = '1080p' } = req.body;

        if (!url) {
            return res.status(400).json({ error: 'URL is required' });
        }

        const id = downloadManager.addToQueue(url, format, quality);
        res.json({ id, message: 'Download started' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

/**
 * GET /api/progress/:id - SSE progress stream
 */
router.get('/progress/:id', (req, res) => {
    const { id } = req.params;

    // Set SSE headers
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('Access-Control-Allow-Origin', '*');

    // Send initial state
    const download = downloadManager.getDownload(id);
    if (download) {
        res.write(`data: ${JSON.stringify({
            status: download.status,
            progress: download.progress,
            speed: download.speed,
            eta: download.eta,
            title: download.title
        })}\n\n`);
    }

    // Create progress listener
    const listener = (downloadId, data) => {
        if (downloadId === id) {
            res.write(`data: ${JSON.stringify(data)}\n\n`);

            // Close connection when complete or failed
            if (data.status === 'completed' || data.status === 'failed') {
                setTimeout(() => {
                    downloadManager.removeListener('progress', listener);
                    res.end();
                }, 1000);
            }
        }
    };

    downloadManager.on('progress', listener);

    // Cleanup on client disconnect
    req.on('close', () => {
        downloadManager.removeListener('progress', listener);
    });
});

/**
 * GET /api/active - Get active downloads
 */
router.get('/active', (req, res) => {
    const downloads = downloadManager.getActiveDownloads();
    res.json(downloads);
});

/**
 * GET /api/history - Get download history
 */
router.get('/history', (req, res) => {
    const history = downloadManager.getHistory();
    res.json(history);
});

/**
 * GET /api/download/:id - Download completed file
 */
router.get('/download/:id', (req, res) => {
    const { id } = req.params;

    // Check in active downloads first
    let download = downloadManager.getDownload(id);

    // Check in history
    if (!download || !download.filePath) {
        const history = downloadManager.getHistory();
        download = history.find(h => h.id === id);
    }

    if (!download || !download.filePath) {
        return res.status(404).json({ error: 'Download not found' });
    }

    if (!fs.existsSync(download.filePath)) {
        return res.status(404).json({ error: 'File not found' });
    }

    const filename = path.basename(download.filePath);
    const ext = path.extname(filename).toLowerCase();

    // Set correct MIME type based on extension
    const mimeTypes = {
        '.mp4': 'video/mp4',
        '.webm': 'video/webm',
        '.mkv': 'video/x-matroska',
        '.mp3': 'audio/mpeg',
        '.m4a': 'audio/mp4',
        '.aac': 'audio/aac',
        '.wav': 'audio/wav',
        '.ogg': 'audio/ogg'
    };

    const contentType = mimeTypes[ext] || 'application/octet-stream';

    // Get file size for Content-Length
    const stats = fs.statSync(download.filePath);

    res.setHeader('Content-Disposition', `attachment; filename="${encodeURIComponent(filename)}"`);
    res.setHeader('Content-Type', contentType);
    res.setHeader('Content-Length', stats.size);

    const stream = fs.createReadStream(download.filePath);
    stream.pipe(res);
});

/**
 * DELETE /api/history/:id - Delete history item
 */
router.delete('/history/:id', (req, res) => {
    const { id } = req.params;
    const deleted = downloadManager.deleteHistoryItem(id);

    if (deleted) {
        res.json({ success: true });
    } else {
        res.status(404).json({ error: 'Item not found' });
    }
});

/**
 * DELETE /api/history - Clear all history
 */
router.delete('/history', (req, res) => {
    downloadManager.clearHistory();
    res.json({ success: true });
});

module.exports = router;
