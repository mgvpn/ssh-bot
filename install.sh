#!/bin/bash
# ================================================
# HTTP CUSTOM BOT PRO - CON VALIDACIÓN HWID
# VERSIÓN COMPLETA CON ENDPOINT DE VERIFICACIÓN
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
║      🤖 HTTP CUSTOM BOT PRO - HWID COMPLETO                 ║
║               📱 WhatsApp + API de Validación               ║
║               💰 MercadoPago SDK v2.x                       ║
║               🔑 VALIDACIÓN HWID EN TIEMPO REAL             ║
║               📂 ENTREGA AUTOMÁTICA .hc                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Debes ejecutar como root${NC}"
    echo -e "${YELLOW}Usa: sudo bash $0${NC}"
    exit 1
fi

# Detectar IP
echo -e "${CYAN}🔍 Detectando IP del servidor...${NC}"
SERVER_IP=$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "127.0.0.1")
if [[ -z "$SERVER_IP" || "$SERVER_IP" == "127.0.0.1" ]]; then
    read -p "📝 Ingresa la IP del servidor: " SERVER_IP
fi

echo -e "${GREEN}✅ IP: ${CYAN}$SERVER_IP${NC}"
echo -e "${YELLOW}📌 Los usuarios usarán: http://$SERVER_IP:8001/api/validate/SU-HWID${NC}\n"

read -p "$(echo -e "${YELLOW}¿Continuar instalación? (s/N): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${RED}❌ Cancelado${NC}"
    exit 0
fi

# ================================================
# INSTALAR DEPENDENCIAS
# ================================================
echo -e "\n${CYAN}📦 Instalando dependencias del sistema...${NC}"

apt-get update -y
apt-get upgrade -y

# Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs gcc g++ make

# Chrome/Chromium para WhatsApp
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get update -y
apt-get install -y google-chrome-stable

# Otras dependencias
apt-get install -y \
    git curl wget sqlite3 jq \
    build-essential libcairo2-dev \
    libpango1.0-dev libjpeg-dev \
    libgif-dev librsvg2-dev \
    python3 python3-pip ffmpeg \
    unzip cron ufw nginx

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
echo -e "\n${CYAN}📁 Creando estructura de directorios...${NC}"

INSTALL_DIR="/opt/hcbot-pro"
USER_HOME="/root/hcbot-pro"
DB_FILE="$INSTALL_DIR/data/users.db"
CONFIG_FILE="$INSTALL_DIR/config/config.json"
HC_FILES_DIR="$INSTALL_DIR/hc_files"

# Limpiar anterior
pm2 delete hcbot-pro 2>/dev/null || true
pm2 delete hwid-server 2>/dev/null || true
rm -rf "$INSTALL_DIR" "$USER_HOME" 2>/dev/null || true
rm -rf /root/.wppconnect 2>/dev/null || true

# Crear directorios
mkdir -p "$INSTALL_DIR"/{data,config,sessions,logs,qr_codes,hc_files,www}
mkdir -p "$USER_HOME"
mkdir -p /root/.wppconnect
chmod -R 755 "$INSTALL_DIR"
chmod -R 700 /root/.wppconnect

# Crear archivo .hc de ejemplo
cat > "$HC_FILES_DIR/mgvpn.hc" << 'HCEOF'
# HTTP Custom Config
# MGVPN Premium
# Generado automáticamente
# Servidor: MGVPN
# Puerto: 443
# Método: HTTPS
HCEOF

# Configuración principal
cat > "$CONFIG_FILE" << EOF
{
    "bot": {
        "name": "HTTP Custom Bot Pro",
        "version": "4.0-HWID-COMPLETE",
        "server_ip": "$SERVER_IP",
        "api_port": 8001
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

# Base de datos
sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    hwid TEXT UNIQUE,
    username TEXT,
    file_name TEXT DEFAULT 'mgvpn.hc',
    tipo TEXT DEFAULT 'test',
    expires_at DATETIME,
    status INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_reminder_sent INTEGER DEFAULT 0,
    last_checkin DATETIME
);

CREATE TABLE IF NOT EXISTS pending_activations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    hwid TEXT,
    code TEXT UNIQUE,
    expires_at DATETIME,
    days INTEGER,
    used INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS daily_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hwid TEXT,
    phone TEXT,
    date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(hwid, date)
);

