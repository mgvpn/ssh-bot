#!/bin/bash
# ================================================
# HTTP CUSTOM BOT PRO - WPPCONNECT + MERCADOPAGO
# VERSIÓN PARA HTTP CUSTOM CON HWID
# ================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${CYAN}${BOLD}"
cat << "BANNER"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   ██╗  ██╗████████╗████████╗██████╗     ██████╗ ██████╗ ████████╗
║   ██║  ██║╚══██╔══╝╚══██╔══╝██╔══██╗   ██╔════╝██╔═══██╗╚══██╔══╝
║   ███████║   ██║      ██║   ██████╔╝   ██║     ██║   ██║   ██║   
║   ██╔══██║   ██║      ██║   ██╔══██╗   ██║     ██║   ██║   ██║   
║   ██║  ██║   ██║      ██║   ██║  ██║   ╚██████╗╚██████╔╝   ██║   
║   ╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚═╝  ╚═╝    ╚═════╝ ╚═════╝    ╚═╝   
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║      🤖 HTTP CUSTOM BOT PRO - HWID + MERCADOPAGO            ║
║               📱 WhatsApp API FUNCIONANDO                   ║
║               💰 MercadoPago SDK v2.x INTEGRADO            ║
║               🔑 LOGIN POR HWID                             ║
║               📂 ENTREGA AUTOMÁTICA DE ARCHIVO .hc          ║
║               🔔 RECORDATORIOS AUTOMÁTICOS                  ║
║               🔄 RENOVACIÓN DE ACCESOS                      ║
║               ⏰ PRUEBA GRATIS AUTOMÁTICA                   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CARACTERÍSTICAS PRINCIPALES:${NC}"
echo -e "  🤖 ${CYAN}WPPConnect${NC} - API WhatsApp funcionando"
echo -e "  💰 ${GREEN}MercadoPago SDK v2.x${NC} - Integrado completo"
echo -e "  🔑 ${YELLOW}Login por HWID${NC} - Activación automática"
echo -e "  📂 ${CYAN}Entrega automática${NC} - Archivo .hc directo"
echo -e "  🔄 ${BLUE}Renovación${NC} - Desde el bot"
echo -e "  ✏️ ${PURPLE}Editar HWID${NC} - Lista numerada"
echo -e "  📋 ${CYAN}Ver usuarios activos${NC} - Con días restantes"
echo -e "  ⏰ ${BLUE}Prueba gratuita${NC} - Automática con aviso"
echo -e "  🔔 ${YELLOW}Recordatorios${NC} - 1 día antes de vencer"
echo -e "  🎛️  ${CYAN}Panel admin completo${NC}"
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

# Dependencias
apt-get install -y \
    git curl wget sqlite3 jq \
    build-essential libcairo2-dev \
    libpango1.0-dev libjpeg-dev \
    libgif-dev librsvg2-dev \
    python3 python3-pip ffmpeg \
    unzip cron ufw

# Firewall
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
# PREPARAR ESTRUCTURA
# ================================================
echo -e "\n${CYAN}📁 Creando estructura...${NC}"

INSTALL_DIR="/opt/hcbot-pro"
USER_HOME="/root/hcbot-pro"
DB_FILE="$INSTALL_DIR/data/users.db"
CONFIG_FILE="$INSTALL_DIR/config/config.json"
HC_FILES_DIR="$INSTALL_DIR/hc_files"

# Limpiar anterior
pm2 delete hcbot-pro 2>/dev/null || true
rm -rf "$INSTALL_DIR" "$USER_HOME" 2>/dev/null || true
rm -rf /root/.wppconnect 2>/dev/null || true

# Crear directorios
mkdir -p "$INSTALL_DIR"/{data,config,sessions,logs,qr_codes,hc_files}
mkdir -p "$USER_HOME"
mkdir -p /root/.wppconnect
chmod -R 755 "$INSTALL_DIR"
chmod -R 700 /root/.wppconnect

# Crear archivo .hc de ejemplo
cat > "$HC_FILES_DIR/mgvpn.hc" << 'HCEOF'
# HTTP Custom Config
# MGVPN Premium
# Generado automáticamente
HCEOF

# Configuración
cat > "$CONFIG_FILE" << EOF
{
    "bot": {
        "name": "HTTP Custom Bot Pro",
        "version": "3.0-HWID",
        "server_ip": "$SERVER_IP"
    },
    "prices": {
        "test_hours": 2,
        "price_7d": 3000.00,
        "price_15d": 4000.00,
        "price_30d": 7500.00,
        "price_50d": 10000.00,
        "currency": "ARS"
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false,
        "public_key": ""
    },
    "reminders": {
        "enabled": true,
        "days_before": [3, 1]
    },
    "hc_files": {
        "default": "mgvpn.hc",
        "available": ["mgvpn.hc"]
    },
    "links": {
        "app_download": "https://play.google.com/store/apps/details?id=com.evolutionoft.httpscustom",
        "how_to_get_hwid": "https://youtu.be/ejemplo",
        "support": "https://wa.me/543435071016"
    },
    "paths": {
        "database": "$DB_FILE",
        "qr_codes": "$INSTALL_DIR/qr_codes",
        "sessions": "/root/.wppconnect",
        "hc_files": "$HC_FILES_DIR"
    }
}
EOF

