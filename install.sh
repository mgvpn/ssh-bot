#!/bin/bash
# ================================================
# SSH BOT PRO - INSTALADOR COMPLETO CON SOLUCIÓN NODE.JS
# Versión completa con planes separados, notificaciones, MercadoPago
# CON ENVÍO DE APK POR ARCHIVO
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

# Banner inicial
clear
echo -e "${CYAN}${BOLD}"
cat << "BANNER"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║                SSH BOT PRO - INSTALADOR COMPLETO            ║
║               CON SOLUCIÓN PARA NODE.JS                     ║
║               📅 PLANES SEPARADOS                          ║
║               📢 NOTIFICACIONES                            ║
║               💰 MERCADOPAGO                               ║
║               📱 APK POR ARCHIVO                           ║
║               🚫 SIN CUPONES                               ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ VERSIÓN COMPLETA CON:${NC}"
echo -e "  📅 Planes DIARIOS: 7, 15 días"
echo -e "  📅 Planes MENSUALES: 30, 50 días"
echo -e "  ⏰ Test gratuito: 2 horas"
echo -e "  🔐 Contraseña fija: mgvpn247"
echo -e "  📢 Sistema de notificaciones"
echo -e "  💰 MercadoPago integrado"
echo -e "  📱 APK enviada como archivo"
echo -e "  🚫 Sin cupones de descuento"
echo -e "  🎛️ Panel de control completo"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}${BOLD}❌ ERROR: Debes ejecutar como root${NC}"
    echo -e "${YELLOW}Usa: sudo bash $0${NC}"
    exit 1
fi

# ================================================
# FUNCIÓN PARA SOLUCIONAR NODE.JS
# ================================================
fix_nodejs() {
    echo -e "${CYAN}${BOLD}🔧 SOLUCIONANDO PROBLEMA DE NODE.JS...${NC}"
    
    # 1. Detener procesos de Node.js
    echo -e "${YELLOW}🛑 Deteniendo procesos Node.js...${NC}"
    pkill -f node 2>/dev/null || true
    pm2 delete all 2>/dev/null || true
    
    # 2. Remover Node.js existente
    echo -e "${YELLOW}🗑️  Removiendo Node.js anterior...${NC}"
    apt-get remove --purge -y nodejs npm node 2>/dev/null || true
    apt-get autoremove -y
    
    # 3. Limpiar archivos conflictivos
    echo -e "${YELLOW}🧹 Limpiando archivos conflictivos...${NC}"
    rm -rf /usr/include/node 2>/dev/null || true
    rm -rf /usr/lib/node_modules 2>/dev/null || true
    rm -rf /usr/local/lib/node_modules 2>/dev/null || true
    rm -rf /opt/nodejs 2>/dev/null || true
    
    # Eliminar binarios
    rm -f /usr/bin/node /usr/bin/npm /usr/bin/npx 2>/dev/null || true
    rm -f /usr/local/bin/node /usr/local/bin/npm /usr/local/bin/npx 2>/dev/null || true
    rm -f /usr/sbin/node /usr/sbin/npm /usr/sbin/npx 2>/dev/null || true
    
    # 4. Reparar sistema de paquetes
    echo -e "${YELLOW}🔧 Reparando paquetes rotos...${NC}"
    dpkg --configure -a
    apt-get update -y
    apt-get install -f -y
    
    # 5. Instalar Node.js 20.x usando binary directo (MÉTODO SEGURO)
    echo -e "${YELLOW}🚀 Instalando Node.js 20.x desde binary...${NC}"
    
    NODE_VERSION="20.20.0"
    
    # Verificar arquitectura
    ARCH=$(uname -m)
    if [[ "$ARCH" == "x86_64" ]]; then
        ARCH="linux-x64"
    elif [[ "$ARCH" == "aarch64" ]]; then
        ARCH="linux-arm64"
    else
        ARCH="linux-x64"
    fi
    
    cd /tmp
    rm -rf node-* 2>/dev/null || true
    
    echo -e "${CYAN}📥 Descargando Node.js v${NODE_VERSION} para ${ARCH}...${NC}"
    wget -q --show-progress "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-${ARCH}.tar.xz" || \
    wget -q "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-${ARCH}.tar.xz"
    
    if [ ! -f "node-v${NODE_VERSION}-${ARCH}.tar.xz" ]; then
        echo -e "${RED}❌ Error descargando Node.js${NC}"
        echo -e "${YELLOW}Intentando con curl...${NC}"
        curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-${ARCH}.tar.xz" -o "node-v${NODE_VERSION}-${ARCH}.tar.xz"
    fi
    
    if [ -f "node-v${NODE_VERSION}-${ARCH}.tar.xz" ]; then
        echo -e "${CYAN}📦 Extrayendo...${NC}"
        tar -xf "node-v${NODE_VERSION}-${ARCH}.tar.xz"
        
        echo -e "${CYAN}📁 Instalando en /usr/local...${NC}"
        cd "node-v${NODE_VERSION}-${ARCH}"
        cp -R bin include lib share /usr/local/
        
        # Crear enlaces simbólicos
        ln -sf /usr/local/bin/node /usr/bin/node 2>/dev/null || true
        ln -sf /usr/local/bin/npm /usr/bin/npm 2>/dev/null || true
        ln -sf /usr/local/bin/npx /usr/bin/npx 2>/dev/null || true
        
        # Agregar a PATH si no está
        if [[ ":$PATH:" != *":/usr/local/bin:"* ]]; then
            echo 'export PATH="/usr/local/bin:$PATH"' >> /root/.bashrc
            source /root/.bashrc
        fi
    else
        echo -e "${RED}❌ No se pudo descargar Node.js${NC}"
        echo -e "${YELLOW}Intentando método alternativo con Nodesource...${NC}"
        
        # Método alternativo usando Nodesource con forzar
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash - --force
        apt-get install -y nodejs --fix-broken --allow-downgrades --allow-remove-essential --allow-change-held-packages
    fi
    
    # 6. Verificar instalación
    echo -e "${CYAN}✅ Verificando instalación...${NC}"
    
    if command -v node &> /dev/null; then
        NODE_VER=$(node --version 2>/dev/null || echo "Desconocido")
        NPM_VER=$(npm --version 2>/dev/null || echo "Desconocido")
        echo -e "${GREEN}✅ Node.js ${NODE_VER} instalado correctamente${NC}"
        echo -e "${GREEN}✅ NPM ${NPM_VER} instalado${NC}"
    else
        echo -e "${RED}❌ Falló la instalación de Node.js${NC}"
        echo -e "${YELLOW}Intentando instalar desde repositorio Ubuntu...${NC}"
        apt-get install -y nodejs npm
    fi
    
    # 7. Instalar PM2
    echo -e "${CYAN}📦 Instalando PM2...${NC}"
    npm install -g pm2 --force 2>/dev/null || npm install -g pm2 || echo -e "${YELLOW}⚠️  No se pudo instalar PM2, continuando...${NC}"
    
    echo -e "${GREEN}${BOLD}✅ PROBLEMA DE NODE.JS SOLUCIONADO${NC}\n"
}

