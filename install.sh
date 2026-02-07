#!/bin/bash
# ================================================
# SSH BOT PRO - COMPATIBLE UBUNTU 20/22
# ✅ Funciona en Ubuntu 20.04 y 22.04
# ✅ MercadoPago funcionando
# ✅ Renovación de usuarios
# ================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${CYAN}${BOLD}"
cat << "BANNER"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║            🤖 BOT MGVPN - UBUNTU 20/22 COMPATIBLE        ║
║             ✅ COMPRA + RENOVACIÓN + MERCADOPAGO           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Debes ejecutar como root${NC}"
    exit 1
fi

# Detectar Ubuntu versión
echo -e "${CYAN}🔍 Detectando sistema...${NC}"
if [[ -f /etc/lsb-release ]]; then
    source /etc/lsb-release
    echo -e "${GREEN}✅ Ubuntu $DISTRIB_RELEASE ($DISTRIB_CODENAME)${NC}"
elif [[ -f /etc/os-release ]]; then
    source /etc/os-release
    echo -e "${GREEN}✅ $NAME $VERSION${NC}"
else
    echo -e "${YELLOW}⚠️  No se pudo detectar la versión exacta${NC}"
fi

# Detectar IP
echo -e "\n${CYAN}🔍 Detectando IP...${NC}"
SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "127.0.0.1")
if [[ -z "$SERVER_IP" || "$SERVER_IP" == "127.0.0.1" ]]; then
    read -p "📝 Ingresa la IP del servidor: " SERVER_IP
fi

echo -e "${GREEN}✅ IP: ${CYAN}$SERVER_IP${NC}\n"

read -p "$(echo -e "${YELLOW}¿Instalar? (s/N): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    exit 0
fi

# ================================================
# INSTALAR DEPENDENCIAS PARA UBUNTU 20/22
# ================================================
echo -e "\n${CYAN}📦 Instalando dependencias para Ubuntu...${NC}"

# Actualizar sistema
apt-get update -y
apt-get upgrade -y

# Instalar dependencias del sistema UBUNTU
apt-get install -y \
    wget \
    curl \
    git \
    sqlite3 \
    jq \
    python3 \
    python3-pip \
    unzip \
    build-essential \
    gconf-service \
    libgbm-dev \
    libasound2 \
    libatk1.0-0 \
    libc6 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libgcc1 \
    libgconf-2-4 \
    libgdk-pixbuf2.0-0 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    ca-certificates \
    fonts-liberation \
    libappindicator1 \
    libnss3 \
    lsb-release \
    xdg-utils

# Instalar Node.js 18.x (compatible con Ubuntu 20/22)
echo -e "\n${CYAN}📦 Instalando Node.js 18...${NC}"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Verificar versiones
echo -e "\n${GREEN}✅ Versiones instaladas:${NC}"
echo -e "Node.js: $(node --version)"
echo -e "npm: $(npm --version)"

# Instalar Chrome estable (compatible)
echo -e "\n${CYAN}📦 Instalando Chrome...${NC}"
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get update -y
apt-get install -y google-chrome-stable

# Instalar PM2 globalmente
echo -e "\n${CYAN}📦 Instalando PM2...${NC}"
npm install -g pm2

echo -e "${GREEN}✅ Dependencias instaladas correctamente${NC}"

# ================================================
# CREAR ESTRUCTURA
# ================================================
echo -e "\n${CYAN}📁 Creando estructura...${NC}"

INSTALL_DIR="/root/sshbot"
mkdir -p "$INSTALL_DIR"/{data,qr_codes,sessions}

# Configuración
cat > "$INSTALL_DIR/config.json" << EOF
{
    "bot": {
        "server_ip": "$SERVER_IP",
        "default_password": "mgvpn247"
    },
    "prices": {
        "test_hours": 1,
        "price_7d": 1500,
        "price_15d": 2500,
        "price_30d": 4000,
        "price_50d": 6000
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false
    },
    "links": {
        "app_download": "https://www.mediafire.com/file/p8kgthxbsid7xws/MAJ/DNI_AND_FIL"
    }
}
EOF

