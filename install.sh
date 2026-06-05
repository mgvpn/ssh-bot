#!/bin/bash
# ================================================
# SSH BOT PRO - WPPCONNECT + MERCADOPAGO + HWID
# VERSIÓN CON HWID EN /ETC/PASSWD - CORREGIDA
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
║               ⏰ NOTIFICACIONES DE VENCIMIENTO              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CARACTERÍSTICAS PRINCIPALES:${NC}"
echo -e "  🔐 ${CYAN}Sistema HWID${NC} - Guardado en /etc/passwd"
echo -e "  📱 ${CYAN}WPPConnect${NC} - API WhatsApp que funciona"
echo -e "  💰 ${GREEN}MercadoPago SDK v2.x${NC} - Integrado completo"
echo -e "  ⏱️  ${YELLOW}PRUEBA: 2 HORAS${NC}"
echo -e "  ⏰ ${CYAN}NOTIFICACIONES DE VENCIMIENTO${NC}"
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

# Crear base de datos
sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE IF NOT EXISTS payments (
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
CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT,
    message TEXT,
    data TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS user_state (
    phone TEXT PRIMARY KEY,
    state TEXT DEFAULT 'main_menu',
    data TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS hwid_attempts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hwid TEXT,
    phone TEXT,
    nombre TEXT,
    action TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS daily_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    nombre TEXT,
    date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(phone, date)
);
CREATE INDEX IF NOT EXISTS idx_payments_hwid ON payments(hwid);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
SQL

echo -e "${GREEN}✅ Estructura creada${NC}"

# ================================================
# CREAR SCRIPT DE GESTIÓN DE HWIDs CORREGIDO
# ================================================

cat > /usr/local/bin/hwid-manager << 'HWIDMANAGER'
#!/bin/bash
# ================================================
# GESTOR DE HWIDS - INTEGRACIÓN CON /ETC/PASSWD
# VERSIÓN CORREGIDA
# ================================================

HWID_DIR="/etc/ssh-hwids"
PASSWD_FILE="/etc/passwd"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Asegurar que existe el directorio
mkdir -p "$HWID_DIR"

# Validar formato HWID
validate_hwid() {
    [[ "$1" =~ ^APP-[A-F0-9]{16}$ ]]
}

# Normalizar HWID
normalize_hwid() {
    local hwid=$(echo "$1" | tr 'a-z' 'A-Z' | sed 's/[^A-F0-9]//g')
    if [[ ! "$hwid" =~ ^APP- ]]; then
        echo "APP-$hwid"
    else
        echo "$hwid"
    fi
}

# Verificar si HWID existe en sistema
hwid_exists() {
    local hwid=$(normalize_hwid "$1")
    grep -q "^${hwid}:" "$PASSWD_FILE" 2>/dev/null
    return $?
}

# Registrar HWID en sistema
register_hwid() {
    local hwid=$(normalize_hwid "$1")
    local nombre="$2"
    local expiry_date="$3"
    local phone="$4"
    
    echo "DEBUG: Registrando HWID=$hwid, nombre=$nombre, expiry=$expiry_date, phone=$phone" >> /tmp/hwid-debug.log
    
    # Verificar si ya existe
    if hwid_exists "$hwid"; then
        echo "ERROR: HWID ya existe: $hwid" >> /tmp/hwid-debug.log
        return 1
    fi
    
    # Buscar UID disponible
    local uid=2000
    while id -u $uid &>/dev/null 2>&1; do
        uid=$((uid + 1))
    done
    
    # Crear usuario en sistema
    useradd -r -M -s /sbin/nologin -u "$uid" -c "$nombre|$phone" "$hwid" 2>> /tmp/hwid-debug.log
    
    if [[ $? -eq 0 ]]; then
        # Guardar metadatos
        echo "$expiry_date" > "$HWID_DIR/${hwid}.expiry"
        echo "$nombre" > "$HWID_DIR/${hwid}.name"
        echo "$phone" > "$HWID_DIR/${hwid}.phone"
        
        # Configurar expiración de usuario
        if command -v chage &>/dev/null; then
            local expiry_unix=$(date -d "$expiry_date" +%Y-%m-%d 2>/dev/null)
            [[ -n "$expiry_unix" ]] && chage -E "$expiry_unix" "$hwid" 2>> /tmp/hwid-debug.log
        fi
        
        echo "✅ HWID registrado: $hwid"
        echo "SUCCESS: $hwid" >> /tmp/hwid-debug.log
        return 0
    fi
    
    echo "ERROR: useradd falló" >> /tmp/hwid-debug.log
    return 1
}

# Obtener información de HWID
get_hwid_info() {
    local hwid=$(normalize_hwid "$1")
    if hwid_exists "$hwid"; then
        grep "^${hwid}:" "$PASSWD_FILE" | cut -d: -f5
    fi
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

# Verificar si HWID está activo (no expirado)
is_hwid_active() {
    local hwid=$(normalize_hwid "$1")
    
    if ! hwid_exists "$hwid"; then
        return 1
    fi
    
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

# Listar HWIDs activos
list_hwids() {
    echo -e "${CYAN}HWIDs activos en el sistema:${NC}\n"
    printf "%-35s %-20s %-20s %s\n" "HWID" "NOMBRE" "TELÉFONO" "EXPIRA"
    echo "--------------------------------------------------------------------------------"
    
    for user in $(grep -E '^APP-[A-F0-9]{16}:' "$PASSWD_FILE" 2>/dev/null | cut -d: -f1); do
        local name_file="$HWID_DIR/${user}.name"
        local phone_file="$HWID_DIR/${user}.phone"
        local expiry_file="$HWID_DIR/${user}.expiry"
        
        local nombre=$(cat "$name_file" 2>/dev/null || echo "?")
        local phone=$(cat "$phone_file" 2>/dev/null || echo "?")
        local expiry=$(cat "$expiry_file" 2>/dev/null || echo "?")
        
        printf "%-35s %-20s %-20s %s\n" "$user" "$nombre" "$phone" "$expiry"
    done
}

# Limpiar HWIDs expirados
clean_expired() {
    local now=$(date +%s)
    local cleaned=0
    
    for user in $(grep -E '^APP-[A-F0-9]{16}:' "$PASSWD_FILE" 2>/dev/null | cut -d: -f1); do
        local expiry_file="$HWID_DIR/${user}.expiry"
        
        if [[ -f "$expiry_file" ]]; then
            local expiry_date=$(cat "$expiry_file")
            local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null)
            
            if [[ -n "$expiry_epoch" ]] && [[ $expiry_epoch -le $now ]]; then
                echo "🧹 Eliminando HWID expirado: $user"
                userdel -r "$user" 2>/dev/null
                rm -f "$HWID_DIR/${user}".*
                cleaned=$((cleaned + 1))
            fi
        fi
    done
    
    echo "✅ $cleaned HWIDs expirados eliminados"
}

# Actualizar HWID
update_hwid() {
    local hwid=$(normalize_hwid "$1")
    local nombre="$2"
    local expiry_date="$3"
    local phone="$4"
    
    if ! hwid_exists "$hwid"; then
        return 1
    fi
    
    usermod -c "$nombre|$phone" "$hwid" 2>/dev/null
    echo "$expiry_date" > "$HWID_DIR/${hwid}.expiry"
    echo "$nombre" > "$HWID_DIR/${hwid}.name"
    echo "$phone" > "$HWID_DIR/${hwid}.phone"
    
    return 0
}

# Eliminar HWID
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
            exit 0
        else
            echo "inactive"
            exit 1
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
            exit 0
        else
            echo "false"
            exit 1
        fi
        ;;
    *)
        echo "Uso: hwid-manager {register|update|delete|list|check|info|expiry|clean|exists} [hwid] [nombre] [expiry] [phone]"
        exit 1
        ;;
esac
HWIDMANAGER

chmod +x /usr/local/bin/hwid-manager

# Probar el script
echo -e "\n${YELLOW}🧪 Probando hwid-manager...${NC}"
/usr/local/bin/hwid-manager list 2>/dev/null || echo "  (sin HWIDs aún)"

# ================================================
# CREAR BOT.js CORREGIDO
# ================================================
echo -e "\n${CYAN}🤖 Creando bot.js...${NC}"

cd "$USER_HOME"

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

# Crear bot.js
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
const axios = require('axios');

const execPromise = util.promisify(exec);
moment.locale('es');

console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════════════╗'));
console.log(chalk.cyan.bold('║           🤖 SSH BOT PRO - HWID + MERCADOPAGO                ║'));
console.log(chalk.cyan.bold('║           📁 HWIDS GUARDADOS EN /ETC/PASSWD                   ║'));
console.log(chalk.cyan.bold('║           ⏱️  PRUEBA: 2 HORAS                                 ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

function loadConfig() {
    delete require.cache[require.resolve('/opt/sshbot-pro/config/config.json')];
    return require('/opt/sshbot-pro/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/sshbot-pro/data/hwid.db');

// Funciones HWID
function validateHWID(hwid) {
    return /^APP-[A-F0-9]{16}$/.test(hwid);
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
        console.log(chalk.red(`CMD Error: ${cmd}`), error.message);
        return { success: false, error: error.message, stdout: '', stderr: '' };
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
        const parts = info.stdout.split('|');
        return {
            hwid: hwid,
            nombre: parts[0] || 'Usuario',
            phone: parts[1] || '',
            expires_at: expiry.stdout || null
        };
    }
    return null;
}

async function registerHWIDinSystem(hwid, nombre, expiryDate, phone) {
    const result = await execCommand(
        `/usr/local/bin/hwid-manager register "${hwid}" "${nombre}" "${expiryDate}" "${phone}"`
    );
    console.log(chalk.cyan(`Registro HWID: ${hwid} -> ${result.success ? 'OK' : 'FAIL'}`));
    return result.success;
}

async function registerHWID(phone, nombre, hwid, days, tipo = 'premium') {
    try {
        const exists = await hwidExists(hwid);
        
        let expireFull;
        if (days === 0) {
            expireFull = moment().add(2, 'hours').format('YYYY-MM-DD HH:mm:ss');
        } else {
            expireFull = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
        }
        
        let registered;
        if (exists) {
            registered = await registerHWIDinSystem(hwid, nombre, expireFull, phone);
        } else {
            registered = await registerHWIDinSystem(hwid, nombre, expireFull, phone);
        }
        
        if (registered) {
            db.run(
                `INSERT INTO hwid_attempts (hwid, phone, nombre, action, created_at) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)`,
                [hwid, phone, nombre, days === 0 ? 'test_registered' : 'premium_registered']
            );
            
            return { success: true, hwid, nombre, expires: expireFull, tipo };
        }
        
        return { success: false, error: 'Error al registrar en el sistema' };
        
    } catch (error) {
        console.error(chalk.red('Error registrando HWID:'), error.message);
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
            console.log(chalk.red('Error MP:'), error.message);
            mpEnabled = false;
        }
    } else {
        console.log(chalk.yellow('MercadoPago NO configurado'));
    }
}

initMercadoPago();

let client = null;

// Estados
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
            [phone, state, dataStr], (err) => resolve());
    });
}

