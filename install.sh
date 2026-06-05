#!/bin/bash
# ================================================
# SSH BOT PRO - WPPCONNECT + MERCADOPAGO + HWID
# VERSIÓN CON HWID EN /ETC/PASSWD
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
║               🔐 HWID GUARDADOS EN /ETC/PASSWD              ║
║               📱 PRIMERO NOMBRE, LUEGO HWID                 ║
║               💰 MercadoPago SDK v2.x INTEGRADO             ║
║               💳 Pago automático con QR                     ║
║               ⏰ NOTIFICACIONES DE VENCIMIENTO              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CARACTERÍSTICAS PRINCIPALES:${NC}"
echo -e "  🔐 ${CYAN}Sistema HWID${NC} - Guardado en /etc/passwd"
echo -e "  📱 ${CYAN}WPPConnect${NC} - API WhatsApp que funciona"
echo -e "  💰 ${GREEN}MercadoPago SDK v2.x${NC} - Integrado completo"
echo -e "  💳 ${YELLOW}Pago automático${NC} - QR + Enlace de pago"
echo -e "  📝 ${PURPLE}Flujo mejorado${NC} - Primero nombre, luego HWID"
echo -e "  🎛️  ${PURPLE}Panel completo${NC} - Control total del sistema"
echo -e "  ⏰ ${CYAN}NOTIFICACIONES DE VENCIMIENTO${NC} - Avisos automáticos"
echo -e "  📁 ${GREEN}HWIDs en sistema Linux${NC} - Compatible con servicios SSH"
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
DB_FILE="$INSTALL_DIR/data/hwid.db"
CONFIG_FILE="$INSTALL_DIR/config/config.json"

# Limpiar anterior
pm2 delete sshbot-pro 2>/dev/null || true
rm -rf "$INSTALL_DIR" "$USER_HOME" 2>/dev/null || true
rm -rf /root/.wppconnect 2>/dev/null || true

# Crear directorios
mkdir -p "$INSTALL_DIR"/{data,config,sessions,logs,qr_codes}
mkdir -p "$USER_HOME"
mkdir -p /root/.wppconnect
mkdir -p /etc/ssh-hwids
chmod -R 755 "$INSTALL_DIR"
chmod -R 700 /root/.wppconnect

cat > "$CONFIG_FILE" << EOF
{
    "bot": {
        "name": "SSH Bot Pro HWID",
        "version": "3.0-HWID",
        "server_ip": "$SERVER_IP"
    },
    "prices": {
        "test_hours": 2,
        "price_7d": 3000.00,
        "price_15d": 4000.00,
        "price_30d": 7000.00,
        "price_50d": 9700.00,
        "currency": "ARS"
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false,
        "public_key": ""
    },
    "links": {
        "app_download": "https://play.google.com/store/apps/details?id=google.android.b6",
        "support": "https://wa.me/54"
    },
    "paths": {
        "database": "$DB_FILE",
        "qr_codes": "$INSTALL_DIR/qr_codes",
        "sessions": "/root/.wppconnect",
        "hwid_storage": "/etc/ssh-hwids"
    }
}
EOF

# Crear base de datos para registro de pagos y logs (sin HWIDs duplicados)
sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_id TEXT UNIQUE,
    phone TEXT,
    nombre TEXT,
    plan TEXT,
    days INTEGER,
    amount REAL,
    status TEXT DEFAULT 'pending',
    payment_url TEXT,
    qr_code TEXT,
    preference_id TEXT,
    hwid TEXT,
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
CREATE TABLE hwid_attempts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hwid TEXT,
    phone TEXT,
    nombre TEXT,
    action TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE daily_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    nombre TEXT,
    date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(phone, date)
);
CREATE INDEX idx_payments_hwid ON payments(hwid);
CREATE INDEX idx_payments_status ON payments(status);
SQL

echo -e "${GREEN}✅ Estructura creada${NC}"

# ================================================
# FUNCIONES PARA MANEJAR HWID EN /ETC/PASSWD
# ================================================

# Crear script de gestión de HWIDs en /etc/passwd
cat > /usr/local/bin/hwid-manager << 'HWIDMANAGER'
#!/bin/bash
# ================================================
# GESTOR DE HWIDS - INTEGRACIÓN CON /ETC/PASSWD
# ================================================

HWID_DIR="/etc/ssh-hwids"
PASSWD_FILE="/etc/passwd"
SHADOW_FILE="/etc/shadow"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Validar formato HWID
validate_hwid() {
    [[ "$1" =~ ^APP-[A-F0-9]{16}$ ]]
}

# Normalizar HWID
normalize_hwid() {
    echo "$1" | tr 'a-z' 'A-Z'
    if [[ ! "$1" =~ ^APP- ]]; then
        echo "APP-$1"
    else
        echo "$1"
    fi
}

# Verificar si HWID existe en sistema
hwid_exists() {
    local hwid=$(normalize_hwid "$1")
    grep -q "^${hwid}:" "$PASSWD_FILE" 2>/dev/null
}

# Obtener información de HWID
get_hwid_info() {
    local hwid=$(normalize_hwid "$1")
    grep "^${hwid}:" "$PASSWD_FILE" 2>/dev/null | cut -d: -f1,5
}

# Obtener expiración de HWID
get_hwid_expiry() {
    local hwid=$(normalize_hwid "$1")
    local expiry_file="$HWID_DIR/${hwid}.expiry"
    if [[ -f "$expiry_file" ]]; then
        cat "$expiry_file"
    else
        echo ""
    fi
}

# Registrar HWID en sistema
register_hwid() {
    local hwid=$(normalize_hwid "$1")
    local nombre="$2"
    local expiry_date="$3"
    local phone="$4"
    
    # Verificar si ya existe
    if hwid_exists "$hwid"; then
        return 1
    fi
    
    # Crear usuario en sistema (sin login, solo para identificación)
    # Formato: hwid:x:UID:GID:nombre:/home/hwid:/sbin/nologin
    local uid=2000
    while id -u $uid &>/dev/null; do
        uid=$((uid + 1))
    done
    
    useradd -r -M -s /sbin/nologin -u "$uid" -c "$nombre|$phone" "$hwid" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        # Guardar fecha de expiración
        echo "$expiry_date" > "$HWID_DIR/${hwid}.expiry"
        echo "$nombre" > "$HWID_DIR/${hwid}.name"
        echo "$phone" > "$HWID_DIR/${hwid}.phone"
        echo "$expiry_date" > "$HWID_DIR/${hwid}.expiry"
        
        # Configurar expiración de usuario (si está disponible)
        if command -v chage &>/dev/null; then
            local expiry_unix=$(date -d "$expiry_date" +%Y-%m-%d 2>/dev/null)
            [[ -n "$expiry_unix" ]] && chage -E "$expiry_unix" "$hwid" 2>/dev/null
        fi
        
        echo "✅ HWID registrado: $hwid"
        return 0
    fi
    
    return 1
}

