# VidFlow Sunucu Yönetim Kılavuzu
**Tarih:** 25 Aralık 2025

---

## 📋 Sunucu Bilgileri

| Bilgi | Değer |
|-------|-------|
| **IP Adresi** | `193.35.154.183` |
| **Kullanıcı** | `root` |
| **Şifre** | `Ab20752490.` |
| **Domain** | https://vidflow.adilemre.xyz |
| **Uygulama Dizini** | `/var/www/vidflow` |
| **Node.js** | v20.19.6 |
| **yt-dlp** | 2025.12.08 |
| **FFmpeg** | 6.1.1 |

---

## 🔌 SSH Bağlantısı

```bash
ssh root@193.35.154.183
```
Şifre: `Ab20752490.`

---

## 📦 PM2 Uygulama Yönetimi

| Komut | Açıklama |
|-------|----------|
| `pm2 list` | Tüm uygulamaları listele |
| `pm2 restart vidflow` | VidFlow'u yeniden başlat |
| `pm2 stop vidflow` | VidFlow'u durdur |
| `pm2 start vidflow` | VidFlow'u başlat |
| `pm2 logs vidflow` | Canlı logları izle |
| `pm2 logs vidflow --lines 100` | Son 100 satır log |
| `pm2 monit` | CPU/RAM izleme paneli |

---

## 🌐 Cloudflare Tunnel Yönetimi

| Komut | Açıklama |
|-------|----------|
| `systemctl status cloudflared` | Durumu kontrol et |
| `systemctl restart cloudflared` | Yeniden başlat |
| `systemctl stop cloudflared` | Durdur |
| `systemctl start cloudflared` | Başlat |
| `journalctl -u cloudflared -f` | Logları izle |
| `journalctl -u cloudflared --since "1 hour ago"` | Son 1 saat log |

---

## 🚀 SİTE GÜNCELLEME (DEPLOYMENT)

Lokal bilgisayarından siteyi güncelledikten sonra sunucuya yüklemek için:

### Yöntem 1: SCP ile Dosya Yükleme (Önerilen)

```bash
# Tüm vidflow-web klasörünü sunucuya yükle
scp -r /Users/adilemre/Documents/projelerim/youtube/vidflow-web/* root@193.35.154.183:/var/www/vidflow/
```

Sonra sunucuda:
```bash
ssh root@193.35.154.183
cd /var/www/vidflow
npm install          # Yeni paket varsa
pm2 restart vidflow  # Uygulamayı yeniden başlat
```

### Yöntem 2: Tek Tek Dosya Güncelleme

```bash
# Örnek: Sadece server.js güncelle
scp /Users/adilemre/Documents/projelerim/youtube/vidflow-web/server.js root@193.35.154.183:/var/www/vidflow/

# Örnek: CSS güncelle
scp /Users/adilemre/Documents/projelerim/youtube/vidflow-web/public/css/style.css root@193.35.154.183:/var/www/vidflow/public/css/

# Örnek: JS güncelle
scp /Users/adilemre/Documents/projelerim/youtube/vidflow-web/public/js/app.js root@193.35.154.183:/var/www/vidflow/public/js/
```

### Yöntem 3: Rsync ile Senkronize Et

```bash
rsync -avz --delete /Users/adilemre/Documents/projelerim/youtube/vidflow-web/ root@193.35.154.183:/var/www/vidflow/
```

### Güncelleme Sonrası Kontrol

```bash
ssh root@193.35.154.183
pm2 restart vidflow
pm2 logs vidflow      # Hata var mı kontrol et
```

---

## 🔧 Sistem Kontrolleri

| Komut | Açıklama |
|-------|----------|
| `df -h` | Disk kullanımı |
| `free -h` | RAM kullanımı |
| `htop` | CPU ve süreç izleme |
| `ss -tlnp \| grep 3000` | Port 3000 kontrolü |
| `ps aux \| grep node` | Node süreçleri |
| `uptime` | Sunucu uptime |

---

## 🔄 Yazılım Güncelleme