# Base de datos COMPLETA
sqlite3 "$INSTALL_DIR/data/users.db" << 'SQL'
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    username TEXT UNIQUE,
    password TEXT DEFAULT 'mgvpn247',
    tipo TEXT,
    expires_at DATETIME,
    status INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_id TEXT UNIQUE,
    phone TEXT,
    username TEXT,
    plan TEXT,
    days INTEGER,
    amount REAL,
    status TEXT DEFAULT 'pending',
    payment_url TEXT,
    qr_code TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS user_states (
    phone TEXT PRIMARY KEY,
    state TEXT DEFAULT 'menu',
    data TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
SQL

# Crear archivo de log
touch "$INSTALL_DIR/bot.log"
chmod 644 "$INSTALL_DIR/bot.log"

echo -e "${GREEN}✅ Estructura creada${NC}"

# ================================================
# CREAR BOT COMPLETO CON MEJOR MANEJO DE ERRORES
# ================================================
echo -e "\n${CYAN}🤖 Creando bot mejorado...${NC}"

cd "$INSTALL_DIR"

# Configurar npm para evitar errores
npm config set fetch-retry-mintimeout 20000
npm config set fetch-retry-maxtimeout 120000

# Crear package.json optimizado
cat > package.json << 'PKGEOF'
{
    "name": "sshbot",
    "version": "1.0.0",
    "description": "SSH Bot con renovación",
    "main": "bot.js",
    "scripts": {
        "start": "node bot.js",
        "test": "echo \"Error: no test specified\" && exit 1"
    },
    "dependencies": {
        "@wppconnect-team/wppconnect": "^1.25.0",
        "qrcode-terminal": "^0.12.0",
        "qrcode": "^1.5.3",
        "moment": "^2.29.4",
        "sqlite3": "^5.1.6",
        "axios": "^1.6.0"
    },
    "engines": {
        "node": ">=16.0.0",
        "npm": ">=7.0.0"
    }
}
PKGEOF

# Instalar dependencias con reintentos
echo -e "${CYAN}📦 Instalando dependencias Node.js...${NC}"
for i in {1..3}; do
    echo -e "Intento $i/3..."
    if npm install --silent --no-progress; then
        echo -e "${GREEN}✅ Dependencias instaladas${NC}"
        break
    elif [[ $i -eq 3 ]]; then
        echo -e "${YELLOW}⚠️  Instalando con modo forzado...${NC}"
        npm install --force
    fi
    sleep 2
done

# BOT.JS MEJORADO CON RECONEXIÓN
cat > bot.js << 'BOTEOF'
const wppconnect = require('@wppconnect-team/wppconnect');
const qrcode = require('qrcode-terminal');
const QRCode = require('qrcode');
const moment = require('moment');
const sqlite3 = require('sqlite3').verbose();
const { exec } = require('child_process');
const util = require('util');
const fs = require('fs');
const path = require('path');
const axios = require('axios');

const execPromise = util.promisify(exec);
moment.locale('es');

const config = require('./config.json');
const db = new sqlite3.Database('./data/users.db');

// Configurar logs
const logFile = path.join(__dirname, 'bot.log');

function logMessage(message) {
    const timestamp = moment().format('YYYY-MM-DD HH:mm:ss');
    const logLine = `[${timestamp}] ${message}\n`;
    console.log(logLine.trim());
    fs.appendFileSync(logFile, logLine);
}

logMessage('🚀 SSH BOT PRO - INICIANDO');
logMessage(`📱 IP: ${config.bot.server_ip}`);
logMessage(`📁 Directorio: ${__dirname}`);

// ========== FUNCIONES DE ESTADO ==========
function getState(phone) {
    return new Promise((resolve) => {
        db.get('SELECT state, data FROM user_states WHERE phone = ?', [phone], (err, row) => {
            if (err || !row) {
                resolve({ state: 'menu', data: null });
            } else {
                resolve({
                    state: row.state || 'menu',
                    data: row.data ? JSON.parse(row.data) : null
                });
            }
        });
    });
}

function setState(phone, state, data = null) {
    return new Promise((resolve) => {
        const dataStr = data ? JSON.stringify(data) : null;
        db.run(
            `INSERT OR REPLACE INTO user_states (phone, state, data, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)`,
            [phone, state, dataStr],
            (err) => {
                if (err) logMessage(`Error estado: ${err.message}`);
                resolve();
            }
        );
    });
}

// ========== FUNCIONES SSH ==========
async function createSSHUser(phone, username, days) {
    const password = config.bot.default_password;
    
    try {
        // Verificar si el usuario ya existe
        const userExists = await new Promise((resolve) => {
            db.get('SELECT username FROM users WHERE username = ?', [username], (err, row) => {
                resolve(!!row);
            });
        });
        
        if (userExists) {
            return { success: false, error: 'El usuario ya existe' };
        }
        
        if (days === 0) {
            // Test - 1 hora
            const expire = moment().add(config.prices.test_hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
            
            // Crear usuario en sistema
            await execPromise(`useradd -m -s /bin/bash ${username}`);
            await execPromise(`echo "${username}:${password}" | chpasswd`);
            
            // Guardar en BD
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at) VALUES (?, ?, ?, 'test', ?)`,
                [phone, username, password, expire]);
            
            logMessage(`✅ Test creado: ${username} para ${phone}`);
            return { success: true, username, password };
            
        } else {
            // Premium - días específicos
            const expire = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
            const systemExpire = moment().add(days, 'days').format('YYYY-MM-DD');
            
            // Crear usuario en sistema
            await execPromise(`useradd -M -s /bin/false -e ${systemExpire} ${username}`);
            await execPromise(`echo "${username}:${password}" | chpasswd`);
            
            // Guardar en BD
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at) VALUES (?, ?, ?, 'premium', ?)`,
                [phone, username, password, expire]);
            
            logMessage(`✅ Premium creado: ${username} por ${days} días para ${phone}`);
            return { success: true, username, password };
        }
    } catch (error) {
        logMessage(`❌ Error crear SSH: ${error.message}`);
        return { success: false, error: error.message };
    }
}

// ========== RENOVAR USUARIO ==========
async function renewSSHUser(username, days) {
    try {
        // Verificar que el usuario existe en sistema
        try {
            await execPromise(`id ${username}`);
        } catch (error) {
            return { success: false, error: 'Usuario no existe en el sistema' };
        }
        
        // Obtener fecha actual de expiración
        const user = await new Promise((resolve, reject) => {
            db.get('SELECT expires_at FROM users WHERE username = ?', [username], (err, row) => {
                if (err) reject(err);
                else resolve(row);
            });
        });
        
        let newExpire;
        if (user && user.expires_at) {
            // Extender desde la fecha actual
            const currentExpire = moment(user.expires_at);
            if (currentExpire.isBefore(moment())) {
                // Si ya expiró, empezar desde hoy
                newExpire = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
            } else {
                newExpire = currentExpire.add(days, 'days').format('YYYY-MM-DD 23:59:59');
            }
        } else {
            // Si no hay fecha, extender desde hoy
            newExpire = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
        }
        
        // Actualizar en sistema
        const systemExpire = moment(newExpire).format('YYYY-MM-DD');
        await execPromise(`usermod -e ${systemExpire} ${username}`);
        
        // Actualizar en BD
        db.run(`UPDATE users SET expires_at = ? WHERE username = ?`, [newExpire, username]);
        
        logMessage(`✅ Renovado: ${username} por ${days} días, nueva expiración: ${newExpire}`);
        
        return { success: true, username, newExpire };
        
    } catch (error) {
        logMessage(`❌ Error renovar SSH: ${error.message}`);
        return { success: false, error: error.message };
    }
}

