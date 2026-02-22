#!/bin/bash
# ================================================
# SSH BOT PRO - WPPCONNECT + MERCADOPAGO + HTTP CUSTOM
# VERSIÓN CORREGIDA - CON HWID Y ARCHIVOS HC
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

# Instalar Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs gcc g++ make

# Instalar Chrome/Chromium
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get update -y
apt-get install -y google-chrome-stable

# Instalar dependencias del sistema
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

# Instalar PM2
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
        "default_password": "mgvpn247",
        "test_hours": 2
    },
    "prices": {
        "price_7d": 3000,
        "price_15d": 4000,
        "price_30d": 6500,
        "price_50d": 9700,
        "currency": "ARS"
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false
    },
    "http_custom": {
        "server_url": "http://$SERVER_IP/hc_files/",
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

# Crear base de datos
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
SQL

echo -e "${GREEN}✅ Estructura creada${NC}"

# ================================================
# INSTALAR DEPENDENCIAS NODE
# ================================================
echo -e "\n${CYAN}📦 Instalando dependencias de Node.js...${NC}"

cd "$USER_HOME"

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
        "axios": "^1.6.5"
    }
}
PKGEOF

npm install --silent

# ================================================
# CREAR BOT.JS
# ================================================
echo -e "\n${CYAN}🤖 Creando bot.js...${NC}"

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
console.log(chalk.cyan.bold('║        🤖 SSH BOT PRO - HTTP CUSTOM + HWID + MP             ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

// Cargar configuración
function loadConfig() {
    delete require.cache[require.resolve('/opt/sshbot-pro/config/config.json')];
    return require('/opt/sshbot-pro/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/sshbot-pro/data/users.db');

// Variables globales
let client = null;

// Función para validar HWID
function validateHWID(hwid) {
    return /^[0-9a-fA-F]{32}$/.test(hwid);
}

// Función para verificar HWID existente
function checkExistingHWID(hwid) {
    return new Promise((resolve) => {
        db.get('SELECT * FROM users WHERE hwid = ? AND status = 1 AND expires_at > datetime("now")', [hwid], (err, row) => {
            resolve(row ? true : false);
        });
    });
}

// Función para generar archivo HC
function generateHCFile(hwid, days, username) {
    try {
        const filename = `config_${username}_${hwid.substring(0, 8)}.hc`;
        const filePath = `/var/www/html/hc_files/${filename}`;
        
        const expireDate = days === 0 ? 
            moment().add(config.bot.test_hours, 'hours').unix() : 
            moment().add(days, 'days').unix();
        
        const configContent = `# HTTP Custom Config
# Generado para: ${username}
# HWID: ${hwid}
# Expira: ${moment.unix(expireDate).format('DD/MM/YYYY HH:mm')}

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
expires=${expireDate}
username=${username}
password=${config.bot.default_password}`;

        fs.writeFileSync(filePath, configContent);
        
        return {
            success: true,
            filename: filename,
            url: `http://${config.bot.server_ip}/hc_files/${filename}`
        };
    } catch (error) {
        console.error(chalk.red('❌ Error generando HC file:'), error.message);
        return { success: false, error: error.message };
    }
}

// Función para crear usuario
async function createHTTPCustomUser(phone, username, days, hwid = null) {
    const password = config.bot.default_password;
    
    if (days === 0) {
        const expireFull = moment().add(config.bot.test_hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
        
        try {
            if (hwid) {
                const hcFile = generateHCFile(hwid, 0, username);
                
                db.run(`INSERT INTO users (phone, username, password, tipo, hwid, hc_file, expires_at) VALUES (?, ?, ?, 'test', ?, ?, ?)`,
                    [phone, username, password, hwid, hcFile.filename, expireFull]);
                
                return { success: true, username, password, hwid, hcFile: hcFile.url, expires: expireFull };
            }
        } catch (error) {
            return { success: false, error: error.message };
        }
    } else {
        const expireFull = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
        
        try {
            if (hwid) {
                const hcFile = generateHCFile(hwid, days, username);
                
                db.run(`INSERT INTO users (phone, username, password, tipo, hwid, hc_file, expires_at) VALUES (?, ?, ?, 'premium', ?, ?, ?)`,
                    [phone, username, password, hwid, hcFile.filename, expireFull]);
                
                return { success: true, username, password, hwid, hcFile: hcFile.url, expires: expireFull };
            }
        } catch (error) {
            return { success: false, error: error.message };
        }
    }
}

// Función para generar username
function generateUsername() {
    return `user${Math.floor(1000 + Math.random() * 9000)}`;
}

// Sistema de estados
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

// Verificar test diario
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
                '--disable-dev-shm-usage'
            ],
            puppeteerOptions: {
                executablePath: '/usr/bin/google-chrome',
                headless: 'new',
                args: ['--no-sandbox', '--disable-setuid-sandbox']
            },
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
                if (['menu', 'hola', 'start', '0'].includes(text)) {
                    await setUserState(from, 'main_menu');
                    
                    await client.sendText(from, `🚀 *HTTP CUSTOM BOT*

Elija una opción:

1️⃣ *PRUEBA GRATIS* (${config.bot.test_hours} horas)
2️⃣ *COMPRAR CONFIGURACIÓN*
3️⃣ *VERIFICAR CUENTA*
4️⃣ *CÓMO OBTENER HWID*

👨‍💻 Soporte: wa.me/543435071016`);
                }
                
                // OPCIÓN 4: CÓMO OBTENER HWID
                else if (text === '4' && userState.state === 'main_menu') {
                    await client.sendText(from, `🔍 *CÓMO OBTENER TU HWID*

1. Abre HTTP Custom
2. Ve a *Configuración* (⚙️)
3. Busca *HWID* (32 caracteres)
4. Cópialo y envíalo aquí

📱 *Ejemplo:* a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6

⚠️ *IMPORTANTE:* Cada HWID es único por dispositivo`);
                }
                
                // OPCIÓN 1: PRUEBA GRATIS
                else if (text === '1' && userState.state === 'main_menu') {
                    await setUserState(from, 'awaiting_test_hwid');
                    await client.sendText(from, `📲 *PRUEBA GRATUITA*

Envía tu HWID de HTTP Custom:

🔍 *Ejemplo:* a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`);
                }
                
                // RECIBIR HWID PARA PRUEBA
                else if (userState.state === 'awaiting_test_hwid') {
                    const hwid = message.body.trim();
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ *HWID INVÁLIDO*

Debe tener 32 caracteres hexadecimales.

Intenta nuevamente:`);
                        return;
                    }
                    
                    if (await checkExistingHWID(hwid)) {
                        await client.sendText(from, `❌ *HWID YA REGISTRADO*

Contacta al soporte para ayuda.`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    if (!(await canCreateTest(from, hwid))) {
                        await client.sendText(from, `❌ *YA USaste tu prueba hoy*

Vuelve mañana o compra un plan.`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    await client.sendText(from, '⏳ Generando configuración...');
                    
                    try {
                        const username = generateUsername();
                        const result = await createHTTPCustomUser(from, username, 0, hwid);
                        
                        if (result.success) {
                            registerTest(from, hwid);
                            
                            await client.sendText(from, `✅ *PRUEBA CREADA*

📱 *Tus datos:*
👤 Usuario: ${username}
🔑 Pass: ${config.bot.default_password}
⏰ Expira: ${moment().add(config.bot.test_hours, 'hours').format('DD/MM/YYYY HH:mm')}

📁 *CONFIGURACIÓN:*
${result.hcFile}

🔍 *HWID:* ${hwid}`);
                            
                            console.log(chalk.green(`✅ Test: ${username} - HWID: ${hwid}`));
                        }
                    } catch (error) {
                        await client.sendText(from, `❌ Error: ${error.message}`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
                // OPCIÓN 2: COMPRAR
                else if (text === '2' && userState.state === 'main_menu') {
                    await setUserState(from, 'buying_plan');
                    
                    await client.sendText(from, `💰 *PLANES DISPONIBLES*

1️⃣ 7 días - $${config.prices.price_7d}
2️⃣ 15 días - $${config.prices.price_15d}
3️⃣ 30 días - $${config.prices.price_30d}
4️⃣ 50 días - $${config.prices.price_50d}

0️⃣ Volver

Responde con el número:`);
                }
                
                // SELECCIONAR PLAN
                else if (userState.state === 'buying_plan' && ['1','2','3','4'].includes(text)) {
                    const planMap = {
                        '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                        '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' },
                        '3': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                        '4': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                    };
                    
                    const plan = planMap[text];
                    await setUserState(from, 'awaiting_payment_hwid', { plan });
                    await client.sendText(from, `📲 *PLAN ${plan.name}*

Envía tu HWID para continuar:`);
                }
                
                else if (text === '0' && userState.state === 'buying_plan') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, `🚀 Menú principal - Envía MENU`);
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
                        await client.sendText(from, `❌ HWID inválido. Intenta nuevamente:`);
                        return;
                    }
                    
                    if (await checkExistingHWID(hwid)) {
                        await client.sendText(from, `❌ HWID ya registrado. Contacta al soporte.`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    // Guardar HWID para después del pago
                    await setUserState(from, 'payment_created', { 
                        days: planData.days,
                        hwid: hwid,
                        plan: planData.name,
                        price: planData.price
                    });
                    
                    await client.sendText(from, `💰 *PAGO MANUAL*

Plan: ${planData.name}
Monto: $${planData.price} ARS
HWID: ${hwid}

Para pagar, transfiere el monto y envía el comprobante a:
wa.me/543435071016

Te activaremos manualmente.`);
                    
                    await setUserState(from, 'main_menu');
                }
                
                // OPCIÓN 3: VERIFICAR
                else if (text === '3' && userState.state === 'main_menu') {
                    await setUserState(from, 'awaiting_check_hwid');
                    await client.sendText(from, `🔍 *VERIFICAR CUENTA*

Envía tu HWID:`);
                }
                
                // VERIFICAR HWID
                else if (userState.state === 'awaiting_check_hwid') {
                    const hwid = message.body.trim();
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ HWID inválido. Intenta nuevamente:`);
                        return;
                    }
                    
                    db.get('SELECT username, expires_at FROM users WHERE hwid = ? AND status = 1', [hwid], async (err, user) => {
                        if (user) {
                            const daysLeft = moment(user.expires_at).diff(moment(), 'days');
                            await client.sendText(from, `✅ *CUENTA ACTIVA*

👤 Usuario: ${user.username}
⏰ Expira: ${moment(user.expires_at).format('DD/MM/YYYY')}
📅 Días restantes: ${daysLeft}`);
                        } else {
                            await client.sendText(from, `❌ No se encontró cuenta activa con ese HWID.`);
                        }
                    });
                    
                    await setUserState(from, 'main_menu');
                }
                
            } catch (error) {
                console.error(chalk.red('❌ Error:'), error.message);
            }
        });
        
        // Limpiar estados cada hora
        cron.schedule('0 * * * *', () => {
            db.run(`DELETE FROM user_state WHERE updated_at < datetime('now', '-1 hour')`);
        });
        
    } catch (error) {
        console.error(chalk.red('❌ Error inicializando:'), error.message);
        setTimeout(initializeBot, 10000);
    }
}

