/**
 * VidFlow Web - Frontend Application
 */

class VidFlowApp {
    constructor() {
        this.currentUrl = '';
        this.videoInfo = null;
        this.activeDownloads = new Map();

        this.initElements();
        this.initEventListeners();
        this.loadHistory();
    }

    // ================================
    // Initialization
    // ================================

    initElements() {
        // URL Input
        this.urlInput = document.getElementById('url-input');
        this.pasteBtn = document.getElementById('paste-btn');
        this.fetchBtn = document.getElementById('fetch-btn');
        this.errorMessage = document.getElementById('error-message');

        // Video Preview
        this.videoPreview = document.getElementById('video-preview');
        this.videoThumbnail = document.getElementById('video-thumbnail');
        this.videoDuration = document.getElementById('video-duration');
        this.videoTitle = document.getElementById('video-title');
        this.videoUploader = document.getElementById('video-uploader');
        this.videoViews = document.getElementById('video-views');

        // Format Selection
        this.formatInputs = document.querySelectorAll('input[name="format"]');
        this.qualitySelect = document.getElementById('quality-select');
        this.qualityGroup = document.getElementById('quality-group');

        // Download
        this.downloadBtn = document.getElementById('download-btn');
        this.activeDownloadsCard = document.getElementById('active-downloads');
        this.downloadsList = document.getElementById('downloads-list');

        // Terminal
        this.terminalContent = document.getElementById('terminal-content');
        this.clearTerminalBtn = document.getElementById('clear-terminal');

        // History
        this.historyList = document.getElementById('history-list');
        this.clearHistoryBtn = document.getElementById('clear-history');

        // Navigation
        this.navBtns = document.querySelectorAll('.nav-btn');
        this.tabContents = document.querySelectorAll('.tab-content');
    }

