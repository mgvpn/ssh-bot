#!/bin/bash
# ================================================
# HTTP CUSTOM BOT - WPPCONNECT + MERCADOPAGO
# CON ENTREGA DE ARCHIVO .HC (HTTP CUSTOM)
# VERSIÓN COMPLETA
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
║  ██╗  ██╗████████╗████████╗██████╗ ███████╗                 ║
║  ██║  ██║╚══██╔══╝╚══██╔══╝██╔══██╗██╔════╝                 ║
║  ███████║   ██║      ██║   ██████╔╝█████╗                   ║
║  ██╔══██║   ██║      ██║   ██╔═══╝ ██╔══╝                   ║
║  ██║  ██║   ██║      ██║   ██║     ███████╗                 ║
║  ╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚═╝     ╚══════╝                 ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║           🤖 HTTP CUSTOM BOT - WPPCONNECT + MP              ║
║               📱 WhatsApp API FUNCIONANDO                   ║
║               💰 MercadoPago SDK v2.x INTEGRADO            ║
║               📁 Entrega automática de .hc                  ║
║               ⚡ Test 2 horas en HTTP Custom                ║
║               🎛️  Panel completo con control MP           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CARACTERÍSTICAS PRINCIPALES:${NC}"
echo -e "  📱 ${CYAN}WPPConnect${NC} - API WhatsApp que funciona"
echo -e "  💰 ${GREEN}MercadoPago SDK v2.x${NC} - Integrado completo"
echo -e "  💳 ${YELLOW}Pago automático${NC} - QR + Enlace de pago"
echo -e "  📁 ${BLUE}Entrega .hc${NC} - Archivo HTTP Custom automático"
echo -e "  ⚡ ${GREEN}Test 2 horas${NC} - Para HTTP Custom"
echo -e "  🔑 ${PURPLE}HWID único${NC} - Sistema de HWID"
echo -e "  📊 ${CYAN}Estadísticas${NC} - Ventas, usuarios, ingresos"
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
    read -p "📝 Ingresa la IP o dominio del servidor: " SERVER_IP
fi

echo -e "${GREEN}✅ IP/Dominio: ${CYAN}$SERVER_IP${NC}\n"

# Puerto para HTTP Custom
read -p "$(echo -e "${YELLOW}📌 Ingresa el puerto para HTTP Custom (ej: 8080): ${NC}")" HC_PORT
HC_PORT=${HC_PORT:-8080}

# Método de encriptación
read -p "$(echo -e "${YELLOW}🔐 Método de encriptación (ej: aes-256-gcm): ${NC}")" ENCRYPTION
ENCRYPTION=${ENCRYPTION:-"aes-256-gcm"}

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
apt-get install -y wget gnupg
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
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
    unzip cron ufw nginx

# Configurar firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow $HC_PORT/tcp
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

INSTALL_DIR="/opt/httpcustom-bot"
USER_HOME="/root/httpcustom-bot"
DB_FILE="$INSTALL_DIR/data/users.db"
CONFIG_FILE="$INSTALL_DIR/config/config.json"
HC_FILES_DIR="$INSTALL_DIR/hc_files"

# Limpiar anterior
pm2 delete httpcustom-bot 2>/dev/null || true
rm -rf "$INSTALL_DIR" "$USER_HOME" 2>/dev/null || true
rm -rf /root/.wppconnect 2>/dev/null || true

# Crear directorios
mkdir -p "$INSTALL_DIR"/{data,config,sessions,logs,qr_codes}
mkdir -p "$USER_HOME"
mkdir -p "$HC_FILES_DIR"
mkdir -p /root/.wppconnect
chmod -R 755 "$INSTALL_DIR"
chmod -R 700 /root/.wppconnect