// Crear pago MP
async function createMercadoPagoPayment(phone, days, amount, planName) {
    try {
        if (!mpEnabled || !mpPreference) {
            return { success: false, error: 'MercadoPago no configurado' };
        }
        
        const phoneClean = phone.replace('@c.us', '');
        const paymentId = `HWID-${phoneClean}-${days}d-${Date.now()}`;
        
        const preferenceData = {
            items: [{
                title: `HWID SSH PREMIUM ${days} DÍAS`,
                quantity: 1,
                currency_id: config.prices.currency || 'ARS',
                unit_price: parseFloat(amount)
            }],
            external_reference: paymentId,
            back_urls: {
                success: `https://wa.me/${phoneClean}?text=Ya%20pague%20hwid`,
                failure: `https://wa.me/${phoneClean}?text=Pago%20fallido`,
                pending: `https://wa.me/${phoneClean}?text=Pago%pendiente`
            }
        };
        
        const response = await mpPreference.create({ body: preferenceData });
        
        if (response && response.id) {
            const paymentUrl = response.init_point;
            const qrPath = `${config.paths.qr_codes}/${paymentId}.png`;
            await QRCode.toFile(qrPath, paymentUrl, { width: 400 });
            
            db.run(`INSERT INTO payments (payment_id, phone, plan, days, amount, status, payment_url, qr_code, preference_id) 
                    VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
                [paymentId, phone, `${days}d`, days, amount, paymentUrl, qrPath, response.id]);
            
            return { success: true, paymentId, paymentUrl, qrPath, amount: parseFloat(amount) };
        }
        
        return { success: false, error: 'Respuesta inválida' };
        
    } catch (error) {
        console.error(chalk.red('Error MP:'), error.message);
        return { success: false, error: error.message };
    }
}

// Verificar pagos
async function checkPendingPayments() {
    if (!mpEnabled) return;
    
    db.all('SELECT * FROM payments WHERE status = "pending"', async (err, payments) => {
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
                        db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`, 
                            [payment.payment_id]);
                        
                        if (client) {
                            await client.sendText(payment.phone, `✅ PAGO CONFIRMADO

🎉 Tu pago ha sido aprobado

📝 PRIMERO, ESCRIBE TU NOMBRE:
Para continuar con la activación, dime tu nombre`);
                            await setUserState(payment.phone, 'awaiting_hwid', { 
                                payment_id: payment.payment_id,
                                days: payment.days,
                                plan: payment.plan
                            });
                        }
                    }
                }
            } catch (error) {
                console.error(chalk.red(`Error verificando pago:`), error.message);
            }
        }
    });
}