// ========== MERCADOPAGO ==========
async function createMercadoPagoPayment(phone, days, price, planName, username = null) {
    try {
        if (!config.mercadopago.access_token) {
            return { success: false, error: 'MercadoPago no configurado. Contacta al administrador.' };
        }
        
        const phoneClean = phone.replace('@c.us', '');
        const paymentId = `ssh-${phoneClean}-${Date.now()}`;
        
        logMessage(`🔄 Creando pago MP: ${paymentId} para ${phoneClean}`);
        
        const preferenceData = {
            items: [{
                title: username ? `RENOVACIÓN SSH ${planName}` : `SSH ${planName}`,
                description: username ? 
                    `Renovación de ${username} por ${days} días` : 
                    `Acceso SSH por ${days} días`,
                quantity: 1,
                currency_id: "ARS",
                unit_price: parseFloat(price)
            }],
            external_reference: paymentId,
            expires: true,
            expiration_date_from: moment().toISOString(),
            expiration_date_to: moment().add(24, 'hours').toISOString(),
            back_urls: {
                success: "https://www.mercadopago.com.ar",
                failure: "https://www.mercadopago.com.ar",
                pending: "https://www.mercadopago.com.ar"
            },
            auto_return: "approved"
        };
        
        const response = await axios.post(
            'https://api.mercadopago.com/checkout/preferences',
            preferenceData,
            {
                headers: {
                    'Authorization': `Bearer ${config.mercadopago.access_token}`,
                    'Content-Type': 'application/json'
                },
                timeout: 10000
            }
        );
        
        if (response.data && response.data.init_point) {
            const paymentUrl = response.data.init_point;
            const qrPath = path.join(__dirname, 'qr_codes', `${paymentId}.png`);
            
            try {
                await QRCode.toFile(qrPath, paymentUrl, { width: 400, margin: 2 });
                logMessage(`✅ QR generado: ${qrPath}`);
            } catch (qrError) {
                logMessage(`⚠️  Error QR: ${qrError.message}`);
            }
            
            // Guardar en BD
            db.run(
                `INSERT INTO payments (payment_id, phone, username, plan, days, amount, payment_url, qr_code) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
                [paymentId, phone, username, planName, days, price, paymentUrl, qrPath]
            );
            
            logMessage(`✅ Pago creado: ${paymentId} - $${price}`);
            
            return { 
                success: true, 
                paymentUrl, 
                qrPath,
                amount: price,
                paymentId
            };
        }
        
        return { success: false, error: 'Error en respuesta de MercadoPago' };
        
    } catch (error) {
        logMessage(`❌ Error MP: ${error.message}`);
        if (error.response) {
            logMessage(`Detalles: ${JSON.stringify(error.response.data)}`);
        }
        return { 
            success: false, 
            error: 'Error al conectar con MercadoPago. Verifica el token.' 
        };
    }
}

// ========== VERIFICAR PAGOS ==========
async function checkPendingPayments(client) {
    if (!config.mercadopago.access_token) return;
    
    try {
        const payments = await new Promise((resolve, reject) => {
            db.all('SELECT * FROM payments WHERE status = "pending"', (err, rows) => {
                if (err) reject(err);
                else resolve(rows || []);
            });
        });
        
        logMessage(`🔍 Verificando ${payments.length} pagos pendientes...`);
        
        for (const payment of payments) {
            try {
                const response = await axios.get(
                    `https://api.mercadopago.com/v1/payments/search?external_reference=${payment.payment_id}`,
                    {
                        headers: {
                            'Authorization': `Bearer ${config.mercadopago.access_token}`
                        },
                        timeout: 5000
                    }
                );
                
                if (response.data.results && response.data.results[0]?.status === 'approved') {
                    logMessage(`✅ Pago aprobado: ${payment.payment_id}`);
                    
                    // Actualizar estado del pago
                    db.run('UPDATE payments SET status = "approved" WHERE payment_id = ?', [payment.payment_id]);
                    
                    if (payment.username) {
                        // ES RENOVACIÓN
                        const result = await renewSSHUser(payment.username, payment.days);
                        
                        if (result.success) {
                            const msg = `✅ *RENOVACIÓN CONFIRMADA*

👤 Usuario: ${payment.username}
⏰ Nueva expiración: ${moment(result.newExpire).format('DD/MM/YYYY')}
🔑 Contraseña: ${config.bot.default_password}

¡Tu cuenta ha sido renovada exitosamente!`;
                            
                            await client.sendText(payment.phone, msg);
                            logMessage(`✅ Renovación exitosa para ${payment.username}`);
                        } else {
                            await client.sendText(payment.phone, `❌ Error en renovación: ${result.error}`);
                            logMessage(`❌ Error renovación ${payment.username}: ${result.error}`);
                        }
                        
                    } else {
                        // ES COMPRA NUEVA
                        const username = 'user' + Math.floor(1000 + Math.random() * 9000);
                        const result = await createSSHUser(payment.phone, username, payment.days);
                        
                        if (result.success) {
                            const msg = `✅ *PAGO CONFIRMADO*

👤 Usuario: ${username}
🔑 Contraseña: ${config.bot.default_password}
⏰ Expira: ${moment().add(payment.days, 'days').format('DD/MM/YYYY')}
📱 App: ${config.links.app_download}

¡Disfruta tu servicio premium!`;
                            
                            await client.sendText(payment.phone, msg);
                            logMessage(`✅ Creación exitosa para ${username}`);
                        } else {
                            await client.sendText(payment.phone, `❌ Error: ${result.error}`);
                            logMessage(`❌ Error creación ${username}: ${result.error}`);
                        }
                    }
                }
            } catch (error) {
                logMessage(`⚠️  Error verificando pago ${payment.payment_id}: ${error.message}`);
            }
        }
    } catch (error) {
        logMessage(`❌ Error en checkPendingPayments: ${error.message}`);
    }
}

// ========== LIMPIAR USUARIOS EXPIRADOS ==========
async function cleanExpiredUsers() {
    try {
        const now = moment().format('YYYY-MM-DD HH:mm:ss');
        
        const expiredUsers = await new Promise((resolve, reject) => {
            db.all('SELECT username FROM users WHERE expires_at < ? AND status = 1', [now], (err, rows) => {
                if (err) reject(err);
                else resolve(rows || []);
            });
        });
        
        for (const user of expiredUsers) {
            try {
                // Eliminar del sistema
                await execPromise(`pkill -u ${user.username} 2>/dev/null || true`);
                await execPromise(`deluser --remove-home ${user.username} 2>/dev/null || true`);
                
                // Actualizar en BD
                db.run('UPDATE users SET status = 0 WHERE username = ?', [user.username]);
                
                logMessage(`🧹 Usuario expirado eliminado: ${user.username}`);
            } catch (error) {
                logMessage(`⚠️  Error eliminando ${user.username}: ${error.message}`);
            }
        }
    } catch (error) {
        logMessage(`❌ Error en cleanExpiredUsers: ${error.message}`);
    }
}

