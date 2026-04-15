#!/bin/bash
# ================================================
# SSH BOT PRO - INSTALACIÓN COMPLETA
# VERSIÓN FINAL OPTIMIZADA
# CONTRASEÑA: cloudvpn | TESTS ILIMITADOS | PLANES: 7,15,30 DIAS
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
║          🚀 SSH BOT PRO - INSTALACIÓN COMPLETA 🚀           ║
║                                                              ║
║       🔑 CONTRASEÑA USUARIOS: cloudvpn (FIJA)              ║
║       🎁 TESTS ILIMITADOS (SIN RESTRICCIÓN)                ║
║       📅 PLANES: 7, 15, 30 DÍAS (SIN 50)                   ║
║       👥 SISTEMA DE REVENDEDORES CON COMISIONES            ║
║       🎛️  PANEL ADMINISTRADOR COMPLETO                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CARACTERÍSTICAS:${NC}"
echo -e "  🔑 ${CYAN}Contraseña usuarios:${NC} cloudvpn"
echo -e "  🎁 ${YELLOW}Tests ilimitados${NC} - Sin límite diario"
echo -e "  📅 ${PURPLE}Planes disponibles:${NC} 7, 15, 30 días"
echo -e "  👥 ${BLUE}Revendedores${NC} - Cada uno con su clave"
echo -e "  💰 ${GREEN}Comisiones${NC} - Porcentaje o monto fijo"
echo -e "  🎛️  ${CYAN}Panel admin${NC} - Gestión completa"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Debes ejecutar como root${NC}"
    echo -e "${YELLOW}Usa: sudo bash $0${NC}"
    exit 1
fi

# Detectar IP
echo -e "${CYAN}🔍 Detectando IP...${NC}"
SERVER_IP=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
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
apt-get install -y nodejs

# Chrome/Chromium
wget -q -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
dpkg -i /tmp/chrome.deb 2>/dev/null || apt-get install -f -y

# Dependencias del sistema
apt-get install -y \
    git curl wget sqlite3 jq \
    build-essential gcc g++ make \
    python3 python3-pip ffmpeg \
    unzip cron ufw

# Configurar firewall
ufw --force enable 2>/dev/null || true

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
pm2 kill 2>/dev/null || true
pkill -f "node.*bot.js" 2>/dev/null || true
pkill -f pm2 2>/dev/null || true
rm -rf "$INSTALL_DIR" "$USER_HOME" /root/.wppconnect /root/.pm2 2>/dev/null || true
sleep 1

# Crear directorios
mkdir -p "$INSTALL_DIR"/{data,config,logs,qr_codes}
mkdir -p "$USER_HOME"
mkdir -p /root/.wppconnect
chmod -R 755 "$INSTALL_DIR"

# Configuración
cat > "$CONFIG_FILE" << EOF
{
    "bot": {
        "name": "SSH Bot Pro",
        "version": "3.0-FINAL",
        "server_ip": "$SERVER_IP",
        "default_password": "cloudvpn"
    },
    "prices": {
        "test_hours": 2,
        "price_7d": 1800.00,
        "price_15d": 2400.00,
        "price_30d": 4500.00,
        "currency": "ARS"
    },
    "commission": {
        "type": "percentage",
        "value": 20
    },
    "tests": {
        "unlimited": true
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false
    },
    "paths": {
        "database": "$DB_FILE",
        "sessions": "/root/.wppconnect",
        "apk_file": "$APK_PATH"
    }
}
EOF

# Base de datos
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

CREATE TABLE daily_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    date DATE,
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
SQL

# Crear admin
ADMIN_PASS="admin123"
sqlite3 "$DB_FILE" << SQL
INSERT OR REPLACE INTO resellers (username, password, name, phone, commission_type, commission_value, status) 
VALUES ('admin', '$ADMIN_PASS', 'Administrador', '0000000000', 'percentage', 0, 1);
SQL

echo -e "${GREEN}✅ Estructura creada${NC}"
echo -e "${GREEN}✅ Admin creado: usuario 'admin', contraseña '$ADMIN_PASS'${NC}"

# ================================================
# INSTALAR NPM DEPENDENCIAS
# ================================================
echo -e "\n${CYAN}📦 Instalando paquetes NPM...${NC}"

