#!/bin/bash
# ================================================
# SSH BOT PRO - WPPCONNECT + MERCADOPAGO COMPLETO
# VERSIÓN CORREGIDA: Recordatorios + Renovación
# CON RECORDATORIOS DE VENCIMIENTO AUTOMÁTICOS
# CON SUBIDA DE APK DESDE PANEL
# RENOVACIÓN DE USUARIOS FUNCIONAL
# VER MIS USUARIOS ACTIVOS
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
║               🔔 RECORDATORIOS AUTOMÁTICOS ✓               ║
║               🔄 RENOVACIÓN DE USUARIOS ✓                  ║
║               📋 VER MIS USUARIOS ✓                        ║
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
echo -e "  🔔 ${PURPLE}Recordatorios${NC} - 24h, 12h, 6h y 1h antes ✓ CORREGIDO"
echo -e "  🔄 ${BLUE}Renovación${NC} - Renueva tus usuarios existentes ✓ NUEVO"
echo -e "  📋 ${CYAN}Ver usuarios${NC} - Comando 'misusuarios' ✓ NUEVO"
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
        "name": "SSH Bot Pro",
        "version": "2.0-MP-RECORDATORIOS-2H",
        "server_ip": "$SERVER_IP",
        "default_password": "mgvpn247"
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
    is_renewal INTEGER DEFAULT 0,
    renewal_username TEXT,
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
echo -e "\n${CYAN}🤖 Creando bot con WPPConnect + MercadoPago + Recordatorios + Renovación...${NC}"

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

# Crear bot.js COMPLETO CORREGIDO
echo -e "${YELLOW}📝 Creando bot.js CORREGIDO...${NC}"

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
console.log(chalk.cyan.bold('║              🔄 RENOVACIÓN DE USUARIOS                        ║'));
console.log(chalk.cyan.bold('║                    🕒 PRUEBA DE 2 HORAS                       ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

// Cargar configuración
function loadConfig() {
    delete require.cache[require.resolve('/opt/sshbot-pro/config/config.json')];
    return require('/opt/sshbot-pro/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/sshbot-pro/data/users.db');

// Agregar columna last_reminder_hours si no existe
db.run(`ALTER TABLE users ADD COLUMN last_reminder_hours INTEGER DEFAULT 0`, () => {});

// MERCADOPAGO SDK V2.X
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
            return false;
        }
    }
    console.log(chalk.yellow('⚠️ MercadoPago NO configurado'));
    return false;
}

initMercadoPago();

let client = null;

// SISTEMA DE ESTADOS
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

// ✅ FUNCIÓN PARA RENOVAR USUARIO
async function renewSSHUser(phone, username, additionalDays) {
    return new Promise((resolve, reject) => {
        db.get('SELECT username, expires_at, tipo FROM users WHERE phone = ? AND username = ? AND status = 1', 
            [phone, username], 
            async (err, user) => {
                if (err || !user) {
                    resolve({ success: false, error: 'Usuario no encontrado' });
                    return;
                }
                
                const currentExpiry = moment(user.expires_at);
                const newExpiry = currentExpiry.add(additionalDays, 'days');
                const newExpiryStr = newExpiry.format('YYYY-MM-DD HH:mm:ss');
                const newExpiryDate = newExpiry.format('YYYY-MM-DD');
                
                try {
                    await execPromise(`chage -E ${newExpiryDate} ${username} 2>/dev/null || true`);
                    
                    db.run(`UPDATE users SET expires_at = ?, tipo = 'premium' WHERE phone = ? AND username = ?`,
                        [newExpiryStr, phone, username]);
                    
                    resolve({ 
                        success: true, 
                        username, 
                        newExpiry: newExpiryStr,
                        daysAdded: additionalDays
                    });
                } catch (error) {
                    resolve({ success: false, error: error.message });
                }
            });
    });
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

// Enviar APK
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
            '📲 *APP MGVPN*\n\ninstala la aplicación si te sale el cartel dale en mas detalles - instalar de todas formas'
        );
        console.log(chalk.green(`✅ APK enviado a ${to}`));
        return true;
    } catch (error) {
        console.error(chalk.red(`❌ Error enviando APK: ${error.message}`));
        return false;
    }
}