# Base de datos para HTTP Custom
sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    hwid TEXT UNIQUE,
    username TEXT,
    file_name TEXT DEFAULT 'mgvpn.hc',
    tipo TEXT DEFAULT 'test',
    expires_at DATETIME,
    status INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_reminder_sent INTEGER DEFAULT 0
);

CREATE TABLE pending_activations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    hwid TEXT,
    code TEXT UNIQUE,
    expires_at DATETIME,
    days INTEGER,
    used INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE daily_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hwid TEXT,
    phone TEXT,
    date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(hwid, date)
);

CREATE TABLE payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_id TEXT UNIQUE,
    phone TEXT,
    hwid TEXT,
    plan TEXT,
    days INTEGER,
    amount REAL,
    status TEXT DEFAULT 'pending',
    payment_url TEXT,
    qr_code TEXT,
    preference_id TEXT,
    is_renewal INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    approved_at DATETIME
);

CREATE TABLE user_state (
    phone TEXT PRIMARY KEY,
    state TEXT DEFAULT 'main_menu',
    data TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_hwid ON users(hwid);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_payments_status ON payments(status);
SQL

echo -e "${GREEN}✅ Estructura creada${NC}"

# ================================================
# CREAR BOT PARA HTTP CUSTOM
# ================================================
echo -e "\n${CYAN}🤖 Creando bot para HTTP Custom...${NC}"

cd "$USER_HOME"

cat > package.json << 'PKGEOF'
{
    "name": "hcbot-pro",
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
        "sharp": "^0.33.2"
    }
}
PKGEOF

echo -e "${YELLOW}📦 Instalando dependencias NPM...${NC}"
npm install --silent 2>&1 | grep -v "npm WARN" || true

# Crear bot.js
echo -e "${YELLOW}📝 Creando bot.js para HTTP Custom...${NC}"

cat > "bot.js" << 'BOTEOF'
const wppconnect = require('@wppconnect-team/wppconnect');
const qrcode = require('qrcode-terminal');
const QRCode = require('qrcode');
const moment = require('moment');
const sqlite3 = require('sqlite3').verbose();
const { exec } = require('child_process');
const chalk = require('chalk');
const cron = require('node-cron');
const fs = require('fs');
const path = require('path');
const axios = require('axios');

moment.locale('es');