// Inicializar bot
async function initializeBot() {
    try {
        console.log(chalk.yellow('Inicializando WPPConnect...'));
        
        client = await wppconnect.create({
            session: 'sshbot-pro-hwid',
            headless: true,
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
            folderNameToken: '/root/.wppconnect'
        });
        
        console.log(chalk.green('WPPConnect conectado!'));
        
        client.onMessage(async (message) => {
            try {
                const text = message.body.toLowerCase().trim();
                const from = message.from;
                
                console.log(chalk.cyan(`Mensaje: ${text.substring(0, 30)}`));
                
                const userState = await getUserState(from);
                
                // Menú
                if (['menu', 'hola', 'start', '0'].includes(text)) {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, `HOLA BIENVENIDO BOT 🤖

Elija una opción:

 1️⃣ - PROBAR INTERNET (2 horas gratis)
 2️⃣ - COMPRAR INTERNET
 3️⃣ - VERIFICAR MI HWID
 4️⃣ - DESCARGAR APLICACIÓN`);
                }
                
                // Prueba
                else if (text === '1' && userState.state === 'main_menu') {
                    await setUserState(from, 'awaiting_test_nombre');
                    await client.sendText(from, `⏳ PRUEBA GRATUITA - 2 HORAS

Primero, dime tu nombre:`);
                }
                
                // Comprar
                else if (text === '2' && userState.state === 'main_menu') {
                    await setUserState(from, 'buying_hwid');
                    await client.sendText(from, `💰 PLANES DE INTERNET

 1️⃣ - 7 DÍAS - $${config.prices.price_7d}
 2️⃣ - 15 DÍAS - $${config.prices.price_15d}
 3️⃣ - 30 DÍAS - $${config.prices.price_30d}
 4️⃣ - 50 DÍAS - $${config.prices.price_50d}
 0️⃣ - VOLVER`);
                }
                
                // Verificar HWID
                else if (text === '3' && userState.state === 'main_menu') {
                    await setUserState(from, 'awaiting_check_hwid');
                    await client.sendText(from, `🔍 VERIFICAR HWID

Envía tu HWID para verificar:

Ejemplo: APP-E3E4D5CBB7636907`);
                }
                
                // Descargar
                else if (text === '4' && userState.state === 'main_menu') {
                    await client.sendText(from, `📱 DESCARGAR APLICACIÓN

${config.links.app_download}`);
                }
                
                // Procesar nombre para prueba
                else if (userState.state === 'awaiting_test_nombre') {
                    const nombre = message.body.trim();
                    if (nombre.length < 2) {
                        await client.sendText(from, 'Nombre debe tener al menos 2 caracteres. Intenta de nuevo:');
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
                
                // Procesar HWID para prueba
                else if (userState.state === 'awaiting_test_hwid') {
                    const rawHwid = message.body;
                    const hwid = normalizeHWID(rawHwid);
                    const nombre = userState.data.nombre;
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, `❌ HWID INVÁLIDO

Formato: APP-E3E4D5CBB7636907

Envía el HWID nuevamente o MENU`);
                        return;
                    }
                    
                    if (!(await canCreateTest(from))) {
                        await client.sendText(from, `❌ YA USASTE TU PRUEBA HOY

Vuelve mañana o compra un plan`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    const active = await isHWIDActive(hwid);
                    if (active) {
                        await client.sendText(from, `❌ Este HWID ya está activo`);
                        await setUserState(from, 'main_menu');
                        return;
                    }
                    
                    await client.sendText(from, 'Activando prueba (2 horas)...');
                    
                    const result = await registerHWID(from, nombre, hwid, 0, 'test');
                    
                    if (result.success) {
                        registerTest(from, nombre);
                        const expireTime = moment(result.expires).format('HH:mm DD/MM/YYYY');
                        await client.sendText(from, `✅ PRUEBA ACTIVADA ${nombre}

🔐 HWID: ${hwid}
⏰ Expira: ${expireTime}
📁 Registrado en: /etc/passwd`);
                        console.log(chalk.green(`Test activado: ${hwid} - ${nombre}`));
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                        console.log(chalk.red(`Error test: ${result.error}`));
                    }
                    await setUserState(from, 'main_menu');
                }
                
                // Procesar compra
                else if (userState.state === 'buying_hwid' && ['1','2','3','4'].includes(text)) {
                    const planMap = {
                        '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                        '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' },
                        '3': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                        '4': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                    };
                    const plan = planMap[text];
                    
                    if (mpEnabled) {
                        await client.sendText(from, 'Generando pago...');
                        const payment = await createMercadoPagoPayment(from, plan.days, plan.price, plan.name);
                        
                        if (payment.success) {
                            await client.sendText(from, `💰 PAGO PARA HWID

Plan: ${plan.name}
Precio: $${payment.amount}

LINK DE PAGO:
${payment.paymentUrl}

DESPUÉS DE PAGAR:
1. Espera la confirmación
2. Te pediremos tu nombre
3. Luego tu HWID`);
                            
                            if (fs.existsSync(payment.qrPath)) {
                                await client.sendImage(from, payment.qrPath, 'qr.jpg', `QR ${plan.name}`);
                            }
                        } else {
                            await client.sendText(from, `ERROR: ${payment.error}`);
                        }
                        await setUserState(from, 'main_menu');
                    } else {
                        await client.sendText(from, `Contacta soporte: ${config.links.support}`);
                        await setUserState(from, 'main_menu');
                    }
                }
                
                // Verificar HWID
                else if (userState.state === 'awaiting_check_hwid') {
                    const hwid = normalizeHWID(message.body);
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, 'Formato inválido. Intenta de nuevo o MENU');
                        return;
                    }
                    
                    const active = await isHWIDActive(hwid);
                    const info = await getHWIDInfo(hwid);
                    
                    if (active && info && info.expires_at) {
                        const expires = moment(info.expires_at).format('DD/MM/YYYY HH:mm');
                        await client.sendText(from, `✅ HWID ACTIVO

👤 Usuario: ${info.nombre}
🔐 HWID: ${hwid}
⏰ Válido hasta: ${expires}`);
                    } else {
                        await client.sendText(from, `❌ HWID NO ACTIVO

Envía 1 para prueba gratis (2 horas)`);
                    }
                    await setUserState(from, 'main_menu');
                }
                
                // Esperando HWID después de pago
                else if (userState.state === 'awaiting_hwid') {
                    if (!userState.data.nombre) {
                        const nombre = message.body.trim();
                        if (nombre.length < 2) {
                            await client.sendText(from, 'Nombre debe tener al menos 2 caracteres:');
                            return;
                        }
                        userState.data.nombre = nombre;
                        await setUserState(from, 'awaiting_hwid', userState.data);
                        await client.sendText(from, `✅ Gracias ${nombre}

Ahora envía tu HWID:
Formato: APP-E3E4D5CBB7636907`);
                        return;
                    }
                    
                    const hwid = normalizeHWID(message.body);
                    const nombre = userState.data.nombre;
                    
                    if (!validateHWID(hwid)) {
                        await client.sendText(from, 'Formato incorrecto. Envía HWID nuevamente:');
                        return;
                    }
                    
                    await client.sendText(from, 'Activando tu HWID...');
                    const result = await registerHWID(from, nombre, hwid, userState.data.days, 'premium');
                    
                    if (result.success) {
                        db.run(`UPDATE payments SET hwid = ?, nombre = ? WHERE payment_id = ?`,
                            [hwid, nombre, userState.data.payment_id]);
                        await client.sendText(from, `✅ ¡ACTIVADO ${nombre}!

🔐 HWID: ${hwid}
⏰ Válido hasta: ${moment(result.expires).format('DD/MM/YYYY')}
📁 Registrado en: /etc/passwd`);
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    await setUserState(from, 'main_menu');
                }
                
                else if (text === '0' && userState.state === 'buying_hwid') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from, `Menu principal:
 1 - Prueba
 2 - Comprar
 3 - Verificar
 4 - Descargar`);
                }
                
            } catch (error) {
                console.error(chalk.red('Error:'), error.message);
            }
        });
        
        // Tareas programadas
        cron.schedule('*/2 * * * *', () => checkPendingPayments());
        cron.schedule('*/15 * * * *', async () => {
            await execPromise('/usr/local/bin/hwid-manager clean');
        });
        
    } catch (error) {
        console.error(chalk.red('Error inicializando:'), error.message);
        setTimeout(initializeBot, 10000);
    }
}

