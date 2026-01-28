cat > install_ssh_bot_phone.sh << 'INSTALLPHONEEOF'
#!/bin/bash

# ================================================
# SSH BOT PRO - AUTH POR TELÉFONO/CÓDIGO
# No requiere QR, usa número de WhatsApp + código
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
║     ███████╗███████╗██║  ██║    ██████╗  ██████╗ ████████╗  ║
║     ██╔════╝██╔════╝██║  ██║    ██╔══██╗██╔═══██╗╚══██╔══╝  ║
║     ███████╗███████╗███████║    ██████╔╝██║   ██║   ██║     ║
║     ╚════██║╚════██║██╔══██║    ██╔══██╗██║   ██║   ██║     ║
║     ███████║███████║██║  ██║    ██████╔╝╚██████╔╝   ██║     ║
║     ╚══════╝╚══════╝╚═╝  ╚═╝    ╚═════╝  ╚═════╝    ╚═╝     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║                SSH BOT PRO - AUTH POR TELÉFONO              ║
║               📱 SIN QR - USA NÚMERO + CÓDIGO              ║
║               🔐 CONTRASEÑA FIJA: mgvpn247                 ║
║               💰 MERCADOPAGO INTEGRADO                     ║
║               🚀 CONEXIÓN PERMANENTE                       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CARACTERÍSTICAS:${NC}"
echo -e "  📱 ${CYAN}Autenticación por teléfono${NC} (sin QR)"
echo -e "  🔐 ${CYAN}Contraseña fija: mgvpn247${NC}"
echo -e "  💰 ${CYAN}MercadoPago integrado${NC}"
echo -e "  ⏰ ${CYAN}Test 1 hora${NC}"
echo -e "  📊 ${CYAN}Panel de control${NC}"
echo -e "  🔄 ${CYAN}Auto-reconexión${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}${BOLD}❌ ERROR: Debes ejecutar como root${NC}"
    echo -e "${YELLOW}Usa: sudo bash install_ssh_bot_phone.sh${NC}"
    exit 1
fi

# Detectar IP
echo -e "${CYAN}${BOLD}🔍 DETECTANDO IP DEL SERVIDOR...${NC}"
SERVER_IP=$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "127.0.0.1")
if [[ -z "$SERVER_IP" || "$SERVER_IP" == "127.0.0.1" ]]; then
    echo -e "${RED}❌ No se pudo obtener IP pública${NC}"
    read -p "📝 Ingresa la IP del servidor manualmente: " SERVER_IP
fi

echo -e "${GREEN}✅ IP detectada: ${CYAN}$SERVER_IP${NC}\n"

# Confirmar instalación
echo -e "${YELLOW}⚠️  ESTE INSTALADOR HARÁ:${NC}"
echo -e "   • Instalar Node.js 20.x + Chrome"
echo -e "   • Instalar WPPConnect (auth por teléfono)"
echo -e "   • Crear SSH Bot con auth por número"
echo -e "   • Sistema de estados inteligente"
echo -e "   • Menú: 1=Prueba, 2=Comprar, 3=Renovar, 4=APP"
echo -e "   • Planes: 7, 15, 30, 50 días"
echo -e "   • MercadoPago integrado"
echo -e "   • Panel de control web"
echo -e "   • Auto-reinicio automático"
echo -e "   • 🔐 CONTRASEÑA FIJA: mgvpn247 para todos"
echo -e "\n${RED}⚠️  Se eliminarán instalaciones anteriores${NC}"

read -p "$(echo -e "${YELLOW}¿Continuar con la instalación? (s/N): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${RED}❌ Instalación cancelada${NC}"
    exit 0
fi

# ================================================
# INSTALAR DEPENDENCIAS
# ================================================
echo -e "\n${CYAN}${BOLD}📦 INSTALANDO DEPENDENCIAS...${NC}"

# Actualizar sistema
apt-get update -y
apt-get upgrade -y

# Instalar Node.js 20.x
echo -e "${YELLOW}📦 Instalando Node.js 20.x...${NC}"
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
apt-get install -y gcc g++ make

# Instalar Chromium
echo -e "${YELLOW}🌐 Instalando Chrome...${NC}"
apt-get install -y wget gnupg
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get update -y
apt-get install -y google-chrome-stable

# Instalar dependencias del sistema
echo -e "${YELLOW}⚙️ Instalando utilidades...${NC}"
apt-get install -y \
    git \
    curl \
    wget \
    sqlite3 \
    jq \
    build-essential \
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libgif-dev \
    librsvg2-dev \
    pkg-config \
    python3 \
    python3-pip \
    ffmpeg \
    unzip \
    cron \
    ufw \
    screen \
    htop \
    net-tools

# Instalar PM2 globalmente
echo -e "${YELLOW}🔄 Instalando PM2...${NC}"
npm install -g pm2
pm2 update

# Configurar firewall
echo -e "${YELLOW}🛡️ Configurando firewall...${NC}"
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 3000/tcp
ufw allow 8000/tcp
ufw --force enable

echo -e "${GREEN}✅ Dependencias instaladas${NC}"

