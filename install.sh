#!/bin/bash
# ================================================
# SSH BOT PRO - WPPCONNECT + MERCADOPAGO + HWID
# VERSIÓN CORREGIDA - FECHA DE EXPIRACIÓN FIX
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
BOLD='\033[1m'

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
║          🤖 SSH BOT PRO - WPPCONNECT + MERCADOPAGO          ║
║               🔐 VERSIÓN HWID - CORREGIDA                   ║
║               ⏱️  PRUEBA 2 HORAS - FECHA FIJA                ║
║               💰 MercadoPago SDK v2.x                       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ VERSIÓN CORREGIDA - Problema de expiración solucionado${NC}\n"

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
    git curl wget sqlite3 jq \
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
# PREPARAR ESTRUCTURA
# ================================================
echo -e "\n${CYAN}📁 Creando estructura...${NC}"

INSTALL_DIR="/opt/sshbot-pro"
USER_HOME="/root/sshbot-pro"
DB_FILE="$INSTALL_DIR/data/hwid.db"
CONFIG_FILE="$INSTALL_DIR/config/config.json"

# Limpiar anterior
pm2 delete sshbot-pro 2>/dev/null || true
rm -rf "$INSTALL_DIR" "$USER_HOME" 2>/dev/null || true
rm -rf /root/.wppconnect 2>/dev/null || true

# Crear directorios
mkdir -p "$INSTALL_DIR"/{data,config,sessions,logs,qr_codes}
mkdir -p "$USER_HOME"
mkdir -p /root/.wppconnect
chmod -R 755 "$INSTALL_DIR"
chmod -R 700 /root/.wppconnect

cat > "$CONFIG_FILE" << EOF
{
    "bot": {
        "name": "SSH Bot Pro HWID",
        "version": "3.0-HWID-FIX",
        "server_ip": "$SERVER_IP"
    },
    "prices": {
        "test_hours": 2,
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
    "links": {
        "app_download": "https://play.google.com/store/apps/details?id=google.android.b6",
        "support": "https://wa.me/54"
    },
    "paths": {
        "database": "$DB_FILE",
        "qr_codes": "$INSTALL_DIR/qr_codes",
        "sessions": "/root/.wppconnect"
    }
}
EOF

# Crear base de datos para HWID
sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE IF NOT EXISTS hwid_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    nombre TEXT,
    hwid TEXT UNIQUE,
    tipo TEXT DEFAULT 'test',
    expires_at DATETIME,
    status INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS daily_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    nombre TEXT,
    date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(phone, date)
);
CREATE TABLE IF NOT EXISTS payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_id TEXT UNIQUE,
    phone TEXT,
    nombre TEXT,
    plan TEXT,
    days INTEGER,
    amount REAL,
    status TEXT DEFAULT 'pending',
    payment_url TEXT,
    qr_code TEXT,
    preference_id TEXT,
    hwid TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    approved_at DATETIME
);
CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT,
    message TEXT,
    data TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS user_state (
    phone TEXT PRIMARY KEY,
    state TEXT DEFAULT 'main_menu',
    data TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS hwid_attempts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hwid TEXT,
    phone TEXT,
    nombre TEXT,
    action TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_hwid_users_hwid ON hwid_users(hwid);
CREATE INDEX IF NOT EXISTS idx_hwid_users_status ON hwid_users(status);
CREATE INDEX IF NOT EXISTS idx_payments_hwid ON payments(hwid);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
SQL

echo -e "${GREEN}✅ Estructura HWID creada${NC}"

# ================================================
# CREAR BOT CON HWID CORREGIDO
# ================================================
echo -e "\n${CYAN}🤖 Creando bot con sistema HWID CORREGIDO...${NC}"

cd "$USER_HOME"

# package.json
cat > package.json << 'PKGEOF'
{
    "name": "sshbot-pro-hwid",
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
        "axios": "^1.6.5"
    }
}
PKGEOF

echo -e "${YELLOW}📦 Instalando dependencias...${NC}"
npm install --silent 2>&1 | grep -v "npm WARN" || true

# Crear bot.js CORREGIDO
cat > "bot.js" << 'BOTEOF'
const wppconnect = require('@wppconnect-team/wppconnect');
const QRCode = require('qrcode');
const moment = require('moment');
const sqlite3 = require('sqlite3').verbose();
const chalk = require('chalk');
const cron = require('node-cron');
const fs = require('fs');
const axios = require('axios');