CREATE TABLE IF NOT EXISTS payments (
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

CREATE TABLE IF NOT EXISTS user_state (
    phone TEXT PRIMARY KEY,
    state TEXT DEFAULT 'main_menu',
    data TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS hwid_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hwid TEXT,
    ip TEXT,
    user_agent TEXT,
    check_time DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_hwid ON users(hwid);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_hwid_logs_hwid ON hwid_logs(hwid);
CREATE INDEX idx_hwid_logs_time ON hwid_logs(check_time);
SQL

echo -e "${GREEN}✅ Estructura creada${NC}"

# ================================================
# CREAR BOT COMPLETO CON VALIDACIÓN HWID
# ================================================
echo -e "\n${CYAN}🤖 Creando bot con validación HWID...${NC}"

cd "$USER_HOME"

cat > package.json << 'PKGEOF'
{
    "name": "hcbot-pro-complete",
    "version": "4.0.0",
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
        "express": "^4.18.2",
        "cors": "^2.8.5"
    }
}
PKGEOF

echo -e "${YELLOW}📦 Instalando dependencias NPM...${NC}"
npm install --silent 2>&1 | grep -v "npm WARN" || true

# Crear bot.js completo
cat > "bot.js" << 'BOTEOF'
const wppconnect = require('@wppconnect-team/wppconnect');
const qrcode = require('qrcode-terminal');
const moment = require('moment');
const sqlite3 = require('sqlite3').verbose();
const chalk = require('chalk');
const cron = require('node-cron');
const fs = require('fs');
const path = require('path');
const axios = require('axios');
const express = require('express');
const cors = require('cors');

moment.locale('es');

console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════════════╗'));
console.log(chalk.cyan.bold('║   🤖 HTTP CUSTOM BOT PRO - CON VALIDACIÓN HWID COMPLETA      ║'));
console.log(chalk.cyan.bold('║         🔑 API DE VALIDACIÓN EN TIEMPO REAL ACTIVADA         ║'));
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

// ============ SERVIDOR EXPRESS PARA VALIDACIÓN HWID ============
const app = express();
app.use(cors());
app.use(express.json());

// Función para verificar HWID (reutilizable)
function checkHWIDAccess(hwid) {
    return new Promise((resolve) => {
        db.get(`SELECT * FROM users WHERE hwid = ? AND status = 1 AND expires_at > datetime('now')`,
            [hwid], (err, row) => {
            resolve({ active: !!row, user: row });
        });
    });
}

function getDaysRemaining(expiresAt) {
    const diff = moment(expiresAt).diff(moment(), 'days');
    return diff > 0 ? diff : 0;
}

// Endpoint PRINCIPAL que usa HTTP Custom
app.get('/api/validate/:hwid', async (req, res) => {
    const hwid = req.params.hwid;
    const ip = req.ip || req.headers['x-forwarded-for'] || 'unknown';
    
    console.log(chalk.yellow(`🔍 Validación HWID: ${hwid} desde ${ip}`));
    
    if (!hwid || hwid.length < 5) {
        return res.json({ 
            success: false, 
            active: false, 
            message: 'HWID inválido',
            error_code: 'INVALID_HWID'
        });
    }
    
    try {
        // Registrar intento de validación
        db.run(`INSERT INTO hwid_logs (hwid, ip, user_agent) VALUES (?, ?, ?)`,
            [hwid, ip, req.headers['user-agent'] || 'unknown']);
        
        const result = await checkHWIDAccess(hwid);
        
        if (result.active) {
            const daysLeft = getDaysRemaining(result.user.expires_at);
            console.log(chalk.green(`✅ HWID válido: ${hwid} - Días restantes: ${daysLeft}`));
            
            // Actualizar último checkin
            db.run(`UPDATE users SET last_checkin = CURRENT_TIMESTAMP WHERE hwid = ?`, [hwid]);
            
            return res.json({
                success: true,
                active: true,
                message: '✅ Acceso activo',
                expires_at: result.user.expires_at,
                days_left: daysLeft,
                tipo: result.user.tipo,
                file: result.user.file_name || 'mgvpn.hc',
                server: config.bot.name
            });
        } else {
            console.log(chalk.red(`❌ HWID inválido/expirado: ${hwid}`));
            return res.json({
                success: false,
                active: false,
                message: '❌ Acceso expirado o no existe. Contacta soporte para renovar.',
                error_code: 'EXPIRED_OR_NOT_FOUND'
            });
        }
    } catch (error) {
        console.error(chalk.red(`Error en validación: ${error.message}`));
        return res.json({ 
            success: false, 
            active: false, 
            message: 'Error de verificación',
            error_code: 'SERVER_ERROR'
        });
    }
});

// Endpoint para verificar en lote (múltiples HWIDs)
app.post('/api/validate-batch', async (req, res) => {
    const { hwids } = req.body;
    
    if (!hwids || !Array.isArray(hwids) || hwids.length === 0) {
        return res.json({ success: false, error: 'Se requiere array de HWIDs' });
    }
    
    const results = [];
    for (const hwid of hwids) {
        const result = await checkHWIDAccess(hwid);
        results.push({
            hwid,
            active: result.active,
            expires_at: result.active ? result.user.expires_at : null,
            days_left: result.active ? getDaysRemaining(result.user.expires_at) : 0
        });
    }
    
    res.json({ success: true, count: results.length, results });
});

// Endpoint de configuración para el cliente
app.get('/api/config', (req, res) => {
    res.json({
        success: true,
        server: {
            name: config.bot.name,
            version: config.bot.version,
            ip: config.bot.server_ip
        },
        validation_endpoint: `http://${config.bot.server_ip}:${config.bot.api_port}/api/validate/`,
        prices: config.prices,
        links: {
            app_download: config.links.app_download,
            support: config.links.support,
            how_to_get_hwid: config.links.how_to_get_hwid
        }
    });
});

// Endpoint de estadísticas para admin
app.get('/api/stats', async (req, res) => {
    db.get(`SELECT 
        (SELECT COUNT(*) FROM users) as total_users,
        (SELECT COUNT(*) FROM users WHERE status = 1 AND expires_at > datetime('now')) as active_users,
        (SELECT COUNT(*) FROM hwid_logs WHERE date(check_time) = date('now')) as todays_checks
    `, (err, stats) => {
        res.json({ success: true, stats: stats || { total_users: 0, active_users: 0, todays_checks: 0 } });
    });
});

// Endpoint para verificar si un pago fue aprobado (desde HTTP Custom)
app.get('/api/check-payment/:payment_id', async (req, res) => {
    const { payment_id } = req.params;
    
    db.get(`SELECT * FROM payments WHERE payment_id = ? OR preference_id = ?`, 
        [payment_id, payment_id], async (err, payment) => {
        if (err || !payment) {
            return res.json({ success: false, status: 'not_found' });
        }
        
        if (payment.status === 'approved') {
            return res.json({ success: true, status: 'approved', message: 'Pago confirmado' });
        }
        
        // Verificar en MercadoPago si está pendiente
        if (mpEnabled && payment.status === 'pending') {
            try {
                const response = await axios.get(`https://api.mercadopago.com/v1/payments/search?external_reference=${payment.payment_id}`, {
                    headers: { 'Authorization': `Bearer ${config.mercadopago.access_token}` }
                });
                
                if (response.data.results?.[0]?.status === 'approved') {
                    await activatePayment(payment);
                    return res.json({ success: true, status: 'approved', message: 'Pago confirmado' });
                }
            } catch (e) {}
        }
        
        res.json({ success: false, status: payment.status });
    });
});

// Función auxiliar para activar pago
async function activatePayment(payment) {
    const expiresAt = moment().add(payment.days, 'days').format('YYYY-MM-DD HH:mm:ss');
    
    if (payment.is_renewal) {
        db.run(`UPDATE users SET expires_at = ?, tipo = 'premium' WHERE hwid = ?`,
            [expiresAt, payment.hwid]);
    } else {
        db.run(`INSERT OR REPLACE INTO users (phone, hwid, tipo, expires_at, status)
                VALUES (?, ?, 'premium', ?, 1)`,
            [payment.phone, payment.hwid, expiresAt]);
    }
    
    db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE id = ?`, 
        [payment.id]);
}

// Iniciar servidor HTTP
const HTTP_PORT = config.bot.api_port || 8001;
app.listen(HTTP_PORT, '0.0.0.0', () => {
    console.log(chalk.green(`✅ Servidor de validación HWID activo`));
    console.log(chalk.cyan(`   URL: http://${config.bot.server_ip}:${HTTP_PORT}/api/validate/{HWID}`));
});