// ========== INICIAR BOT ==========
async function startBot() {
    try {
        logMessage('🔗 Conectando WhatsApp...');
        
        const client = await wppconnect.create({
            session: 'sshbot',
            headless: true,
            useChrome: true,
            logQR: true,
            browserArgs: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-accelerated-2d-canvas',
                '--no-first-run',
                '--no-zygote',
                '--disable-gpu',
                '--disable-software-rasterizer',
                '--disable-features=site-per-process'
            ],
            puppeteerOptions: {
                executablePath: process.platform === 'linux' ? '/usr/bin/google-chrome' : undefined,
                headless: 'new',
                args: [
                    '--no-sandbox',
                    '--disable-setuid-sandbox'
                ]
            }
        });
        
        logMessage('✅ WhatsApp conectado!');
        
        // Manejar mensajes
        client.onMessage(async (message) => {
            try {
                const text = message.body.toLowerCase().trim();
                const from = message.from;
                
                if (from.includes('@g.us')) return;
                
                logMessage(`📩 ${from.replace('@c.us', '')}: ${text}`);
                
                const userState = await getState(from);
                
                // ===== MENÚ PRINCIPAL =====
                if (['menu', 'hola', 'start', 'hi', '0'].includes(text)) {
                    await setState(from, 'menu');
                    
                    const menu = `🚀 * BOT MGVPN*

1️⃣ *PRUEBA GRATIS* (1 hora)
2️⃣ *COMPRAR PLAN* 
3️⃣ *RENOVAR USUARIO*
4️⃣ *DESCARGAR APP*
5️⃣ *SOPORTE*

Escribe el número:`;
                    
                    await client.sendText(from, menu);
                    return;
                }
                
                // ===== OPCIÓN 1: PRUEBA =====
                if (text === '1' && userState.state === 'menu') {
                    await client.sendText(from, '⏳ Creando prueba...');
                    
                    const username = 'test' + Math.floor(1000 + Math.random() * 9000);
                    const result = await createSSHUser(from, username, 0);
                    
                    if (result.success) {
                        const msg = `✅ *PRUEBA CREADA*

👤 Usuario: ${username}
🔑 Contraseña: ${config.bot.default_password}
⏰ Expira: 1 hora
📱 App: ${config.links.app_download}

Instrucciones:
1. Descarga el APK 
2. Click "Más detalles"
3. Click "Instalar de todas formas"
4. Configura con tu usuario y contraseña`;
                        
                        await client.sendText(from, msg);
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    return;
                }
                
                // ===== OPCIÓN 2: COMPRAR =====
                if (text === '2' && userState.state === 'menu') {
                    await setState(from, 'buying');
                    
                    const menu = `🌐 *SELECCIONAR PLAN*

1️⃣ 7 DÍAS - $${config.prices.price_7d}
2️⃣ 15 DÍAS - $${config.prices.price_15d}
3️⃣ 30 DÍAS - $${config.prices.price_30d}
4️⃣ 50 DÍAS - $${config.prices.price_50d}

0️⃣ Volver`;
                    
                    await client.sendText(from, menu);
                    return;
                }
                
                // ===== OPCIÓN 3: RENOVAR =====
                if (text === '3' && userState.state === 'menu') {
                    // Buscar usuarios del cliente
                    const users = await new Promise((resolve, reject) => {
                        db.all('SELECT username, expires_at FROM users WHERE phone = ? AND status = 1 ORDER BY expires_at DESC', 
                            [from], (err, rows) => {
                            if (err) reject(err);
                            else resolve(rows || []);
                        });
                    });
                    
                    if (users.length === 0) {
                        await client.sendText(from, `❌ *NO TIENES USUARIOS ACTIVOS*

Para crear uno nuevo, selecciona:
2️⃣ COMPRAR PLAN`);
                        return;
                    }
                    
                    let userList = `🔄 *TUS USUARIOS ACTIVOS*\n\n`;
                    users.forEach((user, index) => {
                        const expireDate = moment(user.expires_at).format('DD/MM/YYYY');
                        const daysLeft = moment(user.expires_at).diff(moment(), 'days');
                        userList += `${index + 1}. 👤 *${user.username}* - ⏰ Expira: ${expireDate} (${daysLeft}d restantes)\n`;
                    });
                    
                    userList += `\nPara renovar, escribe:\n*renovar [usuario]*\n\nEjemplo: renovar ${users[0].username}`;
                    
                    await client.sendText(from, userList);
                    return;
                }
                
                // ===== COMANDO RENOVAR =====
                if (text.startsWith('renovar ') && userState.state === 'menu') {
                    const username = text.replace('renovar ', '').trim();
                    
                    // Verificar que el usuario pertenece al cliente
                    const user = await new Promise((resolve, reject) => {
                        db.get('SELECT username FROM users WHERE username = ? AND phone = ? AND status = 1', 
                            [username, from], (err, row) => {
                            if (err) reject(err);
                            else resolve(row);
                        });
                    });
                    
                    if (!user) {
                        await client.sendText(from, `❌ *USUARIO NO ENCONTRADO*

Verifica que:
1. El nombre sea correcto
2. El usuario te pertenezca
3. El usuario no haya expirado

Para ver tus usuarios activos, escribe *menu*`);
                        return;
                    }
                    
                    await setState(from, 'renewing', { username });
                    
                    const menu = `🔄 *RENOVAR: ${username}*

Selecciona el plan:

1️⃣ 7 DÍAS - $${config.prices.price_7d}
2️⃣ 15 DÍAS - $${config.prices.price_15d}
3️⃣ 30 DÍAS - $${config.prices.price_30d}
4️⃣ 50 DÍAS - $${config.prices.price_50d}

0️⃣ Cancelar`;
                    
                    await client.sendText(from, menu);
                    return;
                }
                
                // ===== RENOVACIÓN - SELECCIONAR PLAN =====
                if (userState.state === 'renewing') {
                    const plans = {
                        '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                        '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' },
                        '3': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                        '4': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                    };
                    
                    if (plans[text]) {
                        const plan = plans[text];
                        const username = userState.data.username;
                        
                        if (!config.mercadopago.access_token) {
                            await client.sendText(from, `⚠️ *MERCADOPAGO NO CONFIGURADO*

Contacta al administrador para configurar el sistema de pagos.`);
                            await setState(from, 'menu');
                            return;
                        }
                        
                        await client.sendText(from, `⏳ Generando pago de renovación para ${username}...`);
                        
                        const payment = await createMercadoPagoPayment(
                            from, 
                            plan.days, 
                            plan.price, 
                            plan.name,
                            username
                        );
                        
                        if (payment.success) {
                            const msg = `💳 *RENOVACIÓN ${plan.name}*

👤 Usuario: ${username}
💰 Monto: $${payment.amount}
⏰ Días adicionales: ${plan.days}

✅ *Enlace de pago:*
${payment.paymentUrl}

📱 *Escanea el QR que se enviará a continuación*`;
                            
                            await client.sendText(from, msg);
                            
                            if (fs.existsSync(payment.qrPath)) {
                                try {
                                    await client.sendImage(
                                        from,
                                        payment.qrPath,
                                        'qr-pago.jpg',
                                        `Renovación: ${username}\n${plan.name} - $${payment.amount}`
                                    );
                                } catch (qrError) {
                                    logMessage(`⚠️  Error enviando QR: ${qrError.message}`);
                                }
                            }
                            
                        } else {
                            await client.sendText(from, `❌ *ERROR AL GENERAR PAGO*

${payment.error}`);
                        }
                        
                        await setState(from, 'menu');
                        return;
                    }
                    
                    if (text === '0') {
                        await setState(from, 'menu');
                        await client.sendText(from, '✅ Renovación cancelada. Escribe *menu* para ver opciones.');
                        return;
                    }
                }
                
                // ===== COMPRA - SELECCIONAR PLAN =====
                if (userState.state === 'buying') {
                    const plans = {
                        '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                        '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' },
                        '3': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                        '4': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                    };
                    
                    if (plans[text]) {
                        const plan = plans[text];
                        
                        if (!config.mercadopago.access_token) {
                            await client.sendText(from, `⚠️ *MERCADOPAGO NO CONFIGURADO*

Contacta al administrador para configurar.`);
                            await setState(from, 'menu');
                            return;
                        }
                        
                        await client.sendText(from, `⏳ Generando pago para ${plan.name}...`);
                        
                        const payment = await createMercadoPagoPayment(
                            from, 
                            plan.days, 
                            plan.price, 
                            plan.name
                        );
                        
                        if (payment.success) {
                            const msg = `💳 *PAGO ${plan.name}*

💰 Monto: $${payment.amount}
⏰ Duración: ${plan.days} días

✅ *Enlace de pago:*
${payment.paymentUrl}

📱 *Escanea el QR que se enviará a continuación*`;
                            
                            await client.sendText(from, msg);
                            
                            if (fs.existsSync(payment.qrPath)) {
                                try {
                                    await client.sendImage(
                                        from,
                                        payment.qrPath,
                                        'qr-pago.jpg',
                                        `${plan.name} - $${payment.amount}`
                                    );
                                } catch (qrError) {
                                    logMessage(`⚠️  Error enviando QR: ${qrError.message}`);
                                }
                            }
                            
                        } else {
                            await client.sendText(from, `❌ *ERROR AL GENERAR PAGO*

${payment.error}`);
                        }
                        
                        await setState(from, 'menu');
                        return;
                    }
                    
                    if (text === '0') {
                        await setState(from, 'menu');
                        await client.sendText(from, '✅ Compra cancelada. Escribe *menu* para ver opciones.');
                        return;
                    }
                }
                
                // ===== OPCIÓN 4: APP =====
                if (text === '4' && userState.state === 'menu') {
                    const msg = `📱 *DESCARGAR APP*

🔗 ${config.links.app_download}

Instrucciones:
1. Descarga el APK
2. Click "Más detalles"
3. Click "Instalar de todas formas"
4. Configura con tus credenciales`;
                    
                    await client.sendText(from, msg);
                    return;
                }
                
                // ===== OPCIÓN 5: SOPORTE =====
                if (text === '5' && userState.state === 'menu') {
                    await client.sendText(from, `📞 *SOPORTE*

Para ayuda contacta:
https://wa.me/543435071016`);
                    return;
                }
                
                // ===== MENSAJE NO RECONOCIDO =====
                if (userState.state === 'menu') {
                    await client.sendText(from, '⚠️ Escribe *menu* para ver las opciones disponibles');
                } else {
                    await client.sendText(from, '⚠️ Opción no válida. Escribe *0* para volver al menú principal');
                }
                
            } catch (error) {
                logMessage(`❌ Error procesando mensaje: ${error.message}`);
            }
        });
        
        // Verificar pagos cada 1 minuto
        setInterval(() => {
            checkPendingPayments(client);
        }, 60000);
        
        // Limpiar estados antiguos cada 30 minutos
        setInterval(() => {
            const hourAgo = moment().subtract(1, 'hour').format('YYYY-MM-DD HH:mm:ss');
            db.run("DELETE FROM user_states WHERE updated_at < ?", [hourAgo]);
        }, 1800000);
        
        // Limpiar usuarios expirados cada hora
        setInterval(() => {
            cleanExpiredUsers();
        }, 3600000);
        
        logMessage('✅ Bot listo y funcionando!');
        
        // Función de reconexión automática
        client.onStateChange((state) => {
            logMessage(`📡 Estado WhatsApp: ${state}`);
            
            if (state === 'UNPAIRED' || state === 'DISCONNECTED') {
                logMessage('⚠️  WhatsApp desconectado, intentando reconectar...');
                setTimeout(() => {
                    process.exit(1); // PM2 reiniciará automáticamente
                }, 5000);
            }
        });
        
    } catch (error) {
        logMessage(`❌ Error crítico: ${error.message}`);
        logMessage(`Stack: ${error.stack}`);
        
        // Esperar 10 segundos antes de reintentar
        setTimeout(() => {
            logMessage('🔄 Reiniciando bot...');
            process.exit(1);
        }, 10000);
    }
}