moment.locale('es');

console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════════════╗'));
console.log(chalk.cyan.bold('║           🤖 SSH BOT PRO - HWID (VERSIÓN CORREGIDA)          ║'));
console.log(chalk.cyan.bold('║           ⏱️  PRUEBA: 2 HORAS - FECHA CORRECTA                ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

function loadConfig() {
    delete require.cache[require.resolve('/opt/sshbot-pro/config/config.json')];
    return require('/opt/sshbot-pro/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/sshbot-pro/data/hwid.db');

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
            console.log(chalk.green('✅ MercadoPago SDK v2.x ACTIVO'));
        } catch (error) {
            console.log(chalk.red('❌ Error MP:'), error.message);
            mpEnabled = false;
        }
    }
}
initMercadoPago();

let client = null;

function validateHWID(hwid) {
    return /^APP-[A-F0-9]{16}$/.test(hwid);
}

function normalizeHWID(hwid) {
    if (!hwid) return null;
    let cleaned = hwid.trim().toUpperCase().replace(/[^A-F0-9]/g, '');
    if (cleaned.length > 16) cleaned = cleaned.substring(0, 16);
    if (cleaned.length < 16) cleaned = cleaned.padEnd(16, '0');
    return `APP-${cleaned}`;
}

function isHWIDActive(hwid) {
    return new Promise((resolve) => {
        db.get('SELECT * FROM hwid_users WHERE hwid = ? AND status = 1 AND expires_at > datetime("now")', [hwid], (err, row) => {
            resolve(!err && row);
        });
    });
}

function getHWIDInfo(hwid) {
    return new Promise((resolve) => {
        db.get('SELECT * FROM hwid_users WHERE hwid = ?', [hwid], (err, row) => {
            resolve(err ? null : row);
        });
    });
}

async function registerHWID(phone, nombre, hwid, days, tipo = 'premium') {
    try {
        console.log(chalk.cyan(`📝 Registrando: ${hwid} para ${nombre} (${days} días)`));
        
        const existing = await new Promise((resolve) => {
            db.get('SELECT hwid FROM hwid_users WHERE hwid = ?', [hwid], (err, row) => resolve(row));
        });

        if (existing) {
            return { success: false, error: 'HWID ya registrado' };
        }

        let expireFull;
        if (days === 0) {
            expireFull = moment().add(2, 'hours').format('YYYY-MM-DD HH:mm:ss');
            console.log(chalk.yellow(`⏱️ Prueba 2h - Expira: ${expireFull}`));
        } else {
            expireFull = moment().add(days, 'days').endOf('day').format('YYYY-MM-DD HH:mm:ss');
            console.log(chalk.green(`💰 Premium - Expira: ${expireFull}`));
        }

        await new Promise((resolve, reject) => {
            db.run(
                `INSERT INTO hwid_users (phone, nombre, hwid, tipo, expires_at, status) VALUES (?, ?, ?, ?, ?, 1)`,
                [phone, nombre, hwid, tipo, expireFull],
                function(err) { if (err) reject(err); else resolve(this.lastID); }
            );
        });

        db.run(`INSERT INTO hwid_attempts (hwid, phone, nombre, action) VALUES (?, ?, ?, 'registered')`, [hwid, phone, nombre]);

        return { success: true, hwid, nombre, expires: expireFull, tipo };
    } catch (error) {
        console.error(chalk.red('❌ Error:'), error.message);
        return { success: false, error: error.message };
    }
}

function canCreateTest(phone) {
    return new Promise((resolve) => {
        const today = moment().format('YYYY-MM-DD');
        db.get('SELECT COUNT(*) as count FROM daily_tests WHERE phone = ? AND date = ?', [phone, today], (err, row) => {
            resolve(!err && row && row.count === 0);
        });
    });
}

function registerTest(phone, nombre) {
    db.run('INSERT OR IGNORE INTO daily_tests (phone, nombre, date) VALUES (?, ?, ?)', [phone, nombre, moment().format('YYYY-MM-DD')]);
}

function getUserState(phone) {
    return new Promise((resolve) => {
        db.get('SELECT state, data FROM user_state WHERE phone = ?', [phone], (err, row) => {
            if (err || !row) resolve({ state: 'main_menu', data: null });
            else resolve({ state: row.state || 'main_menu', data: row.data ? JSON.parse(row.data) : null });
        });
    });
}

