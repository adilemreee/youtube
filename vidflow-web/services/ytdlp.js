const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

class YtdlpService {
    constructor() {
        this.downloadsDir = path.join(__dirname, '..', 'downloads');
        // Ensure downloads directory exists
        if (!fs.existsSync(this.downloadsDir)) {
            fs.mkdirSync(this.downloadsDir, { recursive: true });
        }
    }

    /**
     * Fetch video information from URL
     * @param {string} url - Video URL
     * @returns {Promise<object>} Video info object
     */
    async getVideoInfo(url) {
        return new Promise((resolve, reject) => {
            const args = [
                '--dump-json',
                '--no-playlist',
                '--no-warnings',
                url
            ];

            let stdout = '';
            let stderr = '';

            const process = spawn('yt-dlp', args);

            process.stdout.on('data', (data) => {
                stdout += data.toString();
            });

            process.stderr.on('data', (data) => {
                stderr += data.toString();
            });

            process.on('close', (code) => {
                if (code === 0) {
                    try {
                        const info = JSON.parse(stdout);
                        resolve({
                            id: info.id,
                            title: info.title,
                            thumbnail: info.thumbnail,
                            duration: info.duration,
                            uploader: info.uploader || info.channel,
                            viewCount: info.view_count,
                            description: info.description?.substring(0, 500)
                        });
                    } catch (e) {
                        reject(new Error('Failed to parse video info'));
                    }
                } else {
                    reject(new Error(stderr || 'Failed to fetch video info'));
                }
            });

            process.on('error', (err) => {
                reject(new Error(`yt-dlp not found: ${err.message}`));
            });
        });
    }

    /**
     * Download video with progress callback
     * @param {string} url - Video URL
     * @param {string} format - Format (mp4, webm, mp3, m4a)
     * @param {string} quality - Quality (4K, 1080p, 720p, 480p)
     * @param {function} onProgress - Progress callback
     * @returns {Promise<object>} Download result with file path
     */
    downloadVideo(url, format, quality, onProgress) {
        return new Promise((resolve, reject) => {
            const outputTemplate = path.join(this.downloadsDir, '%(title)s.%(ext)s');

            let args = [
                '--newline',
                '--progress',
                '-o', outputTemplate
            ];

            // Add format selection
            if (format === 'mp3' || format === 'm4a') {
                args.push('-x', '--audio-format', format);
            } else {
                const formatString = this.buildFormatString(quality, format);
                args.push('-f', formatString);
                if (format === 'mp4') {
                    args.push('--merge-output-format', 'mp4');
                } else if (format === 'webm') {
                    args.push('--merge-output-format', 'webm');
                }
            }

            args.push(url);

            let filePath = '';
            let title = '';

            const process = spawn('yt-dlp', args, { cwd: this.downloadsDir });

            process.stdout.on('data', (data) => {
                const output = data.toString();

                // Parse destination path
                if (output.includes('Destination:')) {
                    const match = output.match(/Destination:\s*(.+)/);
                    if (match) {
                        filePath = match[1].trim();
                        title = path.basename(filePath, path.extname(filePath));
                    }
                }

                // Parse merged file path
                if (output.includes('Merging formats into')) {
                    const match = output.match(/"([^"]+)"/);
                    if (match) {
                        filePath = match[1];
                        title = path.basename(filePath, path.extname(filePath));
                    }
                }

                // Parse progress
                const progressMatch = output.match(/(\d+\.?\d*)%/);
                const speedMatch = output.match(/at\s+(\d+\.?\d*\w+\/s)/);
                const etaMatch = output.match(/ETA\s+(\d+:\d+)/);

                if (progressMatch || speedMatch || etaMatch) {
                    onProgress({
                        progress: progressMatch ? parseFloat(progressMatch[1]) : null,
                        speed: speedMatch ? speedMatch[1] : null,
                        eta: etaMatch ? etaMatch[1] : null,
                        title: title,
                        output: output
                    });
                }
            });

            process.stderr.on('data', (data) => {
                const output = data.toString();
                onProgress({ output: output, error: true });
            });

            process.on('close', (code) => {
                if (code === 0) {
                    // Find the actual file if template was used
                    if (!filePath || !fs.existsSync(filePath)) {
                        const files = fs.readdirSync(this.downloadsDir)
                            .map(f => ({ name: f, time: fs.statSync(path.join(this.downloadsDir, f)).mtime }))
                            .sort((a, b) => b.time - a.time);

                        if (files.length > 0) {
                            filePath = path.join(this.downloadsDir, files[0].name);
                            title = path.basename(filePath, path.extname(filePath));
                        }
                    }

                    const stats = fs.existsSync(filePath) ? fs.statSync(filePath) : { size: 0 };

                    resolve({
                        success: true,
                        filePath: filePath,
                        title: title,
                        fileSize: stats.size
                    });
                } else {
                    reject(new Error('Download failed'));
                }
            });

            process.on('error', (err) => {
                reject(new Error(`yt-dlp not found: ${err.message}`));
            });
        });
    }

    /**
     * Build format string for yt-dlp
     */
    buildFormatString(quality, format) {
        switch (quality) {
            case '4K':
            case '2160p':
                return 'bestvideo[height<=2160][vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[height<=2160]+bestaudio/best[height<=2160]';
            case '1080p':
                return 'bestvideo[height<=1080][vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[height<=1080]+bestaudio/best[height<=1080]';
            case '720p':
                return 'bestvideo[height<=720][vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[height<=720]+bestaudio/best[height<=720]';
            case '480p':
                return 'bestvideo[height<=480][vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo[height<=480]+bestaudio/best[height<=480]';
            default:
                return 'bestvideo[vcodec^=avc1]+bestaudio[acodec^=mp4a]/bestvideo+bestaudio/best';
        }
    }
}

module.exports = new YtdlpService();