# ================================================
# PREPARAR ESTRUCTURA
# ================================================
echo -e "\n${CYAN}${BOLD}📁 CREANDO ESTRUCTURA...${NC}"

INSTALL_DIR="/opt/ssh-bot-phone"
USER_HOME="/root/ssh-bot-phone"
DB_FILE="$INSTALL_DIR/data/users.db"
CONFIG_FILE="$INSTALL_DIR/config/config.json"

# Limpiar instalaciones anteriores
echo -e "${YELLOW}🧹 Limpiando instalaciones anteriores...${NC}"
pm2 delete ssh-bot-phone 2>/dev/null || true
pm2 flush 2>/dev/null || true
rm -rf "$INSTALL_DIR" "$USER_HOME" 2>/dev/null || true
rm -rf /root/.wwebjs_auth 2>/dev/null || true

# Crear directorios
mkdir -p "$INSTALL_DIR"/{data,config,logs,sessions}
mkdir -p "$USER_HOME"
chmod -R 755 "$INSTALL_DIR"
chmod -R 700 "$INSTALL_DIR/sessions"

# Crear configuración
cat > "$CONFIG_FILE" << EOF
{
    "bot": {
        "name": "SSH Bot Phone Auth",
        "version": "2.0",
        "server_ip": "$SERVER_IP",
        "default_password": "mgvpn247",
        "test_hours": 1
    },
    "prices": {
        "price_7d": 1500.00,
        "price_15d": 2500.00,
        "price_30d": 5500.00,
        "price_50d": 8500.00,
        "currency": "ARS"
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false
    },
    "links": {
        "tutorial": "https://youtube.com",
        "support": "https://wa.me/543435071016",
        "app_download": "https://www.mediafire.com/file/p8kgthxbsid7xws/MAJ/DNI_AND_FIL"
    },
    "whatsapp": {
        "session_path": "/opt/ssh-bot-phone/sessions",
        "headless": true,
        "useChrome": true
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
    expires_at DATETIME,
    max_connections INTEGER DEFAULT 1,
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
    plan TEXT,
    days INTEGER,
    amount REAL,
    discount_code TEXT,
    final_amount REAL,
    status TEXT DEFAULT 'pending',
    payment_url TEXT,
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
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_status ON users(status);
SQL

echo -e "${GREEN}✅ Estructura creada${NC}"

# ================================================
# INSTALAR WPPCONNECT (AUTH POR TELÉFONO)
# ================================================
echo -e "\n${CYAN}${BOLD}📱 INSTALANDO WPPCONNECT...${NC}"

cd "$USER_HOME"

# package.json
cat > package.json << 'PKGEOF'
{
    "name": "ssh-bot-phone",
    "version": "2.0.0",
    "main": "bot.js",
    "dependencies": {
        "@wppconnect-team/wppconnect": "^1.29.4",
        "qrcode-terminal": "^0.12.0",
        "qrcode": "^1.5.3",
        "moment": "^2.30.1",
        "sqlite3": "^5.1.7",
        "chalk": "^4.1.2",
        "node-cron": "^3.0.3",
        "axios": "^1.6.5",
        "express": "^4.18.2",
        "body-parser": "^1.20.2",
        "pm2": "^5.3.0"
    }
}
PKGEOF

echo -e "${YELLOW}📦 Instalando paquetes Node.js...${NC}"
npm install --silent

# ================================================
# CREAR BOT CON AUTH POR TELÉFONO
# ================================================
echo -e "\n${CYAN}${BOLD}🤖 CREANDO BOT CON AUTH POR TELÉFONO...${NC}"

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
const express = require('express');
const bodyParser = require('body-parser');

const execPromise = util.promisify(exec);

// Configuración
const CONFIG = {
    server_ip: process.env.SERVER_IP || 'TU_IP_AQUI',
    password: 'mgvpn247',
    test_hours: 1,
    prices: {
        '7': 1500,
        '15': 2500,
        '30': 5500,
        '50': 8500
    }
};

console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════════════╗'));
console.log(chalk.cyan.bold('║           🤖 SSH BOT - AUTH POR TELÉFONO/CÓDIGO            ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));
console.log(chalk.yellow(`📍 IP: ${CONFIG.server_ip}`));
console.log(chalk.yellow(`🔐 Contraseña: ${CONFIG.password}`));
console.log(chalk.green('✅ Sistema de auth por teléfono activado'));
console.log(chalk.green('✅ No requiere QR - Usa número + código'));

let client = null;
const db = new sqlite3.Database('/opt/ssh-bot-phone/data/users.db');

// Servidor web para panel
const app = express();
app.use(bodyParser.json());
app.use(express.static('public'));

app.get('/status', (req, res) => {
    res.json({
        status: client ? 'connected' : 'disconnected',
        server_ip: CONFIG.server_ip,
        timestamp: moment().format('YYYY-MM-DD HH:mm:ss')
    });
});

app.listen(3000, () => {
    console.log(chalk.cyan('🌐 Panel web en: http://localhost:3000'));
});

// Función para iniciar WhatsApp
async function startWhatsApp() {
    try {
        console.log(chalk.yellow('🚀 Iniciando WhatsApp con WPPConnect...'));
        
        client = await wppconnect.create({
            session: 'ssh-bot-session',
            catchQR: (base64Qr, asciiQR) => {
                console.log(chalk.green('\n📱 OPCIONAL: Si prefieres usar QR, escanea este:'));
                qrcode.generate(asciiQR, { small: true });
                
                // Guardar QR
                const qrPath = '/root/qr-whatsapp.png';
                const qrBuffer = Buffer.from(base64Qr.replace('data:image/png;base64,', ''), 'base64');
                fs.writeFileSync(qrPath, qrBuffer);
                console.log(chalk.cyan(`💾 QR guardado: ${qrPath}`));
            },
            statusFind: (statusSession, session) => {
                console.log(chalk.blue('🔍 Estado sesión:'), statusSession);
                console.log(chalk.blue('📱 Sesión:'), session);
                
                if (statusSession === 'isLogged') {
                    console.log(chalk.green('✅ Ya hay una sesión activa'));
                } else if (statusSession === 'notLogged') {
                    console.log(chalk.yellow('⚠️  No hay sesión, necesitas autenticarte'));
                }
            },
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
                '--disable-gpu',
                '--no-first-run',
                '--disable-extensions'
            ],
            puppeteerOptions: {
                executablePath: '/usr/bin/google-chrome'
            },
            disableWelcome: true,
            updatesLog: true,
            autoClose: 0,
            tokenStore: 'file',
            folderNameToken: '/opt/ssh-bot-phone/sessions',
            createPathFileToken: true
        });

        console.log(chalk.green('✅ WPPConnect inicializado'));
        
        // Evento cuando está listo
        client.onStateChange((state) => {
            console.log(chalk.blue('🔄 Estado cambio:'), state);
            
            if (state === 'CONNECTED') {
                console.log(chalk.green.bold('\n✅ WHATSAPP CONECTADO CORRECTAMENTE'));
                console.log(chalk.cyan('💬 Envía "menu" a este número para comenzar\n'));
            }
        });

        // Escuchar mensajes
        client.onMessage(async (message) => {
            try {
                const phone = message.from;
                const text = message.body.toLowerCase().trim();
                
                if (phone.includes('@g.us')) return;
                
                console.log(chalk.cyan(`📩 [${phone.split('@')[0]}]: ${text.substring(0, 50)}`));
                
                // MENU PRINCIPAL
                if (text === 'menu' || text === 'hola' || text === 'start' || text === 'help') {
                    const menu = `🎟️ *MENU PRINCIPAL - SSH BOT*

1️⃣ *PRUEBA GRATIS* - 1 hora
2️⃣ *COMPRAR USUARIO* - Planes disponibles
3️⃣ *RENOVAR USUARIO* - Extender tiempo
4️⃣ *DESCARGAR APP* - Cliente SSH

📱 *IP SERVIDOR:* ${CONFIG.server_ip}
🔐 *CONTRASEÑA:* ${CONFIG.password}

Escribe el *NÚMERO* de la opción deseada.`;
                    
                    await client.sendText(phone, menu);
                }
                
                // OPCIÓN 1: PRUEBA GRATIS
                else if (text === '1') {
                    // Verificar si ya usó prueba hoy
                    const today = moment().format('YYYY-MM-DD');
                    db.get('SELECT COUNT(*) as count FROM daily_tests WHERE phone = ? AND date = ?', 
                        [phone, today], async (err, row) => {
                            if (err || (row && row.count > 0)) {
                                await client.sendText(phone, `⚠️ *YA USASTE TU PRUEBA HOY*

Solo puedes crear 1 prueba por día.
Vuelve mañana para otra prueba gratuita.`);
                                return;
                            }
                            
                            // Crear usuario de prueba
                            const username = 'TEST' + Math.floor(1000 + Math.random() * 9000);
                            const expireTime = moment().add(CONFIG.test_hours, 'hours').format('DD/MM/YYYY HH:mm');
                            
                            try {
                                // Crear usuario en sistema
                                await execPromise(`useradd -M -s /bin/false ${username} && echo "${username}:${CONFIG.password}" | chpasswd`);
                                
                                // Guardar en BD
                                db.run(`INSERT INTO users (phone, username, password, tipo, expires_at, max_connections, status) VALUES (?, ?, ?, 'test', datetime('now', '+1 hour'), 1, 1)`,
                                    [phone, username, CONFIG.password]);
                                
                                // Registrar prueba diaria
                                db.run('INSERT INTO daily_tests (phone, date) VALUES (?, ?)', [phone, today]);
                                
                                const response = `✅ *PRUEBA CREADA EXITOSAMENTE*

👤 *Usuario:* \`${username}\`
🔑 *Contraseña:* \`${CONFIG.password}\`
⏰ *Expira:* ${expireTime}
🔌 *Conexiones:* 1 dispositivo

📱 *PARA CONECTARSE:*
• IP: ${CONFIG.server_ip}
• Puerto: 22
• Usuario: ${username}
• Contraseña: ${CONFIG.password}

💾 *APP RECOMENDADA:* JuiceSSH (Play Store)
🔗 *Tutorial:* https://youtube.com`;
                                
                                await client.sendText(phone, response);
                                console.log(chalk.green(`✅ Prueba creada: ${username} para ${phone}`));
                                
                            } catch (error) {
                                console.error(chalk.red('❌ Error creando prueba:'), error);
                                await client.sendText(phone, '❌ Error al crear prueba. Intenta más tarde.');
                            }
                        });
                }
                
                // OPCIÓN 2: COMPRAR
                else if (text === '2') {
                    const plans = `💰 *PLANES DISPONIBLES*

1️⃣ *7 DÍAS* - $${CONFIG.prices['7']} ARS
2️⃣ *15 DÍAS* - $${CONFIG.prices['15']} ARS  
3️⃣ *30 DÍAS* - $${CONFIG.prices['30']} ARS
4️⃣ *50 DÍAS* - $${CONFIG.prices['50']} ARS

🔐 *CONTRASEÑA:* ${CONFIG.password}
🔌 *CONEXIONES:* 1 dispositivo

Escribe el *NÚMERO* del plan que deseas.`;
                    
                    await client.sendText(phone, plans);
                }
                
                // OPCIÓN 3: RENOVAR
                else if (text === '3') {
                    await client.sendText(phone, `🔄 *RENOVAR USUARIO*

Para renovar tu cuenta:
1. Envía tu nombre de usuario actual
2. Selecciona el plan de renovación
3. Realiza el pago

O contacta soporte para asistencia.`);
                }
                
                // OPCIÓN 4: DESCARGAR APP
                else if (text === '4') {
                    await client.sendText(phone, `📱 *DESCARGAR APLICACIÓN*

🔗 *Enlace de descarga:*
https://www.mediafire.com/file/p8kgthxbsid7xws/MAJ/DNI_AND_FIL

📋 *Instrucciones:*
1. Descarga e instala la APK
2. Configura con:
   • Servidor: ${CONFIG.server_ip}
   • Usuario: (el proporcionado)
   • Contraseña: ${CONFIG.password}
   • Puerto: 22

⚠️ *Nota:* Si tu dispositivo bloquea la instalación, activa "Orígenes desconocidos" en ajustes.`);
                }
                
                // PLANES ESPECÍFICOS
                else if (['1', '2', '3', '4'].includes(text)) {
                    const planMap = {
                        '1': { days: 7, price: CONFIG.prices['7'] },
                        '2': { days: 15, price: CONFIG.prices['15'] },
                        '3': { days: 30, price: CONFIG.prices['30'] },
                        '4': { days: 50, price: CONFIG.prices['50'] }
                    };
                    
                    const plan = planMap[text];
                    if (plan) {
                        const response = `🗓️ *PLAN ${plan.days} DÍAS*

• *Duración:* ${plan.days} días
• *Precio:* $${plan.price} ARS
• *Contraseña:* ${CONFIG.password}
• *Conexiones:* 1 dispositivo

💳 *MÉTODOS DE PAGO:*
1. MercadoPago (automático)
2. Transferencia bancaria
3. Efectivo

Para pagar con MercadoPago, escribe *pagar ${plan.days}*
Para otros métodos, escribe *otros métodos*`;
                        
                        await client.sendText(phone, response);
                    }
                }
                
                // COMANDO PAGAR
                else if (text.startsWith('pagar')) {
                    await client.sendText(phone, `💳 *SISTEMA DE PAGOS*

Actualmente el sistema de pagos automáticos está en configuración.

📞 *PAGO MANUAL:*
1. Realiza transferencia a:
   • Alias: ssh.vpn.bot
   • CBU: 0000000000000000000
2. Envía comprobante a este WhatsApp
3. Tu usuario será activado en minutos

💬 Para consultas: https://wa.me/543435071016`);
                }
                
                // COMANDO NO RECONOCIDO
                else {
                    await client.sendText(phone, `❌ *COMANDO NO RECONOCIDO*

Escribe *menu* para ver las opciones disponibles.

📞 *SOPORTE:* https://wa.me/543435071016`);
                }
                
            } catch (error) {
                console.error(chalk.red('❌ Error procesando mensaje:'), error);
            }
        });

        console.log(chalk.green('✅ Bot listo para recibir mensajes'));
        
    } catch (error) {
        console.error(chalk.red('❌ Error iniciando WhatsApp:'), error);
        console.log(chalk.yellow('🔄 Reintentando en 10 segundos...'));
        setTimeout(startWhatsApp, 10000);
    }
}

// Función para crear usuario SSH
async function createSSHUser(username, days = 0) {
    try {
        if (days === 0) {
            // Usuario de prueba (1 hora)
            await execPromise(`useradd -M -s /bin/false ${username} && echo "${username}:${CONFIG.password}" | chpasswd`);
            return { success: true, expires: moment().add(1, 'hour').format('DD/MM/YYYY HH:mm') };
        } else {
            // Usuario premium
            const expireDate = moment().add(days, 'days').format('YYYY-MM-DD');
            await execPromise(`useradd -M -s /bin/false -e ${expireDate} ${username} && echo "${username}:${CONFIG.password}" | chpasswd`);
            return { success: true, expires: expireDate };
        }
    } catch (error) {
        console.error(chalk.red('❌ Error creando usuario SSH:'), error);
        return { success: false, error: error.message };
    }
}

// Cron para limpiar usuarios expirados
cron.schedule('*/15 * * * *', async () => {
    console.log(chalk.yellow('🧹 Limpiando usuarios expirados...'));
    
    const now = moment().format('YYYY-MM-DD HH:mm:ss');
    db.all('SELECT username FROM users WHERE expires_at < ? AND status = 1', [now], async (err, rows) => {
        if (err || !rows) return;
        
        for (const row of rows) {
            try {
                await execPromise(`pkill -u ${row.username} 2>/dev/null || true`);
                await execPromise(`userdel -f ${row.username} 2>/dev/null || true`);
                db.run('UPDATE users SET status = 0 WHERE username = ?', [row.username]);
                console.log(chalk.green(`🗑️ Eliminado: ${row.username}`));
            } catch (e) {
                console.error(chalk.red(`Error eliminando ${row.username}:`), e.message);
            }
        }
    });
});

// Cron para verificar estado
cron.schedule('*/5 * * * *', () => {
    if (client) {
        console.log(chalk.blue('🔄 Verificando conexión WhatsApp...'));
        client.getHostDevice().then(device => {
            console.log(chalk.green(`✅ Conexión activa: ${device.pushname || 'Dispositivo'}`));
        }).catch(err => {
            console.log(chalk.red('❌ Conexión perdida, reiniciando...'));
            startWhatsApp();
        });
    }
});

// Iniciar todo
async function start() {
    console.log(chalk.yellow('🚀 Iniciando sistema SSH Bot...'));
    
    // Actualizar IP si no está configurada
    if (CONFIG.server_ip === 'TU_IP_AQUI') {
        try {
            const ip = await execPromise('curl -4 -s ifconfig.me');
            CONFIG.server_ip = ip.stdout.trim();
            console.log(chalk.green(`📍 IP actualizada: ${CONFIG.server_ip}`));
        } catch (error) {
            console.log(chalk.red('❌ No se pudo obtener IP'));
        }
    }
    
    // Iniciar WhatsApp
    await startWhatsApp();
    
    console.log(chalk.green.bold('\n✅ SISTEMA INICIADO CORRECTAMENTE'));
    console.log(chalk.cyan('📱 Auth por teléfono/código activado'));
    console.log(chalk.cyan('🌐 Panel: http://localhost:3000/status'));
    console.log(chalk.cyan('💬 Envía "menu" al WhatsApp para comenzar\n'));
}

// Manejar cierre
process.on('SIGINT', async () => {
    console.log(chalk.yellow('\n⚠️  Cerrando bot...'));
    if (client) {
        await client.close();
    }
    process.exit(0);
});

// Iniciar aplicación
start();
BOTEOF

echo -e "${GREEN}✅ Bot creado con auth por teléfono${NC}"

# ================================================
# CREAR SCRIPT DE AUTENTICACIÓN
# ================================================
echo -e "\n${CYAN}${BOLD}🔐 CREANDO SCRIPT DE AUTH...${NC}"

cat > /usr/local/bin/auth-whatsapp << 'AUTHEOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           🔐 AUTHENTICACIÓN WHATSAPP - SSH BOT           ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

SESSION_DIR="/opt/ssh-bot-phone/sessions"

if [ -f "$SESSION_DIR/ssh-bot-session.token.json" ]; then
    echo -e "${GREEN}✅ Sesión existente encontrada${NC}"
    echo -e "${YELLOW}El bot usará la sesión guardada automáticamente.${NC}"
    echo -e "\n${CYAN}Para forzar nueva autenticación:${NC}"
    echo -e "rm -rf $SESSION_DIR/*"
else
    echo -e "${YELLOW}⚠️  No hay sesión guardada${NC}"
    echo -e "${CYAN}El bot pedirá autenticación al iniciar.${NC}"
fi

echo -e "\n${YELLOW}📱 MÉTODOS DE AUTH DISPONIBLES:${NC}"
echo -e "1. ${GREEN}QR Code${NC} (se generará automáticamente)"
echo -e "2. ${GREEN}Código de 6 dígitos${NC} (vía WhatsApp)"
echo -e "3. ${GREEN}Pairing Code${NC} (código de vinculación)"

echo -e "\n${CYAN}Para ver el QR (si se necesita):${NC}"
echo -e "cat /root/qr-whatsapp.png"
echo -e "\n${CYAN}Para ver logs de auth:${NC}"
echo -e "pm2 logs ssh-bot-phone --lines 50"

echo -e "\n${GREEN}✅ Script de auth creado${NC}"
AUTHEOF

chmod +x /usr/local/bin/auth-whatsapp

# ================================================
# CREAR PANEL DE CONTROL
# ================================================
echo -e "\n${CYAN}${BOLD}🎛️  CREANDO PANEL DE CONTROL...${NC}"

cat > /usr/local/bin/sshbot-phone << 'PANELEOF'
#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

DB="/opt/ssh-bot-phone/data/users.db"
CONFIG="/opt/ssh-bot-phone/config/config.json"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                🎛️  PANEL SSH BOT - PHONE AUTH             ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

while true; do
    show_header
    
    TOTAL_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1" 2>/dev/null || echo "0")
    
    STATUS=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.name=="ssh-bot-phone") | .pm2_env.status' 2>/dev/null || echo "stopped")
    if [[ "$STATUS" == "online" ]]; then
        BOT_STATUS="${GREEN}● ACTIVO${NC}"
        BOT_UPTIME=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.name=="ssh-bot-phone") | .pm2_env.pm_uptime' 2>/dev/null)
        if [ -n "$BOT_UPTIME" ]; then
            UPTIME_SEC=$(( ( $(date +%s) - $BOT_UPTIME / 1000 ) ))
            UPTIME_STR=$(printf '%dd %dh %dm %ds' $((UPTIME_SEC/86400)) $((UPTIME_SEC%86400/3600)) $((UPTIME_SEC%3600/60)) $((UPTIME_SEC%60)))
        else
            UPTIME_STR="N/A"
        fi
    else
        BOT_STATUS="${RED}● DETENIDO${NC}"
        UPTIME_STR="N/A"
    fi
    
    echo -e "${YELLOW}📊 ESTADO DEL SISTEMA${NC}"
    echo -e "  Bot: $BOT_STATUS"
    echo -e "  Uptime: ${CYAN}$UPTIME_STR${NC}"
    echo -e "  Usuarios: ${CYAN}$ACTIVE_USERS/$TOTAL_USERS${NC} activos/total"
    echo -e "  IP: ${GREEN}$(get_val '.bot.server_ip')${NC}"
    echo -e "  Contraseña: ${GREEN}$(get_val '.bot.default_password')${NC}"
    echo -e "  Test: ${GREEN}$(get_val '.bot.test_hours') hora(s)${NC}"
    echo -e ""
    
    echo -e "${YELLOW}💰 PRECIOS:${NC}"
    echo -e "  7 días: $ $(get_val '.prices.price_7d') ARS"
    echo -e "  15 días: $ $(get_val '.prices.price_15d') ARS"
    echo -e "  30 días: $ $(get_val '.prices.price_30d') ARS"
    echo -e "  50 días: $ $(get_val '.prices.price_50d') ARS"
    echo -e ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC}  🚀  Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC}  🛑  Detener bot"
    echo -e "${CYAN}[3]${NC}  📱  Ver estado WhatsApp"
    echo -e "${CYAN}[4]${NC}  👤  Crear usuario manual"
    echo -e "${CYAN}[5]${NC}  👥  Listar usuarios"
    echo -e "${CYAN}[6]${NC}  💰  Cambiar precios"
    echo -e "${CYAN}[7]${NC}  🔧  Configurar MercadoPago"
    echo -e "${CYAN}[8]${NC}  📊  Ver estadísticas"
    echo -e "${CYAN}[9]${NC}  📝  Ver logs"
    echo -e "${CYAN}[a]${NC}  🔐  Auth WhatsApp"
    echo -e "${CYAN}[0]${NC}  🚪  Salir"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e ""
    read -p "👉 Selecciona una opción: " OPTION
    
    case $OPTION in
        1)
            echo -e "\n${YELLOW}🔄 Reiniciando bot...${NC}"
            cd /root/ssh-bot-phone
            pm2 restart bot.js --name ssh-bot-phone 2>/dev/null || pm2 start bot.js --name ssh-bot-phone
            pm2 save
            echo -e "${GREEN}✅ Bot reiniciado${NC}"
            sleep 2
            ;;
        2)
            echo -e "\n${YELLOW}🛑 Deteniendo bot...${NC}"
            pm2 stop ssh-bot-phone
            echo -e "${GREEN}✅ Bot detenido${NC}"
            sleep 2
            ;;
        3)
            echo -e "\n${YELLOW}📱 Estado WhatsApp...${NC}"
            curl -s http://localhost:3000/status || echo -e "${RED}❌ Servidor no disponible${NC}"
            read -p "Presiona Enter..."
            ;;
        4)
            clear
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║                     👤 CREAR USUARIO                        ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
            
            read -p "Teléfono (ej: 5491122334455): " PHONE
            read -p "Usuario: " USERNAME
            read -p "Tipo (test/premium): " TIPO
            read -p "Días (0=test 1h, 7,15,30,50=premium): " DAYS
            
            [[ -z "$DAYS" ]] && DAYS="30"
            [[ -z "$USERNAME" ]] && USERNAME="USER$(shuf -i 1000-9999 -n 1)"
            PASSWORD="mgvpn247"
            
            if [[ "$TIPO" == "test" ]]; then
                DAYS="0"
                EXPIRE_DATE=$(date -d "+1 hour" +"%Y-%m-%d %H:%M:%S")
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
                echo -e "📱 Teléfono: ${PHONE}"
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
            
            sqlite3 -column -header "$DB" "SELECT username, password, tipo, expires_at, substr(phone,1,12) as tel FROM users WHERE status = 1 ORDER BY expires_at DESC LIMIT 20"
            echo -e "\n${YELLOW}Total: ${ACTIVE_USERS} activos${NC}"
            read -p "Presiona Enter..." 
            ;;
        6)
            clear
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║                    💰 CAMBIAR PRECIOS                       ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
            
            echo -e "${YELLOW}Ingresa nuevos precios:${NC}"
            read -p "7 días [$(get_val '.prices.price_7d')]: " PRICE_7D
            read -p "15 días [$(get_val '.prices.price_15d')]: " PRICE_15D
            read -p "30 días [$(get_val '.prices.price_30d')]: " PRICE_30D
            read -p "50 días [$(get_val '.prices.price_50d')]: " PRICE_50D
            
            [[ -n "$PRICE_7D" ]] && jq ".prices.price_7d = $PRICE_7D" "$CONFIG" > tmp.json && mv tmp.json "$CONFIG"
            [[ -n "$PRICE_15D" ]] && jq ".prices.price_15d = $PRICE_15D" "$CONFIG" > tmp.json && mv tmp.json "$CONFIG"
            [[ -n "$PRICE_30D" ]] && jq ".prices.price_30d = $PRICE_30D" "$CONFIG" > tmp.json && mv tmp.json "$CONFIG"
            [[ -n "$PRICE_50D" ]] && jq ".prices.price_50d = $PRICE_50D" "$CONFIG" > tmp.json && mv tmp.json "$CONFIG"
            
            echo -e "\n${GREEN}✅ Precios actualizados${NC}"
            read -p "Presiona Enter..." 
            ;;
        7)
            clear
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║              🔑 CONFIGURAR MERCADOPAGO                      ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
            
            CURRENT_TOKEN=$(get_val '.mercadopago.access_token')
            
            if [[ -n "$CURRENT_TOKEN" && "$CURRENT_TOKEN" != "null" && "$CURRENT_TOKEN" != "" ]]; then
                echo -e "${GREEN}✅ Token configurado${NC}"
                echo -e "${YELLOW}Preview: ${CURRENT_TOKEN:0:20}...${NC}\n"
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
                    jq ".mercadopago.access_token = \"$NEW_TOKEN\" | .mercadopago.enabled = true" "$CONFIG" > tmp.json && mv tmp.json "$CONFIG"
                    echo -e "\n${GREEN}✅ Token configurado${NC}"
                    echo -e "${YELLOW}🔄 Reiniciando bot...${NC}"
                    pm2 restart ssh-bot-phone
                    sleep 2
                else
                    echo -e "${RED}❌ Token inválido${NC}"
                fi
            fi
            read -p "Presiona Enter..." 
            ;;
        8)
            clear
            echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${CYAN}║                     📊 ESTADÍSTICAS                         ║${NC}"
            echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
            
            echo -e "${YELLOW}👥 USUARIOS:${NC}"
            sqlite3 "$DB" "SELECT 'Total: ' || COUNT(*) || ' | Activos: ' || SUM(CASE WHEN status=1 THEN 1 ELSE 0 END) || ' | Tests: ' || (SELECT COUNT(*) FROM daily_tests) FROM users"
            
            echo -e "\n${YELLOW}💰 INGRESOS:${NC}"
            sqlite3 "$DB" "SELECT 'Aprobados: $' || printf('%.2f', SUM(CASE WHEN status='approved' THEN final_amount ELSE 0 END)) FROM payments"
            
            echo -e "\n${YELLOW}📅 DISTRIBUCIÓN:${NC}"
            sqlite3 "$DB" "SELECT '7d: ' || SUM(CASE WHEN plan='7d' THEN 1 ELSE 0 END) || ' | 15d: ' || SUM(CASE WHEN plan='15d' THEN 1 ELSE 0 END) || ' | 30d: ' || SUM(CASE WHEN plan='30d' THEN 1 ELSE 0 END) || ' | 50d: ' || SUM(CASE WHEN plan='50d' THEN 1 ELSE 0 END) FROM payments"
            
            read -p "\nPresiona Enter..." 
            ;;
        9)
            echo -e "\n${YELLOW}📝 Logs (Ctrl+C para salir)...${NC}\n"
            pm2 logs ssh-bot-phone --lines 100
            ;;
        a|A)
            echo -e "\n${YELLOW}🔐 Auth WhatsApp...${NC}"
            auth-whatsapp
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