initializeBot();

process.on('SIGINT', async () => {
    console.log(chalk.yellow('Cerrando...'));
    if (client) await client.close();
    process.exit();
});
BOTEOF

echo -e "${GREEN}✅ Bot.js creado${NC}"

# ================================================
# CREAR PANEL DE CONTROL
# ================================================
echo -e "\n${CYAN}🎛️ Creando panel de control...${NC}"

cat > /usr/local/bin/sshbot-hwid << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

DB="/opt/sshbot-pro/data/hwid.db"
CONFIG="/opt/sshbot-pro/config/config.json"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }
set_val() { local t=$(mktemp); jq "$1 = $2" "$CONFIG" > "$t" && mv "$t" "$CONFIG"; }

while true; do
    clear
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}         PANEL SSH BOT PRO - HWID EN /ETC/PASSWD${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"
    
    TOTAL_HWID=$(grep -c '^APP-[A-F0-9]\{16\}:' /etc/passwd 2>/dev/null || echo "0")
    STATUS=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.name=="sshbot-pro") | .pm2_env.status' 2>/dev/null || echo "stopped")
    
    echo -e "${YELLOW}📊 ESTADO:${NC}"
    echo -e "  Bot: $([ "$STATUS" == "online" ] && echo "${GREEN}● ACTIVO${NC}" || echo "${RED}● DETENIDO${NC}")"
    echo -e "  HWIDs en /etc/passwd: ${CYAN}$TOTAL_HWID${NC}"
    echo -e "  IP: $(get_val '.bot.server_ip')"
    echo -e ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC} Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC} Detener bot"
    echo -e "${CYAN}[3]${NC} Ver logs y QR"
    echo -e "${CYAN}[4]${NC} Listar HWIDs en /etc/passwd"
    echo -e "${CYAN}[5]${NC} Configurar MercadoPago"
    echo -e "${CYAN}[6]${NC} Ver pagos"
    echo -e "${CYAN}[7]${NC} Limpiar sesión"
    echo -e "${CYAN}[0]${NC} Salir"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "👉 Selecciona: " OPTION
    
    case $OPTION in
        1)
            cd /root/sshbot-pro
            pm2 restart sshbot-pro 2>/dev/null || pm2 start bot.js --name sshbot-pro
            pm2 save
            echo -e "${GREEN}✅ Bot iniciado${NC}"
            sleep 2
            ;;
        2)
            pm2 stop sshbot-pro
            echo -e "${GREEN}✅ Bot detenido${NC}"
            sleep 2
            ;;
        3)
            pm2 logs sshbot-pro --lines 80
            ;;
        4)
            clear
            echo -e "${CYAN}HWIDs en /etc/passwd:${NC}\n"
            grep '^APP-' /etc/passwd | while read line; do
                hwid=$(echo "$line" | cut -d: -f1)
                info=$(echo "$line" | cut -d: -f5)
                echo -e "${GREEN}$hwid${NC} - $info"
            done
            echo -e "\n${YELLOW}Total: $TOTAL_HWID${NC}"
            read -p "Presiona Enter..."
            ;;
        5)
            clear
            echo -e "${CYAN}Configurar MercadoPago${NC}\n"
            read -p "Pega tu Access Token: " TOKEN
            if [[ "$TOKEN" =~ ^(APP_USR-|TEST-) ]]; then
                set_val '.mercadopago.access_token' "\"$TOKEN\""
                set_val '.mercadopago.enabled' "true"
                echo -e "${GREEN}✅ Token configurado${NC}"
                cd /root/sshbot-pro && pm2 restart sshbot-pro
            else
                echo -e "${RED}Token inválido${NC}"
            fi
            sleep 2
            ;;
        6)
            clear
            echo -e "${CYAN}Pagos pendientes:${NC}"
            sqlite3 "$DB" "SELECT payment_id, phone, plan, amount, created_at FROM payments WHERE status='pending' LIMIT 10"
            echo -e "\n${CYAN}Pagos aprobados:${NC}"
            sqlite3 "$DB" "SELECT payment_id, phone, nombre, plan, amount, hwid FROM payments WHERE status='approved' LIMIT 10"
            read -p "Presiona Enter..."
            ;;
        7)
            pm2 stop sshbot-pro
            rm -rf /root/.wppconnect/*
            echo -e "${GREEN}✅ Sesión limpiada${NC}"
            sleep 2
            ;;
        0)
            echo -e "${GREEN}Hasta pronto${NC}"
            exit 0
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
║       🔐 HWIDS GUARDADOS EN /ETC/PASSWD                    ║
║       📱 PRIMERO NOMBRE, LUEGO HWID                        ║
║       💰 MercadoPago SDK v2.x INTEGRADO                    ║
║       ⏱️  PRUEBA DE 2 HORAS                               ║
║       ⏰ NOTIFICACIONES DE VENCIMIENTO                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${GREEN}✅ Instalación completada${NC}"
echo -e "${GREEN}✅ HWIDs se guardan en ${CYAN}/etc/passwd${NC}"
echo -e ""
echo -e "${YELLOW}📋 Comandos:${NC}"
echo -e "  ${GREEN}sshbot${NC} - Panel de control"
echo -e "  ${GREEN}pm2 logs sshbot-pro${NC} - Ver logs y QR"
echo -e "  ${GREEN}hwid-manager list${NC} - Listar HWIDs"
echo -e "  ${GREEN}grep '^APP-' /etc/passwd${NC} - Ver HWIDs en sistema"
echo -e ""

read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}Esperando QR...${NC}\n"
    sleep 3
    pm2 logs sshbot-pro --lines 50
else
    echo -e "\n${YELLOW}Para ver el QR ejecuta: ${GREEN}pm2 logs sshbot-pro${NC}\n"
fi

exit 0