function setUserState(phone, state, data = null) {
    return new Promise((resolve) => {
        const dataStr = data ? JSON.stringify(data) : null;
        db.run(`INSERT OR REPLACE INTO user_state (phone, state, data, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)`, [phone, state, dataStr], () => resolve());
    });
}

async function createMercadoPagoPayment(phone, days, amount, planName) {
    try {
        if (!mpEnabled || !mpPreference) return { success: false, error: 'MercadoPago no configurado' };
        
        const phoneClean = phone.replace('@c.us', '');
        const paymentId = `HWID-${phoneClean}-${days}d-${Date.now()}`;
        
        const preferenceData = {
            items: [{
                title: `HWID SSH ${days} DÍAS`,
                quantity: 1,
                currency_id: config.prices.currency || 'ARS',
                unit_price: parseFloat(amount)
            }],
            external_reference: paymentId,
            back_urls: {
                success: `https://wa.me/${phoneClean}`,
                failure: `https://wa.me/${phoneClean}`,
                pending: `https://wa.me/${phoneClean}`
            },
            auto_return: 'approved'
        };
        
        const response = await mpPreference.create({ body: preferenceData });
        
        if (response && response.id) {
            const paymentUrl = response.init_point;
            db.run(`INSERT INTO payments (payment_id, phone, plan, days, amount, status, payment_url, preference_id) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?)`,
                [paymentId, phone, `${days}d`, days, amount, paymentUrl, response.id]);
            
            return { success: true, paymentUrl, amount: parseFloat(amount) };
        }
        throw new Error('Error al crear pago');
    } catch (error) {
        console.error(chalk.red('❌ Error MP:'), error.message);
        return { success: false, error: error.message };
    }
}