// Iniciar bot
startBot();

// Manejar señales de cierre
process.on('SIGINT', () => {
    logMessage('🛑 Cerrando bot...');
    process.exit(0);
});

process.on('SIGTERM', () => {
    logMessage('🛑 Terminando bot...');
    process.exit(0);
});

process.on('uncaughtException', (error) => {
    logMessage(`❌ Error no manejado: ${error.message}`);
    logMessage(`Stack: ${error.stack}`);
});
BOTEOF

echo -e "${GREEN}✅ Bot creado con mejoras para Ubuntu${NC}"

# ================================================
# CREAR PANEL DE CONTROL MEJORADO
# ================================================
echo -e "\n${CYAN}🎛️  Creando panel de control mejorado...${NC}"

cat > /usr/local/bin/sshbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/root/sshbot"
CONFIG="$INSTALL_DIR/config.json"
DB="$INSTALL_DIR/data/users.db"
LOG_FILE="$INSTALL_DIR/bot.log"

get_val() {
    jq -r "$1" "$CONFIG" 2>/dev/null || echo ""
}

set_val() {
    local temp=$(mktemp)
    jq "$1 = $2" "$CONFIG" > "$temp" && mv "$temp" "$CONFIG"
}

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                🎛️  CONTROL SSH BOT - UBUNTU               ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

# Verificar instalación
check_install() {
    if [[ ! -d "$INSTALL_DIR" ]]; then
        echo -e "${RED}❌ El bot no está instalado${NC}"
        exit 1
    fi
}

