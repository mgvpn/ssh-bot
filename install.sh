#!/bin/bash
# ================================================
# SSH BOT PRO - WPPCONNECT + MERCADOPAGO COMPLETO
# VERSIÓN SIMPLIFICADA: Sin cupones, sin números azules
# CON RECORDATORIOS DE VENCIMIENTO AUTOMÁTICOS
# CON SUBIDA DE APK DESDE PANEL
# PRUEBA: 2 HORAS
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
║          🤖 SSH BOT PRO - WPPCONNECT + MERCADOPAGO          ║
║               📱 WhatsApp API FUNCIONANDO                   ║
║               💰 MercadoPago SDK v2.x INTEGRADO            ║
║               💳 Pago automático con QR                    ║
║               🔔 RECORDATORIOS AUTOMÁTICOS                  ║
║               ⏰ PRUEBA DE 2 HORAS                          ║
║               🎛️  Panel completo con control MP           ║
║               📲 ENVÍO DE APP POR WHATSAPP                  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CARACTERÍSTICAS PRINCIPALES:${NC}"
echo -e "  📱 ${CYAN}WPPConnect${NC} - API WhatsApp que funciona"
echo -e "  💰 ${GREEN}MercadoPago SDK v2.x${NC} - Integrado completo"
echo -e "  💳 ${YELLOW}Pago automático${NC} - QR + Enlace de pago"
echo -e "  🔔 ${PURPLE}Recordatorios${NC} - 24h, 12h, 6h y 1h antes"
echo -e "  ⏰ ${BLUE}PRUEBA GRATIS${NC} - 2 HORAS de duración"
echo -e "  🎛️  ${CYAN}Panel completo${NC} - Control total del sistema"
echo -e "  📊 ${GREEN}Estadísticas${NC} - Ventas, usuarios, ingresos"
echo -e "  ⚡ ${YELLOW}Auto-verificación${NC} - Pagos verificados cada 2 min"
echo -e "  📲 ${CYAN}Envío APP${NC} - Archivo APK directo por WhatsApp"
echo -e "  💰 ${GREEN}Editar precios${NC} - Desde el panel"
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

# Node.js 18.x (compatible con WPPConnect y MercadoPago)
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
        "name": "SSH Bot Pro",
        "version": "2.0-MP-RECORDATORIOS-2H",
        "server_ip": "$SERVER_IP",
        "default_password": "mgvpn247"
    },
    "prices": {
        "test_hours": 2,
        "price_7d": 3000.00,
        "price_15d": 4000.00,
        "price_30d": 7000.00,
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
        "times": [24, 12, 6, 1]
    },
    "links": {
        "app_download": "https://www.mediafire.com/file/tvt0vpmyfg3xqhj/mgvpn.apk/file",
        "support": "https://wa.me/543435071016"
    },
    "paths": {
        "database": "$DB_FILE",
        "qr_codes": "$INSTALL_DIR/qr_codes",
        "sessions": "/root/.wppconnect",
        "apk_file": "$APK_PATH"
    }
}
EOF

# Crear base de datos COMPLETA
sqlite3 "$DB_FILE" << 'SQL'
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
CREATE TABLE daily_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    date DATE,
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
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_preference ON payments(preference_id);
SQL

echo -e "${GREEN}✅ Estructura creada con MercadoPago${NC}"

# ================================================
# CREAR BOT COMPLETO CON MERCADOPAGO Y RECORDATORIOS
# ================================================
echo -e "\n${CYAN}🤖 Creando bot con WPPConnect + MercadoPago + Recordatorios + Envío APP...${NC}"

cd "$USER_HOME"

# package.json con todas las dependencias
cat > package.json << 'PKGEOF'
{
    "name": "sshbot-pro",
    "version": "2.0.0",
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

# Crear bot.js COMPLETO con MercadoPago, RECORDATORIOS y envío de APK
echo -e "${YELLOW}📝 Creando bot.js con MercadoPago, Recordatorios y envío APP...${NC}"

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
console.log(chalk.cyan.bold('║      🤖 SSH BOT PRO - WPPCONNECT + MP + RECORDATORIOS        ║'));
console.log(chalk.cyan.bold('║              📲 ENVÍO DE APP POR WHATSAPP                     ║'));
console.log(chalk.cyan.bold('║                    🕒 PRUEBA DE 2 HORAS                       ║'));
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
            console.log(chalk.cyan(`🔑 Token: ${config.mercadopago.access_token.substring(0, 20)}...`));
            return true;
        } catch (error) {
            console.log(chalk.red('❌ Error inicializando MP:'), error.message);
            mpEnabled = false;
            mpClient = null;
            mpPreference = null;
            return false;
        }
    }
    console.log(chalk.yellow('⚠️ MercadoPago NO configurado'));
    return false;
}

initMercadoPago();

// Variables globales
let client = null;

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

function clearUserState(phone) {
    db.run('DELETE FROM user_state WHERE phone = ?', [phone]);
}

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

const DEFAULT_PASSWORD = 'mgvpn247';