// Crear pago MercadoPago
async function createMercadoPagoPayment(phone, days, amount, planName, isRenewal = false, renewalUsername = null) {
    try {
        if (!mpEnabled || !mpPreference) {
            return { success: false, error: 'MercadoPago no configurado' };
        }
        
        const phoneClean = phone.replace('@c.us', '');
        const paymentId = `${isRenewal ? 'RENEW' : 'SSH'}-${phoneClean}-${days}d-${Date.now()}`;
        
        console.log(chalk.cyan(`🔄 Creando pago MP: ${paymentId}`));
        
        const preferenceData = {
            items: [{
                title: isRenewal ? `RENOVACIÓN SSH ${days} DÍAS` : `SSH PREMIUM ${days} DÍAS`,
                description: isRenewal ? `Renovación de acceso SSH por ${days} días` : `Acceso SSH Premium por ${days} días`,
                quantity: 1,
                currency_id: config.prices.currency || 'ARS',
                unit_price: parseFloat(amount)
            }],
            external_reference: paymentId,
            expires: true,
            expiration_date_from: moment().toISOString(),
            expiration_date_to: moment().add(24, 'hours').toISOString(),
            back_urls: {
                success: `https://wa.me/${phoneClean}?text=Ya%20pague%20mgvpn`,
                failure: `https://wa.me/${phoneClean}?text=Pago%20fallido`,
                pending: `https://wa.me/${phoneClean}?text=Pago%20pendiente`
            },
            auto_return: 'approved',
            statement_descriptor: 'SSH PREMIUM'
        };
        
        const response = await mpPreference.create({ body: preferenceData });
        
        if (response && response.id) {
            const paymentUrl = response.init_point;
            const qrPath = `${config.paths.qr_codes}/${paymentId}.png`;
            
            await QRCode.toFile(qrPath, paymentUrl, { width: 400, margin: 2 });
            
            db.run(
                `INSERT INTO payments (payment_id, phone, plan, days, amount, status, payment_url, qr_code, preference_id, is_renewal, renewal_username) 
                 VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?, ?)`,
                [paymentId, phone, `${days}d`, days, amount, paymentUrl, qrPath, response.id, isRenewal ? 1 : 0, renewalUsername],
                (err) => { if (err) console.error(chalk.red('❌ Error BD:'), err.message); }
            );
            
            return { success: true, paymentId, paymentUrl, qrPath, amount: parseFloat(amount) };
        }
        
        throw new Error('Respuesta inválida');
        
    } catch (error) {
        console.error(chalk.red('❌ Error MercadoPago:'), error.message);
        return { success: false, error: error.message };
    }
}