cd "$USER_HOME"

cat > package.json << 'EOF'
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
        "axios": "^1.6.5"
    }
}
EOF

npm install --silent --no-progress 2>&1 | grep -v "WARN" || true

echo -e "${GREEN}✅ Paquetes instalados${NC}"

# ================================================
# CREAR BOT COMPLETO (CON DISABLE STATUS)
# ================================================
echo -e "\n${CYAN}🤖 Creando bot...${NC}"

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
const axios = require('axios');

const execPromise = util.promisify(exec);
moment.locale('es');

console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════════════╗'));
console.log(chalk.cyan.bold('║      🤖 BOT REVENTAS - TESTS ILIMITADOS                       ║'));
console.log(chalk.cyan.bold('║              🔐 CONTRASEÑA: cloudvpn                        ║'));
console.log(chalk.cyan.bold('║              📅 PLANES: 7, 15, 30 DÍAS                     ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

function loadConfig() {
    delete require.cache[require.resolve('/opt/sshbot-pro/config/config.json')];
    return require('/opt/sshbot-pro/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/sshbot-pro/data/users.db');
const DEFAULT_PASSWORD = 'cloudvpn';

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

async function createSSHUser(phone, username, days, resellerId = null) {
    if (days === 0) {
        const expireFull = moment().add(config.prices.test_hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
        await execPromise(`useradd -m -s /bin/bash ${username} && echo "${username}:${DEFAULT_PASSWORD}" | chpasswd`);
        db.run(`INSERT INTO users (phone, username, password, tipo, expires_at, created_by, reseller_id) VALUES (?, ?, ?, 'test', ?, ?, ?)`,
            [phone, username, DEFAULT_PASSWORD, expireFull, 'test', resellerId]);
        return { success: true, username, password: DEFAULT_PASSWORD, expires: expireFull };
    } else {
        const expireFull = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
        await execPromise(`useradd -M -s /bin/false -e ${moment().add(days, 'days').format('YYYY-MM-DD')} ${username} && echo "${username}:${DEFAULT_PASSWORD}" | chpasswd`);
        db.run(`INSERT INTO users (phone, username, password, tipo, expires_at, created_by, reseller_id) VALUES (?, ?, ?, 'premium', ?, ?, ?)`,
            [phone, username, DEFAULT_PASSWORD, expireFull, 'premium', resellerId]);
        return { success: true, username, password: DEFAULT_PASSWORD, expires: expireFull };
    }
}

async function sendAppFile(to) {
    const apkPath = '/root/mgvpn.apk';
    if (fs.existsSync(apkPath)) {
        try {
            await client.sendFile(to, apkPath, 'mgvpn.apk', '📲 APP MGVPN\nContraseña: cloudvpn');
            return true;
        } catch (error) {
            return false;
        }
    }
    return false;
}

function authenticateReseller(username, password) {
    return new Promise((resolve) => {
        db.get('SELECT id, username, name, commission_type, commission_value, status FROM resellers WHERE username = ? AND password = ? AND status = 1',
            [username, password], (err, row) => resolve(err ? null : row));
    });
}

async function getUserState(phone) {
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
        db.run(`INSERT OR REPLACE INTO user_state (phone, state, data, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)`,
            [phone, state, dataStr], () => resolve());
    });
}

function clearUserState(phone) {
    db.run('DELETE FROM user_state WHERE phone = ?');
}

async function getResellerStats(resellerId) {
    return new Promise((resolve) => {
        db.get(`
            SELECT COUNT(DISTINCT u.id) as total_users,
                   COUNT(CASE WHEN u.status = 1 THEN 1 END) as active_users,
                   COUNT(CASE WHEN u.tipo = 'test' THEN 1 END) as test_users,
                   COUNT(CASE WHEN u.tipo = 'premium' THEN 1 END) as premium_users,
                   COUNT(p.id) as total_sales,
                   COALESCE(SUM(p.amount), 0) as total_income,
                   COALESCE(SUM(p.commission), 0) as total_commission
            FROM users u
            LEFT JOIN payments p ON u.reseller_id = p.reseller_id AND p.status = 'approved'
            WHERE u.reseller_id = ?
        `, [resellerId], (err, row) => resolve(row || { total_users: 0, active_users: 0, test_users: 0, premium_users: 0, total_sales: 0, total_income: 0, total_commission: 0 }));
    });
}

async function getResellerUsers(resellerId, limit = 20) {
    return new Promise((resolve) => {
        db.all(`SELECT username, phone, tipo, expires_at, status, created_at FROM users WHERE reseller_id = ? ORDER BY created_at DESC LIMIT ?`,
            [resellerId, limit], (err, rows) => resolve(rows || []));
    });
}

let client = null;

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
            browserArgs: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
            puppeteerOptions: {
                executablePath: '/usr/bin/google-chrome',
                headless: 'new',
                args: ['--no-sandbox', '--disable-setuid-sandbox']
            },
            disableWelcome: true,
            autoClose: 0,
            tokenStore: 'file',
            folderNameToken: '/root/.wppconnect',
            disableAutoStatus: true  // 🔥 NO SUBE ESTADO A WHATSAPP
        });
        
        console.log(chalk.green('✅ WPPConnect conectado!'));
        
        client.onStateChange((state) => {
            console.log(chalk.cyan(`📱 Estado: ${state}`));
            if (state === 'DISCONNECTED') setTimeout(initializeBot, 10000);
        });
        
        client.onMessage(async (message) => {
            try {
                const text = message.body.trim();
                const from = message.from;
                console.log(chalk.cyan(`📩 [${from}]: ${text.substring(0, 30)}`));
                
                const userState = await getUserState(from);
                
                // REVENDEDOR AUTENTICADO
                if (userState.state === 'reseller_authenticated') {
                    const reseller = userState.data;
                    
                    if (text.toLowerCase() === 'menu' || text === '0') {
                        await client.sendText(from, `👤 *PANEL REVENDEDOR - ${reseller.name}*

1️⃣ - CREAR USUARIO
2️⃣ - MIS USUARIOS
3️⃣ - MIS ESTADÍSTICAS
4️⃣ - DESCARGAR APP
0️⃣ - SALIR`);
                        return;
                    }
                    
                    if (text === '1') {
                        await setUserState(from, 'reseller_creating_user', reseller);
                        await client.sendText(from, `📝 Ingresa el teléfono (ej: 5491122334455):\n0 - Cancelar`);
                        return;
                    }
                    
                    if (text === '2') {
                        const users = await getResellerUsers(reseller.id);
                        if (users.length === 0) {
                            await client.sendText(from, '📭 No hay usuarios creados');
                        } else {
                            let msg = `👥 MIS USUARIOS (${users.length})\n\n`;
                            for (const u of users) {
                                msg += `👤 ${u.username}\n📱 ${u.phone}\n📅 ${moment(u.expires_at).format('DD/MM/YYYY')}\n✅ ${u.status === 1 ? 'Activo' : 'Inactivo'}\n\n`;
                            }
                            await client.sendText(from, msg);
                        }
                        return;
                    }
                    
                    if (text === '3') {
                        const stats = await getResellerStats(reseller.id);
                        await client.sendText(from, `📊 MIS ESTADÍSTICAS

👤 ${reseller.name}

USUARIOS:
Total: ${stats.total_users}
Activos: ${stats.active_users}
Tests: ${stats.test_users}
Premium: ${stats.premium_users}

VENTAS:
Total: ${stats.total_sales}
Ingresos: $${stats.total_income}
Comisiones: $${stats.total_commission}

Comisión: ${reseller.commission_value}%`);
                        return;
                    }
                    
                    if (text === '4') {
                        await client.sendText(from, '📲 Enviando app...');
                        await sendAppFile(from);
                        return;
                    }
                    
                    if (userState.state === 'reseller_creating_user') {
                        const reseller = userState.data;
                        if (text === '0') {
                            await setUserState(from, 'reseller_authenticated', reseller);
                            await client.sendText(from, '❌ Cancelado');
                            return;
                        }
                        await setUserState(from, 'reseller_selecting_plan', { ...reseller, userPhone: text });
                        await client.sendText(from, `📱 SELECCIONAR PLAN

Usuario: ${text}

1️⃣ - 7 DIAS - $${config.prices.price_7d}
2️⃣ - 15 DIAS - $${config.prices.price_15d}
3️⃣ - 30 DIAS - $${config.prices.price_30d}
4️⃣ - PRUEBA (${config.prices.test_hours}h GRATIS)
0️⃣ - CANCELAR`);
                        return;
                    }
                    
                    if (userState.state === 'reseller_selecting_plan') {
                        const data = userState.data;
                        const reseller = data;
                        const userPhone = data.userPhone;
                        
                        if (text === '0') {
                            await setUserState(from, 'reseller_authenticated', reseller);
                            await client.sendText(from, '❌ Cancelado');
                            return;
                        }
                        
                        const planMap = {
                            '1': { days: 7, price: config.prices.price_7d, type: 'premium' },
                            '2': { days: 15, price: config.prices.price_15d, type: 'premium' },
                            '3': { days: 30, price: config.prices.price_30d, type: 'premium' },
                            '4': { days: 0, price: 0, type: 'test' }
                        };
                        
                        const plan = planMap[text];
                        if (!plan) {
                            await client.sendText(from, '❌ Opción inválida');
                            return;
                        }
                        
                        await client.sendText(from, '⏳ Creando usuario...');
                        
                        const username = plan.type === 'test' ? generateUsername() : generatePremiumUsername();
                        const result = await createSSHUser(userPhone, username, plan.days, reseller.id);
                        
                        if (result.success) {
                            let msg = `✅ USUARIO CREADO

👤 Usuario: ${username}
🔑 Contraseña: cloudvpn
📱 Teléfono: ${userPhone}`;
                            
                            if (plan.type === 'test') {
                                msg += `\n⏰ Expira: ${config.prices.test_hours} horas\n🎁 PRUEBA GRATUITA`;
                            } else {
                                msg += `\n📅 Expira: ${moment(result.expires).format('DD/MM/YYYY HH:mm')}`;
                                msg += `\n💰 Plan: ${plan.days} días - $${plan.price}`;
                                
                                const paymentId = `RESELLER-${reseller.id}-${Date.now()}`;
                                const commission = plan.price * (reseller.commission_value / 100);
                                db.run(`INSERT INTO payments (payment_id, phone, plan, days, amount, status, reseller_id, commission, approved_at)
                                        VALUES (?, ?, ?, ?, ?, 'approved', ?, ?, CURRENT_TIMESTAMP)`,
                                    [paymentId, userPhone, `${plan.days}d`, plan.days, plan.price, reseller.id, commission]);
                            }
                            
                            await client.sendText(from, msg);
                            await client.sendText(userPhone, `🎉 CUENTA SSH ACTIVADA

👤 Usuario: ${username}
🔑 Contraseña: cloudvpn
📲 Envía "APK" para descargar la app`);
                        } else {
                            await client.sendText(from, `❌ Error: ${result.error}`);
                        }
                        
                        await setUserState(from, 'reseller_authenticated', reseller);
                        return;
                    }
                    
                    if (text.toLowerCase() === 'salir') {
                        await clearUserState(from);
                        await client.sendText(from, '👋 Sesión cerrada');
                        return;
                    }
                    return;
                }
                
                // CLIENTES - MENU PRINCIPAL
                if (text.toLowerCase() === 'menu' || text.toLowerCase() === 'hola' || text.toLowerCase() === 'start') {
                    await client.sendText(from, '⏳ Creando prueba gratuita...');
                    
                    const username = generateUsername();
                    const result = await createSSHUser(from, username, 0, null);
                    
                    if (result.success) {
                        await client.sendText(from, `✅ PRUEBA CREADA

🎁 TESTS ILIMITADOS

👤 Usuario: ${username}
🔑 Contraseña: cloudvpn
⏰ Expira: ${config.prices.test_hours} horas

📲 Envía "APK" para descargar la app
🔄 Envía "MENU" para otra prueba`);
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    return;
                }
                
                if (text.toLowerCase() === 'apk') {
                    const sent = await sendAppFile(from);
                    if (!sent) await client.sendText(from, '📲 App no disponible temporalmente');
                    return;
                }
                
                // LOGIN REVENDEDORES
                if (text.toUpperCase().startsWith('LOGIN ')) {
                    const parts = text.split(' ');
                    if (parts.length >= 3) {
                        const reseller = await authenticateReseller(parts[1], parts[2]);
                        if (reseller) {
                            await setUserState(from, 'reseller_authenticated', reseller);
                            await client.sendText(from, `✅ Bienvenido ${reseller.name}\nEnvía MENU para ver opciones`);
                        } else {
                            await client.sendText(from, '❌ Login fallido');
                        }
                    }
                    return;
                }
                
                // MENSAJE POR DEFECTO
                if (text && !text.startsWith('LOGIN')) {
                    await client.sendText(from, `🤖 SSH BOT PRO

Envía MENU para prueba gratuita de ${config.prices.test_hours} horas

Si eres revendedor: LOGIN usuario contraseña
Descargar app: APK`);
                }
                
            } catch (error) {
                console.error(chalk.red('Error:', error.message));
            }
        });
        
        // LIMPIEZA CADA 15 MINUTOS
        cron.schedule('*/15 * * * *', async () => {
            const now = moment().format('YYYY-MM-DD HH:mm:ss');
            db.all('SELECT username FROM users WHERE expires_at < ? AND status = 1', [now], async (err, rows) => {
                if (rows && rows.length > 0) {
                    for (const r of rows) {
                        await execPromise(`userdel -f ${r.username} 2>/dev/null || true`);
                        db.run('UPDATE users SET status = 0 WHERE username = ?', [r.username]);
                    }
                }
            });
        });
        
        // LIMPIAR ESTADOS
        cron.schedule('0 * * * *', () => {
            db.run(`DELETE FROM user_state WHERE updated_at < datetime('now', '-1 hour')`);
        });
        
    } catch (error) {
        console.error(chalk.red('Error:', error.message));
        setTimeout(initializeBot, 10000);
    }
}