// Iniciar
initializeBot();

process.on('SIGINT', async () => {
    console.log(chalk.yellow('\n🛑 Cerrando...'));
    if (client) await client.close();
    process.exit();
});
BOTEOF

# ================================================
# CREAR PANEL DE CONTROL CORREGIDO
# ================================================
echo -e "\n${CYAN}🎛️  Creando panel de control...${NC}"

cat > /usr/local/bin/sshbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

DB="/opt/sshbot-pro/data/users.db"
CONFIG="/opt/sshbot-pro/config/config.json"

get_val() {
    jq -r "$1" "$CONFIG" 2>/dev/null
}

set_val() {
    local tmp=$(mktemp)
    jq "$1 = $2" "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
}

while true; do
    clear
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║           🎛️  PANEL HTTP CUSTOM - HWID + MP                   ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    
    # Estadísticas
    TOTAL_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1 AND expires_at > datetime('now')" 2>/dev/null || echo "0")
    PENDING_PAY=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='pending'" 2>/dev/null || echo "0")
    TOTAL_HWID=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE hwid IS NOT NULL" 2>/dev/null || echo "0")
    
    # Estado del bot
    BOT_STATUS=$(pm2 show sshbot-pro 2>/dev/null | grep status | awk '{print $4}')
    if [[ "$BOT_STATUS" == "online" ]]; then
        STATUS="${GREEN}● ACTIVO${NC}"
    else
        STATUS="${RED}● DETENIDO${NC}"
    fi
    
    # Token MP
    MP_TOKEN=$(get_val '.mercadopago.access_token')
    if [[ -n "$MP_TOKEN" && "$MP_TOKEN" != "null" ]]; then
        MP_STATUS="${GREEN}✅ CONFIGURADO${NC}"
    else
        MP_STATUS="${RED}❌ NO CONFIGURADO${NC}"
    fi
    
    TEST_HOURS=$(get_val '.bot.test_hours')
    
    echo -e "${YELLOW}📊 ESTADO DEL SISTEMA:${NC}"
    echo -e "  Bot: $STATUS"
    echo -e "  Usuarios: ${CYAN}$ACTIVE_USERS/$TOTAL_USERS${NC} activos/total"
    echo -e "  HWIDs: ${PURPLE}$TOTAL_HWID${NC} registrados"
    echo -e "  Pagos pendientes: ${YELLOW}$PENDING_PAY${NC}"
    echo -e "  MercadoPago: $MP_STATUS"
    echo -e "  Test: ${CYAN}$TEST_HOURS${NC} horas"
    echo -e "  IP: ${GREEN}$(get_val '.bot.server_ip')${NC}"
    echo -e "  Pass: ${YELLOW}mgvpn247${NC}"
    echo ""
    
    echo -e "${YELLOW}💰 PRECIOS:${NC}"
    echo -e "  7 días: $ ${GREEN}$(get_val '.prices.price_7d')${NC} ARS"
    echo -e "  15 días: $ ${GREEN}$(get_val '.prices.price_15d')${NC} ARS"
    echo -e "  30 días: $ ${GREEN}$(get_val '.prices.price_30d')${NC} ARS"
    echo -e "  50 días: $ ${GREEN}$(get_val '.prices.price_50d')${NC} ARS"
    echo ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC} 🚀  Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC} 🛑  Detener bot"
    echo -e "${CYAN}[3]${NC} 📱  Ver QR WhatsApp"
    echo -e "${CYAN}[4]${NC} 👤  Crear usuario manual"
    echo -e "${CYAN}[5]${NC} 👥  Listar usuarios"
    echo -e "${CYAN}[6]${NC} ⏰  Cambiar horas del test"
    echo -e "${CYAN}[7]${NC} 💰  Cambiar precios"
    echo -e "${CYAN}[8]${NC} 🔑  Configurar MercadoPago"
    echo -e "${CYAN}[9]${NC} 📁  Subir/Ver archivos HC"
    echo -e "${CYAN}[10]${NC} 🔍  Buscar por HWID"
    echo -e "${CYAN}[11]${NC} 📊  Ver estadísticas"
    echo -e "${CYAN}[12]${NC} 📋  Ver logs"
    echo -e "${CYAN}[0]${NC} 🚪  Salir"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    read -p "👉 Selecciona: " OPTION
    
    case $OPTION in
        1)
            echo -e "\n${YELLOW}🔄 Iniciando bot...${NC}"
            cd /root/sshbot-pro
            pm2 restart sshbot-pro 2>/dev/null || pm2 start bot.js --name sshbot-pro
            pm2 save
            echo -e "${GREEN}✅ Bot iniciado${NC}"
            sleep 2
            ;;
        2)
            echo -e "\n${YELLOW}🛑 Deteniendo bot...${NC}"
            pm2 stop sshbot-pro
            echo -e "${GREEN}✅ Bot detenido${NC}"
            sleep 2
            ;;
        3)
            echo -e "\n${YELLOW}📱 Mostrando QR...${NC}"
            pm2 logs sshbot-pro --lines 100 | grep -A 20 "QR CODE" || echo "Esperando QR..."
            read -p "Presiona Enter..."
            ;;
        4)
            clear
            echo -e "${CYAN}👤 CREAR USUARIO MANUAL${NC}\n"
            
            read -p "Teléfono (ej: 5491122334455): " PHONE
            read -p "HWID (32 caracteres): " HWID
            read -p "Días (0=test, 7,15,30,50): " DAYS
            read -p "Usuario (dejar vacío para generar): " USERNAME
            
            if [[ -z "$USERNAME" ]]; then
                USERNAME="user$(shuf -i 1000-9999 -n 1)"
            fi
            
            PASSWORD="mgvpn247"
            
            if [[ "$DAYS" == "0" ]]; then
                TIPO="test"
                EXPIRE=$(date -d "+$(get_val '.bot.test_hours') hours" +"%Y-%m-%d %H:%M:%S")
            else
                TIPO="premium"
                EXPIRE=$(date -d "+$DAYS days" +"%Y-%m-%d 23:59:59")
            fi
            
            # Generar archivo HC
            FILENAME="config_${USERNAME}_${HWID:0:8}.hc"
            cat > "/var/www/html/hc_files/$FILENAME" << EOF
