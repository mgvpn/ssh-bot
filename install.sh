#!/bin/bash
# ================================================
# SSH BOT PRO - INSTALADOR CORREGIDO
# ✅ Soluciona conflictos Node.js
# ✅ Compatible Ubuntu 20/22
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
║            🤖 SSH BOT PRO - INSTALADOR CORREGIDO         ║
║             ✅ SOLUCIÓN CONFLICTOS NODE.JS                ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Debes ejecutar como root${NC}"
    exit 1
fi

# Detectar sistema
echo -e "${CYAN}🔍 Detectando sistema...${NC}"
if [[ -f /etc/lsb-release ]]; then
    source /etc/lsb-release
    echo -e "${GREEN}✅ Ubuntu $DISTRIB_RELEASE ($DISTRIB_CODENAME)${NC}"
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
# PASO 1: LIMPIAR INSTALACIONES ANTERIORES
# ================================================
echo -e "\n${RED}🔄 PASO 1: Limpiando instalaciones anteriores...${NC}"

# Detener procesos si existen
pkill -f wppconnect 2>/dev/null || true
pkill -f chrome 2>/dev/null || true
pm2 delete sshbot 2>/dev/null || true

# Remover Node.js conflictivo
echo -e "${YELLOW}Removiendo Node.js antiguo...${NC}"
apt-get remove --purge -y nodejs libnode-dev 2>/dev/null || true
apt-get autoremove -y
rm -rf /usr/local/bin/node
rm -rf /usr/local/bin/npm
rm -rf /usr/local/lib/node_modules
rm -rf /etc/apt/sources.list.d/nodesource.list

# Limpiar apt
apt-get clean
apt-get autoclean

# ================================================
# PASO 2: INSTALAR DEPENDENCIAS BASE
# ================================================
echo -e "\n${CYAN}📦 PASO 2: Instalando dependencias base...${NC}"

apt-get update -y
apt-get upgrade -y

# Instalar dependencias esenciales
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
    libx11-xcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxi6 \
    libxtst6 \
    libnss3 \
    libcups2 \
    libxss1 \
    libxrandr2 \
    libasound2 \
    libpangocairo-1.0-0 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    gconf-service \
    libgconf-2-4 \
    libgbm-dev \
    libappindicator1 \
    fonts-liberation \
    xdg-utils \
    ca-certificates \
    lsb-release \
    gnupg

# ================================================
# PASO 3: INSTALAR NODE.JS 18.x SIN CONFLICTOS
# ================================================
echo -e "\n${CYAN}📦 PASO 3: Instalando Node.js 18.x...${NC}"

# Método alternativo para evitar conflictos
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -

# Forzar reinstalación limpiando primero
apt-get remove --purge -y nodejs 2>/dev/null || true
apt-get install -y nodejs --fix-broken --reinstall

# Verificar instalación
echo -e "\n${GREEN}✅ Node.js version: $(node --version 2>/dev/null || echo "No instalado")${NC}"
echo -e "${GREEN}✅ npm version: $(npm --version 2>/dev/null || echo "No instalado")${NC}"

# Si Node.js no se instaló, usar método alternativo
if ! command -v node &>/dev/null; then
    echo -e "${YELLOW}⚠️  Node.js no se instaló. Usando método alternativo...${NC}"
    
    # Descargar e instalar manualmente
    wget https://nodejs.org/dist/v18.20.4/node-v18.20.4-linux-x64.tar.xz
    tar -xf node-v18.20.4-linux-x64.tar.xz
    mv node-v18.20.4-linux-x64 /usr/local/lib/nodejs
    ln -sf /usr/local/lib/nodejs/bin/node /usr/local/bin/node
    ln -sf /usr/local/lib/nodejs/bin/npm /usr/local/bin/npm
    ln -sf /usr/local/lib/nodejs/bin/npx /usr/local/bin/npx
    
    export PATH=/usr/local/lib/nodejs/bin:$PATH
    echo 'export PATH=/usr/local/lib/nodejs/bin:$PATH' >> /etc/profile
    
    rm -f node-v18.20.4-linux-x64.tar.xz