initializeBot();

process.on('SIGINT', async () => {
    if (client) await client.close();
    process.exit();
});
BOTEOF

echo -e "${GREEN}✅ Bot creado${NC}"

# ================================================
# INSTALAR PM2
# ================================================
echo -e "\n${CYAN}⚡ Instalando PM2...${NC}"

npm install -g pm2 --silent
pm2 kill 2>/dev/null || true
sleep 1

cd "$USER_HOME"
pm2 start bot.js --name sshbot-pro
pm2 save
pm2 startup systemd -u root --hp /root 2>/dev/null || true

echo -e "${GREEN}✅ PM2 instalado${NC}"

# ================================================
# PANEL ADMIN COMPLETO
# ================================================
cat > /usr/local/bin/reseller-admin << 'ADMINEOF'
#!/bin/bash

DB="/opt/sshbot-pro/data/users.db"
CONFIG="/opt/sshbot-pro/config/config.json"
APK_PATH="/root/mgvpn.apk"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }

# Función para escanear QR
scan_qr() {
    echo ""
    echo "========================================="
    echo "     ESCANEAR QR - WHATSAPP BOT"
    echo "========================================="
    echo ""
    echo "📱 Para conectar el bot a WhatsApp:"
    echo ""
    echo "1. Abre WhatsApp en tu teléfono"
    echo "2. Ve a 'Dispositivos vinculados'"
    echo "3. Toca 'Vincular un dispositivo'"
    echo "4. Escanea el código QR que aparecerá"
    echo ""
    echo "========================================="
    echo ""
    read -p "Presiona Enter para ver el QR..."
    
    # Detener y reiniciar para mostrar QR
    pm2 stop sshbot-pro 2>/dev/null
    rm -rf /root/.wppconnect/sshbot-pro-session 2>/dev/null
    pm2 start sshbot-pro
    sleep 3
    
    echo ""
    echo "📱 ESCANEA EL SIGUIENTE CÓDIGO QR:"
    echo "========================================="
    echo ""
    
    # Mostrar logs con QR
    pm2 logs sshbot-pro --lines 50 --nostream
}

