#!/bin/bash
# ================================================
# SSH BOT PRO - WPPCONNECT + MERCADOPAGO + REVENDEDORES
# VERSIÓN COMPLETA CON OPCIÓN 5 - SER REVENDEDOR
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
║          🤖 SSH BOT PRO - CON REVENDEDORES                  ║
║               💰 MERCADOPAGO + REVENDEDORES                 ║
║               👥 Opción 5 - SER REVENDEDOR                  ║
║               💸 Precios mayoristas:                         ║
║               🗓️ 7d = $1700 | 15d = $2500                   ║
║               🗓️ 20d = $3500 | 30d = $4500                  ║
║               🔔 Recordatorios automáticos                   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CARACTERÍSTICAS PRINCIPALES:${NC}"
echo -e "  👥 ${CYAN}OPCIÓN 5 - SER REVENDEDOR${NC} - Registro automático"
echo -e "  💰 ${GREEN}Precios mayoristas fijos${NC} - 7d=$1700, 15d=$2500, 20d=$3500, 30d=$4500"
echo -e "  💳 ${YELLOW}Pago por MercadoPago${NC} - Recibe usuario automáticamente"
echo -e "  📦 ${PURPLE}Cuenta de revendedor + 1 cuenta para vender${NC}"
echo -e "  📱 ${BLUE}Comandos exclusivos${NC} - !mis_cuentas, !vender, !panel"
echo -e "  🔔 ${CYAN}Recordatorios${NC} - A usuarios finales"
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
# PREPARAR ESTRUCTURA
# ================================================
echo -e "\n${CYAN}📁 Creando estructura...${NC}"

INSTALL_DIR="/opt/sshbot-pro"
USER_HOME="/root/sshbot-pro"
DB_FILE="$INSTALL_DIR/data/users.db"
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
        "name": "SSH Bot Pro",
        "version": "3.0-REVENDEDORES",
        "server_ip": "$SERVER_IP",
        "default_password": "mgvpn247"
    },
    "prices": {
        "test_hours": 2,
        "price_7d": 1700.00,
        "price_15d": 2500.00,
        "price_20d": 3500.00,
        "price_30d": 4500.00,
        "currency": "ARS"
    },
    "reseller_prices": {
        "7d": 1700.00,
        "15d": 2500.00,
        "20d": 3500.00,
        "30d": 4500.00
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false,
        "public_key": ""
    },
    "reminders": {
        "enabled": true,
        "times": [24, 12, 6, 1]
    },
    "links": {
        "app_download": "https://www.mediafire.com/file/tvt0vpmyfg3xqhj/mgvpn.apk/file",
        "support": "https://wa.me/543435071016"
    },
    "paths": {
        "database": "$DB_FILE",
        "qr_codes": "$INSTALL_DIR/qr_codes",
        "sessions": "/root/.wppconnect"
    }
}
EOF

# Crear base de datos COMPLETA con tablas de revendedores
sqlite3 "$DB_FILE" << 'SQL'
-- Tabla de usuarios normales
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    username TEXT UNIQUE,
    password TEXT DEFAULT 'mgvpn247',
    tipo TEXT DEFAULT 'test',
    expires_at DATETIME,
    status INTEGER DEFAULT 1,
    last_reminder_hours INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de tests diarios
CREATE TABLE daily_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(phone, date)
);

-- Tabla de pagos normales
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
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    approved_at DATETIME
);

-- TABLAS DE REVENDEDORES
CREATE TABLE resellers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT UNIQUE,
    username TEXT UNIQUE,
    password TEXT DEFAULT 'mgvpn247',
    plan TEXT,
    expires_at DATETIME,
    accounts_remaining INTEGER DEFAULT 0,
    total_accounts INTEGER DEFAULT 0,
    status TEXT DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_purchase DATETIME
);

CREATE TABLE reseller_purchases_pending (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    plan TEXT,
    days INTEGER,
    price REAL,
    payment_id TEXT UNIQUE,
    preference_id TEXT,
    status TEXT DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    approved_at DATETIME
);

CREATE TABLE reseller_accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    reseller_phone TEXT,
    username TEXT UNIQUE,
    password TEXT DEFAULT 'mgvpn247',
    expires_at DATETIME,
    status TEXT DEFAULT 'available',
    sold_to TEXT,
    sold_price REAL,
    sold_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
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

-- Índices
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_preference ON payments(preference_id);
CREATE INDEX idx_resellers_phone ON resellers(phone);
CREATE INDEX idx_reseller_accounts_reseller ON reseller_accounts(reseller_phone);
CREATE INDEX idx_reseller_accounts_status ON reseller_accounts(status);
SQL

echo -e "${GREEN}✅ Estructura creada con tablas de revendedores${NC}"

# ================================================
# CREAR BOT COMPLETO CON REVENDEDORES
# ================================================
echo -e "\n${CYAN}🤖 Creando bot con WPPConnect + MercadoPago + Revendedores...${NC}"

cd "$USER_HOME"