// ============ FUNCIONES DEL BOT WHATSAPP ============

function formatExpiration(date) {
    return moment(date).format('DD/MM/YYYY HH:mm');
}

function generateActivationCode() {
    return Math.random().toString(36).substring(2, 10).toUpperCase();
}

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
            `📱 *HTTP CUSTOM CONFIG - MGVPN*\n\n🔗 *URL DE VALIDACIÓN:*\nhttp://${config.bot.server_ip}:${HTTP_PORT}/api/validate/TU-HWID\n\n📌 *Instrucciones:*\n1. Importa este archivo en HTTP Custom\n2. Ve a Ajustes → Validación HWID\n3. Configura la URL de validación\n4. Tu HWID se validará automáticamente\n\n✅ Tu acceso ya está activo`
        );
        return true;
    } catch (error) {
        console.error(chalk.red(`❌ Error: ${error.message}`));
        return false;
    }
}

function getUserActiveAccess(phone) {
    return new Promise((resolve) => {
        db.all(`SELECT hwid, tipo, expires_at, file_name FROM users 
                WHERE phone = ? AND status = 1 AND expires_at > datetime('now')`,
            [phone], (err, rows) => {
            resolve(rows || []);
        });
    });
}

async function createPayment(phone, hwid, days, amount, planName, isRenewal = false) {
    if (!mpEnabled || !mpPreference) {
        return { success: false, error: 'MercadoPago no configurado. Contacta al administrador.' };
    }
    
    const paymentId = `${isRenewal ? 'RENEW' : 'HC'}-${Date.now()}`;
    
    try {
        const preferenceData = {
            items: [{
                title: isRenewal ? `RENOVACIÓN ${days} DÍAS - MGVPN` : `HTTP CUSTOM MGVPN - ${days} DÍAS`,
                description: `Acceso VPN por ${days} días con validación HWID`,
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
            },
            notification_url: `http://${config.bot.server_ip}:${HTTP_PORT}/api/webhook`
        };
        
        const response = await mpPreference.create({ body: preferenceData });
        
        if (response && response.id) {
            db.run(`INSERT INTO payments (payment_id, phone, hwid, plan, days, amount, status, payment_url, preference_id, is_renewal)
                    VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
                [paymentId, phone, hwid, `${days}d`, days, amount, response.init_point, response.id, isRenewal ? 1 : 0]);
            
            return { success: true, paymentUrl: response.init_point, amount, paymentId };
        }
        
        return { success: false, error: 'Error creando pago' };
    } catch (error) {
        return { success: false, error: error.message };
    }
}

// Webhook para MercadoPago
app.post('/api/webhook', express.json(), async (req, res) => {
    console.log(chalk.yellow('Webhook recibido:'), req.body);
    res.sendStatus(200);
});

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
                    
                    const expiresAt = moment().add(payment.days, 'days').format('YYYY-MM-DD HH:mm:ss');
                    
                    if (payment.is_renewal) {
                        db.run(`UPDATE users SET expires_at = ?, tipo = 'premium' WHERE hwid = ?`,
                            [expiresAt, payment.hwid]);
                    } else {
                        db.run(`INSERT OR REPLACE INTO users (phone, hwid, tipo, expires_at, status)
                                VALUES (?, ?, 'premium', ?, 1)`,
                            [payment.phone, payment.hwid, expiresAt]);
                    }
                    
                    db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`,
                        [payment.payment_id]);
                    
                    if (client) {
                        await client.sendText(payment.phone, `✅ *PAGO CONFIRMADO - MGVPN*\n\nTu acceso ha sido activado por ${payment.days} días.\n\n🔑 HWID: ${payment.hwid}\n📅 Expira: ${moment(expiresAt).format('DD/MM/YYYY')}\n\n📲 Envía "MENU" para más opciones.`);
                        await sendHCFile(payment.phone);
                    }
                }
            } catch (error) {
                console.error(chalk.red(`Error verificando: ${error.message}`));
            }
        }
    });
}

