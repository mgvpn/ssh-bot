#!/bin/bash
# ================================================
# BOT WHATSAPP - HTTP CUSTOM CON HWID
# VERSIÓN: USUARIO HWID BOT 24/7
# MENÚ: COMPRAR | RENOVAR | EDITAR HWID | ARCHIVO.HC | PRUEBA | INFO
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
║     ██╗  ██╗██╗    ██╗██╗██████╗                             ║
║     ██║  ██║██║    ██║██║██╔══██╗                            ║
║     ███████║██║ █╗ ██║██║██║  ██║                            ║
║     ██╔══██║██║███╗██║██║██║  ██║                            ║
║     ██║  ██║╚███╔███╔╝██║██████╔╝                            ║
║     ╚═╝  ╚═╝ ╚══╝╚══╝ ╚═╝╚═════╝                             ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║          🤖 USUARIO HWID BOT 24/7                           ║
║          📱 VERIFICACIÓN POR HARDWARE ID                     ║
║          🔐 GENERACIÓN DE ARCHIVOS .HC                       ║
║          💰 MERCADOPAGO INTEGRADO                            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CARACTERÍSTICAS:${NC}"
echo -e "  📱 ${CYAN}Menú HWID 24/7${NC} - Compra, Renueva, Edita HWID"
echo -e "  🔐 ${YELLOW}Sistema de HWID${NC} - Verificación por hardware"
echo -e "  📁 ${PURPLE}Archivos .HC${NC} - Generación personalizada"
echo -e "  ⏰ ${BLUE}Prueba gratis${NC} - 2 horas de duración"
echo -e "  💰 ${GREEN}MercadoPago${NC} - Pagos automáticos"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Debes ejecutar como root${NC}"
    exit 1
fi

# Detectar IP
SERVER_IP=$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
[[ -z "$SERVER_IP" ]] && read -p "📝 Ingresa la IP del servidor: " SERVER_IP

echo -e "${GREEN}✅ IP: ${CYAN}$SERVER_IP${NC}\n"

read -p "$(echo -e "${YELLOW}¿Continuar instalación? (s/N): ${NC}")" -n 1 -r
echo
[[ ! $REPLY =~ ^[Ss]$ ]] && exit 0

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
apt-get install -y git curl wget sqlite3 jq build-essential cron ufw

# PM2
npm install -g pm2
pm2 update

# Configurar firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo -e "${GREEN}✅ Dependencias instaladas${NC}"

# ================================================
# PREPARAR ESTRUCTURA
# ================================================
echo -e "\n${CYAN}📁 Creando estructura...${NC}"

INSTALL_DIR="/opt/hwid-bot"
USER_HOME="/root/hwid-bot"
DB_FILE="$INSTALL_DIR/data/hwid.db"
CONFIG_FILE="$INSTALL_DIR/config/config.json"
HC_TEMPLATES="$INSTALL_DIR/templates"

# Limpiar anterior
pm2 delete hwid-bot 2>/dev/null || true
rm -rf "$INSTALL_DIR" "$USER_HOME" 2>/dev/null || true
rm -rf /root/.wppconnect 2>/dev/null || true

# Crear directorios
mkdir -p "$INSTALL_DIR"/{data,config,sessions,logs,hc_files,templates}
mkdir -p "$USER_HOME"
mkdir -p /root/.wppconnect
chmod -R 755 "$INSTALL_DIR"

# ================================================
# CREAR CONFIGURACIÓN
# ================================================
cat > "$CONFIG_FILE" << EOF
{
    "bot": {
        "name": "HWID Bot 24/7",
        "version": "3.0-HWID",
        "server_ip": "$SERVER_IP",
        "server_port": 8080
    },
    "prices": {
        "test_hours": 2,
        "price_7d": 3000,
        "price_15d": 4000,
        "price_30d": 7500,
        "price_50d": 10000,
        "currency": "ARS"
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false
    },
    "hwid": {
        "enabled": true,
        "max_per_user": 3
    },
    "links": {
        "app_download": "https://httpcustom.net/download",
        "support": "https://wa.me/543435071016"
    },
    "paths": {
        "database": "$DB_FILE",
        "hc_files": "$INSTALL_DIR/hc_files",
        "templates": "$HC_TEMPLATES",
        "sessions": "/root/.wppconnect"
    }
}
EOF

# ================================================
# CREAR BASE DE DATOS COMPLETA
# ================================================
sqlite3 "$DB_FILE" << 'SQL'
-- Tabla de usuarios HWID
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT NOT NULL,
    nombre TEXT,
    username TEXT UNIQUE,
    hwid TEXT UNIQUE,
    tipo TEXT DEFAULT 'test',
    expires_at DATETIME,
    status INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de pagos
CREATE TABLE payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_id TEXT UNIQUE,
    phone TEXT,
    username TEXT,
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

-- Tabla de pruebas diarias
CREATE TABLE daily_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    hwid TEXT,
    date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(phone, date)
);