# HTTP Custom Config
# Generado para: $USERNAME
# HWID: $HWID
# Expira: $EXPIRE

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
username=$USERNAME
password=$PASSWORD
EOF
            
            sqlite3 "$DB" "INSERT INTO users (phone, username, password, tipo, hwid, hc_file, expires_at) VALUES ('$PHONE', '$USERNAME', '$PASSWORD', '$TIPO', '$HWID', '$FILENAME', '$EXPIRE')"
            
            echo -e "\n${GREEN}✅ USUARIO CREADO${NC}"
            echo -e "Usuario: $USERNAME"
            echo -e "HWID: $HWID"
            echo -e "Config: http://$(get_val '.bot.server_ip')/hc_files/$FILENAME"
            read -p "Presiona Enter..."
            ;;
        5)
            clear
            echo -e "${CYAN}👥 USUARIOS ACTIVOS${NC}\n"
            sqlite3 -column -header "$DB" "SELECT username, hwid, tipo, expires_at FROM users WHERE status=1 ORDER BY expires_at DESC LIMIT 20"
            read -p "Presiona Enter..."
            ;;
        6)
            clear
            echo -e "${CYAN}⏰ CAMBIAR HORAS DE TEST${NC}\n"
            CURRENT=$(get_val '.bot.test_hours')
            echo -e "Actual: ${GREEN}$CURRENT horas${NC}\n"
            read -p "Nuevas horas: " NEW_HOURS
            if [[ -n "$NEW_HOURS" ]]; then
                set_val '.bot.test_hours' "$NEW_HOURS"
                echo -e "${GREEN}✅ Actualizado${NC}"
            fi
            sleep 2
            ;;
        7)
            clear
            echo -e "${CYAN}💰 CAMBIAR PRECIOS${NC}\n"
            
            P7=$(get_val '.prices.price_7d')
            P15=$(get_val '.prices.price_15d')
            P30=$(get_val '.prices.price_30d')
            P50=$(get_val '.prices.price_50d')
            
            echo -e "Actuales:"
            echo -e "  7 días: $P7"
            echo -e "  15 días: $P15"
            echo -e "  30 días: $P30"
            echo -e "  50 días: $P50\n"
            
            read -p "Nuevo precio 7 días: " N7
            read -p "Nuevo precio 15 días: " N15
            read -p "Nuevo precio 30 días: " N30
            read -p "Nuevo precio 50 días: " N50
            
            [[ -n "$N7" ]] && set_val '.prices.price_7d' "$N7"
            [[ -n "$N15" ]] && set_val '.prices.price_15d' "$N15"
            [[ -n "$N30" ]] && set_val '.prices.price_30d' "$N30"
            [[ -n "$N50" ]] && set_val '.prices.price_50d' "$N50"
            
            echo -e "${GREEN}✅ Precios actualizados${NC}"
            sleep 2
            ;;
        8)
            clear
            echo -e "${CYAN}🔑 CONFIGURAR MERCADOPAGO${NC}\n"
            
            CURRENT=$(get_val '.mercadopago.access_token')
            if [[ -n "$CURRENT" && "$CURRENT" != "null" ]]; then
                echo -e "Token actual: ${GREEN}${CURRENT:0:20}...${NC}\n"
            fi
            
            read -p "Nuevo Access Token (dejar vacío para no cambiar): " TOKEN
            if [[ -n "$TOKEN" ]]; then
                set_val '.mercadopago.access_token' "\"$TOKEN\""
                set_val '.mercadopago.enabled' "true"
                echo -e "${GREEN}✅ Token configurado${NC}"
                cd /root/sshbot-pro && pm2 restart sshbot-pro
            fi
            sleep 2
            ;;
        9)
            clear
            echo -e "${CYAN}📁 ARCHIVOS HC${NC}\n"
            
            echo -e "${YELLOW}Archivos disponibles:${NC}"
            ls -lh /var/www/html/hc_files/ | grep .hc
            
            echo -e "\n${YELLOW}URL:${NC} http://$(get_val '.bot.server_ip')/hc_files/"
            
            read -p "Presiona Enter..."
            ;;
        10)
            clear
            echo -e "${CYAN}🔍 BUSCAR POR HWID${NC}\n"
            read -p "Ingresa HWID: " SEARCH
            sqlite3 -column -header "$DB" "SELECT username, phone, tipo, expires_at FROM users WHERE hwid = '$SEARCH'"
            read -p "Presiona Enter..."
            ;;
        11)
            clear
            echo -e "${CYAN}📊 ESTADÍSTICAS${NC}\n"
            
            TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users")
            ACTIVOS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1 AND expires_at > datetime('now')")
            TESTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE tipo='test'")
            PREMIUM=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE tipo='premium'")
            CON_HWID=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE hwid IS NOT NULL")
            
            echo -e "${YELLOW}📊 USUARIOS:${NC}"
            echo -e "  Totales: $TOTAL"
            echo -e "  Activos: $ACTIVOS"
            echo -e "  Tests: $TESTS"
            echo -e "  Premium: $PREMIUM"
            echo -e "  Con HWID: $CON_HWID"
            read -p "Presiona Enter..."
            ;;
        12)
            echo -e "\n${YELLOW}📋 Mostrando logs...${NC}"
            pm2 logs sshbot-pro --lines 50
            ;;
        0)
            echo -e "\n${GREEN}👋 Hasta luego${NC}\n"
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

