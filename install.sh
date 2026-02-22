#!/bin/bash
# ================================================
# SSH BOT PRO - WPPCONNECT + MERCADOPAGO + HTTP CUSTOM
# VERSIÓN CON HWID Y ARCHIVOS HC
# ================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

clear
echo -e "${CYAN}${BOLD}"
cat << "BANNER"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     ███████╗███████╗██║  ██║    ██████╗  ██████╗ ████████╗  ║
║     ██╔════╝██╔════╝██║  ██║    ██╔══██╗██╔═══██╗╚══██╔══╝  ║
║     ███████╗███████╗███████║    ██████╔╝██║   ██║   ██║     ║
║     ╚════██║╚════██║██╔══██║    ██╔══██╗██║   ██║   ██║     ║
║     ███████║███████║██║  ██║    ██████╔╝╚██████╔╝   ██║     ║
║     ╚══════╝╚══════╝╚═╝  ╚═╝    ╚═════╝  ╚═════╝    ╚═╝     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║          🤖 SSH BOT PRO - HTTP CUSTOM + MERCADOPAGO         ║
║               📱 WhatsApp API + HWID + HC FILES            ║
║               💰 MercadoPago SDK v2.x INTEGRADO            ║
║               💳 Pago automático con QR                    ║
║               📁 Sistema de archivos HTTP Custom           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CARACTERÍSTICAS PRINCIPALES:${NC}"
echo -e "  📱 ${CYAN}WPPConnect${NC} - API WhatsApp que funciona"
echo -e "  💰 ${GREEN}MercadoPago SDK v2.x${NC} - Integrado completo"
echo -e "  💳 ${YELLOW}Pago automático${NC} - QR + Enlace de pago"
echo -e "  📁 ${PURPLE}HTTP CUSTOM${NC} - Sistema HWID + Archivos HC"
echo -e "  🎛️  ${BLUE}Panel completo${NC} - Subir/administrar archivos HC"
echo -e "  📊 ${GREEN}Estadísticas${NC} - Ventas, usuarios, ingresos"
echo -e "  ⚡ ${CYAN}Auto-verificación${NC} - Pagos verificados cada 2 min"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Debes ejecutar como root${NC}"
    echo -e "${YELLOW}Usa: sudo bash $0${NC}"
    exit 1
fi

# Detectar IP
echo -e "${CYAN}🔍 Detectando IP...${NC}"
SERVER_IP=$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "127.0.0.1")
if [[ -z "$SERVER_IP" || "$SERVER_IP" == "127.0.0.1" ]]; then
    read -p "📝 Ingresa la IP del servidor: " SERVER_IP
fi

echo -e "${GREEN}✅ IP: ${CYAN}$SERVER_IP${NC}\n"

read -p "$(echo -e "${YELLOW}¿Continuar instalación? (s/N): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${RED}❌ Cancelado${NC}"
    exit 0
fi

# ================================================
# INSTALAR DEPENDENCIAS
# ================================================
echo -e "\n${CYAN}📦 Instalando dependencias...${NC}"

apt-get update -y
apt-get upgrade -y

# Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs gcc g++ make

# Chrome/Chromium
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get update -y
apt-get install -y google-chrome-stable

# Dependencias del sistema
apt-get install -y \
    git curl wget sqlite3 jq nginx \
    build-essential libcairo2-dev \
    libpango1.0-dev libjpeg-dev \
    libgif-dev librsvg2-dev \
    python3 python3-pip ffmpeg \
    unzip cron ufw

# Configurar firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8001/tcp
ufw allow 3000/tcp
ufw --force enable

# PM2
npm install -g pm2
pm2 update

echo -e "${GREEN}✅ Dependencias instaladas${NC}"

# ================================================
# CONFIGURAR NGINX PARA ARCHIVOS HC
# ================================================
echo -e "\n${CYAN}📁 Configurando servidor de archivos HC...${NC}"

mkdir -p /var/www/html/hc_files
chmod -R 755 /var/www/html

cat > /etc/nginx/sites-available/hc-files << 'NGINXEOF'
server {
    listen 80;
    server_name _;
    
    root /var/www/html;
    index index.html;
    
    location /hc_files/ {
        alias /var/www/html/hc_files/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
    
    location /download/ {
        alias /var/www/html/hc_files/;
        add_header Content-Disposition 'attachment; filename="$1"';
    }
}
NGINXEOF

ln -sf /etc/nginx/sites-available/hc-files /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

echo -e "${GREEN}✅ Servidor de archivos configurado en: http://$SERVER_IP/hc_files/${NC}"

# ================================================
# PREPARAR ESTRUCTURA
# ================================================
echo -e "\n${CYAN}📁 Creando estructura...${NC}"

INSTALL_DIR="/opt/sshbot-pro"
USER_HOME="/root/sshbot-pro"
DB_FILE="$INSTALL_DIR/data/users.db"
CONFIG_FILE="$INSTALL_DIR/config/config.json"
HC_FILES_DIR="$INSTALL_DIR/hc_files"
HC_UPLOADS_DIR="/var/www/html/hc_files"

# Limpiar anterior
pm2 delete sshbot-pro 2>/dev/null || true
rm -rf "$INSTALL_DIR" "$USER_HOME" 2>/dev/null || true
rm -rf /root/.wppconnect 2>/dev/null || true

# Crear directorios
mkdir -p "$INSTALL_DIR"/{data,config,sessions,logs,qr_codes,hc_files}
mkdir -p "$USER_HOME"
mkdir -p "$HC_UPLOADS_DIR"
mkdir -p /root/.wppconnect
chmod -R 755 "$INSTALL_DIR"
chmod -R 755 "$HC_UPLOADS_DIR"
chmod -R 700 /root/.wppconnect

# Configuración inicial
cat > "$CONFIG_FILE" << EOF
{
    "bot": {
        "name": "SSH Bot Pro - HTTP Custom",
        "version": "3.0-HWID-HC",
        "server_ip": "$SERVER_IP",
        "default_password": "mgvpn247"
    },
    "prices": {
        "test_hours": 1,
        "price_7d": 3000.00,
        "price_15d": 4000.00,
        "price_30d": 7000.00,
        "price_50d": 9700.00,
        "currency": "ARS"
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false,
        "public_key": ""
    },
    "http_custom": {
        "server_url": "http://$SERVER_IP/hc_files/",
        "default_file": "config.hc",
        "hwid_enabled": true
    },
    "links": {
        "app_download": "https://play.google.com/store/apps/details?id=http.custom",
        "support": "https://wa.me/543435071016"
    },
    "paths": {
        "database": "$DB_FILE",
        "qr_codes": "$INSTALL_DIR/qr_codes",
        "hc_files": "$HC_FILES_DIR",
        "sessions": "/root/.wppconnect"
    }
}
EOF

# Crear base de datos COMPLETA con soporte HWID
sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    username TEXT UNIQUE,
    password TEXT DEFAULT 'mgvpn247',
    tipo TEXT DEFAULT 'test',
    hwid TEXT,
    hc_file TEXT,
    expires_at DATETIME,
    status INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE daily_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    date DATE,
    hwid_used TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(phone, date)
);

CREATE TABLE payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_id TEXT UNIQUE,
    phone TEXT,
    plan TEXT,
    days INTEGER,
    amount REAL,
    status TEXT DEFAULT 'pending',
    payment_url TEXT,
    qr_code TEXT,
    preference_id TEXT,
    hwid TEXT,
    hc_file_generated TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    approved_at DATETIME
);