// Verificar pagos pendientes
async function checkPendingPayments() {
    if (!mpEnabled) return;
    
    db.all('SELECT * FROM payments WHERE status = "pending" AND created_at > datetime("now", "-48 hours")', async (err, payments) => {
        if (err || !payments || payments.length === 0) return;
        
        console.log(chalk.yellow(`🔍 Verificando ${payments.length} pagos...`));
        
        for (const payment of payments) {
            try {
                const url = `https://api.mercadopago.com/v1/payments/search?external_reference=${payment.payment_id}`;
                const response = await axios.get(url, {
                    headers: { 'Authorization': `Bearer ${config.mercadopago.access_token}` },
                    timeout: 15000
                });
                
                if (response.data && response.data.results && response.data.results.length > 0) {
                    const mpPayment = response.data.results[0];
                    
                    if (mpPayment.status === 'approved') {
                        console.log(chalk.green(`✅ PAGO APROBADO: ${payment.payment_id}`));
                        
                        if (payment.is_renewal && payment.renewal_username) {
                            // Es renovación
                            const result = await renewSSHUser(payment.phone, payment.renewal_username, payment.days);
                            
                            if (result.success) {
                                db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`, [payment.payment_id]);
                                
                                const message = `✅ RENOVACIÓN CONFIRMADA

🎉 Tu usuario ${result.username} ha sido renovado por +${payment.days} días

📅 Nueva expiración: ${moment(result.newExpiry).format('DD/MM/YYYY HH:mm')}

🎊 ¡Gracias por confiar en nosotros!`;
                                
                                if (client) await client.sendText(payment.phone, message);
                            }
                        } else {
                            // Usuario nuevo
                            const username = generatePremiumUsername();
                            const result = await createSSHUser(payment.phone, username, payment.days);
                            
                            if (result.success) {
                                db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`, [payment.payment_id]);
                                
                                const expireDate = moment().add(payment.days, 'days').format('DD/MM/YYYY');
                                const message = `✅ PAGO CONFIRMADO

🎉 Tu compra ha sido aprobada

👤 Usuario: ${username}
🔑 Contraseña: ${DEFAULT_PASSWORD}
⏰ Válido hasta: ${expireDate}

🎊 ¡Disfruta del servicio premium!`;
                                
                                if (client) await client.sendText(payment.phone, message);
                            }
                        }
                    }
                }
            } catch (error) {
                console.error(chalk.red(`❌ Error verificando: ${error.message}`));
            }
        }
    });
}