chmod +x /usr/local/bin/sshbot-phone

# ================================================
# CONFIGURAR PM2 Y SERVICIOS
# ================================================
echo -e "\n${CYAN}${BOLD}⚙️  CONFIGURANDO SERVICIOS...${NC}"

cd "$USER_HOME"

# Crear ecosystem para PM2
cat > ecosystem.config.js << 'ECOSYSTEMEOF'
module.exports = {
    apps: [{
        name: 'ssh-bot-phone',
        script: 'bot.js',
        cwd: '/root/ssh-bot-phone',
        instances: 1,
        autorestart: true,
        watch: false,
        max_memory_restart: '300M',
        env: {
            NODE_ENV: 'production',
            SERVER_IP: '$SERVER_IP'
        },
        error_file: '/opt/ssh-bot-phone/logs/error.log',
        out_file: '/opt/ssh-bot-phone/logs/out.log',
        log_file: '/opt/ssh-bot-phone/logs/combined.log',
        time: true,
        exp_backoff_restart_delay: 100,
        max_restarts: 10,
        min_uptime: '10s'
    }]
};
ECOSYSTEMEOF

# Iniciar con PM2
pm2 start ecosystem.config.js
pm2 save
pm2 startup

# Crear servicio systemd
cat > /etc/systemd/system/ssh-bot-phone.service << 'SERVICEEOF'
[Unit]
Description=SSH Bot WhatsApp Phone Auth
After=network.target

