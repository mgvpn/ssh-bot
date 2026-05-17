#!/bin/bash
# ================================================
# SSH BOT PRO - MULTI-SERVIDOR CON CONTRASEÑAS
# 🇦🇷 ARGENTINA | 🇨🇱 CHILE | 🇧🇷 BRASIL
# ¡PIDES CONTRASEÑAS DURANTE LA INSTALACIÓN!
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
║       🌎 SSH BOT PRO - MULTI-SERVIDOR 🌎                     ║
║                                                              ║
║         🇦🇷 ARGENTINA  |  🇨🇱 CHILE  |  🇧🇷 BRASIL            ║
║                                                              ║
║        🔐 INCLUYE CONTRASEÑAS DE SERVIDORES 🔐              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Debes ejecutar como root${NC}"
    exit 1
fi

# ================================================
# CONFIGURACIÓN DE SERVIDORES CON CONTRASEÑAS
# ================================================
echo -e "\n${CYAN}🌎 CONFIGURACIÓN DE SERVIDORES${NC}\n"

# ARGENTINA
echo -e "${YELLOW}🇦🇷 SERVIDOR ARGENTINA${NC}"
read -p "  IP del servidor Argentina: " IP_ARG
if [[ -z "$IP_ARG" ]]; then
    echo -e "${RED}❌ IP Argentina requerida${NC}"
    exit 1
fi
read -p "  Puerto SSH (default 22): " PORT_ARG
PORT_ARG=${PORT_ARG:-22}
read -p "  🔐 Contraseña ROOT de Argentina: " -s PASS_ARG
echo ""
read -p "  Precio 7 días (ARS): " PRICE_ARG_7D
PRICE_ARG_7D=${PRICE_ARG_7D:-3000}
read -p "  Precio 15 días (ARS): " PRICE_ARG_15D
PRICE_ARG_15D=${PRICE_ARG_15D:-4000}
read -p "  Precio 30 días (ARS): " PRICE_ARG_30D
PRICE_ARG_30D=${PRICE_ARG_30D:-7500}
read -p "  Precio 50 días (ARS): " PRICE_ARG_50D
PRICE_ARG_50D=${PRICE_ARG_50D:-10000}

# CHILE
echo -e "\n${YELLOW}🇨🇱 SERVIDOR CHILE${NC}"
read -p "  IP del servidor Chile: " IP_CHILE
if [[ -z "$IP_CHILE" ]]; then
    echo -e "${RED}❌ IP Chile requerida${NC}"
    exit 1
fi
read -p "  Puerto SSH (default 22): " PORT_CHILE
PORT_CHILE=${PORT_CHILE:-22}
read -p "  🔐 Contraseña ROOT de Chile: " -s PASS_CHILE
echo ""
read -p "  Precio 7 días (ARS): " PRICE_CHILE_7D
PRICE_CHILE_7D=${PRICE_CHILE_7D:-3500}
read -p "  Precio 15 días (ARS): " PRICE_CHILE_15D
PRICE_CHILE_15D=${PRICE_CHILE_15D:-4500}
read -p "  Precio 30 días (ARS): " PRICE_CHILE_30D
PRICE_CHILE_30D=${PRICE_CHILE_30D:-8000}
read -p "  Precio 50 días (ARS): " PRICE_CHILE_50D
PRICE_CHILE_50D=${PRICE_CHILE_50D:-11000}

# BRASIL
echo -e "\n${YELLOW}🇧🇷 SERVIDOR BRASIL${NC}"
read -p "  IP del servidor Brasil: " IP_BRASIL
if [[ -z "$IP_BRASIL" ]]; then
    echo -e "${RED}❌ IP Brasil requerida${NC}"
    exit 1
fi
read -p "  Puerto SSH (default 22): " PORT_BRASIL
PORT_BRASIL=${PORT_BRASIL:-22}
read -p "  🔐 Contraseña ROOT de Brasil: " -s PASS_BRASIL
echo ""
read -p "  Precio 7 días (ARS): " PRICE_BRASIL_7D
PRICE_BRASIL_7D=${PRICE_BRASIL_7D:-4000}
read -p "  Precio 15 días (ARS): " PRICE_BRASIL_15D
PRICE_BRASIL_15D=${PRICE_BRASIL_15D:-5000}
read -p "  Precio 30 días (ARS): " PRICE_BRASIL_30D
PRICE_BRASIL_30D=${PRICE_BRASIL_30D:-9000}
read -p "  Precio 50 días (ARS): " PRICE_BRASIL_50D
PRICE_BRASIL_50D=${PRICE_BRASIL_50D:-12000}

