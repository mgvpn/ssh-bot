#!/bin/bash
# ================================================
# SSH BOT PRO REVENDEDORES - TESTS ILIMITADOS
# VERSIÓN: Tests sin límite diario
# CONTRASEÑA USUARIOS: cloudvpn (FIJA)
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
║     ███████╗███████╗██║  ██║    ██████╗  ██████╗ ████████╗  ║
║     ██╔════╝██╔════╝██║  ██║    ██╔══██╗██╔═══██╗╚══██╔══╝  ║
║     ███████╗███████╗███████║    ██████╔╝██║   ██║   ██║     ║
║     ╚════██║╚════██║██╔══██║    ██╔══██╗██║   ██║   ██║     ║
║     ███████║███████║██║  ██║    ██████╔╝╚██████╔╝   ██║     ║
║     ╚══════╝╚══════╝╚═╝  ╚═╝    ╚═════╝  ╚═════╝    ╚═╝     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║          🤖 SSH BOT PRO - SISTEMA DE REVENDEDORES          ║
║               🔐 CADA REVENDEDOR CON SU CLAVE              ║
║               🔑 CONTRASEÑA USUARIOS: cloudvpn             ║
║               🎁 TESTS ILIMITADOS (SIN RESTRICCIÓN)       ║
║               💰 PANEL ADMINISTRADOR COMPLETO              ║
║               📊 CONTROL DE COMISIONES Y VENTAS            ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CARACTERÍSTICAS DEL SISTEMA:${NC}"
echo -e "  🔐 ${CYAN}Cada revendedor${NC} - Contraseña única personalizada"
echo -e "  🔑 ${GREEN}Contraseña usuarios${NC} - cloudvpn (FIJA)"
echo -e "  🎁 ${YELLOW}TESTS ILIMITADOS${NC} - Sin límite diario"
echo -e "  💰 ${PURPLE}Comisiones${NC} - Control de ventas por revendedor"
echo -e "  📊 ${BLUE}Estadísticas${NC} - Ventas y usuarios por revendedor"
echo -e "  🎛️  ${CYAN}Panel Admin${NC} - Crear y gestionar revendedores"
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
APK_PATH="/root/mgvpn.apk"

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
        "name": "SSH Bot Pro Revendedores",
        "version": "3.0-REVENDEDORES-TESTS-ILIMITADOS",
        "server_ip": "$SERVER_IP",
        "default_password": "cloudvpn"
    },
    "prices": {
        "test_hours": 2,
        "price_7d": 3000.00,
        "price_15d": 4000.00,
        "price_30d": 7000.00,
        "price_50d": 10000.00,
        "currency": "ARS"
    },
    "commission": {
        "type": "percentage",
        "value": 20
    },
    "tests": {
        "unlimited": true,
        "test_hours": 2
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false,
        "public_key": ""
    },
    "paths": {
        "database": "$DB_FILE",
        "qr_codes": "$INSTALL_DIR/qr_codes",
        "sessions": "/root/.wppconnect",
        "apk_file": "$APK_PATH"
    }
}
EOF