while true; do
    show_header
    check_install
    
    # Estado del bot
    BOT_STATUS=$(pm2 info sshbot 2>/dev/null | grep "status" | awk '{print $4}' || echo "stopped")
    if [[ "$BOT_STATUS" == "online" ]]; then
        STATUS="${GREEN}● ACTIVO${NC}"
    else
        STATUS="${RED}● DETENIDO${NC}"
    fi
    
    # Estado MP
    MP_TOKEN=$(get_val '.mercadopago.access_token')
    if [[ -n "$MP_TOKEN" && "$MP_TOKEN" != "null" && "$MP_TOKEN" != "" ]]; then
        MP_STATUS="${GREEN}✅ CONFIGURADO${NC}"
    else
        MP_STATUS="${RED}❌ NO CONFIGURADO${NC}"
    fi
    
    # Usuarios activos
    ACTIVE_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1" 2>/dev/null || echo "0")
    
    echo -e "${YELLOW}📊 ESTADO DEL BOT:${NC} $STATUS"
    echo -e "${YELLOW}💰 MERCADOPAGO:${NC} $MP_STATUS"
    echo -e "${YELLOW}👥 USUARIOS ACTIVOS:${NC} $ACTIVE_USERS"
    echo -e "${YELLOW}📱 IP SERVER:${NC} $(get_val '.bot.server_ip')"
    echo -e ""
    
    echo -e "${CYAN}[1]${NC} 🚀 Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC} 🛑 Detener bot"
    echo -e "${CYAN}[3]${NC} 📱 Ver logs y QR"
    echo -e "${CYAN}[4]${NC} 📋 Ver logs de errores"
    echo -e "${CYAN}[5]${NC} 👤 Crear usuario manual"
    echo -e "${CYAN}[6]${NC} 👥 Listar usuarios"
    echo -e "${CYAN}[7]${NC} 🔑 Configurar MercadoPago"
    echo -e "${CYAN}[8]${NC} 💰 Cambiar precios"
    echo -e "${CYAN}[9]${NC} 🔄 Renovar usuario manual"
    echo -e "${CYAN}[10]${NC} 🧹 Limpiar sesión WhatsApp"
    echo -e "${CYAN}[11]${NC} 🔍 Ver pagos pendientes"
    echo -e "${CYAN}[12]${NC} 🛠️  Verificar instalación"
    echo -e "${CYAN}[0]${NC} 🚪 Salir"
    echo -e ""
    
    read -p "👉 Opción: " OPT
    
    case $OPT in
        1)
            echo -e "\n${YELLOW}🔄 Iniciando bot...${NC}"
            cd "$INSTALL_DIR"
            
            # Verificar si ya existe
            if pm2 list | grep -q sshbot; then
                pm2 restart sshbot --update-env
            else
                pm2 start bot.js --name sshbot
            fi
            
            pm2 save --force
            echo -e "${GREEN}✅ Bot iniciado/reiniciado${NC}"
            echo -e "${YELLOW}📱 Espera el QR en los logs${NC}"
            sleep 3
            ;;
        2)
            echo -e "\n${YELLOW}🛑 Deteniendo bot...${NC}"
            pm2 stop sshbot 2>/dev/null
            echo -e "${GREEN}✅ Bot detenido${NC}"
            sleep 2
            ;;
        3)
            echo -e "\n${YELLOW}📱 Mostrando logs...${NC}"
            echo -e "${CYAN}Presiona Ctrl+C para volver al menú${NC}\n"
            pm2 logs sshbot --lines 100 --raw
            ;;
        4)
            echo -e "\n${YELLOW}📋 Mostrando errores...${NC}"
            if [[ -f "$LOG_FILE" ]]; then
                echo -e "${CYAN}Últimos errores:${NC}\n"
                tail -100 "$LOG_FILE" | grep -i "error\|failed\|❌\|⚠️" || echo "No hay errores recientes"
            else
                echo -e "${RED}❌ Archivo de log no encontrado${NC}"
            fi
            echo -e "\n${CYAN}Presiona Enter para continuar...${NC}"
            read
            ;;
        5)
            echo -e "\n${CYAN}👤 CREAR USUARIO MANUAL${NC}"
            read -p "Teléfono (ej: 5493412345678): " PHONE
            read -p "Tipo (test/premium): " TIPO
            read -p "Días (0=test, >0=premium): " DAYS
            
            if [[ ! "$PHONE" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}❌ Teléfono inválido${NC}"
                read -p "Enter..."
                continue
            fi
            
            if [[ "$TIPO" == "test" ]]; then
                DAYS=0
                USERNAME="test$(shuf -i 1000-9999 -n 1)"
                EXPIRE=$(date -d "+1 hour" +"%Y-%m-%d %H:%M:%S")
                echo -e "${YELLOW}Creando test...${NC}"
                
                # Crear en sistema
                useradd -m -s /bin/bash "$USERNAME" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    echo "$USERNAME:mgvpn247" | chpasswd
                    echo -e "${GREEN}✅ Usuario creado en sistema${NC}"
                else
                    echo -e "${RED}❌ Error creando usuario en sistema${NC}"
                fi
            else
                USERNAME="user$(shuf -i 1000-9999 -n 1)"
                EXPIRE=$(date -d "+$DAYS days" +"%Y-%m-%d 23:59:59")
                echo -e "${YELLOW}Creando premium...${NC}"
                
                # Crear en sistema
                useradd -M -s /bin/false -e "$(date -d "+$DAYS days" +%Y-%m-%d)" "$USERNAME" 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    echo "$USERNAME:mgvpn247" | chpasswd
                    echo -e "${GREEN}✅ Usuario creado en sistema${NC}"
                else
                    echo -e "${RED}❌ Error creando usuario en sistema${NC}"
                fi
            fi
            
            # Guardar en BD
            sqlite3 "$DB" "INSERT INTO users (phone, username, password, tipo, expires_at) VALUES ('$PHONE', '$USERNAME', 'mgvpn247', '$TIPO', '$EXPIRE')" 2>/dev/null
            
            echo -e "\n${GREEN}✅ USUARIO CREADO${NC}"
            echo -e "👤 Usuario: $USERNAME"
            echo -e "🔑 Contraseña: mgvpn247"
            echo -e "⏰ Expira: $EXPIRE"
            echo -e "📞 Teléfono: $PHONE"
            echo -e ""
            read -p "Enter..."
            ;;
        6)
            echo -e "\n${CYAN}👥 LISTA DE USUARIOS${NC}"
            echo -e "${YELLOW}Total activos: $ACTIVE_USERS${NC}\n"
            
            if [[ "$ACTIVE_USERS" -gt 0 ]]; then
                sqlite3 -column -header "$DB" <<< "SELECT username, phone, tipo, expires_at FROM users WHERE status=1 ORDER BY expires_at DESC"
            else
                echo -e "${YELLOW}No hay usuarios activos${NC}"
            fi
            
            echo -e ""
            read -p "Enter..."
            ;;
        7)
            echo -e "\n${CYAN}🔑 CONFIGURAR MERCADOPAGO${NC}"
            echo -e "${YELLOW}Pasos para obtener el token:${NC}"
            echo -e "1. Ve a https://www.mercadopago.com.ar/developers"
            echo -e "2. Inicia sesión con tu cuenta"
            echo -e "3. Haz clic en 'Tus credenciales'"
            echo -e "4. Copia 'Access Token PRODUCCIÓN'"
            echo -e ""
            
            CURRENT=$(get_val '.mercadopago.access_token')
            if [[ -n "$CURRENT" && "$CURRENT" != "null" && "$CURRENT" != "" ]]; then
                echo -e "${GREEN}✅ Token actual configurado${NC}"
                echo -e "Primeros 10 caracteres: ${CURRENT:0:10}..."
                echo -e ""
                read -p "¿Cambiar token? (s/N): " CHANGE
                if [[ ! "$CHANGE" =~ ^[Ss]$ ]]; then
                    continue
                fi
            fi
            
            read -p "Nuevo token de MercadoPago: " TOKEN
            if [[ -n "$TOKEN" ]]; then
                set_val '.mercadopago.access_token' "\"$TOKEN\""
                set_val '.mercadopago.enabled' "true"
                echo -e "${GREEN}✅ Token guardado correctamente${NC}"
                
                # Reiniciar bot para aplicar cambios
                read -p "¿Reiniciar bot para aplicar cambios? (s/N): " RESTART
                if [[ "$RESTART" =~ ^[Ss]$ ]]; then
                    pm2 restart sshbot 2>/dev/null
                    echo -e "${GREEN}✅ Bot reiniciado${NC}"
                fi
            else
                echo -e "${YELLOW}⚠️  Token no cambiado${NC}"
            fi
            
            read -p "Enter..."
            ;;
        8)
            echo -e "\n${CYAN}💰 CAMBIAR PRECIOS${NC}"
            
            CURRENT_7D=$(get_val '.prices.price_7d')
            CURRENT_15D=$(get_val '.prices.price_15d')
            CURRENT_30D=$(get_val '.prices.price_30d')
            CURRENT_50D=$(get_val '.prices.price_50d')
            
            echo -e "${YELLOW}Precios actuales:${NC}"
            echo -e "  7 días: $${CURRENT_7D}"
            echo -e "  15 días: $${CURRENT_15D}"
            echo -e "  30 días: $${CURRENT_30D}"
            echo -e "  50 días: $${CURRENT_50D}"
            echo -e ""
            
            read -p "Nuevo precio 7 días: " NEW_7D
            read -p "Nuevo precio 15 días: " NEW_15D
            read -p "Nuevo precio 30 días: " NEW_30D
            read -p "Nuevo precio 50 días: " NEW_50D
            
            [[ -n "$NEW_7D" ]] && set_val '.prices.price_7d' "$NEW_7D"
            [[ -n "$NEW_15D" ]] && set_val '.prices.price_15d' "$NEW_15D"
            [[ -n "$NEW_30D" ]] && set_val '.prices.price_30d' "$NEW_30D"
            [[ -n "$NEW_50D" ]] && set_val '.prices.price_50d' "$NEW_50D"
            
            echo -e "${GREEN}✅ Precios actualizados${NC}"
            read -p "Enter..."
            ;;
        9)
            echo -e "\n${CYAN}🔄 RENOVAR USUARIO MANUAL${NC}"
            read -p "Nombre de usuario: " USERNAME
            
            # Verificar que el usuario existe
            if ! id "$USERNAME" &>/dev/null; then
                echo -e "${RED}❌ Usuario no existe en el sistema${NC}"
                read -p "Enter..."
                continue
            fi
            
            read -p "Días adicionales: " DAYS
            
            if [[ ! "$DAYS" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}❌ Días inválidos${NC}"
                read -p "Enter..."
                continue
            fi
            
            # Extender fecha
            CURRENT_EXPIRE=$(chage -l "$USERNAME" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
            
            if [[ "$CURRENT_EXPIRE" == "never" ]]; then
                NEW_EXPIRE=$(date -d "+$DAYS days" +%Y-%m-%d)
            else
                CURRENT_DATE=$(date -d "$CURRENT_EXPIRE" +%Y-%m-%d 2>/dev/null || date -d "+$DAYS days" +%Y-%m-%d)
                NEW_EXPIRE=$(date -d "$CURRENT_DATE + $DAYS days" +%Y-%m-%d)
            fi
            
            # Actualizar en sistema
            usermod -e "$NEW_EXPIRE" "$USERNAME" 2>/dev/null
            
            if [[ $? -eq 0 ]]; then
                # Actualizar en BD
                NEW_EXPIRE_FULL="${NEW_EXPIRE} 23:59:59"
                sqlite3 "$DB" "UPDATE users SET expires_at = '$NEW_EXPIRE_FULL' WHERE username = '$USERNAME'" 2>/dev/null
                
                echo -e "${GREEN}✅ USUARIO RENOVADO${NC}"
                echo -e "👤 Usuario: $USERNAME"
                echo -e "⏰ Nueva expiración: $NEW_EXPIRE"
            else
                echo -e "${RED}❌ Error al renovar usuario${NC}"
            fi
            
            read -p "Enter..."
            ;;
        10)
            echo -e "\n${YELLOW}🧹 Limpiando sesión WhatsApp...${NC}"
            pm2 stop sshbot 2>/dev/null
            rm -rf /root/.wppconnect/* 2>/dev/null
            echo -e "${GREEN}✅ Sesión limpiada${NC}"
            echo -e "${YELLOW}📱 Debes escanear nuevo QR al iniciar${NC}"
            sleep 2
            ;;
        11)
            echo -e "\n${CYAN}🔍 PAGOS PENDIENTES${NC}"
            echo -e "${YELLOW}Últimos 20 pagos:${NC}\n"
            
            sqlite3 -column -header "$DB" <<< "SELECT payment_id, phone, username, plan, amount, status, created_at FROM payments ORDER BY created_at DESC LIMIT 20"
            
            PENDING=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='pending'" 2>/dev/null || echo "0")
            echo -e "\n${YELLOW}Pagos pendientes: $PENDING${NC}"
            
            read -p "Enter..."
            ;;
        12)
            echo -e "\n${CYAN}🛠️  VERIFICAR INSTALACIÓN${NC}"
            
            echo -e "${YELLOW}Componentes:${NC}"
            
            # Node.js
            if command -v node &>/dev/null; then
                echo -e "✅ Node.js: $(node --version)"
            else
                echo -e "❌ Node.js: No instalado"
            fi
            
            # Chrome
            if command -v google-chrome &>/dev/null; then
                echo -e "✅ Chrome: $(google-chrome --version | head -1)"
            else
                echo -e "❌ Chrome: No instalado"
            fi
            
            # PM2
            if command -v pm2 &>/dev/null; then
                echo -e "✅ PM2: Instalado"
            else
                echo -e "❌ PM2: No instalado"
            fi
            
            # Directorios
            echo -e "\n${YELLOW}Directorios:${NC}"
            [[ -d "$INSTALL_DIR" ]] && echo -e "✅ Instalación: $INSTALL_DIR" || echo -e "❌ Instalación: No existe"
            [[ -d "$INSTALL_DIR/qr_codes" ]] && echo -e "✅ QR Codes: $INSTALL_DIR/qr_codes" || echo -e "❌ QR Codes: No existe"
            [[ -f "$INSTALL_DIR/config.json" ]] && echo -e "✅ Configuración: $INSTALL_DIR/config.json" || echo -e "❌ Configuración: No existe"
            [[ -f "$INSTALL_DIR/data/users.db" ]] && echo -e "✅ Base de datos: $INSTALL_DIR/data/users.db" || echo -e "❌ Base de datos: No existe"
            
            # Bot status
            echo -e "\n${YELLOW}Estado del bot:${NC}"
            if pm2 list | grep -q sshbot; then
                echo -e "✅ Bot en PM2: $(pm2 jlist | jq -r '.[] | select(.name=="sshbot") | .status')"
            else
                echo -e "❌ Bot en PM2: No registrado"
            fi
            
            read -p "Enter..."
            ;;
        0)
            echo -e "\n${GREEN}👋 Hasta luego${NC}"
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

# Crear script de limpieza
cat > /usr/local/bin/clean-sshbot << 'CLEANEOF'
#!/bin/bash
echo "🧹 Limpiando SSH Bot..."
pm2 stop sshbot 2>/dev/null
pm2 delete sshbot 2>/dev/null
rm -rf /root/.wppconnect/*
rm -rf /root/sshbot/qr_codes/*.png
echo "✅ Limpieza completada"
CLEANEOF

chmod +x /usr/local/bin/clean-sshbot

echo -e "${GREEN}✅ Panel y utilidades creados${NC}"

# ================================================
# CONFIGURAR PM2 PARA AUTOINICIO
# ================================================
echo -e "\n${CYAN}⚙️  Configurando autoinicio...${NC}"

pm2 startup systemd -u root --hp /root
pm2 save --force

# Crear servicio systemd alternativo
cat > /etc/systemd/system/sshbot.service << 'SERVICEEOF'
[Unit]
Description=SSH Bot WhatsApp
After=network.target

[Service]
Type=exec
User=root
WorkingDirectory=/root/sshbot
ExecStart=/usr/bin/pm2 start /root/sshbot/bot.js --name sshbot
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable sshbot.service 2>/dev/null || true

echo -e "${GREEN}✅ Autoinicio configurado${NC}"

# ================================================
# INICIAR BOT
# ================================================
echo -e "\n${CYAN}🚀 Iniciando bot...${NC}"

cd "$INSTALL_DIR"
pm2 start bot.js --name sshbot
pm2 save --force

sleep 3

# ================================================
# MENSAJE FINAL
# ================================================
clear
echo -e "${GREEN}${BOLD}"
cat << "FINAL"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║       ✅ SSH BOT PRO - INSTALACIÓN COMPLETADA              ║
║           🚀 COMPATIBLE CON UBUNTU 20/22                   ║
║           🔥 RENOVACIÓN + MERCADOPAGO                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}📦 PAQUETES INSTALADOS:${NC}"
echo -e "  ✅ Node.js 18.x"
echo -e "  ✅ Google Chrome"
echo -e "  ✅ PM2 (Gestor de procesos)"
echo -e "  ✅ SQLite3 (Base de datos)"
echo -e "  ✅ Todas las dependencias necesarias"
echo -e ""
echo -e "${GREEN}🚀 CARACTERÍSTICAS:${NC}"
echo -e "  1️⃣  Prueba gratis (1 hora)"
echo -e "  2️⃣  Comprar plan (4 opciones)"
echo -e "  3️⃣  🔥 RENOVAR USUARIO EXISTENTE"
echo -e "  4️⃣  Descargar aplicación"
echo -e "  5️⃣  Soporte"
echo -e ""
echo -e "${GREEN}⚙️  CONFIGURACIÓN AVANZADA:${NC}"
echo -e "  ✅ Estados persistentes"
echo -e "  ✅ MercadoPago integrado"
echo -e "  ✅ Verificación automática de pagos"
echo -e "  ✅ Limpieza automática de usuarios expirados"
echo -e "  ✅ Reconexión automática"
echo -e "  ✅ Logs detallados"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 CÓMO USAR LA RENOVACIÓN:${NC}"
echo -e "1. Escribe *menu* al bot"
echo -e "2. Selecciona *3 - RENOVAR USUARIO*"
echo -e "3. Verás tu lista de usuarios activos"
echo -e "4. Escribe *renovar [usuario]*"
echo -e "5. Selecciona el plan de renovación"
echo -e "6. Recibirás link de pago MP y QR"
echo -e "7. Al pagar, se renueva AUTOMÁTICAMENTE"
echo -e ""
echo -e "${YELLOW}🔧 CONFIGURAR MERCADOPAGO:${NC}"
echo -e "1. Ejecuta: ${GREEN}sshbot${NC}"
echo -e "2. Selecciona opción 7"
echo -e "3. Ingresa tu token de producción"
echo -e "4. Reinicia el bot"
echo -e ""
echo -e "${YELLOW}⚡ COMANDOS PRINCIPALES:${NC}"
echo -e "  ${GREEN}sshbot${NC}          - Panel de control completo"
echo -e "  ${GREEN}pm2 logs sshbot${NC} - Ver logs y escanear QR"
echo -e "  ${GREEN}pm2 status${NC}      - Ver estado del bot"
echo -e "  ${GREEN}clean-sshbot${NC}    - Limpiar sesión WhatsApp"
echo -e "  ${GREEN}systemctl status sshbot${NC} - Ver servicio"
echo -e ""
echo -e "${YELLOW}🔍 SOLUCIÓN DE PROBLEMAS:${NC}"
echo -e "Si el bot no inicia:"
echo -e "  1. Verifica logs: ${GREEN}pm2 logs sshbot${NC}"
echo -e "  2. Limpia sesión: ${GREEN}clean-sshbot${NC}"
echo -e "  3. Reinstala dependencias:"
echo -e "     ${GREEN}cd /root/sshbot && npm install${NC}"
echo -e "  4. Revisa Chrome: ${GREEN}google-chrome --version${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${GREEN}${BOLD}¡Instalación completada exitosamente! 🎉${NC}\n"
echo -e "${YELLOW}📱 Ahora debes escanear el código QR de WhatsApp${NC}"
echo -e ""

read -p "$(echo -e "${YELLOW}¿Ver logs y escanear QR ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}📱 Espera el código QR...${NC}"
    echo -e "${YELLOW}Presiona Ctrl+C para detener los logs${NC}\n"
    sleep 2
    pm2 logs sshbot
else
    echo -e "\n${YELLOW}Para ver el QR después, ejecuta:${NC} ${GREEN}pm2 logs sshbot${NC}"
fi

echo -e "\n${GREEN}✅ Instalación finalizada. ¡Bot listo!${NC}\n"
exit 0