async function checkPendingPayments() {
    if (!mpEnabled) return;
    
    db.all('SELECT * FROM payments WHERE status = "pending" AND created_at > datetime("now", "-48 hours")', async (err, payments) => {
        if (err || !payments || payments.length === 0) return;
        
        for (const payment of payments) {
            try {
                const url = `https://api.mercadopago.com/v1/payments/search?external_reference=${payment.payment_id}`;
                const response = await axios.get(url, {
                    headers: { 'Authorization': `Bearer ${config.mercadopago.access_token}` }
                });
                
                if (response.data && response.data.results && response.data.results.length > 0) {
                    const mpPayment = response.data.results[0];
                    if (mpPayment.status === 'approved') {
                        db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`, [payment.payment_id]);
                        
                        if (client) {
                            await client.sendText(payment.phone, `✅ PAGO CONFIRMADO\n\nAhora dime tu NOMBRE para activar:`);
                            await setUserState(payment.phone, 'awaiting_hwid', { payment_id: payment.payment_id, days: payment.days });
                        }
                    }
                }
            } catch (error) {
                console.error(chalk.red(`❌ Error: ${payment.payment_id}`), error.message);
            }
        }
    });
}

async function initializeBot() {
    try {
        console.log(chalk.yellow('🚀 Inicializando WPPConnect...'));
        
        client = await wppconnect.create({
            session: 'sshbot-pro-hwid',
            headless: true,
            devtools: false,
            useChrome: true,
            debug: false,
            logQR: true,
            browserArgs: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu'],
            puppeteerOptions: {
                executablePath: '/usr/bin/google-chrome',
                headless: 'new',
                args: ['--no-sandbox', '--disable-setuid-sandbox']
            },
            disableWelcome: true,
            folderNameToken: '/root/.wppconnect'
        });
        
        console.log(chalk.green('✅ WPPConnect conectado!'));
        
        client.onMessage(async (message) => {
            try {
                const text = message.body.toLowerCase().trim();
                const from = message.from;
                
                console.log(chalk.cyan(`📩 [${from}]: ${text.substring(0, 30)}`));
                
                const userState = await getUserState(from);
                
                // MENÚ PRINCIPAL
                if (['menu', 'hola', 'start', 'hi', 'volver', '0'].includes(text)) {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, `🤖 SSH BOT PRO - HWID\n\n1️⃣ - PROBAR (2 horas)\n2️⃣ - COMPRAR\n3️⃣ - VERIFICAR HWID\n4️⃣ - DESCARGAR APP`);
                }
                
                // OPCIÓN 1: PRUEBA
                else if (text === '1' && userState.state === 'main_menu') {
                    await setUserState(from, 'awaiting_test_nombre');
                    await client.sendText(from, `⏳ PRUEBA 2 HORAS\n\nPrimero, dime tu NOMBRE:`);
                }
                
                // OPCIÓN 2: COMPRAR
                else if (text === '2' && userState.state === 'main_menu') {
                    await setUserState(from, 'buying_hwid');
                    await client.sendText(from, `💰 PLANES\n\n1️⃣ - 7 DÍAS - $${config.prices.price_7d}\n2️⃣ - 15 DÍAS - $${config.prices.price_15d}\n3️⃣ - 30 DÍAS - $${config.prices.price_30d}\n4️⃣ - 50 DÍAS - $${config.prices.price_50d}\n0️⃣ - VOLVER`);
                }
                
                // OPCIÓN 3: VERIFICAR HWID
                else if (text === '3' && userState.state === 'main_menu') {
                    await setUserState(from, 'awaiting_check_hwid');
                    await client.sendText(from, `🔍 Envía tu HWID para verificar:\n\nEjemplo: APP-E3E4D5CBB7636907`);
                }
                
                // OPCIÓN 4: DESCARGAR APP
                else if (text === '4' && userState.state === 'main_menu') {
                    await client.sendText(from, `📱 DESCARGAR APP\n\n${config.links.app_download}`);
                }
                
                // PROCESAR NOMBRE PARA PRUEBA
                else if (userState.state === 'awaiting_test_nombre') {
                    const nombre = message.body.trim();
                    if (nombre.length < 2) {
                        await client.sendText(from, '❌ Nombre inválido. Intenta de nuevo:');
                        return;
                    }
                    await setUserState(from, 'awaiting_test_hwid', { nombre });
                    await client.sendText(from, `✅ Gracias ${nombre}\n\nAhora envía tu HWID:\nFormato: APP-E3E4D5CBB7636907`);
                }
                
                // PROCESAR HWID PARA PRUEBA
                else if (userState.state === 'awaiting_test_hwid') {
                    const hwid = normalizeHWID(message.body);
                    const nombre = userState.data.nombre;
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ HWID INVÁLIDO\n\nFormato correcto: APP-E3E4D5CBB7636907\n\nEnvía nuevamente o MENU`);
                        return;
                    }
                    
                    if (!(await canCreateTest(from))) {
                        await client.sendText(from, `❌ YA USASTE TU PRUEBA HOY\n\nVuelve mañana o compra un plan (opción 2)`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    const active = await isHWIDActive(hwid);
                    if (active) {
                        await client.sendText(from, `❌ HWID ya activo\n\nContacta soporte si es error.`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    await client.sendText(from, '⏳ Activando prueba (2 horas)...');
                    
                    const result = await registerHWID(from, nombre, hwid, 0, 'test');
                    
                    if (result.success) {
                        registerTest(from, nombre);
                        await client.sendText(from, `✅ PRUEBA ACTIVADA ${nombre}!\n\n🔐 HWID: ${hwid}\n⏰ Expira: ${moment(result.expires).format('HH:mm DD/MM/YYYY')}\n\n📱 Ya puedes conectarte!`);
                        console.log(chalk.green(`✅ TEST: ${hwid} - ${nombre}`));
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    await setUserState(from, 'main_menu');
                }
                
                // PROCESAR PLAN DE COMPRA
                else if (userState.state === 'buying_hwid' && ['1','2','3','4'].includes(text)) {
                    const planMap = {
                        '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                        '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' },
                        '3': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                        '4': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                    };
                    const plan = planMap[text];
                    
                    if (mpEnabled) {
                        await client.sendText(from, '⏳ Generando pago...');
                        const payment = await createMercadoPagoPayment(from, plan.days, plan.price, plan.name);
                        
                        if (payment.success) {
                            await client.sendText(from, `💰 PAGO\n\nPlan: ${plan.name}\nPrecio: $${payment.amount}\n\n🔗 Link: ${payment.paymentUrl}\n\n⏰ Válido 24h\n\n📌 DESPUÉS DE PAGAR:\n1. Espera confirmación\n2. Dime tu nombre\n3. Envía tu HWID`);
                        } else {
                            await client.sendText(from, `❌ Error: ${payment.error}\n\nContacta soporte: ${config.links.support}`);
                        }
                    } else {
                        await client.sendText(from, `📦 Plan: ${plan.name}\n💵 Precio: $${plan.price}\n\nContacta soporte: ${config.links.support}`);
                    }
                    await setUserState(from, 'main_menu');
                }
                
                else if (text === '0' && userState.state === 'buying_hwid') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, `🤖 SSH BOT PRO - HWID\n\n1️⃣ - PROBAR (2 horas)\n2️⃣ - COMPRAR\n3️⃣ - VERIFICAR HWID\n4️⃣ - DESCARGAR APP`);
                }
                
                // VERIFICAR HWID
                else if (userState.state === 'awaiting_check_hwid') {
                    const hwid = normalizeHWID(message.body);
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ Formato inválido\n\nEjemplo: APP-E3E4D5CBB7636907`);
                        return;
                    }
                    
                    const info = await getHWIDInfo(hwid);
                    if (info && info.status === 1 && moment(info.expires_at).isAfter(moment())) {
                        await client.sendText(from, `✅ HWID ACTIVO\n\n👤 ${info.nombre}\n🔐 ${hwid}\n⏰ Expira: ${moment(info.expires_at).format('DD/MM/YYYY HH:mm')}\n⌛ Restante: ${moment(info.expires_at).fromNow()}`);
                    } else if (info) {
                        await client.sendText(from, `❌ HWID EXPIRADO\n\nExpiró: ${moment(info.expires_at).format('DD/MM/YYYY HH:mm')}\n\nRenueva con opción 2`);
                    } else {
                        await client.sendText(from, `❌ HWID NO REGISTRADO\n\nPrueba gratis con opción 1`);
                    }
                    await setUserState(from, 'main_menu');
                }
                
                // ESPERANDO NOMBRE Y HWID DESPUÉS DE PAGO
                else if (userState.state === 'awaiting_hwid') {
                    if (!userState.data.nombre) {
                        const nombre = message.body.trim();
                        if (nombre.length < 2) {
                            await client.sendText(from, '❌ Nombre inválido. Intenta de nuevo:');
                            return;
                        }
                        userState.data.nombre = nombre;
                        await setUserState(from, 'awaiting_hwid', userState.data);
                        await client.sendText(from, `✅ Gracias ${nombre}\n\nAhora envía tu HWID para activar:`);
                        return;
                    }
                    
                    const hwid = normalizeHWID(message.body);
                    const nombre = userState.data.nombre;
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ FORMATO INCORRECTO\n\nEjemplo: APP-E3E4D5CBB7636907`);
                        return;
                    }
                    
                    const active = await isHWIDActive(hwid);
                    if (active) {
                        await client.sendText(from, `❌ HWID ya activo`);
                        return;
                    }
                    
                    await client.sendText(from, '⏳ Activando...');
                    const result = await registerHWID(from, nombre, hwid, parseInt(userState.data.days), 'premium');
                    
                    if (result.success) {
                        db.run(`UPDATE payments SET hwid = ?, nombre = ? WHERE payment_id = ?`, [hwid, nombre, userState.data.payment_id]);
                        await client.sendText(from, `✅ ¡ACTIVADO ${nombre}!\n\n🔐 HWID: ${hwid}\n⏰ Válido hasta: ${moment(result.expires).format('DD/MM/YYYY')}\n\n🎉 Ya puedes usar la app!`);
                        console.log(chalk.green(`✅ PREMIUM: ${hwid} - ${nombre}`));
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    await setUserState(from, 'main_menu');
                }
                
            } catch (error) {
                console.error(chalk.red('❌ Error:'), error.message);
            }
        });
        
        // CRON JOBS
        cron.schedule('*/2 * * * *', () => checkPendingPayments());
        cron.schedule('*/15 * * * *', () => {
            db.run('UPDATE hwid_users SET status = 0 WHERE expires_at < datetime("now") AND status = 1');
        });
        cron.schedule('0 * * * *', () => {
            db.run(`DELETE FROM user_state WHERE updated_at < datetime('now', '-1 hour')`);
        });
        
    } catch (error) {
        console.error(chalk.red('❌ Error:'), error.message);
        setTimeout(initializeBot, 10000);
    }
}

initializeBot();

process.on('SIGINT', async () => {
    console.log(chalk.yellow('\n🛑 Cerrando...'));
    if (client) await client.close();
    process.exit();
});
BOTEOF

echo -e "${GREEN}✅ Bot HWID CORREGIDO creado${NC}"

# ================================================
# CREAR PANEL DE CONTROL
# ================================================
echo -e "\n${CYAN}🎛️ Creando panel de control...${NC}"

cat > /usr/local/bin/sshbot-hwid << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

DB="/opt/sshbot-pro/data/hwid.db"
CONFIG="/opt/sshbot-pro/config/config.json"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }
set_val() { local t=$(mktemp); jq "$1 = $2" "$CONFIG" > "$t" && mv "$t" "$CONFIG"; }