CREATE TABLE hc_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT UNIQUE,
    original_name TEXT,
    description TEXT,
    size INTEGER,
    downloads INTEGER DEFAULT 0,
    active INTEGER DEFAULT 1,
    uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT,
    message TEXT,
    data TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE user_state (
    phone TEXT PRIMARY KEY,
    state TEXT DEFAULT 'main_menu',
    data TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_hwid ON users(hwid);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_hwid ON payments(hwid);
SQL

echo -e "${GREEN}✅ Estructura creada con soporte HWID${NC}"

# ================================================
# CREAR BOT COMPLETO CON HWID Y HTTP CUSTOM
# ================================================
echo -e "\n${CYAN}🤖 Creando bot con WPPConnect + MercadoPago + HTTP Custom...${NC}"

cd "$USER_HOME"

# package.json
cat > package.json << 'PKGEOF'
{
    "name": "sshbot-pro-hc",
    "version": "3.0.0",
    "main": "bot.js",
    "dependencies": {
        "@wppconnect-team/wppconnect": "^1.24.0",
        "qrcode-terminal": "^0.12.0",
        "qrcode": "^1.5.3",
        "moment": "^2.30.1",
        "sqlite3": "^5.1.7",
        "chalk": "^4.1.2",
        "node-cron": "^3.0.3",
        "mercadopago": "^2.0.15",
        "axios": "^1.6.5",
        "sharp": "^0.33.2",
        "multer": "^1.4.5-lts.1",
        "express": "^4.18.2"
    }
}
PKGEOF

echo -e "${YELLOW}📦 Instalando dependencias...${NC}"
npm install --silent 2>&1 | grep -v "npm WARN" || true

# Crear bot.js con soporte HWID
echo -e "${YELLOW}📝 Creando bot.js con HWID y HTTP Custom...${NC}"

cat > "bot.js" << 'BOTEOF'
const wppconnect = require('@wppconnect-team/wppconnect');
const qrcode = require('qrcode-terminal');
const QRCode = require('qrcode');
const moment = require('moment');
const sqlite3 = require('sqlite3').verbose();
const { exec } = require('child_process');
const util = require('util');
const chalk = require('chalk');
const cron = require('node-cron');
const fs = require('fs');
const path = require('path');
const axios = require('axios');
const crypto = require('crypto');

const execPromise = util.promisify(exec);
moment.locale('es');

console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════════════╗'));
console.log(chalk.cyan.bold('║        🤖 SSH BOT PRO - HTTP CUSTOM + HWID + MP             ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

// Cargar configuración
function loadConfig() {
    delete require.cache[require.resolve('/opt/sshbot-pro/config/config.json')];
    return require('/opt/sshbot-pro/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/sshbot-pro/data/users.db');

// ✅ MERCADOPAGO SDK V2.X
let mpEnabled = false;
let mpClient = null;
let mpPreference = null;

function initMercadoPago() {
    config = loadConfig();
    if (config.mercadopago.access_token && config.mercadopago.access_token !== '') {
        try {
            const { MercadoPagoConfig, Preference } = require('mercadopago');
            
            mpClient = new MercadoPagoConfig({ 
                accessToken: config.mercadopago.access_token,
                options: { timeout: 5000, idempotencyKey: true }
            });
            
            mpPreference = new Preference(mpClient);
            mpEnabled = true;
            
            console.log(chalk.green('✅ MercadoPago SDK v2.x ACTIVO'));
            return true;
        } catch (error) {
            console.log(chalk.red('❌ Error inicializando MP:'), error.message);
            mpEnabled = false;
            return false;
        }
    }
    console.log(chalk.yellow('⚠️ MercadoPago NO configurado'));
    return false;
}

initMercadoPago();

// Variables globales
let client = null;

// ✅ FUNCIONES PARA HWID Y HTTP CUSTOM
function generateHCFile(hwid, days, username) {
    try {
        // Crear archivo de configuración HTTP Custom
        const configContent = `# HTTP Custom Config
# Generado para: ${username}
# HWID: ${hwid}
# Expira: ${moment().add(days, 'days').format('DD/MM/YYYY')}

[config]
name=SSH-PRO-${username}
server=${config.bot.server_ip}
port=22,80,443
type=ssh
payload=GET / HTTP/1.1[crlf]Host: [host][crlf]Connection: Keep-Alive[crlf]User-Agent: [ua][crlf][crlf]
ssh_method=1
dns=8.8.8.8
timeout=30
hwid=${hwid}
expires=${moment().add(days, 'days').unix()}
username=${username}
password=${config.bot.default_password}`;

        const filename = `config_${username}_${hwid.substring(0, 8)}.hc`;
        const filePath = path.join(config.paths.hc_files, filename);
        const publicPath = `/var/www/html/hc_files/${filename}`;
        
        fs.writeFileSync(filePath, configContent);
        fs.copyFileSync(filePath, publicPath);
        
        return {
            success: true,
            filename: filename,
            path: publicPath,
            url: `http://${config.bot.server_ip}/hc_files/${filename}`
        };
    } catch (error) {
        console.error(chalk.red('❌ Error generando HC file:'), error.message);
        return { success: false, error: error.message };
    }
}

function validateHWID(hwid) {
    // Formato HWID típico: 32 caracteres hexadecimales
    return /^[0-9a-fA-F]{32}$/.test(hwid);
}

function checkExistingHWID(hwid) {
    return new Promise((resolve) => {
        db.get('SELECT * FROM users WHERE hwid = ? AND status = 1 AND expires_at > datetime("now")', [hwid], (err, row) => {
            resolve(row ? true : false);
        });
    });
}

function getUserByHWID(hwid) {
    return new Promise((resolve) => {
        db.get('SELECT * FROM users WHERE hwid = ? AND status = 1 AND expires_at > datetime("now")', [hwid], (err, row) => {
            resolve(row || null);
        });
    });
}

// ✅ SISTEMA DE ESTADOS
function getUserState(phone) {
    return new Promise((resolve) => {
        db.get('SELECT state, data FROM user_state WHERE phone = ?', [phone], (err, row) => {
            if (err || !row) {
                resolve({ state: 'main_menu', data: null });
            } else {
                resolve({
                    state: row.state || 'main_menu',
                    data: row.data ? JSON.parse(row.data) : null
                });
            }
        });
    });
}

function setUserState(phone, state, data = null) {
    return new Promise((resolve) => {
        const dataStr = data ? JSON.stringify(data) : null;
        db.run(
            `INSERT OR REPLACE INTO user_state (phone, state, data, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)`,
            [phone, state, dataStr],
            (err) => {
                if (err) console.error(chalk.red('❌ Error estado:'), err.message);
                resolve();
            }
        );
    });
}

// Funciones auxiliares
function generateUsername() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    const randomNum = Math.floor(1000 + Math.random() * 9000);
    return `test${randomNum}`;
}

function generatePremiumUsername() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    const randomNum = Math.floor(1000 + Math.random() * 9000);
    return `user${randomNum}`;
}

const DEFAULT_PASSWORD = 'mgvpn247';

async function createHTTPCustomUser(phone, username, days, hwid = null) {
    const password = DEFAULT_PASSWORD;
    
    if (days === 0) {
        // Test - 1 hora
        const expireFull = moment().add(config.prices.test_hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
        
        try {
            // No crear usuario del sistema, solo registro en BD
            if (hwid) {
                const hcFile = generateHCFile(hwid, 0, username);
                
                db.run(`INSERT INTO users (phone, username, password, tipo, hwid, hc_file, expires_at) VALUES (?, ?, ?, 'test', ?, ?, ?)`,
                    [phone, username, password, hwid, hcFile.filename, expireFull]);
                
                return { success: true, username, password, hwid, hcFile: hcFile.url, expires: expireFull };
            } else {
                db.run(`INSERT INTO users (phone, username, password, tipo, expires_at) VALUES (?, ?, ?, 'test', ?)`,
                    [phone, username, password, expireFull]);
                
                return { success: true, username, password, expires: expireFull };
            }
        } catch (error) {
            console.error(chalk.red('❌ Error:'), error.message);
            return { success: false, error: error.message };
        }
    } else {
        // Premium
        const expireFull = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
        
        try {
            // Crear usuario del sistema
            await execPromise(`useradd -M -s /bin/false -e ${moment().add(days, 'days').format('YYYY-MM-DD')} ${username} && echo "${username}:${password}" | chpasswd`);
            
            if (hwid) {
                const hcFile = generateHCFile(hwid, days, username);
                
                db.run(`INSERT INTO users (phone, username, password, tipo, hwid, hc_file, expires_at) VALUES (?, ?, ?, 'premium', ?, ?, ?)`,
                    [phone, username, password, hwid, hcFile.filename, expireFull]);
                
                return { success: true, username, password, hwid, hcFile: hcFile.url, expires: expireFull };
            } else {
                db.run(`INSERT INTO users (phone, username, password, tipo, expires_at) VALUES (?, ?, ?, 'premium', ?)`,
                    [phone, username, password, expireFull]);
                
                return { success: true, username, password, expires: expireFull };
            }
        } catch (error) {
            console.error(chalk.red('❌ Error:'), error.message);
            return { success: false, error: error.message };
        }
    }
}

function canCreateTest(phone, hwid = null) {
    return new Promise((resolve) => {
        const today = moment().format('YYYY-MM-DD');
        
        if (hwid) {
            db.get('SELECT COUNT(*) as count FROM daily_tests WHERE (phone = ? OR hwid_used = ?) AND date = ?', 
                [phone, hwid, today], (err, row) => resolve(!err && row && row.count === 0));
        } else {
            db.get('SELECT COUNT(*) as count FROM daily_tests WHERE phone = ? AND date = ?', [phone, today],
                (err, row) => resolve(!err && row && row.count === 0));
        }
    });
}

function registerTest(phone, hwid = null) {
    db.run('INSERT OR IGNORE INTO daily_tests (phone, date, hwid_used) VALUES (?, ?, ?)', 
        [phone, moment().format('YYYY-MM-DD'), hwid]);
}

// ✅ MERCADOPAGO - CREAR PAGO
async function createMercadoPagoPayment(phone, days, amount, planName) {
    try {
        if (!mpEnabled || !mpPreference) {
            return { success: false, error: 'MercadoPago no configurado' };
        }
        
        const phoneClean = phone.replace('@c.us', '');
        const paymentId = `SSH-${phoneClean}-${days}d-${Date.now()}`;
        
        console.log(chalk.cyan(`🔄 Creando pago MP: ${paymentId}`));
        
        const expirationDate = moment().add(24, 'hours');
        const isoDate = expirationDate.toISOString();
        
        const preferenceData = {
            items: [{
                title: `HTTP CUSTOM ${days} DÍAS`,
                description: `Configuración HTTP Custom por ${days} días - HWID`,
                quantity: 1,
                currency_id: config.prices.currency || 'ARS',
                unit_price: parseFloat(amount)
            }],
            external_reference: paymentId,
            expires: true,
            expiration_date_from: moment().toISOString(),
            expiration_date_to: isoDate,
            back_urls: {
                success: `https://wa.me/${phoneClean}?text=Ya%20pague%20mgvpn`,
                failure: `https://wa.me/${phoneClean}?text=Pago%20fallido%20SSH`,
                pending: `https://wa.me/${phoneClean}?text=Pago%20pendiente%20SSH`
            },
            auto_return: 'approved',
            statement_descriptor: 'HTTP CUSTOM'
        };
        
        const response = await mpPreference.create({ body: preferenceData });
        
        if (response && response.id) {
            const paymentUrl = response.init_point;
            const qrPath = `${config.paths.qr_codes}/${paymentId}.png`;
            
            await QRCode.toFile(qrPath, paymentUrl, { width: 400 });
            
            db.run(
                `INSERT INTO payments (payment_id, phone, plan, days, amount, status, payment_url, qr_code, preference_id) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
                [paymentId, phone, `${days}d`, days, amount, paymentUrl, qrPath, response.id]
            );
            
            return { success: true, paymentId, paymentUrl, qrPath };
        }
        
        throw new Error('Respuesta inválida de MercadoPago');
        
    } catch (error) {
        console.error(chalk.red('❌ Error MercadoPago:'), error.message);
        return { success: false, error: error.message };
    }
}

// ✅ VERIFICAR PAGOS PENDIENTES
async function checkPendingPayments() {
    if (!mpEnabled) return;
    
    db.all('SELECT * FROM payments WHERE status = "pending" AND created_at > datetime("now", "-48 hours")', async (err, payments) => {
        if (err || !payments || payments.length === 0) return;
        
        console.log(chalk.yellow(`🔍 Verificando ${payments.length} pagos...`));
        
        for (const payment of payments) {
            try {
                const url = `https://api.mercadopago.com/v1/payments/search?external_reference=${payment.payment_id}`;
                const response = await axios.get(url, {
                    headers: { 
                        'Authorization': `Bearer ${config.mercadopago.access_token}`
                    }
                });
                
                if (response.data && response.data.results && response.data.results.length > 0) {
                    const mpPayment = response.data.results[0];
                    
                    if (mpPayment.status === 'approved') {
                        console.log(chalk.green(`✅ PAGO APROBADO: ${payment.payment_id}`));
                        
                        // Esperar HWID del usuario
                        // El usuario enviará su HWID después del pago
                        
                        db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`, [payment.payment_id]);
                        
                        // Notificar al usuario
                        const message = `✅ PAGO CONFIRMADO

🎉 Tu pago ha sido aprobado.

📲 Para continuar, envía tu HWID de HTTP Custom.

🔍 Para obtener tu HWID:
1. Abre HTTP Custom
2. Ve a "Configuración"
3. Copia el código HWID (32 caracteres)

📝 Responde con tu HWID para generar tu archivo de configuración.`;
                        
                        if (client) {
                            await client.sendText(payment.phone, message);
                            await setUserState(payment.phone, 'awaiting_hwid', { payment_id: payment.payment_id, days: payment.days });
                        }
                    }
                }
            } catch (error) {
                console.error(chalk.red(`❌ Error verificando ${payment.payment_id}:`), error.message);
            }
        }
    });
}

// Inicializar WPPConnect
async function initializeBot() {
    try {
        console.log(chalk.yellow('🚀 Inicializando WPPConnect...'));
        
        client = await wppconnect.create({
            session: 'sshbot-pro-hc-session',
            headless: true,
            devtools: false,
            useChrome: true,
            debug: false,
            logQR: true,
            browserArgs: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--no-first-run',
                '--no-zygote',
                '--disable-gpu'
            ],
            puppeteerOptions: {
                executablePath: '/usr/bin/google-chrome',
                headless: 'new',
                args: ['--no-sandbox', '--disable-setuid-sandbox']
            },
            disableWelcome: true,
            updatesLog: false,
            folderNameToken: '/root/.wppconnect'
        });
        
        console.log(chalk.green('✅ WPPConnect conectado!'));
        
        // Manejar mensajes
        client.onMessage(async (message) => {
            try {
                const text = message.body.toLowerCase().trim();
                const from = message.from;
                
                console.log(chalk.cyan(`📩 [${from}]: ${text.substring(0, 30)}`));
                
                const userState = await getUserState(from);
                
                // MENÚ PRINCIPAL
                if (['menu', 'hola', 'start', 'hi', 'volver', '0'].includes(text)) {
                    await setUserState(from, 'main_menu');
                    
                    await client.sendText(from, `🚀 *HTTP CUSTOM BOT*

Elija una opción:

🧪 1 - PRUEBA GRATIS (1 hora)
💰 2 - COMPRAR CONFIGURACIÓN
🔄 3 - RENOVAR / VERIFICAR
📱 4 - DESCARGAR HTTP CUSTOM
❓ 5 - CÓMO OBTENER HWID

👨‍💻 Soporte: ${config.links.support}`);
                }
                
                // OPCIÓN 5: CÓMO OBTENER HWID
                else if (text === '5' && userState.state === 'main_menu') {
                    await client.sendText(from, `🔍 *CÓMO OBTENER TU HWID*

1. Abre la aplicación HTTP Custom
2. Ve a *Configuración* (⚙️)
3. Busca la sección *HWID*
4. Copia el código (32 caracteres)
5. Envíalo cuando te lo pidan

📱 *Ejemplo de HWID:*
\`a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6\`

⚠️ *IMPORTANTE:*
- El HWID es único por dispositivo
- No lo compartas con nadie
- Cada HWID solo puede tener 1 cuenta activa`);
                }
                
                // OPCIÓN 1: CREAR PRUEBA
                else if (text === '1' && userState.state === 'main_menu') {
                    await setUserState(from, 'awaiting_test_hwid');
                    await client.sendText(from, `📲 *PRUEBA GRATUITA*

Envía tu HWID de HTTP Custom para generar tu prueba de ${config.prices.test_hours} hora.

🔍 *Instrucciones:*
1. Abre HTTP Custom
2. Ve a Configuración
3. Copia tu HWID
4. Pégalo aquí

📝 *Ejemplo:* a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`);
                }
                
                // RECIBIR HWID PARA PRUEBA
                else if (userState.state === 'awaiting_test_hwid') {
                    const hwid = message.body.trim();
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ *HWID INVÁLIDO*

El HWID debe tener 32 caracteres hexadecimales.

🔍 Ejemplo: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6

Intenta nuevamente:`);
                        return;
                    }
                    
                    if (await checkExistingHWID(hwid)) {
                        await client.sendText(from, `❌ *HWID YA REGISTRADO*

Este HWID ya tiene una cuenta activa.

Si necesitas ayuda, contacta al soporte:
${config.links.support}`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    if (!(await canCreateTest(from, hwid))) {
                        await client.sendText(from, `❌ *YA USaste tu prueba hoy*

Vuelve mañana para otra prueba gratuita.

O puedes comprar una configuración premium:`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    await client.sendText(from, '⏳ Generando configuración de prueba...');
                    
                    try {
                        const username = generateUsername();
                        const result = await createHTTPCustomUser(from, username, 0, hwid);
                        
                        if (result.success) {
                            registerTest(from, hwid);
                            
                            const message = `✅ *PRUEBA CREADA CON ÉXITO*

📱 *Tus datos:*
👤 Usuario: ${username}
🔑 Contraseña: ${DEFAULT_PASSWORD}
⏰ Expira: ${moment().add(1, 'hour').format('DD/MM/YYYY HH:mm')}
🔌 Límite: 1 dispositivo

📁 *ARCHIVO DE CONFIGURACIÓN:*
${result.hcFile}

🔍 *HWID:* ${hwid}

📲 *INSTRUCCIONES:*
1. Abre HTTP Custom
2. Importa el archivo .hc
3. Ingresa usuario y contraseña
4. Conecta y disfruta

⚠️ *GUARDA ESTOS DATOS*`;
                            
                            await client.sendText(from, message);
                            console.log(chalk.green(`✅ Test creado: ${username} - HWID: ${hwid}`));
                        } else {
                            await client.sendText(from, `❌ Error: ${result.error}`);
                        }
                    } catch (error) {
                        await client.sendText(from, `❌ Error al crear prueba: ${error.message}`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
                // OPCIÓN 2: COMPRAR
                else if (text === '2' && userState.state === 'main_menu') {
                    await setUserState(from, 'buying_plan');
                    
                    await client.sendText(from, `💰 *PLANES DISPONIBLES*

📅 *PLANES:*
1️⃣ 7 días - $${config.prices.price_7d}
2️⃣ 15 días - $${config.prices.price_15d}
3️⃣ 30 días - $${config.prices.price_30d}
4️⃣ 50 días - $${config.prices.price_50d}

0️⃣ Volver al menú

Responde con el número del plan:`);
                }
                
                // SELECCIONAR PLAN
                else if (userState.state === 'buying_plan' && ['1', '2', '3', '4'].includes(text)) {
                    const planMap = {
                        '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                        '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' },
                        '3': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                        '4': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                    };
                    
                    const plan = planMap[text];
                    
                    await setUserState(from, 'awaiting_payment_hwid', { plan });
                    await client.sendText(from, `📲 *PLAN SELECCIONADO:* ${plan.name}

Ahora envía tu HWID de HTTP Custom para continuar con el pago.

🔍 *Tu HWID:*
- 32 caracteres hexadecimales
- Lo encuentras en Configuración de HTTP Custom

📝 *Ejemplo:* a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`);
                }
                
                else if (text === '0' && userState.state === 'buying_plan') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, `🚀 *HTTP CUSTOM BOT*

Elija una opción:

🧪 1 - PRUEBA GRATIS
💰 2 - COMPRAR CONFIGURACIÓN
🔄 3 - RENOVAR / VERIFICAR
📱 4 - DESCARGAR HTTP CUSTOM
❓ 5 - CÓMO OBTENER HWID`);
                }
                
                // RECIBIR HWID PARA COMPRA
                else if (userState.state === 'awaiting_payment_hwid') {
                    const hwid = message.body.trim();
                    const planData = userState.data?.plan;
                    
                    if (!planData) {
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ *HWID INVÁLIDO*

El HWID debe tener 32 caracteres hexadecimales.

Intenta nuevamente:`);
                        return;
                    }
                    
                    if (await checkExistingHWID(hwid)) {
                        await client.sendText(from, `❌ *HWID YA REGISTRADO*

Este HWID ya tiene una cuenta activa.

Si necesitas renovar, contacta al soporte:
${config.links.support}`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    if (mpEnabled) {
                        await client.sendText(from, '⏳ Generando link de pago...');
                        
                        const payment = await createMercadoPagoPayment(
                            from, 
                            planData.days, 
                            planData.price, 
                            planData.name
                        );
                        
                        if (payment.success) {
                            // Guardar HWID temporalmente
                            await setUserState(from, 'payment_created', { 
                                payment_id: payment.paymentId,
                                days: planData.days,
                                hwid: hwid,
                                plan: planData.name
                            });
                            
                            const message = `💳 *PAGO CON MERCADOPAGO*

🌐 Plan: ${planData.name}
💰 Monto: $${planData.price} ARS
📱 HWID: ${hwid}

🔗 *LINK DE PAGO:*
${payment.paymentUrl}

⏰ Este enlace expira en 24 horas

✅ Una vez que pagues, te enviaremos tu archivo de configuración automáticamente.`;
                            
                            await client.sendText(from, message);
                            
                            // Enviar QR
                            if (fs.existsSync(payment.qrPath)) {
                                try {
                                    await client.sendImage(from, payment.qrPath, 'qr-pago.jpg', 
                                        `Escanea con MercadoPago\n\n${planData.name} - $${planData.price}`);
                                } catch (qrError) {}
                            }
                            
                        } else {
                            await client.sendText(from, `❌ *ERROR AL GENERAR PAGO*

${payment.error}

Contacta al soporte: ${config.links.support}`);
                            await setUserState(from, 'main_menu');
                        }
                    } else {
                        // Sin MercadoPago
                        await client.sendText(from, `💰 *PLAN SELECCIONADO:* ${planData.name}

📱 *HWID:* ${hwid}

Para continuar, contacta al administrador:
${config.links.support}

O realiza la transferencia bancaria y envía el comprobante.`);
                        
                        await setUserState(from, 'main_menu');
                    }
                }
                
                // RECIBIR HWID PARA ACTIVACIÓN POST-PAGO
                else if (userState.state === 'awaiting_hwid') {
                    const hwid = message.body.trim();
                    const paymentData = userState.data;
                    
                    if (!paymentData) {
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ *HWID INVÁLIDO*

El HWID debe tener 32 caracteres hexadecimales.

Intenta nuevamente:`);
                        return;
                    }
                    
                    if (await checkExistingHWID(hwid)) {
                        await client.sendText(from, `❌ *HWID YA REGISTRADO*

Este HWID ya tiene una cuenta activa.

Si necesitas renovar, contacta al soporte:
${config.links.support}`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    await client.sendText(from, '⏳ Generando tu configuración...');
                    
                    try {
                        const username = generatePremiumUsername();
                        const result = await createHTTPCustomUser(from, username, paymentData.days, hwid);
                        
                        if (result.success) {
                            // Actualizar pago con HWID
                            db.run(`UPDATE payments SET hwid = ?, hc_file_generated = ? WHERE payment_id = ?`, 
                                [hwid, result.hcFile, paymentData.payment_id]);
                            
                            const message = `✅ *CONFIGURACIÓN GENERADA*

📱 *Tus datos:*
👤 Usuario: ${username}
🔑 Contraseña: ${DEFAULT_PASSWORD}
⏰ Expira: ${moment().add(paymentData.days, 'days').format('DD/MM/YYYY')}
🔌 Límite: 1 dispositivo

📁 *ARCHIVO DE CONFIGURACIÓN:*
${result.hcFile}

🔍 *HWID:* ${hwid}

📲 *INSTRUCCIONES:*
1. Abre HTTP Custom
2. Importa el archivo .hc
3. Ingresa usuario y contraseña
4. Conecta y disfruta

🎊 ¡Gracias por tu compra!`;
                            
                            await client.sendText(from, message);
                            console.log(chalk.green(`✅ Usuario premium creado: ${username} - HWID: ${hwid}`));
                        } else {
                            await client.sendText(from, `❌ Error: ${result.error}`);
                        }
                    } catch (error) {
                        await client.sendText(from, `❌ Error al generar: ${error.message}`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
                // OPCIÓN 3: RENOVAR/VERIFICAR
                else if (text === '3' && userState.state === 'main_menu') {
                    await setUserState(from, 'awaiting_check_hwid');
                    await client.sendText(from, `🔍 *VERIFICAR/RENOVAR CUENTA*

Envía tu HWID para verificar el estado de tu cuenta o renovarla.

📝 *Ejemplo:* a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`);
                }
                
                // VERIFICAR HWID
                else if (userState.state === 'awaiting_check_hwid') {
                    const hwid = message.body.trim();
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ *HWID INVÁLIDO*

El HWID debe tener 32 caracteres hexadecimales.

Intenta nuevamente:`);
                        return;
                    }
                    
                    const user = await getUserByHWID(hwid);
                    
                    if (user) {
                        const expireDate = moment(user.expires_at).format('DD/MM/YYYY HH:mm');
                        const daysLeft = moment(user.expires_at).diff(moment(), 'days');
                        
                        await client.sendText(from, `✅ *CUENTA ACTIVA*

📱 *Información:*
👤 Usuario: ${user.username}
⏰ Expira: ${expireDate}
📅 Días restantes: ${daysLeft}

📁 *Configuración:*
http://${config.bot.server_ip}/hc_files/${user.hc_file}

¿Necesitas renovar? Contacta al soporte:
${config.links.support}`);
                    } else {
                        await client.sendText(from, `❌ *NO SE ENCONTRÓ CUENTA ACTIVA*

Este HWID no tiene una cuenta activa o ya expiró.

Para comprar una nueva configuración, elige la opción 2 del menú.`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
                // OPCIÓN 4: DESCARGAR APP
                else if (text === '4' && userState.state === 'main_menu') {
                    await client.sendText(from, `📱 *DESCARGAR HTTP CUSTOM*

🔗 *Enlace oficial:*
${config.links.app_download}

📲 *Instrucciones:*
1. Abre el enlace
2. Descarga la APK
3. Instala la aplicación
4. Abre HTTP Custom
5. Ve a Configuración para ver tu HWID

💡 *¿Necesitas ayuda?*
${config.links.support}`);
                }
                
            } catch (error) {
                console.error(chalk.red('❌ Error procesando mensaje:'), error.message);
            }
        });
        
        // ✅ VERIFICAR PAGOS CADA 2 MINUTOS
        cron.schedule('*/2 * * * *', () => {
            console.log(chalk.yellow('🔄 Verificando pagos pendientes...'));
            checkPendingPayments();
        });
        
        // ✅ LIMPIAR ESTADOS ANTIGUOS
        cron.schedule('0 * * * *', () => {
            db.run(`DELETE FROM user_state WHERE updated_at < datetime('now', '-1 hour')`);
        });
        
    } catch (error) {
        console.error(chalk.red('❌ Error inicializando WPPConnect:'), error.message);
        console.log(chalk.yellow('🔄 Reintentando en 10 segundos...'));
        setTimeout(initializeBot, 10000);
    }
}

// Iniciar el bot
initializeBot();

// Manejar cierre
process.on('SIGINT', async () => {
    console.log(chalk.yellow('\n🛑 Cerrando bot...'));
    if (client) {
        await client.close();
    }
    process.exit();
});
BOTEOF

echo -e "${GREEN}✅ Bot creado con soporte HWID${NC}"

# ================================================
# CREAR PANEL DE CONTROL CON SUBIDA DE ARCHIVOS HC
# ================================================
echo -e "\n${CYAN}🎛️  Creando panel de control con gestión de archivos HC...${NC}"

cat > /usr/local/bin/sshbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; NC='\033[0m'

DB="/opt/sshbot-pro/data/users.db"
CONFIG="/opt/sshbot-pro/config/config.json"
HC_DIR="/var/www/html/hc_files"
HC_SOURCE_DIR="/opt/sshbot-pro/hc_files"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }
set_val() { local t=$(mktemp); jq "$1 = $2" "$CONFIG" > "$t" && mv "$t" "$CONFIG"; }

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          🎛️  PANEL SSH BOT PRO - HTTP CUSTOM + HWID        ║${NC}"
    echo -e "${CYAN}║                  💰 MERCADOPAGO + ARCHIVOS HC               ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

test_mercadopago() {
    local TOKEN="$1"
    echo -e "${YELLOW}🔄 Probando conexión con MercadoPago...${NC}"
    
    RESPONSE=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $TOKEN" \
        "https://api.mercadopago.com/v1/payment_methods" \
        2>/dev/null)
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)
    
    if [[ "$HTTP_CODE" == "200" ]]; then
        echo -e "${GREEN}✅ CONEXIÓN EXITOSA${NC}"
        return 0
    else
        echo -e "${RED}❌ ERROR - Código: $HTTP_CODE${NC}"
        return 1
    fi
}

upload_hc_file() {
    clear
    echo -e "${CYAN}📁 SUBIR ARCHIVO HC${NC}\n"
    
    echo -e "${YELLOW}Formatos aceptados: .hc, .txt, .cfg${NC}"
    echo -e "${YELLOW}Tamaño máximo: 1MB${NC}\n"
    
    read -p "Ruta del archivo a subir: " FILE_PATH
    
    if [[ ! -f "$FILE_PATH" ]]; then
        echo -e "${RED}❌ Archivo no encontrado${NC}"
        return
    fi
    
    FILENAME=$(basename "$FILE_PATH")
    EXT="${FILENAME##*.}"
    
    if [[ ! "$EXT" =~ ^(hc|txt|cfg)$ ]]; then
        echo -e "${RED}❌ Extensión no válida${NC}"
        return
    fi
    
    SIZE=$(stat -c%s "$FILE_PATH")
    if [[ $SIZE -gt 1048576 ]]; then
        echo -e "${RED}❌ Archivo demasiado grande${NC}"
        return
    fi
    
    # Copiar a ambos directorios
    cp "$FILE_PATH" "$HC_SOURCE_DIR/$FILENAME"
    cp "$FILE_PATH" "$HC_DIR/$FILENAME"
    
    read -p "Descripción del archivo: " DESC
    
    sqlite3 "$DB" "INSERT INTO hc_files (filename, original_name, description, size) VALUES ('$FILENAME', '$FILENAME', '$DESC', $SIZE)"
    
    echo -e "\n${GREEN}✅ Archivo subido exitosamente${NC}"
    echo -e "${CYAN}URL: http://$(get_val '.bot.server_ip')/hc_files/$FILENAME${NC}"
}

list_hc_files() {
    clear
    echo -e "${CYAN}📁 ARCHIVOS HC DISPONIBLES${NC}\n"
    
    sqlite3 -column -header "$DB" "SELECT id, filename, description, downloads, active FROM hc_files ORDER BY uploaded_at DESC LIMIT 20"
    
    echo -e "\n${YELLOW}Archivos en directorio:${NC}"
    ls -lh "$HC_DIR" | grep -E '\.(hc|txt|cfg)'
}

delete_hc_file() {
    clear
    echo -e "${CYAN}🗑️ ELIMINAR ARCHIVO HC${NC}\n"
    
    read -p "ID del archivo a eliminar: " FILE_ID
    
    FILENAME=$(sqlite3 "$DB" "SELECT filename FROM hc_files WHERE id = $FILE_ID")
    
    if [[ -z "$FILENAME" ]]; then
        echo -e "${RED}❌ Archivo no encontrado${NC}"
        return
    fi
    
    rm -f "$HC_SOURCE_DIR/$FILENAME" "$HC_DIR/$FILENAME"
    sqlite3 "$DB" "DELETE FROM hc_files WHERE id = $FILE_ID"
    
    echo -e "${GREEN}✅ Archivo eliminado${NC}"
}

while true; do
    show_header
    
    TOTAL_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1" 2>/dev/null || echo "0")
    PENDING_PAYMENTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='pending'" 2>/dev/null || echo "0")
    APPROVED_PAYMENTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='approved'" 2>/dev/null || echo "0")
    HC_FILES=$(sqlite3 "$DB" "SELECT COUNT(*) FROM hc_files" 2>/dev/null || echo "0")
    
    STATUS=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.name=="sshbot-pro") | .pm2_env.status' 2>/dev/null || echo "stopped")
    if [[ "$STATUS" == "online" ]]; then
        BOT_STATUS="${GREEN}● ACTIVO${NC}"
    else
        BOT_STATUS="${RED}● DETENIDO${NC}"
    fi
    
    MP_TOKEN=$(get_val '.mercadopago.access_token')
    if [[ -n "$MP_TOKEN" && "$MP_TOKEN" != "" && "$MP_TOKEN" != "null" ]]; then
        MP_STATUS="${GREEN}✅ CONFIGURADO${NC}"
    else
        MP_STATUS="${RED}❌ NO CONFIGURADO${NC}"
    fi
    
    echo -e "${YELLOW}📊 ESTADO DEL SISTEMA${NC}"
    echo -e "  Bot: $BOT_STATUS"
    echo -e "  Usuarios: ${CYAN}$ACTIVE_USERS/$TOTAL_USERS${NC} activos/total"
    echo -e "  Pagos: ${CYAN}$PENDING_PAYMENTS${NC} pendientes | ${GREEN}$APPROVED_PAYMENTS${NC} aprobados"
    echo -e "  Archivos HC: ${PURPLE}$HC_FILES${NC}"
    echo -e "  MercadoPago: $MP_STATUS"
    echo -e "  IP: $(get_val '.bot.server_ip')"
    echo -e "  URL archivos: ${CYAN}http://$(get_val '.bot.server_ip')/hc_files/${NC}"
    echo -e ""
    
    echo -e "${YELLOW}💰 PRECIOS ACTUALES:${NC}"
    echo -e "  7 días: $ $(get_val '.prices.price_7d') ARS"
    echo -e "  15 días: $ $(get_val '.prices.price_15d') ARS"
    echo -e "  30 días: $ $(get_val '.prices.price_30d') ARS"
    echo -e "  50 días: $ $(get_val '.prices.price_50d') ARS"
    echo -e ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC} 🚀  Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC} 🛑  Detener bot"
    echo -e "${CYAN}[3]${NC} 📱  Ver logs y QR"
    echo -e "${CYAN}[4]${NC} 👤  Crear usuario manual con HWID"
    echo -e "${CYAN}[5]${NC} 👥  Listar usuarios activos"
    echo -e "${CYAN}[6]${NC} 💰  Cambiar precios"
    echo -e "${CYAN}[7]${NC} 🔑  Configurar MercadoPago"
    echo -e "${CYAN}[8]${NC} 🧪  Test MercadoPago"
    echo -e "${CYAN}[9]${NC} 📊  Ver estadísticas"
    echo -e "${CYAN}[10]${NC} 📁  Subir archivo HC"
    echo -e "${CYAN}[11]${NC} 📋  Listar archivos HC"
    echo -e "${CYAN}[12]${NC} 🗑️  Eliminar archivo HC"
    echo -e "${CYAN}[13]${NC} 💳  Ver pagos"
    echo -e "${CYAN}[14]${NC} 🔍  Buscar por HWID"
    echo -e "${CYAN}[15]${NC} 🔄  Limpiar sesión WhatsApp"
    echo -e "${CYAN}[0]${NC} 🚪  Salir"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e ""
    
    read -p "👉 Selecciona: " OPTION
    
    case $OPTION in
        1)
            echo -e "\n${YELLOW}🔄 Reiniciando...${NC}"
            cd /root/sshbot-pro
            pm2 restart sshbot-pro 2>/dev/null || pm2 start bot.js --name sshbot-pro
            pm2 save
            echo -e "${GREEN}✅ Bot reiniciado${NC}"
            sleep 2
            ;;
        2)
            echo -e "\n${YELLOW}🛑 Deteniendo...${NC}"
            pm2 stop sshbot-pro
            echo -e "${GREEN}✅ Bot detenido${NC}"
            sleep 2
            ;;
        3)
            echo -e "\n${YELLOW}📱 Mostrando logs...${NC}"
            pm2 logs sshbot-pro --lines 100
            ;;
        4)
            clear
            echo -e "${CYAN}👤 CREAR USUARIO CON HWID${NC}\n"
            
            read -p "Teléfono: " PHONE
            read -p "Usuario (auto=generar): " USERNAME
            read -p "Tipo (test/premium): " TIPO
            read -p "Días (0=test 1h, 7,15,30,50=premium): " DAYS
            read -p "HWID (32 caracteres hex): " HWID
            
            [[ -z "$DAYS" ]] && DAYS="30"
            
            if [[ "$USERNAME" == "auto" || -z "$USERNAME" ]]; then
                if [[ "$TIPO" == "test" ]]; then
                    USERNAME="test$(shuf -i 1000-9999 -n 1)"
                else
                    USERNAME="user$(shuf -i 1000-9999 -n 1)"
                fi
            fi
            
            USERNAME=$(echo "$USERNAME" | tr '[:upper:]' '[:lower:]')
            PASSWORD="mgvpn247"
            
            if [[ "$TIPO" == "test" ]]; then
                DAYS="0"
                EXPIRE_DATE=$(date -d "+1 hour" +"%Y-%m-%d %H:%M:%S")
                # No crear usuario del sistema para test
            else
                EXPIRE_DATE=$(date -d "+$DAYS days" +"%Y-%m-%d 23:59:59")
                useradd -M -s /bin/false -e "$(date -d "+$DAYS days" +%Y-%m-%d)" "$USERNAME" && echo "$USERNAME:$PASSWORD" | chpasswd
            fi
            
            if [[ $? -eq 0 ]] || [[ "$TIPO" == "test" ]]; then
                # Generar archivo HC
                HC_FILENAME="config_${USERNAME}_${HWID:0:8}.hc"
                HC_PATH="/var/www/html/hc_files/$HC_FILENAME"
                
                cat > "$HC_PATH" << HCEOF