# Función para configurar MercadoPago
setup_mercadopago() {
    echo ""
    echo "========================================="
    echo "     MERCADOPAGO - CONFIGURACIÓN"
    echo "========================================="
    echo ""
    echo "📝 Ingresa tu Access Token de MercadoPago"
    echo "👉 Puedes obtenerlo en: developers.mercadopago.com"
    echo ""
    read -p "Access Token: " MP_TOKEN
    
    if [ -n "$MP_TOKEN" ]; then
        sed -i "s/\"access_token\": \"[^\"]*\"/\"access_token\": \"$MP_TOKEN\"/" $CONFIG
        sed -i "s/\"enabled\": false/\"enabled\": true/" $CONFIG
        echo ""
        echo "✅ MercadoPago configurado correctamente"
        echo "ℹ️  Reinicia el bot para aplicar cambios: pm2 restart sshbot-pro"
    else
        echo "❌ Token no válido"
    fi
}

# Función para subir APK
upload_apk() {
    echo ""
    echo "========================================="
    echo "     SUBIR APK - APLICACIÓN"
    echo "========================================="
    echo ""
    echo "📲 Sube el archivo APK de MGVPN"
    echo "El archivo se guardará como: mgvpn.apk"
    echo ""
    echo "Opciones:"
    echo "1) Subir desde URL"
    echo "2) Subir desde archivo local"
    echo "0) Cancelar"
    echo ""
    read -p "Opción: " UPLOAD_OPT
    
    case $UPLOAD_OPT in
        1)
            read -p "URL del APK: " APK_URL
            if [ -n "$APK_URL" ]; then
                echo "⏳ Descargando APK..."
                wget -O "$APK_PATH" "$APK_URL"
                if [ $? -eq 0 ]; then
                    echo "✅ APK descargado correctamente"
                    ls -lh "$APK_PATH"
                else
                    echo "❌ Error al descargar"
                fi
            fi
            ;;
        2)
            echo "📂 Sube el archivo APK a este directorio: /root/"
            echo "El archivo debe llamarse 'mgvpn.apk'"
            echo ""
            echo "Puedes usar SCP o SFTP para transferir el archivo"
            echo "Ejemplo: scp tu-app.apk root@$SERVER_IP:/root/mgvpn.apk"
            echo ""
            read -p "Presiona Enter cuando hayas subido el archivo..."
            if [ -f "$APK_PATH" ]; then
                echo "✅ APK encontrado: $(ls -lh $APK_PATH)"
            else
                echo "❌ No se encontró el archivo en /root/mgvpn.apk"
            fi
            ;;
        *)
            echo "❌ Cancelado"
            ;;
    esac
}