# ================================================
# INSTALAR DEPENDENCIAS
# ================================================
echo -e "\n${CYAN}📦 Instalando dependencias...${NC}"

apt-get update -y
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs gcc g++ make sqlite3 jq sshpass

# Chrome/Chromium
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get update -y
apt-get install -y google-chrome-stable

# Otras dependencias
apt-get install -y git curl wget build-essential python3 python3-pip ffmpeg unzip cron ufw

# PM2
npm install -g pm2

# Crear estructura
INSTALL_DIR="/opt/sshbot-pro"
USER_HOME="/root/sshbot-pro"
DB_FILE="$INSTALL_DIR/data/users.db"
CONFIG_FILE="$INSTALL_DIR/config/config.json"

rm -rf "$INSTALL_DIR" "$USER_HOME" 2>/dev/null || true
mkdir -p "$INSTALL_DIR"/{data,config,sessions,logs,qr_codes,scripts}
mkdir -p "$USER_HOME"

# ================================================
# CREAR SCRIPTS SSH CON CONTRASEÑAS
# ================================================

# Script para crear usuario en servidor remoto CON CONTRASEÑA
cat > "$INSTALL_DIR/scripts/create_user.sh" << SCRIPTEOF
#!/bin/bash
IP="\$1"
PORT="\$2"
USERNAME="\$3"
PASSWORD="\$4"
DAYS="\$5"

# Configurar contraseñas según IP
case "\$IP" in
    "$IP_ARG") ROOT_PASS="$PASS_ARG" ;;
    "$IP_CHILE") ROOT_PASS="$PASS_CHILE" ;;
    "$IP_BRASIL") ROOT_PASS="$PASS_BRASIL" ;;
    *) echo "IP no reconocida"; exit 1 ;;
esac

sshpass -p "\$ROOT_PASS" ssh -o StrictHostKeyChecking=no -p "\$PORT" root@"\$IP" "
    useradd -m -s /bin/bash \$USERNAME 2>/dev/null
    echo '\$USERNAME:\$PASSWORD' | chpasswd
    chage -M \$DAYS \$USERNAME 2>/dev/null
    echo 'OK'
"
SCRIPTEOF

# Script para eliminar usuario remoto CON CONTRASEÑA
cat > "$INSTALL_DIR/scripts/delete_user.sh" << SCRIPTEOF
#!/bin/bash
IP="\$1"
PORT="\$2"
USERNAME="\$3"

case "\$IP" in
    "$IP_ARG") ROOT_PASS="$PASS_ARG" ;;
    "$IP_CHILE") ROOT_PASS="$PASS_CHILE" ;;
    "$IP_BRASIL") ROOT_PASS="$PASS_BRASIL" ;;
    *) exit 1 ;;
esac

sshpass -p "\$ROOT_PASS" ssh -o StrictHostKeyChecking=no -p "\$PORT" root@"\$IP" "
    userdel -f \$USERNAME 2>/dev/null
"
SCRIPTEOF

# Script para renovar usuario remoto CON CONTRASEÑA
cat > "$INSTALL_DIR/scripts/renew_user.sh" << SCRIPTEOF
#!/bin/bash
IP="\$1"
PORT="\$2"
USERNAME="\$3"
DAYS="\$4"

case "\$IP" in
    "$IP_ARG") ROOT_PASS="$PASS_ARG" ;;
    "$IP_CHILE") ROOT_PASS="$PASS_CHILE" ;;
    "$IP_BRASIL") ROOT_PASS="$PASS_BRASIL" ;;
    *) exit 1 ;;
esac

sshpass -p "\$ROOT_PASS" ssh -o StrictHostKeyChecking=no -p "\$PORT" root@"\$IP" "
    chage -M \$DAYS \$USERNAME 2>/dev/null
"
SCRIPTEOF