# ================================================
# INSTALACIÓN PRINCIPAL COMPLETA
# ================================================
main_installation() {
    echo -e "${CYAN}${BOLD}🚀 INICIANDO INSTALACIÓN PRINCIPAL COMPLETA...${NC}"
    
    # Detectar IP
    echo -e "${YELLOW}🔍 Detectando IP del servidor...${NC}"
    SERVER_IP=$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "127.0.0.1")
    if [[ -z "$SERVER_IP" || "$SERVER_IP" == "127.0.0.1" ]]; then
        echo -e "${RED}❌ No se pudo obtener IP pública${NC}"
        read -p "📝 Ingresa la IP del servidor manualmente: " SERVER_IP
    fi

    echo -e "${GREEN}✅ IP detectada: ${CYAN}$SERVER_IP${NC}\n"
    
    # Solicitar grupo de notificaciones
    echo -e "${YELLOW}📢 CONFIGURACIÓN DE NOTIFICACIONES${NC}"
    echo -e "${CYAN}Ingresa el ID del grupo de WhatsApp para notificaciones${NC}"
    echo -e "Ejemplo: 1234567890-123456@g.us"
    echo -e "Deja vacío si no quieres notificaciones en grupo\n"
    
    read -p "ID del grupo para notificaciones: " NOTIFICATION_GROUP
    
    if [[ -n "$NOTIFICATION_GROUP" ]]; then
        echo -e "${GREEN}✅ Grupo configurado: ${CYAN}$NOTIFICATION_GROUP${NC}"
    else
        echo -e "${YELLOW}⚠️ Notificaciones en grupo desactivadas${NC}"
    fi
    
    # Confirmar instalación
    echo -e "\n${YELLOW}⚠️  ESTE INSTALADOR HARÁ:${NC}"
    echo -e "   • Instalar dependencias del sistema"
    echo -e "   • Crear SSH Bot Pro con planes separados"
    echo -e "   • Sistema de notificaciones automáticas"
    echo -e "   • Menú: 1=Prueba, 2=Comprar, 3=Renovar, 4=APP"
    echo -e "   • Planes DIARIOS: 7, 15 días"
    echo -e "   • Planes MENSUALES: 30, 50 días"
    echo -e "   • Test gratuito: 2 horas"
    echo -e "   • CONTRASEÑA FIJA: mgvpn247"
    echo -e "   • MercadoPago integrado"
    echo -e "   • APK enviada como archivo"
    echo -e "   • Sin cupones de descuento"
    echo -e "   • Panel de control completo"
    
    read -p "$(echo -e "${YELLOW}¿Continuar con la instalación? (s/N): ${NC}")" -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo -e "${RED}❌ Instalación cancelada${NC}"
        exit 0
    fi
    
    # Actualizar sistema
    echo -e "${YELLOW}🔄 Actualizando sistema...${NC}"
    apt-get update -y
    apt-get upgrade -y
    
    # Instalar dependencias del sistema
    echo -e "${YELLOW}📦 Instalando dependencias del sistema...${NC}"
    apt-get install -y \
        git curl wget sqlite3 jq \
        build-essential python3 python3-pip \
        unzip cron ufw ffmpeg gnupg \
        libcairo2-dev libpango1.0-dev \
        libjpeg-dev libgif-dev librsvg2-dev \
        pkg-config ca-certificates \
        software-properties-common apt-transport-https
        
    # Instalar Chrome/Chromium
    echo -e "${YELLOW}🌐 Instalando Chrome/Chromium...${NC}"
    apt-get install -y wget
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add - 2>/dev/null || true
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list 2>/dev/null || true
    apt-get update -y
    
    # Intentar instalar chrome o chromium
    apt-get install -y google-chrome-stable 2>/dev/null || \
    apt-get install -y chromium-browser 2>/dev/null || \
    apt-get install -y chromium 2>/dev/null || \
    echo -e "${YELLOW}⚠️  No se pudo instalar Chrome, usando sistema alternativo${NC}"
    
    # Configurar firewall
    echo -e "${YELLOW}🛡️  Configurando firewall...${NC}"
    ufw allow 22/tcp 2>/dev/null || true
    ufw allow 80/tcp 2>/dev/null || true
    ufw allow 443/tcp 2>/dev/null || true
    ufw --force enable 2>/dev/null || true
    
    # Crear estructura de directorios
    echo -e "${YELLOW}📁 Creando estructura de directorios...${NC}"
    INSTALL_DIR="/opt/ssh-bot"
    USER_HOME="/root/ssh-bot"
    
    # Limpiar instalaciones anteriores
    pm2 delete ssh-bot 2>/dev/null || true
    pm2 flush 2>/dev/null || true
    rm -rf "$INSTALL_DIR" "$USER_HOME" 2>/dev/null || true
    rm -rf /root/.wwebjs_auth /root/.wwebjs_cache 2>/dev/null || true
    
    mkdir -p "$INSTALL_DIR"/{data,config,qr_codes,logs,apk}
    mkdir -p "$USER_HOME"
    mkdir -p /root/.wwebjs_auth
    chmod -R 755 "$INSTALL_DIR"
    chmod -R 700 /root/.wwebjs_auth
    
    # Crear archivo APK por defecto (mensaje)
    echo -e "${YELLOW}📱 Preparando directorio APK...${NC}"
    APK_DIR="$INSTALL_DIR/apk"
    touch "$APK_DIR/.apk_placeholder"
    echo "Suba su archivo APK aquí y renómbrelo a 'app.apk'" > "$APK_DIR/LEEME.txt"
    
    # Crear configuración COMPLETA
    CONFIG_FILE="$INSTALL_DIR/config/config.json"
    DB_FILE="$INSTALL_DIR/data/users.db"
    
    cat > "$CONFIG_FILE" << EOF
{
    "bot": {
        "name": "SSH Bot Pro",
        "version": "1.0-COMPLETO",
        "server_ip": "$SERVER_IP",
        "default_password": "mgvpn247",
        "notification_group": "$NOTIFICATION_GROUP"
    },
    "prices": {
        "test_hours": 2,
        "price_7d_1conn": 1500.00,
        "price_15d_1conn": 2500.00,
        "price_30d_1conn": 5500.00,
        "price_50d_1conn": 8500.00,
        "currency": "ARS"
    },
    "notifications": {
        "expiry_warning_hours": 24,
        "enabled": true
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false
    },
    "apk": {
        "path": "$APK_DIR/app.apk",
        "filename": "MGVPN.apk",
        "caption": "📱 MGVPN - Cliente SSH Premium\n\n🔐 Contraseña: mgvpn247\n📍 IP: $SERVER_IP\n\n💡 Instrucciones:\n1. Permite instalación de fuentes desconocidas\n2. Instala la aplicación\n3. Configura con tus credenciales SSH"
    },
    "links": {
        "tutorial": "https://youtube.com",
        "support": "https://wa.me/543435071016"
    },
    "paths": {
        "database": "$DB_FILE",
        "chromium": "/usr/bin/google-chrome-stable",
        "qr_codes": "$INSTALL_DIR/qr_codes"
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
    max_connections INTEGER DEFAULT 1,
    status INTEGER DEFAULT 1,
    notification_sent INTEGER DEFAULT 0,
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
    connections INTEGER DEFAULT 1,
    amount REAL,
    final_amount REAL,
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
CREATE TABLE notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    type TEXT,
    message TEXT,
    sent_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_expires ON users(expires_at);
CREATE INDEX idx_users_notification ON users(notification_sent);
CREATE INDEX idx_payments_status ON payments(status);
SQL

    echo -e "${GREEN}✅ Base de datos creada${NC}"
    
    # Crear bot COMPLETO
    cd "$USER_HOME"
    
    echo -e "${YELLOW}📦 Creando package.json...${NC}"
    cat > package.json << 'PKGEOF'
{
    "name": "ssh-bot-pro-completo",
    "version": "1.0.0",
    "main": "bot.js",
    "dependencies": {
        "whatsapp-web.js": "^1.24.0",
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
    
    echo -e "${YELLOW}📦 Instalando dependencias Node.js...${NC}"
    npm install --silent 2>&1 | grep -v "npm WARN" || npm install --force
    
    # Aplicar parche para error WhatsApp Web
    echo -e "${YELLOW}🔧 Aplicando parche para WhatsApp Web...${NC}"
    find node_modules/whatsapp-web.js -name "Client.js" -type f -exec sed -i 's/if (chat && chat.markedUnread)/if (false \&\& chat.markedUnread)/g' {} \; 2>/dev/null || true
    
    echo -e "${GREEN}✅ Dependencias instaladas${NC}"
    
    # Crear bot.js COMPLETO (versión simplificada pero funcional)
    echo -e "${YELLOW}📝 Creando bot.js completo...${NC}"
    
    cat > "bot.js" << 'BOTEOF'
const { Client, LocalAuth, MessageMedia } = require('whatsapp-web.js');
const qrcodeTerminal = require('qrcode-terminal');
const QRCode = require('qrcode');
const moment = require('moment');
const sqlite3 = require('sqlite3').verbose();
const { exec } = require('child_process');
const util = require('util');
const chalk = require('chalk');
const cron = require('node-cron');
const fs = require('fs');
const path = require('path');

const execPromise = util.promisify(exec);

function loadConfig() {
    delete require.cache[require.resolve('/opt/ssh-bot/config/config.json')];
    return require('/opt/ssh-bot/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database(config.paths.database);
moment.locale('es');

console.log(chalk.cyan.bold('\n🤖 SSH BOT PRO - VERSIÓN COMPLETA'));
console.log(chalk.cyan(`📍 IP: ${config.bot.server_ip}`));
console.log(chalk.cyan(`🔐 Pass: ${config.bot.default_password}`));
console.log(chalk.green('✅ Sistema de planes separados'));
console.log(chalk.green('✅ Planes DIARIOS: 7, 15 días'));
console.log(chalk.green('✅ Planes MENSUALES: 30, 50 días'));
console.log(chalk.green('✅ Test: 2 horas'));
console.log(chalk.green('✅ Sistema de notificaciones'));
console.log(chalk.green('✅ APK por archivo'));
console.log(chalk.red('🚫 Sin cupones de descuento\n'));

// Funciones de estado
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
            [phone, state, dataStr], (err) => { if (err) console.error('❌ Error estado:', err.message); resolve(); });
    });
}

// Generar usuario
function generateUsername(tipo = 'test') {
    const randomNum = Math.floor(1000 + Math.random() * 9000);
    if (tipo === 'test') return 'test' + randomNum;
    else return 'user' + randomNum;
}

function generatePassword() {
    return 'mgvpn247';
}

// Crear usuario SSH
async function createSSHUser(phone, username, password, days, connections = 1) {
    if (days === 0) {
        const expireFull = moment().add(config.prices.test_hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
        
        const commands = [
            `useradd -m -s /bin/bash ${username} 2>/dev/null || true`,
            `echo "${username}:${password}" | chpasswd`
        ];
        
        for (const cmd of commands) {
            try { await execPromise(cmd); } catch (error) { console.error(`❌ Error: ${cmd}`, error.message); }
        }
        
        return new Promise((resolve, reject) => {
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at, max_connections, status, notification_sent) VALUES (?, ?, ?, 'test', ?, ?, 1, 0)`,
                [phone, username, password, expireFull, 1],
                (err) => err ? reject(err) : resolve({ username, password, expires: expireFull, tipo: 'test' }));
        });
    } else {
        const expireDate = moment().add(days, 'days').format('YYYY-MM-DD');
        const expireFull = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
        
        try {
            await execPromise(`useradd -M -s /bin/false -e ${expireDate} ${username} 2>/dev/null || true && echo "${username}:${password}" | chpasswd`);
        } catch (error) {
            console.error('❌ Error creando premium:', error.message);
            throw error;
        }
        
        return new Promise((resolve, reject) => {
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at, max_connections, status, notification_sent) VALUES (?, ?, ?, 'premium', ?, ?, 1, 0)`,
                [phone, username, password, expireFull, connections],
                (err) => err ? reject(err) : resolve({ username, password, expires: expireFull, tipo: 'premium' }));
        });
    }
}

// Verificar prueba diaria
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
async function sendAPK(phone) {
    try {
        const apkPath = config.apk.path;
        
        if (!fs.existsSync(apkPath)) {
            await client.sendMessage(phone, `⚠️ *APK NO DISPONIBLE*

El administrador aún no ha subido el archivo APK.

Por favor contacta soporte:
${config.links.support}`, { sendSeen: false });
            return false;
        }
        
        const media = MessageMedia.fromFilePath(apkPath);
        await client.sendMessage(phone, media, {
            caption: config.apk.caption,
            sendSeen: false
        });
        
        return true;
    } catch (error) {
        console.error('❌ Error enviando APK:', error);
        await client.sendMessage(phone, `❌ Error al enviar el archivo APK: ${error.message}`, { sendSeen: false });
        return false;
    }
}

// Planes disponibles
const dailyPlans = {
    '7': { days: 7, amountKey: 'price_7d_1conn', name: '7 DÍAS' },
    '15': { days: 15, amountKey: 'price_15d_1conn', name: '15 DÍAS' }
};

const monthlyPlans = {
    '30': { days: 30, amountKey: 'price_30d_1conn', name: '30 DÍAS' },
    '50': { days: 50, amountKey: 'price_50d_1conn', name: '50 DÍAS' }
};

// Configurar cliente WhatsApp
const client = new Client({
    authStrategy: new LocalAuth({dataPath: '/root/.wwebjs_auth', clientId: 'ssh-bot-completo'}),
    puppeteer: {
        headless: true,
        executablePath: config.paths.chromium || '/usr/bin/chromium-browser',
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu'],
        timeout: 60000
    },
    authTimeoutMs: 60000
});

let qrCount = 0;

// Eventos del cliente
client.on('qr', (qr) => {
    qrCount++;
    console.clear();
    console.log(chalk.yellow.bold(`\n📱 QR #${qrCount} - ESCANEA CON WHATSAPP\n`));
    qrcodeTerminal.generate(qr, { small: true });
    QRCode.toFile('/root/qr-whatsapp.png', qr, { width: 500 }).catch(() => {});
    console.log(chalk.cyan('\n1. Abre WhatsApp → Dispositivos vinculados'));
    console.log(chalk.cyan('2. Escanea el QR de arriba'));
    console.log(chalk.green('\n💾 QR guardado: /root/qr-whatsapp.png\n'));
});

client.on('authenticated', () => console.log(chalk.green('✅ Autenticado')));
client.on('loading_screen', (p, m) => console.log(chalk.yellow(`⏳ Cargando: ${p}% - ${m}`)));
client.on('ready', () => {
    console.clear();
    console.log(chalk.green.bold('\n✅ BOT CONECTADO Y OPERATIVO\n'));
    console.log(chalk.cyan('💬 Envía "menu" a tu WhatsApp\n'));
    qrCount = 0;
});
client.on('auth_failure', (m) => console.log(chalk.red('❌ Error auth:'), m));
client.on('disconnected', (r) => console.log(chalk.yellow('⚠️ Desconectado:'), r));

// Manejo de mensajes PRINCIPAL
client.on('message', async (msg) => {
    const text = msg.body.toLowerCase().trim();
    const phone = msg.from;
    if (phone.includes('@g.us')) return;
    
    console.log(chalk.cyan(`📩 [${phone.split('@')[0]}]: ${text.substring(0, 30)}`));
    
    const userState = await getUserState(phone);
    
    // MENÚ PRINCIPAL
    if (['menu', 'hola', 'start', 'hi', 'volver', 'atras', '0'].includes(text)) {
        await setUserState(phone, 'main_menu');
        await client.sendMessage(phone, `HOLA, BIENVENIDO BOT MGVPN 🚀

Elija una opción:

🧾 1 - CREAR PRUEBA (${config.prices.test_hours} HORAS)
💰 2 - COMPRAR USUARIO SSH
🔄 3 - RENOVAR USUARIO SSH
📱 4 - DESCARGAR APLICACIÓN

🔐 Contraseña: ${config.bot.default_password}
📍 IP: ${config.bot.server_ip}`, { sendSeen: false });
    }
    // OPCIÓN 1: PRUEBA
    else if (text === '1' && userState.state === 'main_menu') {
        if (!(await canCreateTest(phone))) {
            await client.sendMessage(phone, `⚠️ *YA USASTE TU PRUEBA HOY*

⏳ Vuelve mañana para otra prueba gratuita`, { sendSeen: false });
            return;
        }
        
        await client.sendMessage(phone, '⏳ Creando cuenta de prueba...', { sendSeen: false });
        
        try {
            const username = generateUsername('test');
            const password = generatePassword();
            await createSSHUser(phone, username, password, 0, 1);
            registerTest(phone);
            
            await client.sendMessage(phone, `✅ *PRUEBA CREADA CON ÉXITO* !

👤 Usuario: ${username}
🔑 Contraseña: ${password}
⏰ Expira en: ${config.prices.test_hours} horas
🔌 Conexiones: 1 dispositivo

📱 *APP:* ${config.links.app_download}

¡Disfruta tu prueba! 🚀`, { sendSeen: false });
            
            console.log(chalk.green(`✅ Test creado: ${username}`));
        } catch (error) {
            await client.sendMessage(phone, `❌ Error al crear cuenta: ${error.message}`, { sendSeen: false });
        }
    }
    // OPCIÓN 2: COMPRAR
    else if (text === '2' && userState.state === 'main_menu') {
        await setUserState(phone, 'buying_ssh');
        await client.sendMessage(phone, `PLANES SSH PREMIUM !

Elija una opción:
🗓 1 - PLANES SSH DIARIOS (7, 15 DÍAS)
🗓 2 - PLANES SSH MENSUALES (30, 50 DÍAS)
⬅️ 0 - VOLVER`, { sendSeen: false });
    }
    // SUBMENÚ COMPRAS
    else if (userState.state === 'buying_ssh') {
        if (text === '1') {
            await setUserState(phone, 'selecting_daily_plan');
            await client.sendMessage(phone, `🗓 *PLANES SSH DIARIOS*

Elija un plan:
🗓 1 - 7 DÍAS - $${config.prices.price_7d_1conn} ARS
🗓 2 - 15 DÍAS - $${config.prices.price_15d_1conn} ARS
⬅️ 0 - VOLVER`, { sendSeen: false });
        }
        else if (text === '2') {
            await setUserState(phone, 'selecting_monthly_plan');
            await client.sendMessage(phone, `🗓 *PLANES SSH MENSUALES*

Elija un plan:
🗓 1 - 30 DÍAS - $${config.prices.price_30d_1conn} ARS
🗓 2 - 50 DÍAS - $${config.prices.price_50d_1conn} ARS
⬅️ 0 - VOLVER`, { sendSeen: false });
        }
        else if (text === '0') {
            await setUserState(phone, 'main_menu');
            await client.sendMessage(phone, `HOLA, BIENVENIDO MGVPN

Elija una opción:
🧾 1 - CREAR PRUEBA (${config.prices.test_hours} HORAS)
💰 2 - COMPRAR USUARIO SSH
🔄 3 - RENOVAR USUARIO SSH
📱 4 - DESCARGAR APLICACIÓN`, { sendSeen: false });
        }
    }
    // SELECCIÓN PLAN DIARIO
    else if (userState.state === 'selecting_daily_plan') {
        if (text === '1' || text === '2') {
            const planNumber = parseInt(text);
            let planData;
            
            if (planNumber === 1) planData = dailyPlans['7'];
            else if (planNumber === 2) planData = dailyPlans['15'];
            
            if (planData) {
                const amount = config.prices[planData.amountKey];
                
                await client.sendMessage(phone, `✅ *PLAN SELECCIONADO: ${planData.name}*

💰 Precio: $${amount} ARS
⏰ Duración: ${planData.days} días
🔌 Conexiones: 1 dispositivo

⚠️ *MERCADOPAGO NO CONFIGURADO*
El administrador debe configurar MercadoPago primero.

💬 Contacta soporte para realizar la compra:
${config.links.support}`, { sendSeen: false });
                
                await setUserState(phone, 'main_menu');
            }
        }
        else if (text === '0') {
            await setUserState(phone, 'buying_ssh');
            await client.sendMessage(phone, `PLANES SSH PREMIUM !

Elija una opción:
🗓 1 - PLANES SSH DIARIOS (7, 15 DÍAS)
🗓 2 - PLANES SSH MENSUALES (30, 50 DÍAS)
⬅️ 0 - VOLVER`, { sendSeen: false });
        }
    }
    // SELECCIÓN PLAN MENSUAL
    else if (userState.state === 'selecting_monthly_plan') {
        if (text === '1' || text === '2') {
            const planNumber = parseInt(text);
            let planData;
            
            if (planNumber === 1) planData = monthlyPlans['30'];
            else if (planNumber === 2) planData = monthlyPlans['50'];
            
            if (planData) {
                const amount = config.prices[planData.amountKey];
                
                await client.sendMessage(phone, `✅ *PLAN SELECCIONADO: ${planData.name}*

💰 Precio: $${amount} ARS
⏰ Duración: ${planData.days} días
🔌 Conexiones: 1 dispositivo

⚠️ *MERCADOPAGO NO CONFIGURADO*
El administrador debe configurar MercadoPago primero.

💬 Contacta soporte para realizar la compra:
${config.links.support}`, { sendSeen: false });
                
                await setUserState(phone, 'main_menu');
            }
        }
        else if (text === '0') {
            await setUserState(phone, 'buying_ssh');
            await client.sendMessage(phone, `PLANES SSH PREMIUM !

Elija una opción:
🗓 1 - PLANES SSH DIARIOS (7, 15 DÍAS)
🗓 2 - PLANES SSH MENSUALES (30, 50 DÍAS)
⬅️ 0 - VOLVER`, { sendSeen: false });
        }
    }
    // OPCIÓN 3: RENOVAR
    else if (text === '3' && userState.state === 'main_menu') {
        db.all('SELECT username, expires_at FROM users WHERE phone = ? AND status = 1 ORDER BY expires_at DESC', [phone], (err, rows) => {
            if (err || !rows || rows.length === 0) {
                client.sendMessage(phone, `🔄 *RENOVAR USUARIO SSH*

No tienes cuentas activas para renovar.

Para crear una nueva cuenta, selecciona:
💰 2 - COMPRAR USUARIO SSH`, { sendSeen: false });
                return;
            }
            
            let message = `🔄 *RENOVAR USUARIO SSH*\n\nTus cuentas activas:\n`;
            rows.forEach((row, index) => {
                const expireDate = moment(row.expires_at).format('DD/MM/YYYY HH:mm');
                message += `${index + 1}. 👤 *${row.username}* - ⏰ Vence: ${expireDate}\n`;
            });
            
            message += `\nPara renovar contacta soporte:\n${config.links.support}`;
            client.sendMessage(phone, message, { sendSeen: false });
        });
    }
    // OPCIÓN 4: DESCARGAR APP
    else if (text === '4' && userState.state === 'main_menu') {
        await client.sendMessage(phone, `📱 *DESCARGANDO APLICACIÓN...*

⏳ Buscando archivo APK...`, { sendSeen: false });
        
        const apkSent = await sendAPK(phone);
        
        if (apkSent) {
            await client.sendMessage(phone, `✅ *APK ENVIADA CON ÉXITO*

📁 *Nombre:* ${config.apk.filename}
💡 *Instrucciones:*
1. Permite instalación de fuentes desconocidas
2. Instala la aplicación
3. Configura con tus credenciales SSH

🔐 *Credenciales:*
Usuario: (el que te proporcionamos)
Contraseña: ${config.bot.default_password}`, { sendSeen: false });
        }
    }
});

// Limpiar usuarios expirados cada 15 minutos
cron.schedule('*/15 * * * *', async () => {
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    console.log(chalk.yellow(`🧹 Limpiando usuarios expirados... (${now})`));
    
    db.all('SELECT username FROM users WHERE expires_at < ? AND status = 1', [now], async (err, rows) => {
        if (err || !rows || rows.length === 0) return;
        
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

// Inicializar bot
console.log(chalk.green('\n🚀 Inicializando bot completo...\n'));
client.initialize();
BOTEOF

    echo -e "${GREEN}✅ Bot completo creado${NC}"
    
    # Crear panel de control COMPLETO con función de subir APK
    echo -e "${YELLOW}🎛️  Creando panel de control con APK...${NC}"
    
    cat > /usr/local/bin/sshbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; NC='\033[0m'

DB="/opt/ssh-bot/data/users.db"
CONFIG="/opt/ssh-bot/config/config.json"
APK_DIR="/opt/ssh-bot/apk"
APK_FILE="$APK_DIR/app.apk"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }
set_val() { local t=$(mktemp); jq "$1 = $2" "$CONFIG" > "$t" && mv "$t" "$CONFIG"; }

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                🎛️  PANEL SSH BOT - COMPLETO               ║${NC}"
    echo -e "${CYAN}║                   📱 APK POR ARCHIVO                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

upload_apk() {
    echo -e "\n${CYAN}📁 SUBIR ARCHIVO APK${NC}"
    echo -e "${YELLOW}=========================================${NC}"
    
    if [[ -f "$APK_FILE" ]]; then
        APK_SIZE=$(stat -c%s "$APK_FILE" 2>/dev/null || echo "0")
        APK_DATE=$(stat -c%y "$APK_FILE" 2>/dev/null | cut -d' ' -f1)
        
        if [[ $APK_SIZE -gt 0 ]]; then
            SIZE_MB=$(echo "scale=2; $APK_SIZE / 1024 / 1024" | bc)
            echo -e "${GREEN}✅ APK actual: ${config.apk.filename}${NC}"
            echo -e "📊 Tamaño: ${SIZE_MB} MB"
            echo -e "📅 Fecha: ${APK_DATE}"
        else
            echo -e "${RED}⚠️  Archivo APK existe pero está vacío${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No hay archivo APK cargado${NC}"
        echo -e "   Ubicación esperada: $APK_FILE"
    fi
    
    echo -e "\n${CYAN}💾 INSTRUCCIONES PARA SUBIR:${NC}"
    echo -e "1. Transfiere tu APK al servidor usando:"
    echo -e "   scp /ruta/tu/app.apk root@${SERVER_IP}:$APK_DIR/"
    echo -e "2. Luego renómbrala:"
    echo -e "   mv $APK_DIR/*.apk $APK_FILE"
    echo -e "3. Verifica que se haya subido correctamente"
    
    echo -e "\n${YELLOW}O usa el método directo (si estás en este servidor):${NC}"
    read -p "¿Quieres subir un archivo APK desde este servidor? (s/N): " SUBIR
    
    if [[ "$SUBIR" == "s" ]]; then
        echo -e "\n${CYAN}📂 Buscando archivos APK en el sistema...${NC}"
        
        # Buscar archivos APK
        find /home /root /tmp -name "*.apk" -type f 2>/dev/null | head -10 | while read -r found_apk; do
            SIZE=$(stat -c%s "$found_apk" 2>/dev/null || echo "0")
            SIZE_MB=$(echo "scale=2; $SIZE / 1024 / 1024" | bc)
            echo -e "   📍 ${found_apk} (${SIZE_MB} MB)"
        done
        
        echo -e "\n${CYAN}📝 Ingresa la ruta completa del archivo APK:${NC}"
        read -p "Ruta: " APK_PATH
        
        if [[ -f "$APK_PATH" ]] && [[ "$APK_PATH" == *.apk ]]; then
            echo -e "${YELLOW}⏳ Copiando $APK_PATH ...${NC}"
            cp "$APK_PATH" "$APK_FILE" 2>/dev/null
            
            if [[ $? -eq 0 ]]; then
                APK_SIZE=$(stat -c%s "$APK_FILE" 2>/dev/null || echo "0")
                SIZE_MB=$(echo "scale=2; $APK_SIZE / 1024 / 1024" | bc)
                
                # Actualizar nombre en config
                APK_NAME=$(basename "$APK_PATH")
                set_val '.apk.filename' "\"$APK_NAME\""
                
                echo -e "${GREEN}✅ APK subida correctamente${NC}"
                echo -e "📁 Nombre: ${APK_NAME}"
                echo -e "📊 Tamaño: ${SIZE_MB} MB"
                echo -e "📍 Ubicación: ${APK_FILE}"
                
                # Verificar que sea un APK válido
                if file "$APK_FILE" | grep -q "Zip archive"; then
                    echo -e "${GREEN}✅ Archivo APK válido${NC}"
                else
                    echo -e "${YELLOW}⚠️  El archivo puede no ser un APK válido${NC}"
                fi
            else
                echo -e "${RED}❌ Error al copiar el archivo${NC}"
            fi
        else
            echo -e "${RED}❌ Archivo no encontrado o no es un APK${NC}"
        fi
    fi
    
    echo -e "\n${YELLOW}📋 Verificación:${NC}"
    if [[ -f "$APK_FILE" ]]; then
        APK_SIZE=$(stat -c%s "$APK_FILE" 2>/dev/null || echo "0")
        if [[ $APK_SIZE -gt 100000 ]]; then
            echo -e "${GREEN}✅ APK lista para enviar por WhatsApp${NC}"
        else
            echo -e "${RED}❌ Archivo muy pequeño, puede estar corrupto${NC}"
        fi
    else
        echo -e "${RED}❌ No hay APK disponible${NC}"
    fi
    
    read -p "Presiona Enter para continuar..."
}

while true; do
    show_header
    
    TOTAL_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1" 2>/dev/null || echo "0")
    
    STATUS=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.name=="ssh-bot") | .pm2_env.status' 2>/dev/null || echo "stopped")
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
    
    NOTIF_GROUP=$(get_val '.bot.notification_group')
    if [[ -n "$NOTIF_GROUP" && "$NOTIF_GROUP" != "" && "$NOTIF_GROUP" != "null" ]]; then
        GROUP_STATUS="${GREEN}✅ CONFIGURADO${NC}"
    else
        GROUP_STATUS="${RED}❌ NO CONFIGURADO${NC}"
    fi
    
    # Verificar APK
    if [[ -f "$APK_FILE" ]]; then
        APK_SIZE=$(stat -c%s "$APK_FILE" 2>/dev/null || echo "0")
        if [[ $APK_SIZE -gt 100000 ]]; then
            APK_SIZE_MB=$(echo "scale=2; $APK_SIZE / 1024 / 1024" | bc)
            APK_STATUS="${GREEN}✅ DISPONIBLE (${APK_SIZE_MB} MB)${NC}"
        else
            APK_STATUS="${RED}❌ ARCHIVO PEQUEÑO${NC}"
        fi
    else
        APK_STATUS="${RED}❌ NO DISPONIBLE${NC}"
    fi
    
    SERVER_IP=$(get_val '.bot.server_ip')
    
    echo -e "${YELLOW}📊 ESTADO DEL SISTEMA${NC}"
    echo -e "  Bot: $BOT_STATUS"
    echo -e "  Usuarios: ${CYAN}$ACTIVE_USERS/$TOTAL_USERS${NC} activos/total"
    echo -e "  MercadoPago: $MP_STATUS"
    echo -e "  Grupo notif.: $GROUP_STATUS"
    echo -e "  APK: $APK_STATUS"
    echo -e "  Test: ${GREEN}$(get_val '.prices.test_hours') horas${NC}"
    echo -e "  Contraseña: ${GREEN}$(get_val '.bot.default_password')${NC}"
    echo -e "  Cupones: ${RED}🚫 DESACTIVADOS${NC}"
    echo -e ""
    
    echo -e "${YELLOW}💰 PRECIOS:${NC}"
    echo -e "  📅 DIARIOS:"
    echo -e "    7 días: $ $(get_val '.prices.price_7d_1conn')"
    echo -e "    15 días: $ $(get_val '.prices.price_15d_1conn')"
    echo -e "  📅 MENSUALES:"
    echo -e "    30 días: $ $(get_val '.prices.price_30d_1conn')"
    echo -e "    50 días: $ $(get_val '.prices.price_50d_1conn')"
    echo -e ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC}  🚀  Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC}  🛑  Detener bot"
    echo -e "${CYAN}[3]${NC}  📱  Ver QR WhatsApp"
    echo -e "${CYAN}[4]${NC}  👤  Crear usuario manual"
    echo -e "${CYAN}[5]${NC}  👥  Listar usuarios"
    echo -e "${CYAN}[6]${NC}  ⏰  Cambiar horas del test"
    echo -e "${CYAN}[7]${NC}  💰  Cambiar precios"
    echo -e "${CYAN}[8]${NC}  🔑  Configurar MercadoPago"
    echo -e "${CYAN}[9]${NC}  📢  Configurar notificaciones"
    echo -e "${CYAN}[10]${NC} 📁  Subir/Ver APK"
    echo -e "${CYAN}[11]${NC} 📊  Ver estadísticas"
    echo -e "${CYAN}[12]${NC} 📝  Ver logs"
    echo -e "${CYAN}[0]${NC}  🚪  Salir"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "👉 Selecciona una opción: " OPTION
    
    case $OPTION in
        1)
            echo -e "\n${YELLOW}🔄 Reiniciando bot...${NC}"
            cd /root/ssh-bot
            pm2 restart ssh-bot 2>/dev/null || pm2 start bot.js --name ssh-bot
            pm2 save
            echo -e "${GREEN}✅ Bot reiniciado${NC}"
            sleep 2
            ;;
        2)
            echo -e "\n${YELLOW}🛑 Deteniendo bot...${NC}"
            pm2 stop ssh-bot
            echo -e "${GREEN}✅ Bot detenido${NC}"
            sleep 2
            ;;
        3)
            clear
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║                    📱 CÓDIGO QR WHATSAPP                     ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
            
            if [[ -f "/root/qr-whatsapp.png" ]]; then
                echo -e "${GREEN}✅ QR guardado en: /root/qr-whatsapp.png${NC}\n"
                echo -e "${YELLOW}Para ver el QR actual, revisa los logs:${NC}"
                echo -e "pm2 logs ssh-bot --lines 50"
            else
                echo -e "${YELLOW}⚠️  QR no generado aún${NC}"
                echo -e "${CYAN}Espera a que el bot se conecte o reinícialo${NC}"
            fi
            read -p "¿Ver logs? (s/N): " VER
            [[ "$VER" == "s" ]] && pm2 logs ssh-bot --lines 50
            ;;
        4)
            clear
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║                     👤 CREAR USUARIO                        ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
            
            read -p "Teléfono (ej: 5491122334455): " PHONE
            read -p "Usuario (auto=generar): " USERNAME
            read -p "Tipo (test/premium): " TIPO
            read -p "Días (0=test, 7,15,30,50=premium): " DAYS
            
            [[ -z "$DAYS" ]] && DAYS="30"
            if [[ "$USERNAME" == "auto" || -z "$USERNAME" ]]; then
                if [[ "$TIPO" == "test" ]]; then
                    USERNAME="test$(shuf -i 1000-9999 -n 1)"
                else
                    USERNAME="user$(shuf -i 1000-9999 -n 1)"
                fi
            fi
            PASSWORD="mgvpn247"
            
            if [[ "$TIPO" == "test" ]]; then
                DAYS="0"
                TEST_HOURS=$(get_val '.prices.test_hours')
                EXPIRE_DATE=$(date -d "+${TEST_HOURS} hours" +"%Y-%m-%d %H:%M:%S")
                useradd -M -s /bin/false "$USERNAME" && echo "$USERNAME:$PASSWORD" | chpasswd
            else
                EXPIRE_DATE=$(date -d "+$DAYS days" +"%Y-%m-%d 23:59:59")
                useradd -M -s /bin/false -e "$(date -d "+$DAYS days" +%Y-%m-%d)" "$USERNAME" && echo "$USERNAME:$PASSWORD" | chpasswd
            fi
            
            if [[ $? -eq 0 ]]; then
                sqlite3 "$DB" "INSERT INTO users (phone, username, password, tipo, expires_at, max_connections, status) VALUES ('$PHONE', '$USERNAME', '$PASSWORD', '$TIPO', '$EXPIRE_DATE', 1, 1)"
                echo -e "\n${GREEN}✅ USUARIO CREADO${NC}"
                echo -e "👤 Usuario: ${USERNAME}"
                echo -e "🔑 Contraseña: ${PASSWORD}"
                echo -e "⏰ Expira: ${EXPIRE_DATE}"
                echo -e "📞 Teléfono: ${PHONE}"
            else
                echo -e "\n${RED}❌ Error creando usuario${NC}"
            fi
            read -p "Presiona Enter..." 
            ;;
        5)
            clear
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║                     👥 USUARIOS ACTIVOS                     ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
            
            sqlite3 -column -header "$DB" "SELECT username, tipo, expires_at, substr(phone,1,12) as tel FROM users WHERE status = 1 ORDER BY expires_at DESC LIMIT 20"
            
            echo -e "\n${YELLOW}Total: ${ACTIVE_USERS} activos${NC}"
            read -p "Presiona Enter..." 
            ;;
        6)
            clear
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║                  ⏰ CAMBIAR HORAS DEL TEST                   ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
            
            CURRENT_HOURS=$(get_val '.prices.test_hours')
            echo -e "${YELLOW}⏰ HORAS ACTUALES DEL TEST: ${GREEN}${CURRENT_HOURS} HORAS${NC}\n"
            
            read -p "Nuevas horas para el test [${CURRENT_HOURS}]: " NEW_HOURS
            
            if [[ -n "$NEW_HOURS" ]]; then
                if [[ $NEW_HOURS =~ ^[0-9]+$ ]] && [[ $NEW_HOURs -ge 1 ]] && [[ $NEW_HOURS -le 24 ]]; then
                    set_val '.prices.test_hours' "$NEW_HOURS"
                    echo -e "\n${GREEN}✅ Horas cambiadas a ${NEW_HOURS} horas${NC}"
                    echo -e "${YELLOW}🔄 Reiniciando bot...${NC}"
                    cd /root/ssh-bot && pm2 restart ssh-bot
                    sleep 2
                else
                    echo -e "${RED}❌ Error: Debe ser un número entre 1 y 24${NC}"
                fi
            fi
            read -p "Presiona Enter..." 
            ;;
        7)
            clear
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║                    💰 CAMBIAR PRECIOS                       ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
            
            CURRENT_7D=$(get_val '.prices.price_7d_1conn')
            CURRENT_15D=$(get_val '.prices.price_15d_1conn')
            CURRENT_30D=$(get_val '.prices.price_30d_1conn')
            CURRENT_50D=$(get_val '.prices.price_50d_1conn')
            
            echo -e "${YELLOW}💰 PRECIOS ACTUALES:${NC}"
            echo -e "  📅 DIARIOS:"
            echo -e "    7 días: $${CURRENT_7D}"
            echo -e "    15 días: $${CURRENT_15D}"
            echo -e "  📅 MENSUALES:"
            echo -e "    30 días: $${CURRENT_30D}"
            echo -e "    50 días: $${CURRENT_50D}\n"
            
            read -p "Nuevo precio 7d [${CURRENT_7D}]: " NEW_7D
            read -p "Nuevo precio 15d [${CURRENT_15D}]: " NEW_15D
            read -p "Nuevo precio 30d [${CURRENT_30D}]: " NEW_30D
            read -p "Nuevo precio 50d [${CURRENT_50D}]: " NEW_50D
            
            [[ -n "$NEW_7D" ]] && set_val '.prices.price_7d_1conn' "$NEW_7D"
            [[ -n "$NEW_15D" ]] && set_val '.prices.price_15d_1conn' "$NEW_15D"
            [[ -n "$NEW_30D" ]] && set_val '.prices.price_30d_1conn' "$NEW_30D"
            [[ -n "$NEW_50D" ]] && set_val '.prices.price_50d_1conn' "$NEW_50D"
            
            echo -e "\n${GREEN}✅ Precios actualizados${NC}"
            echo -e "${YELLOW}🔄 Reiniciando bot...${NC}"
            cd /root/ssh-bot && pm2 restart ssh-bot
            sleep 2
            read -p "Presiona Enter..." 
            ;;
        8)
            clear
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║              🔑 CONFIGURAR MERCADOPAGO                      ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
            
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
                    cd /root/ssh-bot && pm2 restart ssh-bot
                    sleep 2
                else
                    echo -e "${RED}❌ Token inválido${NC}"
                    echo -e "${YELLOW}Debe empezar con APP_USR- o TEST-${NC}"
                fi
            fi
            read -p "Presiona Enter..." 
            ;;
        9)
            clear
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║             📢 CONFIGURAR NOTIFICACIONES                   ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
            
            CURRENT_GROUP=$(get_val '.bot.notification_group')
            CURRENT_WARNING=$(get_val '.notifications.expiry_warning_hours')
            
            echo -e "${YELLOW}⚙️ CONFIGURACIÓN ACTUAL:${NC}"
            echo -e "  Grupo WhatsApp: ${CYAN}${CURRENT_GROUP:-'No configurado'}${NC}"
            echo -e "  Aviso por vencer: ${CYAN}${CURRENT_WARNING} horas antes${NC}\n"
            
            read -p "Nuevo ID de grupo [${CURRENT_GROUP}]: " NEW_GROUP
            read -p "Horas para aviso por vencer [${CURRENT_WARNING}]: " NEW_WARNING
            
            if [[ -n "$NEW_GROUP" ]]; then
                set_val '.bot.notification_group' "\"$NEW_GROUP\""
                echo -e "${GREEN}✅ Grupo actualizado${NC}"
            fi
            
            if [[ -n "$NEW_WARNING" ]]; then
                if [[ $NEW_WARNING =~ ^[0-9]+$ ]] && [[ $NEW_WARNING -ge 1 ]] && [[ $NEW_WARNING -le 168 ]]; then
                    set_val '.notifications.expiry_warning_hours' "$NEW_WARNING"
                    echo -e "${GREEN}✅ Aviso por vencer actualizado a ${NEW_WARNING} horas${NC}"
                else
                    echo -e "${RED}❌ Error: Debe ser un número entre 1 y 168 (7 días)${NC}"
                fi
            fi
            
            echo -e "\n${YELLOW}🔄 Reiniciando bot...${NC}"
            cd /root/ssh-bot && pm2 restart ssh-bot
            sleep 2
            read -p "Presiona Enter..." 
            ;;
        10)
            upload_apk
            ;;
        11)
            clear
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║                     📊 ESTADÍSTICAS                         ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
            
            echo -e "${YELLOW}👥 USUARIOS:${NC}"
            sqlite3 "$DB" "SELECT 'Total: ' || COUNT(*) || ' | Activos: ' || SUM(CASE WHEN status=1 THEN 1 ELSE 0 END) || ' | Tests: ' || SUM(CASE WHEN tipo='test' THEN 1 ELSE 0 END) || ' | Premium: ' || SUM(CASE WHEN tipo='premium' THEN 1 ELSE 0 END) FROM users"
            
            echo -e "\n${YELLOW}📅 DISTRIBUCIÓN POR PLANES:${NC}"
            sqlite3 "$DB" "SELECT '7 días: ' || SUM(CASE WHEN plan='7d' THEN 1 ELSE 0 END) || ' | 15 días: ' || SUM(CASE WHEN plan='15d' THEN 1 ELSE 0 END) || ' | 30 días: ' || SUM(CASE WHEN plan='30d' THEN 1 ELSE 0 END) || ' | 50 días: ' || SUM(CASE WHEN plan='50d' THEN 1 ELSE 0 END) FROM payments WHERE status='approved'"
            
            echo -e "\n${YELLOW}⏰ USUARIOS POR VENCER:${NC}"
            sqlite3 "$DB" "SELECT 'En 24h: ' || COUNT(*) || ' | En 48h: ' || (SELECT COUNT(*) FROM users WHERE status=1 AND tipo='premium' AND expires_at <= datetime('now', '+48 hours') AND expires_at > datetime('now', '+24 hours')) FROM users WHERE status=1 AND tipo='premium' AND expires_at <= datetime('now', '+24 hours')"
            
            echo -e "\n${YELLOW}📱 APK:${NC}"
            if [[ -f "$APK_FILE" ]]; then
                APK_SIZE=$(stat -c%s "$APK_FILE" 2>/dev/null || echo "0")
                SIZE_MB=$(echo "scale=2; $APK_SIZE / 1024 / 1024" | bc)
                echo -e "  Disponible: ${GREEN}${SIZE_MB} MB${NC}"
                echo -e "  Enviada: $(sqlite3 "$DB" "SELECT COUNT(DISTINCT phone) FROM users WHERE tipo='premium' OR tipo='test'" 2>/dev/null || echo "0") veces"
            else
                echo -e "  ${RED}No disponible${NC}"
            fi
            
            read -p "\nPresiona Enter..." 
            ;;
        12)
            echo -e "\n${YELLOW}📝 Logs (Ctrl+C para salir)...${NC}\n"
            pm2 logs ssh-bot --lines 100
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
    
    echo -e "${GREEN}✅ Panel de control creado con función APK${NC}"
    
    # Crear script para subir APK fácilmente
    cat > /usr/local/bin/upload-apk << 'UPLOADEOP'