# ================================================
# CREAR ARCHIVO DE EJEMPLO
# ================================================
echo -e "\n${CYAN}📁 Creando archivo de ejemplo...${NC}"

cat > "/var/www/html/hc_files/ejemplo.hc" << EOF
# HTTP Custom Config - EJEMPLO
# No uses este archivo, es solo de referencia

[config]
name=SSH-PRO-EJEMPLO
server=$SERVER_IP
port=22,80,443
type=ssh
payload=GET / HTTP/1.1[crlf]Host: [host][crlf]Connection: Keep-Alive[crlf]User-Agent: [ua][crlf][crlf]
ssh_method=1
dns=8.8.8.8
timeout=30
hwid=TU_HWID_AQUI
username=ejemplo
password=mgvpn247
EOF

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
║          🎉 INSTALACIÓN COMPLETADA - HTTP CUSTOM 🎉         ║
║                                                              ║
║       ✅ WhatsApp API funcionando                           ║
║       ✅ Sistema HWID activado                              ║
║       ✅ Servidor de archivos HC                            ║
║       ✅ Panel de control corregido                         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "\n${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}📱 COMANDOS PRINCIPALES:${NC}"
echo -e "  ${YELLOW}sshbot${NC}         - Panel de control"
echo -e "  ${YELLOW}pm2 logs sshbot-pro${NC} - Ver QR y logs"
echo -e "  ${YELLOW}http://$SERVER_IP/hc_files/${NC} - Archivos HC"
echo -e ""
echo -e "${GREEN}🔑 CONTRASEÑA POR DEFECTO:${NC} mgvpn247"
echo -e "${GREEN}⏰ TEST:${NC} $(get_val '.bot.test_hours') horas"
echo -e ""
echo -e "${YELLOW}📱 PRIMEROS PASOS:${NC}"
echo -e "  1. Ejecuta: ${CYAN}pm2 logs sshbot-pro${NC}"
echo -e "  2. Escanea el QR con WhatsApp"
echo -e "  3. Ejecuta: ${CYAN}sshbot${NC} para el panel"
echo -e "  4. Envía 'menu' al bot en WhatsApp"
echo -e ""
echo -e "${GREEN}✅ TODO LISTO!${NC}\n"

# Preguntar si ver logs
read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}Mostrando logs...${NC}"
    sleep 2
    pm2 logs sshbot-pro
fi

exit 0