#!/bin/bash
# ================================================
# SSH BOT PRO - WPPCONNECT + MERCADOPAGO COMPLETO
# VERSIÓN SIMPLIFICADA: Sin cupones, sin números azules
# CON RECORDATORIOS DE VENCIMIENTO AUTOMÁTICOS
# CON ENVÍO DE APK POR WHATSAPP (OPCIÓN 4)
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
║               📱 ENVÍO DE APK POR WHATSAPP (OPCIÓN 4)      ║
║               ⏰ PRUEBA DE 2 HORAS                          ║
║               🎛️  Panel completo con control MP           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CARACTERÍSTICAS PRINCIPALES:${NC}"
echo -e "  📱 ${CYAN}WPPConnect${NC} - API WhatsApp que funciona"
echo -e "  💰 ${GREEN}MercadoPago SDK v2.x${NC} - Integrado completo"
echo -e "  💳 ${YELLOW}Pago automático${NC} - QR + Enlace de pago"
echo -e "  🔔 ${PURPLE}Recordatorios${NC} - 24h, 12h, 6h y 1h antes"
echo -e "  📱 ${BLUE}Envío APK${NC} - Descarga directa por WhatsApp (Opción 4)"
echo -e "  ⏰ ${BLUE}PRUEBA GRATIS${NC} - 2 HORAS de duración"
echo -e "  🎛️  ${CYAN}Panel completo${NC} - Control total del sistema"
echo -e "  📊 ${GREEN}Estadísticas${NC} - Ventas, usuarios, ingresos"
echo -e "  ⚡ ${YELLOW}Auto-verificación${NC} - Pagos verificados cada 2 min"
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
APK_DIR="$INSTALL_DIR/apk"

# Limpiar anterior
pm2 delete sshbot-pro 2>/dev/null || true
rm -rf "$INSTALL_DIR" "$USER_HOME" 2>/dev/null || true
rm -rf /root/.wppconnect 2>/dev/null || true

# Crear directorios
mkdir -p "$INSTALL_DIR"/{data,config,sessions,logs,qr_codes,apk}
mkdir -p "$USER_HOME"
mkdir -p /root/.wppconnect
chmod -R 755 "$INSTALL_DIR"
chmod -R 700 /root/.wppconnect

cat > "$CONFIG_FILE" << EOF
{
    "bot": {
        "name": "SSH Bot Pro",
        "version": "2.0-MP-RECORDATORIOS-APK",
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
    "apk": {
        "enabled": false,
        "filename": "",
        "size_mb": 0,
        "uploaded_at": ""
    },
    "links": {
        "app_download": "",
        "support": "https://wa.me/543435071016"
    },
    "paths": {
        "database": "$DB_FILE",
        "qr_codes": "$INSTALL_DIR/qr_codes",
        "sessions": "/root/.wppconnect",
        "apk_dir": "$APK_DIR"
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

echo -e "${GREEN}✅ Estructura creada${NC}"

# ================================================
# CREAR BOT COMPLETO CON ENVÍO APK EN OPCIÓN 4
# ================================================
echo -e "\n${CYAN}🤖 Creando bot con WPPConnect + MercadoPago + Recordatorios + Envío APK (Opción 4)...${NC}"

cd "$USER_HOME"

# package.json
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

# Crear bot.js
echo -e "${YELLOW}📝 Creando bot.js...${NC}"

cat > "bot.js" << 'BOTEOF'
const wppconnect = require('@wppconnect-team/wppconnect');
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
console.log(chalk.cyan.bold('║              📱 ENVÍO DE APK POR WHATSAPP (OPCIÓN 4)          ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

// Cargar configuración
function loadConfig() {
    delete require.cache[require.resolve('/opt/sshbot-pro/config/config.json')];
    return require('/opt/sshbot-pro/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/sshbot-pro/data/users.db');

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
            console.log(chalk.green('✅ MercadoPago SDK v2.x ACTIVO'));
        } catch (error) {
            console.log(chalk.red('❌ Error MP:'), error.message);
            mpEnabled = false;
        }
    } else {
        console.log(chalk.yellow('⚠️ MercadoPago NO configurado'));
    }
}

initMercadoPago();

let client = null;

// Estado de usuario
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
        db.run(`INSERT OR REPLACE INTO user_state (phone, state, data, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)`,
            [phone, state, dataStr], () => resolve());
    });
}

// Generar usuario
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
        const expireFull = moment().add(config.prices.test_hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
        try {
            await execPromise(`useradd -m -s /bin/bash ${username} && echo "${username}:${password}" | chpasswd`);
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at) VALUES (?, ?, ?, 'test', ?)`,
                [phone, username, password, expireFull]);
            return { success: true, username, password, expires: expireFull };
        } catch (error) {
            return { success: false, error: error.message };
        }
    } else {
        const expireFull = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
        try {
            await execPromise(`useradd -M -s /bin/false -e ${moment().add(days, 'days').format('YYYY-MM-DD')} ${username} && echo "${username}:${password}" | chpasswd`);
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at) VALUES (?, ?, ?, 'premium', ?)`,
                [phone, username, password, expireFull]);
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