# HTTP Custom Config
# Generado para: $USERNAME
# HWID: $HWID
# Expira: $(date -d "+$DAYS days" +"%d/%m/%Y")

[config]
name=SSH-PRO-$USERNAME
server=$(get_val '.bot.server_ip')
port=22,80,443
type=ssh
payload=GET / HTTP/1.1[crlf]Host: [host][crlf]Connection: Keep-Alive[crlf]User-Agent: [ua][crlf][crlf]
ssh_method=1
dns=8.8.8.8
timeout=30
hwid=$HWID
expires=$(date -d "+$DAYS days" +%s)
username=$USERNAME
password=$PASSWORD
HCEOF
                
                cp "$HC_PATH" "/opt/sshbot-pro/hc_files/$HC_FILENAME"
                
                sqlite3 "$DB" "INSERT INTO users (phone, username, password, tipo, hwid, hc_file, expires_at, status) VALUES ('$PHONE', '$USERNAME', '$PASSWORD', '$TIPO', '$HWID', '$HC_FILENAME', '$EXPIRE_DATE', 1)"
                
                echo -e "\n${GREEN}✅ USUARIO CREADO${NC}"
                echo -e "📱 Teléfono: ${PHONE}"
                echo -e "👤 Usuario: ${USERNAME}"
                echo -e "🔑 Contraseña: ${PASSWORD}"
                echo -e "🔍 HWID: ${HWID}"
                echo -e "⏰ Expira: ${EXPIRE_DATE}"
                echo -e "📁 Config: http://$(get_val '.bot.server_ip')/hc_files/$HC_FILENAME"
            else
                echo -e "\n${RED}❌ Error${NC}"
            fi
            read -p "Presiona Enter..."
            ;;
        5)
            clear
            echo -e "${CYAN}👥 USUARIOS ACTIVOS${NC}\n"
            
            sqlite3 -column -header "$DB" "SELECT username, hwid, tipo, expires_at FROM users WHERE status = 1 ORDER BY expires_at DESC LIMIT 20"
            echo -e "\n${YELLOW}Total: ${ACTIVE_USERS} activos${NC}"
            read -p "Presiona Enter..."
            ;;
        6)
            clear
            echo -e "${CYAN}💰 CAMBIAR PRECIOS${NC}\n"
            
            CURRENT_7D=$(get_val '.prices.price_7d')
            CURRENT_15D=$(get_val '.prices.price_15d')
            CURRENT_30D=$(get_val '.prices.price_30d')
            CURRENT_50D=$(get_val '.prices.price_50d')
            
            echo -e "${YELLOW}Precios actuales:${NC}"
            echo -e "  7 días: $${CURRENT_7D} ARS"
            echo -e "  15 días: $${CURRENT_15D} ARS"
            echo -e "  30 días: $${CURRENT_30D} ARS"
            echo -e "  50 días: $${CURRENT_50D} ARS\n"
            
            read -p "Nuevo precio 7d [${CURRENT_7D}]: " NEW_7D
            read -p "Nuevo precio 15d [${CURRENT_15D}]: " NEW_15D
            read -p "Nuevo precio 30d [${CURRENT_30D}]: " NEW_30D
            read -p "Nuevo precio 50d [${CURRENT_50D}]: " NEW_50D
            
            [[ -n "$NEW_7D" ]] && set_val '.prices.price_7d' "$NEW_7D"
            [[ -n "$NEW_15D" ]] && set_val '.prices.price_15d' "$NEW_15D"
            [[ -n "$NEW_30D" ]] && set_val '.prices.price_30d' "$NEW_30D"
            [[ -n "$NEW_50D" ]] && set_val '.prices.price_50d' "$NEW_50D"
            
            echo -e "\n${GREEN}✅ Precios actualizados${NC}"
            read -p "Presiona Enter..."
            ;;
        7)
            clear
            echo -e "${CYAN}🔑 CONFIGURAR MERCADOPAGO${NC}\n"
            
            CURRENT_TOKEN=$(get_val '.mercadopago.access_token')
            
            if [[ -n "$CURRENT_TOKEN" && "$CURRENT_TOKEN" != "null" && "$CURRENT_TOKEN" != "" ]]; then
                echo -e "${GREEN}✅ Token configurado${NC}"
            else
                echo -e "${YELLOW}⚠️  Sin token configurado${NC}\n"
            fi
            
            read -p "¿Configurar nuevo token? (s/N): " CONF
            if [[ "$CONF" == "s" ]]; then
                echo ""
                read -p "Pega el Access Token: " NEW_TOKEN
                
                if [[ "$NEW_TOKEN" =~ ^APP_USR- ]] || [[ "$NEW_TOKEN" =~ ^TEST- ]]; then
                    set_val '.mercadopago.access_token' "\"$NEW_TOKEN\""
                    set_val '.mercadopago.enabled' "true"
                    echo -e "\n${GREEN}✅ Token configurado${NC}"
                    echo -e "${YELLOW}🔄 Reiniciando bot...${NC}"
                    cd /root/sshbot-pro && pm2 restart sshbot-pro
                    sleep 2
                else
                    echo -e "${RED}❌ Token inválido${NC}"
                fi
            fi
            read -p "Presiona Enter..."
            ;;
        8)
            clear
            echo -e "${CYAN}🧪 TEST MERCADOPAGO${NC}\n"
            
            TOKEN=$(get_val '.mercadopago.access_token')
            if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
                echo -e "${RED}❌ Token no configurado${NC}\n"
                read -p "Presiona Enter..."
                continue
            fi
            
            test_mercadopago "$TOKEN"
            read -p "\nPresiona Enter..."
            ;;
        9)
            clear
            echo -e "${CYAN}📊 ESTADÍSTICAS${NC}\n"
            
            echo -e "${YELLOW}👥 USUARIOS:${NC}"
            sqlite3 "$DB" "SELECT 'Total: ' || COUNT(*) || ' | Activos: ' || SUM(CASE WHEN status=1 THEN 1 ELSE 0 END) FROM users"
            
            echo -e "\n${YELLOW}💰 PAGOS:${NC}"
            sqlite3 "$DB" "SELECT 'Pendientes: ' || SUM(CASE WHEN status='pending' THEN 1 ELSE 0 END) || ' | Aprobados: ' || SUM(CASE WHEN status='approved' THEN 1 ELSE 0 END) || ' | Total: $' || printf('%.2f', SUM(CASE WHEN status='approved' THEN amount ELSE 0 END)) FROM payments"
            
            echo -e "\n${YELLOW}🔍 HWID:${NC}"
            sqlite3 "$DB" "SELECT 'Con HWID: ' || COUNT(*) FROM users WHERE hwid IS NOT NULL"
            
            echo -e "\n${YELLOW}📁 ARCHIVOS HC:${NC}"
            sqlite3 "$DB" "SELECT 'Total: ' || COUNT(*) FROM hc_files"
            
            read -p "\nPresiona Enter..."
            ;;
        10)
            upload_hc_file
            read -p "\nPresiona Enter..."
            ;;
        11)
            list_hc_files
            read -p "\nPresiona Enter..."
            ;;
        12)
            delete_hc_file
            read -p "\nPresiona Enter..."
            ;;
        13)
            clear
            echo -e "${CYAN}💳 PAGOS${NC}\n"
            
            echo -e "${YELLOW}Pagos pendientes:${NC}"
            sqlite3 -column -header "$DB" "SELECT payment_id, phone, plan, amount, created_at FROM payments WHERE status='pending' ORDER BY created_at DESC LIMIT 10"
            
            echo -e "\n${YELLOW}Pagos aprobados:${NC}"
            sqlite3 -column -header "$DB" "SELECT payment_id, phone, plan, amount, hwid, approved_at FROM payments WHERE status='approved' ORDER BY approved_at DESC LIMIT 10"
            
            read -p "\nPresiona Enter..."
            ;;
        14)
            clear
            echo -e "${CYAN}🔍 BUSCAR POR HWID${NC}\n"
            
            read -p "Ingresa HWID: " SEARCH_HWID
            
            sqlite3 -column -header "$DB" "SELECT username, phone, tipo, expires_at, hc_file FROM users WHERE hwid = '$SEARCH_HWID'"
            
            read -p "\nPresiona Enter..."
            ;;
        15)
            echo -e "\n${YELLOW}🧹 Limpiando sesión WhatsApp...${NC}"
            pm2 stop sshbot-pro
            rm -rf /root/.wppconnect/*
            echo -e "${GREEN}✅ Sesión limpiada${NC}"
            echo -e "${YELLOW}📱 Escanea nuevo QR al reiniciar${NC}"
            sleep 2
            ;;
        0)
            echo -e "\n${GREEN}👋 Hasta pronto${NC}\n"
            exit 0
            ;;
        *)
            echo -e "\n${RED}❌ Opción inválida${NC}"
            sleep 1
            ;;
    esac
done
PANELEOF

chmod +x /usr/local/bin/sshbot
echo -e "${GREEN}✅ Panel creado con gestión de archivos HC${NC}"

# ================================================
# CREAR ARCHIVO HC DE EJEMPLO
# ================================================
echo -e "\n${CYAN}📁 Creando archivo HC de ejemplo...${NC}"

cat > "/var/www/html/hc_files/ejemplo_config.hc" << 'EXAMPLE'
# HTTP Custom Config - EJEMPLO
# Este es un archivo de ejemplo

[config]
name=SSH-PRO-EJEMPLO
server=SERVER_IP
port=22,80,443
type=ssh
payload=GET / HTTP/1.1[crlf]Host: [host][crlf]Connection: Keep-Alive[crlf]User-Agent: [ua][crlf][crlf]
ssh_method=1
dns=8.8.8.8
timeout=30
hwid=TU_HWID_AQUI
expires=0
username=ejemplo
password=mgvpn247
EXAMPLE

sed -i "s/SERVER_IP/$SERVER_IP/g" "/var/www/html/hc_files/ejemplo_config.hc"
cp "/var/www/html/hc_files/ejemplo_config.hc" "/opt/sshbot-pro/hc_files/"

sqlite3 "$DB" "INSERT INTO hc_files (filename, original_name, description, size) VALUES ('ejemplo_config.hc', 'ejemplo_config.hc', 'Archivo de ejemplo', $(stat -c%s /var/www/html/hc_files/ejemplo_config.hc))"

# ================================================
# INICIAR BOT
# ================================================
echo -e "\n${CYAN}🚀 Iniciando bot...${NC}"

cd "$USER_HOME"
pm2 start bot.js --name sshbot-pro
pm2 save
pm2 startup systemd -u root --hp /root > /dev/null 2>&1

sleep 3

# ================================================
# MENSAJE FINAL
# ================================================
clear
echo -e "${GREEN}${BOLD}"
cat << "FINAL"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          🎉 INSTALACIÓN COMPLETADA - HTTP CUSTOM 🎉         ║
║                                                              ║
║       🤖 SSH BOT PRO - WPPCONNECT + MERCADOPAGO            ║
║       📱 WhatsApp API con HWID y Archivos HC               ║
║       💰 MercadoPago SDK v2.x COMPLETO                      ║
║       📁 Sistema de archivos HTTP Custom                    ║
║       🔍 Verificación por HWID                              ║
║       🎛️  Panel completo con gestión de archivos            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Sistema HTTP Custom instalado${NC}"
echo -e "${GREEN}✅ WhatsApp API funcionando con HWID${NC}"
echo -e "${GREEN}✅ MercadoPago SDK v2.x integrado${NC}"
echo -e "${GREEN}✅ Servidor de archivos HC en: http://$SERVER_IP/hc_files/${NC}"
echo -e "${GREEN}✅ Panel de control con gestión de archivos${NC}"
echo -e "${GREEN}✅ Verificación automática de pagos${NC}"
echo -e "${GREEN}✅ Planes: 7, 15, 30, 50 días${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 COMANDOS PRINCIPALES:${NC}\n"
echo -e "  ${GREEN}sshbot${NC}         - Panel de control completo"
echo -e "  ${GREEN}pm2 logs sshbot-pro${NC} - Ver logs y QR"
echo -e "  ${GREEN}pm2 restart sshbot-pro${NC} - Reiniciar bot"
echo -e "  ${GREEN}http://$SERVER_IP/hc_files/${NC} - Archivos HC"
echo -e "\n"

echo -e "${YELLOW}🚀 PRIMEROS PASOS:${NC}\n"
echo -e "  1. Ver logs: ${GREEN}pm2 logs sshbot-pro${NC}"
echo -e "  2. Escanear QR cuando aparezca"
echo -e "  3. Configurar MercadoPago en el panel: ${GREEN}sshbot${NC} (opción 7)"
echo -e "  4. Subir archivos HC: ${GREEN}sshbot${NC} (opción 10)"
echo -e "  5. Enviar 'menu' al bot en WhatsApp"
echo -e "\n"

echo -e "${YELLOW}📱 FLUJO DE TRABAJO:${NC}\n"
echo -e "  1. Usuario envía HWID"
echo -e "  2. Bot verifica/genera configuración"
echo -e "  3. Usuario recibe archivo .hc"
echo -e "  4. Usuario importa en HTTP Custom"
echo -e "  5. Conexión establecida"
echo -e "\n"

echo -e "${GREEN}${BOLD}¡Sistema listo! Escanea el QR y empieza a vender configuraciones HTTP Custom 🚀${NC}\n"

# Ver logs automáticamente
read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}Mostrando logs...${NC}"
    echo -e "${YELLOW}📱 Espera que aparezca el QR para escanear...${NC}\n"
    sleep 2
    pm2 logs sshbot-pro
else
    echo -e "\n${YELLOW}💡 Para iniciar: ${GREEN}sshbot${NC}"
    echo -e "${YELLOW}💡 Para logs: ${GREEN}pm2 logs sshbot-pro${NC}\n"
fi

exit 0