# package.json
cat > package.json << 'PKGEOF'
{
    "name": "sshbot-pro",
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

echo -e "${YELLOW}📦 Instalando dependencias...${NC}"
npm install --silent 2>&1 | grep -v "npm WARN" || true

# Crear bot.js COMPLETO con sistema de revendedores
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
console.log(chalk.cyan.bold('║      🤖 SSH BOT PRO - CON REVENDEDORES                      ║'));
console.log(chalk.cyan.bold('║         💼 OPCIÓN 5 - SER REVENDEDOR                        ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

// Cargar configuración
function loadConfig() {
    delete require.cache[require.resolve('/opt/sshbot-pro/config/config.json')];
    return require('/opt/sshbot-pro/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/sshbot-pro/data/users.db');

// MERCADOPAGO
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
const DEFAULT_PASSWORD = 'mgvpn247';

// ================================================
// FUNCIONES DE ESTADO
// ================================================
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

function clearUserState(phone) {
    db.run('DELETE FROM user_state WHERE phone = ?', [phone]);
}

// ================================================
// FUNCIONES AUXILIARES
// ================================================
function generateUsername(prefix = 'user') {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    const randomNum = Math.floor(1000 + Math.random() * 9000);
    const randomChar = chars.charAt(Math.floor(Math.random() * chars.length));
    return `${prefix}${randomChar}${randomNum}`;
}

function generateResellerUsername() {
    return generateUsername('vendedor');
}

function generateClientUsername() {
    return generateUsername('cliente');
}

async function createSSHUser(username, days) {
    const password = DEFAULT_PASSWORD;
    
    if (days === 0) {
        // Test - horas
        const expireFull = moment().add(config.prices.test_hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
        
        try {
            await execPromise(`useradd -m -s /bin/bash ${username} && echo "${username}:${password}" | chpasswd`);
            return { success: true, username, password, expires: expireFull };
        } catch (error) {
            return { success: false, error: error.message };
        }
    } else {
        // Premium
        const expireFull = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
        
        try {
            await execPromise(`useradd -M -s /bin/false -e ${moment().add(days, 'days').format('YYYY-MM-DD')} ${username} && echo "${username}:${password}" | chpasswd`);
            return { success: true, username, password, expires: expireFull };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }
}

function canCreateTest(phone) {
    return new Promise((resolve) => {
        const today = moment().format('YYYY-MM-DD');
        db.get('SELECT COUNT(*) as count FROM daily_tests WHERE phone = ? AND date = ?', [phone, today],
            (err, row) => resolve(!err && row && row.count === 0));
    });
}

function registerTest(phone) {
    db.run('INSERT OR IGNORE INTO daily_tests (phone, date) VALUES (?, ?)', [phone, moment().format('YYYY-MM-DD')]);
}

// ================================================
// MERCADOPAGO - CREAR PAGO
// ================================================
async function createMercadoPagoPayment(phone, days, amount, title, reference) {
    try {
        if (!mpEnabled || !mpPreference) {
            return { success: false, error: 'MercadoPago no configurado' };
        }
        
        const phoneClean = phone.replace('@c.us', '');
        const paymentId = reference || `PAY-${phoneClean}-${days}d-${Date.now()}`;
        
        const preferenceData = {
            items: [{
                title: title,
                description: `SSH Premium - ${days} días`,
                quantity: 1,
                currency_id: config.prices.currency || 'ARS',
                unit_price: parseFloat(amount)
            }],
            external_reference: paymentId,
            expires: true,
            expiration_date_to: moment().add(24, 'hours').toISOString(),
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
            const qrPath = `${config.paths.qr_codes}/${paymentId}.png`;
            
            await QRCode.toFile(qrPath, paymentUrl, { width: 400 });
            
            return { 
                success: true, 
                paymentId, 
                paymentUrl, 
                qrPath,
                preferenceId: response.id,
                amount: parseFloat(amount)
            };
        }
        
        throw new Error('Respuesta inválida de MercadoPago');
        
    } catch (error) {
        console.error(chalk.red('❌ Error MercadoPago:'), error.message);
        return { success: false, error: error.message };
    }
}

// ================================================
// VERIFICAR PAGOS
// ================================================
async function checkPendingPayments() {
    if (!mpEnabled) return;
    
    // Verificar pagos normales
    db.all('SELECT * FROM payments WHERE status = "pending" AND created_at > datetime("now", "-48 hours")', async (err, payments) => {
        if (err || !payments) return;
        
        for (const payment of payments) {
            try {
                const url = `https://api.mercadopago.com/v1/payments/search?external_reference=${payment.payment_id}`;
                const response = await axios.get(url, {
                    headers: { 'Authorization': `Bearer ${config.mercadopago.access_token}` }
                });
                
                if (response.data.results && response.data.results.length > 0) {
                    const mpPayment = response.data.results[0];
                    
                    if (mpPayment.status === 'approved') {
                        // Crear usuario SSH
                        const username = generateUsername();
                        const result = await createSSHUser(username, payment.days);
                        
                        if (result.success) {
                            db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`, [payment.payment_id]);
                            
                            const expireDate = moment().add(payment.days, 'days').format('DD/MM/YYYY');
                            
                            const message = `✅ PAGO CONFIRMADO

📋 DATOS DE ACCESO:
👤 Usuario: ${username}
🔑 Contraseña: ${DEFAULT_PASSWORD}
⏰ VÁLIDO HASTA: ${expireDate}`;
                            
                            if (client) {
                                await client.sendText(payment.phone, message);
                            }
                        }
                    }
                }
            } catch (error) {
                console.error(chalk.red('Error verificando pago:'), error.message);
            }
        }
    });
    
    // Verificar pagos de revendedores
    db.all('SELECT * FROM reseller_purchases_pending WHERE status = "pending"', async (err, purchases) => {
        if (err || !purchases) return;
        
        for (const purchase of purchases) {
            try {
                const url = `https://api.mercadopago.com/v1/payments/search?external_reference=${purchase.payment_id}`;
                const response = await axios.get(url, {
                    headers: { 'Authorization': `Bearer ${config.mercadopago.access_token}` }
                });
                
                if (response.data.results && response.data.results.length > 0) {
                    const mpPayment = response.data.results[0];
                    
                    if (mpPayment.status === 'approved') {
                        console.log(chalk.green(`✅ PAGO REVENDEDOR APROBADO: ${purchase.payment_id}`));
                        
                        // Generar usuario revendedor
                        const resellerUsername = generateResellerUsername();
                        const resellerExpire = moment().add(purchase.days, 'days').format('YYYY-MM-DD HH:mm:ss');
                        
                        // Crear usuario SSH para revendedor
                        await createSSHUser(resellerUsername, purchase.days);
                        
                        // Generar cuenta para vender
                        const clientUsername = generateClientUsername();
                        const clientExpire = moment().add(purchase.days, 'days').format('YYYY-MM-DD HH:mm:ss');
                        
                        await createSSHUser(clientUsername, purchase.days);
                        
                        // Guardar en BD
                        db.run(`
                            INSERT INTO resellers 
                            (phone, username, plan, expires_at, accounts_remaining, total_accounts) 
                            VALUES (?, ?, ?, ?, 1, 1)
                        `, [purchase.phone, resellerUsername, purchase.plan, resellerExpire]);
                        
                        db.run(`
                            INSERT INTO reseller_accounts 
                            (reseller_phone, username, expires_at, status) 
                            VALUES (?, ?, ?, 'available')
                        `, [purchase.phone, clientUsername, clientExpire]);
                        
                        db.run(`
                            UPDATE reseller_purchases_pending 
                            SET status = 'approved', approved_at = CURRENT_TIMESTAMP 
                            WHERE payment_id = ?
                        `, [purchase.payment_id]);
                        
                        // Notificar al revendedor
                        const message = `🎉 *¡FELICIDADES! YA ERES REVENDEDOR*

✅ Pago aprobado correctamente

📋 *TUS DATOS DE ACCESO:*
👤 Usuario: ${resellerUsername}
🔑 Contraseña: ${DEFAULT_PASSWORD}
⏰ Válido hasta: ${moment(resellerExpire).format('DD/MM/YYYY HH:mm')}

📦 *CUENTA PARA VENDER:*
👤 Usuario: ${clientUsername}
🔑 Contraseña: ${DEFAULT_PASSWORD}
⏰ Vence: ${moment(clientExpire).format('DD/MM/YYYY HH:mm')}

💼 *COMANDOS:*
!mis_cuentas - Ver tus cuentas
!vender [usuario] [tel] [precio] - Registrar venta
!disponibles - Ver cuentas sin vender
!ayuda_rev - Ayuda completa

💰 *INSTRUCCIONES:*
1. Tienes 1 cuenta para vender
2. Véndela al precio que quieras
3. Para comprar más, vuelve a opción 5`;
                        
                        if (client) {
                            await client.sendText(purchase.phone, message);
                        }
                    }
                }
            } catch (error) {
                console.error(chalk.red('Error verificando pago revendedor:'), error.message);
            }
        }
    });
}

// ================================================
// INICIALIZAR BOT
// ================================================
async function initializeBot() {
    try {
        console.log(chalk.yellow('🚀 Inicializando WPPConnect...'));
        
        client = await wppconnect.create({
            session: 'sshbot-pro-session',
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
                
                // ================================================
                // MENÚ PRINCIPAL
                // ================================================
                if (['menu', 'hola', 'start', 'hi', 'volver', '0'].includes(text)) {
                    await setUserState(from, 'main_menu');
                    
                    await client.sendText(from, `🤖 *BOT MGVPN*

Elija una opción:

1️⃣ - PRUEBA GRATIS (2 HORAS)
2️⃣ - COMPRAR USUARIO SSH
3️⃣ - RENOVAR USUARIO
4️⃣ - DESCARGAR APP
5️⃣ - SER REVENDEDOR 💼
6️⃣ - PANEL REVENDEDOR

0️⃣ - VOLVER`);
                }
                
                // ================================================
                // OPCIÓN 1: PRUEBA GRATIS
                // ================================================
                else if (text === '1' && userState.state === 'main_menu') {
                    if (!(await canCreateTest(from))) {
                        await client.sendText(from, `❌ YA USASTE TU PRUEBA HOY

⏳ Vuelve mañana para otra prueba gratuita de 2 horas`);
                        return;
                    }
                    
                    await client.sendText(from, '⏳ Creando cuenta de prueba de 2 horas...');
                    
                    const username = generateUsername('test');
                    const result = await createSSHUser(username, 0);
                    
                    if (result.success) {
                        registerTest(from);
                        
                        await client.sendText(from, `✅ *PRUEBA DE 2 HORAS CREADA*

👤 Usuario: ${username}
🔑 Contraseña: ${DEFAULT_PASSWORD}
⏰ Expira en: ${config.prices.test_hours} horas

📱 APP: ${config.links.app_download}`);
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                }
                
                // ================================================
                // OPCIÓN 2: COMPRAR SSH
                // ================================================
                else if (text === '2' && userState.state === 'main_menu') {
                    await setUserState(from, 'buying_ssh');
                    
                    await client.sendText(from, `🌐 *PLANES SSH*

Elija un plan:
1️⃣ - 7 DÍAS - $${config.prices.price_7d}
2️⃣ - 15 DÍAS - $${config.prices.price_15d}
3️⃣ - 20 DÍAS - $${config.prices.price_20d}
4️⃣ - 30 DÍAS - $${config.prices.price_30d}
0️⃣ - VOLVER`);
                }
                
                // ================================================
                // SELECCIÓN DE PLANES NORMALES
                // ================================================
                else if (userState.state === 'buying_ssh' && ['1', '2', '3', '4'].includes(text)) {
                    const planMap = {
                        '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                        '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' },
                        '3': { days: 20, price: config.prices.price_20d, name: '20 DÍAS' },
                        '4': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' }
                    };
                    
                    const plan = planMap[text];
                    
                    if (mpEnabled) {
                        await client.sendText(from, '⏳ Procesando tu compra...');
                        
                        const payment = await createMercadoPagoPayment(
                            from, 
                            plan.days, 
                            plan.price, 
                            `SSH ${plan.name}`,
                            `USER-${from.replace('@c.us', '')}-${plan.days}d-${Date.now()}`
                        );
                        
                        if (payment.success) {
                            db.run(
                                `INSERT INTO payments (payment_id, phone, plan, days, amount, status, payment_url, qr_code, preference_id) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
                                [payment.paymentId, from, `${plan.days}d`, plan.days, plan.price, payment.paymentUrl, payment.qrPath, payment.preferenceId]
                            );
                            
                            await client.sendText(from, `🔗 *LINK DE PAGO:*
${payment.paymentUrl}

💰 Monto: $${plan.price}
⏰ Expira en 24 horas`);
                            
                            if (fs.existsSync(payment.qrPath)) {
                                await client.sendImage(from, payment.qrPath, 'qr-pago.jpg', 'Escanea para pagar');
                            }
                        } else {
                            await client.sendText(from, `❌ Error: ${payment.error}`);
                        }
                    } else {
                        await client.sendText(from, `❌ MercadoPago no configurado. Contacta al administrador.`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
                // ================================================
                // OPCIÓN 3: RENOVAR
                // ================================================
                else if (text === '3' && userState.state === 'main_menu') {
                    await client.sendText(from, `📞 Para renovar, contacta al administrador:
${config.links.support}`);
                }
                
                // ================================================
                // OPCIÓN 4: DESCARGAR APP
                // ================================================
                else if (text === '4' && userState.state === 'main_menu') {
                    await client.sendText(from, `📱 *DESCARGAR APP*

🔗 Enlace:
${config.links.app_download}

💡 Instrucciones:
1. Abre el enlace
2. Descarga el APK
3. Instala la aplicación
4. Configura con tus credenciales`);
                }
                
                // ================================================
                // OPCIÓN 5: SER REVENDEDOR 💼
                // ================================================
                else if (text === '5' && userState.state === 'main_menu') {
                    await setUserState(from, 'selecting_reseller_plan');
                    
                    await client.sendText(from, `💼 *SER REVENDEDOR - PRECIOS MAYORISTAS*

Elija un plan (pago único por las cuentas):

1️⃣ - 7 DÍAS = $${config.reseller_prices['7d']}
     (Recibes 1 cuenta para vender)

2️⃣ - 15 DÍAS = $${config.reseller_prices['15d']}
     (Recibes 1 cuenta para vender)

3️⃣ - 20 DÍAS = $${config.reseller_prices['20d']}
     (Recibes 1 cuenta para vender)

4️⃣ - 30 DÍAS = $${config.reseller_prices['30d']}
     (Recibes 1 cuenta para vender)

📌 *AL COMPRAR RECIBES:*
• Tu usuario de revendedor
• 1 cuenta SSH para vender
• Contraseña: ${DEFAULT_PASSWORD}
• Puedes venderla al precio que quieras

0️⃣ - VOLVER

Elige una opción:`);
                }
                
                // ================================================
                // SELECCIÓN DE PLAN REVENDEDOR
                // ================================================
                else if (userState.state === 'selecting_reseller_plan' && ['1', '2', '3', '4'].includes(text)) {
                    const planMap = {
                        '1': { days: 7, price: config.reseller_prices['7d'], name: '7 DÍAS' },
                        '2': { days: 15, price: config.reseller_prices['15d'], name: '15 DÍAS' },
                        '3': { days: 20, price: config.reseller_prices['20d'], name: '20 DÍAS' },
                        '4': { days: 30, price: config.reseller_prices['30d'], name: '30 DÍAS' }
                    };
                    
                    const plan = planMap[text];
                    await setUserState(from, 'confirming_reseller_payment', plan);
                    
                    await client.sendText(from, `💼 *CONFIRMAR COMPRA REVENDEDOR*

Plan: ${plan.name}
Precio: $${plan.price}
Incluye:
• Tu usuario de revendedor (válido ${plan.days} días)
• 1 cuenta SSH para vender a tu cliente

💰 *TOTAL A PAGAR: $${plan.price}*

¿Deseas continuar?

✅ *SI* - Ir a pagar
❌ *NO* - Cancelar`);
                }
                
                // ================================================
                // CONFIRMAR PAGO REVENDEDOR
                // ================================================
                else if (userState.state === 'confirming_reseller_payment' && text.toLowerCase() === 'si') {
                    const plan = userState.data;
                    
                    if (mpEnabled) {
                        await client.sendText(from, '⏳ Procesando tu compra como revendedor...');
                        
                        const paymentId = `RESELLER-${from.replace('@c.us', '')}-${plan.days}d-${Date.now()}`;
                        
                        const payment = await createMercadoPagoPayment(
                            from, 
                            plan.days, 
                            plan.price, 
                            `PAQUETE REVENDEDOR ${plan.name}`,
                            paymentId
                        );
                        
                        if (payment.success) {
                            db.run(
                                `INSERT INTO reseller_purchases_pending (phone, plan, days, price, payment_id, preference_id, status) VALUES (?, ?, ?, ?, ?, ?, 'pending')`,
                                [from, plan.name, plan.days, plan.price, payment.paymentId, payment.preferenceId]
                            );
                            
                            const message = `💼 *COMPRA REVENDEDOR INICIADA*

Plan: ${plan.name}
Monto: $${plan.price}

🔗 *LINK DE PAGO:*
${payment.paymentUrl}

⏰ Este enlace expira en 24 horas

⚠️ *IMPORTANTE:*
Al pagar, recibirás AUTOMÁTICAMENTE:
✅ Tu usuario de revendedor
✅ Contraseña: ${DEFAULT_PASSWORD}
✅ 1 cuenta SSH para vender
✅ Instrucciones de uso`;
                            
                            await client.sendText(from, message);
                            
                            if (fs.existsSync(payment.qrPath)) {
                                await client.sendImage(from, payment.qrPath, 'qr-pago.jpg', 
                                    `Escanea para pagar\n\n${plan.name} - $${plan.price}`);
                            }
                        } else {
                            await client.sendText(from, `❌ Error al generar pago: ${payment.error}`);
                        }
                    } else {
                        await client.sendText(from, `❌ MercadoPago no configurado. Contacta al administrador.`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
                else if (userState.state === 'confirming_reseller_payment' && text.toLowerCase() === 'no') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, '❌ Compra cancelada. Vuelve al menú con MENU');
                }
                
                // ================================================
                // OPCIÓN 6: PANEL REVENDEDOR
                // ================================================
                else if (text === '6' && userState.state === 'main_menu') {
                    db.get('SELECT * FROM resellers WHERE phone = ? AND status = "active"', [from], async (err, reseller) => {
                        if (reseller) {
                            // Obtener estadísticas
                            const accounts = await new Promise((resolve) => {
                                db.get('SELECT COUNT(*) as total FROM reseller_accounts WHERE reseller_phone = ?', [from], (err, row) => {
                                    resolve(row ? row.total : 0);
                                });
                            });
                            
                            const available = await new Promise((resolve) => {
                                db.get('SELECT COUNT(*) as total FROM reseller_accounts WHERE reseller_phone = ? AND status = "available"', [from], (err, row) => {
                                    resolve(row ? row.total : 0);
                                });
                            });
                            
                            const sold = await new Promise((resolve) => {
                                db.get('SELECT COUNT(*) as total FROM reseller_accounts WHERE reseller_phone = ? AND status = "sold"', [from], (err, row) => {
                                    resolve(row ? row.total : 0);
                                });
                            });
                            
                            await client.sendText(from, `💼 *PANEL REVENDEDOR*

📊 *TUS ESTADÍSTICAS:*
📦 Cuentas totales: ${accounts}
✅ Disponibles: ${available}
💰 Vendidas: ${sold}
⏰ Tu cuenta vence: ${moment(reseller.expires_at).format('DD/MM/YYYY')}

*COMANDOS:*
!mis_cuentas - Ver lista de cuentas
!disponibles - Ver cuentas sin vender
!vender [usuario] [tel] [precio] - Registrar venta
!comprar_mas - Comprar más (opción 5)
!ayuda_rev - Ver todos los comandos`);
                        } else {
                            await client.sendText(from, `❌ No eres revendedor aún.

Para ser revendedor, selecciona la opción 5 del menú principal.

💼 Opción 5 - SER REVENDEDOR`);
                        }
                    });
                }
                
                // ================================================
                // COMANDOS DE REVENDEDOR
                // ================================================
                else if (text === '!mis_cuentas') {
                    db.all('SELECT * FROM reseller_accounts WHERE reseller_phone = ? ORDER BY created_at DESC', [from], async (err, accounts) => {
                        if (!accounts || accounts.length === 0) {
                            await client.sendText(from, '📦 No tienes cuentas aún. Compra en opción 5.');
                            return;
                        }
                        
                        let msg = '📦 *TUS CUENTAS:*\n\n';
                        accounts.forEach((acc, i) => {
                            const status = acc.status === 'available' ? '✅ DISPONIBLE' : '💰 VENDIDA';
                            msg += `👤 ${acc.username}\n`;
                            msg += `🔑 ${DEFAULT_PASSWORD}\n`;
                            msg += `⏰ Vence: ${moment(acc.expires_at).format('DD/MM/YYYY')}\n`;
                            msg += `📊 ${status}\n`;
                            if (acc.sold_to) {
                                msg += `📱 Cliente: ${acc.sold_to}\n`;
                                msg += `💵 Precio: $${acc.sold_price}\n`;
                            }
                            msg += `➖➖➖➖➖➖➖\n`;
                        });
                        
                        await client.sendText(from, msg);
                    });
                }
                
                else if (text === '!disponibles') {
                    db.all('SELECT * FROM reseller_accounts WHERE reseller_phone = ? AND status = "available"', [from], async (err, accounts) => {
                        if (!accounts || accounts.length === 0) {
                            await client.sendText(from, '✅ No tienes cuentas disponibles. Compra más en opción 5.');
                            return;
                        }
                        
                        let msg = '✅ *CUENTAS DISPONIBLES:*\n\n';
                        accounts.forEach(acc => {
                            msg += `👤 ${acc.username}\n`;
                            msg += `🔑 ${DEFAULT_PASSWORD}\n`;
                            msg += `⏰ Vence: ${moment(acc.expires_at).format('DD/MM/YYYY')}\n`;
                            msg += `➖➖➖➖➖\n`;
                        });
                        
                        await client.sendText(from, msg);
                    });
                }
                
                else if (text.startsWith('!vender ')) {
                    const parts = text.split(' ');
                    if (parts.length >= 4) {
                        const username = parts[1];
                        const clientPhone = parts[2];
                        const price = parts[3];
                        
                        // Verificar que la cuenta existe y está disponible
                        db.get('SELECT * FROM reseller_accounts WHERE reseller_phone = ? AND username = ? AND status = "available"', 
                            [from, username], async (err, account) => {
                                if (account) {
                                    db.run(`
                                        UPDATE reseller_accounts 
                                        SET status = 'sold', sold_to = ?, sold_price = ?, sold_at = CURRENT_TIMESTAMP
                                        WHERE reseller_phone = ? AND username = ?
                                    `, [clientPhone, price, from, username], async (err) => {
                                        if (err) {
                                            await client.sendText(from, '❌ Error al registrar venta');
                                        } else {
                                            await client.sendText(from, `✅ *VENTA REGISTRADA*

👤 Usuario: ${username}
📱 Cliente: ${clientPhone}
💰 Precio: $${price}
💼 Ganancia: $${price - account.price_paid || 0}

💡 Puedes comprar más cuentas en opción 5`);
                                        }
                                    });
                                } else {
                                    await client.sendText(from, '❌ Cuenta no disponible o no te pertenece');
                                }
                            });
                    } else {
                        await client.sendText(from, '❌ Uso: !vender [usuario] [teléfono_cliente] [precio]');
                    }
                }
                
                else if (text === '!comprar_mas') {
                    await setUserState(from, 'selecting_reseller_plan');
                    
                    await client.sendText(from, `💼 *COMPRAR MÁS CUENTAS*

Elige un plan:

1️⃣ - 7 DÍAS = $${config.reseller_prices['7d']}
2️⃣ - 15 DÍAS = $${config.reseller_prices['15d']}
3️⃣ - 20 DÍAS = $${config.reseller_prices['20d']}
4️⃣ - 30 DÍAS = $${config.reseller_prices['30d']}

0️⃣ - VOLVER`);
                }
                
                else if (text === '!ayuda_rev') {
                    await client.sendText(from, `📚 *AYUDA PARA REVENDEDORES*

*COMANDOS DISPONIBLES:*

!mis_cuentas
  Ver todas tus cuentas

!disponibles
  Ver cuentas sin vender

!vender [user] [tel] [precio]
  Registrar venta de una cuenta
  Ej: !vender cliente123 54911223344 2500

!comprar_mas
  Comprar más cuentas (opción 5)

!panel
  Ver panel de estadísticas

💡 *CONSEJOS:*
• Las cuentas vencen según el plan
• Puedes vender al precio que quieras
• La ganancia es toda tuya
• Para comprar más, usa !comprar_mas`);
                }
                
                else if (text === '!panel') {
                    // Redirige a opción 6
                    await client.sendText(from, 'Usa la opción 6 del menú o escribe !panel_rev');
                }
                
                else if (text === '0' && userState.state !== 'main_menu') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, 'Volviendo al menú principal... Escribe MENU');
                }
                
            } catch (error) {
                console.error(chalk.red('❌ Error procesando mensaje:'), error.message);
            }
        });
        
        // ================================================
        // CRON JOBS
        // ================================================
        
        // Verificar pagos cada 2 minutos
        cron.schedule('*/2 * * * *', () => {
            checkPendingPayments();
        });
        
        // Limpiar usuarios expirados cada 15 minutos
        cron.schedule('*/15 * * * *', async () => {
            const now = moment().format('YYYY-MM-DD HH:mm:ss');
            
            db.all('SELECT username FROM users WHERE expires_at < ? AND status = 1', [now], async (err, rows) => {
                if (err || !rows) return;
                
                for (const r of rows) {
                    try {
                        await execPromise(`pkill -u ${r.username} 2>/dev/null || true`);
                        await execPromise(`userdel -f ${r.username} 2>/dev/null || true`);
                        db.run('UPDATE users SET status = 0 WHERE username = ?', [r.username]);
                    } catch (e) {}
                }
            });
            
            // Limpiar cuentas de revendedores expiradas
            db.all('SELECT username FROM reseller_accounts WHERE expires_at < ? AND status = "available"', [now], async (err, rows) => {
                if (err || !rows) return;
                
                for (const r of rows) {
                    try {
                        await execPromise(`userdel -f ${r.username} 2>/dev/null || true`);
                        db.run('UPDATE reseller_accounts SET status = "expired" WHERE username = ?', [r.username]);
                    } catch (e) {}
                }
            });
        });
        
        // Recordatorios cada hora
        cron.schedule('0 * * * *', async () => {
            if (!config.reminders || !config.reminders.enabled) return;
            
            const reminderTimes = config.reminders.times || [24, 12, 6, 1];
            
            for (const hours of reminderTimes) {
                const targetTime = moment().add(hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
                
                db.all(
                    `SELECT phone, username, expires_at FROM users 
                     WHERE status = 1 AND tipo = 'premium'
                     AND expires_at BETWEEN datetime('now') AND datetime(?)`,
                    [targetTime],
                    async (err, users) => {
                        if (err || !users) return;
                        
                        for (const user of users) {
                            const expireFormatted = moment(user.expires_at).format('DD/MM/YYYY HH:mm');
                            const message = `🔔 *RECORDATORIO*

Tu cuenta *${user.username}* vencerá en ${hours} horas.

📅 Fecha: ${expireFormatted}

Para renovar, usa el menú principal.`;
                            
                            try {
                                if (client) {
                                    await client.sendText(user.phone, message);
                                }
                            } catch (error) {}
                        }
                    }
                );
            }
        });
        
    } catch (error) {
        console.error(chalk.red('❌ Error inicializando WPPConnect:'), error.message);
        setTimeout(initializeBot, 10000);
    }
}

// Iniciar bot
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

echo -e "${GREEN}✅ Bot creado con sistema de revendedores${NC}"

# ================================================
# CREAR PANEL DE CONTROL
# ================================================
echo -e "\n${CYAN}🎛️  Creando panel de control...${NC}"

cat > /usr/local/bin/sshbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; NC='\033[0m'

DB="/opt/sshbot-pro/data/users.db"
CONFIG="/opt/sshbot-pro/config/config.json"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }
set_val() { local t=$(mktemp); jq "$1 = $2" "$CONFIG" > "$t" && mv "$t" "$CONFIG"; }

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         🎛️  PANEL SSH BOT PRO - CON REVENDEDORES           ║${NC}"
    echo -e "${CYAN}║              💼 OPCIÓN 5 - SER REVENDEDOR                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

while true; do
    show_header
    
    TOTAL_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1" 2>/dev/null || echo "0")
    TOTAL_RESELLERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM resellers" 2>/dev/null || echo "0")
    ACTIVE_RESELLERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM resellers WHERE status='active'" 2>/dev/null || echo "0")
    PENDING_PAYMENTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='pending'" 2>/dev/null || echo "0")
    PENDING_RESELLER=$(sqlite3 "$DB" "SELECT COUNT(*) FROM reseller_purchases_pending WHERE status='pending'" 2>/dev/null || echo "0")
    
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
    echo -e "  Usuarios normales: ${CYAN}$ACTIVE_USERS/$TOTAL_USERS${NC} activos"
    echo -e "  Revendedores: ${CYAN}$ACTIVE_RESELLERS/$TOTAL_RESELLERS${NC} activos"
    echo -e "  Pagos pendientes: ${CYAN}$PENDING_PAYMENTS${NC} normales | ${PURPLE}$PENDING_RESELLER${NC} revendedores"
    echo -e "  MercadoPago: $MP_STATUS"
    echo -e ""
    
    echo -e "${YELLOW}💰 PRECIOS REVENDEDORES:${NC}"
    echo -e "  7 días: $ $(get_val '.reseller_prices."7d"') ARS"
    echo -e "  15 días: $ $(get_val '.reseller_prices."15d"') ARS"
    echo -e "  20 días: $ $(get_val '.reseller_prices."20d"') ARS"
    echo -e "  30 días: $ $(get_val '.reseller_prices."30d"') ARS"
    echo -e ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC} 🚀  Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC} 🛑  Detener bot"
    echo -e "${CYAN}[3]${NC} 📱  Ver logs y QR"
    echo -e "${CYAN}[4]${NC} 👤  Gestionar usuarios"
    echo -e "${CYAN}[5]${NC} 💼  Gestionar revendedores"
    echo -e "${CYAN}[6]${NC} 🔑  Configurar MercadoPago"
    echo -e "${CYAN}[7]${NC} 💰  Cambiar precios revendedores"
    echo -e "${CYAN}[8]${NC} 📊  Ver estadísticas"
    echo -e "${CYAN}[9]${NC} 🔄  Limpiar sesión"
    echo -e "${CYAN}[10]${NC} 💳 Ver pagos pendientes"
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
            echo -e "${CYAN}👤 GESTIÓN DE USUARIOS${NC}\n"
            echo "1. Listar usuarios"
            echo "2. Crear usuario manual"
            echo "3. Eliminar usuario expirado"
            read -p "Opción: " SUB
            case $SUB in
                1)
                    sqlite3 -column -header "$DB" "SELECT username, phone, tipo, expires_at FROM users WHERE status=1 ORDER BY expires_at"
                    ;;
                2)
                    read -p "Teléfono: " PHONE
                    read -p "Días (7/15/20/30): " DAYS
                    USER="user$(shuf -i 1000-9999 -n 1)"
                    EXPIRE=$(date -d "+$DAYS days" +"%Y-%m-%d 23:59:59")
                    useradd -M -s /bin/false -e "$(date -d "+$DAYS days" +%Y-%m-%d)" "$USER" && echo "$USER:mgvpn247" | chpasswd
                    sqlite3 "$DB" "INSERT INTO users (phone, username, password, tipo, expires_at, status) VALUES ('$PHONE', '$USER', 'mgvpn247', 'premium', '$EXPIRE', 1)"
                    echo -e "${GREEN}✅ Usuario $USER creado${NC}"
                    ;;
            esac
            read -p "Presiona Enter..."
            ;;
        5)
            clear
            echo -e "${CYAN}💼 GESTIÓN DE REVENDEDORES${NC}\n"
            echo "1. Listar revendedores"
            echo "2. Ver cuentas de revendedor"
            echo "3. Agregar revendedor manual"
            read -p "Opción: " SUB
            case $SUB in
                1)
                    sqlite3 -column -header "$DB" "SELECT phone, username, plan, expires_at, accounts_remaining FROM resellers WHERE status='active'"
                    ;;
                2)
                    read -p "Teléfono revendedor: " RPHONE
                    sqlite3 -column -header "$DB" "SELECT username, status, sold_to, sold_price FROM reseller_accounts WHERE reseller_phone='$RPHONE'"
                    ;;
                3)
                    read -p "Teléfono: " PHONE
                    read -p "Plan (7/15/20/30): " PLAN
                    RUSER="vendedor$(shuf -i 1000-9999 -n 1)"
                    CUSER="cliente$(shuf -i 1000-9999 -n 1)"
                    EXPIRE=$(date -d "+$PLAN days" +"%Y-%m-%d 23:59:59")
                    
                    useradd -M -s /bin/false -e "$(date -d "+$PLAN days" +%Y-%m-%d)" "$RUSER" && echo "$RUSER:mgvpn247" | chpasswd
                    useradd -M -s /bin/false -e "$(date -d "+$PLAN days" +%Y-%m-%d)" "$CUSER" && echo "$CUSER:mgvpn247" | chpasswd
                    
                    sqlite3 "$DB" "INSERT INTO resellers (phone, username, plan, expires_at, accounts_remaining, total_accounts) VALUES ('$PHONE', '$RUSER', '${PLAN}d', '$EXPIRE', 1, 1)"
                    sqlite3 "$DB" "INSERT INTO reseller_accounts (reseller_phone, username, expires_at, status) VALUES ('$PHONE', '$CUSER', '$EXPIRE', 'available')"
                    
                    echo -e "${GREEN}✅ Revendedor $RUSER creado con cuenta $CUSER${NC}"
                    ;;
            esac
            read -p "Presiona Enter..."
            ;;
        6)
            clear
            echo -e "${CYAN}🔑 CONFIGURAR MERCADOPAGO${NC}\n"
            read -p "Pega el Access Token: " NEW_TOKEN
            if [[ "$NEW_TOKEN" =~ ^APP_USR- ]] || [[ "$NEW_TOKEN" =~ ^TEST- ]]; then
                set_val '.mercadopago.access_token' "\"$NEW_TOKEN\""
                set_val '.mercadopago.enabled' "true"
                echo -e "${GREEN}✅ Token configurado${NC}"
                pm2 restart sshbot-pro
            else
                echo -e "${RED}❌ Token inválido${NC}"
            fi
            read -p "Presiona Enter..."
            ;;
        7)
            clear
            echo -e "${CYAN}💰 CAMBIAR PRECIOS REVENDEDORES${NC}\n"
            echo "Precios actuales:"
            echo "7d: $(get_val '.reseller_prices."7d"')"
            echo "15d: $(get_val '.reseller_prices."15d"')"
            echo "20d: $(get_val '.reseller_prices."20d"')"
            echo "30d: $(get_val '.reseller_prices."30d"')"
            echo ""
            read -p "Nuevo precio 7d: " P7
            read -p "Nuevo precio 15d: " P15
            read -p "Nuevo precio 20d: " P20
            read -p "Nuevo precio 30d: " P30
            [[ -n "$P7" ]] && set_val '.reseller_prices."7d"' "$P7"
            [[ -n "$P15" ]] && set_val '.reseller_prices."15d"' "$P15"
            [[ -n "$P20" ]] && set_val '.reseller_prices."20d"' "$P20"
            [[ -n "$P30" ]] && set_val '.reseller_prices."30d"' "$P30"
            echo -e "${GREEN}✅ Precios actualizados${NC}"
            read -p "Presiona Enter..."
            ;;
        8)
            clear
            echo -e "${CYAN}📊 ESTADÍSTICAS${NC}\n"
            
            echo "👥 USUARIOS NORMALES:"
            sqlite3 "$DB" "SELECT 'Activos: ' || COUNT(*) FROM users WHERE status=1"
            sqlite3 "$DB" "SELECT 'Expirados: ' || COUNT(*) FROM users WHERE status=0"
            
            echo -e "\n💼 REVENDEDORES:"
            sqlite3 "$DB" "SELECT 'Activos: ' || COUNT(*) FROM resellers WHERE status='active'"
            sqlite3 "$DB" "SELECT 'Cuentas disponibles: ' || COUNT(*) FROM reseller_accounts WHERE status='available'"
            sqlite3 "$DB" "SELECT 'Cuentas vendidas: ' || COUNT(*) FROM reseller_accounts WHERE status='sold'"
            
            echo -e "\n💰 PAGOS:"
            sqlite3 "$DB" "SELECT 'Pendientes: ' || COUNT(*) FROM payments WHERE status='pending'"
            sqlite3 "$DB" "SELECT 'Aprobados: ' || COUNT(*) FROM payments WHERE status='approved'"
            sqlite3 "$DB" "SELECT 'Pagos revendedor pendientes: ' || COUNT(*) FROM reseller_purchases_pending WHERE status='pending'"
            
            read -p "\nPresiona Enter..."
            ;;
        9)
            echo -e "\n${YELLOW}🧹 Limpiando sesión...${NC}"
            pm2 stop sshbot-pro
            rm -rf /root/.wppconnect/*
            echo -e "${GREEN}✅ Sesión limpiada${NC}"
            sleep 2
            ;;
        10)
            clear
            echo -e "${CYAN}💳 PAGOS PENDIENTES${NC}\n"
            echo "Pagos normales:"
            sqlite3 -column -header "$DB" "SELECT payment_id, phone, plan, amount, created_at FROM payments WHERE status='pending'"
            echo -e "\nPagos revendedores:"
            sqlite3 -column -header "$DB" "SELECT payment_id, phone, plan, price, created_at FROM reseller_purchases_pending WHERE status='pending'"
            read -p "\nPresiona Enter..."
            ;;
        0)
            echo -e "\n${GREEN}👋 Hasta pronto${NC}\n"
            exit 0
            ;;
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
║          🎉 INSTALACIÓN COMPLETADA 🎉                       ║
║                                                              ║
║       🤖 SSH BOT PRO - CON REVENDEDORES                     ║
║       💼 OPCIÓN 5 - SER REVENDEDOR                          ║
║                                                              ║
║       PRECIOS MAYORISTAS:                                   ║
║       🗓️ 7 días  = $1.700                                   ║
║       🗓️ 15 días = $2.500                                   ║
║       🗓️ 20 días = $3.500                                   ║
║       🗓️ 30 días = $4.500                                   ║
║                                                              ║
║       Al pagar, reciben:                                    ║
║       ✅ Usuario de revendedor                              ║
║       ✅ 1 cuenta para vender                               ║
║       ✅ Contraseña: mgvpn247                               ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Sistema instalado con revendedores${NC}"
echo -e "${GREEN}✅ Opción 5 - SER REVENDEDOR funcionando${NC}"
echo -e "${GREEN}✅ Pago automático por MercadoPago${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 COMANDOS:${NC}\n"
echo -e "  ${GREEN}sshbot${NC}         - Panel de control"
echo -e "  ${GREEN}pm2 logs sshbot-pro${NC} - Ver logs y QR"
echo -e ""

echo -e "${YELLOW}🚀 PRIMEROS PASOS:${NC}"
echo -e "  1. ${GREEN}pm2 logs sshbot-pro${NC} - Ver QR y escanear"
echo -e "  2. ${GREEN}sshbot${NC} - Configurar MercadoPago (opción 6)"
echo -e "  3. Enviar 'menu' al bot en WhatsApp"
echo -e "  4. Probar opción 5 - SER REVENDEDOR"
echo -e ""

echo -e "${YELLOW}💰 PROBAR REVENDEDOR:${NC}"
echo -e "  • Opción 5 en el menú"
echo -e "  • Elegir plan (7d=$1700, 15d=$2500, 20d=$3500, 30d=$4500)"
echo -e "  • Pagar con MercadoPago"
echo -e "  • Recibir usuario revendedor + cuenta para vender"
echo -e ""

read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}Mostrando logs...${NC}"
    echo -e "${YELLOW}📱 Espera que aparezca el QR para escanear...${NC}\n"
    sleep 2
    pm2 logs sshbot-pro
fi

exit 0