// ✅ ENVIAR APK POR WHATSAPP (OPCIÓN 4)
async function sendApkFile(phone) {
    try {
        config = loadConfig();
        const apkDir = config.paths.apk_dir || '/opt/sshbot-pro/apk';
        const apkEnabled = config.apk.enabled || false;
        const apkFilename = config.apk.filename || '';
        
        if (!apkEnabled || !apkFilename) {
            await client.sendText(phone, `📱 *APLICACIÓN NO DISPONIBLE*

⚠️ La aplicación aún no ha sido subida al sistema.

📋 *Instrucciones para el administrador:*
1. Ejecuta el comando: ${chalk.green('sshbot')}
2. Ve a la opción: ${chalk.green('[15] SUBIR APK')}
3. Sube el archivo APK

🔄 Una vez subido, estará disponible para descargar.`);
            return false;
        }
        
        const apkPath = path.join(apkDir, apkFilename);
        
        if (!fs.existsSync(apkPath)) {
            await client.sendText(phone, `❌ Error: El archivo APK no se encuentra en el sistema.\n\nContacta al administrador.`);
            return false;
        }
        
        const stats = fs.statSync(apkPath);
        const fileSizeMB = (stats.size / (1024 * 1024)).toFixed(2);
        
        await client.sendFileFromPath(
            phone,
            apkPath,
            apkFilename,
            `📱 *APLICACIÓN SSH BOT PRO*

📦 *Archivo:* ${apkFilename}
📊 *Tamaño:* ${fileSizeMB} MB

💡 *Instrucciones de instalación:*
1. Descarga el archivo APK
2. Abre el archivo descargado
3. Click en "Más detalles"
4. Click en "Instalar de todas formas"
5. Espera a que se complete la instalación

🔐 *Configuración:*
Usuario: (el que te proporcionamos)
Contraseña: ${DEFAULT_PASSWORD}

⚠️ *Importante:* Solo descarga desde este chat oficial`
        );
        
        console.log(chalk.green(`✅ APK enviado a ${phone}`));
        return true;
        
    } catch (error) {
        console.error(chalk.red(`❌ Error enviando APK: ${error.message}`));
        await client.sendText(phone, `❌ Error al enviar la aplicación.\n\nContacta al administrador.`);
        return false;
    }
}

// MercadoPago - Crear pago
async function createMercadoPagoPayment(phone, days, amount, planName) {
    try {
        if (!mpEnabled || !mpPreference) {
            return { success: false, error: 'MercadoPago no configurado' };
        }
        
        const phoneClean = phone.replace('@c.us', '');
        const paymentId = `SSH-${phoneClean}-${days}d-${Date.now()}`;
        
        const preferenceData = {
            items: [{
                title: `SSH PREMIUM ${days} DÍAS`,
                description: `Acceso SSH Premium por ${days} días`,
                quantity: 1,
                currency_id: config.prices.currency || 'ARS',
                unit_price: parseFloat(amount)
            }],
            external_reference: paymentId,
            expires: true,
            expiration_date_to: moment().add(24, 'hours').toISOString(),
            back_urls: {
                success: `https://wa.me/${phoneClean}?text=Ya%20pague`,
                failure: `https://wa.me/${phoneClean}?text=Pago%20fallido`
            },
            auto_return: 'approved'
        };
        
        const response = await mpPreference.create({ body: preferenceData });
        
        if (response && response.id) {
            const paymentUrl = response.init_point;
            const qrPath = `${config.paths.qr_codes}/${paymentId}.png`;
            
            await QRCode.toFile(qrPath, paymentUrl, { width: 400 });
            
            db.run(`INSERT INTO payments (payment_id, phone, plan, days, amount, status, payment_url, qr_code, preference_id) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
                [paymentId, phone, `${days}d`, days, amount, paymentUrl, qrPath, response.id]);
            
            return { success: true, paymentUrl, qrPath, amount: parseFloat(amount) };
        }
        
        throw new Error('Respuesta inválida');
        
    } catch (error) {
        return { success: false, error: error.message };
    }
}

// Verificar pagos
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
                        const username = generatePremiumUsername();
                        const result = await createSSHUser(payment.phone, username, payment.days);
                        
                        if (result.success) {
                            db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`, [payment.payment_id]);
                            
                            await client.sendText(payment.phone, `✅ PAGO CONFIRMADO\n\n👤 Usuario: ${username}\n🔑 Contraseña: ${DEFAULT_PASSWORD}\n⏰ Válido hasta: ${moment().add(payment.days, 'days').format('DD/MM/YYYY')}`);
                        }
                    }
                }
            } catch (error) {
                console.error(chalk.red(`Error: ${error.message}`));
            }
        }
    });
}

