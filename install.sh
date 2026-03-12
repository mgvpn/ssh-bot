#!/bin/bash
# ================================================
# SSH BOT PRO - WPPCONNECT + MERCADOPAGO + HWID
# VERSIÓN CORREGIDA - BD ÚNICA (NO DA EXPIRADO)
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
║          🤖 SSH BOT PRO - VERSIÓN CORREGIDA                ║
║               🔐 BD ÚNICA - NO DA EXPIRADO                 ║
║               📱 HWID + MERCADOPAGO                        ║
║               💰 Pago automático con QR                    ║
║               ⏰ NOTIFICACIONES DE VENCIMIENTO             ║
║               ✅ PRUEBA 2 HORAS                            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CARACTERÍSTICAS PRINCIPALES:${NC}"
echo -e "  🔐 ${CYAN}Sistema HWID${NC} - Sin usuario/contraseña"
echo -e "  📱 ${CYAN}WPPConnect${NC} - API WhatsApp funcionando"
echo -e "  💰 ${GREEN}MercadoPago SDK v2.x${NC} - Integrado completo"
echo -e "  💳 ${YELLOW}Pago automático${NC} - QR + Enlace"
echo -e "  📝 ${PURPLE}Flujo mejorado${NC} - Primero nombre, luego HWID"
echo -e "  🎛️  ${PURPLE}Panel completo${NC} - Control total"
echo -e "  📊 ${BLUE}Estadísticas${NC} - Ventas, HWIDs, ingresos"
echo -e "  ⚡ ${GREEN}Auto-verificación${NC} - Pagos c/2 min"
echo -e "  ⏱️  ${YELLOW}PRUEBA 2 HORAS${NC} - Duración correcta"
echo -e "  ⏰ ${CYAN}NOTIFICACIONES${NC} - Avisos automáticos"
echo -e "  ✅ ${GREEN}BD ÚNICA${NC} - NO DA ERROR EXPIRADO"
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
# PREPARAR ESTRUCTURA - CON BD ÚNICA
# ================================================
echo -e "\n${CYAN}📁 Creando estructura con BD ÚNICA...${NC}"

INSTALL_DIR="/opt/sshbot-pro"
USER_HOME="/root/sshbot-pro"
DB_FILE="$INSTALL_DIR/data/bot.db"  # ← ¡BD ÚNICA! (CORREGIDO)
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
        "version": "3.0-HWID-CORREGIDO",
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
        "app_download": "https://www.mediafire.com/file/18tnc70qr2771lu/MGVPN.apk/file",
        "support": "https://wa.me/543435071016"
    },
    "paths": {
        "database": "$DB_FILE",
        "qr_codes": "$INSTALL_DIR/qr_codes",
        "sessions": "/root/.wppconnect"
    }
}
EOF

# ================================================
# CREAR BASE DE DATOS ÚNICA (TODAS LAS TABLAS)
# ================================================
echo -e "${CYAN}🗄️  Creando BD ÚNICA con todas las tablas...${NC}"

sqlite3 "$DB_FILE" << 'SQL'
-- Tabla principal para HWID
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

-- Tabla para SSH (por si luego se necesita)
CREATE TABLE IF NOT EXISTS ssh_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    username TEXT UNIQUE,
    password TEXT DEFAULT 'mgvpn247',
    tipo TEXT DEFAULT 'test',
    expires_at DATETIME,
    status INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de tests diarios
CREATE TABLE IF NOT EXISTS daily_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    nombre TEXT,
    date DATE,
    system_type TEXT DEFAULT 'hwid',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(phone, date)
);

-- Tabla de pagos (con todos los campos necesarios)
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
    system_type TEXT DEFAULT 'hwid',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    approved_at DATETIME
);

-- Tabla de logs
CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT,
    message TEXT,
    data TEXT,
    system_type TEXT DEFAULT 'hwid',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de estados de usuario