while true; do
    clear
    echo "========================================="
    echo "     PANEL ADMIN - SSH BOT PRO"
    echo "========================================="
    echo ""
    echo "1) Crear revendedor"
    echo "2) Listar revendedores"
    echo "3) Ver usuarios"
    echo "4) Ver pagos"
    echo "5) Estadísticas"
    echo "6) Editar precios"
    echo "7) 📱 Escanear QR (Conectar WhatsApp)"
    echo "8) 💰 Configurar MercadoPago"
    echo "9) 📲 Subir APK"
    echo "0) Salir"
    echo ""
    read -p "Opción: " OPT
    
    case $OPT in
        1)
            echo ""
            read -p "Nombre: " NAME
            read -p "Usuario: " USER
            read -p "Contraseña: " PASS
            read -p "Comisión (%): " COM
            sqlite3 "$DB" "INSERT INTO resellers (username, password, name, commission_value) VALUES ('$USER', '$PASS', '$NAME', $COM)" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "✅ Revendedor creado"
                echo "📝 Login: $USER / $PASS"
            else
                echo "❌ Error: Usuario ya existe"
            fi
            ;;
        2)
            echo ""
            sqlite3 -column -header "$DB" "SELECT id, name, username, commission_value, status FROM resellers WHERE username!='admin'"
            ;;
        3)
            echo ""
            sqlite3 -column -header "$DB" "SELECT username, phone, tipo, expires_at, status FROM users ORDER BY created_at DESC LIMIT 20"
            ;;
        4)
            echo ""
            sqlite3 -column -header "$DB" "SELECT payment_id, phone, plan, amount, status, created_at FROM payments ORDER BY created_at DESC LIMIT 20"
            ;;
        5)
            echo ""
            TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users")
            ACTIVE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1")
            TESTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE tipo='test'")
            PREMIUM=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE tipo='premium'")
            RESELLERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM resellers WHERE username!='admin'")
            SALES=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='approved'")
            INCOME=$(sqlite3 "$DB" "SELECT printf('%.2f', SUM(amount)) FROM payments WHERE status='approved'")
            
            echo "📊 ESTADÍSTICAS"
            echo "================"
            echo "Usuarios totales: $TOTAL"
            echo "Usuarios activos: $ACTIVE"
            echo "Tests creados: $TESTS (ILIMITADOS)"
            echo "Usuarios premium: $PREMIUM"
            echo "Revendedores: $RESELLERS"
            echo "Ventas: $SALES"
            echo "Ingresos: $$INCOME"
            echo "Contraseña: cloudvpn"
            ;;
        6)
            echo ""
            echo "Precios actuales:"
            echo "7 días: $ $(get_val '.prices.price_7d')"
            echo "15 días: $ $(get_val '.prices.price_15d')"
            echo "30 días: $ $(get_val '.prices.price_30d')"
            echo ""
            read -p "Nuevo precio 7 días: " P7
            read -p "Nuevo precio 15 días: " P15
            read -p "Nuevo precio 30 días: " P30
            [ -n "$P7" ] && sed -i "s/\"price_7d\": [0-9.]*,/\"price_7d\": $P7,/" $CONFIG
            [ -n "$P15" ] && sed -i "s/\"price_15d\": [0-9.]*,/\"price_15d\": $P15,/" $CONFIG
            [ -n "$P30" ] && sed -i "s/\"price_30d\": [0-9.]*,/\"price_30d\": $P30,/" $CONFIG
            echo "✅ Precios actualizados (reinicia el bot)"
            ;;
        7)
            scan_qr
            ;;
        8)
            setup_mercadopago
            ;;
        9)
            upload_apk
            ;;
        0)
            exit 0
            ;;
    esac
    read -p "Enter para continuar..."