#!/bin/bash
APK_DIR="/opt/ssh-bot/apk"
APK_FILE="$APK_DIR/app.apk"

echo -e "\n📱 SUBIR ARCHIVO APK PARA EL BOT"
echo -e "================================\n"

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Uso:"
    echo "  upload-apk                    - Mostrar ayuda"
    echo "  upload-apk /ruta/apk.apk      - Subir archivo APK"
    echo "  upload-apk --status           - Ver estado del APK"
    exit 0
fi

if [ "$1" == "--status" ]; then
    if [ -f "$APK_FILE" ]; then
        APK_SIZE=$(stat -c%s "$APK_FILE" 2>/dev/null || echo "0")
        if [ $APK_SIZE -gt 100000 ]; then
            SIZE_MB=$(echo "scale=2; $APK_SIZE / 1024 / 1024" | bc)
            echo -e "✅ APK disponible: $APK_FILE"
            echo -e "📊 Tamaño: ${SIZE_MB} MB"
            echo -e "📍 El bot la enviará automáticamente"
        else
            echo -e "⚠️  Archivo APK muy pequeño o corrupto"
        fi
    else
        echo -e "❌ No hay archivo APK"
        echo -e "   Ubicación esperada: $APK_FILE"
    fi
    exit 0
fi

if [ -n "$1" ] && [ -f "$1" ]; then
    echo "📥 Copiando $1 a $APK_FILE..."
    cp "$1" "$APK_FILE"
    
    if [ $? -eq 0 ]; then
        APK_SIZE=$(stat -c%s "$APK_FILE" 2>/dev/null || echo "0")
        if [ $APK_SIZE -gt 100000 ]; then
            SIZE_MB=$(echo "scale=2; $APK_SIZE / 1024 / 1024" | bc)
            echo -e "✅ APK subida correctamente"
            echo -e "📊 Tamaño: ${SIZE_MB} MB"
            echo -e "📍 El bot la enviará cuando seleccionen '4 - DESCARGAR APLICACIÓN'"
        else
            echo -e "⚠️  Archivo muy pequeño. ¿Es un APK válido?"
        fi
    else
        echo -e "❌ Error al copiar el archivo"
    fi