    initEventListeners() {
        // URL Input events
        this.pasteBtn.addEventListener('click', () => this.handlePaste());
        this.fetchBtn.addEventListener('click', () => this.fetchVideoInfo());
        this.urlInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') this.fetchVideoInfo();
        });
        this.urlInput.addEventListener('input', () => {
            this.downloadBtn.disabled = !this.urlInput.value.trim();
        });

        // Format selection
        this.formatInputs.forEach(input => {
            input.addEventListener('change', () => this.handleFormatChange());
        });

        // Download button
        this.downloadBtn.addEventListener('click', () => this.startDownload());

        // Terminal
        this.clearTerminalBtn.addEventListener('click', () => this.clearTerminal());

        // History
        this.clearHistoryBtn.addEventListener('click', () => this.clearHistory());

        // Navigation
        this.navBtns.forEach(btn => {
            btn.addEventListener('click', () => this.switchTab(btn.dataset.tab));
        });
    }

    // ================================
    // URL & Video Info
    // ================================

    async handlePaste() {
        try {
            const text = await navigator.clipboard.readText();
            if (text && (text.includes('youtube') || text.includes('youtu.be') || text.startsWith('http'))) {
                this.urlInput.value = text;
                this.downloadBtn.disabled = false;
            }
        } catch (err) {
            console.error('Failed to read clipboard:', err);
        }
    }

    async fetchVideoInfo() {
        const url = this.urlInput.value.trim();
        if (!url) return;

        this.setLoading(true);
        this.hideError();
        this.videoPreview.classList.add('hidden');

        try {
            const response = await fetch('/api/info', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ url })
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || 'Failed to fetch video info');
            }

            this.videoInfo = data;
            this.displayVideoInfo(data);
            this.appendToTerminal(`✅ Video bulundu: ${data.title}\n`);

        } catch (error) {
            this.showError(error.message);
            this.appendToTerminal(`❌ Hata: ${error.message}\n`);
        } finally {
            this.setLoading(false);
        }
    }

    displayVideoInfo(info) {
        this.videoThumbnail.src = info.thumbnail || '';
        this.videoDuration.textContent = this.formatDuration(info.duration);
        this.videoTitle.textContent = info.title;
        this.videoUploader.textContent = info.uploader || 'Bilinmiyor';
        this.videoViews.innerHTML = `
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
                <circle cx="12" cy="12" r="3"/>
            </svg>
            ${this.formatViewCount(info.viewCount)} görüntüleme
        `;
        this.videoPreview.classList.remove('hidden');
    }

    // ================================
    // Format Selection
    // ================================

    handleFormatChange() {
        const selectedFormat = document.querySelector('input[name="format"]:checked').value;
        const isAudio = selectedFormat === 'mp3' || selectedFormat === 'm4a';

        this.qualitySelect.disabled = isAudio;
        if (isAudio) {
            this.qualityGroup.style.opacity = '0.5';
        } else {
            this.qualityGroup.style.opacity = '1';
        }
    }

    getSelectedFormat() {
        return document.querySelector('input[name="format"]:checked').value;
    }

    getSelectedQuality() {
        return this.qualitySelect.value;
    }

    // ================================
    // Download
    // ================================

    async startDownload() {
        const url = this.urlInput.value.trim();
        if (!url) return;

        const format = this.getSelectedFormat();
        const quality = this.getSelectedQuality();

        try {
            this.appendToTerminal(`\n--- İndirme Başlatılıyor ---\n`);
            this.appendToTerminal(`URL: ${url}\n`);
            this.appendToTerminal(`Format: ${format}, Kalite: ${quality}\n\n`);

            const response = await fetch('/api/download', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ url, format, quality })
            });

            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || 'Download failed');
            }

            // Start listening for progress
            this.listenToProgress(data.id);

            // Add to active downloads UI
            this.addDownloadToUI(data.id, this.videoInfo?.title || 'İndiriliyor...');

        } catch (error) {
            this.showError(error.message);
            this.appendToTerminal(`❌ Hata: ${error.message}\n`);
        }
    }

    listenToProgress(id) {
        const eventSource = new EventSource(`/api/progress/${id}`);

        eventSource.onmessage = (event) => {
            const data = JSON.parse(event.data);

            // Update UI
            this.updateDownloadUI(id, data);

            // Append to terminal
            if (data.output) {
                this.appendToTerminal(data.output);
            }

            // Handle completion
            if (data.status === 'completed') {
                this.appendToTerminal(`\n✅ İndirme tamamlandı!\n`);
                eventSource.close();
                this.loadHistory();
            } else if (data.status === 'failed') {
                this.appendToTerminal(`\n❌ İndirme başarısız: ${data.error}\n`);
                eventSource.close();
            }
        };

        eventSource.onerror = () => {
            eventSource.close();
        };
    }

    addDownloadToUI(id, title) {
        this.activeDownloadsCard.classList.remove('hidden');

        const item = document.createElement('div');
        item.className = 'download-item';
        item.id = `download-${id}`;
        item.innerHTML = `
            <div class="download-item-info">
                <div class="download-item-title">${this.escapeHtml(title)}</div>
                <div class="download-item-status">Başlatılıyor...</div>
                <div class="download-progress">
                    <div class="download-progress-bar" style="width: 0%"></div>
                </div>
            </div>
            <div class="download-item-actions hidden">
                <button class="download-action-btn" onclick="app.downloadFile('${id}')" title="İndir">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4M7 10l5 5 5-5M12 15V3"/>
                    </svg>
                </button>
            </div>
        `;

        this.downloadsList.appendChild(item);
        this.activeDownloads.set(id, { title });
    }

    updateDownloadUI(id, data) {
        const item = document.getElementById(`download-${id}`);
        if (!item) return;

        const statusEl = item.querySelector('.download-item-status');
        const progressBar = item.querySelector('.download-progress-bar');
        const actionsEl = item.querySelector('.download-item-actions');

        if (data.title) {
            item.querySelector('.download-item-title').textContent = data.title;
        }

        if (data.progress !== null && data.progress !== undefined) {
            progressBar.style.width = `${data.progress}%`;
            statusEl.textContent = `${data.progress.toFixed(1)}%${data.speed ? ` • ${data.speed}` : ''}${data.eta ? ` • ETA: ${data.eta}` : ''}`;
        }

        if (data.status === 'completed') {
            statusEl.textContent = 'Tamamlandı ✓';
            statusEl.style.color = 'var(--success)';
            progressBar.style.width = '100%';
            actionsEl.classList.remove('hidden');
        } else if (data.status === 'failed') {
            statusEl.textContent = `Başarısız: ${data.error || 'Bilinmeyen hata'}`;
            statusEl.style.color = 'var(--danger)';
        }
    }

    downloadFile(id) {
        window.location.href = `/api/download/${id}`;
    }

    // ================================
    // History
    // ================================

    async loadHistory() {
        try {
            const response = await fetch('/api/history');
            const history = await response.json();
            this.displayHistory(history);
        } catch (error) {
            console.error('Failed to load history:', error);
        }
    }

    displayHistory(history) {
        if (history.length === 0) {
            this.historyList.innerHTML = '<p class="empty-message">Henüz indirme geçmişi yok.</p>';
            return;
        }

        this.historyList.innerHTML = history.map(item => `
            <div class="history-item" data-id="${item.id}">
                <div class="history-item-icon">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        ${item.format === 'mp3' || item.format === 'm4a'
                ? '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>'
                : '<polygon points="23 7 16 12 23 17 23 7"/><rect x="1" y="5" width="15" height="14" rx="2" ry="2"/>'}
                    </svg>
                </div>
                <div class="history-item-info">
                    <div class="history-item-title">${this.escapeHtml(item.title)}</div>
                    <div class="history-item-meta">
                        ${item.format.toUpperCase()} • ${this.formatBytes(item.fileSize)} • ${this.formatDate(item.completedAt)}
                    </div>
                </div>
                <div class="history-item-actions">
                    <button class="icon-btn small" onclick="app.downloadFile('${item.id}')" title="İndir">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4M7 10l5 5 5-5M12 15V3"/>
                        </svg>
                    </button>
                    <button class="icon-btn small danger" onclick="app.deleteHistoryItem('${item.id}')" title="Sil">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <polyline points="3 6 5 6 21 6"/>
                            <path d="M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/>
                        </svg>
                    </button>
                </div>
            </div>
        `).join('');
    }

    async deleteHistoryItem(id) {
        if (!confirm('Bu öğeyi silmek istediğinize emin misiniz?')) return;

        try {
            await fetch(`/api/history/${id}`, { method: 'DELETE' });
            this.loadHistory();
        } catch (error) {
            console.error('Failed to delete item:', error);
        }
    }

    async clearHistory() {
        if (!confirm('Tüm geçmişi silmek istediğinize emin misiniz?')) return;

        try {
            await fetch('/api/history', { method: 'DELETE' });
            this.loadHistory();
        } catch (error) {
            console.error('Failed to clear history:', error);
        }
    }

    // ================================
    // Terminal
    // ================================

    appendToTerminal(text) {
        const placeholder = this.terminalContent.querySelector('.terminal-placeholder');
        if (placeholder) {
            placeholder.remove();
        }

        this.terminalContent.textContent += text;
        this.terminalContent.scrollTop = this.terminalContent.scrollHeight;
    }

    clearTerminal() {
        this.terminalContent.innerHTML = '<p class="terminal-placeholder">İndirme başlamak için hazır...</p>';
    }

    // ================================
    // Navigation
    // ================================

    switchTab(tabName) {
        this.navBtns.forEach(btn => {
            btn.classList.toggle('active', btn.dataset.tab === tabName);
        });

        this.tabContents.forEach(content => {
            content.classList.toggle('active', content.id === `${tabName}-tab`);
        });

        if (tabName === 'history') {
            this.loadHistory();
        }
    }

    // ================================
    // UI Helpers
    // ================================

    setLoading(loading) {
        if (loading) {
            this.fetchBtn.innerHTML = '<div class="loading"></div>';
            this.fetchBtn.disabled = true;
        } else {
            this.fetchBtn.innerHTML = `
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="11" cy="11" r="8"/>
                    <path d="M21 21l-4.35-4.35"/>
                </svg>
            `;
            this.fetchBtn.disabled = false;
        }
    }

    showError(message) {
        this.errorMessage.textContent = message;
    }

    hideError() {
        this.errorMessage.textContent = '';
    }

    // ================================
    // Formatting Helpers
    // ================================

    formatDuration(seconds) {
        if (!seconds) return '0:00';
        const h = Math.floor(seconds / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        const s = Math.floor(seconds % 60);

        if (h > 0) {
            return `${h}:${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
        }
        return `${m}:${s.toString().padStart(2, '0')}`;
    }

    formatViewCount(count) {
        if (!count) return '0';
        if (count >= 1000000) {
            return (count / 1000000).toFixed(1) + 'M';
        }
        if (count >= 1000) {
            return (count / 1000).toFixed(1) + 'K';
        }
        return count.toString();
    }

    formatBytes(bytes) {
        if (!bytes) return '0 B';
        const units = ['B', 'KB', 'MB', 'GB'];
        let i = 0;
        while (bytes >= 1024 && i < units.length - 1) {
            bytes /= 1024;
            i++;
        }
        return bytes.toFixed(1) + ' ' + units[i];
    }

    formatDate(dateString) {
        if (!dateString) return '';
        const date = new Date(dateString);
        return date.toLocaleDateString('tr-TR', {
            day: 'numeric',
            month: 'short',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize app
const app = new VidFlowApp();