# Actualizar HWID existente
update_hwid() {
    local hwid=$(normalize_hwid "$1")
    local nombre="$2"
    local expiry_date="$3"
    local phone="$4"
    
    if ! hwid_exists "$hwid"; then
        return 1
    fi
    
    # Actualizar información del usuario
    usermod -c "$nombre|$phone" "$hwid" 2>/dev/null
    
    # Actualizar archivos
    echo "$expiry_date" > "$HWID_DIR/${hwid}.expiry"
    echo "$nombre" > "$HWID_DIR/${hwid}.name"
    echo "$phone" > "$HWID_DIR/${hwid}.phone"
    
    # Actualizar expiración
    if command -v chage &>/dev/null; then
        local expiry_unix=$(date -d "$expiry_date" +%Y-%m-%d 2>/dev/null)
        [[ -n "$expiry_unix" ]] && chage -E "$expiry_unix" "$hwid" 2>/dev/null
    fi
    
    echo "✅ HWID actualizado: $hwid"
    return 0
}

# Eliminar HWID del sistema
delete_hwid() {
    local hwid=$(normalize_hwid "$1")
    
    if hwid_exists "$hwid"; then
        userdel -r "$hwid" 2>/dev/null
        rm -f "$HWID_DIR/${hwid}".*
        echo "✅ HWID eliminado: $hwid"
        return 0
    fi
    
    return 1
}

# Listar HWIDs activos
list_hwids() {
    echo -e "${CYAN}HWIDs activos en el sistema:${NC}\n"
    printf "%-30s %-20s %-20s %s\n" "HWID" "NOMBRE" "TELÉFONO" "EXPIRA"
    echo "--------------------------------------------------------------------------------"
    
    for user in $(grep -E '^APP-[A-F0-9]{16}:' "$PASSWD_FILE" | cut -d: -f1); do
        local name_file="$HWID_DIR/${user}.name"
        local phone_file="$HWID_DIR/${user}.phone"
        local expiry_file="$HWID_DIR/${user}.expiry"
        
        local nombre=$(cat "$name_file" 2>/dev/null || echo "?")
        local phone=$(cat "$phone_file" 2>/dev/null || echo "?")
        local expiry=$(cat "$expiry_file" 2>/dev/null || echo "?")
        
        printf "%-30s %-20s %-20s %s\n" "$user" "$nombre" "$phone" "$expiry"
    done
}

# Verificar si HWID está activo (no expirado)
is_hwid_active() {
    local hwid=$(normalize_hwid "$1")
    local expiry_file="$HWID_DIR/${hwid}.expiry"
    
    if [[ ! -f "$expiry_file" ]]; then
        return 1
    fi
    
    local expiry_date=$(cat "$expiry_file")
    local now=$(date +%s)
    local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
    
    if [[ -n "$expiry_epoch" ]] && [[ $expiry_epoch -gt $now ]]; then
        return 0
    fi
    
    return 1
}

# Limpiar HWIDs expirados
clean_expired() {
    local now=$(date +%s)
    local cleaned=0
    
    for user in $(grep -E '^APP-[A-F0-9]{16}:' "$PASSWD_FILE" | cut -d: -f1); do
        local expiry_file="$HWID_DIR/${user}.expiry"
        
        if [[ -f "$expiry_file" ]]; then
            local expiry_date=$(cat "$expiry_file")
            local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
            
            if [[ -n "$expiry_epoch" ]] && [[ $expiry_epoch -le $now ]]; then
                echo "🧹 Eliminando HWID expirado: $user"
                delete_hwid "$user"
                cleaned=$((cleaned + 1))
            fi
        fi
    done
    
    echo "✅ $cleaned HWIDs expirados eliminados"
}

# Mostrar menú
case "$1" in
    register)
        register_hwid "$2" "$3" "$4" "$5"
        ;;
    update)
        update_hwid "$2" "$3" "$4" "$5"
        ;;
    delete)
        delete_hwid "$2"
        ;;
    list)
        list_hwids
        ;;
    check)
        if is_hwid_active "$2"; then
            echo "active"
        else
            echo "inactive"
        fi
        ;;
    info)
        get_hwid_info "$2"
        ;;
    expiry)
        get_hwid_expiry "$2"
        ;;
    clean)
        clean_expired
        ;;
    exists)
        if hwid_exists "$2"; then
            echo "true"
        else
            echo "false"
        fi
        ;;
    *)
        echo "Uso: hwid-manager {register|update|delete|list|check|info|expiry|clean|exists} [hwid] [nombre] [expiry] [phone]"
        exit 1
        ;;
esac
HWIDMANAGER

chmod +x /usr/local/bin/hwid-manager

# ================================================
# CREAR BOT CON HWID (PRIMERO NOMBRE, LUEGO HWID)
# ================================================
echo -e "\n${CYAN}🤖 Creando bot con sistema HWID (almacenamiento en /etc/passwd)...${NC}"

cd "$USER_HOME"

