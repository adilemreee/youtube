const { EventEmitter } = require('events');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const path = require('path');
const ytdlp = require('./ytdlp');

class DownloadManager extends EventEmitter {
    constructor() {
        super();
        this.downloads = new Map(); // Active downloads
        this.queue = []; // Pending downloads
        this.isProcessing = false;
        this.historyFile = path.join(__dirname, '..', 'data', 'history.json');
        this.history = this.loadHistory();
    }

    /**
     * Load history from file
     */
    loadHistory() {
        try {
            if (fs.existsSync(this.historyFile)) {
                const data = fs.readFileSync(this.historyFile, 'utf8');
                return JSON.parse(data);
            }
        } catch (e) {
            console.error('Failed to load history:', e);
        }
        return [];
    }

    /**
     * Save history to file
     */
    saveHistory() {
        try {
            const dir = path.dirname(this.historyFile);
            if (!fs.existsSync(dir)) {
                fs.mkdirSync(dir, { recursive: true });
            }
            fs.writeFileSync(this.historyFile, JSON.stringify(this.history, null, 2));
        } catch (e) {
            console.error('Failed to save history:', e);
        }
    }

    /**
     * Add download to queue
     */
    addToQueue(url, format, quality) {
        const id = uuidv4();
        const download = {
            id,
            url,
            format,
            quality,
            status: 'pending',
            progress: 0,
            speed: '',
            eta: '',
            title: '',
            output: '',
            createdAt: new Date().toISOString()
        };

        this.downloads.set(id, download);
        this.queue.push(id);

        // Start processing if not already
        if (!this.isProcessing) {
            this.processQueue();
        }

        return id;
    }

    /**
     * Process download queue
     */
    async processQueue() {
        if (this.isProcessing || this.queue.length === 0) return;

        this.isProcessing = true;

        while (this.queue.length > 0) {
            const id = this.queue.shift();
            const download = this.downloads.get(id);

            if (!download) continue;

            download.status = 'downloading';
            this.emit('progress', id, { status: 'downloading' });

            try {
                const result = await ytdlp.downloadVideo(
                    download.url,
                    download.format,
                    download.quality,
                    (progress) => {
                        if (progress.progress !== null) {
                            download.progress = progress.progress;
                        }
                        if (progress.speed) {
                            download.speed = progress.speed;
                        }
                        if (progress.eta) {
                            download.eta = progress.eta;
                        }
                        if (progress.title) {
                            download.title = progress.title;
                        }
                        if (progress.output) {
                            download.output += progress.output;
                        }
                        this.emit('progress', id, {
                            progress: download.progress,
                            speed: download.speed,
                            eta: download.eta,
                            title: download.title,
                            output: progress.output
                        });
                    }
                );

                download.status = 'completed';
                download.progress = 100;
                download.filePath = result.filePath;
                download.title = result.title || download.title;
                download.fileSize = result.fileSize;
                download.completedAt = new Date().toISOString();

                // Add to history
                this.history.unshift({
                    id: download.id,
                    title: download.title,
                    url: download.url,
                    format: download.format,
                    quality: download.quality,
                    filePath: download.filePath,
                    fileSize: download.fileSize,
                    completedAt: download.completedAt
                });
                this.saveHistory();

                this.emit('progress', id, {
                    status: 'completed',
                    progress: 100,
                    filePath: download.filePath
                });

            } catch (error) {
                download.status = 'failed';
                download.error = error.message;
                this.emit('progress', id, {
                    status: 'failed',
                    error: error.message
                });
            }
        }

        this.isProcessing = false;
    }

    /**
     * Get download by ID
     */
    getDownload(id) {
        return this.downloads.get(id);
    }

    /**
     * Get all active downloads
     */
    getActiveDownloads() {
        return Array.from(this.downloads.values())
            .filter(d => d.status !== 'completed' && d.status !== 'failed');
    }

    /**
     * Get download history
     */
    getHistory() {
        return this.history;
    }

    /**
     * Delete history item
     */
    deleteHistoryItem(id) {
        const index = this.history.findIndex(h => h.id === id);
        if (index !== -1) {
            const item = this.history[index];
            // Delete file if exists
            if (item.filePath && fs.existsSync(item.filePath)) {
                try {
                    fs.unlinkSync(item.filePath);
                } catch (e) {
                    console.error('Failed to delete file:', e);
                }
            }
            this.history.splice(index, 1);
            this.saveHistory();
            return true;
        }
        return false;
    }

    /**
     * Clear all history
     */
    clearHistory() {
        // Delete all files
        for (const item of this.history) {
            if (item.filePath && fs.existsSync(item.filePath)) {
                try {
                    fs.unlinkSync(item.filePath);
                } catch (e) {
                    console.error('Failed to delete file:', e);
                }
            }
        }
        this.history = [];
        this.saveHistory();
    }
}

module.exports = new DownloadManager();