console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════════════╗'));
console.log(chalk.cyan.bold('║      🤖 HTTP CUSTOM BOT PRO - HWID + MERCADOPAGO             ║'));
console.log(chalk.cyan.bold('║              🔑 LOGIN POR HWID - ENTREGA .hc                 ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

// Configuración
function loadConfig() {
    delete require.cache[require.resolve('/opt/hcbot-pro/config/config.json')];
    return require('/opt/hcbot-pro/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/hcbot-pro/data/users.db');

// MercadoPago
let mpEnabled = false;
let mpClient = null;
let mpPreference = null;

function initMercadoPago() {
    config = loadConfig();
    if (config.mercadopago.access_token && config.mercadopago.access_token !== '') {
        try {
            const { MercadoPagoConfig, Preference } = require('mercadopago');
            mpClient = new MercadoPagoConfig({ accessToken: config.mercadopago.access_token });
            mpPreference = new Preference(mpClient);
            mpEnabled = true;
            console.log(chalk.green('✅ MercadoPago SDK activado'));
        } catch (error) {
            console.log(chalk.red('❌ Error MP:'), error.message);
            mpEnabled = false;
        }
    }
    return mpEnabled;
}

initMercadoPago();

let client = null;

// ============ FUNCIONES HWID ============

function generateActivationCode() {
    return Math.random().toString(36).substring(2, 10).toUpperCase();
}

function formatExpiration(date) {
    return moment(date).format('DD/MM/YYYY HH:mm');
}

function getDaysRemaining(expiresAt) {
    const diff = moment(expiresAt).diff(moment(), 'days');
    return diff > 0 ? diff : 0;
}

// Verificar si HWID tiene acceso activo
function checkHWIDAccess(hwid) {
    return new Promise((resolve) => {
        db.get(`SELECT * FROM users WHERE hwid = ? AND status = 1 AND expires_at > datetime('now')`,
            [hwid], (err, row) => {
            resolve({ active: !!row, user: row });
        });
    });
}

// Crear activación pendiente (para después de pagar)
function createPendingActivation(phone, hwid, days) {
    return new Promise((resolve) => {
        const code = generateActivationCode();
        const expiresAt = moment().add(24, 'hours').format('YYYY-MM-DD HH:mm:ss');
        
        db.run(`INSERT INTO pending_activations (phone, hwid, code, expires_at, days) VALUES (?, ?, ?, ?, ?)`,
            [phone, hwid, code, expiresAt, days],
            function(err) {
                if (err) {
                    resolve({ success: false, error: err.message });
                } else {
                    resolve({ success: true, code, expiresAt });
                }
            });
    });
}

// Activar HWID por código
function activateByCode(phone, code) {
    return new Promise((resolve) => {
        db.get(`SELECT * FROM pending_activations WHERE code = ? AND used = 0 AND expires_at > datetime('now')`,
            [code], async (err, activation) => {
            if (err || !activation) {
                resolve({ success: false, error: 'Código inválido o expirado' });
                return;
            }
            
            const expiresAt = moment().add(activation.days, 'days').format('YYYY-MM-DD 23:59:59');
            
            db.run(`INSERT OR REPLACE INTO users (phone, hwid, tipo, expires_at, status, file_name)
                    VALUES (?, ?, 'premium', ?, 1, 'mgvpn.hc')`,
                [activation.phone, activation.hwid, expiresAt]);
            
            db.run(`UPDATE pending_activations SET used = 1 WHERE code = ?`, [code]);
            
            resolve({ success: true, hwid: activation.hwid, expiresAt });
        });
    });
}

// Crear prueba gratuita
function createTestAccess(phone, hwid) {
    return new Promise((resolve) => {
        const expiresAt = moment().add(config.prices.test_hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
        
        db.run(`INSERT OR REPLACE INTO users (phone, hwid, tipo, expires_at, status, file_name)
                VALUES (?, ?, 'test', ?, 1, 'mgvpn.hc')`,
            [phone, hwid, expiresAt],
            function(err) {
                if (err) {
                    resolve({ success: false, error: err.message });
                } else {
                    resolve({ success: true, hwid, expiresAt });
                }
            });
    });
}

// Verificar si puede obtener prueba
function canGetTest(hwid, phone) {
    return new Promise((resolve) => {
        const today = moment().format('YYYY-MM-DD');
        db.get(`SELECT COUNT(*) as count FROM daily_tests WHERE (hwid = ? OR phone = ?) AND date = ?`,
            [hwid, phone, today], (err, row) => {
            resolve(!err && row && row.count === 0);
        });
    });
}

function registerTest(hwid, phone) {
    db.run(`INSERT INTO daily_tests (hwid, phone, date) VALUES (?, ?, ?)`,
        [hwid, phone, moment().format('YYYY-MM-DD')]);
}

// Enviar archivo .hc
async function sendHCFile(to) {
    const hcPath = '/opt/hcbot-pro/hc_files/mgvpn.hc';
    
    if (!fs.existsSync(hcPath)) {
        console.log(chalk.yellow('⚠️ Archivo .hc no encontrado'));
        return false;
    }
    
    try {
        await client.sendFile(
            to,
            hcPath,
            'mgvpn.hc',
            '📱 *HTTP CUSTOM CONFIG*\n\nImporta este archivo en HTTP Custom\nConfiguración: Menú → Importar Config\n\n🔑 Tu acceso ya está activo'
        );
        return true;
    } catch (error) {
        console.error(chalk.red(`❌ Error: ${error.message}`));
        return false;
    }
}

// Ver usuarios activos del cliente
function getUserActiveAccess(phone) {
    return new Promise((resolve) => {
        db.all(`SELECT hwid, tipo, expires_at, file_name FROM users 
                WHERE phone = ? AND status = 1 AND expires_at > datetime('now')`,
            [phone], (err, rows) => {
            resolve(rows || []);
        });
    });
}

// Renovar acceso
function renewAccess(phone, hwid, days) {
    return new Promise((resolve) => {
        db.get(`SELECT expires_at FROM users WHERE phone = ? AND hwid = ? AND status = 1`,
            [phone, hwid], (err, user) => {
            if (err || !user) {
                resolve({ success: false, error: 'Acceso no encontrado' });
                return;
            }
            
            const currentExpiry = moment(user.expires_at);
            const newExpiry = currentExpiry.add(days, 'days');
            const newExpiryStr = newExpiry.format('YYYY-MM-DD HH:mm:ss');
            
            db.run(`UPDATE users SET expires_at = ?, tipo = 'premium' WHERE phone = ? AND hwid = ?`,
                [newExpiryStr, phone, hwid]);
            
            resolve({ success: true, hwid, newExpiry: newExpiryStr, daysAdded: days });
        });
    });
}

// ============ MERCADOPAGO ============

async function createPayment(phone, hwid, days, amount, planName, isRenewal = false) {
    if (!mpEnabled || !mpPreference) {
        return { success: false, error: 'MercadoPago no configurado' };
    }
    
    const paymentId = `${isRenewal ? 'RENEW' : 'HC'}-${Date.now()}`;
    
    try {
        const preferenceData = {
            items: [{
                title: isRenewal ? `RENOVACIÓN ${days} DÍAS` : `HTTP CUSTOM ${days} DÍAS`,
                quantity: 1,
                currency_id: 'ARS',
                unit_price: parseFloat(amount)
            }],
            external_reference: paymentId,
            expires: true,
            expiration_date_from: moment().toISOString(),
            expiration_date_to: moment().add(24, 'hours').toISOString(),
            back_urls: {
                success: `https://wa.me/${phone.replace('@c.us', '')}`,
                failure: `https://wa.me/${phone.replace('@c.us', '')}`
            }
        };
        
        const response = await mpPreference.create({ body: preferenceData });
        
        if (response && response.id) {
            db.run(`INSERT INTO payments (payment_id, phone, hwid, plan, days, amount, status, payment_url, preference_id, is_renewal)
                    VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
                [paymentId, phone, hwid, `${days}d`, days, amount, response.init_point, response.id, isRenewal ? 1 : 0]);
            
            return { success: true, paymentUrl: response.init_point, amount };
        }
        
        return { success: false, error: 'Error creando pago' };
    } catch (error) {
        return { success: false, error: error.message };
    }
}

// Verificar pagos pendientes
async function checkPendingPayments() {
    if (!mpEnabled) return;
    
    db.all(`SELECT * FROM payments WHERE status = 'pending'`, async (err, payments) => {
        if (err || !payments) return;
        
        for (const payment of payments) {
            try {
                const response = await axios.get(`https://api.mercadopago.com/v1/payments/search?external_reference=${payment.payment_id}`, {
                    headers: { 'Authorization': `Bearer ${config.mercadopago.access_token}` }
                });
                
                if (response.data && response.data.results && response.data.results[0]?.status === 'approved') {
                    console.log(chalk.green(`✅ Pago aprobado: ${payment.payment_id}`));
                    
                    if (payment.is_renewal) {
                        await renewAccess(payment.phone, payment.hwid, payment.days);
                    } else {
                        const expiresAt = moment().add(payment.days, 'days').format('YYYY-MM-DD HH:mm:ss');
                        db.run(`INSERT OR REPLACE INTO users (phone, hwid, tipo, expires_at, status)
                                VALUES (?, ?, 'premium', ?, 1)`,
                            [payment.phone, payment.hwid, expiresAt]);
                    }
                    
                    db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`,
                        [payment.payment_id]);
                    
                    await client.sendText(payment.phone, `✅ *PAGO CONFIRMADO*\n\nTu acceso ha sido activado por ${payment.days} días.\n\nEnvía "MENU" para más opciones.`);
                    await sendHCFile(payment.phone);
                }
            } catch (error) {
                console.error(chalk.red(`Error verificando: ${error.message}`));
            }
        }
    });
}

// ============ ESTADOS DEL BOT ============

function getUserState(phone) {
    return new Promise((resolve) => {
        db.get('SELECT state, data FROM user_state WHERE phone = ?', [phone], (err, row) => {
            if (!row) resolve({ state: 'main_menu', data: null });
            else resolve({ state: row.state, data: row.data ? JSON.parse(row.data) : null });
        });
    });
}

function setUserState(phone, state, data = null) {
    const dataStr = data ? JSON.stringify(data) : null;
    db.run(`INSERT OR REPLACE INTO user_state (phone, state, data, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)`,
        [phone, state, dataStr]);
}

// ============ INICIALIZAR BOT ============

async function initializeBot() {
    try {
        console.log(chalk.yellow('🚀 Iniciando WPPConnect...'));
        
        client = await wppconnect.create({
            session: 'hcbot-session',
            headless: true,
            useChrome: true,
            debug: false,
            logQR: true,
            browserArgs: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
            puppeteerOptions: {
                executablePath: '/usr/bin/google-chrome',
                headless: 'new',
                args: ['--no-sandbox']
            }
        });
        
        console.log(chalk.green('✅ Bot conectado!'));
        
        // Manejar mensajes
        client.onMessage(async (message) => {
            try {
                const text = message.body.toLowerCase().trim();
                const from = message.from;
                
                console.log(chalk.cyan(`📩 ${from}: ${text.substring(0, 50)}`));
                
                const userState = await getUserState(from);
                
                // ============ MENÚ PRINCIPAL ============
                if (['menu', 'hola', 'start', '0'].includes(text)) {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, `🌟 *HTTP CUSTOM BOT PRO* 🌟

┌─────────────────────────┐
│ 1️⃣ - 🧪 PRUEBA GRATIS   │
│ 2️⃣ - 💰 COMPRAR ACCESO  │
│ 3️⃣ - 🔄 RENOVAR ACCESO  │
│ 4️⃣ - 📱 MI ACCESO       │
│ 5️⃣ - 📂 DESCARGAR CONFIG │
│ 6️⃣ - ❓ CÓMO OBTENER HWID│
└─────────────────────────┘

💡 *NUEVO:* Acceso por HWID automático`);
                }
                
                // ============ OPCIÓN 1: PRUEBA GRATIS ============
                else if (text === '1' && userState.state === 'main_menu') {
                    await setUserState(from, 'waiting_hwid_test');
                    await client.sendText(from, `🧪 *PRUEBA GRATIS - 2 HORAS*

📱 Para activar tu prueba necesito tu *HWID*

📍 ¿Cómo obtener tu HWID?
1. Abre HTTP Custom
2. Ve a Ajustes ⚙️
3. Busca "ID del dispositivo" o "Device ID"
4. Copia el código

✏️ *Envía tu HWID ahora* (ej: abc123def456)

O envía 0 para cancelar`);
                }
                
                else if (userState.state === 'waiting_hwid_test' && text !== '0' && text.length > 5) {
                    const hwid = message.body.trim();
                    
                    if (!(await canGetTest(hwid, from))) {
                        await client.sendText(from, `⚠️ *Ya usaste tu prueba hoy*

Vuelve mañana para otra prueba gratuita de 2 horas.
O compra acceso completo con la opción 2.`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    const result = await createTestAccess(from, hwid);
                    
                    if (result.success) {
                        registerTest(hwid, from);
                        await client.sendText(from, `✅ *PRUEBA ACTIVADA*

🔑 HWID: ${hwid}
⏰ Válido hasta: ${formatExpiration(result.expiresAt)}
📂 Configuración: HTTP Custom Premium

📲 *Envía "4" ahora para descargar tu archivo .hc*`);
                        await sendHCFile(from);
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    await setUserState(from, 'main_menu');
                }
                
                // ============ OPCIÓN 2: COMPRAR ============
                else if (text === '2' && userState.state === 'main_menu') {
                    await setUserState(from, 'buying_hwid');
                    await client.sendText(from, `💎 *PLANES DISPONIBLES*

┌─────────────────────────┐
│ 1️⃣ - 7 DÍAS    - $${config.prices.price_7d} │
│ 2️⃣ - 15 DÍAS   - $${config.prices.price_15d}│
│ 3️⃣ - 30 DÍAS   - $${config.prices.price_30d}│
│ 4️⃣ - 50 DÍAS   - $${config.prices.price_50d}│
└─────────────────────────┘

💰 Pagos vía MercadoPago

*Envía el número del plan* (1, 2, 3 o 4)
0 para cancelar`);
                }
                
                else if (userState.state === 'buying_hwid' && ['1', '2', '3', '4'].includes(text)) {
                    const plans = {
                        '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                        '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' },
                        '3': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                        '4': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                    };
                    const plan = plans[text];
                    
                    await setUserState(from, 'buying_waiting_hwid', { plan });
                    await client.sendText(from, `📱 *Plan seleccionado:* ${plan.name} - $${plan.price}

Ahora *envía tu HWID* para generar el pago

📍 ¿Cómo obtener HWID?
Configuración de HTTP Custom → ID del dispositivo

0 para cancelar`);
                }
                
                else if (userState.state === 'buying_waiting_hwid') {
                    if (text === '0') {
                        await setUserState(from, 'main_menu');
                        await client.sendText(from, `✅ Compra cancelada`);
                        return;
                    }
                    
                    const hwid = message.body.trim();
                    const plan = userState.data.plan;
                    
                    if (hwid.length < 5) {
                        await client.sendText(from, `❌ HWID inválido. Envía un código válido (mínimo 5 caracteres)`);
                        return;
                    }
                    
                    await client.sendText(from, `⏳ Generando pago...`);
                    
                    const payment = await createPayment(from, hwid, plan.days, plan.price, plan.name, false);
                    
                    if (payment.success) {
                        await client.sendText(from, `💳 *PAGO CON MERCADOPAGO*

📆 Plan: ${plan.name}
💰 Total: $${payment.amount}

🔗 *LINK DE PAGO:*
${payment.paymentUrl}

⏰ Válido por 24 horas

✅ Una vez pagado, tu acceso se activará automáticamente`);
                    } else {
                        await client.sendText(from, `❌ Error: ${payment.error}\n\nContacta al administrador:\n${config.links.support}`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
                // ============ OPCIÓN 3: RENOVAR ============
                else if (text === '3' && userState.state === 'main_menu') {
                    const accesos = await getUserActiveAccess(from);
                    
                    if (accesos.length === 0) {
                        await client.sendText(from, `📋 *No tienes accesos activos*

Para obtener una prueba gratis, envía MENU → opción 1`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    let message = `🔄 *RENOVAR ACCESO*

Tus accesos activos:\n\n`;
                    accesos.forEach((a, i) => {
                        message += `${i + 1}️⃣ HWID: ${a.hwid.substring(0, 10)}...\n   ⏰ Expira: ${formatExpiration(a.expires_at)}\n   📅 Días restantes: ${getDaysRemaining(a.expires_at)}\n\n`;
                    });
                    message += `✏️ *Envía el número del acceso a renovar* (1-${accesos.length})\n0 para cancelar`;
                    
                    await setUserState(from, 'renew_select_access', { accesos });
                    await client.sendText(from, message);
                }
                
                else if (userState.state === 'renew_select_access') {
                    if (text === '0') {
                        await setUserState(from, 'main_menu');
                        await client.sendText(from, `✅ Renovación cancelada`);
                        return;
                    }
                    
                    const idx = parseInt(text) - 1;
                    const accesos = userState.data.accesos;
                    
                    if (idx >= 0 && idx < accesos.length) {
                        await setUserState(from, 'renew_select_plan', { hwid: accesos[idx].hwid });
                        await client.sendText(from, `📆 *PLANES DE RENOVACIÓN*

1️⃣ - 7 DÍAS   - $${config.prices.price_7d}
2️⃣ - 15 DÍAS  - $${config.prices.price_15d}
3️⃣ - 30 DÍAS  - $${config.prices.price_30d}
4️⃣ - 50 DÍAS  - $${config.prices.price_50d}

Envía el número del plan
0 para cancelar`);
                    } else {
                        await client.sendText(from, `❌ Opción inválida`);
                    }
                }
                
                else if (userState.state === 'renew_select_plan' && ['1', '2', '3', '4'].includes(text)) {
                    const plans = {
                        '1': { days: 7, price: config.prices.price_7d },
                        '2': { days: 15, price: config.prices.price_15d },
                        '3': { days: 30, price: config.prices.price_30d },
                        '4': { days: 50, price: config.prices.price_50d }
                    };
                    const plan = plans[text];
                    const hwid = userState.data.hwid;
                    
                    await client.sendText(from, `⏳ Generando pago para renovación...`);
                    
                    const payment = await createPayment(from, hwid, plan.days, plan.price, 'RENOVACIÓN', true);
                    
                    if (payment.success) {
                        await client.sendText(from, `🔄 *RENOVACIÓN*

🔑 HWID: ${hwid.substring(0, 10)}...
📆 +${plan.days} días
💰 $${payment.amount}

🔗 *LINK DE PAGO:*
${payment.paymentUrl}

✅ Se sumará a tu tiempo restante`);
                    } else {
                        await client.sendText(from, `❌ Error: ${payment.error}`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
                // ============ OPCIÓN 4: MI ACCESO ============
                else if (text === '4' && userState.state === 'main_menu') {
                    const accesos = await getUserActiveAccess(from);
                    
                    if (accesos.length === 0) {
                        await client.sendText(from, `📋 *No tienes accesos activos*

🔓 Para prueba gratis: MENU → 1
💎 Para comprar: MENU → 2`);
                    } else {
                        let message = `📋 *TUS ACCESOS ACTIVOS*\n\n`;
                        for (const a of accesos) {
                            message += `🔑 HWID: ${a.hwid}\n`;
                            message += `📁 Config: ${a.file_name}\n`;
                            message += `⏰ Expira: ${formatExpiration(a.expires_at)}\n`;
                            message += `📅 Días restantes: ${getDaysRemaining(a.expires_at)}\n`;
                            message += `━━━━━━━━━━━━━━━━━━━━━\n`;
                        }
                        message += `\n🔄 Para renovar: MENU → 3\n📂 Para descargar config: MENU → 5`;
                        await client.sendText(from, message);
                    }
                }
                
                // ============ OPCIÓN 5: DESCARGAR CONFIG ============
                else if (text === '5' && userState.state === 'main_menu') {
                    const accesos = await getUserActiveAccess(from);
                    
                    if (accesos.length === 0) {
                        await client.sendText(from, `❌ *No tienes accesos activos*

Primero activa una prueba o compra acceso.`);
                    } else {
                        await client.sendText(from, `📂 *Enviando configuración...*`);
                        await sendHCFile(from);
                    }
                }
                
                // ============ OPCIÓN 6: CÓMO OBTENER HWID ============
                else if (text === '6' && userState.state === 'main_menu') {
                    await client.sendText(from, `📱 *CÓMO OBTENER TU HWID*

1️⃣ Abre la app *HTTP Custom*
2️⃣ Ve a la pestaña *Ajustes* (⚙️)
3️⃣ Busca *"ID del dispositivo"* o *"Device ID"*
4️⃣ Copia el código (ej: abc123def456)

📹 *Video tutorial:* ${config.links.how_to_get_hwid}

✏️ Una vez tengas tu HWID, vuelve y usa las opciones del menú.`);
                }
                
            } catch (error) {
                console.error(chalk.red(`Error: ${error.message}`));
            }
        });
        
        // ============ CRON JOBS ============
        
        // Verificar pagos cada 2 minutos
        cron.schedule('*/2 * * * *', () => {
            checkPendingPayments();
        });
        
        // Limpiar expirados cada hora
        cron.schedule('0 * * * *', () => {
            db.run(`UPDATE users SET status = 0 WHERE expires_at < datetime('now')`);
            db.run(`DELETE FROM pending_activations WHERE expires_at < datetime('now')`);
            console.log(chalk.yellow('🔄 Limpieza de accesos expirados completada'));
        });
        
        // Recordatorios diarios (1 día antes)
        cron.schedule('0 10 * * *', async () => {
            const tomorrow = moment().add(1, 'day').format('YYYY-MM-DD');
            
            db.all(`SELECT phone, hwid, expires_at FROM users 
                    WHERE status = 1 AND date(expires_at) = ? AND last_reminder_sent = 0`,
                [tomorrow], async (err, users) => {
                if (err || !users) return;
                
                for (const user of users) {
                    try {
                        await client.sendText(user.phone, `⚠️ *RECORDATORIO*

Tu acceso para HWID *${user.hwid}* expirará MAÑANA.

📅 Fecha: ${formatExpiration(user.expires_at)}

🔄 *RENUEVA AHORA* enviando MENU → opción 3`);
                        
                        db.run(`UPDATE users SET last_reminder_sent = 1 WHERE hwid = ?`, [user.hwid]);
                        console.log(chalk.green(`✅ Recordatorio enviado a ${user.hwid}`));
                    } catch (e) {}
                }
            });
        });
        
        // Recordatorio 6 horas antes
        cron.schedule('*/30 * * * *', async () => {
            const sixHoursLater = moment().add(6, 'hours').format('YYYY-MM-DD HH:00:00');
            
            db.all(`SELECT phone, hwid, expires_at FROM users 
                    WHERE status = 1 AND expires_at BETWEEN datetime('now') AND ? AND tipo = 'premium'`,
                [sixHoursLater], async (err, users) => {
                if (err || !users) return;
                
                for (const user of users) {
                    const hoursLeft = moment(user.expires_at).diff(moment(), 'hours');
                    if (hoursLeft <= 6 && hoursLeft > 0) {
                        await client.sendText(user.phone, `⏰ *AVISO IMPORTANTE*

Tu acceso expirará en *${hoursLeft} horas*

🔑 HWID: ${user.hwid}

Renueva con MENU → opción 3`);
                    }
                }
            });
        });
        
    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
        setTimeout(initializeBot, 10000);
    }
}

initializeBot();

process.on('SIGINT', async () => {
    console.log(chalk.yellow('🛑 Cerrando...'));
    if (client) await client.close();
    process.exit();
});
BOTEOF

echo -e "${GREEN}✅ Bot.js creado${NC}"

# ================================================
# PANEL DE CONTROL
# ================================================
echo -e "\n${CYAN}🎛️ Creando panel de control...${NC}"

cat > /usr/local/bin/hcbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

DB="/opt/hcbot-pro/data/users.db"
CONFIG="/opt/hcbot-pro/config/config.json"
HC_DIR="/opt/hcbot-pro/hc_files"

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         🎛️  PANEL HTTP CUSTOM BOT PRO - HWID                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

while true; do
    show_header
    
    TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1 AND expires_at > datetime('now')" 2>/dev/null || echo "0")
    TESTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE tipo='test' AND status=1" 2>/dev/null || echo "0")
    STATUS=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.name=="hcbot-pro") | .pm2_env.status' 2>/dev/null || echo "stopped")
    
    echo -e "${YELLOW}📊 ESTADO${NC}"
    echo -e "  Bot: $([ "$STATUS" == "online" ] && echo "${GREEN}● ACTIVO${NC}" || echo "${RED}● DETENIDO${NC}")"
    echo -e "  Usuarios: ${CYAN}$ACTIVE/$TOTAL${NC} (${TESTS} pruebas)"
    echo -e "  MP: $([ -n "$(jq -r '.mercadopago.access_token' $CONFIG 2>/dev/null)" ] && echo "${GREEN}✅${NC}" || echo "${RED}❌${NC}")"
    echo -e ""
    
    echo -e "${CYAN}[1] Iniciar bot    [2] Detener bot    [3] Ver logs"
    echo -e "${CYAN}[4] Config MP      [5] Editar precios [6] Subir archivo .hc"
    echo -e "${CYAN}[7] Ver usuarios   [8] Estadísticas   [9] Broadcast"
    echo -e "${CYAN}[0] Salir${NC}"
    echo ""
    read -p "👉 Opción: " OPT
    
    case $OPT in
        1) cd /root/hcbot-pro && pm2 restart hcbot-pro 2>/dev/null || pm2 start bot.js --name hcbot-pro; pm2 save;;
        2) pm2 stop hcbot-pro;;
        3) pm2 logs hcbot-pro --lines 80;;
        4)
            TOKEN=$(jq -r '.mercadopago.access_token' $CONFIG)
            echo -e "\n${YELLOW}Token actual: ${TOKEN:0:30}...${NC}"
            read -p "Nuevo token (APP_USR-xxx): " NEW_TOKEN
            if [[ "$NEW_TOKEN" =~ ^APP_USR- ]]; then
                jq ".mercadopago.access_token = \"$NEW_TOKEN\" | .mercadopago.enabled = true" $CONFIG > tmp && mv tmp $CONFIG
                echo -e "${GREEN}✅ Token guardado${NC}"
            fi
            read -p "Enter...";;
        5)
            echo -e "\n${YELLOW}Precios actuales:${NC}"
            echo "  7d: $(jq -r '.prices.price_7d' $CONFIG) | 15d: $(jq -r '.prices.price_15d' $CONFIG)"
            echo "  30d: $(jq -r '.prices.price_30d' $CONFIG) | 50d: $(jq -r '.prices.price_50d' $CONFIG)"
            read -p "Nuevo 7d: " p7; read -p "Nuevo 15d: " p15
            read -p "Nuevo 30d: " p30; read -p "Nuevo 50d: " p50
            [[ -n "$p7" ]] && jq ".prices.price_7d = $p7" $CONFIG > tmp && mv tmp $CONFIG
            [[ -n "$p15" ]] && jq ".prices.price_15d = $p15" $CONFIG > tmp && mv tmp $CONFIG
            [[ -n "$p30" ]] && jq ".prices.price_30d = $p30" $CONFIG > tmp && mv tmp $CONFIG
            [[ -n "$p50" ]] && jq ".prices.price_50d = $p50" $CONFIG > tmp && mv tmp $CONFIG
            echo -e "${GREEN}✅ Precios actualizados${NC}"
            read -p "Enter...";;
        6)
            echo -e "\n${CYAN}📂 Subir archivo .hc${NC}"
            read -p "Ruta del archivo .hc: " SOURCE
            if [[ -f "$SOURCE" && "$SOURCE" == *.hc ]]; then
                cp "$SOURCE" "$HC_DIR/mgvpn.hc"
                echo -e "${GREEN}✅ Archivo actualizado${NC}"
            else
                echo -e "${RED}❌ Archivo inválido${NC}"
            fi
            read -p "Enter...";;
        7)
            echo -e "\n${CYAN}USUARIOS ACTIVOS:${NC}"
            sqlite3 -column -header "$DB" "SELECT hwid, phone, tipo, expires_at FROM users WHERE status=1 AND expires_at>datetime('now') ORDER BY expires_at LIMIT 30"
            read -p "Enter...";;
        8)
            clear
            echo -e "${CYAN}📊 ESTADÍSTICAS${NC}\n"
            echo "Usuarios totales: $(sqlite3 "$DB" "SELECT COUNT(*) FROM users")"
            echo "Activos: $(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1 AND expires_at>datetime('now')")"
            echo "Pruebas hoy: $(sqlite3 "$DB" "SELECT COUNT(*) FROM daily_tests WHERE date=date('now')")"
            echo "Pagos aprobados: $(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='approved'")"
            echo "Ingresos: $(sqlite3 "$DB" "SELECT printf('%.2f', SUM(amount)) FROM payments WHERE status='approved'") ARS"
            echo "Vencen hoy: $(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1 AND date(expires_at)=date('now')")"
            read -p "Enter...";;
        9)
            echo -e "\n${YELLOW}📢 BROADCAST${NC}"
            read -p "Mensaje: " MSG
            PHONES=$(sqlite3 "$DB" "SELECT DISTINCT phone FROM users WHERE status=1 AND expires_at>datetime('now')")
            for p in $PHONES; do
                curl -s -X POST "https://api.whatsapp.com/send?phone=$p&text=$(echo $MSG | sed 's/ /%20/g')" > /dev/null
                sleep 1
            done
            echo -e "${GREEN}✅ Enviado${NC}"
            read -p "Enter...";;
        0) echo -e "\n${GREEN}👋 Hasta luego${NC}"; exit 0;;
    esac
done
PANELEOF

chmod +x /usr/local/bin/hcbot

# ================================================
# INICIAR
# ================================================
echo -e "\n${CYAN}🚀 Iniciando bot...${NC}"

cd "$USER_HOME"
pm2 start bot.js --name hcbot-pro
pm2 save
pm2 startup systemd -u root --hp /root > /dev/null 2>&1

sleep 3

# ================================================
# FINAL
# ================================================
clear
echo -e "${GREEN}${BOLD}"
cat << "FINAL"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          🎉 INSTALACIÓN COMPLETADA - HTTP CUSTOM 🎉         ║
║                                                              ║
║       ✅ Login por HWID funcionando                        ║
║       ✅ Entrega automática de archivo .hc                 ║
║       ✅ Prueba gratuita 2 horas                           ║
║       ✅ Renovación de accesos                             ║
║       ✅ Recordatorios automáticos                         ║
║       ✅ MercadoPago integrado                             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${GREEN}✅ Instalación completa${NC}"
echo -e ""
echo -e "${YELLOW}📋 COMANDOS:${NC}"
echo -e "  ${GREEN}hcbot${NC}          - Panel de control"
echo -e "  ${GREEN}pm2 logs hcbot-pro${NC} - Ver QR y logs"
echo -e ""
echo -e "${YELLOW}🚀 PRIMEROS PASOS:${NC}"
echo -e "  1. ${GREEN}pm2 logs hcbot-pro${NC} - Escanear QR"
echo -e "  2. ${GREEN}hcbot${NC} - Configurar MercadoPago (opción 4)"
echo -e "  3. Subir archivo .hc (opción 6)"
echo -e "  4. Enviar 'menu' al bot"
echo -e ""

read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    pm2 logs hcbot-pro
fi

exit 0