// Inicializar bot
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
                args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
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
                
                // Comando para ver usuarios activos
                if (text === 'misusuarios' || text === 'mis usuarios') {
                    db.all(`SELECT username, expires_at FROM users WHERE phone = ? AND status = 1`, [from], async (err, rows) => {
                        if (err || !rows || rows.length === 0) {
                            await client.sendText(from, `📋 No tienes usuarios activos.\n\nPara crear una cuenta, envía MENU y selecciona opción 1 o 2.`);
                        } else {
                            let response = `📋 *TUS USUARIOS ACTIVOS*\n\n`;
                            for (const row of rows) {
                                const expires = moment(row.expires_at).format('DD/MM/YYYY HH:mm');
                                response += `👤 *${row.username}*\n⏰ Expira: ${expires}\n━━━━━━━━━━━━━━━━━━━━━\n`;
                            }
                            response += `\nPara renovar, envía MENU → Opción 3`;
                            await client.sendText(from, response);
                        }
                    });
                    return;
                }
                
                // MENÚ PRINCIPAL
                if (['menu', 'hola', 'start', 'hi', 'volver', '0'].includes(text)) {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, `HOLA BIENVENIDO BOT MGVPN IP 🇦🇷

Elija una opción:

 1️⃣ - CREAR PRUEBA (2 HORAS)
 2️⃣ - COMPRAR USUARIO SSH
 3️⃣ - RENOVAR USUARIO SSH
 4️⃣ - DESCARGAR APLICACIÓN
 5️⃣ - MIS USUARIOS`);
                }
                
                // OPCIÓN 1: CREAR PRUEBA
                else if (text === '1' && userState.state === 'main_menu') {
                    if (!(await canCreateTest(from))) {
                        await client.sendText(from, `⚠️ YA USASTE TU PRUEBA HOY\n\n⏳ Vuelve mañana para otra prueba gratuita de 2 horas`);
                        return;
                    }
                    
                    await client.sendText(from, '⏳ Creando cuenta de prueba de 2 horas...');
                    
                    const username = generateUsername();
                    const result = await createSSHUser(from, username, 0);
                    
                    if (result.success) {
                        registerTest(from);
                        await client.sendText(from, `✅ PRUEBA DE 2 HORAS CREADA

👤 Usuario: ${username}
🔐 Contraseña: ${DEFAULT_PASSWORD}
⏰ Expira en: ${config.prices.test_hours} horas

💡 Envía "4" para descargar la APP`);
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                }
                
                // OPCIÓN 2: COMPRAR
                else if (text === '2' && userState.state === 'main_menu') {
                    await setUserState(from, 'buying_ssh');
                    await client.sendText(from, `🌐 PLANES SSH PREMIUM

Elija una opción:
 1️⃣ - PLANES DIARIOS 
 2️⃣ - PLANES MENSUALES
 0️⃣ - VOLVER`);
                }
                
                // SUBMENÚ COMPRAS
                else if (userState.state === 'buying_ssh') {
                    if (text === '1') {
                        await setUserState(from, 'selecting_daily_plan');
                        await client.sendText(from, `🌐 PLANES DIARIOS SSH

 1️⃣ - 7 DIAS - $${config.prices.price_7d}
 2️⃣ - 15 DIAS - $${config.prices.price_15d}
 0️⃣ - VOLVER`);
                    }
                    else if (text === '2') {
                        await setUserState(from, 'selecting_monthly_plan');
                        await client.sendText(from, `🌐 PLANES MENSUALES SSH

 1️⃣ - 30 DIAS - $${config.prices.price_30d}
 2️⃣ - 50 DIAS - $${config.prices.price_50d}
 0️⃣ - VOLVER`);
                    }
                    else if (text === '0') {
                        await setUserState(from, 'main_menu');
                        await client.sendText(from, `HOLA BIENVENIDO BOT MGVPN IP 🇦🇷

Elija una opción:

 1️⃣ - CREAR PRUEBA (2 HORAS)
 2️⃣ - COMPRAR USUARIO SSH
 3️⃣ - RENOVAR USUARIO SSH
 4️⃣ - DESCARGAR APLICACIÓN
 5️⃣ - MIS USUARIOS`);
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
                            await client.sendText(from, '⏳ Procesando...');
                            const payment = await createMercadoPagoPayment(from, plan.days, plan.price, plan.name, false, null);
                            
                            if (payment.success) {
                                await client.sendText(from, `🌐 Plan: ${plan.name}\n💰 Precio: $${payment.amount}\n\n🔗 LINK DE PAGO:\n${payment.paymentUrl}\n\n⏰ Válido por 24 horas`);
                                if (fs.existsSync(payment.qrPath)) {
                                    await client.sendImage(from, payment.qrPath, 'qr.jpg', `Escanea con MercadoPago\n${plan.name} - $${payment.amount}`);
                                }
                            } else {
                                await client.sendText(from, `❌ Error: ${payment.error}`);
                            }
                        } else {
                            await client.sendText(from, `⚠️ Pago manual. Contacta al administrador:\n${config.links.support}`);
                        }
                        await setUserState(from, 'main_menu');
                    }
                    else if (text === '0') {
                        await setUserState(from, 'buying_ssh');
                        await client.sendText(from, `🌐 PLANES SSH PREMIUM\n\n 1️⃣ - DIARIOS\n 2️⃣ - MENSUALES\n 0️⃣ - VOLVER`);
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
                            await client.sendText(from, '⏳ Procesando...');
                            const payment = await createMercadoPagoPayment(from, plan.days, plan.price, plan.name, false, null);
                            
                            if (payment.success) {
                                await client.sendText(from, `🌐 Plan: ${plan.name}\n💰 Precio: $${payment.amount}\n\n🔗 LINK DE PAGO:\n${payment.paymentUrl}\n\n⏰ Válido por 24 horas`);
                                if (fs.existsSync(payment.qrPath)) {
                                    await client.sendImage(from, payment.qrPath, 'qr.jpg', `Escanea con MercadoPago\n${plan.name} - $${payment.amount}`);
                                }
                            } else {
                                await client.sendText(from, `❌ Error: ${payment.error}`);
                            }
                        } else {
                            await client.sendText(from, `⚠️ Pago manual. Contacta al administrador:\n${config.links.support}`);
                        }
                        await setUserState(from, 'main_menu');
                    }
                    else if (text === '0') {
                        await setUserState(from, 'buying_ssh');
                        await client.sendText(from, `🌐 PLANES SSH PREMIUM\n\n 1️⃣ - DIARIOS\n 2️⃣ - MENSUALES\n 0️⃣ - VOLVER`);
                    }
                }
                
                // OPCIÓN 3: RENOVAR
                else if (text === '3' && userState.state === 'main_menu') {
                    await setUserState(from, 'renewing_ssh');
                    await client.sendText(from, `🔄 RENOVAR USUARIO SSH

Escribe tu NOMBRE DE USUARIO (ej: user1234)

O envía 0 para cancelar.`);
                }
                
                // MANEJAR RENOVACIÓN
                else if (userState.state === 'renewing_ssh') {
                    if (text === '0') {
                        await setUserState(from, 'main_menu');
                        await client.sendText(from, `✅ Renovación cancelada.`);
                        return;
                    }
                    
                    // Verificar que el usuario existe
                    db.get(`SELECT username FROM users WHERE phone = ? AND username = ? AND status = 1`, 
                        [from, text], 
                        async (err, row) => {
                            if (err || !row) {
                                await client.sendText(from, `❌ Usuario "${text}" no encontrado o no está activo.\n\nVerifica con "misusuarios" y vuelve a intentar.`);
                                await setUserState(from, 'main_menu');
                                return;
                            }
                            
                            await setUserState(from, 'renewing_select_plan', { username: text });
                            
                            await client.sendText(from, `✅ Usuario: ${text}\n\nSelecciona los días a RENOVAR:\n\n1️⃣ - 7 DÍAS - $${config.prices.price_7d}\n2️⃣ - 15 DÍAS - $${config.prices.price_15d}\n3️⃣ - 30 DÍAS - $${config.prices.price_30d}\n4️⃣ - 50 DÍAS - $${config.prices.price_50d}\n0️⃣ - CANCELAR`);
                        });
                }
                
                else if (userState.state === 'renewing_select_plan') {
                    const username = userState.data.username;
                    const planMap = {
                        '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                        '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' },
                        '3': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                        '4': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                    };
                    
                    if (text === '0') {
                        await setUserState(from, 'main_menu');
                        await client.sendText(from, `✅ Renovación cancelada.`);
                        return;
                    }
                    
                    const plan = planMap[text];
                    
                    if (plan) {
                        if (mpEnabled) {
                            await client.sendText(from, '⏳ Procesando renovación...');
                            const payment = await createMercadoPagoPayment(from, plan.days, plan.price, plan.name, true, username);
                            
                            if (payment.success) {
                                await client.sendText(from, `🔄 RENOVACIÓN SSH\n\n👤 Usuario: ${username}\n📆 Plan: ${plan.name}\n💰 Precio: $${payment.amount}\n\n🔗 LINK DE PAGO:\n${payment.paymentUrl}\n\n✅ Una vez pagado, se renovará automáticamente.`);
                                if (fs.existsSync(payment.qrPath)) {
                                    await client.sendImage(from, payment.qrPath, 'qr.jpg', `Renovación ${plan.name} - $${payment.amount}`);
                                }
                            } else {
                                await client.sendText(from, `❌ Error: ${payment.error}`);
                            }
                        } else {
                            await client.sendText(from, `🔄 RENOVACIÓN: ${plan.name}\n👤 Usuario: ${username}\n💰 Precio: $${plan.price}\n\nContacta al administrador:\n${config.links.support}`);
                        }
                        await setUserState(from, 'main_menu');
                    }
                }
                
                // OPCIÓN 4: DESCARGAR APP
                else if (text === '4' && userState.state === 'main_menu') {
                    const apkPath = '/root/mgvpn.apk';
                    if (fs.existsSync(apkPath)) {
                        await client.sendText(from, '📲 Enviando aplicación...');
                        await sendAppFile(from);
                    } else {
                        await client.sendText(from, `📲 DESCARGAR APP\n\n🔗 Enlace: ${config.links.app_download}\n\nContraseña por defecto: ${DEFAULT_PASSWORD}`);
                    }
                }
                
                // OPCIÓN 5: MIS USUARIOS
                else if (text === '5' && userState.state === 'main_menu') {
                    db.all(`SELECT username, expires_at FROM users WHERE phone = ? AND status = 1`, [from], async (err, rows) => {
                        if (err || !rows || rows.length === 0) {
                            await client.sendText(from, `📋 No tienes usuarios activos.\n\nPara crear una cuenta, envía MENU y selecciona opción 1 o 2.`);
                        } else {
                            let response = `📋 *TUS USUARIOS ACTIVOS*\n\n`;
                            for (const row of rows) {
                                const expires = moment(row.expires_at).format('DD/MM/YYYY HH:mm');
                                response += `👤 *${row.username}*\n⏰ Expira: ${expires}\n━━━━━━━━━━━━━━━━━━━━━\n`;
                            }
                            response += `\nPara renovar, envía MENU → Opción 3`;
                            await client.sendText(from, response);
                        }
                    });
                }
                
            } catch (error) {
                console.error(chalk.red('❌ Error:'), error.message);
            }
        });
        
        // VERIFICAR PAGOS CADA 2 MINUTOS
        cron.schedule('*/2 * * * *', () => {
            console.log(chalk.yellow('🔄 Verificando pagos...'));
            checkPendingPayments();
        });
        
        // LIMPIEZA CADA 15 MINUTOS
        cron.schedule('*/15 * * * *', async () => {
            const now = moment().format('YYYY-MM-DD HH:mm:ss');
            db.all('SELECT username FROM users WHERE expires_at < ? AND status = 1', [now], async (err, rows) => {
                if (err || !rows) return;
                for (const r of rows) {
                    try {
                        await execPromise(`pkill -u ${r.username} 2>/dev/null || true`);
                        await execPromise(`userdel -f ${r.username} 2>/dev/null || true`);
                        db.run('UPDATE users SET status = 0 WHERE username = ?', [r.username]);
                        console.log(chalk.green(`🗑️ Eliminado: ${r.username}`));
                    } catch (e) {}
                }
            });
        });
        
        // RECORDATORIOS CADA HORA - CORREGIDO
        cron.schedule('0 * * * *', async () => {
            if (!config.reminders || !config.reminders.enabled) return;
            
            console.log(chalk.yellow('🔔 Verificando usuarios por vencer...'));
            const reminderTimes = config.reminders.times || [24, 12, 6, 1];
            
            for (const hours of reminderTimes) {
                const targetTime = moment().add(hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
                
                db.all(
                    `SELECT phone, username, expires_at, last_reminder_hours FROM users 
                     WHERE status = 1 
                     AND tipo = 'premium'
                     AND expires_at BETWEEN datetime('now') AND ?`,
                    [targetTime],
                    async (err, users) => {
                        if (err || !users) return;
                        
                        for (const user of users) {
                            const bitFlag = 1 << hours;
                            if (user.last_reminder_hours & bitFlag) {
                                continue;
                            }
                            
                            const expireFormatted = moment(user.expires_at).format('DD/MM/YYYY HH:mm');
                            let message = hours === 1 
                                ? `⚠️ *¡ÚLTIMA HORA!*\n\nTu cuenta SSH *${user.username}* vencerá en *1 HORA*\n📅 ${expireFormatted}\n\n⏰ *RENUEVA AHORA* enviando MENU`
                                : `🔔 *RECORDATORIO*\n\nTu cuenta SSH *${user.username}* vencerá en *${hours} horas*\n📅 ${expireFormatted}\n\nPara renovar, envía MENU`;
                            
                            try {
                                if (client) {
                                    await client.sendText(user.phone, message);
                                    console.log(chalk.green(`✅ Recordatorio ${hours}h a ${user.username}`));
                                    const newFlags = user.last_reminder_hours | bitFlag;
                                    db.run(`UPDATE users SET last_reminder_hours = ? WHERE username = ?`, [newFlags, user.username]);
                                }
                            } catch (error) {
                                console.error(chalk.red(`❌ Error: ${error.message}`));
                            }
                        }
                    }
                );
            }
        });
        
        // LIMPIAR ESTADOS
        cron.schedule('0 * * * *', () => {
            db.run(`DELETE FROM user_state WHERE updated_at < datetime('now', '-1 hour')`);
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

echo -e "${GREEN}✅ Bot creado con todas las correcciones${NC}"

# ================================================
# CREAR PANEL DE CONTROL
# ================================================
echo -e "\n${CYAN}🎛️  Creando panel de control...${NC}"

cat > /usr/local/bin/sshbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

DB="/opt/sshbot-pro/data/users.db"
CONFIG="/opt/sshbot-pro/config/config.json"
APK_PATH="/root/mgvpn.apk"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }
set_val() { local t=$(mktemp); jq "$1 = $2" "$CONFIG" > "$t" && mv "$t" "$CONFIG"; }

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         🎛️  PANEL SSH BOT PRO - CON RECORDATORIOS          ║${NC}"
    echo -e "${CYAN}║              🔄 RENOVACIÓN + MIS USUARIOS                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

upload_apk() {
    clear
    echo -e "${CYAN}📲 SUBIR APLICACIÓN (APK)${NC}\n"
    if [[ -f "$APK_PATH" ]]; then
        echo -e "${GREEN}✅ App actual: $(du -h "$APK_PATH" | cut -f1)${NC}\n"
    fi
    read -p "Ruta del APK: " SOURCE_APK
    if [[ -f "$SOURCE_APK" && "$SOURCE_APK" == *.apk ]]; then
        cp "$SOURCE_APK" "$APK_PATH" && chmod 644 "$APK_PATH"
        echo -e "${GREEN}✅ APK subido${NC}"
    else
        echo -e "${RED}❌ Archivo inválido${NC}"
    fi
    read -p "Enter..."
}

while true; do
    show_header
    
    TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1" 2>/dev/null || echo "0")
    STATUS=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.name=="sshbot-pro") | .pm2_env.status' 2>/dev/null || echo "stopped")
    
    echo -e "${YELLOW}📊 ESTADO${NC}"
    echo -e "  Bot: $([ "$STATUS" == "online" ] && echo "${GREEN}● ACTIVO${NC}" || echo "${RED}● DETENIDO${NC}")"
    echo -e "  Usuarios: ${CYAN}$ACTIVE/$TOTAL${NC}"
    echo -e "  MP: $([ -n "$(get_val '.mercadopago.access_token')" ] && echo "${GREEN}✅${NC}" || echo "${RED}❌${NC}")"
    echo -e "  Recordatorios: $([ "$(get_val '.reminders.enabled')" == "true" ] && echo "${GREEN}✅${NC}" || echo "${RED}❌${NC}")"
    echo -e ""
    
    echo -e "${CYAN}[1] Iniciar bot    [2] Detener bot    [3] Logs"
    echo -e "${CYAN}[4] Config MP      [5] Editar precios [6] Subir APK"
    echo -e "${CYAN}[7] Ver usuarios   [8] Estadísticas   [0] Salir${NC}"
    echo ""
    read -p "👉 Selecciona: " OPT
    
    case $OPT in
        1) cd /root/sshbot-pro && pm2 restart sshbot-pro 2>/dev/null || pm2 start bot.js --name sshbot-pro; pm2 save; sleep 2;;
        2) pm2 stop sshbot-pro; sleep 1;;
        3) pm2 logs sshbot-pro --lines 80;;
        4)
            TOKEN=$(get_val '.mercadopago.access_token')
            echo -e "\n${YELLOW}Token actual: ${TOKEN:0:30}...${NC}"
            read -p "Nuevo token (APP_USR-xxx): " NEW_TOKEN
            if [[ "$NEW_TOKEN" =~ ^APP_USR- ]]; then
                set_val '.mercadopago.access_token' "\"$NEW_TOKEN\""
                set_val '.mercadopago.enabled' "true"
                echo -e "${GREEN}✅ Token guardado. Reinicia el bot.${NC}"
            fi
            read -p "Enter...";;
        5)
            echo -e "\n${YELLOW}Precios actuales:${NC}"
            echo "  7d: $(get_val '.prices.price_7d') | 15d: $(get_val '.prices.price_15d')"
            echo "  30d: $(get_val '.prices.price_30d') | 50d: $(get_val '.prices.price_50d')"
            read -p "Nuevo precio 7d: " p7; read -p "Nuevo precio 15d: " p15
            read -p "Nuevo precio 30d: " p30; read -p "Nuevo precio 50d: " p50
            [[ -n "$p7" ]] && set_val '.prices.price_7d' "$p7"
            [[ -n "$p15" ]] && set_val '.prices.price_15d' "$p15"
            [[ -n "$p30" ]] && set_val '.prices.price_30d' "$p30"
            [[ -n "$p50" ]] && set_val '.prices.price_50d' "$p50"
            echo -e "${GREEN}✅ Precios actualizados${NC}"
            read -p "Enter...";;
        6) upload_apk;;
        7)
            echo -e "\n${CYAN}USUARIOS ACTIVOS:${NC}"
            sqlite3 -column -header "$DB" "SELECT username, phone, tipo, expires_at FROM users WHERE status=1 ORDER BY expires_at LIMIT 20"
            read -p "Enter...";;
        8)
            clear
            echo -e "${CYAN}📊 ESTADÍSTICAS${NC}\n"
            echo "Usuarios totales: $(sqlite3 "$DB" "SELECT COUNT(*) FROM users")"
            echo "Usuarios activos: $(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1")"
            echo "Pagos aprobados: $(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='approved'")"
            echo "Ingresos totales: $(sqlite3 "$DB" "SELECT printf('%.2f', SUM(amount)) FROM payments WHERE status='approved'") ARS"
            echo "Tests hoy: $(sqlite3 "$DB" "SELECT COUNT(*) FROM daily_tests WHERE date=date('now')")"
            echo "Vencen hoy: $(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1 AND date(expires_at)=date('now')")"
            read -p "Enter...";;
        0) echo -e "\n${GREEN}👋 Hasta luego${NC}"; exit 0;;
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