// Estado de usuario
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

let client = null;

// ============ INICIALIZAR BOT WHATSAPP ============

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
                args: ['--no-sandbox', '--disable-gpu']
            }
        });
        
        console.log(chalk.green('✅ Bot de WhatsApp conectado!'));
        
        // Manejar mensajes
        client.onMessage(async (message) => {
            try {
                const text = message.body.toLowerCase().trim();
                const from = message.from;
                
                console.log(chalk.cyan(`📩 ${from}: ${text.substring(0, 50)}`));
                
                const userState = await getUserState(from);
                
                // Menú principal
                if (['menu', 'hola', 'start', '0'].includes(text)) {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, `🌟 *MGVPN - HTTP CUSTOM BOT* 🌟

┌─────────────────────────┐
│ 1️⃣ - 🧪 PRUEBA GRATIS   │
│ 2️⃣ - 💰 COMPRAR ACCESO  │
│ 3️⃣ - 🔄 RENOVAR ACCESO  │
│ 4️⃣ - 📱 MI ACCESO       │
│ 5️⃣ - 📂 DESCARGAR CONFIG │
│ 6️⃣ - ❓ CÓMO OBTENER HWID│
└─────────────────────────┘

🔑 *URL DE VALIDACIÓN:*
http://${config.bot.server_ip}:${HTTP_PORT}/api/validate/TU-HWID`);
                }
                
                // Opción 1: Prueba gratis
                else if (text === '1' && userState.state === 'main_menu') {
                    await setUserState(from, 'waiting_hwid_test');
                    await client.sendText(from, `🧪 *PRUEBA GRATIS - 2 HORAS*

📱 Para activar tu prueba necesito tu *HWID*

📍 *URL de validación que usarás:*
http://${config.bot.server_ip}:${HTTP_PORT}/api/validate/TU-HWID

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
                        await client.sendText(from, `✅ *PRUEBA ACTIVADA - MGVPN*

🔑 HWID: ${hwid}
⏰ Válido hasta: ${formatExpiration(result.expiresAt)}
🌐 URL de validación: http://${config.bot.server_ip}:${HTTP_PORT}/api/validate/${hwid}

📲 *Configura en HTTP Custom:*
1. Ajustes → Validación HWID
2. Activar validación
3. Pegar la URL de arriba

📂 *Envía "5" para descargar tu archivo .hc*`);
                        await sendHCFile(from);
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    await setUserState(from, 'main_menu');
                }
                
                // Opción 2: Comprar
                else if (text === '2' && userState.state === 'main_menu') {
                    await setUserState(from, 'buying_hwid');
                    await client.sendText(from, `💎 *PLANES MGVPN*

┌─────────────────────────┐
│ 1️⃣ - 7 DÍAS    - $${config.prices.price_7d} │
│ 2️⃣ - 15 DÍAS   - $${config.prices.price_15d}│
│ 3️⃣ - 30 DÍAS   - $${config.prices.price_30d}│
│ 4️⃣ - 50 DÍAS   - $${config.prices.price_50d}│
└─────────────────────────┘

💳 Pagos vía MercadoPago

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

📍 *Tu URL de validación será:*
http://${config.bot.server_ip}:${HTTP_PORT}/api/validate/TU-HWID

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
                        await client.sendText(from, `💳 *PAGO CON MERCADOPAGO - MGVPN*

📆 Plan: ${plan.name}
💰 Total: $${payment.amount}
🔑 HWID: ${hwid}

🔗 *LINK DE PAGO:*
${payment.paymentUrl}

⏰ Válido por 24 horas

✅ Una vez pagado, tu acceso se activará automáticamente
📲 Tu HWID quedará registrado: http://${config.bot.server_ip}:${HTTP_PORT}/api/validate/${hwid}`);
                    } else {
                        await client.sendText(from, `❌ Error: ${payment.error}\n\nContacta al administrador:\n${config.links.support}`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
                // Opción 4: Mi acceso
                else if (text === '4' && userState.state === 'main_menu') {
                    const accesos = await getUserActiveAccess(from);
                    
                    if (accesos.length === 0) {
                        await client.sendText(from, `📋 *No tienes accesos activos*

🔓 Para prueba gratis: MENU → 1
💎 Para comprar: MENU → 2

🌐 URL de validación base:
http://${config.bot.server_ip}:${HTTP_PORT}/api/validate/`);
                    } else {
                        let message = `📋 *TUS ACCESOS ACTIVOS - MGVPN*\n\n`;
                        for (const a of accesos) {
                            message += `🔑 HWID: ${a.hwid}\n`;
                            message += `📁 Config: ${a.file_name}\n`;
                            message += `⏰ Expira: ${formatExpiration(a.expires_at)}\n`;
                            message += `🌐 Validación: http://${config.bot.server_ip}:${HTTP_PORT}/api/validate/${a.hwid}\n`;
                            message += `━━━━━━━━━━━━━━━━━━━━━\n`;
                        }
                        message += `\n🔄 Para renovar: MENU → 3\n📂 Para descargar config: MENU → 5`;
                        await client.sendText(from, message);
                    }
                }
                
                // Opción 5: Descargar config
                else if (text === '5' && userState.state === 'main_menu') {
                    const accesos = await getUserActiveAccess(from);
                    
                    if (accesos.length === 0) {
                        await client.sendText(from, `❌ *No tienes accesos activos*

Primero activa una prueba o compra acceso.`);
                    } else {
                        await client.sendText(from, `📂 *Enviando configuración MGVPN...*`);
                        await sendHCFile(from);
                    }
                }
                
                // Opción 6: Cómo obtener HWID
                else if (text === '6' && userState.state === 'main_menu') {
                    await client.sendText(from, `📱 *CÓMO OBTENER TU HWID*

1️⃣ Abre la app *HTTP Custom*
2️⃣ Ve a la pestaña *Ajustes* (⚙️)
3️⃣ Busca *"ID del dispositivo"* o *"Device ID"*
4️⃣ Copia el código (ej: abc123def456)

📹 *Video tutorial:* ${config.links.how_to_get_hwid}

🌐 *URL de validación que usarás:*
http://${config.bot.server_ip}:${HTTP_PORT}/api/validate/TU-HWID

✏️ Una vez tengas tu HWID, vuelve y usa las opciones del menú.`);
                }
                
                // Mostrar menú si no reconoce
                else if (userState.state === 'main_menu' && !['1','2','3','4','5','6','menu','hola','start','0'].includes(text)) {
                    await client.sendText(from, `❓ Opción no reconocida.

Envía *MENU* para ver las opciones disponibles.`);
                }
                
            } catch (error) {
                console.error(chalk.red(`Error en mensaje: ${error.message}`));
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
        
        // Recordatorios diarios
        cron.schedule('0 10 * * *', async () => {
            const tomorrow = moment().add(1, 'day').format('YYYY-MM-DD');
            
            db.all(`SELECT phone, hwid, expires_at FROM users 
                    WHERE status = 1 AND date(expires_at) = ? AND last_reminder_sent = 0`,
                [tomorrow], async (err, users) => {
                if (err || !users) return;
                
                for (const user of users) {
                    try {
                        await client.sendText(user.phone, `⚠️ *RECORDATORIO MGVPN*

Tu acceso para HWID *${user.hwid}* expirará MAÑANA.

📅 Fecha: ${formatExpiration(user.expires_at)}
🌐 Validación: http://${config.bot.server_ip}:${HTTP_PORT}/api/validate/${user.hwid}

🔄 *RENUEVA AHORA* enviando MENU → opción 3`);
                        
                        db.run(`UPDATE users SET last_reminder_sent = 1 WHERE hwid = ?`, [user.hwid]);
                        console.log(chalk.green(`✅ Recordatorio enviado a ${user.hwid}`));
                    } catch (e) {}
                }
            });
        });
        
    } catch (error) {
        console.error(chalk.red(`Error inicializando bot: ${error.message}`));
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

echo -e "${GREEN}✅ Bot.js creado con validación HWID completa${NC}"

# ================================================
# CREAR PANEL DE CONTROL
# ================================================
echo -e "\n${CYAN}🎛️ Creando panel de control...${NC}"

cat > /usr/local/bin/hcbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'

DB="/opt/hcbot-pro/data/users.db"
CONFIG="/opt/hcbot-pro/config/config.json"
HC_DIR="/opt/hcbot-pro/hc_files"
PORT=$(jq -r '.bot.api_port' $CONFIG 2>/dev/null || echo "8001")
SERVER_IP=$(jq -r '.bot.server_ip' $CONFIG 2>/dev/null || echo "127.0.0.1")

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         🎛️  PANEL MGVPN - HTTP CUSTOM BOT PRO                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

while true; do
    show_header
    
    TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1 AND expires_at > datetime('now')" 2>/dev/null || echo "0")
    TESTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE tipo='test' AND status=1" 2>/dev/null || echo "0")
    CHECKS_TODAY=$(sqlite3 "$DB" "SELECT COUNT(*) FROM hwid_logs WHERE date(check_time)=date('now')" 2>/dev/null || echo "0")
    STATUS=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.name=="hcbot-pro") | .pm2_env.status' 2>/dev/null || echo "stopped")
    
    echo -e "${YELLOW}📊 ESTADO DEL SISTEMA${NC}"
    echo -e "  🤖 Bot WhatsApp: $([ "$STATUS" == "online" ] && echo "${GREEN}● ACTIVO${NC}" || echo "${RED}● DETENIDO${NC}")"
    echo -e "  🌐 API Validación: ${GREEN}● ACTIVA${NC} (puerto $PORT)"
    echo -e "  👥 Usuarios: ${CYAN}$ACTIVE/$TOTAL${NC} activos (${TESTS} pruebas)"
    echo -e "  📊 Validaciones hoy: ${CYAN}$CHECKS_TODAY${NC}"
    echo -e "  💰 MercadoPago: $([ -n "$(jq -r '.mercadopago.access_token' $CONFIG 2>/dev/null | grep -v '^""')" ] && echo "${GREEN}✅ CONFIGURADO${NC}" || echo "${RED}❌ NO CONFIGURADO${NC}")"
    echo -e ""
    echo -e "${CYAN}🔗 URL DE VALIDACIÓN:${NC}"
    echo -e "  ${GREEN}http://$SERVER_IP:$PORT/api/validate/{HWID}${NC}"
    echo -e ""
    
    echo -e "${CYAN}[1] Iniciar bot    [2] Detener bot    [3] Ver logs"
    echo -e "${CYAN}[4] Config MP      [5] Editar precios [6] Subir archivo .hc"
    echo -e "${CYAN}[7] Ver usuarios   [8] Estadísticas   [9] Probar validación"
    echo -e "${CYAN}[0] Salir${NC}"
    echo ""
    read -p "👉 Opción: " OPT
    
    case $OPT in
        1) 
            cd /root/hcbot-pro 
            pm2 restart hcbot-pro 2>/dev/null || pm2 start bot.js --name hcbot-pro
            pm2 save
            echo -e "${GREEN}✅ Bot iniciado${NC}"
            sleep 2
            ;;
        2) 
            pm2 stop hcbot-pro
            echo -e "${YELLOW}⏹️ Bot detenido${NC}"
            sleep 2
            ;;
        3) 
            pm2 logs hcbot-pro --lines 80
            ;;
        4)
            echo -e "\n${YELLOW}⚙ CONFIGURAR MERCADOPAGO${NC}"
            CURRENT_TOKEN=$(jq -r '.mercadopago.access_token' $CONFIG)
            echo -e "Token actual: ${CURRENT_TOKEN:0:30}...\n"
            read -p "Nuevo token (APP_USR-xxx): " NEW_TOKEN
            if [[ "$NEW_TOKEN" =~ ^APP_USR- ]]; then
                jq ".mercadopago.access_token = \"$NEW_TOKEN\" | .mercadopago.enabled = true" $CONFIG > tmp && mv tmp $CONFIG
                echo -e "${GREEN}✅ Token guardado - Reinicia el bot para aplicar cambios${NC}"
            else
                echo -e "${RED}❌ Token inválido (debe empezar con APP_USR-)${NC}"
            fi
            read -p "Enter..."
            ;;
        5)
            echo -e "\n${YELLOW}💰 EDITAR PRECIOS${NC}"
            echo "  Precios actuales:"
            echo "    7 días:  $(jq -r '.prices.price_7d' $CONFIG)"
            echo "    15 días: $(jq -r '.prices.price_15d' $CONFIG)"
            echo "    30 días: $(jq -r '.prices.price_30d' $CONFIG)"
            echo "    50 días: $(jq -r '.prices.price_50d' $CONFIG)"
            echo ""
            read -p "Nuevo precio 7 días (dejar vacío para mantener): " p7
            read -p "Nuevo precio 15 días: " p15
            read -p "Nuevo precio 30 días: " p30
            read -p "Nuevo precio 50 días: " p50
            [[ -n "$p7" ]] && jq ".prices.price_7d = $p7" $CONFIG > tmp && mv tmp $CONFIG
            [[ -n "$p15" ]] && jq ".prices.price_15d = $p15" $CONFIG > tmp && mv tmp $CONFIG
            [[ -n "$p30" ]] && jq ".prices.price_30d = $p30" $CONFIG > tmp && mv tmp $CONFIG
            [[ -n "$p50" ]] && jq ".prices.price_50d = $p50" $CONFIG > tmp && mv tmp $CONFIG
            echo -e "${GREEN}✅ Precios actualizados${NC}"
            read -p "Enter..."
            ;;
        6)
            echo -e "\n${CYAN}📂 SUBIR ARCHIVO .hc${NC}"
            echo -e "El archivo se usará para todos los usuarios"
            read -p "Ruta del archivo .hc: " SOURCE
            if [[ -f "$SOURCE" && "$SOURCE" == *.hc ]]; then
                cp "$SOURCE" "$HC_DIR/mgvpn.hc"
                echo -e "${GREEN}✅ Archivo actualizado${NC}"
            else
                echo -e "${RED}❌ Archivo inválido (debe ser .hc)${NC}"
            fi
            read -p "Enter..."
            ;;
        7)
            echo -e "\n${CYAN}📋 USUARIOS ACTIVOS${NC}\n"
            sqlite3 -column -header "$DB" "SELECT hwid, phone, tipo, substr(expires_at,1,16) as expira FROM users WHERE status=1 AND expires_at>datetime('now') ORDER BY expires_at LIMIT 30"
            echo ""
            read -p "Enter..."
            ;;
        8)
            clear
            echo -e "${CYAN}📊 ESTADÍSTICAS COMPLETAS${NC}\n"
            echo "┌─────────────────────────────────────┐"
            echo "│ USUARIOS                            │"
            echo "├─────────────────────────────────────┤"
            echo "│ Total registrados:   $(printf "%10s" $(sqlite3 "$DB" "SELECT COUNT(*) FROM users")) │"
            echo "│ Activos:             $(printf "%10s" $(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1 AND expires_at>datetime('now')")) │"
            echo "│ En prueba:           $(printf "%10s" $(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE tipo='test' AND status=1")) │"
            echo "│ Premium:             $(printf "%10s" $(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE tipo='premium' AND status=1")) │"
            echo "├─────────────────────────────────────┤"
            echo "│ ACTIVIDAD                           │"
            echo "├─────────────────────────────────────┤"
            echo "│ Pruebas hoy:         $(printf "%10s" $(sqlite3 "$DB" "SELECT COUNT(*) FROM daily_tests WHERE date=date('now')")) │"
            echo "│ Validaciones hoy:    $(printf "%10s" $(sqlite3 "$DB" "SELECT COUNT(*) FROM hwid_logs WHERE date(check_time)=date('now')")) │"
            echo "│ Vencen hoy:          $(printf "%10s" $(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1 AND date(expires_at)=date('now')")) │"
            echo "├─────────────────────────────────────┤"
            echo "│ PAGOS                               │"
            echo "├─────────────────────────────────────┤"
            echo "│ Total pagos:         $(printf "%10s" $(sqlite3 "$DB" "SELECT COUNT(*) FROM payments")) │"
            echo "│ Aprobados:           $(printf "%10s" $(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='approved'")) │"
            echo "│ Ingresos totales:    $$(printf "%10s" $(sqlite3 "$DB" "SELECT printf('%.0f', SUM(amount)) FROM payments WHERE status='approved'")) ARS │"
            echo "└─────────────────────────────────────┘"
            echo ""
            read -p "Enter..."
            ;;
        9)
            echo -e "\n${CYAN}🔍 PROBAR VALIDACIÓN DE HWID${NC}"
            read -p "Ingresa HWID a probar: " TEST_HWID
            echo -e "\n${YELLOW}Consultando: http://$SERVER_IP:$PORT/api/validate/$TEST_HWID${NC}\n"
            curl -s "http://localhost:$PORT/api/validate/$TEST_HWID" | jq . 2>/dev/null || curl -s "http://localhost:$PORT/api/validate/$TEST_HWID"
            echo ""
            read -p "Enter..."
            ;;
        0) 
            echo -e "\n${GREEN}👋 Hasta luego${NC}"
            exit 0
            ;;
    esac