fi

# ================================================
# PASO 4: INSTALAR CHROME
# ================================================
echo -e "\n${CYAN}📦 PASO 4: Instalando Chrome...${NC}"

# Remover chrome existente
apt-get remove --purge -y google-chrome-stable 2>/dev/null || true

# Instalar desde repositorio oficial
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

apt-get update -y
apt-get install -y google-chrome-stable --fix-broken

# Verificar
echo -e "${GREEN}✅ Chrome version: $(google-chrome --version 2>/dev/null | head -1 || echo "No instalado")${NC}"

# ================================================
# PASO 5: INSTALAR PM2
# ================================================
echo -e "\n${CYAN}📦 PASO 5: Instalando PM2...${NC}"

npm install -g pm2 --force
pm2 update

echo -e "${GREEN}✅ PM2 instalado${NC}"

# ================================================
# PASO 6: CREAR ESTRUCTURA
# ================================================
echo -e "\n${CYAN}📁 PASO 6: Creando estructura...${NC}"

INSTALL_DIR="/root/sshbot"
rm -rf "$INSTALL_DIR" 2>/dev/null || true
mkdir -p "$INSTALL_DIR"/{data,qr_codes,sessions,logs}

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

# Base de datos
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

echo -e "${GREEN}✅ Estructura creada${NC}"

# ================================================
# PASO 7: CREAR BOT SIMPLIFICADO
# ================================================
echo -e "\n${CYAN}🤖 PASO 7: Creando bot simplificado...${NC}"

cd "$INSTALL_DIR"

# Crear package.json simple
cat > package.json << 'PKGEOF'
{
    "name": "sshbot",
    "version": "1.0.0",
    "main": "bot.js",
    "scripts": {
        "start": "node bot.js"
    },
    "dependencies": {
        "@wppconnect-team/wppconnect": "^1.25.0",
        "qrcode-terminal": "^0.12.0",
        "qrcode": "^1.5.3",
        "moment": "^2.29.4",
        "sqlite3": "^5.1.6",
        "axios": "^1.6.0"
    }
}
PKGEOF

# Instalar dependencias paso a paso
echo -e "${YELLOW}Instalando dependencias...${NC}"
npm cache clean --force

# Instalar una por una para evitar errores
npm install sqlite3@5.1.6 --no-optional
npm install moment@2.29.4
npm install qrcode@1.5.3
npm install qrcode-terminal@0.12.0
npm install axios@1.6.0

# Instalar wppconnect con flags especiales
echo -e "${YELLOW}Instalando wppconnect (esto puede tardar)...${NC}"
npm install @wppconnect-team/wppconnect@1.25.0 --ignore-scripts --no-optional

echo -e "${GREEN}✅ Dependencias instaladas${NC}"

# Crear bot.js simplificado
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
const db = new sqlite3.Database('./data/users.db');

console.log('🚀 SSH BOT PRO - INICIANDO');

// Configuración
const config = {
    server_ip: 'SERVER_IP_PLACEHOLDER',
    default_password: 'mgvpn247',
    prices: {
        price_7d: 1500,
        price_15d: 2500,
        price_30d: 4000,
        price_50d: 6000
    }
};

// Reemplazar IP
const botCode = fs.readFileSync(__filename, 'utf8').replace('SERVER_IP_PLACEHOLDER', process.argv[2] || '127.0.0.1');

// Funciones SSH
async function createSSHUser(phone, username, days) {
    try {
        const password = config.default_password;
        
        if (days === 0) {
            // Test 1 hora
            await execPromise(`useradd -m -s /bin/bash ${username} && echo "${username}:${password}" | chpasswd`);
            const expire = moment().add(1, 'hour').format('YYYY-MM-DD HH:mm:ss');
            
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at) VALUES (?, ?, ?, 'test', ?)`,
                [phone, username, password, expire]);
            
            return { success: true, username, password };
        } else {
            // Premium
            const expireDate = moment().add(days, 'days').format('YYYY-MM-DD');
            await execPromise(`useradd -M -s /bin/false -e ${expireDate} ${username} && echo "${username}:${password}" | chpasswd`);
            
            const expire = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at) VALUES (?, ?, ?, 'premium', ?)`,
                [phone, username, password, expire]);
            
            return { success: true, username, password };
        }
    } catch (error) {
        console.error('Error crear usuario:', error);
        return { success: false, error: error.message };
    }
}