else
    echo -e "ℹ️  INSTRUCCIONES PARA SUBIR APK:\n"
    echo -e "1. Subir via SCP (desde tu PC):"
    echo -e "   scp /ruta/a/tu.apk root@$(hostname -I | awk '{print $1}'):$APK_DIR/"
    echo -e "   ssh root@$(hostname -I | awk '{print $1}') 'mv $APK_DIR/*.apk $APK_FILE'\n"
    
    echo -e "2. Si ya está en el servidor:"
    echo -e "   upload-apk /ruta/a/tu.apk\n"
    
    echo -e "3. Verificar estado:"
    echo -e "   upload-apk --status\n"
    
    echo -e "📋 El APK debe llamarse 'app.apk' en $APK_DIR"
fi
UPLOADEOP

    chmod +x /usr/local/bin/upload-apk
    
    echo -e "${GREEN}✅ Script de subida APK creado${NC}"
    
    # Iniciar bot
    echo -e "${YELLOW}🚀 Iniciando bot completo...${NC}"
    cd "$USER_HOME"
    pm2 start bot.js --name ssh-bot
    pm2 save
    pm2 startup systemd -u root --hp /root 2>/dev/null || true
    
    sleep 3
    
    # Mostrar mensaje final
    echo -e "\n${GREEN}${BOLD}"
    cat << "FINAL"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║       🎉 INSTALACIÓN COMPLETADA - VERSIÓN COMPLETA 🎉      ║