CREATE TABLE IF NOT EXISTS user_state (
    phone TEXT PRIMARY KEY,
    state TEXT DEFAULT 'main_menu',
    data TEXT,
    system_type TEXT DEFAULT 'hwid',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de intentos de HWID
CREATE TABLE IF NOT EXISTS hwid_attempts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hwid TEXT,
    phone TEXT,
    nombre TEXT,
    action TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Índices para búsquedas rápidas
CREATE INDEX IF NOT EXISTS idx_hwid_users_hwid ON hwid_users(hwid);
CREATE INDEX IF NOT EXISTS idx_hwid_users_status ON hwid_users(status);
CREATE INDEX IF NOT EXISTS idx_hwid_users_phone ON hwid_users(phone);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_hwid ON payments(hwid);
CREATE INDEX IF NOT EXISTS idx_payments_phone ON payments(phone);
CREATE INDEX IF NOT EXISTS idx_daily_tests_phone ON daily_tests(phone, date);
SQL

echo -e "${GREEN}✅ BD ÚNICA creada en: ${CYAN}$DB_FILE${NC}"

# ================================================
# CREAR BOT CON HWID (BD ÚNICA - CORREGIDO)
# ================================================
echo -e "\n${CYAN}🤖 Creando bot con sistema HWID (BD ÚNICA - NO DA EXPIRADO)...${NC}"

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

# ================================================
# CREAR BOT.JS CON BD ÚNICA - ¡CORREGIDO!
# ================================================
echo -e "${YELLOW}📝 Creando bot.js con BD ÚNICA (NO DA EXPIRADO)...${NC}"

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

const execPromise = util.promisify(exec);
moment.locale('es');

console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════════════╗'));
console.log(chalk.cyan.bold('║           🤖 SSH BOT PRO - HWID CORREGIDO                   ║'));
console.log(chalk.cyan.bold('║           ✅ BD ÚNICA - NO DA EXPIRADO                       ║'));
console.log(chalk.cyan.bold('║           ⏱️  PRUEBA: 2 HORAS                                ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

// Cargar configuración
function loadConfig() {
    delete require.cache[require.resolve('/opt/sshbot-pro/config/config.json')];
    return require('/opt/sshbot-pro/config/config.json');
}

let config = loadConfig();

// ================================================
// ✅ BD ÚNICA - MISMA CONEXIÓN PARA TODO
// ================================================
const db = new sqlite3.Database('/opt/sshbot-pro/data/bot.db');  // ← ¡BD ÚNICA!

console.log(chalk.green('✅ Conectado a BD ÚNICA: /opt/sshbot-pro/data/bot.db'));

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

let client = null;

// ✅ FUNCIONES PARA HWID - CORREGIDAS (BUSCAN EN BD ÚNICA)
function validateHWID(hwid) {
    const hwidRegex = /^APP-[A-F0-9]{16}$/;
    return hwidRegex.test(hwid);
}

function normalizeHWID(hwid) {
    hwid = hwid.trim().toUpperCase();
    if (!hwid.startsWith('APP-')) {
        hwid = 'APP-' + hwid.replace(/[^A-F0-9]/g, '');
    }
    return hwid;
}

// ✅ ¡CORREGIDO! - Busca en la MISMA BD
function isHWIDActive(hwid) {
    return new Promise((resolve) => {
        db.get('SELECT * FROM hwid_users WHERE hwid = ? AND status = 1 AND expires_at > datetime("now")', 
            [hwid], (err, row) => {
            if (err) {
                console.error(chalk.red('❌ Error buscando HWID:'), err.message);
                resolve(false);
            } else {
                resolve(!!row);
            }
        });
    });
}

// ✅ ¡CORREGIDO! - Obtiene info completa
function getHWIDInfo(hwid) {
    return new Promise((resolve) => {
        db.get('SELECT * FROM hwid_users WHERE hwid = ?', [hwid], (err, row) => {
            if (err) {
                console.error(chalk.red('❌ Error obteniendo HWID:'), err.message);
                resolve(null);
            } else {
                resolve(row || null);
            }
        });
    });
}

// ✅ Registrar HWID en BD ÚNICA
async function registerHWID(phone, nombre, hwid, days, tipo = 'premium') {
    try {
        // Verificar si HWID ya existe
        const existing = await new Promise((resolve) => {
            db.get('SELECT hwid FROM hwid_users WHERE hwid = ?', [hwid], (err, row) => {
                resolve(row);
            });
        });

        if (existing) {
            return { success: false, error: 'HWID ya registrado' };
        }

        let expireFull;
        if (days === 0) {
            // Test - 2 horas
            expireFull = moment().add(2, 'hours').format('YYYY-MM-DD HH:mm:ss');
            console.log(chalk.cyan(`⏱️  Prueba 2 horas - Expira: ${expireFull}`));
        } else {
            // Premium
            expireFull = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
        }

        // Registrar en BD ÚNICA
        await new Promise((resolve, reject) => {
            db.run(
                `INSERT INTO hwid_users (phone, nombre, hwid, tipo, expires_at, status) VALUES (?, ?, ?, ?, ?, 1)`,
                [phone, nombre, hwid, tipo, expireFull],
                function(err) {
                    if (err) reject(err);
                    else resolve(this.lastID);
                }
            );
        });

        // Registrar intento
        db.run(`INSERT INTO hwid_attempts (hwid, phone, nombre, action) VALUES (?, ?, ?, 'registered')`, 
            [hwid, phone, nombre]);

        return { 
            success: true, 
            hwid,
            nombre,
            expires: expireFull,
            tipo
        };

    } catch (error) {
        console.error(chalk.red('❌ Error registrando HWID:'), error.message);
        return { success: false, error: error.message };
    }
}

function canCreateTest(phone) {
    return new Promise((resolve) => {
        const today = moment().format('YYYY-MM-DD');
        db.get('SELECT COUNT(*) as count FROM daily_tests WHERE phone = ? AND date = ?', 
            [phone, today], (err, row) => {
            if (err) {
                console.error(chalk.red('❌ Error verificando test:'), err.message);
                resolve(false);
            } else {
                resolve(row && row.count === 0);
            }
        });
    });
}

function registerTest(phone, nombre) {
    db.run('INSERT OR IGNORE INTO daily_tests (phone, nombre, date) VALUES (?, ?, ?)', 
        [phone, nombre, moment().format('YYYY-MM-DD')]);
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

// ✅ MERCADOPAGO - CREAR PAGO
async function createMercadoPagoPayment(phone, days, amount, planName) {
    try {
        if (!mpEnabled || !mpPreference) {
            return { success: false, error: 'MercadoPago no configurado' };
        }
        
        const phoneClean = phone.replace('@c.us', '');
        const paymentId = `HWID-${phoneClean}-${days}d-${Date.now()}`;
        
        console.log(chalk.cyan(`🔄 Creando pago MP: ${paymentId}`));
        
        const expirationDate = moment().add(24, 'hours');
        const isoDate = expirationDate.toISOString();
        
        const preferenceData = {
            items: [{
                title: `HWID SSH PREMIUM ${days} DÍAS`,
                description: `Activación HWID SSH por ${days} días`,
                quantity: 1,
                currency_id: config.prices.currency || 'ARS',
                unit_price: parseFloat(amount)
            }],
            external_reference: paymentId,
            expires: true,
            expiration_date_from: moment().toISOString(),
            expiration_date_to: isoDate,
            back_urls: {
                success: `https://wa.me/${phoneClean}?text=Ya%20pague%20hwid`,
                failure: `https://wa.me/${phoneClean}?text=Pago%20fallido`,
                pending: `https://wa.me/${phoneClean}?text=Pago%20pendiente`
            },
            auto_return: 'approved',
            statement_descriptor: 'HWID SSH'
        };
        
        const response = await mpPreference.create({ body: preferenceData });
        
        if (response && response.id) {
            const paymentUrl = response.init_point;
            const qrPath = `${config.paths.qr_codes}/${paymentId}.png`;
            
            await QRCode.toFile(qrPath, paymentUrl, { 
                width: 400,
                margin: 2
            });
            
            db.run(
                `INSERT INTO payments (payment_id, phone, plan, days, amount, status, payment_url, qr_code, preference_id) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
                [paymentId, phone, `${days}d`, days, amount, paymentUrl, qrPath, response.id]
            );
            
            return { 
                success: true, 
                paymentId, 
                paymentUrl, 
                qrPath,
                amount: parseFloat(amount)
            };
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
    
    db.all('SELECT * FROM payments WHERE status = "pending" AND created_at > datetime("now", "-48 hours")', 
        async (err, payments) => {
        if (err || !payments || payments.length === 0) return;
        
        console.log(chalk.yellow(`🔍 Verificando ${payments.length} pagos...`));
        
        for (const payment of payments) {
            try {
                const url = `https://api.mercadopago.com/v1/payments/search?external_reference=${payment.payment_id}`;
                const response = await axios.get(url, {
                    headers: { 
                        'Authorization': `Bearer ${config.mercadopago.access_token}`
                    },
                    timeout: 15000
                });
                
                if (response.data && response.data.results && response.data.results.length > 0) {
                    const mpPayment = response.data.results[0];
                    
                    console.log(chalk.cyan(`📋 Pago ${payment.payment_id}: ${mpPayment.status}`));
                    
                    if (mpPayment.status === 'approved') {
                        console.log(chalk.green(`✅ PAGO APROBADO: ${payment.payment_id}`));
                        
                        db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`, 
                            [payment.payment_id]);
                        
                        // Enviar mensaje pidiendo NOMBRE primero
                        const message = `✅ PAGO CONFIRMADO

🎉 Tu pago ha sido aprobado

📝 PRIMERO, ESCRIBE TU NOMBRE:
Para continuar con la activación, dime tu nombre

⏳ Tienes 30 minutos para completar el proceso`;
                        
                        if (client) {
                            await client.sendText(payment.phone, message);
                            await setUserState(payment.phone, 'awaiting_hwid', { 
                                payment_id: payment.payment_id,
                                days: payment.days,
                                plan: payment.plan
                            });
                        }
                    }
                }
            } catch (error) {
                console.error(chalk.red(`❌ Error verificando ${payment.payment_id}:`), error.message);
            }
        }
    });
}

// ✅ NOTIFICACIONES DE VENCIMIENTO
async function checkExpiringHWIDs() {
    try {
        const expiringSoon = await new Promise((resolve, reject) => {
            db.all(`
                SELECT * FROM hwid_users 
                WHERE status = 1 
                AND expires_at > datetime('now') 
                AND expires_at < datetime('now', '+1 day')
                AND tipo = 'premium'
            `, (err, rows) => {
                if (err) reject(err);
                else resolve(rows || []);
            });
        });

        for (const hwid of expiringSoon) {
            const hoursLeft = moment(hwid.expires_at).diff(moment(), 'hours');
            const message = `⏰ RECORDATORIO DE VENCIMIENTO

Hola ${hwid.nombre}, tu acceso expirará en aproximadamente ${hoursLeft} horas.

🔐 HWID: ${hwid.hwid}
⏰ Vence: ${moment(hwid.expires_at).format('DD/MM/YYYY HH:mm')}

💰 Para renovar, envía 2 y elige tu plan.`;
            
            if (client) {
                await client.sendText(hwid.phone, message);
                console.log(chalk.yellow(`📨 Notificación a ${hwid.nombre}`));
            }
        }

        const expired = await new Promise((resolve, reject) => {
            db.all(`
                SELECT * FROM hwid_users 
                WHERE status = 0 
                AND expires_at > datetime('now', '-1 day')
                AND expires_at < datetime('now')
                AND tipo = 'premium'
            `, (err, rows) => {
                if (err) reject(err);
                else resolve(rows || []);
            });
        });

        for (const hwid of expired) {
            const message = `⏰ SERVICIO EXPIRADO

Hola ${hwid.nombre}, tu acceso ha expirado.

🔐 HWID: ${hwid.hwid}
⏰ Expiró: ${moment(hwid.expires_at).format('DD/MM/YYYY HH:mm')}

💰 Renueva enviando 2`;
            
            if (client) {
                await client.sendText(hwid.phone, message);
            }
        }

    } catch (error) {
        console.error(chalk.red('❌ Error en notificaciones:'), error.message);
    }
}

// Inicializar WPPConnect
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
            browserWS: '',
            browserArgs: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--no-first-run',
                '--no-zygote',
                '--disable-gpu',
                '--window-size=1920,1080'
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
        
        client.onStateChange((state) => {
            console.log(chalk.cyan(`📱 Estado: ${state}`));
        });
        
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
                    
                    await client.sendText(from, `🤖 BOT MGVPN - HWID

Elija una opción:

 1️⃣ - PROBAR (2 horas gratis)
 2️⃣ - COMPRAR ACCESO
 3️⃣ - VERIFICAR MI HWID
 4️⃣ - DESCARGAR APP`);
                }
                
                // OPCIÓN 1: PRUEBA
                else if (text === '1' && userState.state === 'main_menu') {
                    await setUserState(from, 'awaiting_test_nombre');
                    
                    await client.sendText(from, `⏳️ PRUEBA 2 HORAS

Primero, dime tu nombre:`);
                }
                
                // OPCIÓN 2: COMPRAR
                else if (text === '2' && userState.state === 'main_menu') {
                    await setUserState(from, 'buying_hwid');
                    
                    await client.sendText(from, `💰 PLANES DISPONIBLES

 1️⃣ - 7 DÍAS - $${config.prices.price_7d}
 2️⃣ - 15 DÍAS - $${config.prices.price_15d}
 3️⃣ - 30 DÍAS - $${config.prices.price_30d}
 4️⃣ - 50 DÍAS - $${config.prices.price_50d}

 0️⃣ - VOLVER`);
                }
                
                // OPCIÓN 3: VERIFICAR HWID
                else if (text === '3' && userState.state === 'main_menu') {
                    await setUserState(from, 'awaiting_check_hwid');
                    
                    await client.sendText(from, `🔍 VERIFICAR HWID

Envía tu HWID:
Ejemplo: APP-E3E4D5CBB7636907`);
                }
                
                // OPCIÓN 4: DESCARGAR APP
                else if (text === '4' && userState.state === 'main_menu') {
                    await client.sendText(from, `📱 DESCARGAR APP

🔗 ${config.links.app_download}`);
                }
                
                // PROCESAR NOMBRE PARA PRUEBA
                else if (userState.state === 'awaiting_test_nombre') {
                    const nombre = message.body.trim();
                    
                    if (nombre.length < 2) {
                        await client.sendText(from, '❌ Nombre muy corto. Intenta de nuevo:');
                        return;
                    }
                    
                    await setUserState(from, 'awaiting_test_hwid', { nombre });
                    
                    await client.sendText(from, `✅ Gracias ${nombre}

Ahora envía tu HWID:

Formato: APP-E3E4D5CBB7636907`);
                }
                
                // PROCESAR HWID PARA PRUEBA
                else if (userState.state === 'awaiting_test_hwid') {
                    const rawHwid = message.body;
                    const hwid = normalizeHWID(rawHwid);
                    const nombre = userState.data.nombre;
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ HWID INVÁLIDO

Formato: APP-E3E4D5CBB7636907
Intenta de nuevo:`);
                        return;
                    }
                    
                    // Verificar prueba diaria
                    if (!(await canCreateTest(from))) {
                        await client.sendText(from, `❌ YA USaste tu prueba hoy

⏳ Vuelve mañana o compra un plan`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    // Verificar si HWID ya existe
                    const active = await isHWIDActive(hwid);
                    if (active) {
                        await client.sendText(from, `❌ Este HWID ya está activo`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    await client.sendText(from, '⏳ Activando prueba (2 horas)...');
                    
                    const result = await registerHWID(from, nombre, hwid, 0, 'test');
                    
                    if (result.success) {
                        registerTest(from, nombre);
                        
                        const expireTime = moment(result.expires).format('HH:mm DD/MM/YYYY');
                        
                        await client.sendText(from, `✅ PRUEBA ACTIVADA

👤 Nombre: ${nombre}
🔐 HWID: ${hwid}
⏰ Expira: ${expireTime}

📱 Ya puedes usar la app`);
                        
                        console.log(chalk.green(`✅ HWID test: ${hwid} - ${nombre}`));
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
                        
                        const payment = await createMercadoPagoPayment(
                            from, 
                            plan.days, 
                            plan.price, 
                            plan.name
                        );
                        
                        if (payment.success) {
                            const message = `💰 PAGO PARA HWID

Plan: ${plan.name}
Precio: $${payment.amount}

LINK: ${payment.paymentUrl}

⏰ Válido 24 horas

📌 DESPUÉS DE PAGAR:
1. Espera confirmación
2. Te pediré tu nombre
3. Luego tu HWID`;
                            
                            await client.sendText(from, message);
                            
                            if (fs.existsSync(payment.qrPath)) {
                                try {
                                    await client.sendImage(from, payment.qrPath, 'qr-pago.jpg', 
                                        `QR ${plan.name} - $${payment.amount}`);
                                } catch (qrError) {}
                            }
                        } else {
                            await client.sendText(from, `❌ Error: ${payment.error}`);
                        }
                        
                        await setUserState(from, 'main_menu');
                    } else {
                        await client.sendText(from, `Plan ${plan.name} - $${plan.price}

Contacta al admin: ${config.links.support}`);
                        await setUserState(from, 'main_menu');
                    }
                }
                
                else if (text === '0' && userState.state === 'buying_hwid') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, `Menú principal:
 1 - Probar
 2 - Comprar
 3 - Verificar HWID
 4 - Descargar app`);
                }
                
                // PROCESAR HWID PARA VERIFICACIÓN
                else if (userState.state === 'awaiting_check_hwid') {
                    const rawHwid = message.body;
                    const hwid = normalizeHWID(rawHwid);
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ Formato inválido

Ejemplo: APP-E3E4D5CBB7636907`);
                        return;
                    }
                    
                    const info = await getHWIDInfo(hwid);
                    
                    if (info && info.status === 1) {
                        const expires = moment(info.expires_at).format('DD/MM/YYYY HH:mm');
                        const now = moment();
                        const expiresMoment = moment(info.expires_at);
                        
                        if (expiresMoment.isAfter(now)) {
                            await client.sendText(from, `✅ HWID ACTIVO

👤 ${info.nombre}
🔐 ${hwid}
⏰ Válido hasta: ${expires}`);
                        } else {
                            await client.sendText(from, `❌ HWID EXPIRADO

👤 ${info.nombre}
🔐 ${hwid}
📅 Expiró: ${expires}`);
                        }
                    } else {
                        await client.sendText(from, `❌ HWID NO REGISTRADO

Envía 1 para prueba gratis`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
                // ESPERANDO NOMBRE Y HWID DESPUÉS DE PAGO
                else if (userState.state === 'awaiting_hwid') {
                    if (!userState.data.nombre) {
                        const nombre = message.body.trim();
                        
                        if (nombre.length < 2) {
                            await client.sendText(from, '❌ Nombre muy corto. Intenta:');
                            return;
                        }
                        
                        userState.data.nombre = nombre;
                        await setUserState(from, 'awaiting_hwid', userState.data);
                        
                        await client.sendText(from, `✅ Gracias ${nombre}

Ahora envía tu HWID:
APP-E3E4D5CBB7636907`);
                        
                        return;
                    }
                    
                    const rawHwid = message.body;
                    const hwid = normalizeHWID(rawHwid);
                    const nombre = userState.data.nombre;
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ FORMATO INCORRECTO

Ejemplo: APP-E3E4D5CBB7636907
Envía el HWID:`);
                        return;
                    }
                    
                    const active = await isHWIDActive(hwid);
                    if (active) {
                        await client.sendText(from, `❌ HWID ya activo`);
                        return;
                    }
                    
                    await client.sendText(from, '⏳ Activando HWID...');
                    
                    const result = await registerHWID(
                        from, 
                        nombre,
                        hwid, 
                        userState.data.days, 
                        'premium'
                    );
                    
                    if (result.success) {
                        db.run(`UPDATE payments SET hwid = ?, nombre = ? WHERE payment_id = ?`,
                            [hwid, nombre, userState.data.payment_id]);
                        
                        await client.sendText(from, `✅ ¡ACTIVADO!

👤 ${nombre}
🔐 ${hwid}
⏰ Válido: ${moment(result.expires).format('DD/MM/YYYY')}`);
                        
                        console.log(chalk.green(`✅ HWID premium: ${hwid} - ${nombre}`));
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
            } catch (error) {
                console.error(chalk.red('❌ Error procesando mensaje:'), error.message);
            }
        });
        
        // ✅ CRON JOBS
        cron.schedule('*/2 * * * *', () => {
            console.log(chalk.yellow('🔄 Verificando pagos...'));
            checkPendingPayments();
        });
        
        cron.schedule('0 * * * *', () => {
            console.log(chalk.yellow('⏰ Verificando vencimientos...'));
            checkExpiringHWIDs();
        });
        
        cron.schedule('*/15 * * * *', () => {
            const now = moment().format('YYYY-MM-DD HH:mm:ss');
            db.run('UPDATE hwid_users SET status = 0 WHERE expires_at < ? AND status = 1', [now]);
        });
        
    } catch (error) {
        console.error(chalk.red('❌ Error inicializando:'), error.message);
        setTimeout(initializeBot, 10000);
    }
}

// Iniciar
initializeBot();

process.on('SIGINT', async () => {
    console.log(chalk.yellow('\n🛑 Cerrando bot...'));
    if (client) {
        await client.close();
    }
    process.exit();
});
BOTEOF

echo -e "${GREEN}✅ Bot HWID creado con BD ÚNICA (CORREGIDO)${NC}"

# ================================================
# CREAR PANEL DE CONTROL
# ================================================
echo -e "\n${CYAN}🎛️  Creando panel de control...${NC}"

cat > /usr/local/bin/sshbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'

DB="/opt/sshbot-pro/data/bot.db"
CONFIG="/opt/sshbot-pro/config/config.json"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }
set_val() { local t=$(mktemp); jq "$1 = $2" "$CONFIG" > "$t" && mv "$t" "$CONFIG"; }

while true; do
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     PANEL SSH BOT - HWID (BD ÚNICA - CORREGIDO)   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}\n"
    
    TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM hwid_users" 2>/dev/null || echo "0")
    ACTIVE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM hwid_users WHERE status=1" 2>/dev/null || echo "0")
    PENDING=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='pending'" 2>/dev/null || echo "0")
    
    echo -e "${YELLOW}📊 ESTADO${NC}"
    echo -e "  HWIDs: ${CYAN}$ACTIVE/$TOTAL${NC} activos"
    echo -e "  Pagos pendientes: ${CYAN}$PENDING${NC}"
    echo -e ""
    
    echo -e "${CYAN}[1]${NC} Iniciar bot"
    echo -e "${CYAN}[2]${NC} Detener bot"
    echo -e "${CYAN}[3]${NC} Ver logs"
    echo -e "${CYAN}[4]${NC} Listar HWIDs"
    echo -e "${CYAN}[5]${NC} Configurar MP"
    echo -e "${CYAN}[0]${NC} Salir"
    echo ""
    
    read -p "👉 Opción: " OPT
    
    case $OPT in
        1) cd /root/sshbot-pro && pm2 restart sshbot-pro 2>/dev/null || pm2 start bot.js --name sshbot-pro; pm2 save;;
        2) pm2 stop sshbot-pro;;
        3) pm2 logs sshbot-pro --lines 50;;
        4) sqlite3 -column -header "$DB" "SELECT nombre, hwid, phone, expires_at FROM hwid_users WHERE status=1 ORDER BY expires_at;" | less;;
        5) 
            echo -e "\n${YELLOW}Token actual: $(get_val '.mercadopago.access_token' | cut -c1-30)...${NC}"
            read -p "Nuevo token: " TOKEN
            if [[ -n "$TOKEN" ]]; then
                set_val '.mercadopago.access_token' "\"$TOKEN\""
                set_val '.mercadopago.enabled' "true"
                echo -e "${GREEN}✅ Token guardado${NC}"
                cd /root/sshbot-pro && pm2 restart sshbot-pro
            fi
            read -p "Enter..." 
            ;;
        0) exit 0;;
    esac
done
PANELEOF

chmod +x /usr/local/bin/sshbot

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
║     ✅ INSTALACIÓN CORREGIDA - HWID CON BD ÚNICA ✅        ║
║                                                              ║
║     🔐 NO DA ERROR "EXPIRADO"                              ║
║     📱 MISMA BD PARA TODOS LOS DATOS                       ║
║     💰 MERCADOPAGO INTEGRADO                               ║
║     ⏱️  PRUEBA 2 HORAS                                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "\n${GREEN}✅ BD ÚNICA: ${CYAN}/opt/sshbot-pro/data/bot.db${NC}"
echo -e "${GREEN}✅ Comando: ${CYAN}sshbot${NC} - Panel de control"
echo -e "${GREEN}✅ Logs: ${CYAN}pm2 logs sshbot-pro${NC}"
echo -e "\n${YELLOW}📱 Escanea el QR y prueba - ¡YA NO DIRÁ EXPIRADO!${NC}\n"

read -p "¿Ver logs ahora? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    pm2 logs sshbot-pro
fi

exit 0