async function createSSHUser(phone, username, days) {
    const password = DEFAULT_PASSWORD;
    
    if (days === 0) {
        // Test - 2 HORAS
        const expireFull = moment().add(config.prices.test_hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
        
        try {
            await execPromise(`useradd -m -s /bin/bash ${username} && echo "${username}:${password}" | chpasswd`);
            
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at) VALUES (?, ?, ?, 'test', ?)`,
                [phone, username, password, expireFull]);
            
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
            
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at) VALUES (?, ?, ?, 'premium', ?)`,
                [phone, username, password, expireFull]);
            
            return { success: true, username, password, expires: expireFull };
        } catch (error) {
            console.error(chalk.red('❌ Error:'), error.message);
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

// ✅ ENVIAR APK COMO ARCHIVO
async function sendAppFile(to) {
    const apkPath = '/root/mgvpn.apk';
    
    if (!fs.existsSync(apkPath)) {
        console.log(chalk.yellow(`⚠️ Archivo APK no encontrado en ${apkPath}`));
        return false;
    }
    
    try {
        await client.sendFile(
            to,
            apkPath,
            'mgvpn.apk',
            '📲 *APP MGVPN*\n\nDescarga nuestra aplicación oficial para conectar tu VPN fácilmente.\n\nInstrucciones:\n1. Descarga el archivo\n2. Haz click en "Instalar"\n3. Si aparece advertencia, haz click en "Más detalles" → "Instalar de todas formas"\n4. Configura con tus credenciales SSH\n\n*Credenciales por defecto:*\nUsuario: (el que te proporcionamos)\nContraseña: mgvpn247'
        );
        console.log(chalk.green(`✅ APK enviado a ${to}`));
        return true;
    } catch (error) {
        console.error(chalk.red(`❌ Error enviando APK: ${error.message}`));
        return false;
    }
}

// ✅ MERCADOPAGO - CREAR PAGO
async function createMercadoPagoPayment(phone, days, amount, planName) {
    try {
        if (!mpEnabled || !mpPreference) {
            console.log(chalk.red('❌ MercadoPago no inicializado'));
            return { success: false, error: 'MercadoPago no configurado' };
        }
        
        const phoneClean = phone.replace('@c.us', '');
        const paymentId = `SSH-${phoneClean}-${days}d-${Date.now()}`;
        
        console.log(chalk.cyan(`🔄 Creando pago MP: ${paymentId}`));
        
        const expirationDate = moment().add(24, 'hours');
        const isoDate = expirationDate.toISOString();
        
        const preferenceData = {
            items: [{
                title: `SSH PREMIUM ${days} DÍAS`,
                description: `Acceso SSH Premium por ${days} días - 1 conexión`,
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
            statement_descriptor: 'SSH PREMIUM'
        };
        
        console.log(chalk.yellow(`📦 Producto: ${preferenceData.items[0].title}`));
        console.log(chalk.yellow(`💰 Monto: $${amount} ${config.prices.currency || 'ARS'}`));
        
        const response = await mpPreference.create({ body: preferenceData });
        
        if (response && response.id) {
            const paymentUrl = response.init_point;
            const qrPath = `${config.paths.qr_codes}/${paymentId}.png`;
            
            await QRCode.toFile(qrPath, paymentUrl, { 
                width: 400,
                margin: 2,
                color: {
                    dark: '#000000',
                    light: '#FFFFFF'
                }
            });
            
            db.run(
                `INSERT INTO payments (payment_id, phone, plan, days, amount, status, payment_url, qr_code, preference_id) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
                [paymentId, phone, `${days}d`, days, amount, paymentUrl, qrPath, response.id],
                (err) => {
                    if (err) console.error(chalk.red('❌ Error BD:'), err.message);
                }
            );
            
            console.log(chalk.green(`✅ Pago creado: ${paymentId}`));
            
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
        
        db.run(
            `INSERT INTO logs (type, message, data) VALUES ('mp_error', ?, ?)`,
            [error.message, JSON.stringify({ stack: error.stack })]
        );
        
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
                        'Authorization': `Bearer ${config.mercadopago.access_token}`,
                        'Content-Type': 'application/json'
                    },
                    timeout: 15000
                });
                
                if (response.data && response.data.results && response.data.results.length > 0) {
                    const mpPayment = response.data.results[0];
                    
                    console.log(chalk.cyan(`📋 Pago ${payment.payment_id}: ${mpPayment.status}`));
                    
                    if (mpPayment.status === 'approved') {
                        console.log(chalk.green(`✅ PAGO APROBADO: ${payment.payment_id}`));
                        
                        // Crear usuario SSH
                        const username = generatePremiumUsername();
                        const result = await createSSHUser(payment.phone, username, payment.days);
                        
                        if (result.success) {
                            db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`, [payment.payment_id]);
                            
                            const expireDate = moment().add(payment.days, 'days').format('DD/MM/YYYY');
                            
                            const message = `✅ PAGO CONFIRMADO

🎉 Tu compra ha sido aprobada

📋 DATOS DE ACCESO:
👤 Usuario: ${username}
🔑 Contraseña: ${DEFAULT_PASSWORD}

⏰ VÁLIDO HASTA: ${expireDate}
🔌 CONEXIÓN: 1 dispositivo


🎊 ¡Disfruta del servicio premium!`;
                            
                            if (client) {
                                await client.sendText(payment.phone, message);
                            }
                            console.log(chalk.green(`✅ Usuario creado: ${username}`));
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
        
        // Estado de conexión
        client.onStateChange((state) => {
            console.log(chalk.cyan(`📱 Estado: ${state}`));
            
            if (state === 'CONNECTED') {
                console.log(chalk.green('✅ Conexión establecida con WhatsApp'));
            } else if (state === 'DISCONNECTED') {
                console.log(chalk.yellow('⚠️ Desconectado, reconectando...'));
                setTimeout(initializeBot, 10000);
            }
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
                    
                    await client.sendText(from, `HOLA BIENVENIDO BOT MGVPN IP🇦🇷

Elija una opción:

 1️⃣ - CREAR PRUEBA (2 HORAS)
 2️⃣ - COMPRAR USUARIO SSH
 3️⃣ - RENOVAR USUARIO SSH
 4️⃣ - DESCARGAR APLICACIÓN`);
                }
                
                // OPCIÓN 1: CREAR PRUEBA
                else if (text === '1' && userState.state === 'main_menu') {
                    if (!(await canCreateTest(from))) {
                        await client.sendText(from, `YA USASTE TU PRUEBA HOY

⏳ Vuelve mañana para otra prueba gratuita de 2 horas`);
                        return;
                    }
                    
                    await client.sendText(from, '⏳ Creando cuenta de prueba de 2 horas...');
                    
                    try {
                        const username = generateUsername();
                        const result = await createSSHUser(from, username, 0);
                        
                        if (result.success) {
                            registerTest(from);
                            
                            await client.sendText(from, `✅ PRUEBA DE 2 HORAS CREADA CON EXITO !

👤 Usuario: ${username}
🔐 Contraseña: ${DEFAULT_PASSWORD}
🔌 Limite: 1 dispositivo(s)
⌛️ Expira en: ${config.prices.test_hours} horas

💡 *Instrucciones:*
1. Envía "4" para descargar la APP
2. Descarga el archivo APK
3. Instala la aplicación click en mas detalles - click en instalar todas formas
4. Configura con tus credenciales SSH

⏰ *TIENES ${config.prices.test_hours} HORAS DE PRUEBA*`);

                            console.log(chalk.green(`✅ Test creado: ${username} (${config.prices.test_hours} horas)`));
                        } else {
                            await client.sendText(from, `❌ Error: ${result.error}`);
                        }
                    } catch (error) {
                        await client.sendText(from, `❌ Error al crear cuenta: ${error.message}`);
                    }
                }
                
                // OPCIÓN 2: 💰 COMPRAR USUARIO SSH
                else if (text === '2' && userState.state === 'main_menu') {
                    await setUserState(from, 'buying_ssh');
                    
                    await client.sendText(from, `🌐 PLANES SSH PREMIUM !

Elija una opción:
 1️⃣ - PLANES DIARIOS
 2️⃣ - PLANES MENSUALES
 0️⃣ - VOLVER`);
                }
                
                // SUBMENÚ DE COMPRAS
                else if (userState.state === 'buying_ssh') {
                    if (text === '1') {
                        // 🌐 PLANES DIARIOS
                        await setUserState(from, 'selecting_daily_plan');
                        
                        await client.sendText(from, `🌐 PLANES DIARIOS SSH

Elija un plan:
 1️⃣ - 7 DIAS - $${config.prices.price_7d}

 2️⃣ - 15 DIAS - $${config.prices.price_15d}

 0️⃣ - VOLVER`);
                    }
                    else if (text === '2') {
                        // 🌐 PLANES MENSUALES
                        await setUserState(from, 'selecting_monthly_plan');
                        
                        await client.sendText(from, `🌐 PLANES MENSUALES SSH

Elija un plan:
 1️⃣ - 30 DIAS - $${config.prices.price_30d}

 2️⃣ - 50 DIAS - $${config.prices.price_50d}

 0️⃣ - VOLVER`);
                    }
                    else if (text === '0') {
                        await setUserState(from, 'main_menu');
                        await client.sendText(from, `🚀 HOLA BIENVENIDO MGVPN IP🇦🇷

Elija una opción:

 1️⃣ - CREAR PRUEBA (2 HORAS GRATIS)
 2️⃣ - COMPRAR USUARIO SSH
 3️⃣ - RENOVAR USUARIO SSH
 4️⃣ - DESCARGAR APLICACIÓN`);
                    }
                }
                
                // SELECCIÓN DE PLAN DIARIO
                else if (userState.state === 'selecting_daily_plan') {
                    if (['1', '2'].includes(text)) {
                        const planMap = {
                            '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                            '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' }
                        };
                        
                        const plan = planMap[text];
                        
                        if (mpEnabled) {
                            await client.sendText(from, '⏳ Procesando tu compra...');
                            
                            const payment = await createMercadoPagoPayment(
                                from, 
                                plan.days, 
                                plan.price, 
                                plan.name
                            );
                            
                            if (payment.success) {
                                const message = `👤 USUARIO SSH

- 🌐 Plan: ${plan.name}
- 💰 Precio: $${payment.amount}
- 🔌 Límite: 1 dispositivo(s)
- 🕜 Duración: ${plan.days} días

LINK DE PAGO

${payment.paymentUrl}

⏰ Este enlace expira en 24 horas
💳 Pago seguro con MercadoPago`;
                                
                                await client.sendText(from, message);
                                
                                if (fs.existsSync(payment.qrPath)) {
                                    try {
                                        await client.sendImage(from, payment.qrPath, 'qr-pago.jpg', 
                                            `Escanea con MercadoPago\n\n${plan.name} - $${payment.amount}`);
                                    } catch (qrError) {
                                        console.error(chalk.red('⚠️ Error enviando QR:'), qrError.message);
                                    }
                                }
                                
                            } else {
                                await client.sendText(from, `ERROR AL GENERAR PAGO

${payment.error}

Contacta al administrador para otras opciones de pago.`);
                            }
                            
                            await setUserState(from, 'main_menu');
                            
                        } else {
                            await client.sendText(from, `PLAN SELECCIONADO: ${plan.name}

Precio: $${plan.price} ARS
Duración: ${plan.days} días

Para continuar con la compra, contacta al administrador:
${config.links.support}`);
                            
                            await setUserState(from, 'main_menu');
                        }
                    }
                    else if (text === '0') {
                        await setUserState(from, 'buying_ssh');
                        await client.sendText(from, `🌐 PLANES SSH PREMIUM !

Elija una opción:
 1️⃣ - PLANES DIARIOS
 2️⃣ - PLANES MENSUALES
 0️⃣ - VOLVER`);
                    }
                }
                
                // SELECCIÓN DE PLAN MENSUAL
                else if (userState.state === 'selecting_monthly_plan') {
                    if (['1', '2'].includes(text)) {
                        const planMap = {
                            '1': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                            '2': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                        };
                        
                        const plan = planMap[text];
                        
                        if (mpEnabled) {
                            await client.sendText(from, '⏳ Procesando tu compra...');
                            
                            const payment = await createMercadoPagoPayment(
                                from, 
                                plan.days, 
                                plan.price, 
                                plan.name
                            );
                            
                            if (payment.success) {
                                const message = `USUARIO SSH

- 🌐 Plan: ${plan.name}
- 💰 Precio: $${payment.amount}
- 🔌 Límite: 1 dispositivo(s)
- 🕜 Duración: ${plan.days} días

LINK DE PAGO

${payment.paymentUrl}

⏰ Este enlace expira en 24 horas
💳 Pago seguro con MercadoPago`;
                                
                                await client.sendText(from, message);
                                
                                if (fs.existsSync(payment.qrPath)) {
                                    try {
                                        await client.sendImage(from, payment.qrPath, 'qr-pago.jpg', 
                                            `Escanea con MercadoPago\n\n${plan.name} - $${payment.amount}`);
                                    } catch (qrError) {
                                        console.error(chalk.red('⚠️ Error enviando QR:'), qrError.message);
                                    }
                                }
                                
                            } else {
                                await client.sendText(from, `ERROR AL GENERAR PAGO

${payment.error}

Contacta al administrador para otras opciones de pago.`);
                            }
                            
                            await setUserState(from, 'main_menu');
                            
                        } else {
                            await client.sendText(from, `🌐 PLAN SELECCIONADO: ${plan.name}

💰 Precio: $${plan.price} ARS
🕜 Duración: ${plan.days} días

Para continuar con la compra, contacta al administrador:
${config.links.support}`);
                            
                            await setUserState(from, 'main_menu');
                        }
                    }
                    else if (text === '0') {
                        await setUserState(from, 'buying_ssh');
                        await client.sendText(from, `🌐 PLANES SSH PREMIUM !

Elija una opción:
 1️⃣ - PLANES DIARIOS
 2️⃣ - PLANES MENSUALES
 0️⃣ - VOLVER`);
                    }
                }
                
                // OPCIÓN 3: RENOVAR
                else if (text === '3' && userState.state === 'main_menu') {
                    await client.sendText(from, `RENOVAR USUARIO SSH

Para renovar tu cuenta SSH existente, contacta al administrador:
${config.links.support}`);
                }
                
                // OPCIÓN 4: DESCARGAR APP - ENVÍA ARCHIVO APK
                else if (text === '4' && userState.state === 'main_menu') {
                    const apkPath = '/root/mgvpn.apk';
                    
                    if (fs.existsSync(apkPath)) {
                        await client.sendText(from, '📲 Enviando aplicación...');
                        await sendAppFile(from);
                    } else {
                        await client.sendText(from, `DESCARGAR APLICACIÓN

🔗 Enlace de descarga temporal:
${config.links.app_download}

💡 *Instrucciones:*
1. Envía "4" para descargar la APP
2. Descarga el archivo APK
3. Instala la aplicación click en mas detalles - click en instalar todas formas
4. Configura con tus credenciales SSH


Credenciales por defecto:
Usuario: (el que te proporcionamos)
Contraseña: ${DEFAULT_PASSWORD}`);
                    }
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
        
        // ✅ LIMPIEZA CADA 15 MINUTOS
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
        
        // ✅ RECORDATORIOS DE VENCIMIENTO - CADA HORA
        cron.schedule('0 * * * *', async () => {
            if (!config.reminders || !config.reminders.enabled) {
                console.log(chalk.gray('⏸️ Recordatorios desactivados en configuración'));
                return;
            }
            
            console.log(chalk.yellow('🔔 Verificando usuarios por vencer...'));
            
            const reminderTimes = config.reminders.times || [24, 12, 6, 1];
            
            for (const hours of reminderTimes) {
                const targetTime = moment().add(hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
                
                db.all(
                    `SELECT phone, username, expires_at FROM users 
                     WHERE status = 1 
                     AND tipo = 'premium'
                     AND expires_at BETWEEN datetime('now') AND datetime(?)`,
                    [targetTime],
                    async (err, users) => {
                        if (err || !users || users.length === 0) return;
                        
                        for (const user of users) {
                            // Verificar si ya se envió recordatorio en las últimas 23 horas
                            const logCheck = await new Promise((resolve) => {
                                db.get(
                                    `SELECT id FROM logs WHERE type = 'reminder' AND message = ? AND data = ? AND created_at > datetime('now', '-23 hours')`,
                                    [`reminder_${hours}h`, user.username],
                                    (err, row) => resolve(!!row)
                                );
                            });
                            
                            if (logCheck) {
                                console.log(chalk.gray(`⏭️ Recordatorio de ${hours}h ya enviado a ${user.username}`));
                                continue;
                            }
                            
                            const expireFormatted = moment(user.expires_at).format('DD/MM/YYYY HH:mm');
                            let message = '';
                            
                            if (hours === 1) {
                                message = `⚠️ *¡ÚLTIMA HORA!*

Hola, tu cuenta SSH *${user.username}* vencerá en aproximadamente *1 HORA*.

📅 Fecha de vencimiento: ${expireFormatted}

⏰ *RENUEVA AHORA* para no perder el acceso.

Para renovar, envía *MENU* y selecciona la opción de compra.`;
                            } else {
                                message = `🔔 *RECORDATORIO DE VENCIMIENTO*

Hola, tu cuenta SSH *${user.username}* vencerá en aproximadamente *${hours} horas*.

📅 Fecha de vencimiento: ${expireFormatted}

Para renovar, envía *MENU* y selecciona la opción de compra.`;
                            }
                            
                            try {
                                if (client) {
                                    await client.sendText(user.phone, message);
                                    console.log(chalk.green(`✅ Recordatorio de ${hours}h enviado a ${user.username}`));
                                    
                                    db.run(
                                        `INSERT INTO logs (type, message, data) VALUES (?, ?, ?)`,
                                        ['reminder', `reminder_${hours}h`, user.username]
                                    );
                                }
                            } catch (error) {
                                console.error(chalk.red(`❌ Error enviando recordatorio a ${user.username}:`), error.message);
                            }
                        }
                    }
                );
            }
        });
        
        // ✅ LIMPIAR ESTADOS ANTIGUOS
        cron.schedule('0 * * * *', () => {
            db.run(`DELETE FROM user_state WHERE updated_at < datetime('now', '-1 hour')`);
        });
        
        // ✅ LIMPIAR LOGS ANTIGUOS (cada semana)
        cron.schedule('0 0 * * 0', () => {
            console.log(chalk.yellow('🧹 Limpiando logs antiguos...'));
            db.run(`DELETE FROM logs WHERE created_at < datetime('now', '-30 days')`);
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

echo -e "${GREEN}✅ Bot creado con MercadoPago, Recordatorios y envío de APP${NC}"

# ================================================
# CREAR PANEL DE CONTROL COMPLETO CON SUBIDA DE APK
# ================================================
echo -e "\n${CYAN}🎛️  Creando panel de control completo con subida de APK...${NC}"

cat > /usr/local/bin/sshbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; NC='\033[0m'

DB="/opt/sshbot-pro/data/users.db"
CONFIG="/opt/sshbot-pro/config/config.json"
APK_PATH="/root/mgvpn.apk"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }
set_val() { local t=$(mktemp); jq "$1 = $2" "$CONFIG" > "$t" && mv "$t" "$CONFIG"; }

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         🎛️  PANEL SSH BOT PRO - CON RECORDATORIOS          ║${NC}"
    echo -e "${CYAN}║              💰 MERCADOPAGO + 🔔 RECORDATORIOS              ║${NC}"
    echo -e "${CYAN}║              📲 SUBIDA DE APP POR WHATSAPP                  ║${NC}"
    echo -e "${CYAN}║                    🕒 PRUEBA DE 2 HORAS                     ║${NC}"
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
        echo -e "${CYAN}Métodos disponibles:${NC}"
        echo "$BODY" | jq -r '.[].name' 2>/dev/null | head -3
        return 0
    else
        echo -e "${RED}❌ ERROR - Código: $HTTP_CODE${NC}"
        return 1
    fi
}

upload_apk() {
    clear
    echo -e "${CYAN}📲 SUBIR APLICACIÓN (APK)${NC}\n"
    
    if [[ -f "$APK_PATH" ]]; then
        APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
        echo -e "${GREEN}✅ App actual instalada:${NC}"
        echo -e "  📁 Archivo: ${APK_PATH}"
        echo -e "  📦 Tamaño: ${APK_SIZE}"
        echo -e "  📅 Última modificación: $(stat -c %y "$APK_PATH" 2>/dev/null | cut -d. -f1)"
        echo ""
    else
        echo -e "${YELLOW}⚠️ No hay aplicación instalada actualmente${NC}\n"
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Opciones:${NC}"
    echo -e "  1. Subir nuevo APK"
    echo -e "  2. Verificar APK actual"
    echo -e "  3. Eliminar APK actual"
    echo -e "  0. Volver"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    read -p "👉 Selecciona: " APK_OPT
    
    case $APK_OPT in
        1)
            echo ""
            echo -e "${YELLOW}📂 Ingresa la ruta del archivo APK a subir:${NC}"
            echo -e "   (ej: /root/miapp.apk o /home/user/app.apk)"
            read -p "Ruta: " SOURCE_APK
            
            if [[ -f "$SOURCE_APK" ]]; then
                if [[ "$SOURCE_APK" == *.apk ]] || [[ "$SOURCE_APK" == *.APK ]]; then
                    echo -e "\n${YELLOW}🔄 Copiando archivo...${NC}"
                    cp "$SOURCE_APK" "$APK_PATH"
                    if [[ $? -eq 0 ]]; then
                        chmod 644 "$APK_PATH"
                        echo -e "${GREEN}✅ APK subido exitosamente!${NC}"
                        echo -e "📁 Ubicación: ${APK_PATH}"
                        echo -e "📦 Tamaño: $(du -h "$APK_PATH" | cut -f1)"
                        echo -e "\n${YELLOW}ℹ️ El bot ahora enviará este archivo cuando los usuarios soliciten la app${NC}"
                    else
                        echo -e "${RED}❌ Error al copiar el archivo${NC}"
                    fi
                else
                    echo -e "${RED}❌ El archivo no tiene extensión .apk${NC}"
                fi
            else
                echo -e "${RED}❌ Archivo no encontrado: ${SOURCE_APK}${NC}"
            fi
            ;;
        2)
            echo ""
            if [[ -f "$APK_PATH" ]]; then
                echo -e "${GREEN}✅ APK INSTALADO${NC}"
                echo -e "  📁 Ruta: $APK_PATH"
                echo -e "  📦 Tamaño: $(du -h "$APK_PATH" | cut -f1)"
                echo -e "  🔐 Permisos: $(ls -l "$APK_PATH" | awk '{print $1}')"
                echo -e "  📅 Fecha: $(stat -c %y "$APK_PATH" 2>/dev/null | cut -d. -f1)"
                
                # Verificar si es un APK válido
                if file "$APK_PATH" | grep -q "Zip archive"; then
                    echo -e "  ✅ Formato APK válido"
                else
                    echo -e "  ⚠️ El archivo puede estar corrupto"
                fi
            else
                echo -e "${RED}❌ No hay APK instalado${NC}"
                echo -e "${YELLOW}💡 Sube uno con la opción 1${NC}"
            fi
            ;;
        3)
            if [[ -f "$APK_PATH" ]]; then
                echo ""
                read -p "¿Eliminar APK actual? (s/N): " CONFIRM
                if [[ "$CONFIRM" == "s" ]]; then
                    rm -f "$APK_PATH"
                    echo -e "${GREEN}✅ APK eliminado${NC}"
                    echo -e "${YELLOW}⚠️ Los usuarios ahora verán el enlace de descarga alternativo${NC}"
                fi
            else
                echo -e "${RED}❌ No hay APK para eliminar${NC}"
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}❌ Opción inválida${NC}"
            ;;
    esac
    
    echo ""
    read -p "Presiona Enter para continuar..."
}

edit_prices() {
    clear
    echo -e "${CYAN}💰 EDITAR PRECIOS${NC}\n"
    
    CURRENT_7D=$(get_val '.prices.price_7d')
    CURRENT_15D=$(get_val '.prices.price_15d')
    CURRENT_30D=$(get_val '.prices.price_30d')
    CURRENT_50D=$(get_val '.prices.price_50d')
    
    echo -e "${YELLOW}Precios actuales (ARS):${NC}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${GREEN}PLANES DIARIOS:${NC}"
    echo -e "    1️⃣  7 días:  ${GREEN}$${CURRENT_7D}${NC}"
    echo -e "    2️⃣  15 días: ${GREEN}$${CURRENT_15D}${NC}"
    echo -e "  ${GREEN}PLANES MENSUALES:${NC}"
    echo -e "    3️⃣  30 días: ${GREEN}$${CURRENT_30D}${NC}"
    echo -e "    4️⃣  50 días: ${GREEN}$${CURRENT_50D}${NC}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    echo -e "${YELLOW}📝 Ingresa nuevos precios (dejar vacío para mantener):${NC}"
    echo ""
    
    read -p "Precio 7 días [${CURRENT_7D}]: " NEW_7D
    read -p "Precio 15 días [${CURRENT_15D}]: " NEW_15D
    read -p "Precio 30 días [${CURRENT_30D}]: " NEW_30D
    read -p "Precio 50 días [${CURRENT_50D}]: " NEW_50D
    
    if [[ -n "$NEW_7D" && "$NEW_7D" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        set_val '.prices.price_7d' "$NEW_7D"
        echo -e "${GREEN}✅ Precio 7 días actualizado a $${NEW_7D}${NC}"
    fi
    
    if [[ -n "$NEW_15D" && "$NEW_15D" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        set_val '.prices.price_15d' "$NEW_15D"
        echo -e "${GREEN}✅ Precio 15 días actualizado a $${NEW_15D}${NC}"
    fi
    
    if [[ -n "$NEW_30D" && "$NEW_30D" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        set_val '.prices.price_30d' "$NEW_30D"
        echo -e "${GREEN}✅ Precio 30 días actualizado a $${NEW_30D}${NC}"
    fi
    
    if [[ -n "$NEW_50D" && "$NEW_50D" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        set_val '.prices.price_50d' "$NEW_50D"
        echo -e "${GREEN}✅ Precio 50 días actualizado a $${NEW_50D}${NC}"
    fi
    
    echo -e "\n${YELLOW}🔄 Reinicia el bot para que los cambios surtan efecto:${NC}"
    echo -e "   ${GREEN}pm2 restart sshbot-pro${NC}"
    echo ""
    read -p "Presiona Enter para continuar..."
}

while true; do
    show_header
    
    TOTAL_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1" 2>/dev/null || echo "0")
    PENDING_PAYMENTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='pending'" 2>/dev/null || echo "0")
    APPROVED_PAYMENTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='approved'" 2>/dev/null || echo "0")
    EXPIRING_TODAY=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1 AND date(expires_at) = date('now')" 2>/dev/null || echo "0")
    EXPIRING_TOMORROW=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1 AND date(expires_at) = date('now', '+1 day')" 2>/dev/null || echo "0")
    
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
    
    REMINDERS=$(get_val '.reminders.enabled')
    if [[ "$REMINDERS" == "true" ]]; then
        REMINDER_STATUS="${GREEN}✅ ACTIVOS${NC}"
    else
        REMINDER_STATUS="${RED}❌ DESACTIVADOS${NC}"
    fi
    
    TEST_HOURS=$(get_val '.prices.test_hours')
    
    # Verificar APK
    if [[ -f "$APK_PATH" ]]; then
        APK_STATUS="${GREEN}✅ INSTALADA${NC}"
        APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    else
        APK_STATUS="${RED}❌ NO INSTALADA${NC}"
        APK_SIZE=""
    fi
    
    echo -e "${YELLOW}📊 ESTADO DEL SISTEMA${NC}"
    echo -e "  Bot: $BOT_STATUS"
    echo -e "  Usuarios: ${CYAN}$ACTIVE_USERS/$TOTAL_USERS${NC} activos/total"
    echo -e "  Pagos: ${CYAN}$PENDING_PAYMENTS${NC} pendientes | ${GREEN}$APPROVED_PAYMENTS${NC} aprobados"
    echo -e "  Vencen hoy/mañana: ${YELLOW}$EXPIRING_TODAY / $EXPIRING_TOMORROW${NC}"
    echo -e "  MercadoPago: $MP_STATUS"
    echo -e "  Recordatorios: $REMINDER_STATUS"
    echo -e "  App WhatsApp: $APK_STATUS $APK_SIZE"
    echo -e "  IP: $(get_val '.bot.server_ip')"
    echo -e "  Prueba gratis: ${GREEN}$TEST_HOURS horas${NC}"
    echo -e "  Contraseña: ${GREEN}mgvpn247${NC} (FIJA)"
    echo -e ""
    
    echo -e "${YELLOW}💰 PRECIOS ACTUALES:${NC}"
    echo -e "  ${CYAN}DIARIOS:${NC}"
    echo -e "    7 días: $ $(get_val '.prices.price_7d') ARS"
    echo -e "    15 días: $ $(get_val '.prices.price_15d') ARS"
    echo -e "  ${CYAN}MENSUALES:${NC}"
    echo -e "    30 días: $ $(get_val '.prices.price_30d') ARS"
    echo -e "    50 días: $ $(get_val '.prices.price_50d') ARS"
    echo -e ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC} 🚀  Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC} 🛑  Detener bot"
    echo -e "${CYAN}[3]${NC} 📱  Ver logs y QR"
    echo -e "${CYAN}[4]${NC} 👤  Crear usuario manual"
    echo -e "${CYAN}[5]${NC} 👥  Listar usuarios"
    echo -e "${CYAN}[6]${NC} 💰  Editar precios"
    echo -e "${CYAN}[7]${NC} 🔑  Configurar MercadoPago"
    echo -e "${CYAN}[8]${NC} 🧪  Test MercadoPago"
    echo -e "${CYAN}[9]${NC} 🔔  Configurar recordatorios"
    echo -e "${CYAN}[10]${NC} 📊 Ver estadísticas"
    echo -e "${CYAN}[11]${NC} 🔄 Limpiar sesión"
    echo -e "${CYAN}[12]${NC} 💳 Ver pagos"
    echo -e "${CYAN}[13]${NC} ⚙️  Ver configuración"
    echo -e "${CYAN}[14]${NC} ⏰ Cambiar horas de prueba"
    echo -e "${CYAN}[15]${NC} 📲 SUBIR APLICACIÓN (APK)"
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
            echo -e "${CYAN}👤 CREAR USUARIO${NC}\n"
            
            read -p "Teléfono (ej: 5491122334455@c.us): " PHONE
            read -p "Usuario (minúsculas, auto=generar): " USERNAME
            read -p "Tipo (test/premium): " TIPO
            read -p "Días (0=test 2h, 7,15,30,50=premium): " DAYS
            
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
                EXPIRE_DATE=$(date -d "+2 hours" +"%Y-%m-%d %H:%M:%S")
                useradd -M -s /bin/false "$USERNAME" && echo "$USERNAME:$PASSWORD" | chpasswd
            else
                EXPIRE_DATE=$(date -d "+$DAYS days" +"%Y-%m-%d 23:59:59")
                useradd -M -s /bin/false -e "$(date -d "+$DAYS days" +%Y-%m-%d)" "$USERNAME" && echo "$USERNAME:$PASSWORD" | chpasswd
            fi
            
            if [[ $? -eq 0 ]]; then
                sqlite3 "$DB" "INSERT INTO users (phone, username, password, tipo, expires_at, status) VALUES ('$PHONE', '$USERNAME', '$PASSWORD', '$TIPO', '$EXPIRE_DATE', 1)"
                echo -e "\n${GREEN}✅ USUARIO CREADO${NC}"
                echo -e "📱 Teléfono: ${PHONE}"
                echo -e "👤 Usuario: ${USERNAME}"
                echo -e "🔑 Contraseña: ${PASSWORD}"
                echo -e "⏰ Expira: ${EXPIRE_DATE}"
                echo -e "🔌 Días: ${DAYS}"
            else
                echo -e "\n${RED}❌ Error${NC}"
            fi
            read -p "Presiona Enter..."
            ;;
        5)
            clear
            echo -e "${CYAN}👥 USUARIOS ACTIVOS${NC}\n"
            
            sqlite3 -column -header "$DB" "SELECT username, phone, tipo, expires_at FROM users WHERE status = 1 ORDER BY expires_at ASC LIMIT 20"
            echo -e "\n${YELLOW}Total: ${ACTIVE_USERS} activos${NC}"
            read -p "Presiona Enter..."
            ;;
        6)
            edit_prices
            ;;
        7)
            clear
            echo -e "${CYAN}🔑 CONFIGURAR MERCADOPAGO${NC}\n"
            
            CURRENT_TOKEN=$(get_val '.mercadopago.access_token')
            
            if [[ -n "$CURRENT_TOKEN" && "$CURRENT_TOKEN" != "null" && "$CURRENT_TOKEN" != "" ]]; then
                echo -e "${GREEN}✅ Token configurado${NC}"
                echo -e "${YELLOW}Preview: ${CURRENT_TOKEN:0:30}...${NC}\n"
            else
                echo -e "${YELLOW}⚠️  Sin token configurado${NC}\n"
            fi
            
            echo -e "${CYAN}📋 Obtener token:${NC}"
            echo -e "  1. https://www.mercadopago.com.ar/developers"
            echo -e "  2. Inicia sesión"
            echo -e "  3. 'Tus credenciales' → Access Token PRODUCCIÓN"
            echo -e "  4. Formato: APP_USR-xxxxxxxxxx\n"
            
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
                    echo -e "${GREEN}✅ MercadoPago activado${NC}"
                else
                    echo -e "${RED}❌ Token inválido${NC}"
                    echo -e "${YELLOW}Debe empezar con APP_USR- o TEST-${NC}"
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
            
            echo -e "${YELLOW}🔑 Token: ${TOKEN:0:30}...${NC}\n"
            test_mercadopago "$TOKEN"
            
            echo ""
            read -p "Presiona Enter..."
            ;;
        9)
            clear
            echo -e "${CYAN}🔔 CONFIGURAR RECORDATORIOS${NC}\n"
            
            CURRENT_STATUS=$(get_val '.reminders.enabled')
            echo -e "Estado actual: ${GREEN}$CURRENT_STATUS${NC}\n"
            
            echo -e "${YELLOW}Opciones:${NC}"
            echo -e "  1. Activar recordatorios"
            echo -e "  2. Desactivar recordatorios"
            echo -e "  3. Ver/editar horarios"
            echo -e "  0. Volver"
            
            read -p "Selecciona: " REM_OPT
            
            case $REM_OPT in
                1)
                    set_val '.reminders.enabled' "true"
                    echo -e "${GREEN}✅ Recordatorios activados${NC}"
                    ;;
                2)
                    set_val '.reminders.enabled' "false"
                    echo -e "${YELLOW}⚠️ Recordatorios desactivados${NC}"
                    ;;
                3)
                    CURRENT_TIMES=$(get_val '.reminders.times')
                    echo -e "Horarios actuales: ${CYAN}$CURRENT_TIMES${NC}"
                    echo -e "\nIngresa nuevos horarios (ej: [24,12,6,1]):"
                    read -p "> " NEW_TIMES
                    if [[ -n "$NEW_TIMES" ]]; then
                        set_val '.reminders.times' "$NEW_TIMES"
                        echo -e "${GREEN}✅ Horarios actualizados${NC}"
                    fi
                    ;;
                0)
                    continue
                    ;;
            esac
            read -p "Presiona Enter..."
            ;;
        10)
            clear
            echo -e "${CYAN}📊 ESTADÍSTICAS COMPLETAS${NC}\n"
            
            echo -e "${YELLOW}👥 USUARIOS:${NC}"
            sqlite3 "$DB" "SELECT 'Total: ' || COUNT(*) || ' | Activos: ' || SUM(CASE WHEN status=1 THEN 1 ELSE 0 END) || ' | Tests hoy: ' || (SELECT COUNT(*) FROM daily_tests WHERE date = date('now')) FROM users"
            
            echo -e "\n${YELLOW}💰 PAGOS:${NC}"
            sqlite3 "$DB" "SELECT 'Pendientes: ' || SUM(CASE WHEN status='pending' THEN 1 ELSE 0 END) || ' | Aprobados: ' || SUM(CASE WHEN status='approved' THEN 1 ELSE 0 END) || ' | Total: $' || printf('%.2f', SUM(CASE WHEN status='approved' THEN amount ELSE 0 END)) FROM payments"
            
            echo -e "\n${YELLOW}📅 PRÓXIMOS VENCIMIENTOS:${NC}"
            sqlite3 "$DB" "SELECT date(expires_at) as fecha, COUNT(*) as cantidad FROM users WHERE status=1 AND expires_at > datetime('now') GROUP BY date(expires_at) ORDER BY fecha ASC LIMIT 5"
            
            echo -e "\n${YELLOW}📅 DISTRIBUCIÓN PLANES:${NC}"
            sqlite3 "$DB" "SELECT '7 días: ' || SUM(CASE WHEN plan='7d' THEN 1 ELSE 0 END) || ' | 15 días: ' || SUM(CASE WHEN plan='15d' THEN 1 ELSE 0 END) || ' | 30 días: ' || SUM(CASE WHEN plan='30d' THEN 1 ELSE 0 END) || ' | 50 días: ' || SUM(CASE WHEN plan='50d' THEN 1 ELSE 0 END) FROM payments WHERE status='approved'"
            
            echo -e "\n${YELLOW}💸 INGRESOS HOY:${NC}"
            sqlite3 "$DB" "SELECT 'Hoy: $' || printf('%.2f', SUM(CASE WHEN date(created_at) = date('now') THEN amount ELSE 0 END)) FROM payments WHERE status='approved'"
            
            echo -e "\n${YELLOW}🔔 RECORDATORIOS ENVIADOS HOY:${NC}"
            sqlite3 "$DB" "SELECT COUNT(*) FROM logs WHERE type='reminder' AND date(created_at) = date('now')"
            
            echo -e "\n${YELLOW}📲 APP EN WHATSAPP:${NC}"
            if [[ -f "$APK_PATH" ]]; then
                echo -e "  ${GREEN}✅ APK instalado - Se envía automáticamente${NC}"
            else
                echo -e "  ${RED}❌ No hay APK - Se usa enlace alternativo${NC}"
            fi
            
            echo ""
            read -p "Presiona Enter..."
            ;;
        11)
            echo -e "\n${YELLOW}🧹 Limpiando sesión...${NC}"
            pm2 stop sshbot-pro
            rm -rf /root/.wppconnect/*
            echo -e "${GREEN}✅ Sesión limpiada${NC}"
            echo -e "${YELLOW}📱 Escanea nuevo QR al iniciar${NC}"
            sleep 2
            ;;
        12)
            clear
            echo -e "${CYAN}💳 PAGOS${NC}\n"
            
            echo -e "${YELLOW}Pagos pendientes:${NC}"
            sqlite3 -column -header "$DB" "SELECT payment_id, phone, plan, amount, created_at FROM payments WHERE status='pending' ORDER BY created_at DESC LIMIT 10"
            
            echo -e "\n${YELLOW}Pagos aprobados:${NC}"
            sqlite3 -column -header "$DB" "SELECT payment_id, phone, plan, amount, approved_at FROM payments WHERE status='approved' ORDER BY approved_at DESC LIMIT 10"
            
            echo ""
            read -p "Presiona Enter..."
            ;;
        13)
            clear
            echo -e "${CYAN}⚙️  CONFIGURACIÓN${NC}\n"
            
            echo -e "${YELLOW}🤖 BOT:${NC}"
            echo -e "  IP: $(get_val '.bot.server_ip')"
            echo -e "  Versión: $(get_val '.bot.version')"
            echo -e "  Contraseña fija: mgvpn247"
            
            echo -e "\n${YELLOW}💰 PRECIOS:${NC}"
            echo -e "  ${CYAN}DIARIOS:${NC}"
            echo -e "  7d: $(get_val '.prices.price_7d') ARS"
            echo -e "  15d: $(get_val '.prices.price_15d') ARS"
            echo -e "  ${CYAN}MENSUALES:${NC}"
            echo -e "  30d: $(get_val '.prices.price_30d') ARS"
            echo -e "  50d: $(get_val '.prices.price_50d') ARS"
            echo -e "  Test: $(get_val '.prices.test_hours') horas"
            
            echo -e "\n${YELLOW}💳 MERCADOPAGO:${NC}"
            MP_TOKEN=$(get_val '.mercadopago.access_token')
            if [[ -n "$MP_TOKEN" && "$MP_TOKEN" != "null" ]]; then
                echo -e "  Estado: ${GREEN}CONFIGURADO${NC}"
            else
                echo -e "  Estado: ${RED}NO CONFIGURADO${NC}"
            fi
            
            echo -e "\n${YELLOW}🔔 RECORDATORIOS:${NC}"
            echo -e "  Estado: $(get_val '.reminders.enabled')"
            echo -e "  Horarios: $(get_val '.reminders.times') horas"
            
            echo -e "\n${YELLOW}📲 APP WHATSAPP:${NC}"
            if [[ -f "$APK_PATH" ]]; then
                echo -e "  Estado: ${GREEN}INSTALADA${NC}"
                echo -e "  Ruta: $APK_PATH"
                echo -e "  Tamaño: $(du -h "$APK_PATH" | cut -f1)"
            else
                echo -e "  Estado: ${RED}NO INSTALADA${NC}"
                echo -e "  Alternativa: Enlace web configurado"
            fi
            
            echo -e "\n${YELLOW}⚡ AJUSTES:${NC}"
            echo -e "  Limpieza: cada 15 minutos"
            echo -e "  Verificación pagos: cada 2 minutos"
            echo -e "  Test: 2 horas exactas"
            echo -e "  Contraseña: mgvpn247 (fija)"
            
            echo ""
            read -p "Presiona Enter..."
            ;;
        14)
            clear
            echo -e "${CYAN}⏰ CAMBIAR HORAS DE PRUEBA${NC}\n"
            
            CURRENT_HOURS=$(get_val '.prices.test_hours')
            echo -e "Horas actuales de prueba: ${GREEN}$CURRENT_HOURS horas${NC}\n"
            
            read -p "Ingresa nuevas horas de prueba (ej: 2, 3, 4): " NEW_HOURS
            
            if [[ -n "$NEW_HOURS" && "$NEW_HOURS" =~ ^[0-9]+$ ]]; then
                set_val '.prices.test_hours' "$NEW_HOURS"
                echo -e "\n${GREEN}✅ Horas de prueba actualizadas a $NEW_HOURS horas${NC}"
                echo -e "${YELLOW}🔄 Reinicia el bot para aplicar cambios${NC}"
            else
                echo -e "\n${RED}❌ Valor inválido${NC}"
            fi
            read -p "Presiona Enter..."
            ;;
        15)
            upload_apk
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
echo -e "${GREEN}✅ Panel creado completo con subida de APK${NC}"

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
║          🎉 INSTALACIÓN COMPLETADA - TODO INTEGRADO 🎉      ║
║                                                              ║
║       🤖 SSH BOT PRO - WPPCONNECT + MERCADOPAGO            ║
║       📱 WhatsApp API FUNCIONANDO                         ║
║       💰 MercadoPago SDK v2.x COMPLETO                    ║
║       💳 Pago automático con QR                           ║
║       🔔 RECORDATORIOS AUTOMÁTICOS                         ║
║          • 24 horas antes                                  ║
║          • 12 horas antes                                  ║
║          • 6 horas antes                                   ║
║          • 1 hora antes (ÚLTIMO AVISO)                     ║
║       📲 ENVÍO DE APP POR WHATSAPP                         ║
║       💰 EDICIÓN DE PRECIOS DESDE PANEL                    ║
║       ⏰ PRUEBA GRATIS DE 2 HORAS                          ║
║       🎛️  Panel completo con control                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Sistema completo instalado${NC}"
echo -e "${GREEN}✅ WhatsApp API funcionando${NC}"
echo -e "${GREEN}✅ MercadoPago SDK v2.x integrado${NC}"
echo -e "${GREEN}✅ Panel de control completo${NC}"
echo -e "${GREEN}✅ Pago automático con QR${NC}"
echo -e "${GREEN}✅ Verificación automática de pagos${NC}"
echo -e "${GREEN}✅ RECORDATORIOS AUTOMÁTICOS (24h, 12h, 6h, 1h)${NC}"
echo -e "${GREEN}✅ ENVÍO DE APP POR WHATSAPP (Archivo APK)${NC}"
echo -e "${GREEN}✅ EDICIÓN DE PRECIOS DESDE PANEL${NC}"
echo -e "${GREEN}✅ PRUEBA GRATIS DE 2 HORAS${NC}"
echo -e "${GREEN}✅ Estadísticas completas${NC}"
echo -e "${GREEN}✅ Planes: 7 días, 15 días, 30 días, 50 días${NC}"
echo -e "${GREEN}✅ Contraseña fija: mgvpn247${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 COMANDOS PRINCIPALES:${NC}\n"
echo -e "  ${GREEN}sshbot${NC}         - Panel de control completo"
echo -e "  ${GREEN}pm2 logs sshbot-pro${NC} - Ver logs y QR"
echo -e "  ${GREEN}pm2 restart sshbot-pro${NC} - Reiniciar bot"
echo -e "\n"

echo -e "${YELLOW}🚀 PRIMEROS PASOS:${NC}\n"
echo -e "  1. Ver logs: ${GREEN}pm2 logs sshbot-pro${NC}"
echo -e "  2. Escanear QR cuando aparezca"
echo -e "  3. Configurar MercadoPago en el panel: ${GREEN}sshbot${NC}"
echo -e "  4. Opción [7] - Configurar token de MercadoPago"
echo -e "  5. Opción [8] - Testear conexión"
echo -e "  6. Opción [15] - SUBIR APLICACIÓN (archivo APK)"
echo -e "  7. Opción [6] - Editar precios"
echo -e "  8. Opción [9] - Configurar recordatorios (opcional)"
echo -e "  9. Enviar 'menu' al bot en WhatsApp"
echo -e "\n"

echo -e "${YELLOW}💰 CONFIGURAR MERCADOPAGO:${NC}\n"
echo -e "  1. Ve a: https://www.mercadopago.com.ar/developers"
echo -e "  2. Inicia sesión"
echo -e "  3. Ve a 'Tus credenciales'"
echo -e "  4. Copia 'Access Token PRODUCCIÓN'"
echo -e "  5. En el panel: Opción 7 → Pegar token"
echo -e "  6. Testear con opción 8"
echo -e "\n"

echo -e "${YELLOW}📲 SUBIR APLICACIÓN:${NC}\n"
echo -e "  1. En el panel: Opción 15"
echo -e "  2. Opción 1 - Subir nuevo APK"
echo -e "  3. Ingresa la ruta del archivo .apk"
echo -e "  4. El bot enviará el archivo automáticamente"
echo -e "\n"

echo -e "${YELLOW}💰 EDITAR PRECIOS:${NC}\n"
echo -e "  1. En el panel: Opción 6"
echo -e "  2. Ingresa los nuevos precios"
echo -e "  3. Reinicia el bot con 'pm2 restart sshbot-pro'"
echo -e "\n"

echo -e "${YELLOW}🔔 CONFIGURAR RECORDATORIOS:${NC}\n"
echo -e "  1. En el panel: Opción 9"
echo -e "  2. Activar recordatorios"
echo -e "  3. Ajustar horarios si lo deseas"
echo -e "  4. Los avisos se enviarán automáticamente"
echo -e "\n"

echo -e "${GREEN}${BOLD}¡Sistema listo! Escanea el QR, sube tu app, configura MercadoPago y empieza a vender 🚀${NC}\n"

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