chmod +x $INSTALL_DIR/scripts/*.sh

# ================================================
# CREAR CONFIGURACIÓN
# ================================================
cat > "$CONFIG_FILE" << EOF
{
    "bot": {
        "name": "SSH Bot Pro Multi-Server",
        "version": "3.0-MULTI",
        "default_password": "mgvpn247",
        "test_hours": 24
    },
    "servers": {
        "argentina": {
            "name": "🇦🇷 Argentina",
            "ip": "$IP_ARG",
            "port": $PORT_ARG,
            "enabled": true,
            "prices": {
                "7d": $PRICE_ARG_7D,
                "15d": $PRICE_ARG_15D,
                "30d": $PRICE_ARG_30D,
                "50d": $PRICE_ARG_50D
            }
        },
        "chile": {
            "name": "🇨🇱 Chile",
            "ip": "$IP_CHILE",
            "port": $PORT_CHILE,
            "enabled": true,
            "prices": {
                "7d": $PRICE_CHILE_7D,
                "15d": $PRICE_CHILE_15D,
                "30d": $PRICE_CHILE_30D,
                "50d": $PRICE_CHILE_50D
            }
        },
        "brasil": {
            "name": "🇧🇷 Brasil",
            "ip": "$IP_BRASIL",
            "port": $PORT_BRASIL,
            "enabled": true,
            "prices": {
                "7d": $PRICE_BRASIL_7D,
                "15d": $PRICE_BRASIL_15D,
                "30d": $PRICE_BRASIL_30D,
                "50d": $PRICE_BRASIL_50D
            }
        }
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false
    },
    "reminders": {
        "enabled": true,
        "times": [24, 12, 6, 1]
    },
    "paths": {
        "database": "$DB_FILE",
        "qr_codes": "$INSTALL_DIR/qr_codes",
        "scripts": "$INSTALL_DIR/scripts"
    }
}
EOF

# ================================================
# CREAR BASE DE DATOS
# ================================================
sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    username TEXT UNIQUE,
    password TEXT DEFAULT 'mgvpn247',
    server TEXT,
    server_ip TEXT,
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
    server TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(phone, date)
);

CREATE TABLE payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_id TEXT UNIQUE,
    phone TEXT,
    server TEXT,
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

CREATE TABLE user_state (
    phone TEXT PRIMARY KEY,
    state TEXT DEFAULT 'main_menu',
    data TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_server ON users(server);
CREATE INDEX idx_payments_status ON payments(status);
SQL

echo -e "${GREEN}✅ Configuración guardada con 3 servidores y contraseñas${NC}"

# ================================================
# CREAR BOT.JS
# ================================================
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

npm install --silent 2>&1 | grep -v "npm WARN" || true

# Aquí va el bot.js (usaré un curl para no exceder longitud)
cat > bot.js << 'BOTEOF'
const wppconnect = require('@wppconnect-team/wppconnect');
const moment = require('moment');
const sqlite3 = require('sqlite3').verbose();
const chalk = require('chalk');
const cron = require('node-cron');
const fs = require('fs');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

moment.locale('es');

console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════════════╗'));
console.log(chalk.cyan.bold('║     🌎 SSH BOT PRO - MULTI-SERVIDOR (ARG | CHILE | BRASIL)    ║'));
console.log(chalk.cyan.bold('║              🔐 CON CONTRASEÑAS INTEGRADAS 🔐                 ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

const config = JSON.parse(fs.readFileSync('/opt/sshbot-pro/config/config.json', 'utf8'));
const db = new sqlite3.Database(config.paths.database);
const DEFAULT_PASSWORD = config.bot.default_password;
let client = null;

function getScriptPath(scriptName) {
    return `/opt/sshbot-pro/scripts/${scriptName}`;
}

async function createRemoteUser(server, username, password, days) {
    const serverConfig = config.servers[server];
    if (!serverConfig) return { success: false, error: 'Servidor no existe' };
    
    const cmd = `${getScriptPath('create_user.sh')} ${serverConfig.ip} ${serverConfig.port} ${username} ${password} ${days}`;
    
    try {
        const { stdout } = await execPromise(cmd);
        if (stdout.includes('OK')) {
            return { success: true, server: server, ip: serverConfig.ip };
        }
        return { success: false, error: 'Error creando usuario' };
    } catch (error) {
        return { success: false, error: error.message };
    }
}

async function renewRemoteUser(server, username, additionalDays) {
    const serverConfig = config.servers[server];
    if (!serverConfig) return { success: false, error: 'Servidor no existe' };
    
    const cmd = `${getScriptPath('renew_user.sh')} ${serverConfig.ip} ${serverConfig.port} ${username} ${additionalDays}`;
    
    try {
        await execPromise(cmd);
        return { success: true, server: server, ip: serverConfig.ip };
    } catch (error) {
        return { success: false, error: error.message };
    }
}

function generateUsername(server) {
    const prefix = server.substring(0, 2);
    const randomNum = Math.floor(1000 + Math.random() * 9000);
    return `${prefix}${randomNum}`;
}

async function createUser(phone, server, days) {
    const username = generateUsername(server);
    
    if (days === 0) {
        const expiresTest = moment().add(config.bot.test_hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
        
        db.run(`INSERT INTO users (phone, username, password, server, server_ip, tipo, expires_at) 
                VALUES (?, ?, ?, ?, ?, 'test', ?)`,
            [phone, username, DEFAULT_PASSWORD, server, config.servers[server].ip, expiresTest]);
        
        return { success: true, username, password: DEFAULT_PASSWORD, expires: expiresTest, server, ip: config.servers[server].ip };
    } else {
        const expiresAt = moment().add(days, 'days').format('YYYY-MM-DD HH:mm:ss');
        const result = await createRemoteUser(server, username, DEFAULT_PASSWORD, days);
        
        if (result.success) {
            db.run(`INSERT INTO users (phone, username, password, server, server_ip, tipo, expires_at) 
                    VALUES (?, ?, ?, ?, ?, 'premium', ?)`,
                [phone, username, DEFAULT_PASSWORD, server, config.servers[server].ip, expiresAt]);
            
            return { success: true, username, password: DEFAULT_PASSWORD, expires: expiresAt, server, ip: config.servers[server].ip };
        }
        return result;
    }
}

function getUserState(phone) {
    return new Promise((resolve) => {
        db.get('SELECT state, data FROM user_state WHERE phone = ?', [phone], (err, row) => {
            if (err || !row) resolve({ state: 'main_menu', data: null });
            else resolve({ state: row.state, data: row.data ? JSON.parse(row.data) : null });
        });
    });
}

function setUserState(phone, state, data = null) {
    const dataStr = data ? JSON.stringify(data) : null;
    db.run(`INSERT OR REPLACE INTO user_state (phone, state, data, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)`,
        [phone, state, dataStr]);
}

async function showMainMenu(to) {
    await setUserState(to, 'main_menu');
    await client.sendText(to, `🌎 *SSH BOT PRO - MULTI-SERVIDOR*

🇦🇷 Argentina | 🇨🇱 Chile | 🇧🇷 Brasil

📋 *MENÚ PRINCIPAL*

1️⃣ - PRUEBA GRATIS (${config.bot.test_hours} horas)
2️⃣ - COMPRAR VPN
3️⃣ - RENOVAR VPN
4️⃣ - MIS USUARIOS
5️⃣ - DESCARGAR APP

Elija una opción:`);
}

async function initializeBot() {
    try {
        client = await wppconnect.create({
            session: 'sshbot-multi',
            headless: true,
            useChrome: true,
            logQR: true,
            browserArgs: ['--no-sandbox', '--disable-setuid-sandbox'],
            puppeteerOptions: {
                executablePath: '/usr/bin/google-chrome',
                headless: 'new',
                args: ['--no-sandbox', '--disable-setuid-sandbox']
            }
        });
        
        console.log(chalk.green('✅ Bot conectado!'));
        
        client.onMessage(async (message) => {
            const text = message.body.toLowerCase().trim();
            const from = message.from;
            const userState = await getUserState(from);
            
            if (text === 'menu' || text === 'hola' || text === 'start') {
                await showMainMenu(from);
                return;
            }
            
            if (text === 'misusuarios') {
                db.all(`SELECT username, server, expires_at FROM users WHERE phone = ? AND status = 1`, [from], async (err, rows) => {
                    if (!rows || rows.length === 0) {
                        await client.sendText(from, '📋 No tienes usuarios activos. Envía MENU para crear uno.');
                    } else {
                        let msg = '📋 *TUS USUARIOS ACTIVOS*\n\n';
                        for (const row of rows) {
                            msg += `🌎 ${row.server.toUpperCase()}\n`;
                            msg += `👤 ${row.username}\n`;
                            msg += `⏰ Expira: ${moment(row.expires_at).format('DD/MM/YYYY HH:mm')}\n`;
                            msg += `━━━━━━━━━━━━━━━━━━━━━\n`;
                        }
                        msg += `\nPara renovar, envía MENU → Opción 3`;
                        await client.sendText(from, msg);
                    }
                });
                return;
            }
            
            if (text === '1' && userState.state === 'main_menu') {
                await client.sendText(from, `🌎 *ELIGE TU PAÍS PARA PRUEBA*

1️⃣ - 🇦🇷 Argentina
2️⃣ - 🇨🇱 Chile  
3️⃣ - 🇧🇷 Brasil
0️⃣ - Cancelar`);
                await setUserState(from, 'selecting_test_server');
                return;
            }
            
            if (userState.state === 'selecting_test_server') {
                const serverMap = { '1': 'argentina', '2': 'chile', '3': 'brasil' };
                const server = serverMap[text];
                
                if (server && config.servers[server].enabled) {
                    await client.sendText(from, `⏳ Creando prueba de ${config.bot.test_hours} horas en ${config.servers[server].name}...`);
                    
                    const result = await createUser(from, server, 0);
                    
                    if (result.success) {
                        await client.sendText(from, `✅ *PRUEBA CREADA*

🌎 Servidor: ${config.servers[server].name}
👤 Usuario: ${result.username}
🔑 Contraseña: ${result.password}
⏰ Duración: ${config.bot.test_hours} horas

📲 Envía MENU para ver opciones`);
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    await setUserState(from, 'main_menu');
                } else if (text === '0') {
                    await showMainMenu(from);
                }
                return;
            }
            
            if (text === '2' && userState.state === 'main_menu') {
                let msg = `🌎 *SELECCIONA TU SERVIDOR*

`;
                if (config.servers.argentina.enabled) msg += `1️⃣ - 🇦🇷 Argentina - desde $${config.servers.argentina.prices['7d']}\n`;
                if (config.servers.chile.enabled) msg += `2️⃣ - 🇨🇱 Chile - desde $${config.servers.chile.prices['7d']}\n`;
                if (config.servers.brasil.enabled) msg += `3️⃣ - 🇧🇷 Brasil - desde $${config.servers.brasil.prices['7d']}\n`;
                msg += `0️⃣ - Volver`;
                
                await client.sendText(from, msg);
                await setUserState(from, 'selecting_country');
                return;
            }
            
            if (userState.state === 'selecting_country') {
                const serverMap = { '1': 'argentina', '2': 'chile', '3': 'brasil' };
                const server = serverMap[text];
                
                if (server && config.servers[server].enabled) {
                    let plans = `🌎 *${config.servers[server].name} - PLANES*

`;
                    plans += `1️⃣ - 7 DÍAS - $${config.servers[server].prices['7d']}\n`;
                    plans += `2️⃣ - 15 DÍAS - $${config.servers[server].prices['15d']}\n`;
                    plans += `3️⃣ - 30 DÍAS - $${config.servers[server].prices['30d']}\n`;
                    plans += `4️⃣ - 50 DÍAS - $${config.servers[server].prices['50d']}\n`;
                    plans += `0️⃣ - Volver`;
                    
                    await client.sendText(from, plans);
                    await setUserState(from, 'selecting_plan', { server: server });
                } else if (text === '0') {
                    await showMainMenu(from);
                }
                return;
            }
            
            if (userState.state === 'selecting_plan') {
                const server = userState.data.server;
                const daysMap = { '1': 7, '2': 15, '3': 30, '4': 50 };
                const days = daysMap[text];
                
                if (days) {
                    await client.sendText(from, `✅ *CONFIRMACIÓN*

🌎 Servidor: ${config.servers[server].name}
📆 Plan: ${days} días
💰 Precio: $${config.servers[server].prices[`${days}d`]}

⏳ Creando usuario...`);
                    
                    const result = await createUser(from, server, days);
                    
                    if (result.success) {
                        await client.sendText(from, `🎉 *COMPRA EXITOSA*

🌎 Servidor: ${config.servers[server].name}
📡 IP: ${result.ip}
👤 Usuario: ${result.username}
🔑 Contraseña: ${result.password}
⏰ Expira: ${moment(result.expires).format('DD/MM/YYYY HH:mm')}

📲 Envía MENU para más opciones`);
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    await setUserState(from, 'main_menu');
                } else if (text === '0') {
                    await setUserState(from, 'selecting_country');
                    await client.sendText(from, `🌎 Selecciona tu país:\n1️⃣ Argentina\n2️⃣ Chile\n3️⃣ Brasil`);
                }
                return;
            }
            
            if (text === '3' && userState.state === 'main_menu') {
                await client.sendText(from, `🔄 *RENOVAR VPN*

Escribe tu NOMBRE DE USUARIO a renovar:

(Envía 0 para cancelar)`);
                await setUserState(from, 'renewing_username');
                return;
            }
            
            if (userState.state === 'renewing_username') {
                if (text === '0') {
                    await showMainMenu(from);
                    return;
                }
                
                db.get(`SELECT username, server FROM users WHERE phone = ? AND username = ? AND status = 1`, 
                    [from, text], async (err, user) => {
                        if (!user) {
                            await client.sendText(from, `❌ Usuario "${text}" no encontrado. Verifica con "misusuarios"`);
                            await setUserState(from, 'main_menu');
                            return;
                        }
                        
                        let plans = `🔄 *RENOVAR ${user.username}*

Selecciona días a RENOVAR:

1️⃣ - 7 DÍAS - $${config.servers[user.server].prices['7d']}
2️⃣ - 15 DÍAS - $${config.servers[user.server].prices['15d']}
3️⃣ - 30 DÍAS - $${config.servers[user.server].prices['30d']}
4️⃣ - 50 DÍAS - $${config.servers[user.server].prices['50d']}
0️⃣ - Cancelar`;
                        
                        await client.sendText(from, plans);
                        await setUserState(from, 'renewing_plan', { username: user.username, server: user.server });
                    });
                return;
            }
            
            if (userState.state === 'renewing_plan') {
                const username = userState.data.username;
                const server = userState.data.server;
                const daysMap = { '1': 7, '2': 15, '3': 30, '4': 50 };
                const days = daysMap[text];
                
                if (days) {
                    await client.sendText(from, `⏳ Renovando ${username} por ${days} días...`);
                    
                    const result = await renewRemoteUser(server, username, days);
                    
                    if (result.success) {
                        db.run(`UPDATE users SET expires_at = datetime('now', '+' || ? || ' days') WHERE username = ?`, [days, username]);
                        
                        await client.sendText(from, `✅ *RENOVACIÓN EXITOSA*

👤 Usuario: ${username}
🌎 Servidor: ${config.servers[server].name}
📆 +${days} días agregados

🎉 ¡Gracias por confiar en nosotros!`);
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    await setUserState(from, 'main_menu');
                } else if (text === '0') {
                    await showMainMenu(from);
                }
                return;
            }
            
            if (text === '4' && userState.state === 'main_menu') {
                db.all(`SELECT username, server, expires_at FROM users WHERE phone = ? AND status = 1`, [from], async (err, rows) => {
                    if (!rows || rows.length === 0) {
                        await client.sendText(from, '📋 No tienes usuarios activos.');
                    } else {
                        let msg = '📋 *TUS USUARIOS ACTIVOS*\n\n';
                        for (const row of rows) {
                            msg += `🌎 ${row.server.toUpperCase()}\n`;
                            msg += `👤 ${row.username}\n`;
                            msg += `⏰ Expira: ${moment(row.expires_at).format('DD/MM/YYYY HH:mm')}\n`;
                            msg += `━━━━━━━━━━━━━━━━━━━━━\n`;
                        }
                        await client.sendText(from, msg);
                    }
                });
                return;
            }
            
            if (text === '5' && userState.state === 'main_menu') {
                await client.sendText(from, `📲 *DESCARGAR APP*

🔗 Enlace: https://www.mediafire.com/file/tvt0vpmyfg3xqhj/mgvpn.apk

🔑 Contraseña por defecto: ${DEFAULT_PASSWORD}`);
                return;
            }
        });
        
        // Limpiar usuarios expirados cada hora
        cron.schedule('*/10 * * * *', async () => {
            const now = moment().format('YYYY-MM-DD HH:mm:ss');
            db.all(`SELECT username, server, server_ip FROM users WHERE expires_at < ? AND status = 1`, [now], async (err, users) => {
                if (!users) return;
                for (const user of users) {
                    const deleteCmd = `${getScriptPath('delete_user.sh')} ${user.server_ip} 22 ${user.username}`;
                    await execPromise(deleteCmd).catch(() => {});
                    db.run(`UPDATE users SET status = 0 WHERE username = ?`, [user.username]);
                    console.log(chalk.yellow(`🗑️ Eliminado: ${user.username}`));
                }
            });
        });
        
        // Recordatorios
        cron.schedule('0 * * * *', async () => {
            for (const hours of [24, 12, 6, 1]) {
                const targetTime = moment().add(hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
                db.all(`SELECT phone, username, server, expires_at FROM users WHERE status = 1 AND expires_at BETWEEN datetime('now') AND ?`, 
                    [targetTime], async (err, users) => {
                        if (!users) return;
                        for (const user of users) {
                            const msg = hours === 1 
                                ? `⚠️ *¡ÚLTIMA HORA!*\n\nTu VPN *${user.username}* (${user.server.toUpperCase()}) vencerá en 1 hora.\n\nRENUEVA YA con MENU`
                                : `🔔 *RECORDATORIO*\n\nTu VPN *${user.username}* (${user.server.toUpperCase()}) vencerá en ${hours} horas.`;
                            await client.sendText(user.phone, msg);
                        }
                    });
            }
        });
        
    } catch (error) {
        console.error(chalk.red('❌ Error:'), error.message);
        setTimeout(initializeBot, 10000);
    }
}