# Crear base de datos - SIN restricción de tests diarios
sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    username TEXT UNIQUE,
    password TEXT DEFAULT 'cloudvpn',
    tipo TEXT DEFAULT 'test',
    expires_at DATETIME,
    status INTEGER DEFAULT 1,
    created_by TEXT,
    reseller_id INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE resellers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
    password TEXT,
    name TEXT,
    phone TEXT,
    commission_type TEXT DEFAULT 'percentage',
    commission_value REAL DEFAULT 20,
    status INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_id TEXT UNIQUE,
    phone TEXT,
    plan TEXT,
    days INTEGER,
    amount REAL,
    status TEXT DEFAULT 'pending',
    reseller_id INTEGER,
    commission REAL,
    payment_url TEXT,
    qr_code TEXT,
    preference_id TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    approved_at DATETIME
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
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_reseller ON users(reseller_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_reseller ON payments(reseller_id);
SQL

echo -e "${GREEN}✅ Estructura creada (tests ilimitados)${NC}"

# Crear usuario admin por defecto
ADMIN_PASS="admin123"
sqlite3 "$DB_FILE" << SQL
INSERT OR REPLACE INTO resellers (username, password, name, phone, commission_type, commission_value, status) 
VALUES ('admin', '$ADMIN_PASS', 'Administrador', '0000000000', 'percentage', 0, 1);
SQL

echo -e "${GREEN}✅ Admin creado: usuario 'admin', contraseña '$ADMIN_PASS'${NC}"

# ================================================
# CREAR BOT CON TESTS ILIMITADOS
# ================================================
echo -e "\n${CYAN}🤖 Creando bot con tests ilimitados...${NC}"

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

# Crear bot.js con TESTS ILIMITADOS
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
console.log(chalk.cyan.bold('║      🤖 SSH BOT PRO - TESTS ILIMITADOS                       ║'));
console.log(chalk.cyan.bold('║              🔐 CONTRASEÑA: cloudvpn                        ║'));
console.log(chalk.cyan.bold('║                    🎁 TESTS SIN LÍMITE                      ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

function loadConfig() {
    delete require.cache[require.resolve('/opt/sshbot-pro/config/config.json')];
    return require('/opt/sshbot-pro/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/sshbot-pro/data/users.db');

// Variables globales
let client = null;

// Funciones auxiliares
function generateUsername() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    const randomNum = Math.floor(1000 + Math.random() * 9000);
    const randomChar = chars.charAt(Math.floor(Math.random() * chars.length));
    return `test${randomChar}${randomNum}`;
}

function generatePremiumUsername() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    const randomNum = Math.floor(1000 + Math.random() * 9000);
    const randomChar = chars.charAt(Math.floor(Math.random() * chars.length));
    return `user${randomChar}${randomNum}`;
}

const DEFAULT_PASSWORD = 'cloudvpn';

async function createSSHUser(phone, username, days, resellerId = null) {
    const password = DEFAULT_PASSWORD;
    
    if (days === 0) {
        // Test - duración configurable
        const expireFull = moment().add(config.prices.test_hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
        
        try {
            await execPromise(`useradd -m -s /bin/bash ${username} && echo "${username}:${password}" | chpasswd`);
            
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at, created_by, reseller_id) VALUES (?, ?, ?, 'test', ?, ?, ?)`,
                [phone, username, password, expireFull, 'test', resellerId]);
            
            return { success: true, username, password, expires: expireFull };
        } catch (error) {
            console.error(chalk.red('❌ Error:'), error.message);
            return { success: false, error: error.message };
        }
    } else {
        // Premium
        const expireFull = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
        
        try {
            await execPromise(`useradd -M -s /bin/false -e ${moment().add(days, 'days').format('YYYY-MM-DD')} ${username} && echo "${username}:${password}" | chpasswd`);
            
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at, created_by, reseller_id) VALUES (?, ?, ?, 'premium', ?, ?, ?)`,
                [phone, username, password, expireFull, 'premium', resellerId]);
            
            return { success: true, username, password, expires: expireFull };
        } catch (error) {
            console.error(chalk.red('❌ Error:'), error.message);
            return { success: false, error: error.message };
        }
    }
}

// TEST ILIMITADO - Siempre retorna true (sin restricción)
function canCreateTest(phone) {
    return true; // TESTS ILIMITADOS - Siempre puede crear test
}

function registerTest(phone) {
    // Solo registramos para estadísticas, pero no bloqueamos
    db.run('INSERT OR IGNORE INTO daily_tests (phone, date) VALUES (?, ?)', [phone, moment().format('YYYY-MM-DD')]);
}

async function sendAppFile(to) {
    const apkPath = '/root/mgvpn.apk';
    
    if (!fs.existsSync(apkPath)) {
        console.log(chalk.yellow(`⚠️ Archivo APK no encontrado`));
        return false;
    }
    
    try {
        await client.sendFile(
            to,
            apkPath,
            'mgvpn.apk',
            '📲 *APP MGVPN*\n\nDescarga nuestra aplicación oficial.\n\n*Credenciales por defecto:*\nUsuario: (el que te proporcionamos)\nContraseña: cloudvpn'
        );
        return true;
    } catch (error) {
        console.error(chalk.red(`❌ Error enviando APK: ${error.message}`));
        return false;
    }
}

function authenticateReseller(username, password) {
    return new Promise((resolve) => {
        db.get('SELECT id, username, name, commission_type, commission_value, status FROM resellers WHERE username = ? AND password = ? AND status = 1',
            [username, password], (err, row) => {
                resolve(err ? null : row);
            });
    });
}

async function getUserState(phone) {
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

async function getResellerStats(resellerId) {
    return new Promise((resolve) => {
        db.get(`
            SELECT 
                COUNT(DISTINCT u.id) as total_users,
                COUNT(CASE WHEN u.status = 1 THEN 1 END) as active_users,
                COUNT(CASE WHEN u.tipo = 'test' THEN 1 END) as test_users,
                COUNT(CASE WHEN u.tipo = 'premium' THEN 1 END) as premium_users,
                COUNT(p.id) as total_sales,
                COALESCE(SUM(p.amount), 0) as total_income,
                COALESCE(SUM(p.commission), 0) as total_commission
            FROM users u
            LEFT JOIN payments p ON u.reseller_id = p.reseller_id AND p.status = 'approved'
            WHERE u.reseller_id = ?
        `, [resellerId], (err, row) => {
            resolve(row || { total_users: 0, active_users: 0, test_users: 0, premium_users: 0, total_sales: 0, total_income: 0, total_commission: 0 });
        });
    });
}

async function getResellerUsers(resellerId, limit = 20) {
    return new Promise((resolve) => {
        db.all(`
            SELECT username, phone, tipo, expires_at, status, created_at 
            FROM users 
            WHERE reseller_id = ? 
            ORDER BY created_at DESC 
            LIMIT ?
        `, [resellerId, limit], (err, rows) => {
            resolve(rows || []);
        });
    });
}

// Inicializar WPPConnect
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
            browserWS: '',
            browserArgs: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--no-first-run',
                '--no-zygote',
                '--disable-gpu',
                '--disable-background-timer-throttling',
                '--disable-backgrounding-occluded-windows',
                '--disable-renderer-backgrounding',
                '--disable-features=site-per-process',
                '--window-size=1920,1080'
            ],
            puppeteerOptions: {
                executablePath: '/usr/bin/google-chrome',
                headless: 'new',
                args: [
                    '--no-sandbox',
                    '--disable-setuid-sandbox',
                    '--disable-dev-shm-usage'
                ]
            },
            disableWelcome: true,
            updatesLog: false,
            autoClose: 0,
            tokenStore: 'file',
            folderNameToken: '/root/.wppconnect'
        });
        
        console.log(chalk.green('✅ WPPConnect conectado!'));
        
        client.onStateChange((state) => {
            console.log(chalk.cyan(`📱 Estado: ${state}`));
            
            if (state === 'DISCONNECTED') {
                console.log(chalk.yellow('⚠️ Desconectado, reconectando...'));
                setTimeout(initializeBot, 10000);
            }
        });
        
        // Manejar mensajes
        client.onMessage(async (message) => {
            try {
                const text = message.body.trim();
                const from = message.from;
                
                console.log(chalk.cyan(`📩 [${from}]: ${text.substring(0, 30)}`));
                
                const userState = await getUserState(from);
                
                // Verificar si es un revendedor autenticado
                if (userState.state === 'reseller_authenticated') {
                    const reseller = userState.data;
                    
                    // MENÚ REVENDEDOR
                    if (text.toLowerCase() === 'menu' || text === '0') {
                        await client.sendText(from, `👤 *PANEL REVENDEDOR - ${reseller.name}*

Elija una opción:

1️⃣ - CREAR USUARIO SSH
2️⃣ - VER MIS USUARIOS
3️⃣ - MIS ESTADÍSTICAS
4️⃣ - DESCARGAR APLICACIÓN

0️⃣ - SALIR`);
                        return;
                    }
                    
                    // Opción 1: Crear usuario SSH
                    if (text === '1') {
                        await setUserState(from, 'reseller_creating_user', reseller);
                        await client.sendText(from, `📝 *CREAR USUARIO SSH*

Ingresa el teléfono del usuario (ej: 5491122334455):

*0* - Cancelar`);
                        return;
                    }
                    
                    // Opción 2: Ver usuarios creados
                    if (text === '2') {
                        const users = await getResellerUsers(reseller.id);
                        
                        if (users.length === 0) {
                            await client.sendText(from, `📭 *NO HAY USUARIOS CREADOS*

Aún no has creado ningún usuario.
Usa la opción 1 para crear.`);
                        } else {
                            let userList = `👥 *MIS USUARIOS (${users.length})*\n\n`;
                            for (const u of users) {
                                const status = u.status === 1 ? '✅ Activo' : '❌ Inactivo';
                                const expireDate = moment(u.expires_at).format('DD/MM/YYYY HH:mm');
                                userList += `👤 *${u.username}*\n📱 ${u.phone}\n📅 Expira: ${expireDate}\n${status}\n\n`;
                            }
                            await client.sendText(from, userList);
                        }
                        return;
                    }
                    
                    // Opción 3: Estadísticas
                    if (text === '3') {
                        const stats = await getResellerStats(reseller.id);
                        
                        const message = `📊 *MIS ESTADÍSTICAS*

👤 *${reseller.name}*

━━━━━━━━━━━━━━━━━
📈 *USUARIOS CREADOS*
Total: ${stats.total_users}
Activos: ${stats.active_users}
Tests: ${stats.test_users}
Premium: ${stats.premium_users}

━━━━━━━━━━━━━━━━━
💰 *VENTAS*
Total ventas: ${stats.total_sales}
Ingresos: $${stats.total_income}
Comisiones: $${stats.total_commission}
━━━━━━━━━━━━━━━━━

💡 *Comisión configurada:* ${reseller.commission_value}%`;
                        
                        await client.sendText(from, message);
                        return;
                    }
                    
                    // Opción 4: Descargar app
                    if (text === '4') {
                        await client.sendText(from, '📲 Enviando aplicación...');
                        await sendAppFile(from);
                        return;
                    }
                    
                    // Proceso de creación de usuario
                    if (userState.state === 'reseller_creating_user') {
                        const reseller = userState.data;
                        
                        if (text === '0') {
                            await setUserState(from, 'reseller_authenticated', reseller);
                            await client.sendText(from, '❌ Operación cancelada. Envía *MENU* para volver.');
                            return;
                        }
                        
                        // Guardar teléfono y preguntar por el plan
                        await setUserState(from, 'reseller_selecting_plan', { ...reseller, userPhone: text });
                        
                        await client.sendText(from, `📱 *SELECCIONAR PLAN*

Usuario: ${text}

🌐 PLANES SSH PREMIUM

1️⃣ - 7 DIAS - $${config.prices.price_7d}
2️⃣ - 15 DIAS - $${config.prices.price_15d}
3️⃣ - 30 DIAS - $${config.prices.price_30d}
4️⃣ - 50 DIAS - $${config.prices.price_50d}
5️⃣ - PRUEBA (${config.prices.test_hours} horas GRATIS)

0️⃣ - CANCELAR`);
                        return;
                    }
                    
                    if (userState.state === 'reseller_selecting_plan') {
                        const data = userState.data;
                        const reseller = data;
                        const userPhone = data.userPhone;
                        
                        if (text === '0') {
                            await setUserState(from, 'reseller_authenticated', reseller);
                            await client.sendText(from, '❌ Operación cancelada. Envía *MENU* para volver.');
                            return;
                        }
                        
                        const planMap = {
                            '1': { days: 7, price: config.prices.price_7d, type: 'premium' },
                            '2': { days: 15, price: config.prices.price_15d, type: 'premium' },
                            '3': { days: 30, price: config.prices.price_30d, type: 'premium' },
                            '4': { days: 50, price: config.prices.price_50d, type: 'premium' },
                            '5': { days: 0, price: 0, type: 'test' }
                        };
                        
                        const plan = planMap[text];
                        
                        if (!plan) {
                            await client.sendText(from, '❌ Opción inválida. Elige 1-5');
                            return;
                        }
                        
                        await client.sendText(from, '⏳ Creando usuario...');
                        
                        const username = plan.type === 'test' ? generateUsername() : generatePremiumUsername();
                        const result = await createSSHUser(userPhone, username, plan.days, reseller.id);
                        
                        if (result.success) {
                            let message = `✅ *USUARIO CREADO CON ÉXITO*

👤 Usuario: ${username}
🔑 Contraseña: ${DEFAULT_PASSWORD}
📱 Teléfono: ${userPhone}`;
                            
                            if (plan.type === 'test') {
                                message += `\n⏰ Expira en: ${config.prices.test_hours} horas`;
                                message += `\n🎁 PRUEBA GRATUITA (SIN LÍMITE DE TESTS)`;
                            } else {
                                const expireDate = moment(result.expires).format('DD/MM/YYYY HH:mm');
                                message += `\n📅 Expira: ${expireDate}`;
                                message += `\n💰 Plan: ${plan.days} días - $${plan.price} ARS`;
                                message += `\n💸 *Comisión generada: $${(plan.price * (reseller.commission_value / 100)).toFixed(2)} ARS*`;
                                
                                // Registrar pago
                                const paymentId = `RESELLER-${reseller.id}-${Date.now()}`;
                                const commission = plan.price * (reseller.commission_value / 100);
                                
                                db.run(`
                                    INSERT INTO payments (payment_id, phone, plan, days, amount, status, reseller_id, commission, approved_at)
                                    VALUES (?, ?, ?, ?, ?, 'approved', ?, ?, CURRENT_TIMESTAMP)
                                `, [paymentId, userPhone, `${plan.days}d`, plan.days, plan.price, reseller.id, commission]);
                            }
                            
                            await client.sendText(from, message);
                            
                            // Enviar mensaje al usuario
                            if (client) {
                                let userMessage = `🎉 *CUENTA SSH ACTIVADA*

👤 Usuario: ${username}
🔑 Contraseña: ${DEFAULT_PASSWORD}

📲 Descarga la app: Envía *MENU* al bot

🔌 *1 dispositivo máximo*`;
                                
                                if (plan.type === 'test') {
                                    userMessage += `\n⏰ *PRUEBA DE ${config.prices.test_hours} HORAS*`;
                                    userMessage += `\n🎁 *TESTS ILIMITADOS*`;
                                } else {
                                    userMessage += `\n📅 *VÁLIDO HASTA: ${moment(result.expires).format('DD/MM/YYYY')}*`;
                                }
                                
                                await client.sendText(userPhone, userMessage);
                            }
                            
                            console.log(chalk.green(`✅ Revendedor ${reseller.username} creó usuario ${username}`));
                        } else {
                            await client.sendText(from, `❌ Error: ${result.error}`);
                        }
                        
                        await setUserState(from, 'reseller_authenticated', reseller);
                        return;
                    }
                    
                    // Salir
                    if (text.toLowerCase() === 'salir') {
                        await clearUserState(from);
                        await client.sendText(from, `👋 *SESIÓN CERRADA*

Para iniciar sesión nuevamente, envía:

*LOGIN usuario contraseña*
Ejemplo: LOGIN revendedor123 pass123

Para clientes:
Envía *MENU* para crear prueba gratuita`);
                        return;
                    }
                    
                    return;
                }
                
                // MENÚ PRINCIPAL - Para clientes (crear test)
                if (text.toLowerCase() === 'menu' || text.toLowerCase() === 'hola' || text.toLowerCase() === 'start' || text === '1') {
                    await setUserState(from, 'main_menu');
                    
                    // Crear test automáticamente sin preguntar
                    await client.sendText(from, '⏳ Creando cuenta de prueba...');
                    
                    try {
                        const username = generateUsername();
                        const result = await createSSHUser(from, username, 0, null);
                        
                        if (result.success) {
                            registerTest(from);
                            
                            await client.sendText(from, `✅ *PRUEBA GRATUITA CREADA*

🎁 *TESTS ILIMITADOS* - Puedes crear todas las pruebas que quieras

👤 Usuario: ${username}
🔑 Contraseña: ${DEFAULT_PASSWORD}
🔌 Límite: 1 dispositivo
⏰ Expira en: ${config.prices.test_hours} horas

📲 *Instrucciones:*
1. Envía "APK" para descargar la app
2. Instala la aplicación
3. Configura con tus credenciales

⏰ *TIENES ${config.prices.test_hours} HORAS DE PRUEBA*

*Para crear otra prueba, solo envía MENU nuevamente*`);
                            
                            console.log(chalk.green(`✅ Test creado: ${username} (${config.prices.test_hours} horas) - Tests ilimitados`));
                        } else {
                            await client.sendText(from, `❌ Error: ${result.error}`);
                        }
                    } catch (error) {
                        await client.sendText(from, `❌ Error al crear cuenta: ${error.message}`);
                    }
                    return;
                }
                
                // Descargar APK
                if (text.toLowerCase() === 'apk') {
                    await sendAppFile(from);
                    return;
                }
                
                // Autenticación de revendedores
                if (text.toUpperCase().startsWith('LOGIN ')) {
                    const parts = text.split(' ');
                    if (parts.length >= 3) {
                        const username = parts[1];
                        const password = parts[2];
                        
                        const reseller = await authenticateReseller(username, password);
                        
                        if (reseller) {
                            await setUserState(from, 'reseller_authenticated', reseller);
                            await client.sendText(from, `✅ *AUTENTICACIÓN EXITOSA*

👤 Bienvenido ${reseller.name}

Envía *MENU* para ver las opciones

*NOTA:* Los clientes solo deben enviar MENU para crear prueba`);
                        } else {
                            await client.sendText(from, `❌ *AUTENTICACIÓN FALLIDA*

Usuario o contraseña incorrectos.

Para clientes: Envía *MENU* para crear prueba gratuita

Para revendedores: *LOGIN usuario contraseña*`);
                        }
                    } else {
                        await client.sendText(from, `❌ *FORMATO INCORRECTO*

Usa: *LOGIN usuario contraseña*
Ejemplo: LOGIN revendedor123 pass123

Para clientes: Envía *MENU* para prueba gratuita`);
                    }
                    return;
                }
                
                // Mensaje por defecto
                if (text && !text.startsWith('LOGIN')) {
                    await client.sendText(from, `🤖 *SSH BOT PRO*

🎁 *TESTS ILIMITADOS*

Envía *MENU* para crear tu prueba gratuita de ${config.prices.test_hours} horas

Si eres revendedor:
*LOGIN usuario contraseña*

Para descargar la app:
Envía *APK*`);
                }
                
            } catch (error) {
                console.error(chalk.red('❌ Error procesando mensaje:'), error.message);
            }
        });
        
        // Limpieza cada 15 minutos
        cron.schedule('*/15 * * * *', async () => {
            const now = moment().format('YYYY-MM-DD HH:mm:ss');
            console.log(chalk.yellow(`🧹 Limpiando usuarios expirados...`));
            
            db.all('SELECT username FROM users WHERE expires_at < ? AND status = 1', [now], async (err, rows) => {
                if (err || !rows || rows.length === 0) return;
                
                for (const r of rows) {
                    try {
                        await execPromise(`pkill -u ${r.username} 2>/dev/null || true`);
                        await execPromise(`userdel -f ${r.username} 2>/dev/null || true`);
                        db.run('UPDATE users SET status = 0 WHERE username = ?', [r.username]);
                        console.log(chalk.green(`🗑️ Eliminado: ${r.username}`));
                    } catch (e) {
                        console.error(chalk.red(`Error eliminando ${r.username}:`), e.message);
                    }
                }
            });
        });
        
        // Limpiar estados antiguos
        cron.schedule('0 * * * *', () => {
            db.run(`DELETE FROM user_state WHERE updated_at < datetime('now', '-1 hour')`);
        });
        
    } catch (error) {
        console.error(chalk.red('❌ Error inicializando WPPConnect:'), error.message);
        console.log(chalk.yellow('🔄 Reintentando en 10 segundos...'));
        setTimeout(initializeBot, 10000);
    }
}