-- Tabla de logs
CREATE TABLE logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT,
    message TEXT,
    data TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de estados de usuario
CREATE TABLE user_state (
    phone TEXT PRIMARY KEY,
    state TEXT DEFAULT 'main_menu',
    data TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_hwid ON users(hwid);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_preference ON payments(preference_id);
SQL

echo -e "${GREEN}✅ Base de datos creada${NC}"

# ================================================
# CREAR PLANTILLA DE ARCHIVO .HC
# ================================================
cat > "$HC_TEMPLATES/template.hc" << 'TEMPLATE'
# HTTP Custom Config
# Usuario: {username}
# HWID: {hwid}
# Expira: {expires}

[setting]
host = {server_ip}
port = 8080
method = ws
payload = 
bug = 
[payload]
[host]
[header]
Host: {server_ip}
X-HWID: {hwid}
X-User: {username}
User-Agent: HTTP Custom
Connection: Keep-Alive

[dns]
[split]
[rule]
HTTP = google.com
TEMPLATE

echo -e "${GREEN}✅ Plantilla .HC creada${NC}"

# ================================================
# CREAR BOT PRINCIPAL
# ================================================
echo -e "\n${CYAN}🤖 Creando bot con menú HWID...${NC}"

cd "$USER_HOME"

# package.json
cat > package.json << 'PKGEOF'
{
    "name": "hwid-bot",
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

npm install --silent 2>&1 | grep -v "npm WARN" || true

# ================================================
# BOT.JS COMPLETO CON MENÚ HWID
# ================================================
cat > "bot.js" << 'BOTEOF'
const wppconnect = require('@wppconnect-team/wppconnect');
const qrcode = require('qrcode-terminal');
const QRCode = require('qrcode');
const moment = require('moment');
const sqlite3 = require('sqlite3').verbose();
const chalk = require('chalk');
const cron = require('node-cron');
const fs = require('fs');
const path = require('path');
const axios = require('axios');

moment.locale('es');

console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════════════╗'));
console.log(chalk.cyan.bold('║         🤖 USUARIO HWID BOT 24/7 - HTTP CUSTOM              ║'));
console.log(chalk.cyan.bold('║              📱 VERIFICACIÓN POR HARDWARE ID                 ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

// Cargar configuración
function loadConfig() {
    delete require.cache[require.resolve('/opt/hwid-bot/config/config.json')];
    return require('/opt/hwid-bot/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/hwid-bot/data/hwid.db');

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
            console.log(chalk.green('✅ MercadoPago ACTIVO'));
        } catch (error) {
            mpEnabled = false;
        }
    }
}

initMercadoPago();

let client = null;

// ================================================
// FUNCIONES DE ESTADO
// ================================================
function getUserState(phone) {
    return new Promise((resolve) => {
        db.get('SELECT state, data FROM user_state WHERE phone = ?', [phone], (err, row) => {
            if (err || !row) resolve({ state: 'main_menu', data: null });
            else resolve({ state: row.state || 'main_menu', data: row.data ? JSON.parse(row.data) : null });
        });
    });
}

function setUserState(phone, state, data = null) {
    const dataStr = data ? JSON.stringify(data) : null;
    db.run(`INSERT OR REPLACE INTO user_state (phone, state, data, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)`, [phone, state, dataStr]);
}

function clearUserState(phone) {
    db.run('DELETE FROM user_state WHERE phone = ?', [phone]);
}

// ================================================
// FUNCIONES HWID
// ================================================
function generateUsername() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    let result = '';
    for (let i = 0; i < 8; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return `user_${result}`;
}

function validateHWID(hwid) {
    // Validar que HWID tenga al menos 10 caracteres alfanuméricos
    return /^[a-zA-Z0-9]{10,}$/.test(hwid);
}

function registerUser(phone, nombre, hwid, days) {
    return new Promise((resolve, reject) => {
        const username = generateUsername();
        const expires = moment().add(days, 'days').format('YYYY-MM-DD HH:mm:ss');
        const tipo = days === 0 ? 'test' : 'premium';
        
        db.run(`INSERT INTO users (phone, nombre, username, hwid, tipo, expires_at) VALUES (?, ?, ?, ?, ?, ?)`,
            [phone, nombre, username, hwid, tipo, expires],
            function(err) {
                if (err) resolve({ success: false, error: err.message });
                else {
                    // Generar archivo .hc
                    generateHCFile(username, hwid, expires);
                    resolve({ success: true, username, hwid, expires });
                }
            });
    });
}

function generateHCFile(username, hwid, expires) {
    const templatePath = '/opt/hwid-bot/templates/template.hc';
    const outputPath = `/opt/hwid-bot/hc_files/${username}.hc`;
    
    if (!fs.existsSync(templatePath)) {
        console.log(chalk.red('❌ Plantilla no encontrada'));
        return false;
    }
    
    let template = fs.readFileSync(templatePath, 'utf8');
    template = template.replace(/{username}/g, username);
    template = template.replace(/{hwid}/g, hwid);
    template = template.replace(/{expires}/g, moment(expires).format('DD/MM/YYYY HH:mm'));
    template = template.replace(/{server_ip}/g, config.bot.server_ip);
    
    fs.writeFileSync(outputPath, template);
    console.log(chalk.green(`✅ Archivo .HC generado: ${username}.hc`));
    return true;
}

function checkUserExistsByHWID(hwid) {
    return new Promise((resolve) => {
        db.get('SELECT * FROM users WHERE hwid = ? AND status = 1', [hwid], (err, row) => {
            resolve(!err && row);
        });
    });
}

function getUserByPhone(phone) {
    return new Promise((resolve) => {
        db.all('SELECT username, hwid, expires_at, tipo FROM users WHERE phone = ? AND status = 1', [phone], (err, rows) => {
            resolve(err ? [] : rows);
        });
    });
}

function renewUser(phone, username, additionalDays) {
    return new Promise((resolve) => {
        db.get('SELECT username, hwid, expires_at FROM users WHERE phone = ? AND username = ? AND status = 1', [phone, username], async (err, user) => {
            if (err || !user) {
                resolve({ success: false, error: 'Usuario no encontrado' });
                return;
            }
            
            const newExpiry = moment(user.expires_at).add(additionalDays, 'days');
            const newExpiryStr = newExpiry.format('YYYY-MM-DD HH:mm:ss');
            
            db.run(`UPDATE users SET expires_at = ?, tipo = 'premium' WHERE phone = ? AND username = ?`, [newExpiryStr, phone, username]);
            
            // Regenerar archivo .hc
            generateHCFile(user.username, user.hwid, newExpiryStr);
            
            resolve({ success: true, username: user.username, newExpiry: newExpiryStr, daysAdded: additionalDays });
        });
    });
}

function editHWID(phone, username, newHWID) {
    return new Promise((resolve) => {
        db.get('SELECT username FROM users WHERE phone = ? AND username = ? AND status = 1', [phone, username], async (err, user) => {
            if (err || !user) {
                resolve({ success: false, error: 'Usuario no encontrado' });
                return;
            }
            
            // Verificar que el nuevo HWID no esté en uso
            const exists = await checkUserExistsByHWID(newHWID);
            if (exists) {
                resolve({ success: false, error: 'HWID ya está registrado' });
                return;
            }
            
            db.run(`UPDATE users SET hwid = ? WHERE phone = ? AND username = ?`, [newHWID, phone, username]);
            
            // Regenerar archivo .hc con nuevo HWID
            db.get('SELECT username, hwid, expires_at FROM users WHERE phone = ? AND username = ?', [phone, username], (err, updatedUser) => {
                if (updatedUser) {
                    generateHCFile(updatedUser.username, updatedUser.hwid, updatedUser.expires_at);
                }
            });
            
            resolve({ success: true, username, newHWID });
        });
    });
}

function canCreateTest(phone, hwid) {
    return new Promise((resolve) => {
        const today = moment().format('YYYY-MM-DD');
        db.get('SELECT COUNT(*) as count FROM daily_tests WHERE phone = ? AND date = ?', [phone, today], (err, row) => {
            if (err || (row && row.count > 0)) resolve(false);
            else resolve(true);
        });
    });
}

function registerTest(phone, hwid) {
    db.run('INSERT INTO daily_tests (phone, hwid, date) VALUES (?, ?, ?)', [phone, hwid, moment().format('YYYY-MM-DD')]);
}

// ================================================
// CREAR PAGO MERCADOPAGO
// ================================================
async function createPayment(phone, username, hwid, days, amount, planName, isRenewal = false) {
    if (!mpEnabled) return { success: false, error: 'MercadoPago no configurado' };
    
    const paymentId = `${isRenewal ? 'RENEW' : 'HWID'}-${Date.now()}-${Math.random().toString(36).substr(2, 6)}`;
    
    try {
        const preferenceData = {
            items: [{
                title: isRenewal ? `RENOVACIÓN HWID ${days} DÍAS` : `HWID PREMIUM ${days} DÍAS`,
                quantity: 1,
                currency_id: config.prices.currency,
                unit_price: parseFloat(amount)
            }],
            external_reference: paymentId,
            back_urls: {
                success: `https://wa.me/${phone.replace('@c.us', '')}`,
                failure: `https://wa.me/${phone.replace('@c.us', '')}`
            },
            auto_return: 'approved'
        };
        
        const response = await mpPreference.create({ body: preferenceData });
        
        if (response && response.id) {
            const qrPath = `/opt/hwid-bot/logs/${paymentId}.png`;
            await QRCode.toFile(qrPath, response.init_point);
            
            db.run(`INSERT INTO payments (payment_id, phone, username, hwid, plan, days, amount, status, payment_url, qr_code, preference_id, is_renewal) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?)`,
                [paymentId, phone, username, hwid, `${days}d`, days, amount, response.init_point, qrPath, response.id, isRenewal ? 1 : 0]);
            
            return { success: true, paymentUrl: response.init_point, qrPath, amount };
        }
        return { success: false, error: 'Error creando pago' };
    } catch (error) {
        return { success: false, error: error.message };
    }
}

// ================================================
// VERIFICAR PAGOS
// ================================================
async function checkPayments() {
    if (!mpEnabled) return;
    
    db.all('SELECT * FROM payments WHERE status = "pending"', async (err, payments) => {
        if (err || !payments) return;
        
        for (const payment of payments) {
            try {
                const response = await axios.get(`https://api.mercadopago.com/v1/payments/search?external_reference=${payment.payment_id}`, {
                    headers: { 'Authorization': `Bearer ${config.mercadopago.access_token}` }
                });
                
                if (response.data.results && response.data.results[0]?.status === 'approved') {
                    db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`, [payment.payment_id]);
                    
                    if (payment.is_renewal) {
                        const result = await renewUser(payment.phone, payment.username, payment.days);
                        if (result.success && client) {
                            await client.sendText(payment.phone, `✅ *RENOVACIÓN CONFIRMADA*\n\n🎉 Usuario: ${result.username}\n📅 Nueva expiración: ${moment(result.newExpiry).format('DD/MM/YYYY HH:mm')}\n\n📁 Envía *4* para descargar tu archivo .HC`);
                        }
                    } else {
                        const result = await registerUser(payment.phone, payment.username || 'Usuario', payment.hwid, payment.days);
                        if (result.success && client) {
                            await client.sendText(payment.phone, `✅ *PAGO CONFIRMADO*\n\n👤 Usuario: ${result.username}\n🔑 HWID: ${result.hwid}\n📅 Expira: ${moment(result.expires).format('DD/MM/YYYY HH:mm')}\n\n📁 Envía *4* para descargar tu archivo .HC`);
                        }
                    }
                }
            } catch (error) {
                console.error(chalk.red(`Error: ${error.message}`));
            }
        }
    });
}

// ================================================
// MENÚ PRINCIPAL
// ================================================
const MENU_PRINCIPAL = `🤖 *USUARIO HWID BOT 24/7*
━━━━━━━━━━━━━━━━━━━━━━
🛍️ *BIENVENIDO AL PANEL*

1️⃣┆🛒 COMPRAR USUARIO HWID
2️⃣┆🔄 RENOVAR USUARIO HWID
3️⃣┆🛠️ EDITAR HWID
4️⃣┆📂 ARCHIVO.HC
5️⃣┆⏱️ PRUEBA GRATIS 
6️⃣┆📚 INFO Y AYUDA 

━━━━━━━━━━━━━━━━━━━━━━
⚠️ _Escribe *menu* para volver atras_ ⚠️`;

// ================================================
// INICIALIZAR BOT
// ================================================
async function initBot() {
    try {
        client = await wppconnect.create({
            session: 'hwid-bot-session',
            headless: true,
            useChrome: true,
            browserArgs: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
            puppeteerOptions: {
                executablePath: '/usr/bin/google-chrome',
                headless: 'new',
                args: ['--no-sandbox']
            },
            disableWelcome: true
        });
        
        console.log(chalk.green('✅ Bot conectado!'));
        
        client.onMessage(async (message) => {
            const text = message.body.trim();
            const from = message.from;
            
            console.log(chalk.cyan(`📩 [${from}]: ${text.substring(0, 50)}`));
            
            const userState = await getUserState(from);
            
            // Comando menu
            if (text.toLowerCase() === 'menu' || text.toLowerCase() === 'menu') {
                await setUserState(from, 'main_menu');
                await client.sendText(from, MENU_PRINCIPAL);
                return;
            }
            
            // Menú principal
            if (userState.state === 'main_menu') {
                switch(text) {
                    case '1': // COMPRAR
                        await setUserState(from, 'buy_name');
                        await client.sendText(from, `🛒 *COMPRAR USUARIO HWID*\n\n📝 Escribe tu NOMBRE:\n\n_Ejemplo: Juan Perez_\n\n0️⃣ Para cancelar`);
                        break;
                        
                    case '2': // RENOVAR
                        const users = await getUserByPhone(from);
                        if (users.length === 0) {
                            await client.sendText(from, `❌ No tienes usuarios activos.\n\nUsa opción 5 para PRUEBA GRATIS o opción 1 para COMPRAR`);
                        } else {
                            let list = `🔄 *RENOVAR USUARIO HWID*\n\nSelecciona el usuario a renovar:\n\n`;
                            users.forEach((u, i) => {
                                list += `${i+1}️⃣ ┆ ${u.username}\n   📅 Expira: ${moment(u.expires_at).format('DD/MM/YYYY HH:mm')}\n\n`;
                            });
                            list += `0️⃣ ┆ Cancelar`;
                            await setUserState(from, 'renew_select', { users });
                            await client.sendText(from, list);
                        }
                        break;
                        
                    case '3': // EDITAR HWID
                        const userList = await getUserByPhone(from);
                        if (userList.length === 0) {
                            await client.sendText(from, `❌ No tienes usuarios activos para editar HWID`);
                        } else {
                            let list = `🛠️ *EDITAR HWID*\n\nSelecciona el usuario:\n\n`;
                            userList.forEach((u, i) => {
                                list += `${i+1}️⃣ ┆ ${u.username}\n   🔑 HWID: ${u.hwid}\n\n`;
                            });
                            list += `0️⃣ ┆ Cancelar`;
                            await setUserState(from, 'edit_select', { users: userList });
                            await client.sendText(from, list);
                        }
                        break;
                        
                    case '4': // ARCHIVO .HC
                        const hcUsers = await getUserByPhone(from);
                        if (hcUsers.length === 0) {
                            await client.sendText(from, `❌ No tienes usuarios activos.\n\nUsa opción 5 para PRUEBA GRATIS`);
                        } else if (hcUsers.length === 1) {
                            const filePath = `/opt/hwid-bot/hc_files/${hcUsers[0].username}.hc`;
                            if (fs.existsSync(filePath)) {
                                await client.sendFile(from, filePath, `${hcUsers[0].username}.hc`, `📁 *ARCHIVO .HC*\n\n👤 Usuario: ${hcUsers[0].username}\n📅 Expira: ${moment(hcUsers[0].expires_at).format('DD/MM/YYYY HH:mm')}`);
                            } else {
                                await client.sendText(from, `❌ Archivo no encontrado. Contacta al administrador.`);
                            }
                        } else {
                            let list = `📂 *ARCHIVO .HC*\n\nSelecciona el usuario:\n\n`;
                            hcUsers.forEach((u, i) => {
                                list += `${i+1}️⃣ ┆ ${u.username}\n   📅 Expira: ${moment(u.expires_at).format('DD/MM/YYYY')}\n\n`;
                            });
                            list += `0️⃣ ┆ Cancelar`;
                            await setUserState(from, 'download_select', { users: hcUsers });
                            await client.sendText(from, list);
                        }
                        break;
                        
                    case '5': // PRUEBA GRATIS
                        await setUserState(from, 'test_name');
                        await client.sendText(from, `⏱️ *PRUEBA GRATIS*\n\n📝 Escribe tu NOMBRE:\n\n_Ejemplo: Carlos Lopez_\n\n0️⃣ Para cancelar`);
                        break;
                        
                    case '6': // INFO
                        await client.sendText(from, `📚 *INFO Y AYUDA*\n\n🔹 *¿Qué es HWID?*\nEs un identificador único de tu dispositivo\n\n🔹 *¿Cómo obtener mi HWID?*\nAbre HTTP Custom → Ajustes → Ver HWID\n\n🔹 *Planes disponibles:*\n• 7 días - $${config.prices.price_7d}\n• 15 días - $${config.prices.price_15d}\n• 30 días - $${config.prices.price_30d}\n• 50 días - $${config.prices.price_50d}\n\n🔹 *Soporte:* ${config.links.support}`);
                        break;
                        
                    default:
                        await client.sendText(from, MENU_PRINCIPAL);
                }
                return;
            }
            
            // FLUJO: COMPRAR (Nombre → HWID → Plan → Pago)
            if (userState.state === 'buy_name') {
                if (text === '0') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, MENU_PRINCIPAL);
                } else {
                    await setUserState(from, 'buy_hwid', { nombre: text });
                    await client.sendText(from, `✅ Nombre: ${text}\n\n🔑 Envía tu *HWID* (Hardware ID):\n\n_Puedes obtenerlo en HTTP Custom → Ajustes_\n\n0️⃣ Para cancelar`);
                }
                return;
            }
            
            if (userState.state === 'buy_hwid') {
                if (text === '0') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, MENU_PRINCIPAL);
                } else if (!validateHWID(text)) {
                    await client.sendText(from, `❌ HWID inválido. Debe tener al menos 10 caracteres alfanuméricos.\n\nRevisa tu HWID y vuelve a enviarlo:\n\n0️⃣ Para cancelar`);
                } else {
                    const exists = await checkUserExistsByHWID(text);
                    if (exists) {
                        await client.sendText(from, `❌ Este HWID ya está registrado.\n\nSi es tuyo, usa opción 2 para RENOVAR.\n\n0️⃣ Para cancelar`);
                    } else {
                        await setUserState(from, 'buy_plan', { nombre: userState.data.nombre, hwid: text });
                        await client.sendText(from, `✅ HWID: ${text}\n\n🛍️ *SELECCIONA TU PLAN*\n\n1️⃣ ┆ 7 DÍAS - $${config.prices.price_7d}\n2️⃣ ┆ 15 DÍAS - $${config.prices.price_15d}\n3️⃣ ┆ 30 DÍAS - $${config.prices.price_30d}\n4️⃣ ┆ 50 DÍAS - $${config.prices.price_50d}\n\n0️⃣ ┆ Cancelar`);
                    }
                }
                return;
            }
            
            if (userState.state === 'buy_plan') {
                const planMap = {
                    '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                    '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' },
                    '3': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                    '4': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                };
                
                if (text === '0') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, MENU_PRINCIPAL);
                } else if (planMap[text]) {
                    const plan = planMap[text];
                    const { nombre, hwid } = userState.data;
                    
                    if (mpEnabled) {
                        await client.sendText(from, `⏳ Generando pago...`);
                        const payment = await createPayment(from, nombre, hwid, plan.days, plan.price, plan.name);
                        
                        if (payment.success) {
                            await client.sendText(from, `🛍️ *PLAN ${plan.name}*\n💰 Precio: $${payment.amount}\n\n🔗 *LINK DE PAGO:*\n${payment.paymentUrl}\n\n⏰ Válido por 24 horas\n\n✅ Una vez pagado, recibirás tu archivo .HC automáticamente`);
                            if (fs.existsSync(payment.qrPath)) {
                                await client.sendImage(from, payment.qrPath, 'qr.jpg', `Escanea con MercadoPago\n${plan.name} - $${payment.amount}`);
                            }
                        } else {
                            await client.sendText(from, `❌ Error: ${payment.error}\n\nContacta al administrador: ${config.links.support}`);
                        }
                    } else {
                        await client.sendText(from, `⚠️ Pago manual. Contacta al administrador:\n${config.links.support}\n\nDatos:\nNombre: ${nombre}\nHWID: ${hwid}\nPlan: ${plan.name}`);
                    }
                    await setUserState(from, 'main_menu');
                } else {
                    await client.sendText(from, `❌ Opción inválida. Elige 1-4 o 0 para cancelar`);
                }
                return;
            }
            
            // FLUJO: PRUEBA GRATIS (Nombre → HWID)
            if (userState.state === 'test_name') {
                if (text === '0') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, MENU_PRINCIPAL);
                } else {
                    await setUserState(from, 'test_hwid', { nombre: text });
                    await client.sendText(from, `✅ Nombre: ${text}\n\n🔑 Envía tu *HWID* para la prueba de 2 horas:\n\n0️⃣ Para cancelar`);
                }
                return;
            }
            
            if (userState.state === 'test_hwid') {
                if (text === '0') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, MENU_PRINCIPAL);
                } else if (!validateHWID(text)) {
                    await client.sendText(from, `❌ HWID inválido. Debe tener al menos 10 caracteres alfanuméricos.\n\nRevisa tu HWID y vuelve a enviarlo:\n\n0️⃣ Para cancelar`);
                } else {
                    const canTest = await canCreateTest(from, text);
                    if (!canTest) {
                        await client.sendText(from, `⚠️ YA USASTE TU PRUEBA HOY\n\n⏳ Vuelve mañana para otra prueba gratuita de 2 horas`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    const exists = await checkUserExistsByHWID(text);
                    if (exists) {
                        await client.sendText(from, `❌ Este HWID ya tiene una cuenta activa.\n\nUsa opción 2 para RENOVAR`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    await client.sendText(from, `⏳ Creando cuenta de prueba...`);
                    
                    const result = await registerUser(from, userState.data.nombre, text, 0);
                    
                    if (result.success) {
                        registerTest(from, text);
                        const filePath = `/opt/hwid-bot/hc_files/${result.username}.hc`;
                        await client.sendText(from, `✅ *PRUEBA GRATIS CREADA*\n\n👤 Usuario: ${result.username}\n🔑 HWID: ${result.hwid}\n⏰ Expira en: ${config.prices.test_hours} horas\n\n📁 Envía *4* para descargar tu archivo .HC`);
                        
                        if (fs.existsSync(filePath)) {
                            await client.sendFile(from, filePath, `${result.username}.hc`, `📁 *TU ARCHIVO .HC*\n\nImporta este archivo en HTTP Custom`);
                        }
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    await setUserState(from, 'main_menu');
                }
                return;
            }
            
            // FLUJO: RENOVAR
            if (userState.state === 'renew_select') {
                if (text === '0') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, MENU_PRINCIPAL);
                } else {
                    const idx = parseInt(text) - 1;
                    const users = userState.data.users;
                    if (idx >= 0 && idx < users.length) {
                        await setUserState(from, 'renew_plan', { username: users[idx].username });
                        await client.sendText(from, `🔄 *RENOVAR*: ${users[idx].username}\n\n📅 Expira actual: ${moment(users[idx].expires_at).format('DD/MM/YYYY HH:mm')}\n\n📆 *SELECCIONA DÍAS A RENOVAR*\n\n1️⃣ ┆ +7 DÍAS - $${config.prices.price_7d}\n2️⃣ ┆ +15 DÍAS - $${config.prices.price_15d}\n3️⃣ ┆ +30 DÍAS - $${config.prices.price_30d}\n4️⃣ ┆ +50 DÍAS - $${config.prices.price_50d}\n\n0️⃣ ┆ Cancelar`);
                    } else {
                        await client.sendText(from, `❌ Opción inválida`);
                    }
                }
                return;
            }
            
            if (userState.state === 'renew_plan') {
                const planMap = {
                    '1': { days: 7, price: config.prices.price_7d },
                    '2': { days: 15, price: config.prices.price_15d },
                    '3': { days: 30, price: config.prices.price_30d },
                    '4': { days: 50, price: config.prices.price_50d }
                };
                
                if (text === '0') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, MENU_PRINCIPAL);
                } else if (planMap[text]) {
                    const plan = planMap[text];
                    const { username } = userState.data;
                    
                    if (mpEnabled) {
                        await client.sendText(from, `⏳ Generando pago de renovación...`);
                        const payment = await createPayment(from, username, '', plan.days, plan.price, `${plan.days} DÍAS`, true);
                        
                        if (payment.success) {
                            await client.sendText(from, `🔄 *RENOVACIÓN*\n👤 Usuario: ${username}\n📆 +${plan.days} DÍAS\n💰 Precio: $${payment.amount}\n\n🔗 *LINK DE PAGO:*\n${payment.paymentUrl}\n\n✅ Una vez pagado, se renovará automáticamente`);
                        } else {
                            await client.sendText(from, `❌ Error: ${payment.error}`);
                        }
                    } else {
                        await client.sendText(from, `🔄 RENOVACIÓN: +${plan.days} días\n💰 Precio: $${plan.price}\n\nContacta al administrador: ${config.links.support}`);
                    }
                    await setUserState(from, 'main_menu');
                }
                return;
            }
            
            // FLUJO: EDITAR HWID
            if (userState.state === 'edit_select') {
                if (text === '0') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, MENU_PRINCIPAL);
                } else {
                    const idx = parseInt(text) - 1;
                    const users = userState.data.users;
                    if (idx >= 0 && idx < users.length) {
                        await setUserState(from, 'edit_new_hwid', { username: users[idx].username });
                        await client.sendText(from, `🛠️ *EDITAR HWID*\n\n👤 Usuario: ${users[idx].username}\n🔑 HWID actual: ${users[idx].hwid}\n\n📝 Envía tu NUEVO HWID:\n\n0️⃣ Para cancelar`);
                    } else {
                        await client.sendText(from, `❌ Opción inválida`);
                    }
                }
                return;
            }
            
            if (userState.state === 'edit_new_hwid') {
                if (text === '0') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, MENU_PRINCIPAL);
                } else if (!validateHWID(text)) {
                    await client.sendText(from, `❌ HWID inválido. Debe tener al menos 10 caracteres alfanuméricos.\n\nRevisa tu HWID y vuelve a enviarlo:\n\n0️⃣ Para cancelar`);
                } else {
                    const result = await editHWID(from, userState.data.username, text);
                    if (result.success) {
                        await client.sendText(from, `✅ *HWID ACTUALIZADO*\n\n👤 Usuario: ${result.username}\n🔑 Nuevo HWID: ${result.newHWID}\n\n📁 Envía *4* para descargar tu nuevo archivo .HC`);
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    await setUserState(from, 'main_menu');
                }
                return;
            }
            
            // FLUJO: DESCARGAR ARCHIVO
            if (userState.state === 'download_select') {
                if (text === '0') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, MENU_PRINCIPAL);
                } else {
                    const idx = parseInt(text) - 1;
                    const users = userState.data.users;
                    if (idx >= 0 && idx < users.length) {
                        const filePath = `/opt/hwid-bot/hc_files/${users[idx].username}.hc`;
                        if (fs.existsSync(filePath)) {
                            await client.sendFile(from, filePath, `${users[idx].username}.hc`, `📁 *ARCHIVO .HC*\n\n👤 Usuario: ${users[idx].username}\n📅 Expira: ${moment(users[idx].expires_at).format('DD/MM/YYYY HH:mm')}`);
                        } else {
                            await client.sendText(from, `❌ Archivo no encontrado. Regenerando...`);
                            generateHCFile(users[idx].username, users[idx].hwid, users[idx].expires_at);
                            if (fs.existsSync(filePath)) {
                                await client.sendFile(from, filePath, `${users[idx].username}.hc`, `📁 *ARCHIVO .HC REGENERADO*`);
                            } else {
                                await client.sendText(from, `❌ Error. Contacta al administrador.`);
                            }
                        }
                    } else {
                        await client.sendText(from, `❌ Opción inválida`);
                    }
                    await setUserState(from, 'main_menu');
                }
                return;
            }
        });
        
        // CRON JOBS
        cron.schedule('*/2 * * * *', () => checkPayments());
        
        cron.schedule('0 * * * *', () => {
            const now = moment().format('YYYY-MM-DD HH:mm:ss');
            db.all('SELECT username FROM users WHERE expires_at < ? AND status = 1', [now], (err, rows) => {
                if (rows) {
                    rows.forEach(row => {
                        db.run('UPDATE users SET status = 0 WHERE username = ?', [row.username]);
                        console.log(chalk.yellow(`🗑️ Usuario expirado: ${row.username}`));
                    });
                }
            });
        });
        
    } catch (error) {
        console.error(chalk.red('❌ Error:'), error.message);
        setTimeout(initBot, 10000);
    }
}

initBot();

process.on('SIGINT', async () => {
    console.log(chalk.yellow('\n🛑 Cerrando...'));
    if (client) await client.close();
    process.exit();
});
BOTEOF

echo -e "${GREEN}✅ Bot creado con menú HWID${NC}"

# ================================================
# CREAR PANEL DE CONTROL
# ================================================
cat > /usr/local/bin/hwidbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

DB="/opt/hwid-bot/data/hwid.db"
CONFIG="/opt/hwid-bot/config/config.json"

while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              🎛️ PANEL HWID BOT 24/7                         ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    
    TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1" 2>/dev/null || echo "0")
    STATUS=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.name=="hwid-bot") | .pm2_env.status' 2>/dev/null || echo "stopped")
    
    echo -e "${YELLOW}📊 ESTADO${NC}"
    echo -e "  Bot: $([ "$STATUS" == "online" ] && echo "${GREEN}● ACTIVO${NC}" || echo "${RED}● DETENIDO${NC}")"
    echo -e "  Usuarios: ${CYAN}$ACTIVE/$TOTAL${NC}\n"
    
    echo -e "${CYAN}[1] Iniciar bot    [2] Detener bot    [3] Ver logs"
    echo -e "${CYAN}[4] Ver usuarios   [5] Estadísticas   [6] Configurar MP"
    echo -e "${CYAN}[0] Salir${NC}\n"
    read -p "👉 Opción: " OPT
    
    case $OPT in
        1) cd /root/hwid-bot && pm2 restart hwid-bot 2>/dev/null || pm2 start bot.js --name hwid-bot; pm2 save; sleep 2;;
        2) pm2 stop hwid-bot; sleep 1;;
        3) pm2 logs hwid-bot --lines 50;;
        4) sqlite3 -column -header "$DB" "SELECT username, phone, hwid, tipo, expires_at FROM users WHERE status=1 ORDER BY expires_at"; read -p "Enter...";;
        5) clear; echo -e "${CYAN}📊 ESTADÍSTICAS${NC}\n"; echo "Total usuarios: $(sqlite3 "$DB" "SELECT COUNT(*) FROM users")"; echo "Activos: $(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1")"; echo "Pruebas hoy: $(sqlite3 "$DB" "SELECT COUNT(*) FROM daily_tests WHERE date=date('now')")"; echo "Pagos: $(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='approved'")"; read -p "Enter...";;
        6) read -p "Token MP (APP_USR-xxx): " TOKEN; jq ".mercadopago.access_token = \"$TOKEN\" | .mercadopago.enabled = true" "$CONFIG" > tmp && mv tmp "$CONFIG"; echo -e "${GREEN}✅ Token guardado. Reinicia el bot${NC}"; read -p "Enter...";;
        0) echo -e "${GREEN}👋 Hasta luego${NC}"; exit 0;;
    esac
done
PANELEOF

chmod +x /usr/local/bin/hwidbot

# ================================================
# INICIAR BOT
# ================================================
cd "$USER_HOME"
pm2 start bot.js --name hwid-bot
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
║          🎉 INSTALACIÓN COMPLETADA - HWID BOT 24/7 🎉       ║
║                                                              ║
║       ✅ Menú con 6 opciones funcionando                    ║
║       ✅ Sistema de HWID implementado                       ║
║       ✅ Generación de archivos .HC                         ║
║       ✅ Prueba gratis de 2 horas                           ║
║       ✅ Renovación y edición de HWID                       ║
║       ✅ MercadoPago integrado                              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${GREEN}✅ Instalación completa${NC}"
echo -e ""
echo -e "${YELLOW}📋 COMANDOS:${NC}"
echo -e "  ${GREEN}hwidbot${NC}        - Panel de control"
echo -e "  ${GREEN}pm2 logs hwid-bot${NC} - Ver QR y logs"
echo -e ""
echo -e "${YELLOW}🚀 PRIMEROS PASOS:${NC}"
echo -e "  1. ${GREEN}pm2 logs hwid-bot${NC} - Esperar QR"
echo -e "  2. Escanear QR con WhatsApp"
echo -e "  3. Enviar 'menu' al bot"
echo -e "  4. Probar opción 5 (Prueba gratis)"
echo -e "  5. Configurar MercadoPago con ${GREEN}hwidbot${NC} opción 6"
echo -e ""

read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    pm2 logs hwid-bot
fi

exit 0