// Función para renovar usuario
async function renewSSHUser(username, days) {
    try {
        const currentExpire = await new Promise((resolve) => {
            db.get('SELECT expires_at FROM users WHERE username = ?', [username], (err, row) => {
                resolve(row ? row.expires_at : null);
            });
        });
        
        let newExpire;
        if (currentExpire) {
            newExpire = moment(currentExpire).add(days, 'days').format('YYYY-MM-DD 23:59:59');
        } else {
            newExpire = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
        }
        
        const systemExpire = moment(newExpire).format('YYYY-MM-DD');
        await execPromise(`usermod -e ${systemExpire} ${username}`);
        
        db.run(`UPDATE users SET expires_at = ? WHERE username = ?`, [newExpire, username]);
        
        return { success: true, newExpire };
    } catch (error) {
        return { success: false, error: error.message };
    }
}

// Iniciar bot de WhatsApp
async function startBot() {
    try {
        const client = await wppconnect.create({
            session: 'sshbot',
            headless: true,
            useChrome: true,
            logQR: true,
            browserArgs: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage'
            ],
            puppeteerOptions: {
                executablePath: '/usr/bin/google-chrome',
                headless: 'new'
            }
        });
        
        console.log('✅ WhatsApp conectado!');
        
        client.onMessage(async (message) => {
            try {
                const text = message.body.toLowerCase().trim();
                const from = message.from;
                
                if (from.includes('@g.us')) return;
                
                console.log(`📩 ${from}: ${text}`);
                
                // Menú principal
                if (['menu', 'hola', 'start', 'hi', '0'].includes(text)) {
                    const menu = `🚀 *BOT SSH VPN*

1️⃣ *PRUEBA GRATIS* (1 hora)
2️⃣ *COMPRAR PLAN*
3️⃣ *RENOVAR USUARIO*
4️⃣ *DESCARGAR APP*
5️⃣ *SOPORTE*

Escribe el número:`;
                    
                    await client.sendText(from, menu);
                    return;
                }
                
                // Opción 1: Prueba gratis
                if (text === '1') {
                    const username = 'test' + Math.floor(1000 + Math.random() * 9000);
                    const result = await createSSHUser(from, username, 0);
                    
                    if (result.success) {
                        const msg = `✅ *PRUEBA CREADA*

👤 Usuario: ${username}
🔑 Contraseña: ${result.password}
⏰ Expira: 1 hora
📱 IP: ${config.server_ip}

Instrucciones:
1. Usa cualquier cliente SSH
2. Puerto: 22
3. Conéctate con las credenciales`;
                        
                        await client.sendText(from, msg);
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    return;
                }
                
                // Opción 2: Comprar plan
                if (text === '2') {
                    const plans = `🌐 *PLANES DISPONIBLES*

1️⃣ 7 DÍAS - $${config.prices.price_7d}
2️⃣ 15 DÍAS - $${config.prices.price_15d}
3️⃣ 30 DÍAS - $${config.prices.price_30d}
4️⃣ 50 DÍAS - $${config.prices.price_50d}

Para comprar escribe: comprar [número]

Ejemplo: *comprar 1* para 7 días`;
                    
                    await client.sendText(from, plans);
                    return;
                }
                
                // Comando comprar
                if (text.startsWith('comprar ')) {
                    const planNum = text.replace('comprar ', '').trim();
                    const plans = {
                        '1': { days: 7, price: config.prices.price_7d },
                        '2': { days: 15, price: config.prices.price_15d },
                        '3': { days: 30, price: config.prices.price_30d },
                        '4': { days: 50, price: config.prices.price_50d }
                    };
                    
                    if (plans[planNum]) {
                        const plan = plans[planNum];
                        const username = 'user' + Math.floor(1000 + Math.random() * 9000);
                        
                        await client.sendText(from, `⏳ Creando usuario ${username}...`);
                        
                        const result = await createSSHUser(from, username, plan.days);
                        
                        if (result.success) {
                            const msg = `✅ *USUARIO CREADO*

👤 Usuario: ${username}
🔑 Contraseña: ${result.password}
⏰ Duración: ${plan.days} días
💰 Precio: $${plan.price}
📱 IP: ${config.server_ip}

Para pagar contacta al administrador:
https://wa.me/543435071016`;
                            
                            await client.sendText(from, msg);
                        } else {
                            await client.sendText(from, `❌ Error: ${result.error}`);
                        }
                    } else {
                        await client.sendText(from, '❌ Plan inválido. Usa: comprar 1, comprar 2, etc.');
                    }
                    return;
                }
                
                // Opción 3: Renovar usuario
                if (text === '3') {
                    await client.sendText(from, `🔄 *RENOVAR USUARIO*

Para renovar escribe:
*renovar [usuario] [días]*

Ejemplo: renovar usuario123 30

Contacta al administrador para el pago:
https://wa.me/543435071016`);
                    return;
                }
                
                // Comando renovar
                if (text.startsWith('renovar ')) {
                    const parts = text.replace('renovar ', '').split(' ');
                    if (parts.length >= 2) {
                        const username = parts[0];
                        const days = parseInt(parts[1]);
                        
                        if (isNaN(days) || days <= 0) {
                            await client.sendText(from, '❌ Días inválidos');
                            return;
                        }
                        
                        const result = await renewSSHUser(username, days);
                        
                        if (result.success) {
                            const msg = `✅ *USUARIO RENOVADO*

👤 Usuario: ${username}
⏰ Nueva expiración: ${moment(result.newExpire).format('DD/MM/YYYY')}
📅 Días agregados: ${days}

Para pagar la renovación contacta:
https://wa.me/543435071016`;
                            
                            await client.sendText(from, msg);
                        } else {
                            await client.sendText(from, `❌ Error: ${result.error}`);
                        }
                    } else {
                        await client.sendText(from, '❌ Formato incorrecto. Usa: renovar [usuario] [días]');
                    }
                    return;
                }
                
                // Opción 4: Descargar app
                if (text === '4') {
                    await client.sendText(from, `📱 *DESCARGAR APP*

🔗 https://www.mediafire.com/file/p8kgthxbsid7xws/MAJ/DNI_AND_FIL

Instrucciones:
1. Descarga el APK
2. Permite instalación de fuentes desconocidas
3. Instala y configura con tus credenciales`);
                    return;
                }
                
                // Opción 5: Soporte
                if (text === '5') {
                    await client.sendText(from, `📞 *SOPORTE*

Para ayuda contacta:
https://wa.me/543435071016`);
                    return;
                }
                
                // Mensaje no reconocido
                await client.sendText(from, '⚠️ Escribe *menu* para ver las opciones');
                
            } catch (error) {
                console.error('Error mensaje:', error);
            }
        });
        
        // Mantener vivo
        client.onStateChange((state) => {
            console.log('📡 Estado WhatsApp:', state);
        });
        
    } catch (error) {
        console.error('❌ Error bot:', error);
        setTimeout(startBot, 5000);
    }
}