initializeBot();

process.on('SIGINT', async () => {
    console.log(chalk.yellow('\n🛑 Cerrando bot...'));
    if (client) {
        await client.close();
    }
    process.exit();
});
BOTEOF

echo -e "${GREEN}✅ Bot creado con TESTS ILIMITADOS${NC}"

# ================================================
# CREAR PANEL ADMINISTRADOR
# ================================================
echo -e "\n${CYAN}🎛️  Creando panel administrador...${NC}"

cat > /usr/local/bin/reseller-admin << 'ADMINEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; NC='\033[0m'

DB="/opt/sshbot-pro/data/users.db"
CONFIG="/opt/sshbot-pro/config/config.json"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         🎛️  PANEL ADMIN - TESTS ILIMITADOS                  ║${NC}"
    echo -e "${CYAN}║              🎁 SIN RESTRICCIÓN DE PRUEBAS                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

create_reseller() {
    clear
    echo -e "${CYAN}👤 CREAR NUEVO REVENDEDOR${NC}\n"
    
    read -p "Nombre del revendedor: " NAME
    read -p "Usuario (login): " USERNAME
    read -p "Contraseña: " PASSWORD
    read -p "Teléfono (ej: 5491122334455): " PHONE
    
    echo -e "\n${YELLOW}Tipo de comisión:${NC}"
    echo -e "  1. Porcentaje (%)"
    echo -e "  2. Monto fijo (ARS)"
    read -p "Selecciona (1/2): " COMM_TYPE
    
    if [[ "$COMM_TYPE" == "1" ]]; then
        COM_TYPE="percentage"
        read -p "Porcentaje de comisión (ej: 20): " COM_VALUE
    else
        COM_TYPE="fixed"
        read -p "Monto fijo por venta (ej: 500): " COM_VALUE
    fi
    
    echo -e "\n${YELLOW}Creando revendedor...${NC}"
    
    sqlite3 "$DB" "INSERT INTO resellers (username, password, name, phone, commission_type, commission_value, status) 
                   VALUES ('$USERNAME', '$PASSWORD', '$NAME', '$PHONE', '$COM_TYPE', $COM_VALUE, 1)" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        echo -e "\n${GREEN}✅ REVENDEDOR CREADO${NC}"
        echo -e "  👤 Nombre: $NAME"
        echo -e "  🔑 Usuario: $USERNAME"
        echo -e "  🔐 Contraseña: $PASSWORD"
        echo -e "  📱 Teléfono: $PHONE"
        echo -e "  💰 Comisión: $COM_VALUE ${COM_TYPE == 'percentage' ? '%' : 'ARS'}"
    else
        echo -e "\n${RED}❌ Error: Usuario ya existe${NC}"
    fi
    
    read -p "Presiona Enter..."
}

list_resellers() {
    clear
    echo -e "${CYAN}👥 LISTA DE REVENDEDORES${NC}\n"
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    printf "${CYAN}%-20s %-15s %-15s %-15s %-10s${NC}\n" "NOMBRE" "USUARIO" "TELÉFONO" "COMISIÓN" "ESTADO"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    sqlite3 "$DB" "SELECT name, username, phone, commission_type, commission_value, status FROM resellers WHERE username != 'admin'" | while IFS='|' read name username phone com_type com_val status; do
        if [[ "$com_type" == "percentage" ]]; then
            COM="${com_val}%"
        else
            COM="\$${com_val}"
        fi
        
        if [[ "$status" == "1" ]]; then
            STATUS="${GREEN}ACTIVO${NC}"
        else
            STATUS="${RED}INACTIVO${NC}"
        fi
        
        printf "%-20s %-15s %-15s %-15s ${STATUS}\n" "$name" "$username" "$phone" "$COM"
    done
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM resellers WHERE username != 'admin'")
    echo -e "\n${GREEN}Total: $TOTAL revendedores${NC}"
    read -p "Presiona Enter..."
}

global_stats() {
    clear
    echo -e "${CYAN}📊 ESTADÍSTICAS GLOBALES${NC}\n"
    
    TOTAL_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE username != ''")
    ACTIVE_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status = 1")
    TEST_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE tipo = 'test'")
    PREMIUM_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE tipo = 'premium'")
    
    TOTAL_RESELLERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM resellers WHERE username != 'admin'")
    ACTIVE_RESELLERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM resellers WHERE status = 1 AND username != 'admin'")
    
    TOTAL_SALES=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status = 'approved'")
    TOTAL_INCOME=$(sqlite3 "$DB" "SELECT printf('%.2f', SUM(amount)) FROM payments WHERE status = 'approved'")
    TOTAL_COMMISSIONS=$(sqlite3 "$DB" "SELECT printf('%.2f', SUM(commission)) FROM payments WHERE status = 'approved'")
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}📈 ESTADÍSTICAS DEL SISTEMA${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    echo -e "${YELLOW}👥 USUARIOS:${NC}"
    echo -e "  Total usuarios creados: $TOTAL_USERS"
    echo -e "  Usuarios activos: $ACTIVE_USERS"
    echo -e "  Tests creados: $TEST_USERS"
    echo -e "  Usuarios premium: $PREMIUM_USERS"
    
    echo -e "\n${YELLOW}🤝 REVENDEDORES:${NC}"
    echo -e "  Total revendedores: $TOTAL_RESELLERS"
    echo -e "  Revendedores activos: $ACTIVE_RESELLERS"
    
    echo -e "\n${YELLOW}💰 VENTAS:${NC}"
    echo -e "  Total ventas: $TOTAL_SALES"
    echo -e "  Ingresos totales: \$${TOTAL_INCOME}"
    echo -e "  Comisiones totales: \$${TOTAL_COMMISSIONS}"
    
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Presiona Enter..."
}

while true; do
    show_header
    
    TOTAL_RESELLERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM resellers WHERE username != 'admin'" 2>/dev/null || echo "0")
    TOTAL_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    TEST_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE tipo='test'" 2>/dev/null || echo "0")
    
    echo -e "${YELLOW}📊 RESUMEN:${NC}"
    echo -e "  Revendedores: ${CYAN}$TOTAL_RESELLERS${NC}"
    echo -e "  Usuarios totales: ${CYAN}$TOTAL_USERS${NC}"
    echo -e "  Tests creados: ${GREEN}$TEST_USERS (ILIMITADOS)${NC}"
    echo -e "  Contraseña usuarios: ${GREEN}cloudvpn${NC}"
    echo -e ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC} 👤 Crear nuevo revendedor"
    echo -e "${CYAN}[2]${NC} 👥 Listar revendedores"
    echo -e "${CYAN}[3]${NC} 📊 Estadísticas globales"
    echo -e "${CYAN}[4]${NC} 💳 Ver pagos"
    echo -e "${CYAN}[5]${NC} ⚙️  Ver configuración"
    echo -e "${CYAN}[0]${NC} 🚪 Salir"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e ""
    
    read -p "👉 Selecciona: " OPTION
    
    case $OPTION in
        1) create_reseller ;;
        2) list_resellers ;;
        3) global_stats ;;
        4)
            clear
            echo -e "${CYAN}💳 PAGOS${NC}\n"
            sqlite3 -column -header "$DB" "SELECT payment_id, phone, plan, amount, status, created_at FROM payments ORDER BY created_at DESC LIMIT 20"
            read -p "Presiona Enter..."
            ;;
        5)
            clear
            echo -e "${CYAN}⚙️ CONFIGURACIÓN${NC}\n"
            echo -e "${YELLOW}Precios actuales:${NC}"
            echo -e "  7 días: $ ${get_val '.prices.price_7d'}"
            echo -e "  15 días: $ ${get_val '.prices.price_15d'}"
            echo -e "  30 días: $ ${get_val '.prices.price_30d'}"
            echo -e "  50 días: $ ${get_val '.prices.price_50d'}"
            echo -e "  Prueba: ${get_val '.prices.test_hours'} horas"
            echo -e "  Tests: ${GREEN}ILIMITADOS${NC}"
            echo -e "  Contraseña usuarios: ${GREEN}cloudvpn${NC}"
            echo -e ""
            read -p "Presiona Enter..."
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
ADMINEOF