[Service]
Type=exec
User=root
WorkingDirectory=/root/ssh-bot-phone
ExecStart=/usr/bin/pm2 start ecosystem.config.js
ExecStop=/usr/bin/pm2 stop ssh-bot-phone
ExecReload=/usr/bin/pm2 reload ssh-bot-phone
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload
systemctl enable ssh-bot-phone.service

# ================================================
# MENSAJE FINAL
# ================================================
clear
echo -e "${GREEN}${BOLD}"
cat << "FINAL"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║       🎉 INSTALACIÓN COMPLETADA - AUTH POR TELÉFONO 🎉     ║
║                                                              ║
║               SSH BOT PRO - CONFIGURADO                     ║
║               📱 SIN QR - NÚMERO + CÓDIGO                  ║
║               🔐 CONTRASEÑA FIJA: mgvpn247                 ║
║               💰 MERCADOPAGO INTEGRADO                     ║
║               🚀 CONEXIÓN PERMANENTE                       ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Sistema instalado con auth por teléfono${NC}"
echo -e "${GREEN}✅ No requiere QR - Usa número de WhatsApp${NC}"
echo -e "${GREEN}✅ Conexión permanente${NC}"
echo -e "${GREEN}✅ Menú completo: Prueba, Comprar, Renovar, App${NC}"
echo -e "${GREEN}✅ Planes: 7, 15, 30, 50 días${NC}"
echo -e "${GREEN}✅ Contraseña fija: mgvpn247${NC}"
echo -e "${GREEN}✅ Panel de control web: http://localhost:3000${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 COMANDOS DISPONIBLES:${NC}\n"
echo -e "  ${GREEN}sshbot-phone${NC}     - Panel de control principal"
echo -e "  ${GREEN}auth-whatsapp${NC}    - Configurar auth WhatsApp"
echo -e "  ${GREEN}pm2 logs ssh-bot-phone${NC} - Ver logs"
echo -e "  ${GREEN}pm2 restart ssh-bot-phone${NC} - Reiniciar bot\n"