done
ADMINEOF

chmod +x /usr/local/bin/reseller-admin

# ================================================
# MENSAJE FINAL
# ================================================
clear
echo -e "${GREEN}${BOLD}"
cat << "FINAL"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              🎉 INSTALACIÓN COMPLETADA 🎉                   ║
║                                                              ║
║       🔑 CONTRASEÑA USUARIOS: cloudvpn                     ║
║       🎁 TESTS ILIMITADOS                                   ║
║       📅 PLANES: 7, 15, 30 DÍAS                            ║
║       👥 SISTEMA DE REVENDEDORES                           ║
║       📱 NO SUBE ESTADO A WHATSAPP                         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Sistema instalado correctamente${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 COMANDOS PRINCIPALES:${NC}"
echo -e "  ${GREEN}reseller-admin${NC}      - Panel de administración"
echo -e "  ${GREEN}pm2 logs sshbot-pro${NC}  - Ver logs y escanear QR"
echo -e "  ${GREEN}pm2 restart sshbot-pro${NC} - Reiniciar bot"
echo -e "  ${GREEN}pm2 status${NC}           - Ver estado del bot"
echo -e ""

echo -e "${YELLOW}🔐 CREDENCIALES ADMIN:${NC}"
echo -e "  Usuario: ${GREEN}admin${NC}"
echo -e "  Contraseña: ${GREEN}admin123${NC}"
echo -e ""

echo -e "${YELLOW}📱 PARA CLIENTES (WhatsApp):${NC}"
echo -e "  Enviar: ${GREEN}MENU${NC} - Crea prueba gratuita automáticamente"
echo -e "  Enviar: ${GREEN}APK${NC} - Descargar aplicación"
echo -e ""

echo -e "${YELLOW}📱 PARA REVENDEDORES (WhatsApp):${NC}"
echo -e "  Enviar: ${GREEN}LOGIN usuario contraseña${NC}"
echo -e "  Luego enviar: ${GREEN}MENU${NC} para ver opciones"
echo -e ""

echo -e "${GREEN}🎁 Los clientes pueden crear TESTS ILIMITADOS sin restricción diaria${NC}"
echo -e "${GREEN}🔇 El bot NO SUBE ESTADO a WhatsApp${NC}"
echo -e ""

read -p "$(echo -e "${YELLOW}¿Ver logs ahora para escanear el QR? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}Mostrando logs... Espera el código QR para escanear${NC}\n"
    sleep 2
    pm2 logs sshbot-pro
fi

exit 0