// Inicializar bot
async function initializeBot() {
    try {
        client = await wppconnect.create({
            session: 'sshbot-pro-session',
            headless: true,
            devtools: false,
            useChrome: true,
            debug: false,
            logQR: true,
            puppeteerOptions: {
                executablePath: '/usr/bin/google-chrome',
                headless: 'new',
                args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
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
                    
                    const apkStatus = config.apk.enabled ? '✅' : '⏳';
                    
                    await client.sendText(from, `HOLA BIENVENIDO BOT MGVPN IP🇦🇷

Elija una opción:

 1️⃣ - CREAR PRUEBA (${config.prices.test_hours} HORAS)
 2️⃣ - COMPRAR USUARIO SSH
 3️⃣ - RENOVAR USUARIO SSH
 4️⃣ - DESCARGAR APK 📱
 
💡 *Opción 4:* Descarga la aplicación directamente por WhatsApp`);
                }
                
                // OPCIÓN 1: CREAR PRUEBA
                else if (text === '1' && userState.state === 'main_menu') {
                    if (!(await canCreateTest(from))) {
                        await client.sendText(from, `YA USASTE TU PRUEBA HOY\n\n⏳ Vuelve mañana para otra prueba gratuita de ${config.prices.test_hours} horas`);
                        return;
                    }
                    
                    await client.sendText(from, '⏳ Creando cuenta de prueba...');
                    
                    const username = generateUsername();
                    const result = await createSSHUser(from, username, 0);
                    
                    if (result.success) {
                        registerTest(from);
                        
                        await client.sendText(from, `✅ PRUEBA DE ${config.prices.test_hours} HORAS CREADA!

👤 Usuario: ${username}
🔐 Contraseña: ${DEFAULT_PASSWORD}
🔌 Limite: 1 dispositivo(s)
⌛️ Expira en: ${config.prices.test_hours} horas

📱 *DESCARGAR APP:* Envía *4* para recibir el APK

💡 *Instrucciones:*
1. Descarga el APK (Opción 4)
2. Instala la aplicación
3. Configura con tus credenciales

⏰ *TIENES ${config.prices.test_hours} HORAS DE PRUEBA*`);
                        
                        console.log(chalk.green(`✅ Test creado: ${username}`));
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                }
                
                // OPCIÓN 2: COMPRAR
                else if (text === '2' && userState.state === 'main_menu') {
                    await setUserState(from, 'buying_ssh');
                    await client.sendText(from, `🌐 PLANES SSH PREMIUM\n\nElija una opción:\n 1️⃣ - PLANES DIARIOS\n 2️⃣ - PLANES MENSUALES\n 0️⃣ - VOLVER`);
                }
                
                // OPCIÓN 3: RENOVAR
                else if (text === '3' && userState.state === 'main_menu') {
                    await client.sendText(from, `RENOVAR USUARIO SSH\n\nPara renovar tu cuenta SSH existente, contacta al administrador:\n${config.links.support}`);
                }
                
                // ✅ OPCIÓN 4: DESCARGAR APK (ENVÍO DIRECTO)
                else if (text === '4' && userState.state === 'main_menu') {
                    await client.sendText(from, '📱 *Preparando descarga...*\n\nEnviando aplicación...');
                    await sendApkFile(from);
                }
                
                // SUBMENÚ COMPRAS
                else if (userState.state === 'buying_ssh') {
                    if (text === '1') {
                        await setUserState(from, 'selecting_daily_plan');
                        await client.sendText(from, `🌐 PLANES DIARIOS SSH\n\n 1️⃣ - 7 DIAS - $${config.prices.price_7d}\n 2️⃣ - 15 DIAS - $${config.prices.price_15d}\n 0️⃣ - VOLVER`);
                    }
                    else if (text === '2') {
                        await setUserState(from, 'selecting_monthly_plan');
                        await client.sendText(from, `🌐 PLANES MENSUALES SSH\n\n 1️⃣ - 30 DIAS - $${config.prices.price_30d}\n 2️⃣ - 50 DIAS - $${config.prices.price_50d}\n 0️⃣ - VOLVER`);
                    }
                    else if (text === '0') {
                        await setUserState(from, 'main_menu');
                        await client.sendText(from, `HOLA BIENVENIDO BOT MGVPN IP🇦🇷\n\n 1️⃣ - CREAR PRUEBA (${config.prices.test_hours} HORAS)\n 2️⃣ - COMPRAR USUARIO SSH\n 3️⃣ - RENOVAR USUARIO SSH\n 4️⃣ - DESCARGAR APK 📱`);
                    }
                }
                
                // SELECCIÓN PLAN DIARIO
                else if (userState.state === 'selecting_daily_plan') {
                    if (['1', '2'].includes(text)) {
                        const planMap = {
                            '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                            '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' }
                        };
                        const plan = planMap[text];
                        
                        if (mpEnabled) {
                            await client.sendText(from, '⏳ Generando link de pago...');
                            const payment = await createMercadoPagoPayment(from, plan.days, plan.price, plan.name);
                            
                            if (payment.success) {
                                await client.sendText(from, `💳 *PAGO CON MERCADOPAGO*\n\nPlan: ${plan.name}\nMonto: $${payment.amount}\n\n🔗 Link de pago:\n${payment.paymentUrl}\n\n⏰ Válido por 24 horas`);
                                
                                if (fs.existsSync(payment.qrPath)) {
                                    await client.sendImage(from, payment.qrPath, 'qr.png', `QR para pago\n${plan.name} - $${payment.amount}`);
                                }
                            } else {
                                await client.sendText(from, `❌ Error: ${payment.error}\n\nContacta al administrador: ${config.links.support}`);
                            }
                            await setUserState(from, 'main_menu');
                        } else {
                            await client.sendText(from, `PLAN: ${plan.name}\nPrecio: $${plan.price}\n\nContacta al administrador: ${config.links.support}`);
                            await setUserState(from, 'main_menu');
                        }
                    }
                    else if (text === '0') {
                        await setUserState(from, 'buying_ssh');
                        await client.sendText(from, `🌐 PLANES SSH PREMIUM\n\n 1️⃣ - PLANES DIARIOS\n 2️⃣ - PLANES MENSUALES\n 0️⃣ - VOLVER`);
                    }
                }
                
                // SELECCIÓN PLAN MENSUAL
                else if (userState.state === 'selecting_monthly_plan') {
                    if (['1', '2'].includes(text)) {
                        const planMap = {
                            '1': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                            '2': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                        };
                        const plan = planMap[text];
                        
                        if (mpEnabled) {
                            await client.sendText(from, '⏳ Generando link de pago...');
                            const payment = await createMercadoPagoPayment(from, plan.days, plan.price, plan.name);
                            
                            if (payment.success) {
                                await client.sendText(from, `💳 *PAGO CON MERCADOPAGO*\n\nPlan: ${plan.name}\nMonto: $${payment.amount}\n\n🔗 Link de pago:\n${payment.paymentUrl}\n\n⏰ Válido por 24 horas`);
                                
                                if (fs.existsSync(payment.qrPath)) {
                                    await client.sendImage(from, payment.qrPath, 'qr.png', `QR para pago\n${plan.name} - $${payment.amount}`);
                                }
                            } else {
                                await client.sendText(from, `❌ Error: ${payment.error}\n\nContacta al administrador: ${config.links.support}`);
                            }
                            await setUserState(from, 'main_menu');
                        } else {
                            await client.sendText(from, `PLAN: ${plan.name}\nPrecio: $${plan.price}\n\nContacta al administrador: ${config.links.support}`);
                            await setUserState(from, 'main_menu');
                        }
                    }
                    else if (text === '0') {
                        await setUserState(from, 'buying_ssh');
                        await client.sendText(from, `🌐 PLANES SSH PREMIUM\n\n 1️⃣ - PLANES DIARIOS\n 2️⃣ - PLANES MENSUALES\n 0️⃣ - VOLVER`);
                    }
                }
                
            } catch (error) {
                console.error(chalk.red('❌ Error:'), error.message);
            }
        });
        
        // Verificar pagos cada 2 minutos
        cron.schedule('*/2 * * * *', () => checkPendingPayments());
        
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
        });
        
        // Recordatorios cada hora
        cron.schedule('0 * * * *', async () => {
            if (!config.reminders || !config.reminders.enabled) return;
            
            for (const hours of config.reminders.times) {
                const targetTime = moment().add(hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
                
                db.all(`SELECT phone, username, expires_at FROM users WHERE status = 1 AND tipo = 'premium' AND expires_at BETWEEN datetime('now') AND datetime(?)`, [targetTime], async (err, users) => {
                    if (err || !users) return;
                    
                    for (const user of users) {
                        const expireFormatted = moment(user.expires_at).format('DD/MM/YYYY HH:mm');
                        let message = hours === 1 ? 
                            `⚠️ *ÚLTIMA HORA!*\n\nTu cuenta *${user.username}* vencerá en 1 HORA.\n\n📅 ${expireFormatted}\n\nEnvía *MENU* para renovar.` :
                            `🔔 *RECORDATORIO*\n\nTu cuenta *${user.username}* vencerá en ${hours} horas.\n\n📅 ${expireFormatted}\n\nEnvía *MENU* para renovar.`;
                        
                        if (client) await client.sendText(user.phone, message);
                    }
                });
            }
        });
        
    } catch (error) {
        console.error(chalk.red('❌ Error inicializando:'), error.message);
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

echo -e "${GREEN}✅ Bot creado con envío APK en opción 4${NC}"

# ================================================
# CREAR PANEL DE CONTROL COMPLETO
# ================================================
echo -e "\n${CYAN}🎛️  Creando panel de control completo...${NC}"

cat > /usr/local/bin/sshbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; NC='\033[0m'

DB="/opt/sshbot-pro/data/users.db"
CONFIG="/opt/sshbot-pro/config/config.json"
APK_DIR="/opt/sshbot-pro/apk"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }
set_val() { local t=$(mktemp); jq "$1 = $2" "$CONFIG" > "$t" && mv "$t" "$CONFIG"; }

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         🎛️  PANEL SSH BOT PRO - CON RECORDATORIOS          ║${NC}"
    echo -e "${CYAN}║              💰 MERCADOPAGO + 🔔 RECORDATORIOS              ║${NC}"
    echo -e "${CYAN}║              📱 ENVÍO APK POR WHATSAPP (OPCIÓN 4)           ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