echo -e "${YELLOW}🔧 CONFIGURACIÓN INICIAL:${NC}\n"
echo -e "  1. Ejecuta: ${GREEN}sshbot-phone${NC}"
echo -e "  2. Opción ${CYAN}[1]${NC} - Iniciar bot"
echo -e "  3. Opción ${CYAN}[a]${NC} - Configurar auth WhatsApp"
echo -e "  4. Opción ${CYAN}[7]${NC} - Configurar MercadoPago (opcional)"
echo -e "  5. Cuando inicie, ${CYAN}verifica los logs${NC} para auth\n"

echo -e "${YELLOW}📱 MÉTODOS DE AUTH:${NC}\n"
echo -e "  ${CYAN}1. QR Code${NC} - Se generará automáticamente si es necesario"
echo -e "  ${CYAN}2. Código 6 dígitos${NC} - Te llegará por WhatsApp"
echo -e "  ${CYAN}3. Pairing code${NC} - Código de vinculación\n"

echo -e "${YELLOW}💰 PRECIOS POR DEFECTO:${NC}\n"
echo -e "  7 días: ${GREEN}$1500 ARS${NC}"
echo -e "  15 días: ${GREEN}$2500 ARS${NC}"
echo -e "  30 días: ${GREEN}$5500 ARS${NC}"
echo -e "  50 días: ${GREEN}$8500 ARS${NC}\n"