### yt-dlp Güncelle (Önemli!)
```bash
pip3 install -U yt-dlp
pm2 restart vidflow
```

### Node.js Paketlerini Güncelle
```bash
cd /var/www/vidflow
npm update
pm2 restart vidflow
```

### Sistem Güncelle
```bash
apt update && apt upgrade -y
```

### Cloudflared Güncelle
```bash
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared.deb
rm cloudflared.deb
systemctl restart cloudflared
```

---

## 🛠️ Sorun Giderme

### Site Açılmıyorsa

**1. PM2 Kontrolü:**
```bash
pm2 list
# "errored" veya "stopped" ise:
pm2 restart vidflow
pm2 logs vidflow
```

**2. Cloudflared Kontrolü:**
```bash
systemctl status cloudflared
# Çalışmıyorsa:
systemctl restart cloudflared
```

**3. Port Kontrolü:**
```bash
ss -tlnp | grep 3000
# Boş dönerse uygulama çalışmıyor
```

### Video İndirilmiyorsa

```bash
# yt-dlp'yi test et
yt-dlp --version
yt-dlp -F "https://www.youtube.com/watch?v=dQw4w9WgXcQ"

# Güncelle
pip3 install -U yt-dlp
pm2 restart vidflow
```

### Disk Doluysa

```bash
# Disk durumu
df -h

# İndirilen dosyaları temizle
rm -rf /var/www/vidflow/downloads/*

# Sistem loglarını temizle
journalctl --vacuum-time=7d

# Büyük dosyaları bul
du -sh /var/www/vidflow/*
```

### Sunucu Yeniden Başladıysa

Otomatik başlaması gerekiyor, ama kontrol et:
```bash
pm2 list
systemctl status cloudflared
```

---

## 💾 Yedekleme

### Uygulama Yedeği Al
```bash
# Sunucudan bilgisayara indir
scp -r root@193.35.154.183:/var/www/vidflow ~/Desktop/vidflow-backup
```

### Veritabanı/Config Yedeği (varsa)
```bash
scp root@193.35.154.183:/var/www/vidflow/.env ~/Desktop/vidflow-env-backup
```

---

## 🔐 Güvenlik

### Şifre Değiştir
```bash
passwd root
```

### Firewall Durumu
```bash
ufw status
```

### SSH Key Ekle (Önerilen)
```bash
# Lokalde key oluştur
ssh-keygen -t ed25519

# Sunucuya kopyala
ssh-copy-id root@193.35.154.183
```

---

## 📝 Kurulum Özeti (25 Aralık 2025)

### Yapılan İşlemler:

1. **Sistem Kontrolü** - Node.js, yt-dlp, FFmpeg doğrulandı
2. **Cloudflared Kurulumu:**
   ```bash
   curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
   dpkg -i cloudflared.deb
   cloudflared service install <TOKEN>
   systemctl enable cloudflared
   systemctl start cloudflared
   ```
3. **Cloudflare Dashboard Ayarları:**
   - Zero Trust → Networks → Tunnels → vidflow
   - Public Hostname: `vidflow.adilemre.xyz` → `localhost:3000`

---

## 🔗 Önemli Linkler

- **Site:** https://vidflow.adilemre.xyz
- **Direkt IP:** http://193.35.154.183:3000
- **Cloudflare Dashboard:** https://dash.cloudflare.com
- **Zero Trust Panel:** https://one.dash.cloudflare.com

---

## 📞 Hızlı Referans

```bash
# SSH Bağlan
ssh root@193.35.154.183

# Site Güncelle (Mac'ten)
scp -r /Users/adilemre/Documents/projelerim/youtube/vidflow-web/* root@193.35.154.183:/var/www/vidflow/ && ssh root@193.35.154.183 "pm2 restart vidflow"

# Durumu Kontrol Et
ssh root@193.35.154.183 "pm2 list && systemctl status cloudflared --no-pager"

# Logları Gör
ssh root@193.35.154.183 "pm2 logs vidflow --lines 50"

# yt-dlp Güncelle
ssh root@193.35.154.183 "pip3 install -U yt-dlp && pm2 restart vidflow"
```