chmod +x /usr/local/bin/reseller-admin

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
║          🎉 INSTALACIÓN COMPLETADA - TESTS ILIMITADOS 🎉    ║
║                                                              ║
║       🤖 SSH BOT PRO - SISTEMA DE REVENDEDORES             ║
║       🔐 CADA REVENDEDOR CON SU CONTRASEÑA ÚNICA          ║
║       🔑 CONTRASEÑA USUARIOS: cloudvpn (FIJA)             ║
║       🎁 TESTS ILIMITADOS - SIN RESTRICCIÓN DIARIA       ║
║       💰 CONTROL DE COMISIONES Y VENTAS                   ║
║       📊 ESTADÍSTICAS COMPLETAS                           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Sistema completo instalado${NC}"
echo -e "${GREEN}✅ TESTS ILIMITADOS - Sin límite diario${NC}"
echo -e "${GREEN}✅ Contraseña usuarios: cloudvpn${NC}"
echo -e "${GREEN}✅ Sistema de revendedores activo${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 COMANDOS PRINCIPALES:${NC}\n"
echo -e "  ${GREEN}reseller-admin${NC}   - Panel administrador de revendedores"
echo -e "  ${GREEN}pm2 logs sshbot-pro${NC} - Ver logs del bot"
echo -e "  ${GREEN}pm2 restart sshbot-pro${NC} - Reiniciar bot"
echo -e "\n"