// Iniciar
startBot();
BOTEOF

# Reemplazar IP en el bot
sed -i "s/SERVER_IP_PLACEHOLDER/$SERVER_IP/g" "$INSTALL_DIR/bot.js"

echo -e "${GREEN}✅ Bot creado${NC}"

# ================================================
# PASO 8: CREAR PANEL DE CONTROL
# ================================================
echo -e "\n${CYAN}🎛️  PASO 8: Creando panel de control...${NC}"

cat > /usr/local/bin/sshbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="/root/sshbot"

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                🎛️  CONTROL SSH BOT                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

while true; do
    show_header
    
    # Estado
    if pm2 status | grep -q "online.*sshbot"; then
        STATUS="${GREEN}● ACTIVO${NC}"
    else
        STATUS="${RED}● DETENIDO${NC}"
    fi
    
    echo -e "${YELLOW}📊 ESTADO:${NC} $STATUS"
    echo -e ""
    
    echo -e "${CYAN}[1]${NC} 🚀 Iniciar bot"
    echo -e "${CYAN}[2]${NC} 🛑 Detener bot"
    echo -e "${CYAN}[3]${NC} 📱 Ver logs/QR"
    echo -e "${CYAN}[4]${NC} 👤 Crear usuario"
    echo -e "${CYAN}[5]${NC} 👥 Ver usuarios"
    echo -e "${CYAN}[6]${NC} 🔄 Renovar usuario"
    echo -e "${CYAN}[7]${NC} 🧹 Limpiar sesión"
    echo -e "${CYAN}[8]${NC} 🛠️  Reinstalar bot"
    echo -e "${CYAN}[0]${NC} 🚪 Salir"
    echo -e ""
    
    read -p "👉 Opción: " OPT
    
    case $OPT in
        1)
            echo -e "\n${YELLOW}🔄 Iniciando...${NC}"
            cd "$INSTALL_DIR"
            pm2 start bot.js --name sshbot 2>/dev/null || pm2 restart sshbot
            echo -e "${GREEN}✅ Bot iniciado${NC}"
            sleep 2
            ;;
        2)
            echo -e "\n${YELLOW}🛑 Deteniendo...${NC}"
            pm2 stop sshbot 2>/dev/null
            echo -e "${GREEN}✅ Bot detenido${NC}"
            sleep 2
            ;;
        3)
            echo -e "\n${YELLOW}📱 Mostrando logs...${NC}"
            echo -e "${CYAN}Presiona Ctrl+C para salir${NC}\n"
            pm2 logs sshbot
            ;;
        4)
            echo -e "\n${CYAN}👤 CREAR USUARIO${NC}"
            read -p "Usuario: " USERNAME
            read -p "Días (0=test): " DAYS
            
            if [[ "$DAYS" -eq 0 ]]; then
                useradd -m -s /bin/bash "$USERNAME" && echo "$USERNAME:mgvpn247" | chpasswd
                echo -e "${GREEN}✅ Test creado: $USERNAME${NC}"
            else
                useradd -M -s /bin/false -e "$(date -d "+$DAYS days" +%Y-%m-%d)" "$USERNAME" && echo "$USERNAME:mgvpn247" | chpasswd
                echo -e "${GREEN}✅ Premium creado: $USERNAME por $DAYS días${NC}"
            fi
            read -p "Enter..."
            ;;
        5)
            echo -e "\n${CYAN}👥 USUARIOS${NC}"
            echo -e "${YELLOW}Usuarios del sistema:${NC}"
            echo -e "Usuario       | Expiración"
            echo -e "--------------|-----------"
            getent passwd | grep -E "(test|user)[0-9]+" | cut -d: -f1 | while read user; do
                expire=$(chage -l "$user" 2>/dev/null | grep "Account expires" | cut -d: -f2)
                echo -e "$user       | $expire"
            done
            echo -e ""
            read -p "Enter..."
            ;;
        6)
            echo -e "\n${CYAN}🔄 RENOVAR USUARIO${NC}"
            read -p "Usuario: " USERNAME
            read -p "Días adicionales: " DAYS
            
            if id "$USERNAME" &>/dev/null; then
                CURRENT=$(chage -l "$USERNAME" | grep "Account expires" | cut -d: -f2 | xargs)
                if [[ "$CURRENT" == "never" ]]; then
                    NEW_EXPIRE=$(date -d "+$DAYS days" +%Y-%m-%d)
                else
                    NEW_EXPIRE=$(date -d "$CURRENT + $DAYS days" +%Y-%m-%d)
                fi
                
                usermod -e "$NEW_EXPIRE" "$USERNAME"
                echo -e "${GREEN}✅ $USERNAME renovado hasta $NEW_EXPIRE${NC}"
            else
                echo -e "${RED}❌ Usuario no existe${NC}"
            fi
            read -p "Enter..."
            ;;
        7)
            echo -e "\n${YELLOW}🧹 Limpiando...${NC}"
            pm2 stop sshbot 2>/dev/null
            rm -rf /root/.wppconnect/*
            echo -e "${GREEN}✅ Sesión limpiada${NC}"
            echo -e "${YELLOW}📱 Escanea nuevo QR al iniciar${NC}"
            sleep 2
            ;;
        8)
            echo -e "\n${RED}⚠️  Esto reinstalará el bot${NC}"
            read -p "¿Continuar? (s/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                echo -e "${YELLOW}Reinstalando...${NC}"
                curl -s https://raw.githubusercontent.com/tu-repo/sshbot/main/install.sh | bash
            fi
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

# ================================================
# PASO 9: CONFIGURAR SERVICIO
# ================================================
echo -e "\n${CYAN}⚙️  PASO 9: Configurando servicio...${NC}"

cd "$INSTALL_DIR"
pm2 start bot.js --name sshbot
pm2 save
pm2 startup systemd -u root --hp /root

# ================================================
# PASO 10: VERIFICAR INSTALACIÓN
# ================================================
echo -e "\n${CYAN}✅ PASO 10: Verificando instalación...${NC}"

echo -e "${YELLOW}Componentes instalados:${NC}"
echo -e "Node.js: $(node --version 2>/dev/null || echo "❌ No instalado")"
echo -e "Chrome: $(google-chrome --version 2>/dev/null | head -1 || echo "❌ No instalado")"
echo -e "PM2: $(pm2 --version 2>/dev/null || echo "❌ No instalado")"
echo -e "Bot: $(pm2 list | grep sshbot | awk '{print $4}' || echo "❌ No ejecutándose")"

# ================================================
# FINALIZAR
# ================================================
clear
echo -e "${GREEN}${BOLD}"
cat << "FINAL"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║         ✅ SSH BOT PRO - INSTALACIÓN COMPLETADA            ║
║             🚀 PROBLEMAS DE NODE.JS SOLUCIONADOS           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🎉 ¡INSTALACIÓN EXITOSA!${NC}\n"
echo -e "${YELLOW}📋 COMANDOS DISPONIBLES:${NC}"
echo -e "  ${GREEN}sshbot${NC}          - Panel de control"
echo -e "  ${GREEN}pm2 logs sshbot${NC} - Ver logs y escanear QR"
echo -e "  ${GREEN}pm2 status${NC}      - Ver estado"
echo -e "\n${YELLOW}📱 PARA ESCANEAR QR:${NC}"
echo -e "1. Ejecuta: ${GREEN}pm2 logs sshbot${NC}"
echo -e "2. Espera a que aparezca el código QR"
echo -e "3. Escanéalo con WhatsApp"
echo -e "\n${YELLOW}⚠️  SOLUCIÓN DE PROBLEMAS:${NC}"
echo -e "Si no aparece el QR:"
echo -e "  ${GREEN}pm2 stop sshbot${NC}"
echo -e "  ${GREEN}rm -rf /root/.wppconnect/*${NC}"
echo -e "  ${GREEN}pm2 start sshbot${NC}"
echo -e "  ${GREEN}pm2 logs sshbot${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${GREEN}✅ El bot está listo para usar!${NC}\n"

read -p "$(echo -e "${YELLOW}¿Ver logs ahora para escanear QR? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}📱 Esperando QR... (Ctrl+C para salir)${NC}\n"
    pm2 logs sshbot
else
    echo -e "\n${YELLOW}Ejecuta ${GREEN}pm2 logs sshbot${NC} ${YELLOW}para ver el QR${NC}"
fi

echo -e "\n${GREEN}✨ Instalación completada exitosamente!${NC}\n"
exit 0