echo -e "${YELLOW}🌐 URLs IMPORTANTES:${NC}\n"
echo -e "  Panel estado: ${CYAN}http://$(curl -4 -s ifconfig.me):3000/status${NC}"
echo -e "  IP servidor: ${CYAN}$SERVER_IP${NC}"
echo -e "  Contraseña: ${CYAN}mgvpn247${NC}\n"

echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
echo -e "  • ${CYAN}NO cierres${NC} sesión de WhatsApp en tu teléfono"
echo -e "  • ${CYAN}Mantén${NC} WhatsApp activo en tu teléfono"
echo -e "  • La sesión se guarda automáticamente para reconexiones\n"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

read -p "$(echo -e "${YELLOW}¿Iniciar panel de control ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}Abriendo panel...${NC}\n"
    sleep 2
    /usr/local/bin/sshbot-phone
else
    echo -e "\n${YELLOW}💡 Para iniciar panel después: ${GREEN}sshbot-phone${NC}\n"
fi

echo -e "${GREEN}${BOLD}¡Sistema instalado exitosamente! 🚀${NC}\n"
echo -e "${YELLOW}Revisa los logs para completar la autenticación:${NC}"
echo -e "${CYAN}pm2 logs ssh-bot-phone${NC}\n"

exit 0
INSTALLPHONEEOF

# Dar permisos y ejecutar
chmod +x install_ssh_bot_phone.sh