# Crear configuración
cat > "$CONFIG_FILE" << EOF
{
    "bot": {
        "name": "HTTP Custom Bot",
        "version": "2.0-HC-COMPLETO",
        "server_ip": "$SERVER_IP",
        "server_port": $HC_PORT,
        "encryption": "$ENCRYPTION",
        "default_password": "mghc247"
    },
    "prices": {
        "test_hours": 2,
        "price_7d": 3000.00,
        "price_15d": 5000.00,
        "price_30d": 8000.00,
        "price_50d": 12000.00,
        "currency": "ARS"
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false,
        "public_key": ""
    },
    "links": {
        "app_download": "https://play.google.com/store/apps/details?id=xyz.easypro.httpcustom",
        "tutorial": "https://www.youtube.com/watch?v=ejemplo",
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

# Crear base de datos COMPLETA con HWID
sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    username TEXT UNIQUE,
    hwid TEXT UNIQUE,
    password TEXT DEFAULT 'mghc247',
    tipo TEXT DEFAULT 'test',
    expires_at DATETIME,
    status INTEGER DEFAULT 1,
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
    hwid TEXT,
    plan TEXT,
    days INTEGER,
    amount REAL,
    discount_code TEXT,
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
CREATE TABLE hwid_registry (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hwid TEXT UNIQUE,
    username TEXT,
    phone TEXT,
    registered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_used DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_hwid ON users(hwid);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_hwid ON payments(hwid);
SQL

echo -e "${GREEN}✅ Estructura creada con HWID${NC}"

# ================================================
# CREAR GENERADOR DE ARCHIVOS .HC
# ================================================
echo -e "\n${CYAN}📁 Creando generador de archivos .hc...${NC}"

cat > "$INSTALL_DIR/generate_hc.py" << 'PYEOF'
#!/usr/bin/env python3
import json
import sys
import os
import sqlite3
from datetime import datetime, timedelta

def generate_hc_file(username, hwid, server_ip, server_port, encryption, days):
    """Genera archivo .hc para HTTP Custom"""
    
    # Configuración base
    config = {
        "configs": [
            {
                "server": server_ip,
                "server_port": int(server_port),
                "password": "mghc247",
                "method": encryption,
                "plugin": "",
                "plugin_opts": "",
                "remarks": f"HTTP Custom - {username}",
                "timeout": 5,
                "auth": False
            }
        ],
        "strategy": None,
        "index": 0,
        "global": False,
        "enabled": True,
        "shareOverLan": False,
        "isDefault": False,
        "localPort": 1080,
        "portableMode": True,
        "showPluginOutput": False,
        "pacUrl": None,
        "useOnlinePac": False,
        "secureLocalPac": True,
        "availabilityStatistics": False,
        "autoCheckUpdate": True,
        "checkPreRelease": False,
        "isVerboseLogging": False,
        "logViewer": None,
        "proxy": None,
        "hotkey": None,
        "proxyMode": 0,
        "proxyHost": None,
        "proxyPort": 0,
        "proxyTimeout": 3
    }
    
    # Convertir a JSON
    hc_content = json.dumps(config, indent=2)
    
    # Nombre del archivo
    filename = f"{username}_{hwid}.hc"
    
    return filename, hc_content

if __name__ == "__main__":
    if len(sys.argv) != 6:
        print("Uso: python generate_hc.py <username> <hwid> <server_ip> <port> <encryption>")
        sys.exit(1)
    
    username = sys.argv[1]
    hwid = sys.argv[2]
    server_ip = sys.argv[3]
    server_port = sys.argv[4]
    encryption = sys.argv[5]
    
    filename, content = generate_hc_file(username, hwid, server_ip, server_port, encryption, 30)
    
    # Guardar archivo
    with open(filename, 'w') as f:
        f.write(content)
    
    print(f"Archivo generado: {filename}")
PYEOF

chmod +x "$INSTALL_DIR/generate_hc.py"

# Crear script para generar .hc
cat > /usr/local/bin/generate-hc << 'HCGENEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/opt/httpcustom-bot"
DB="$INSTALL_DIR/data/users.db"
CONFIG="$INSTALL_DIR/config/config.json"

if [[ $# -lt 2 ]]; then
    echo -e "${RED}Uso: generate-hc <username> <hwid>${NC}"
    echo -e "${YELLOW}Ejemplo: generate-hc testuser 822ab8c5d5de5341bb92535f61d5509c${NC}"
    exit 1
fi

USERNAME="$1"
HWID="$2"

# Obtener configuración
SERVER_IP=$(jq -r '.bot.server_ip' "$CONFIG")
SERVER_PORT=$(jq -r '.bot.server_port' "$CONFIG")
ENCRYPTION=$(jq -r '.bot.encryption' "$CONFIG")
HC_DIR=$(jq -r '.paths.hc_files' "$CONFIG")

echo -e "${CYAN}Generando archivo .hc para:${NC}"
echo -e "👤 Usuario: ${USERNAME}"
echo -e "🔑 HWID: ${HWID}"
echo -e "🌐 Servidor: ${SERVER_IP}:${SERVER_PORT}"
echo -e "🔐 Encriptación: ${ENCRYPTION}"

# Verificar si el usuario existe en BD
USER_EXISTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE username='$USERNAME' AND hwid='$HWID' AND status=1")
if [[ "$USER_EXISTS" -eq 0 ]]; then
    echo -e "${RED}❌ Usuario/HWID no encontrado o inactivo${NC}"
    exit 1
fi

# Generar archivo
FILENAME="${USERNAME}_${HWID}.hc"
FILEPATH="$HC_DIR/$FILENAME"

python3 "$INSTALL_DIR/generate_hc.py" "$USERNAME" "$HWID" "$SERVER_IP" "$SERVER_PORT" "$ENCRYPTION" 30 > "$FILEPATH"

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✅ Archivo generado: ${FILENAME}${NC}"
    echo -e "${YELLOW}📁 Ubicación: ${FILEPATH}${NC}"
    
    # Crear enlace público
    PUBLIC_DIR="/var/www/html/hc"
    mkdir -p "$PUBLIC_DIR"
    cp "$FILEPATH" "$PUBLIC_DIR/"
    chmod 644 "$PUBLIC_DIR/$FILENAME"
    
    URL="http://${SERVER_IP}/hc/${FILENAME}"
    echo -e "${CYAN}🌐 URL de descarga: ${URL}${NC}"
    
    # Mostrar contenido del archivo
    echo -e "\n${YELLOW}📄 Contenido del archivo .hc:${NC}"
    cat "$FILEPATH"
else
    echo -e "${RED}❌ Error generando archivo${NC}"
    exit 1
fi
HCGENEOF

chmod +x /usr/local/bin/generate-hc

echo -e "${GREEN}✅ Generador de .hc creado${NC}"

# ================================================
# CONFIGURAR NGINX PARA DESCARGAS
# ================================================
echo -e "\n${CYAN}🌐 Configurando Nginx para descargas...${NC}"

mkdir -p /var/www/html/hc
chmod -R 755 /var/www/html

cat > /etc/nginx/sites-available/httpcustom << 'NGINXEOF'
server {
    listen 80;
    server_name _;
    
    root /var/www/html;
    index index.html;
    
    # Para descargar archivos .hc
    location /hc/ {
        alias /var/www/html/hc/;
        autoindex off;
        add_header Content-Type application/octet-stream;
        add_header Content-Disposition "attachment; filename=$request_filename";
    }
    
    # Página de inicio simple
    location / {
        return 200 '<!DOCTYPE html><html><head><title>HTTP Custom</title></head><body><h1>HTTP Custom Bot</h1><p>Sistema de gestión de configuraciones .hc</p></body></html>';
        add_header Content-Type text/html;
    }
}
NGINXEOF

ln -sf /etc/nginx/sites-available/httpcustom /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

echo -e "${GREEN}✅ Nginx configurado${NC}"

# ================================================
# CREAR BOT CON SISTEMA DE HWID
# ================================================
echo -e "\n${CYAN}🤖 Creando bot con sistema HWID...${NC}"

cd "$USER_HOME"

# package.json
cat > package.json << 'PKGEOF'
{
    "name": "httpcustom-bot",
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
        "axios": "^1.6.5"
    }
}
PKGEOF

echo -e "${YELLOW}📦 Instalando dependencias...${NC}"
npm install --silent 2>&1 | grep -v "npm WARN" || true

# Crear bot.js CON SISTEMA HWID
echo -e "${YELLOW}📝 Creando bot.js con HWID...${NC}"

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
console.log(chalk.cyan.bold('║                🤖 HTTP CUSTOM BOT - WPP + MP                ║'));
console.log(chalk.cyan.bold('║                    📁 SISTEMA HWID + .HC                    ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

// Cargar configuración
function loadConfig() {
    delete require.cache[require.resolve('/opt/httpcustom-bot/config/config.json')];
    return require('/opt/httpcustom-bot/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/httpcustom-bot/data/users.db');

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

// Variables globales
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

// Generar HWID aleatorio (simulado)
function generateHWID() {
    const chars = 'abcdef0123456789';
    let hwid = '';
    for (let i = 0; i < 32; i++) {
        hwid += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return hwid;
}

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

const DEFAULT_PASSWORD = 'mghc247';

// VERIFICAR HWID
async function verifyHWID(hwid) {
    return new Promise((resolve) => {
        db.get('SELECT username, tipo, expires_at, status FROM users WHERE hwid = ?', [hwid], (err, row) => {
            if (err || !row) {
                resolve({ valid: false, message: 'HWID no encontrado' });
            } else if (row.status === 0) {
                resolve({ valid: false, message: 'Usuario inactivo' });
            } else if (new Date(row.expires_at) < new Date()) {
                resolve({ valid: false, message: 'Usuario expirado' });
            } else {
                resolve({ 
                    valid: true, 
                    username: row.username,
                    tipo: row.tipo,
                    expires_at: row.expires_at
                });
            }
        });
    });
}

// CREAR USUARIO HTTP CUSTOM (solo en BD, no en sistema)
async function createHTTPUser(phone, username, hwid, days) {
    console.log(chalk.yellow(`🔧 Creando usuario HTTP: ${username} HWID: ${hwid} para ${days} días`));
    
    try {
        const password = DEFAULT_PASSWORD;
        let expireFull;
        
        if (days === 0) {
            // Test de 2 horas
            const horasTest = config.prices.test_hours || 2;
            expireFull = moment().add(horasTest, 'hours').format('YYYY-MM-DD HH:mm:ss');
            
            console.log(chalk.cyan(`📅 Test expira: ${expireFull} (${horasTest} horas)`));
            
            // Insertar en BD
            db.run(`INSERT INTO users (phone, username, hwid, password, tipo, expires_at, status) VALUES (?, ?, ?, ?, 'test', ?, 1)`,
                [phone, username, hwid, password, expireFull], (err) => {
                    if (err) console.error(chalk.red('❌ Error BD:'), err.message);
                });
            
            // Registrar HWID
            db.run(`INSERT OR REPLACE INTO hwid_registry (hwid, username, phone) VALUES (?, ?, ?)`,
                [hwid, username, phone]);
            
            console.log(chalk.green(`✅ Test creado: ${username} HWID: ${hwid} (expira en ${horasTest} horas)`));
            
        } else {
            // Premium
            expireFull = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
            
            console.log(chalk.cyan(`📅 Premium expira: ${expireFull} (${days} días)`));
            
            db.run(`INSERT INTO users (phone, username, hwid, password, tipo, expires_at, status) VALUES (?, ?, ?, ?, 'premium', ?, 1)`,
                [phone, username, hwid, password, expireFull], (err) => {
                    if (err) console.error(chalk.red('❌ Error BD:'), err.message);
                });
            
            // Registrar HWID
            db.run(`INSERT OR REPLACE INTO hwid_registry (hwid, username, phone) VALUES (?, ?, ?)`,
                [hwid, username, phone]);
            
            console.log(chalk.green(`✅ Premium creado: ${username} HWID: ${hwid} (expira en ${days} días)`));
        }
        
        // Generar archivo .hc
        await generateHCFile(username, hwid);
        
        return { 
            success: true, 
            username, 
            hwid, 
            password, 
            expires: expireFull, 
            days: days,
            hc_file: `${username}_${hwid}.hc`
        };
        
    } catch (error) {
        console.error(chalk.red('❌ Error creando usuario:'), error.message);
        return { success: false, error: error.message };
    }
}

// GENERAR ARCHIVO .HC
async function generateHCFile(username, hwid) {
    try {
        const scriptPath = '/opt/httpcustom-bot/generate_hc.py';
        const hcDir = config.paths.hc_files;
        
        await execPromise(`python3 ${scriptPath} "${username}" "${hwid}" "${config.bot.server_ip}" "${config.bot.server_port}" "${config.bot.encryption}"`);
        
        const filename = `${username}_${hwid}.hc`;
        const filepath = `${hcDir}/${filename}`;
        
        // Copiar a directorio público
        await execPromise(`cp "${hcDir}/${filename}" "/var/www/html/hc/" 2>/dev/null || true`);
        
        console.log(chalk.green(`✅ Archivo .hc generado: ${filename}`));
        return { success: true, filename, url: `http://${config.bot.server_ip}/hc/${filename}` };
        
    } catch (error) {
        console.error(chalk.red('❌ Error generando .hc:'), error.message);
        return { success: false, error: error.message };
    }
}

// FUNCIONES DE CONTROL
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

// MERCADOPAGO - CREAR PAGO
async function createMercadoPagoPayment(phone, hwid, days, amount, planName, discountCode = null) {
    try {
        if (!mpEnabled || !mpPreference) {
            return { success: false, error: 'MercadoPago no configurado' };
        }
        
        const phoneClean = phone.replace('@c.us', '');
        const paymentId = `HC-${hwid.substring(0, 8)}-${days}d-${Date.now()}`;
        
        console.log(chalk.cyan(`🔄 Creando pago MP: ${paymentId} HWID: ${hwid}`));
        
        // Aplicar descuento
        let finalAmount = parseFloat(amount);
        let discountPercentage = 0;
        
        if (discountCode) {
            const discountLower = discountCode.toLowerCase();
            if (discountLower.includes('10')) discountPercentage = 10;
            else if (discountLower.includes('15')) discountPercentage = 15;
            else if (discountLower.includes('20')) discountPercentage = 20;
            
            if (discountPercentage > 0) {
                finalAmount = finalAmount * (1 - discountPercentage / 100);
            }
        }
        
        const expirationDate = moment().add(24, 'hours');
        
        const preferenceData = {
            items: [{
                title: `HTTP CUSTOM ${days} DÍAS`,
                description: `Configuración .hwid ${hwid}`,
                quantity: 1,
                currency_id: config.prices.currency || 'ARS',
                unit_price: finalAmount
            }],
            external_reference: paymentId,
            expires: true,
            expiration_date_from: moment().toISOString(),
            expiration_date_to: expirationDate.toISOString(),
            back_urls: {
                success: `https://wa.me/${phoneClean}`,
                failure: `https://wa.me/${phoneClean}`,
                pending: `https://wa.me/${phoneClean}`
            },
            auto_return: 'approved',
            statement_descriptor: 'HTTP CUSTOM'
        };
        
        const response = await mpPreference.create({ body: preferenceData });
        
        if (response && response.id) {
            const paymentUrl = response.init_point;
            const qrPath = `${config.paths.qr_codes}/${paymentId}.png`;
            
            await QRCode.toFile(qrPath, paymentUrl, { 
                width: 400,
                margin: 2
            });
            
            db.run(
                `INSERT INTO payments (payment_id, phone, hwid, plan, days, amount, discount_code, final_amount, status, payment_url, qr_code, preference_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
                [paymentId, phone, hwid, `${days}d`, days, amount, discountCode, finalAmount, paymentUrl, qrPath, response.id]
            );
            
            console.log(chalk.green(`✅ Pago creado: ${paymentId}`));
            
            return { 
                success: true, 
                paymentId, 
                paymentUrl, 
                qrPath,
                preferenceId: response.id,
                amount: finalAmount,
                discountPercentage: discountPercentage
            };
        }
        
        throw new Error('Respuesta inválida de MercadoPago');
        
    } catch (error) {
        console.error(chalk.red('❌ Error MercadoPago:'), error.message);
        return { success: false, error: error.message };
    }
}

// VERIFICAR PAGOS
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
                    
                    if (mpPayment.status === 'approved') {
                        console.log(chalk.green(`✅ PAGO APROBADO: ${payment.payment_id} HWID: ${payment.hwid}`));
                        
                        // Crear usuario premium
                        const username = generatePremiumUsername();
                        const result = await createHTTPUser(payment.phone, username, payment.hwid, payment.days);
                        
                        if (result.success) {
                            db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`, [payment.payment_id]);
                            
                            const expireDate = moment().add(payment.days, 'days').format('DD/MM/YYYY');
                            const hcUrl = `http://${config.bot.server_ip}/hc/${result.hc_file}`;
                            
                            const message = `✅ *PAGO CONFIRMADO*

🎉 Tu configuración HTTP Custom ha sido activada

📋 *DATOS DE CONFIGURACIÓN:*
👤 Usuario: *${username}*
🔑 HWID: *${payment.hwid}*
🔐 Contraseña: *${DEFAULT_PASSWORD}*

⏰ *VÁLIDO HASTA:* ${expireDate}

📁 *ARCHIVO .HC:*
${hcUrl}

📱 *INSTALACIÓN:*
1. Descarga HTTP Custom
2. Importa el archivo .hc
3. ¡Conéctate automáticamente!

🎊 ¡Disfruta del servicio premium!`;
                            
                            if (client) {
                                await client.sendText(payment.phone, message);
                            }
                        }
                    }
                }
            } catch (error) {
                console.error(chalk.red(`❌ Error verificando ${payment.payment_id}:`), error.message);
            }
        }
    });
}

// INICIALIZAR BOT
async function initializeBot() {
    try {
        console.log(chalk.yellow('🚀 Inicializando WPPConnect...'));
        
        client = await wppconnect.create({
            session: 'httpcustom-bot-session',
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
                const text = message.body.trim();
                const from = message.from;
                
                console.log(chalk.cyan(`📩 [${from}]: ${text.substring(0, 30)}`));
                
                const userState = await getUserState(from);
                
                // MENÚ PRINCIPAL
                if (['menu', 'hola', 'start', 'hi', 'volver', '0'].includes(text.toLowerCase())) {
                    await setUserState(from, 'main_menu');
                    
                    await client.sendText(from, `


    🚀 *BIENVENIDOS - HTTP CUSTOM*   


Elija una opción:

🧾 *1* - PRUEBA GRATIS (2 horas)
💰 *2* - COMPRAR USUARIO HWID
🔄 *3* - RENOVAR USUARIO HWID
📁 *4* - ARCHIVO .HC / EDITAR HWID
📱 *5* - DESCARGAR APP
ℹ️  *6* - INFO Y AYUDA

📝 - RESPONDE CON EL NUMERO`);
                }
                
                // OPCIÓN 1 - PRUEBA GRATIS
                else if (text === '1' && userState.state === 'main_menu') {
                    if (!(await canCreateTest(from))) {
                        await client.sendText(from, `⚠️ *YA USO SU PRUEBA HOY*

⏳ Vuelve mañana para otra prueba gratuita`);
                        return;
                    }
                    
                    await setUserState(from, 'creating_test');
                    await client.sendText(from, `🧾 *PRUEBA GRATUITA*

Para crear tu prueba, necesito:
1. Un nombre para tu usuario (solo letras y números, sin espacios)
2. Tu HWID completo

📝 *Escribe un nombre para tu usuario:*`);
                }
                
                // RECIBIR NOMBRE PARA TEST
                else if (userState.state === 'creating_test') {
                    const username = text.toLowerCase().replace(/[^a-z0-9]/g, '');
                    
                    if (username.length < 3) {
                        await client.sendText(from, '❌ Nombre muy corto. Mínimo 3 caracteres.');
                        return;
                    }
                    
                    await setUserState(from, 'getting_hwid_test', { username });
                    await client.sendText(from, `👤 *Nombre:* ${username}

✅ Nombre aceptado.

📋 *Ahora pega tu HWID completo:*
(Ejemplo: 822ab8c5d5de5341bb92535f61d5509c)`);
                }
                
                // RECIBIR HWID PARA TEST
                else if (userState.state === 'getting_hwid_test') {
                    const stateData = userState.data || {};
                    const username = stateData.username;
                    const hwid = text.trim().toLowerCase().replace(/[^a-f0-9]/g, '');
                    
                    if (hwid.length < 10) {
                        await client.sendText(from, '❌ HWID inválido. Debe tener al menos 10 caracteres hexadecimales.');
                        return;
                    }
                    
                    await client.sendText(from, '⏳ *Creando cuenta de prueba...*');
                    
                    try {
                        const result = await createHTTPUser(from, username, hwid, 0);
                        
                        if (result.success) {
                            registerTest(from);
                            
                            const hcUrl = `http://${config.bot.server_ip}/hc/${result.hc_file}`;
                            
                            await client.sendText(from, `✅ *PRUEBA CREADA CON ÉXITO!*

👤 *Usuario:* ${username}
🔑 *HWID:* ${hwid}
🔐 *Contraseña:* ${DEFAULT_PASSWORD}
⏰ *Expira en:* 2 horas ⏳

📁 *ARCHIVO .HC:*
${hcUrl}

📱 *APP:* ${config.links.app_download}

⚠️ *Importa el archivo .hc en HTTP Custom*`);
                            
                            console.log(chalk.green(`✅ Test creado: ${username} HWID: ${hwid}`));
                        } else {
                            await client.sendText(from, `❌ Error: ${result.error}`);
                        }
                    } catch (error) {
                        await client.sendText(from, `❌ Error al crear cuenta: ${error.message}`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
                // OPCIÓN 2 - COMPRAR USUARIO HWID
                else if (text === '2' && userState.state === 'main_menu') {
                    await setUserState(from, 'buying_hwid');
                    
                    await client.sendText(from, `


    💰 *COMPRAR USUARIO HWID*    


Elija un plan:

🗓 *1* - 7 DÍAS - $${config.prices.price_7d}

🗓 *2* - 15 DÍAS - $${config.prices.price_15d}

🗓 *3* - 30 DÍAS - $${config.prices.price_30d}

🗓 *4* - 50 DÍAS - $${config.prices.price_50d}

⬅️ *0* - VOLVER`);
                }
                
                // SELECCIÓN DE PLAN
                else if (userState.state === 'buying_hwid') {
                    if (['1', '2', '3', '4'].includes(text)) {
                        const planMap = {
                            '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                            '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' },
                            '3': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                            '4': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                        };
                        
                        const plan = planMap[text];
                        
                        if (mpEnabled) {
                            // Solicitar HWID primero
                            await setUserState(from, 'getting_hwid_payment', { 
                                plan: plan,
                                days: plan.days,
                                amount: plan.price,
                                planName: plan.name
                            });
                            
                            await client.sendText(from, `✅ *PLAN SELECCIONADO: ${plan.name}*

💰 *Precio:* $${plan.price} ARS
⏰ *Duración:* ${plan.days} días

📋 *Ahora necesito tu HWID para vincular el pago:*
Pega tu HWID completo:`);
                            
                        } else {
                            await client.sendText(from, `✅ *PLAN SELECCIONADO: ${plan.name}*

💰 *Precio:* $${plan.price} ARS
⏰ *Duración:* ${plan.days} días

📞 *Para continuar con la compra, contacta al administrador:*
${config.links.support}`);
                            
                            await setUserState(from, 'main_menu');
                        }
                    }
                    else if (text === '0') {
                        await setUserState(from, 'main_menu');
                        await client.sendText(from, '⬅️ Volviendo al menú principal...');
                    }
                }
                
                // RECIBIR HWID PARA PAGO
                else if (userState.state === 'getting_hwid_payment') {
                    const stateData = userState.data || {};
                    const hwid = text.trim().toLowerCase().replace(/[^a-f0-9]/g, '');
                    
                    if (hwid.length < 10) {
                        await client.sendText(from, '❌ HWID inválido. Intenta nuevamente:');
                        return;
                    }
                    
                    await setUserState(from, 'asking_discount', { 
                        ...stateData,
                        hwid: hwid
                    });
                    
                    await client.sendText(from, `🔑 *HWID registrado:* ${hwid}

**¿Tienes un cupón de descuento?**
Responde: *sí* o *no*.`);
                }
                
                // PREGUNTA POR DESCUENTO
                else if (userState.state === 'asking_discount') {
                    const stateData = userState.data || {};
                    
                    if (text.toLowerCase() === 'sí' || text.toLowerCase() === 'si') {
                        await setUserState(from, 'entering_discount', stateData);
                        await client.sendText(from, '📝 *Por favor, escribe tu código de descuento:*');
                    }
                    else if (text.toLowerCase() === 'no') {
                        await processPayment(from, stateData, null);
                    }
                    else {
                        await client.sendText(from, 'Por favor responde: *sí* o *no*');
                    }
                }
                
                // INGRESAR DESCUENTO
                else if (userState.state === 'entering_discount') {
                    const stateData = userState.data || {};
                    const discountCode = text.trim();
                    
                    await processPayment(from, stateData, discountCode);
                }
                
                // OPCIÓN 4 - ARCHIVO .HC / EDITAR HWID
                else if (text === '4' && userState.state === 'main_menu') {
                    await setUserState(from, 'hc_management');
                    
                    await client.sendText(from, `📁 *ARCHIVO .HC / EDITAR HWID*

1. Para obtener tu archivo .hc actual
2. Para editar/cambiar tu HWID
3. Para verificar estado

📋 *Primero necesito tu HWID:*
Pega tu HWID completo:`);
                }
                
                // VERIFICAR HWID Y MOSTRAR OPCIONES
                else if (userState.state === 'hc_management') {
                    const hwid = text.trim().toLowerCase();
                    
                    const verification = await verifyHWID(hwid);
                    
                    if (verification.valid) {
                        const expireDate = moment(verification.expires_at).format('DD/MM/YYYY HH:mm');
                        const hcUrl = `http://${config.bot.server_ip}/hc/${verification.username}_${hwid}.hc`;
                        
                        await client.sendText(from, `✅ *HWID VÁLIDO*

👤 *Usuario:* ${verification.username}
🔑 *HWID:* ${hwid}
📅 *Expira:* ${expireDate}
📊 *Estado:* ${verification.tipo === 'premium' ? 'PREMIUM' : 'TEST'}

📁 *ARCHIVO .HC:*
${hcUrl}

🔄 *OPCIONES:*
1. Descargar archivo .hc (envío automático)
2. Cambiar HWID (contactar administrador)
3. Verificar tiempo restante

📞 *Soporte:* ${config.links.support}`);
                        
                        // Enviar archivo si existe
                        const filePath = `${config.paths.hc_files}/${verification.username}_${hwid}.hc`;
                        if (fs.existsSync(filePath)) {
                            try {
                                await client.sendFile(from, filePath, `${verification.username}.hc`, 
                                    `📁 Archivo .hc para ${verification.username}`);
                            } catch (fileError) {
                                console.error('Error enviando archivo:', fileError.message);
                            }
                        }
                        
                    } else {
                        await client.sendText(from, `❌ *HWID NO VÁLIDO*

${verification.message}

📞 Contacta al administrador para asistencia:
${config.links.support}`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
                // OPCIÓN 5 - DESCARGAR APP
                else if (text === '5' && userState.state === 'main_menu') {
                    await client.sendText(from, `📱 *DESCARGAR HTTP CUSTOM*

🔗 *Google Play:*
${config.links.app_download}

🎬 *Tutorial de instalación:*
${config.links.tutorial}

💡 *Importante:*
1. Instala HTTP Custom desde Play Store
2. Importa el archivo .hc que te enviamos
3. Activa la conexión`);
                }
                
                // OPCIÓN 6 - INFO Y AYUDA
                else if (text === '6' && userState.state === 'main_menu') {
                    await client.sendText(from, `ℹ️  *INFORMACIÓN Y AYUDA*

📞 *Soporte:* ${config.links.support}

🔧 *Qué es HWID?*
El HWID (Hardware ID) es un identificador único de tu dispositivo.

📁 *Qué es el archivo .hc?*
Es el archivo de configuración para HTTP Custom con todos los datos de conexión.

⏰ *Prueba gratuita:*
Duración: 2 horas
Límite: 1 por día por número

💳 *Métodos de pago:*
- MercadoPago (automático)
- Transferencia bancaria

🔄 *Renovaciones:*
Contacta al administrador para renovar tu cuenta existente.`);
                }
                
            } catch (error) {
                console.error(chalk.red('❌ Error procesando mensaje:'), error.message);
            }
        });
        
        // VERIFICAR PAGOS CADA 2 MINUTOS
        cron.schedule('*/2 * * * *', () => {
            checkPendingPayments();
        });
        
        // LIMPIAR TESTS EXPIRADOS
        cron.schedule('*/5 * * * *', async () => {
            const now = moment().format('YYYY-MM-DD HH:mm:ss');
            
            db.all('SELECT username, hwid FROM users WHERE tipo = "test" AND expires_at < ? AND status = 1', [now], async (err, rows) => {
                if (err || !rows || rows.length === 0) return;
                
                console.log(chalk.yellow(`🗑️  Eliminando ${rows.length} tests expirados...`));
                
                for (const r of rows) {
                    db.run('UPDATE users SET status = 0 WHERE username = ?', [r.username]);
                    console.log(chalk.yellow(`⚠️  Test expirado: ${r.username} HWID: ${r.hwid}`));
                }
            });
        });
        
        // LIMPIAR ESTADOS ANTIGUOS
        cron.schedule('0 * * * *', () => {
            db.run(`DELETE FROM user_state WHERE updated_at < datetime('now', '-1 hour')`);
        });
        
    } catch (error) {
        console.error(chalk.red('❌ Error inicializando WPPConnect:'), error.message);
        setTimeout(initializeBot, 10000);
    }
}

// PROCESAR PAGO
async function processPayment(phone, planData, discountCode) {
    try {
        await client.sendText(phone, '⏳ *Procesando tu compra...*');
        
        const payment = await createMercadoPagoPayment(
            phone, 
            planData.hwid,
            planData.days, 
            planData.amount, 
            planData.planName, 
            discountCode
        );
        
        if (payment.success) {
            let amountText = `$${payment.amount.toFixed(2)}`;
            if (payment.discountPercentage > 0) {
                amountText = `$${planData.amount} → $${payment.amount.toFixed(2)} (${payment.discountPercentage}% descuento)`;
            }
            
            const message = `╔═══════════════════════════════╗
║     ✅ *PAGO GENERADO*       ║
╚═══════════════════════════════╝

📋 *DETALLES:*
🗓 *Plan:* ${planData.planName}
💰 *Precio:* ${amountText}
🔑 *HWID:* ${planData.hwid}
⏰ *Duración:* ${planData.days} días

═══════════════════════════════

🔗 *LINK DE PAGO*

${payment.paymentUrl}

⚠️ *Este enlace expira en 24 horas*
💳 *Pago seguro con MercadoPago*`;
            
            await client.sendText(phone, message);
            
            // Enviar QR
            if (fs.existsSync(payment.qrPath)) {
                try {
                    await client.sendImage(phone, payment.qrPath, 'qr-pago.jpg', 
                        `📱 *Escanea con MercadoPago*\n\n${planData.planName} - ${amountText}`);
                } catch (qrError) {
                    console.error('⚠️ Error enviando QR:', qrError.message);
                }
            }
            
        } else {
            await client.sendText(phone, `❌ *ERROR AL GENERAR PAGO*

${payment.error}

📞 Contacta al administrador para otras opciones de pago.`);
        }
        
    } catch (error) {
        console.error(chalk.red('❌ Error en pago:'), error.message);
        await client.sendText(phone, `❌ *ERROR INESPERADO*

${error.message}

📞 Contacta al administrador para asistencia.`);
    }
    
    await setUserState(phone, 'main_menu');
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

echo -e "${GREEN}✅ Bot creado con sistema HWID${NC}"

# ================================================
# CREAR PANEL DE CONTROL
# ================================================
echo -e "\n${CYAN}🎛️  Creando panel de control...${NC}"

cat > /usr/local/bin/hcbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; NC='\033[0m'

DB="/opt/httpcustom-bot/data/users.db"
CONFIG="/opt/httpcustom-bot/config/config.json"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }
set_val() { local t=$(mktemp); jq "$1 = $2" "$CONFIG" > "$t" && mv "$t" "$CONFIG"; }

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                🎛️  HTTP CUSTOM BOT PANEL                   ║${NC}"
    echo -e "${CYAN}║                    📁 SISTEMA HWID + .HC                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

while true; do
    show_header
    
    TOTAL_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1" 2>/dev/null || echo "0")
    TOTAL_HWID=$(sqlite3 "$DB" "SELECT COUNT(DISTINCT hwid) FROM users WHERE hwid IS NOT NULL" 2>/dev/null || echo "0")
    
    STATUS=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.name=="httpcustom-bot") | .pm2_env.status' 2>/dev/null || echo "stopped")
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
    echo -e "  Usuarios: ${CYAN}$ACTIVE_USERS/$TOTAL_USERS${NC} activos/total"
    echo -e "  HWID únicos: ${CYAN}$TOTAL_HWID${NC}"
    echo -e "  MercadoPago: $MP_STATUS"
    echo -e "  IP: $(get_val '.bot.server_ip')"
    echo -e "  Puerto: $(get_val '.bot.server_port')"
    echo -e "  Encriptación: $(get_val '.bot.encryption')"
    echo -e ""
    
    echo -e "${YELLOW}💰 PRECIOS:${NC}"
    echo -e "  7 días: $ $(get_val '.prices.price_7d')"
    echo -e "  15 días: $ $(get_val '.prices.price_15d')"
    echo -e "  30 días: $ $(get_val '.prices.price_30d')"
    echo -e "  50 días: $ $(get_val '.prices.price_50d')"
    echo -e ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC} 🚀  Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC} 🛑  Detener bot"
    echo -e "${CYAN}[3]${NC} 📱  Ver logs y QR"
    echo -e "${CYAN}[4]${NC} 👤  Crear usuario manual"
    echo -e "${CYAN}[5]${NC} 👥  Listar usuarios/HWID"
    echo -e "${CYAN}[6]${NC} 💰  Cambiar precios"
    echo -e "${CYAN}[7]${NC} 🔑  Configurar MercadoPago"
    echo -e "${CYAN}[8]${NC} 📁  Generar archivo .hc"
    echo -e "${CYAN}[9]${NC} 🔍  Buscar por HWID"
    echo -e "${CYAN}[10]${NC} 📊 Estadísticas"
    echo -e "${CYAN}[11]${NC} 🧹 Limpiar sesión"
    echo -e "${CYAN}[12]${NC} ⚙️  Ver configuración"
    echo -e "${CYAN}[13]${NC} 🗑️  Eliminar usuario"
    echo -e "${CYAN}[0]${NC} 🚪  Salir"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e ""
    
    read -p "👉 Selecciona: " OPTION
    
    case $OPTION in
        1)
            echo -e "\n${YELLOW}🔄 Reiniciando...${NC}"
            cd /root/httpcustom-bot
            pm2 restart httpcustom-bot 2>/dev/null || pm2 start bot.js --name httpcustom-bot
            pm2 save
            echo -e "${GREEN}✅ Bot reiniciado${NC}"
            sleep 2
            ;;
        2)
            echo -e "\n${YELLOW}🛑 Deteniendo...${NC}"
            pm2 stop httpcustom-bot
            echo -e "${GREEN}✅ Bot detenido${NC}"
            sleep 2
            ;;
        3)
            echo -e "\n${YELLOW}📱 Mostrando logs...${NC}"
            pm2 logs httpcustom-bot --lines 100
            ;;
        4)
            clear
            echo -e "${CYAN}👤 CREAR USUARIO MANUAL${NC}\n"
            
            read -p "Teléfono (ej: 5491122334455): " PHONE
            read -p "Nombre de usuario: " USERNAME
            read -p "HWID (32 chars hex, auto=generar): " HWID
            read -p "Tipo (test/premium): " TIPO
            read -p "Días (0=test 2h, 7,15,30,50=premium): " DAYS
            
            [[ -z "$DAYS" ]] && DAYS="30"
            if [[ "$HWID" == "auto" || -z "$HWID" ]]; then
                HWID=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 32 | head -n 1)
            fi
            
            HWID=$(echo "$HWID" | tr '[:upper:]' '[:lower:]')
            PASSWORD="mghc247"
            
            if [[ "$TIPO" == "test" ]]; then
                DAYS="0"
                EXPIRE_DATE=$(date -d "+2 hours" +"%Y-%m-%d %H:%M:%S")
                
                sqlite3 "$DB" "INSERT INTO users (phone, username, hwid, password, tipo, expires_at, status) VALUES ('$PHONE', '$USERNAME', '$HWID', '$PASSWORD', '$TIPO', '$EXPIRE_DATE', 1)"
                
                # Generar .hc
                generate-hc "$USERNAME" "$HWID"
                
                echo -e "\n${GREEN}✅ TEST CREADO (2 HORAS)${NC}"
                echo -e "📱 Teléfono: ${PHONE}"
                echo -e "👤 Usuario: ${USERNAME}"
                echo -e "🔑 HWID: ${HWID}"
                echo -e "🔐 Contraseña: ${PASSWORD}"
                
            else
                EXPIRE_DATE=$(date -d "+$DAYS days" +"%Y-%m-%d 23:59:59")
                
                sqlite3 "$DB" "INSERT INTO users (phone, username, hwid, password, tipo, expires_at, status) VALUES ('$PHONE', '$USERNAME', '$HWID', '$PASSWORD', '$TIPO', '$EXPIRE_DATE', 1)"
                
                # Generar .hc
                generate-hc "$USERNAME" "$HWID"
                
                echo -e "\n${GREEN}✅ PREMIUM CREADO${NC}"
                echo -e "📱 Teléfono: ${PHONE}"
                echo -e "👤 Usuario: ${USERNAME}"
                echo -e "🔑 HWID: ${HWID}"
                echo -e "🔐 Contraseña: ${PASSWORD}"
                echo -e "⏰ Expira: ${EXPIRE_DATE}"
            fi
            read -p "Presiona Enter..."
            ;;
        5)
            clear
            echo -e "${CYAN}👥 USUARIOS Y HWID${NC}\n"
            
            sqlite3 -column -header "$DB" "SELECT username, hwid, tipo, expires_at, CASE WHEN expires_at < datetime('now') THEN 'EXPIRO' ELSE 'ACTIVO' END as estado FROM users WHERE status = 1 ORDER BY expires_at DESC LIMIT 20"
            
            echo -e "\n${YELLOW}Total activos: ${ACTIVE_USERS}${NC}"
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
            echo -e "  7 días: $${CURRENT_7D}"
            echo -e "  15 días: $${CURRENT_15D}"
            echo -e "  30 días: $${CURRENT_30D}"
            echo -e "  50 días: $${CURRENT_50D}"
            echo -e ""
            
            echo -e "${CYAN}Modificar precios:${NC}"
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
                    cd /root/httpcustom-bot && pm2 restart httpcustom-bot
                    sleep 2
                    echo -e "${GREEN}✅ MercadoPago activado${NC}"
                else
                    echo -e "${RED}❌ Token inválido${NC}"
                fi
            fi
            read -p "Presiona Enter..."
            ;;
        8)
            clear
            echo -e "${CYAN}📁 GENERAR ARCHIVO .HC${NC}\n"
            
            read -p "Nombre de usuario: " USERNAME
            read -p "HWID: " HWID
            
            if [[ -n "$USERNAME" && -n "$HWID" ]]; then
                generate-hc "$USERNAME" "$HWID"
            else
                echo -e "${RED}❌ Datos incompletos${NC}"
            fi
            read -p "Presiona Enter..."
            ;;
        9)
            clear
            echo -e "${CYAN}🔍 BUSCAR POR HWID${NC}\n"
            
            read -p "HWID a buscar: " HWID
            
            if [[ -n "$HWID" ]]; then
                echo -e "\n${YELLOW}Resultados:${NC}"
                sqlite3 -column -header "$DB" "SELECT username, phone, tipo, expires_at, status FROM users WHERE hwid LIKE '%$HWID%'"
                
                # Verificar archivo .hc
                HC_FILE="/var/www/html/hc/*_${HWID}.hc"
                if ls $HC_FILE 1>/dev/null 2>&1; then
                    echo -e "\n${GREEN}✅ Archivo .hc encontrado${NC}"
                    ls -la $HC_FILE
                else
                    echo -e "\n${RED}❌ No hay archivo .hc${NC}"
                fi
            fi
            read -p "Presiona Enter..."
            ;;
        10)
            clear
            echo -e "${CYAN}📊 ESTADÍSTICAS${NC}\n"
            
            echo -e "${YELLOW}👥 USUARIOS:${NC}"
            sqlite3 "$DB" "SELECT 'Total: ' || COUNT(*) || ' | Activos: ' || SUM(CASE WHEN status=1 THEN 1 ELSE 0 END) || ' | Tests: ' || SUM(CASE WHEN tipo='test' THEN 1 ELSE 0 END) || ' | Premium: ' || SUM(CASE WHEN tipo='premium' THEN 1 ELSE 0 END) FROM users"
            
            echo -e "\n${YELLOW}📅 DISTRIBUCIÓN HWID:${NC}"
            sqlite3 "$DB" "SELECT 'Últimos 7 días: ' || COUNT(*) FROM users WHERE created_at > datetime('now', '-7 days')"
            
            echo -e "\n${YELLOW}💸 INGRESOS:${NC}"
            sqlite3 "$DB" "SELECT 'Hoy: $' || printf('%.2f', SUM(CASE WHEN date(created_at) = date('now') THEN final_amount ELSE 0 END)) FROM payments WHERE status='approved'"
            
            echo -e "\n${YELLOW}📁 ARCHIVOS .HC:${NC}"
            HC_COUNT=$(ls /var/www/html/hc/*.hc 2>/dev/null | wc -l || echo "0")
            echo -e "  Total archivos: $HC_COUNT"
            
            read -p "\nPresiona Enter..."
            ;;
        11)
            echo -e "\n${YELLOW}🧹 Limpiando sesión...${NC}"
            pm2 stop httpcustom-bot
            rm -rf /root/.wppconnect/*
            echo -e "${GREEN}✅ Sesión limpiada${NC}"
            echo -e "${YELLOW}📱 Escanea nuevo QR al iniciar${NC}"
            sleep 2
            ;;
        12)
            clear
            echo -e "${CYAN}⚙️  CONFIGURACIÓN${NC}\n"
            
            echo -e "${YELLOW}🤖 BOT:${NC}"
            echo -e "  IP: $(get_val '.bot.server_ip')"
            echo -e "  Puerto: $(get_val '.bot.server_port')"
            echo -e "  Encriptación: $(get_val '.bot.encryption')"
            echo -e "  Versión: $(get_val '.bot.version')"
            
            echo -e "\n${YELLOW}💰 PRECIOS:${NC}"
            echo -e "  7d: $(get_val '.prices.price_7d') ARS"
            echo -e "  15d: $(get_val '.prices.price_15d') ARS"
            echo -e "  30d: $(get_val '.prices.price_30d') ARS"
            echo -e "  50d: $(get_val '.prices.price_50d') ARS"
            echo -e "  Test: $(get_val '.prices.test_hours') horas"
            
            echo -e "\n${YELLOW}📁 PATHS:${NC}"
            echo -e "  Base de datos: $(get_val '.paths.database')"
            echo -e "  Archivos .hc: $(get_val '.paths.hc_files')"
            echo -e "  QR codes: $(get_val '.paths.qr_codes')"
            
            read -p "\nPresiona Enter..."
            ;;
        13)
            clear
            echo -e "${CYAN}🗑️  ELIMINAR USUARIO${NC}\n"
            
            read -p "Nombre de usuario o HWID: " IDENTIFIER
            
            if [[ -n "$IDENTIFIER" ]]; then
                echo -e "\n${YELLOW}¿Estás seguro de eliminar? (s/N):${NC} "
                read -n 1 -r CONFIRM
                echo
                
                if [[ $CONFIRM =~ ^[Ss]$ ]]; then
                    sqlite3 "$DB" "UPDATE users SET status = 0 WHERE username = '$IDENTIFIER' OR hwid = '$IDENTIFIER'"
                    
                    # Eliminar archivo .hc
                    rm -f "/var/www/html/hc/${IDENTIFIER}.hc" 2>/dev/null
                    rm -f "/var/www/html/hc/*_${IDENTIFIER}.hc" 2>/dev/null
                    rm -f "/opt/httpcustom-bot/hc_files/${IDENTIFIER}.hc" 2>/dev/null
                    rm -f "/opt/httpcustom-bot/hc_files/*_${IDENTIFIER}.hc" 2>/dev/null
                    
                    echo -e "${GREEN}✅ Usuario eliminado${NC}"
                else
                    echo -e "${YELLOW}❌ Cancelado${NC}"
                fi
            fi
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

chmod +x /usr/local/bin/hcbot

echo -e "${GREEN}✅ Panel de control creado${NC}"

# ================================================
# INICIAR BOT
# ================================================
echo -e "\n${CYAN}🚀 Iniciando bot...${NC}"

cd "$USER_HOME"
npm install 2>&1 | grep -v "npm WARN" || true
pm2 start bot.js --name httpcustom-bot
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
║          🎉 INSTALACIÓN COMPLETADA - HTTP CUSTOM BOT       ║
║                                                              ║
║       🤖 WPPConnect + MercadoPago + HWID Sistema          ║
║       📁 Entrega automática de archivos .hc               ║
║       🔑 Sistema de HWID único por dispositivo            ║
║       ⚡ Test 2 horas para HTTP Custom                    ║
║       💳 Pago automático con QR y enlace                 ║
║       📊 Panel de control completo                       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Sistema completo instalado${NC}"
echo -e "${GREEN}✅ WhatsApp API funcionando${NC}"
echo -e "${GREEN}✅ Sistema HWID implementado${NC}"
echo -e "${GREEN}✅ Generador de archivos .hc${NC}"
echo -e "${GREEN}✅ Nginx configurado para descargas${NC}"
echo -e "${GREEN}✅ MercadoPago SDK integrado${NC}"
echo -e "${GREEN}✅ Panel de control completo${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 COMANDOS PRINCIPALES:${NC}\n"
echo -e "  ${GREEN}hcbot${NC}            - Panel de control completo"
echo -e "  ${GREEN}generate-hc${NC}      - Generar archivo .hc manualmente"
echo -e "  ${GREEN}pm2 logs httpcustom-bot${NC} - Ver logs y QR"
echo -e "\n"

echo -e "${YELLOW}🌐 URLs IMPORTANTES:${NC}\n"
echo -e "  📱 Bot: Escanea QR cuando aparezca en logs"
echo -e "  📁 Descargas: http://${SERVER_IP}/hc/"
echo -e "  📊 Panel: Ejecuta 'hcbot' como root"
echo -e "\n"

echo -e "${YELLOW}🚀 PRIMEROS PASOS:${NC}\n"
echo -e "  1. Ver logs: ${GREEN}pm2 logs httpcustom-bot${NC}"
echo -e "  2. Escanear QR cuando aparezca"
echo -e "  3. Enviar 'menu' al bot en WhatsApp"
echo -e "  4. Probar crear test (opción 1)"
echo -e "  5. Configurar MercadoPago: ${GREEN}hcbot → Opción 7${NC}"
echo -e "\n"

echo -e "${YELLOW}📁 ESTRUCTURA DE ARCHIVOS:${NC}\n"
echo -e "  Configuración: ${CYAN}/opt/httpcustom-bot/config/${NC}"
echo -e "  Base de datos: ${CYAN}/opt/httpcustom-bot/data/users.db${NC}"
echo -e "  Archivos .hc: ${CYAN}/opt/httpcustom-bot/hc_files/${NC}"
echo -e "  Descargas públicas: ${CYAN}/var/www/html/hc/${NC}"
echo -e "\n"

# Ver logs automáticamente
read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}Mostrando logs...${NC}"
    echo -e "${YELLOW}📱 Espera que aparezca el QR para escanear...${NC}\n"
    sleep 2
    pm2 logs httpcustom-bot
else
    echo -e "\n${YELLOW}💡 Para iniciar: ${GREEN}hcbot${NC}"
    echo -e "${YELLOW}💡 Para logs: ${GREEN}pm2 logs httpcustom-bot${NC}"
    echo -e "${YELLOW}💡 Para generar .hc: ${GREEN}generate-hc <usuario> <hwid>${NC}\n"
fi

exit 0