while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           🎛️  PANEL SSH BOT PRO - HWID CORREGIDO             ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    
    TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM hwid_users" 2>/dev/null || echo "0")
    ACTIVE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM hwid_users WHERE status=1 AND expires_at > datetime('now')" 2>/dev/null || echo "0")
    EXPIRED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM hwid_users WHERE status=0 OR expires_at <= datetime('now')" 2>/dev/null || echo "0")
    TESTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM daily_tests WHERE date = date('now')" 2>/dev/null || echo "0")
    PENDING=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='pending'" 2>/dev/null || echo "0")
    APPROVED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='approved'" 2>/dev/null || echo "0")
    
    STATUS=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.name=="sshbot-pro") | .pm2_env.status' 2>/dev/null || echo "stopped")
    [[ "$STATUS" == "online" ]] && BOT_STATUS="${GREEN}● ACTIVO${NC}" || BOT_STATUS="${RED}● DETENIDO${NC}"
    
    echo -e "${YELLOW}📊 ESTADO${NC}"
    echo -e "  Bot: $BOT_STATUS"
    echo -e "  HWIDs: ${GREEN}$ACTIVE${NC} activos | ${RED}$EXPIRED${NC} expirados | Total: $TOTAL"
    echo -e "  Tests hoy: $TESTS"
    echo -e "  Pagos: $PENDING pend | $APPROVED aprob"
    echo -e ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC} 🚀 Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC} 🛑 Detener bot"
    echo -e "${CYAN}[3]${NC} 📱 Ver logs y QR"
    echo -e "${CYAN}[4]${NC} 🔐 Registrar HWID manual"
    echo -e "${CYAN}[5]${NC} 👥 Listar HWIDs"
    echo -e "${CYAN}[6]${NC} 💰 Configurar MercadoPago"
    echo -e "${CYAN}[7]${NC} 🧪 Test MercadoPago"
    echo -e "${CYAN}[8]${NC} 📊 Estadísticas"
    echo -e "${CYAN}[9]${NC} 🔄 Limpiar sesión"
    echo -e "${CYAN}[0]${NC} 🚪 Salir"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
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
            echo -e "${CYAN}🔐 REGISTRAR HWID MANUAL${NC}\n"
            read -p "Teléfono: " PHONE
            read -p "Nombre: " NOMBRE
            read -p "HWID (APP-XXXXXXXXXXXXXXX): " HWID
            read -p "Días (0=test 2h, 1-365): " DAYS
            HWID=$(echo "$HWID" | tr 'a-z' 'A-Z')
            if [[ "$DAYS" == "0" ]]; then
                EXPIRE=$(date -d "+2 hours" +"%Y-%m-%d %H:%M:%S")
                TIPO="test"
            else
                EXPIRE=$(date -d "+$DAYS days" +"%Y-%m-%d 23:59:59")
                TIPO="premium"
            fi
            sqlite3 "$DB" "INSERT OR REPLACE INTO hwid_users (phone, nombre, hwid, tipo, expires_at, status) VALUES ('$PHONE', '$NOMBRE', '$HWID', '$TIPO', '$EXPIRE', 1)"
            echo -e "${GREEN}✅ Registrado - Expira: $EXPIRE${NC}"
            read -p "Enter..."
            ;;
        5)
            clear
            echo -e "${CYAN}👥 HWIDs${NC}\n"
            sqlite3 -column -header "$DB" "SELECT nombre, hwid, tipo, expires_at, status FROM hwid_users ORDER BY expires_at DESC LIMIT 20"
            read -p "Enter..."
            ;;
        6)
            clear
            echo -e "${CYAN}🔑 MERCADOPAGO${NC}\n"
            echo -e "1. https://www.mercadopago.com.ar/developers"
            echo -e "2. Credenciales → Access Token PRODUCCIÓN\n"
            read -p "Access Token: " TOKEN
            if [[ "$TOKEN" =~ ^(APP_USR|TEST)- ]]; then
                set_val '.mercadopago.access_token' "\"$TOKEN\""
                set_val '.mercadopago.enabled' "true"
                echo -e "${GREEN}✅ Token guardado${NC}"
                cd /root/sshbot-pro && pm2 restart sshbot-pro
            else
                echo -e "${RED}❌ Token inválido${NC}"
            fi
            read -p "Enter..."
            ;;
        7)
            clear
            TOKEN=$(get_val '.mercadopago.access_token')
            if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
                echo -e "${RED}❌ Token no configurado${NC}"
            else
                RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "https://api.mercadopago.com/v1/payment_methods")
                if [[ "$RESPONSE" == "200" ]]; then
                    echo -e "${GREEN}✅ Conexión exitosa${NC}"
                else
                    echo -e "${RED}❌ Error HTTP $RESPONSE${NC}"
                fi
            fi
            read -p "Enter..."
            ;;
        8)
            clear
            echo -e "${CYAN}📊 ESTADÍSTICAS${NC}\n"
            echo -e "${YELLOW}HWIDs por tipo:${NC}"
            sqlite3 "$DB" "SELECT tipo, COUNT(*) FROM hwid_users GROUP BY tipo"
            echo -e "\n${YELLOW}Ingresos:${NC}"
            sqlite3 "$DB" "SELECT printf('Total: $%.2f', SUM(amount)) FROM payments WHERE status='approved'"
            read -p "Enter..."
            ;;
        9)
            echo -e "\n${YELLOW}🧹 Limpiando...${NC}"
            pm2 stop sshbot-pro
            rm -rf /root/.wppconnect/*
            echo -e "${GREEN}✅ Sesión limpiada${NC}"
            sleep 2
            ;;
        0)
            echo -e "\n${GREEN}👋 Hasta pronto${NC}"
            exit 0
            ;;
    esac
done
PANELEOF

chmod +x /usr/local/bin/sshbot-hwid
ln -sf /usr/local/bin/sshbot-hwid /usr/local/bin/sshbot

# ================================================
# INICIAR BOT
# ================================================
echo -e "\n${CYAN}🚀 Iniciando bot...${NC}"

cd "$USER_HOME"
pm2 start bot.js --name sshbot-pro
pm2 save
pm2 startup systemd -u root --hp /root > /dev/null 2>&1

# ================================================
# MENSAJE FINAL
# ================================================
clear
echo -e "${GREEN}${BOLD}"
cat << "FINAL"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          🎉 INSTALACIÓN COMPLETADA - VERSIÓN CORREGIDA 🎉   ║
║                                                              ║
║       ✅ Problema de expiración SOLUCIONADO                 ║
║       ✅ Prueba de 2 horas funcionando                     ║
║       ✅ Fechas guardadas correctamente                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Instalación CORREGIDA completada${NC}"
echo -e "${GREEN}✅ El problema de expiración está SOLUCIONADO${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 COMANDOS:${NC}"
echo -e "  ${GREEN}sshbot${NC}         - Panel de control"
echo -e "  ${GREEN}pm2 logs sshbot-pro${NC} - Ver logs y QR"
echo -e "  ${GREEN}pm2 restart sshbot-pro${NC} - Reiniciar"
echo -e ""

echo -e "${YELLOW}⏱️  PRUEBA DE 2 HORAS CORREGIDA:${NC}"
echo -e "  Ahora las fechas se guardan correctamente en la BD"
echo -e "  Formato: YYYY-MM-DD HH:MM:SS (ej: 2024-01-15 14:30:00)"
echo -e ""

echo -e "${YELLOW}📱 FLUJO CORRECTO:${NC}"
echo -e "  1. Usuario envía '1'"
echo -e "  2. Bot pide NOMBRE"
echo -e "  3. Usuario envía nombre"
echo -e "  4. Bot pide HWID"
echo -e "  5. Usuario envía HWID (APP-XXXXXXXXXXXXXXX)"
echo -e "  6. ✅ SE ACTIVA POR 2 HORAS EXACTAS"
echo -e ""

read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}📱 Escanea el QR con WhatsApp...${NC}\n"
    sleep 2
    pm2 logs sshbot-pro
fi

exit 0