# package.json
cat > package.json << 'PKGEOF'
{
    "name": "sshbot-pro-hwid",
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

echo -e "${YELLOW}📦 Instalando dependencias...${NC}"
npm install --silent 2>&1 | grep -v "npm WARN" || true

# Crear bot.js con HWID (flujo nombre -> HWID) - CON INTEGRACIÓN A /ETC/PASSWD
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
console.log(chalk.cyan.bold('║           🤖 SSH BOT PRO - HWID + MERCADOPAGO                ║'));
console.log(chalk.cyan.bold('║           📝 FLUJO: PRIMERO NOMBRE, LUEGO HWID                ║'));
console.log(chalk.cyan.bold('║           📁 HWIDS GUARDADOS EN /ETC/PASSWD                   ║'));
console.log(chalk.cyan.bold('║           ⏱️  PRUEBA: 2 HORAS                                 ║'));
console.log(chalk.cyan.bold('║           ⏰ NOTIFICACIONES DE VENCIMIENTO                    ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

// Cargar configuración
function loadConfig() {
    delete require.cache[require.resolve('/opt/sshbot-pro/config/config.json')];
    return require('/opt/sshbot-pro/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/sshbot-pro/data/hwid.db');

// ✅ FUNCIONES PARA HWID CON INTEGRACIÓN A /etc/passwd
function validateHWID(hwid) {
    const hwidRegex = /^APP-[A-F0-9]{16}$/;
    return hwidRegex.test(hwid);
}

function normalizeHWID(hwid) {
    hwid = hwid.trim().toUpperCase();
    if (!hwid.startsWith('APP-')) {
        hwid = 'APP-' + hwid.replace(/[^A-F0-9]/g, '');
    }
    return hwid;
}

async function execCommand(cmd) {
    try {
        const { stdout, stderr } = await execPromise(cmd);
        return { success: true, stdout: stdout.trim(), stderr: stderr.trim() };
    } catch (error) {
        return { success: false, error: error.message };
    }
}

async function hwidExists(hwid) {
    const result = await execCommand(`/usr/local/bin/hwid-manager exists "${hwid}"`);
    return result.success && result.stdout === 'true';
}

async function isHWIDActive(hwid) {
    const result = await execCommand(`/usr/local/bin/hwid-manager check "${hwid}"`);
    return result.success && result.stdout === 'active';
}

async function getHWIDInfo(hwid) {
    const info = await execCommand(`/usr/local/bin/hwid-manager info "${hwid}"`);
    const expiry = await execCommand(`/usr/local/bin/hwid-manager expiry "${hwid}"`);
    
    if (info.success && info.stdout) {
        const parts = info.stdout.split(':');
        return {
            hwid: hwid,
            nombre: parts[1] || 'Usuario',
            expires_at: expiry.stdout || null
        };
    }
    return null;
}

async function registerHWIDinSystem(hwid, nombre, expiryDate, phone) {
    const result = await execCommand(
        `/usr/local/bin/hwid-manager register "${hwid}" "${nombre}" "${expiryDate}" "${phone}"`
    );
    return result.success;
}

async function updateHWIDinSystem(hwid, nombre, expiryDate, phone) {
    const result = await execCommand(
        `/usr/local/bin/hwid-manager update "${hwid}" "${nombre}" "${expiryDate}" "${phone}"`
    );
    return result.success;
}

async function deleteHWIDfromSystem(hwid) {
    const result = await execCommand(`/usr/local/bin/hwid-manager delete "${hwid}"`);
    return result.success;
}

async function registerHWID(phone, nombre, hwid, days, tipo = 'premium') {
    try {
        // Verificar si HWID ya existe
        const exists = await hwidExists(hwid);
        
        let expireFull;
        if (days === 0) {
            expireFull = moment().add(2, 'hours').format('YYYY-MM-DD HH:mm:ss');
            console.log(chalk.cyan(`⏱️  Prueba 2 horas - Expira: ${expireFull}`));
        } else {
            expireFull = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
        }
        
        let registered = false;
        if (exists) {
            // Actualizar HWID existente
            registered = await updateHWIDinSystem(hwid, nombre, expireFull, phone);
        } else {
            // Registrar nuevo HWID
            registered = await registerHWIDinSystem(hwid, nombre, expireFull, phone);
        }
        
        if (registered) {
            // Registrar en BD de pagos/logs
            db.run(
                `INSERT OR REPLACE INTO hwid_attempts (hwid, phone, nombre, action, created_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)`,
                [hwid, phone, nombre, days === 0 ? 'test_registered' : 'premium_registered']
            );
            
            return { 
                success: true, 
                hwid,
                nombre,
                expires: expireFull,
                tipo
            };
        }
        
        return { success: false, error: 'Error al registrar en el sistema' };
        
    } catch (error) {
        console.error(chalk.red('❌ Error registrando HWID:'), error.message);
        return { success: false, error: error.message };
    }
}

function canCreateTest(phone) {
    return new Promise((resolve) => {
        const today = moment().format('YYYY-MM-DD');
        db.get('SELECT COUNT(*) as count FROM daily_tests WHERE phone = ? AND date = ?', 
            [phone, today], (err, row) => resolve(!err && row && row.count === 0));
    });
}

function registerTest(phone, nombre) {
    db.run('INSERT OR IGNORE INTO daily_tests (phone, nombre, date) VALUES (?, ?, ?)', 
        [phone, nombre, moment().format('YYYY-MM-DD')]);
}

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

// ✅ MERCADOPAGO - CREAR PAGO
async function createMercadoPagoPayment(phone, days, amount, planName) {
    try {
        if (!mpEnabled || !mpPreference) {
            return { success: false, error: 'MercadoPago no configurado' };
        }
        
        const phoneClean = phone.replace('@c.us', '');
        const paymentId = `HWID-${phoneClean}-${days}d-${Date.now()}`;
        
        console.log(chalk.cyan(`🔄 Creando pago MP: ${paymentId}`));
        
        const expirationDate = moment().add(24, 'hours');
        const isoDate = expirationDate.toISOString();
        
        const preferenceData = {
            items: [{
                title: `HWID SSH PREMIUM ${days} DÍAS`,
                description: `Activación HWID SSH por ${days} días - SIN USUARIO/CONTRASEÑA`,
                quantity: 1,
                currency_id: config.prices.currency || 'ARS',
                unit_price: parseFloat(amount)
            }],
            external_reference: paymentId,
            expires: true,
            expiration_date_from: moment().toISOString(),
            expiration_date_to: isoDate,
            back_urls: {
                success: `https://wa.me/${phoneClean}?text=Ya%20pague%20hwid`,
                failure: `https://wa.me/${phoneClean}?text=Pago%20fallido%20hwid`,
                pending: `https://wa.me/${phoneClean}?text=Pago%20pendiente%20hwid`
            },
            auto_return: 'approved',
            statement_descriptor: 'HWID SSH'
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
                `INSERT INTO payments (payment_id, phone, plan, days, amount, status, payment_url, qr_code, preference_id) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
                [paymentId, phone, `${days}d`, days, amount, paymentUrl, qrPath, response.id]
            );
            
            return { 
                success: true, 
                paymentId, 
                paymentUrl, 
                qrPath,
                amount: parseFloat(amount)
            };
        }
        
        throw new Error('Respuesta inválida de MercadoPago');
        
    } catch (error) {
        console.error(chalk.red('❌ Error MercadoPago:'), error.message);
        return { success: false, error: error.message };
    }
}

// ✅ VERIFICAR PAGOS PENDIENTES
async function checkPendingPayments() {
    if (!mpEnabled) return;
    
    db.all('SELECT * FROM payments WHERE status = "pending" AND created_at > datetime("now", "-48 hours")', 
        async (err, payments) => {
        if (err || !payments || payments.length === 0) return;
        
        console.log(chalk.yellow(`🔍 Verificando ${payments.length} pagos...`));
        
        for (const payment of payments) {
            try {
                const url = `https://api.mercadopago.com/v1/payments/search?external_reference=${payment.payment_id}`;
                const response = await axios.get(url, {
                    headers: { 
                        'Authorization': `Bearer ${config.mercadopago.access_token}`
                    },
                    timeout: 15000
                });
                
                if (response.data && response.data.results && response.data.results.length > 0) {
                    const mpPayment = response.data.results[0];
                    
                    console.log(chalk.cyan(`📋 Pago ${payment.payment_id}: ${mpPayment.status}`));
                    
                    if (mpPayment.status === 'approved') {
                        console.log(chalk.green(`✅ PAGO APROBADO: ${payment.payment_id}`));
                        
                        db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`, 
                            [payment.payment_id]);
                        
                        const message = `✅ PAGO CONFIRMADO

🎉 Tu pago ha sido aprobado

📝 PRIMERO, ESCRIBE TU NOMBRE:
Para continuar con la activación, dime tu nombre

⏳ Tienes 30 minutos para completar el proceso`;
                        
                        if (client) {
                            await client.sendText(payment.phone, message);
                            await setUserState(payment.phone, 'awaiting_hwid', { 
                                payment_id: payment.payment_id,
                                days: payment.days,
                                plan: payment.plan
                            });
                        }
                    }
                }
            } catch (error) {
                console.error(chalk.red(`❌ Error verificando ${payment.payment_id}:`), error.message);
            }
        }
    });
}

// ✅ NOTIFICACIONES DE VENCIMIENTO
async function checkExpiringHWIDs() {
    try {
        const { stdout } = await execPromise('/usr/local/bin/hwid-manager list');
        const lines = stdout.split('\n');
        
        for (const line of lines) {
            if (line.includes('APP-')) {
                const parts = line.split(/\s+/);
                const hwid = parts[0];
                const nombre = parts[1] || 'Usuario';
                const phone = parts[2] || '';
                const expiryStr = parts[3] || '';
                
                if (expiryStr && phone) {
                    const expiryMoment = moment(expiryStr, 'YYYY-MM-DD HH:mm:ss');
                    const hoursLeft = expiryMoment.diff(moment(), 'hours');
                    
                    if (hoursLeft > 0 && hoursLeft <= 24) {
                        const message = `⏰ RECORDATORIO DE VENCIMIENTO

Hola ${nombre}, tu acceso expirará en aproximadamente ${hoursLeft} horas.

🔐 HWID: ${hwid}
⏰ Fecha de vencimiento: ${expiryMoment.format('DD/MM/YYYY HH:mm')}

💰 Para renovar, envía 2 y elige tu plan.

¡No te quedes sin servicio!`;
                        
                        if (client && phone) {
                            await client.sendText(phone, message);
                            console.log(chalk.yellow(`📨 Notificación enviada a ${nombre} - Expira en ${hoursLeft} horas`));
                        }
                    }
                }
            }
        }
    } catch (error) {
        console.error(chalk.red('❌ Error en notificaciones de vencimiento:'), error.message);
    }
}

// Inicializar WPPConnect
async function initializeBot() {
    try {
        console.log(chalk.yellow('🚀 Inicializando WPPConnect...'));
        
        client = await wppconnect.create({
            session: 'sshbot-pro-hwid',
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
                '--window-size=1920,1080'
            ],
            puppeteerOptions: {
                executablePath: '/usr/bin/google-chrome',
                headless: 'new',
                args: ['--no-sandbox', '--disable-setuid-sandbox']
            },
            disableWelcome: true,
            updatesLog: false,
            folderNameToken: '/root/.wppconnect'
        });
        
        console.log(chalk.green('✅ WPPConnect conectado!'));
        
        client.onStateChange((state) => {
            console.log(chalk.cyan(`📱 Estado: ${state}`));
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
                    
                    await client.sendText(from, `HOLA BIENVENIDO BOT 🤖

Elija una opción:

 1️⃣ - PROBAR INTERNET (2 horas gratis)
 2️⃣ - COMPRAR INTERNET
 3️⃣ - VERIFICAR MI HWID
 4️⃣ - DESCARGAR APLICACIÓN`);
                }
                
                // OPCIÓN 1: PRUEBA
                else if (text === '1' && userState.state === 'main_menu') {
                    await setUserState(from, 'awaiting_test_nombre');
                    
                    await client.sendText(from, `⏳️ PRUEBA GRATUITA - 2 HORAS

Primero, dime tu nombre:`);
                }
                
                // OPCIÓN 2: COMPRAR
                else if (text === '2' && userState.state === 'main_menu') {
                    await setUserState(from, 'buying_hwid');
                    
                    await client.sendText(from, `💰 PLANES DE INTERNET

Selecciona un plan:

 1️⃣ - 7 DÍAS - $${config.prices.price_7d}
 2️⃣ - 15 DÍAS - $${config.prices.price_15d}
 3️⃣ - 30 DÍAS - $${config.prices.price_30d}
 4️⃣ - 50 DÍAS - $${config.prices.price_50d}

 0️⃣ - VOLVER

💳 Pago con MercadoPago`);
                }
                
                // OPCIÓN 3: VERIFICAR HWID
                else if (text === '3' && userState.state === 'main_menu') {
                    await setUserState(from, 'awaiting_check_hwid');
                    
                    await client.sendText(from, `🔍 VERIFICAR HWID

Envía tu HWID para verificar si está activo:

Ejemplo: APP-E3E4D5CBB7636907`);
                }
                
                // OPCIÓN 4: DESCARGAR APP
                else if (text === '4' && userState.state === 'main_menu') {
                    await client.sendText(from, `📱 DESCARGAR APLICACIÓN

🔗 Enlace:
${config.links.app_download}

💡 Instrucciones:
1. Abre el link descarga la app
2. Abre la app y copia tu HWID
3. Vuelve aquí para activarlo`);
                }
                
                // PROCESAR NOMBRE PARA PRUEBA
                else if (userState.state === 'awaiting_test_nombre') {
                    const nombre = message.body.trim();
                    
                    if (nombre.length < 2) {
                        await client.sendText(from, '❌ El nombre debe tener al menos 2 caracteres. Intenta de nuevo:');
                        return;
                    }
                    
                    await setUserState(from, 'awaiting_test_hwid', { nombre });
                    
                    await client.sendText(from, `✅ Gracias ${nombre}

Ahora envía tu HWID para activar la prueba (2 horas):

Formato: APP-E3E4D5CBB7636907

📱 ¿CÓMO OBTENER TU HWID?
1. Abre la aplicación
2. Copia el hwid
3. Envíalo aquí

⏳ Una prueba por día`);
                }
                
                // PROCESAR HWID PARA PRUEBA
                else if (userState.state === 'awaiting_test_hwid') {
                    const rawHwid = message.body;
                    const hwid = normalizeHWID(rawHwid);
                    const nombre = userState.data.nombre;
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ HWID INVÁLIDO

Formato correcto: APP-E3E4D5CBB7636907

Envía el HWID nuevamente o escribe MENU para volver`);
                        return;
                    }
                    
                    if (!(await canCreateTest(from))) {
                        await client.sendText(from, `❌ YA USASTE TU PRUEBA HOY

⏳ Vuelve mañana o compra un plan`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    const active = await isHWIDActive(hwid);
                    if (active) {
                        await client.sendText(from, `❌ Este HWID ya está activo en el sistema

Si crees que es un error, contacta soporte.`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    await client.sendText(from, '⏳ Activando prueba (2 horas)...');
                    
                    const result = await registerHWID(from, nombre, hwid, 0, 'test');
                    
                    if (result.success) {
                        registerTest(from, nombre);
                        
                        const expireTime = moment(result.expires).format('HH:mm DD/MM/YYYY');
                        
                        await client.sendText(from, `✅ PRUEBA ACTIVADA ${nombre}

🔐 HWID: ${hwid}
⏰ Expira: ${expireTime}
⚡ Tipo: PRUEBA (2 horas)

📱 Abre la aplicación y ya puedes conectarte

⚠️ El HWID quedó registrado en el sistema Linux (/etc/passwd)`);
                        
                        console.log(chalk.green(`✅ HWID test: ${hwid} - ${nombre} - Expira: ${result.expires}`));
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
                // PROCESAR PLAN DE COMPRA
                else if (userState.state === 'buying_hwid' && ['1','2','3','4'].includes(text)) {
                    const planMap = {
                        '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                        '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' },
                        '3': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                        '4': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                    };
                    
                    const plan = planMap[text];
                    
                    if (mpEnabled) {
                        await client.sendText(from, '⏳ Generando pago...');
                        
                        const payment = await createMercadoPagoPayment(
                            from, 
                            plan.days, 
                            plan.price, 
                            plan.name
                        );
                        
                        if (payment.success) {
                            const message = `💰 PAGO PARA HWID

- 🌐 Plan: ${plan.name}
- 💰 Precio: $${payment.amount}
- 🕜 Duración: ${plan.days} días

LINK DE PAGO:
${payment.paymentUrl}

⏰ Válido por 24 horas

📌 DESPUÉS DE PAGAR:
1. Espera la confirmación
2. Te pediremos tu nombre
3. Luego tu HWID
4. Se activará automáticamente en /etc/passwd`;
                            
                            await client.sendText(from, message);
                            
                            if (fs.existsSync(payment.qrPath)) {
                                try {
                                    await client.sendImage(from, payment.qrPath, 'qr-pago.jpg', 
                                        `Escanea con MercadoPago\n\n${plan.name} - $${payment.amount}`);
                                } catch (qrError) {
                                    console.error(chalk.red('⚠️ Error QR:'), qrError.message);
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
                
                else if (text === '0' && userState.state === 'buying_hwid') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, `HOLA BIENVENIDO BOT HWID 🤖

Elija una opción:

 1️⃣ - PROBAR INTERNET (2 horas gratis)
 2️⃣ - COMPRAR INTERNET
 3️⃣ - VERIFICAR MI HWID
 4️⃣ - DESCARGAR APLICACIÓN`);
                }
                
                // PROCESAR HWID PARA VERIFICACIÓN
                else if (userState.state === 'awaiting_check_hwid') {
                    const rawHwid = message.body;
                    const hwid = normalizeHWID(rawHwid);
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ Formato inválido

Ejemplo: APP-E3E4D5CBB7636907

Intenta nuevamente o MENU`);
                        return;
                    }
                    
                    const active = await isHWIDActive(hwid);
                    const info = await getHWIDInfo(hwid);
                    
                    if (active && info && info.expires_at) {
                        const expires = moment(info.expires_at).format('DD/MM/YYYY HH:mm');
                        const remaining = moment(info.expires_at).fromNow();
                        await client.sendText(from, `✅ HWID ACTIVO

👤 Usuario: ${info.nombre || 'Usuario'}
🔐 HWID: ${hwid}
⏰ Válido hasta: ${expires}
⌛ Tiempo restante: ${remaining}
📁 Registrado en: /etc/passwd`);
                    } else {
                        await client.sendText(from, `❌ HWID NO ACTIVO O NO REGISTRADO

Este HWID no está activo en el sistema.

¿Quieres probar el servicio?
Envía 1 para prueba gratis (2 horas)`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
                // ESPERANDO NOMBRE Y HWID DESPUÉS DE PAGO
                else if (userState.state === 'awaiting_hwid') {
                    if (!userState.data.nombre) {
                        const nombre = message.body.trim();
                        
                        if (nombre.length < 2) {
                            await client.sendText(from, '❌ El nombre debe tener al menos 2 caracteres. Intenta de nuevo:');
                            return;
                        }
                        
                        userState.data.nombre = nombre;
                        await setUserState(from, 'awaiting_hwid', userState.data);
                        
                        await client.sendText(from, `✅ Gracias ${nombre}

Ahora envía tu HWID:
Formato: APP-E3E4D5CBB7636907

📱 ¿CÓMO OBTENER TU HWID?
1. Abre la aplicación
2. Copia el código HWID
3. Envíalo aquí`);
                        
                        return;
                    }
                    
                    const rawHwid = message.body;
                    const hwid = normalizeHWID(rawHwid);
                    const nombre = userState.data.nombre;
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ FORMATO INCORRECTO

Ejemplo: APP-E3E4D5CBB7636907

Envía el HWID nuevamente:`);
                        return;
                    }
                    
                    const active = await isHWIDActive(hwid);
                    if (active) {
                        await client.sendText(from, `❌ Este HWID ya está activo

Si es tuyo, contacta soporte.`);
                        return;
                    }
                    
                    await client.sendText(from, '⏳ Activando tu HWID en el sistema...');
                    
                    const result = await registerHWID(
                        from, 
                        nombre,
                        hwid, 
                        userState.data.days, 
                        'premium'
                    );
                    
                    if (result.success) {
                        db.run(`UPDATE payments SET hwid = ?, nombre = ? WHERE payment_id = ?`,
                            [hwid, nombre, userState.data.payment_id]);
                        
                        const expireDate = moment(result.expires).format('DD/MM/YYYY');
                        
                        await client.sendText(from, `✅ ¡ACTIVADO ${nombre}!

🔐 HWID: ${hwid}
⏰ Válido hasta: ${expireDate}
📁 Registrado en: /etc/passwd

¡Ya puedes usar la aplicación!`);
                        
                        console.log(chalk.green(`✅ HWID premium: ${hwid} - ${nombre} - Registrado en /etc/passwd`));
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    
                    await setUserState(from, 'main_menu');
                }
                
            } catch (error) {
                console.error(chalk.red('❌ Error procesando mensaje:'), error.message);
            }
        });
        
        // VERIFICAR PAGOS CADA 2 MINUTOS
        cron.schedule('*/2 * * * *', () => {
            console.log(chalk.yellow('🔄 Verificando pagos pendientes...'));
            checkPendingPayments();
        });
        
        // NOTIFICACIONES DE VENCIMIENTO CADA HORA
        cron.schedule('0 * * * *', () => {
            console.log(chalk.yellow('⏰ Verificando HWIDs próximos a vencer...'));
            checkExpiringHWIDs();
        });
        
        // LIMPIAR HWIDS EXPIRADOS CADA 15 MINUTOS
        cron.schedule('*/15 * * * *', async () => {
            console.log(chalk.yellow('🧹 Limpiando HWIDs expirados del sistema...'));
            await execPromise('/usr/local/bin/hwid-manager clean');
        });
        
        // LIMPIAR ESTADOS CADA HORA
        cron.schedule('0 * * * *', () => {
            db.run(`DELETE FROM user_state WHERE updated_at < datetime('now', '-1 hour')`);
        });
        
    } catch (error) {
        console.error(chalk.red('❌ Error inicializando:'), error.message);
        console.log(chalk.yellow('🔄 Reintentando en 10 segundos...'));
        setTimeout(initializeBot, 10000);
    }
}

// Iniciar
initializeBot();

process.on('SIGINT', async () => {
    console.log(chalk.yellow('\n🛑 Cerrando bot...'));
    if (client) {
        await client.close();
    }
    process.exit();
});
BOTEOF

echo -e "${GREEN}✅ Bot HWID creado con integración a /etc/passwd${NC}"

# ================================================
# CREAR PANEL DE CONTROL PARA HWID
# ================================================
echo -e "\n${CYAN}🎛️  Creando panel de control HWID...${NC}"

cat > /usr/local/bin/sshbot-hwid << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; NC='\033[0m'

DB="/opt/sshbot-pro/data/hwid.db"
CONFIG="/opt/sshbot-pro/config/config.json"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }
set_val() { local t=$(mktemp); jq "$1 = $2" "$CONFIG" > "$t" && mv "$t" "$CONFIG"; }

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
        return 0
    else
        echo -e "${RED}❌ ERROR - Código: $HTTP_CODE${NC}"
        return 1
    fi
}

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           🎛️  PANEL SSH BOT PRO - VERSIÓN HWID              ║${NC}"
    echo -e "${CYAN}║              📁 HWIDs EN /ETC/PASSWD                         ║${NC}"
    echo -e "${CYAN}║              ⏱️  PRUEBA: 2 HORAS                            ║${NC}"
    echo -e "${CYAN}║              ⏰ NOTIFICACIONES DE VENCIMIENTO               ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

while true; do
    show_header
    
    TOTAL_HWID=$(grep -c '^APP-[A-F0-9]\{16\}:' /etc/passwd 2>/dev/null || echo "0")
    ACTIVE_HWID=$(/usr/local/bin/hwid-manager list | grep -c 'APP-' 2>/dev/null || echo "0")
    PENDING_PAYMENTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='pending'" 2>/dev/null || echo "0")
    APPROVED_PAYMENTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='approved'" 2>/dev/null || echo "0")
    TESTS_TODAY=$(sqlite3 "$DB" "SELECT COUNT(*) FROM daily_tests WHERE date = date('now')" 2>/dev/null || echo "0")
    
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
    
    echo -e "${YELLOW}📊 ESTADO DEL SISTEMA${NC}"
    echo -e "  Bot: $BOT_STATUS"
    echo -e "  HWIDs: ${CYAN}$ACTIVE_HWID/$TOTAL_HWID${NC} activos/total (en /etc/passwd)"
    echo -e "  Tests hoy: ${CYAN}$TESTS_TODAY${NC}"
    echo -e "  Pagos: ${CYAN}$PENDING_PAYMENTS${NC} pend | ${GREEN}$APPROVED_PAYMENTS${NC} aprob"
    echo -e "  MercadoPago: $MP_STATUS"
    echo -e "  IP: $(get_val '.bot.server_ip')"
    echo -e "  ⏱️  Prueba: ${YELLOW}2 HORAS${NC}"
    echo -e "  📁  Almacenamiento: ${CYAN}/etc/passwd${NC}"
    echo -e ""
    
    echo -e "${YELLOW}💰 PRECIOS ACTUALES:${NC}"
    echo -e "  7 días: $ $(get_val '.prices.price_7d') ARS"
    echo -e "  15 días: $ $(get_val '.prices.price_15d') ARS"
    echo -e "  30 días: $ $(get_val '.prices.price_30d') ARS"
    echo -e "  50 días: $ $(get_val '.prices.price_50d') ARS"
    echo -e ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC} 🚀  Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC} 🛑  Detener bot"
    echo -e "${CYAN}[3]${NC} 📱  Ver logs y QR"
    echo -e "${CYAN}[4]${NC} 🔐  Registrar HWID manual (en /etc/passwd)"
    echo -e "${CYAN}[5]${NC} 👥  Listar HWIDs activos"
    echo -e "${CYAN}[6]${NC} 💰  Cambiar precios"
    echo -e "${CYAN}[7]${NC} 🔑  Configurar MercadoPago"
    echo -e "${CYAN}[8]${NC} 🧪  Test MercadoPago"
    echo -e "${CYAN}[9]${NC} 📊  Estadísticas"
    echo -e "${CYAN}[10]${NC} 🔄 Limpiar sesión"
    echo -e "${CYAN}[11]${NC} 💳 Ver pagos"
    echo -e "${CYAN}[12]${NC} 🔍 Buscar HWID"
    echo -e "${CYAN}[13]${NC} 🧪 Ver tests hoy"
    echo -e "${CYAN}[14]${NC} 🗑️  Eliminar HWID expirados"
    echo -e "${CYAN}[15]${NC} 📁 Ver /etc/passwd (HWIDs)"
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
            echo -e "${CYAN}🔐 REGISTRAR HWID MANUAL EN /ETC/PASSWD${NC}\n"
            
            read -p "Teléfono (ej: 5491122334455): " PHONE
            read -p "Nombre del usuario: " NOMBRE
            read -p "HWID (formato: APP-E3E4D5CBB7636907): " HWID
            read -p "Tipo (test/premium): " TIPO
            read -p "Días (0=test 2h, 7,15,30,50): " DAYS
            
            [[ -z "$DAYS" ]] && DAYS="30"
            
            HWID=$(echo "$HWID" | tr 'a-z' 'A-Z')
            if [[ ! "$HWID" =~ ^APP-[A-F0-9]{16}$ ]]; then
                echo -e "\n${RED}❌ Formato HWID inválido${NC}"
                read -p "Presiona Enter..."
                continue
            fi
            
            if [[ "$TIPO" == "test" ]]; then
                DAYS="0"
                EXPIRE_DATE=$(date -d "+2 hours" +"%Y-%m-%d %H:%M:%S")
            else
                EXPIRE_DATE=$(date -d "+$DAYS days" +"%Y-%m-%d 23:59:59")
            fi
            
            /usr/local/bin/hwid-manager register "$HWID" "$NOMBRE" "$EXPIRE_DATE" "$PHONE"
            
            if [[ $? -eq 0 ]]; then
                echo -e "\n${GREEN}✅ HWID REGISTRADO EN /ETC/PASSWD${NC}"
                echo -e "📱 Teléfono: ${PHONE}"
                echo -e "👤 Nombre: ${NOMBRE}"
                echo -e "🔐 HWID: ${HWID}"
                echo -e "⏰ Expira: ${EXPIRE_DATE}"
            else
                echo -e "\n${RED}❌ Error al registrar${NC}"
            fi
            read -p "Presiona Enter..."
            ;;
        5)
            clear
            echo -e "${CYAN}👥 HWIDs ACTIVOS EN /ETC/PASSWD${NC}\n"
            /usr/local/bin/hwid-manager list
            echo -e "\n${YELLOW}Total: ${TOTAL_HWID} usuarios HWID${NC}"
            echo -e "${CYAN}Archivo: /etc/passwd${NC}"
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
            
            CURRENT_TOKEN=$(get_val '.mercadopago.access_token')
            
            if [[ -n "$CURRENT_TOKEN" && "$CURRENT_TOKEN" != "null" && "$CURRENT_TOKEN" != "" ]]; then
                echo -e "${GREEN}✅ Token configurado${NC}"
                echo -e "${YELLOW}Preview: ${CURRENT_TOKEN:0:30}...${NC}\n"
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
            
            test_mercadopago "$TOKEN"
            
            read -p "\nPresiona Enter..."
            ;;
        9)
            clear
            echo -e "${CYAN}📊 ESTADÍSTICAS${NC}\n"
            
            echo -e "${YELLOW}🔐 HWIDs (en /etc/passwd):${NC}"
            echo -e "  Total: $(grep -c '^APP-[A-F0-9]\{16\}:' /etc/passwd 2>/dev/null || echo "0")"
            echo -e "  Tests hoy: $(sqlite3 "$DB" "SELECT COUNT(*) FROM daily_tests WHERE date = date('now')" 2>/dev/null || echo "0")"
            
            echo -e "\n${YELLOW}💰 PAGOS:${NC}"
            sqlite3 "$DB" "SELECT 'Pendientes: ' || SUM(CASE WHEN status='pending' THEN 1 ELSE 0 END) || ' | Aprobados: ' || SUM(CASE WHEN status='approved' THEN 1 ELSE 0 END) || ' | Total: $' || printf('%.2f', SUM(CASE WHEN status='approved' THEN amount ELSE 0 END)) FROM payments"
            
            echo -e "\n${YELLOW}📅 PLANES VENDIDOS:${NC}"
            sqlite3 "$DB" "SELECT '7d: ' || SUM(CASE WHEN plan='7d' THEN 1 ELSE 0 END) || ' | 15d: ' || SUM(CASE WHEN plan='15d' THEN 1 ELSE 0 END) || ' | 30d: ' || SUM(CASE WHEN plan='30d' THEN 1 ELSE 0 END) || ' | 50d: ' || SUM(CASE WHEN plan='50d' THEN 1 ELSE 0 END) FROM payments WHERE status='approved'"
            
            read -p "\nPresiona Enter..."
            ;;
        10)
            echo -e "\n${YELLOW}🧹 Limpiando sesión...${NC}"
            pm2 stop sshbot-pro
            rm -rf /root/.wppconnect/*
            echo -e "${GREEN}✅ Sesión limpiada${NC}"
            sleep 2
            ;;
        11)
            clear
            echo -e "${CYAN}💳 PAGOS${NC}\n"
            
            echo -e "${YELLOW}Pagos pendientes:${NC}"
            sqlite3 -column -header "$DB" "SELECT payment_id, phone, plan, amount, created_at FROM payments WHERE status='pending' ORDER BY created_at DESC LIMIT 10"
            
            echo -e "\n${YELLOW}Pagos aprobados:${NC}"
            sqlite3 -column -header "$DB" "SELECT payment_id, phone, nombre, plan, amount, approved_at, hwid FROM payments WHERE status='approved' ORDER BY approved_at DESC LIMIT 10"
            
            read -p "\nPresiona Enter..."
            ;;
        12)
            clear
            echo -e "${CYAN}🔍 BUSCAR HWID${NC}\n"
            read -p "Ingresa HWID, nombre o teléfono: " SEARCH
            
            echo -e "\n${YELLOW}Resultados en /etc/passwd:${NC}"
            grep -i "$SEARCH" /etc/passwd | grep '^APP-' | while read line; do
                hwid=$(echo "$line" | cut -d: -f1)
                info=$(echo "$line" | cut -d: -f5)
                echo "HWID: $hwid | Info: $info"
            done
            
            read -p "\nPresiona Enter..."
            ;;
        13)
            clear
            echo -e "${CYAN}🧪 TESTS DE HOY${NC}\n"
            
            sqlite3 -column -header "$DB" "SELECT nombre, phone, created_at FROM daily_tests WHERE date = date('now') ORDER BY created_at DESC"
            
            read -p "\nPresiona Enter..."
            ;;
        14)
            echo -e "\n${YELLOW}🗑️ Eliminando HWIDs expirados...${NC}"
            /usr/local/bin/hwid-manager clean
            read -p "Presiona Enter..."
            ;;
        15)
            clear
            echo -e "${CYAN}📁 CONTENIDO DE /ETC/PASSWD (SOLO HWIDs)${NC}\n"
            grep '^APP-[A-F0-9]\{16\}:' /etc/passwd | while read line; do
                echo -e "${GREEN}$line${NC}"
            done
            echo -e "\n${YELLOW}Total: $(grep -c '^APP-[A-F0-9]\{16\}:' /etc/passwd) HWIDs registrados${NC}"
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

chmod +x /usr/local/bin/sshbot-hwid
ln -sf /usr/local/bin/sshbot-hwid /usr/local/bin/sshbot

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
║          🎉 INSTALACIÓN COMPLETADA - VERSIÓN HWID 🎉        ║
║                                                              ║
║       🔐 SISTEMA SIN USUARIO/CONTRASEÑA                    ║
║       📁 HWIDs GUARDADOS EN /ETC/PASSWD                    ║
║       📱 PRIMERO NOMBRE, LUEGO HWID                        ║
║       💰 MercadoPago SDK v2.x INTEGRADO                    ║
║       ⏱️  PRUEBA DE 2 HORAS                               ║
║       ⏰ NOTIFICACIONES DE VENCIMIENTO ACTIVAS              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Sistema HWID instalado${NC}"
echo -e "${GREEN}✅ HWIDs guardados en ${CYAN}/etc/passwd${NC}"
echo -e "${GREEN}✅ SIN usuario/contraseña tradicional${NC}"
echo -e "${GREEN}✅ FLUJO: Primero nombre, luego HWID${NC}"
echo -e "${GREEN}✅ Formato HWID: APP-E3E4D5CBB7636907${NC}"
echo -e "${GREEN}✅ MercadoPago SDK v2.x integrado${NC}"
echo -e "${GREEN}✅ Verificación automática de pagos${NC}"
echo -e "${GREEN}✅ ⏱️  PRUEBA DE 2 HORAS${NC}"
echo -e "${GREEN}✅ ⏰ NOTIFICACIONES DE VENCIMIENTO (cada hora)${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 COMANDOS PRINCIPALES:${NC}\n"
echo -e "  ${GREEN}sshbot${NC}         - Panel de control"
echo -e "  ${GREEN}pm2 logs sshbot-pro${NC} - Ver logs y QR"
echo -e "  ${GREEN}pm2 restart sshbot-pro${NC} - Reiniciar"
echo -e "  ${GREEN}hwid-manager list${NC}  - Listar HWIDs en /etc/passwd"
echo -e "\n"

echo -e "${YELLOW}📱 FLUJO DEL SISTEMA HWID:${NC}\n"
echo -e "  1. Usuario paga o pide prueba"
echo -e "  2. Bot pide: ${CYAN}\"Primero, dime tu nombre\"${NC}"
echo -e "  3. Usuario envía nombre"
echo -e "  4. Bot pide: ${CYAN}\"Ahora envía tu HWID\"${NC}"
echo -e "  5. Usuario envía HWID"
echo -e "  6. Sistema activa automáticamente"
echo -e "  7. HWID queda registrado en ${CYAN}/etc/passwd${NC}"
echo -e "\n"

echo -e "${YELLOW}💡 FORMATO HWID VÁLIDO:${NC}"
echo -e "  APP-E3E4D5CBB7636907"
echo -e "  APP- + 16 caracteres hexadecimales"
echo -e "\n"

echo -e "${YELLOW}💰 CONFIGURAR MERCADOPAGO:${NC}\n"
echo -e "  1. Ve a: https://www.mercadopago.com.ar/developers"
echo -e "  2. Inicia sesión"
echo -e "  3. Ve a 'Tus credenciales'"
echo -e "  4. Copia 'Access Token PRODUCCIÓN'"
echo -e "  5. En el panel: Opción 7 → Pegar token"
echo -e "\n"

echo -e "${YELLOW}📁 VER HWIDS EN EL SISTEMA:${NC}\n"
echo -e "  ${CYAN}cat /etc/passwd | grep '^APP-'${NC}"
echo -e "  ${CYAN}hwid-manager list${NC}"
echo -e "\n"

echo -e "${GREEN}${BOLD}¡Sistema HWID listo! Los HWIDs se guardan en /etc/passwd 🚀${NC}\n"

read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}Mostrando logs...${NC}"
    echo -e "${YELLOW}📱 Espera el QR para escanear...${NC}\n"
    sleep 2
    pm2 logs sshbot-pro
else
    echo -e "\n${YELLOW}💡 Para iniciar: ${GREEN}sshbot${NC}"
    echo -e "${YELLOW}💡 Para logs: ${GREEN}pm2 logs sshbot-pro${NC}"
    echo -e "${YELLOW}💡 Para ver HWIDs: ${GREEN}hwid-manager list${NC}\n"
fi

exit 0