║                📱 CON APK POR ARCHIVO                       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
    echo -e "${NC}"
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ Sistema instalado exitosamente${NC}"
    echo -e "${GREEN}✅ Versión completa con planes separados${NC}"
    echo -e "${GREEN}✅ Test: 2 horas por defecto${NC}"
    echo -e "${GREEN}✅ Contraseña: mgvpn247 (fija)${NC}"
    echo -e "${GREEN}✅ APK enviada como archivo${NC}"
    echo -e "${RED}🚫 Cupones de descuento desactivados${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${YELLOW}📋 COMANDOS DISPONIBLES:${NC}\n"
    echo -e "  ${GREEN}sshbot${NC}         - Panel de control completo"
    echo -e "  ${GREEN}upload-apk${NC}     - Subir archivo APK fácilmente"
    echo -e "  ${GREEN}pm2 logs ssh-bot${NC} - Ver logs del bot"
    echo -e "  ${GREEN}pm2 restart ssh-bot${NC} - Reiniciar bot\n"
    
    echo -e "${YELLOW}📱 SUBIR APK:${NC}\n"
    echo -e "  1. Sube tu archivo APK al servidor:"
    echo -e "     ${CYAN}scp mi-app.apk root@$SERVER_IP:/opt/ssh-bot/apk/${NC}"
    echo -e "  2. Luego ejecuta en el servidor:"
    echo -e "     ${CYAN}mv /opt/ssh-bot/apk/*.apk /opt/ssh-bot/apk/app.apk${NC}"
    echo -e "  3. O usa: ${CYAN}upload-apk /ruta/a/tu.apk${NC}\n"
    
    echo -e "${YELLOW}🔧 CONFIGURACIÓN INICIAL:${NC}\n"
    echo -e "  1. Ejecuta: ${GREEN}sshbot${NC}"
    echo -e "  2. Opción ${CYAN}[3]${NC} - Ver QR WhatsApp"
    echo -e "  3. Escanea el QR con tu teléfono"
    echo -e "  4. Envía 'menu' al bot para probar"
    echo -e "  5. Opción ${CYAN}[10]${NC} - Subir APK"
    echo -e "  6. Opción ${CYAN}[8]${NC} - Configurar MercadoPago (opcional)"
    echo -e "  7. Opción ${CYAN}[9]${NC} - Configurar notificaciones (opcional)\n"
    
    echo -e "${YELLOW}💰 PRECIOS POR DEFECTO:${NC}\n"
    echo -e "  Test: ${GREEN}2 horas (gratis)${NC}"
    echo -e "  📅 DIARIOS:"
    echo -e "    7 días: ${GREEN}$1500 ARS${NC}"
    echo -e "    15 días: ${GREEN}$2500 ARS${NC}"
    echo -e "  📅 MENSUALES:"
    echo -e "    30 días: ${GREEN}$5500 ARS${NC}"
    echo -e "    50 días: ${GREEN}$8500 ARS${NC}\n"
    
    echo -e "${YELLOW}📍 INFORMACIÓN:${NC}"
    echo -e "  IP: ${CYAN}$SERVER_IP${NC}"
    echo -e "  BD: ${CYAN}/opt/ssh-bot/data/users.db${NC}"
    echo -e "  Config: ${CYAn}/opt/ssh-bot/config/config.json${NC}"
    echo -e "  APK: ${CYAN}/opt/ssh-bot/apk/app.apk${NC}"
    echo -e "  Bot: ${CYAN}/root/ssh-bot/${NC}"
    echo -e "  QR: ${CYAN}/root/qr-whatsapp.png${NC}\n"
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"
}