test_mercadopago() {
    local TOKEN="$1"
    echo -e "${YELLOW}🔄 Probando conexión...${NC}"
    RESPONSE=$(curl -s -w "\n%{http_code}" -H "Authorization: Bearer $TOKEN" "https://api.mercadopago.com/v1/payment_methods" 2>/dev/null)
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    if [[ "$HTTP_CODE" == "200" ]]; then
        echo -e "${GREEN}✅ CONEXIÓN EXITOSA${NC}"
        return 0
    else
        echo -e "${RED}❌ ERROR - Código: $HTTP_CODE${NC}"
        return 1
    fi
}

while true; do
    show_header
    
    TOTAL_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1" 2>/dev/null || echo "0")
    PENDING_PAYMENTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='pending'" 2>/dev/null || echo "0")
    
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
    
    APK_ENABLED=$(get_val '.apk.enabled')
    APK_FILENAME=$(get_val '.apk.filename')
    if [[ "$APK_ENABLED" == "true" && "$APK_FILENAME" != "null" && "$APK_FILENAME" != "" ]]; then
        APK_STATUS="${GREEN}✅ $APK_FILENAME${NC}"
    else
        APK_STATUS="${RED}❌ NO SUBIDO${NC}"
    fi
    
    echo -e "${YELLOW}📊 ESTADO DEL SISTEMA${NC}"
    echo -e "  Bot: $BOT_STATUS"
    echo -e "  Usuarios: ${CYAN}$ACTIVE_USERS/$TOTAL_USERS${NC} activos/total"
    echo -e "  Pagos pendientes: ${CYAN}$PENDING_PAYMENTS${NC}"
    echo -e "  MercadoPago: $MP_STATUS"
    echo -e "  APK WhatsApp: $APK_STATUS"
    echo -e "  Prueba: ${GREEN}$(get_val '.prices.test_hours') horas${NC}"
    echo -e ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC} 🚀  Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC} 🛑  Detener bot"
    echo -e "${CYAN}[3]${NC} 📱  Ver logs y QR"
    echo -e "${CYAN}[4]${NC} 👤  Crear usuario manual"
    echo -e "${CYAN}[5]${NC} 👥  Listar usuarios"
    echo -e "${CYAN}[6]${NC} 💰  Cambiar precios"
    echo -e "${CYAN}[7]${NC} 🔑  Configurar MercadoPago"
    echo -e "${CYAN}[8]${NC} 🧪  Test MercadoPago"
    echo -e "${CYAN}[9]${NC} 🔔  Configurar recordatorios"
    echo -e "${CYAN}[10]${NC} 📊 Ver estadísticas"
    echo -e "${CYAN}[11]${NC} 🔄 Limpiar sesión"
    echo -e "${CYAN}[12]${NC} 💳 Ver pagos"
    echo -e "${CYAN}[13]${NC} ⚙️  Ver configuración"
    echo -e "${CYAN}[14]${NC} ⏰ Cambiar horas de prueba"
    echo -e "${CYAN}[15]${NC} 📱 SUBIR APK (WhatsApp)"
    echo -e "${CYAN}[16]${NC} 📱 VER INFO APK"
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
            read -p "Usuario (auto=generar): " USERNAME
            read -p "Tipo (test/premium): " TIPO
            read -p "Días (0=test, 7,15,30,50): " DAYS
            [[ -z "$DAYS" ]] && DAYS="30"
            if [[ "$USERNAME" == "auto" || -z "$USERNAME" ]]; then
                USERNAME="user$(shuf -i 1000-9999 -n 1)"
            fi
            PASSWORD="mgvpn247"
            
            if [[ "$TIPO" == "test" ]]; then
                DAYS="0"
                EXPIRE_DATE=$(date -d "+$(get_val '.prices.test_hours') hours" +"%Y-%m-%d %H:%M:%S")
                useradd -m -s /bin/bash "$USERNAME" && echo "$USERNAME:$PASSWORD" | chpasswd
            else
                EXPIRE_DATE=$(date -d "+$DAYS days" +"%Y-%m-%d 23:59:59")
                useradd -M -s /bin/false -e "$(date -d "+$DAYS days" +%Y-%m-%d)" "$USERNAME" && echo "$USERNAME:$PASSWORD" | chpasswd
            fi
            
            if [[ $? -eq 0 ]]; then
                sqlite3 "$DB" "INSERT INTO users (phone, username, password, tipo, expires_at, status) VALUES ('$PHONE', '$USERNAME', '$PASSWORD', '$TIPO', '$EXPIRE_DATE', 1)"
                echo -e "\n${GREEN}✅ USUARIO CREADO${NC}"
                echo -e "👤 Usuario: ${USERNAME}"
                echo -e "🔑 Contraseña: ${PASSWORD}"
                echo -e "⏰ Expira: ${EXPIRE_DATE}"
            else
                echo -e "\n${RED}❌ Error${NC}"
            fi
            read -p "Presiona Enter..."
            ;;
        5)
            clear
            echo -e "${CYAN}👥 USUARIOS ACTIVOS${NC}\n"
            sqlite3 -column -header "$DB" "SELECT username, phone, tipo, expires_at FROM users WHERE status = 1 ORDER BY expires_at ASC LIMIT 20"
            read -p "Presiona Enter..."
            ;;
        6)
            clear
            echo -e "${CYAN}💰 CAMBIAR PRECIOS${NC}\n"
            CURRENT_7D=$(get_val '.prices.price_7d')
            CURRENT_15D=$(get_val '.prices.price_15d')
            CURRENT_30D=$(get_val '.prices.price_30d')
            CURRENT_50D=$(get_val '.prices.price_50d')
            
            echo -e "${YELLOW}Precios actuales:${NC}"
            echo -e "  7 días: $${CURRENT_7D} ARS"
            echo -e "  15 días: $${CURRENT_15D} ARS"
            echo -e "  30 días: $${CURRENT_30D} ARS"
            echo -e "  50 días: $${CURRENT_50D} ARS\n"
            
            read -p "Nuevo precio 7d [${CURRENT_7D}]: " NEW_7D
            read -p "Nuevo precio 15d [${CURRENT_15D}]: " NEW_15D
            read -p "Nuevo precio 30d [${CURRENT_30D}]: " NEW_30D
            read -p "Nuevo precio 50d [${CURRENT_50D}]: " NEW_50D
            
            [[ -n "$NEW_7D" ]] && set_val '.prices.price_7d' "$NEW_7D"
            [[ -n "$NEW_15D" ]] && set_val '.prices.price_15d' "$NEW_15D"
            [[ -n "$NEW_30D" ]] && set_val '.prices.price_30d' "$NEW_30D"
            [[ -n "$NEW_50D" ]] && set_val '.prices.price_50d' "$NEW_50D"
            
            echo -e "\n${GREEN}✅ Precios actualizados${NC}"
            read -p "Presiona Enter..."
            ;;
        7)
            clear
            echo -e "${CYAN}🔑 CONFIGURAR MERCADOPAGO${NC}\n"
            echo -e "${CYAN}📋 Obtener token:${NC}"
            echo -e "  1. https://www.mercadopago.com.ar/developers"
            echo -e "  2. 'Tus credenciales' → Access Token PRODUCCIÓN\n"
            read -p "Pega el Access Token: " NEW_TOKEN
            if [[ -n "$NEW_TOKEN" ]]; then
                set_val '.mercadopago.access_token' "\"$NEW_TOKEN\""
                set_val '.mercadopago.enabled' "true"
                echo -e "\n${GREEN}✅ Token configurado${NC}"
                cd /root/sshbot-pro && pm2 restart sshbot-pro
            fi
            read -p "Presiona Enter..."
            ;;
        8)
            clear
            echo -e "${CYAN}🧪 TEST MERCADOPAGO${NC}\n"
            TOKEN=$(get_val '.mercadopago.access_token')
            if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
                echo -e "${RED}❌ Token no configurado${NC}"
            else
                test_mercadopago "$TOKEN"
            fi
            read -p "Presiona Enter..."
            ;;
        9)
            clear
            echo -e "${CYAN}🔔 CONFIGURAR RECORDATORIOS${NC}\n"
            CURRENT_STATUS=$(get_val '.reminders.enabled')
            echo -e "Estado actual: ${GREEN}$CURRENT_STATUS${NC}\n"
            echo -e "  1. Activar recordatorios"
            echo -e "  2. Desactivar recordatorios"
            echo -e "  3. Ver/editar horarios"
            read -p "Selecciona: " REM_OPT
            case $REM_OPT in
                1) set_val '.reminders.enabled' "true"; echo -e "${GREEN}✅ Activados${NC}" ;;
                2) set_val '.reminders.enabled' "false"; echo -e "${YELLOW}⚠️ Desactivados${NC}" ;;
                3) 
                    CURRENT_TIMES=$(get_val '.reminders.times')
                    echo -e "Horarios actuales: ${CYAN}$CURRENT_TIMES${NC}"
                    read -p "Nuevos horarios (ej: [24,12,6,1]): " NEW_TIMES
                    [[ -n "$NEW_TIMES" ]] && set_val '.reminders.times' "$NEW_TIMES" && echo -e "${GREEN}✅ Actualizados${NC}"
                    ;;
            esac
            read -p "Presiona Enter..."
            ;;
        10)
            clear
            echo -e "${CYAN}📊 ESTADÍSTICAS${NC}\n"
            echo -e "${YELLOW}👥 USUARIOS:${NC}"
            sqlite3 "$DB" "SELECT 'Total: ' || COUNT(*) || ' | Activos: ' || SUM(CASE WHEN status=1 THEN 1 ELSE 0 END) FROM users"
            echo -e "\n${YELLOW}💰 PAGOS:${NC}"
            sqlite3 "$DB" "SELECT 'Pendientes: ' || SUM(CASE WHEN status='pending' THEN 1 ELSE 0 END) || ' | Aprobados: ' || SUM(CASE WHEN status='approved' THEN 1 ELSE 0 END) || ' | Total: $' || printf('%.2f', SUM(CASE WHEN status='approved' THEN amount ELSE 0 END)) FROM payments"
            echo -e "\n${YELLOW}📱 APK:${NC}"
            APK_ENABLED=$(get_val '.apk.enabled')
            APK_FILENAME=$(get_val '.apk.filename')
            echo -e "  Estado: $([ "$APK_ENABLED" == "true" ] && echo "${GREEN}Activo${NC}" || echo "${RED}Inactivo${NC}")"
            echo -e "  Archivo: ${APK_FILENAME:-Ninguno}"
            read -p "Presiona Enter..."
            ;;
        11)
            echo -e "\n${YELLOW}🧹 Limpiando sesión...${NC}"
            pm2 stop sshbot-pro
            rm -rf /root/.wppconnect/*
            echo -e "${GREEN}✅ Sesión limpiada${NC}"
            sleep 2
            ;;
        12)
            clear
            echo -e "${CYAN}💳 PAGOS${NC}\n"
            echo -e "${YELLOW}Pagos pendientes:${NC}"
            sqlite3 -column -header "$DB" "SELECT payment_id, phone, plan, amount, created_at FROM payments WHERE status='pending' ORDER BY created_at DESC LIMIT 10"
            echo -e "\n${YELLOW}Pagos aprobados:${NC}"
            sqlite3 -column -header "$DB" "SELECT payment_id, phone, plan, amount, approved_at FROM payments WHERE status='approved' ORDER BY approved_at DESC LIMIT 10"
            read -p "Presiona Enter..."
            ;;
        13)
            clear
            echo -e "${CYAN}⚙️  CONFIGURACIÓN${NC}\n"
            echo -e "${YELLOW}🤖 BOT:${NC}"
            echo -e "  IP: $(get_val '.bot.server_ip')"
            echo -e "  Versión: $(get_val '.bot.version')"
            echo -e "\n${YELLOW}💰 PRECIOS:${NC}"
            echo -e "  7d: $$(get_val '.prices.price_7d') | 15d: $$(get_val '.prices.price_15d')"
            echo -e "  30d: $$(get_val '.prices.price_30d') | 50d: $$(get_val '.prices.price_50d')"
            echo -e "  Test: $(get_val '.prices.test_hours') horas"
            echo -e "\n${YELLOW}🔔 RECORDATORIOS:${NC}"
            echo -e "  Estado: $(get_val '.reminders.enabled')"
            echo -e "  Horarios: $(get_val '.reminders.times') horas"
            echo -e "\n${YELLOW}📱 APK:${NC}"
            echo -e "  Estado: $(get_val '.apk.enabled')"
            echo -e "  Archivo: $(get_val '.apk.filename')"
            read -p "Presiona Enter..."
            ;;
        14)
            clear
            echo -e "${CYAN}⏰ CAMBIAR HORAS DE PRUEBA${NC}\n"
            CURRENT_HOURS=$(get_val '.prices.test_hours')
            echo -e "Horas actuales: ${GREEN}$CURRENT_HOURS horas${NC}\n"
            read -p "Nuevas horas: " NEW_HOURS
            if [[ -n "$NEW_HOURS" && "$NEW_HOURS" =~ ^[0-9]+$ ]]; then
                set_val '.prices.test_hours' "$NEW_HOURS"
                echo -e "${GREEN}✅ Actualizado a $NEW_HOURS horas${NC}"
            fi
            read -p "Presiona Enter..."
            ;;
        15)
            clear
            echo -e "${CYAN}📱 SUBIR APK PARA WHATSAPP${NC}\n"
            echo -e "${YELLOW}📋 Instrucciones:${NC}"
            echo -e "  1. Coloca el archivo APK en: ${CYAN}$APK_DIR/${NC}"
            echo -e "  2. El archivo debe terminar en .apk"
            echo -e "  3. Los usuarios podrán descargarlo con la opción 4\n"
            
            echo -e "${CYAN}Archivos disponibles en $APK_DIR:${NC}"
            ls -lh "$APK_DIR"/*.apk 2>/dev/null || echo -e "  ${RED}Ningún archivo APK encontrado${NC}"
            echo ""
            
            read -p "Nombre exacto del archivo APK (ej: mgvpn.apk): " APK_FILE
            
            if [[ -n "$APK_FILE" && -f "$APK_DIR/$APK_FILE" ]]; then
                SIZE=$(du -h "$APK_DIR/$APK_FILE" | cut -f1)
                set_val '.apk.enabled' "true"
                set_val '.apk.filename' "\"$APK_FILE\""
                set_val '.apk.size_mb' "$(echo $SIZE | sed 's/M//')"
                set_val '.apk.uploaded_at' "\"$(date)\""
                
                # Actualizar links.app_download con mensaje de WhatsApp
                set_val '.links.app_download' "\"ENVÍA 4 POR WHATSAPP\""
                
                echo -e "\n${GREEN}✅ APK CONFIGURADO CORRECTAMENTE${NC}"
                echo -e "📱 Archivo: ${APK_FILE}"
                echo -e "📊 Tamaño: ${SIZE}"
                echo -e "\n${YELLOW}📱 Los usuarios podrán descargar escribiendo '4' en WhatsApp${NC}"
                
                # Reiniciar bot para aplicar cambios
                cd /root/sshbot-pro && pm2 restart sshbot-pro
            else
                echo -e "\n${RED}❌ Archivo no encontrado: $APK_DIR/$APK_FILE${NC}"
                echo -e "${YELLOW}Primero copia el APK a: $APK_DIR/${NC}"
                echo -e "Ejemplo: ${CYAN}scp mgvpn.apk root@$SERVER_IP:$APK_DIR/${NC}"
            fi
            read -p "Presiona Enter..."
            ;;
        16)
            clear
            echo -e "${CYAN}📱 INFORMACIÓN DEL APK${NC}\n"
            APK_ENABLED=$(get_val '.apk.enabled')
            APK_FILENAME=$(get_val '.apk.filename')
            APK_SIZE=$(get_val '.apk.size_mb')
            APK_UPLOADED=$(get_val '.apk.uploaded_at')
            
            echo -e "${YELLOW}📋 DATOS DEL APK:${NC}"
            echo -e "  Estado: $([ "$APK_ENABLED" == "true" ] && echo "${GREEN}ACTIVO${NC}" || echo "${RED}INACTIVO${NC}")"
            echo -e "  Archivo: ${APK_FILENAME:-No configurado}"
            echo -e "  Tamaño: ${APK_SIZE:-0} MB"
            echo -e "  Subido: ${APK_UPLOADED:-No subido}"
            
            if [[ "$APK_ENABLED" == "true" && -n "$APK_FILENAME" ]]; then
                APK_PATH="$APK_DIR/$APK_FILENAME"
                if [[ -f "$APK_PATH" ]]; then
                    echo -e "\n${GREEN}✅ Archivo existe en el sistema${NC}"
                    ls -lh "$APK_PATH"
                else
                    echo -e "\n${RED}❌ Archivo NO encontrado en el sistema${NC}"
                fi
            fi
            
            echo -e "\n${YELLOW}📱 CÓMO FUNCIONA:${NC}"
            echo -e "  • Los usuarios escriben ${GREEN}4${NC} en WhatsApp"
            echo -e "  • El bot envía automáticamente el archivo APK"
            echo -e "  • También se envía en la creación de prueba"
            
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
PANELEOF

chmod +x /usr/local/bin/sshbot
echo -e "${GREEN}✅ Panel creado con opción SUBIR APK${NC}"

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
║       📱 ENVÍO DE APK POR WHATSAPP (OPCIÓN 4)              ║
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
echo -e "${GREEN}✅ Envío de APK por WhatsApp (Opción 4)${NC}"
echo -e "${GREEN}✅ Recordatorios automáticos${NC}"
echo -e "${GREEN}✅ Prueba gratis de $(get_val '.prices.test_hours') horas${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 COMANDOS PRINCIPALES:${NC}\n"
echo -e "  ${GREEN}sshbot${NC}         - Panel de control completo"
echo -e "  ${GREEN}pm2 logs sshbot-pro${NC} - Ver logs y QR"
echo -e "  ${GREEN}pm2 restart sshbot-pro${NC} - Reiniciar bot"
echo -e "\n"

echo -e "${YELLOW}🚀 PRIMEROS PASOS:${NC}\n"
echo -e "  1. Ver logs: ${GREEN}pm2 logs sshbot-pro${NC}"
echo -e "  2. Escanear QR cuando aparezca"
echo -e "  3. Configurar MercadoPago: ${GREEN}sshbot → opción 7${NC}"
echo -e "  4. SUBIR APK: ${GREEN}sshbot → opción 15${NC}"
echo -e "     • Copia el APK a /opt/sshbot-pro/apk/"
echo -e "     • En el panel, opción 15, escribe el nombre del archivo"
echo -e "  5. Los usuarios descargan con ${GREEN}4${NC} en WhatsApp"
echo -e "  6. Enviar 'menu' al bot en WhatsApp"
echo -e "\n"

echo -e "${YELLOW}📱 SUBIR APK:${NC}\n"
echo -e "  Opción 1 - Copiar por SCP:"
echo -e "    ${CYAN}scp tu_app.apk root@$SERVER_IP:/opt/sshbot-pro/apk/${NC}"
echo -e "\n  Opción 2 - Usar wget:"
echo -e "    ${CYAN}cd /opt/sshbot-pro/apk/${NC}"
echo -e "    ${CYAN}wget https://tu-enlace.com/app.apk${NC}"
echo -e "\n  Luego en el panel: ${GREEN}sshbot → opción 15${NC}"
echo -e "\n"

echo -e "${GREEN}${BOLD}¡Sistema listo! Escanea el QR, sube el APK y empieza a vender 🚀${NC}\n"

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