echo -e "${YELLOW}🚀 PRIMEROS PASOS:${NC}\n"
echo -e "  1. Ver logs: ${GREEN}pm2 logs sshbot-pro${NC}"
echo -e "  2. Escanear QR cuando aparezca"
echo -e "  3. Panel admin: ${GREEN}reseller-admin${NC}"
echo -e "  4. Credenciales admin: usuario 'admin', contraseña 'admin123'"
echo -e "  5. Crear revendedores desde el panel admin"
echo -e "\n"

echo -e "${YELLOW}📱 PARA CLIENTES (WhatsApp):${NC}\n"
echo -e "  Enviar al bot: ${GREEN}MENU${NC} - Crea prueba automáticamente"
echo -e "  ${GREEN}APK${NC} - Descargar aplicación"
echo -e "  🎁 Los clientes pueden crear ${GREEN}TEST ILIMITADOS${NC}"
echo -e "\n"

echo -e "${YELLOW}📱 PARA REVENDEDORES (WhatsApp):${NC}\n"
echo -e "  Enviar al bot: ${GREEN}LOGIN usuario contraseña${NC}"
echo -e "  Ejemplo: LOGIN juan123 pass123"
echo -e "  Luego enviar MENU para ver opciones"
echo -e "\n"

echo -e "${YELLOW}🔐 CREDENCIALES ADMIN:${NC}\n"
echo -e "  Usuario: ${GREEN}admin${NC}"
echo -e "  Contraseña: ${GREEN}admin123${NC}"
echo -e "  Cambia la contraseña del admin por seguridad"
echo -e "\n"

echo -e "${GREEN}${BOLD}🎁 TESTS ILIMITADOS - Los clientes pueden crear todas las pruebas que quieran sin restricción diaria 🚀${NC}\n"

# Ver logs automáticamente
read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}Mostrando logs...${NC}"
    echo -e "${YELLOW}📱 Espera que aparezca el QR para escanear...${NC}\n"
    sleep 2
    pm2 logs sshbot-pro
else
    echo -e "\n${YELLOW}💡 Para iniciar panel admin: ${GREEN}reseller-admin${NC}"
    echo -e "${YELLOW}💡 Para logs: ${GREEN}pm2 logs sshbot-pro${NC}\n"
fi

exit 0