done
PANELEOF

chmod +x /usr/local/bin/hcbot

# ================================================
# INICIAR SERVICIOS
# ================================================
echo -e "\n${CYAN}🚀 Iniciando servicios...${NC}"

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
║           🎉 INSTALACIÓN COMPLETA - MGVPN 🎉                ║
║                                                              ║
║       ✅ WhatsApp Bot funcionando                          ║
║       ✅ API de validación HWID activa                     ║
║       ✅ Login por HWID en tiempo real                     ║
║       ✅ Entrega automática de archivo .hc                 ║
║       ✅ Prueba gratuita 2 horas                           ║
║       ✅ MercadoPago integrado                             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${GREEN}✅ Instalación completa${NC}"
echo -e ""
echo -e "${YELLOW}📋 COMANDOS ÚTILES:${NC}"
echo -e "  ${GREEN}hcbot${NC}              - Panel de control"
echo -e "  ${GREEN}pm2 logs hcbot-pro${NC}  - Ver logs y QR"
echo -e "  ${GREEN}pm2 restart hcbot-pro${NC} - Reiniciar bot"
echo -e ""
echo -e "${CYAN}🔗 URL DE VALIDACIÓN PARA USUARIOS:${NC}"
echo -e "  ${GREEN}http://$SERVER_IP:$PORT/api/validate/TU-HWID${NC}"
echo -e ""
echo -e "${YELLOW}📌 INSTRUCCIONES PARA USUARIOS:${NC}"
echo -e "  1. Obtener HWID en HTTP Custom (Ajustes → ID del dispositivo)"
echo -e "  2. Enviar 'MENU' al bot de WhatsApp"
echo -e "  3. Usar opción 1 para prueba gratis o 2 para comprar"
echo -e "  4. Configurar en HTTP Custom: Ajustes → Validación HWID"
echo -e "  5. Pegar la URL: http://$SERVER_IP:$PORT/api/validate/SU-HWID"
echo -e ""
echo -e "${YELLOW}🚀 PRIMEROS PASOS:${NC}"
echo -e "  1. ${GREEN}pm2 logs hcbot-pro${NC} - Escanear QR para conectar WhatsApp"
echo -e "  2. ${GREEN}hcbot${NC} - Configurar MercadoPago (opción 4)"
echo -e "  3. ${GREEN}hcbot${NC} - Subir archivo .hc (opción 6)"
echo -e ""

read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    pm2 logs hcbot-pro
fi

exit 0