sleep 3

# ================================================
# MENSAJE FINAL
# ================================================
clear
echo -e "${GREEN}${BOLD}"
cat << "FINAL"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          🎉 INSTALACIÓN COMPLETADA - CORREGIDA 🎉           ║
║                                                              ║
║       ✅ Recordatorios funcionando                         ║
║       ✅ Renovación de usuarios funcionando                ║
║       ✅ Comando "misusuarios" disponible                  ║
║       ✅ MercadoPago integrado                             ║
║       ✅ Envío de APK por WhatsApp                         ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${GREEN}✅ Instalación completa${NC}"
echo -e ""
echo -e "${YELLOW}📋 COMANDOS:${NC}"
echo -e "  ${GREEN}sshbot${NC}         - Panel de control"
echo -e "  ${GREEN}pm2 logs sshbot-pro${NC} - Ver QR y logs"
echo -e ""
echo -e "${YELLOW}🚀 PRIMEROS PASOS:${NC}"
echo -e "  1. ${GREEN}pm2 logs sshbot-pro${NC} - Esperar QR"
echo -e "  2. Escanear QR con WhatsApp"
echo -e "  3. ${GREEN}sshbot${NC} - Configurar MercadoPago (opción 4)"
echo -e "  4. Subir APK (opción 6)"
echo -e "  5. Enviar 'menu' al bot"
echo -e ""

read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    pm2 logs sshbot-pro
fi

exit 0