initializeBot();
BOTEOF

# ================================================
# CREAR PANEL DE CONTROL
# ================================================
cat > /usr/local/bin/sshbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

DB="/opt/sshbot-pro/data/users.db"
CONFIG="/opt/sshbot-pro/config/config.json"

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         🎛️  PANEL SSH BOT PRO - MULTI-SERVIDOR             ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

while true; do
    show_header
    
    TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1" 2>/dev/null || echo "0")
    STATUS=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.name=="sshbot-multi") | .pm2_env.status' 2>/dev/null || echo "stopped")
    
    echo -e "${YELLOW}📊 ESTADO${NC}"
    echo -e "  Bot: $([ "$STATUS" == "online" ] && echo "${GREEN}● ACTIVO${NC}" || echo "${RED}● DETENIDO${NC}")"
    echo -e "  Usuarios: ${CYAN}$ACTIVE/$TOTAL${NC}"
    echo -e ""
    echo -e "${CYAN}[1] Iniciar bot    [2] Detener bot    [3] Ver logs"
    echo -e "${CYAN}[4] Ver usuarios   [5] Estadísticas   [0] Salir${NC}"
    echo ""
    read -p "👉 Selecciona: " OPT
    
    case $OPT in
        1) cd /root/sshbot-pro && pm2 start bot.js --name sshbot-multi 2>/dev/null || pm2 restart sshbot-multi; pm2 save; sleep 2;;
        2) pm2 stop sshbot-multi; sleep 1;;
        3) pm2 logs sshbot-multi --lines 50;;
        4) sqlite3 -column -header "$DB" "SELECT username, phone, server, expires_at FROM users WHERE status=1 ORDER BY expires_at LIMIT 20"; read -p "Enter...";;
        5)
            clear
            echo -e "${CYAN}📊 ESTADÍSTICAS${NC}\n"
            echo "Usuarios totales: $(sqlite3 "$DB" "SELECT COUNT(*) FROM users")"
            echo "Usuarios activos: $(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1")"
            echo "Argentina: $(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE server='argentina' AND status=1")"
            echo "Chile: $(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE server='chile' AND status=1")"
            echo "Brasil: $(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE server='brasil' AND status=1")"
            read -p "Enter...";;
        0) echo -e "\n${GREEN}👋 Hasta luego${NC}"; exit 0;;
    esac
done
PANELEOF

chmod +x /usr/local/bin/sshbot

# ================================================
# INICIAR BOT
# ================================================
cd "$USER_HOME"
pm2 start bot.js --name sshbot-multi
pm2 save
pm2 startup

echo -e "\n${GREEN}✅ INSTALACIÓN COMPLETADA CON CONTRASEÑAS${NC}"
echo -e "\n${YELLOW}📋 COMANDOS:${NC}"
echo -e "  ${GREEN}pm2 logs sshbot-multi${NC} - Ver QR y conectar WhatsApp"
echo -e "  ${GREEN}sshbot${NC} - Panel de control"
echo -e ""
echo -e "${GREEN}🎉 ¡El bot ya puede conectarse a tus servidores con las contraseñas que configuraste!${NC}"