# ================================================
# EJECUCIÓN PRINCIPAL
# ================================================

# Ejecutar solución de Node.js primero
fix_nodejs

# Pausa para verificar
echo -e "${YELLOW}⚠️  Solución de Node.js aplicada.${NC}"
echo -e "${CYAN}Verificando Node.js...${NC}"
node --version 2>/dev/null && echo -e "${GREEN}✅ Node.js: $(node --version)${NC}" || echo -e "${RED}❌ Node.js no instalado${NC}"
npm --version 2>/dev/null && echo -e "${GREEN}✅ NPM: $(npm --version)${NC}" || echo -e "${RED}❌ NPM no instalado${NC}"

read -p "$(echo -e "${YELLOW}¿Continuar con la instalación completa del bot? (s/N): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Instalación cancelada${NC}"
    echo -e "${GREEN}Node.js ya está solucionado, puedes instalar manualmente después${NC}"
    exit 0
fi

# Ejecutar instalación principal
main_installation

echo -e "${GREEN}${BOLD}✨ Instalación completada exitosamente! 🚀${NC}\n"

# Preguntar si abrir panel
read -p "$(echo -e "${YELLOW}¿Abrir panel de control ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}Abriendo panel de control...${NC}\n"
    sleep 2
    /usr/local/bin/sshbot
else
    echo -e "\n${YELLOW}💡 Recuerda: Ejecuta ${GREEN}sshbot${NC} para abrir el panel\n"
fi

exit 0