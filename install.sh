#!/bin/bash
# ================================================
# SSH BOT PRO - VERSIÓN COMPLETA Y FUNCIONAL
# WPPConnect + MercadoPago REAL + Estados fijos
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
║                  SSH BOT PRO - VERSIÓN 3.0                  ║
║               ✅ ESTADOS FIJOS + MERCADOPAGO                ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CARACTERÍSTICAS PRINCIPALES:${NC}"
echo -e "  📱 ${CYAN}Estados persistentes${NC} - No vuelve al menú"
echo -e "  💰 ${GREEN}MercadoPago REAL${NC} - Genera links de pago"
echo -e "  💳 ${YELLOW}QR de pago${NC} - Enviado automáticamente"
echo -e "  🎛️  ${BLUE}Panel completo${NC} - Gestión total"
echo -e "  ⚡ ${GREEN}Respuestas rápidas${NC} - Sin delays"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Debes ejecutar como root${NC}"
    exit 1
fi

# Detectar IP
echo -e "${CYAN}🔍 Detectando IP...${NC}"
SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "127.0.0.1")
if [[ -z "$SERVER_IP" || "$SERVER_IP" == "127.0.0.1" ]]; then
    read -p "📝 Ingresa la IP del servidor: " SERVER_IP
fi

echo -e "${GREEN}✅ IP: ${CYAN}$SERVER_IP${NC}\n"

read -p "$(echo -e "${YELLOW}¿Continuar? (s/N): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
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

# Chrome
apt-get install -y wget gnupg
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get update -y
apt-get install -y google-chrome-stable

# Otras dependencias
apt-get install -y git curl wget sqlite3 jq python3 python3-pip unzip cron

# PM2
npm install -g pm2

echo -e "${GREEN}✅ Dependencias instaladas${NC}"

# ================================================
# CREAR ESTRUCTURA
# ================================================
echo -e "\n${CYAN}📁 Creando estructura...${NC}"

INSTALL_DIR="/root/sshbot-pro"
DB_FILE="$INSTALL_DIR/data/users.db"
STATE_FILE="$INSTALL_DIR/data/states.db"

# Limpiar anterior
pm2 delete sshbot-pro 2>/dev/null || true
rm -rf "$INSTALL_DIR" 2>/dev/null || true

# Crear directorios
mkdir -p "$INSTALL_DIR"/{data,config,qr_codes,logs}
chmod -R 755 "$INSTALL_DIR"

# Configuración
cat > "$INSTALL_DIR/config/config.json" << EOF
{
    "bot": {
        "name": "SSH Bot Pro",
        "server_ip": "$SERVER_IP",
        "default_password": "mgvpn247"
    },
    "prices": {
        "test_hours": 1,
        "price_7d": 1500.00,
        "price_15d": 2500.00,
        "price_30d": 4000.00,
        "price_50d": 6000.00,
        "currency": "ARS"
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false
    },
    "links": {
        "app_download": "https://www.mediafire.com/file/p8kgthxbsid7xws/MAJ/DNI_AND_FIL",
        "support": "https://wa.me/543435071016"
    }
}
EOF

# Base de datos con estados
sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    username TEXT UNIQUE,
    password TEXT DEFAULT 'mgvpn247',
    tipo TEXT DEFAULT 'test',
    expires_at DATETIME,
    status INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_id TEXT UNIQUE,
    phone TEXT,
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
    state TEXT DEFAULT 'main_menu',
    plan_data TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
SQL

# Base de datos de estados
sqlite3 "$STATE_FILE" << 'SQL'
CREATE TABLE IF NOT EXISTS states (
    phone TEXT PRIMARY KEY,
    state TEXT DEFAULT 'main_menu',
    data TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
SQL

echo -e "${GREEN}✅ Estructura creada${NC}"

# ================================================
# CREAR BOT FUNCIONAL
# ================================================
echo -e "\n${CYAN}🤖 Creando bot funcional...${NC}"

cd "$INSTALL_DIR"

# package.json
cat > package.json << 'PKGEOF'
{
    "name": "sshbot-pro",
    "version": "3.0.0",
    "main": "bot.js",
    "dependencies": {
        "@wppconnect-team/wppconnect": "^1.25.0",
        "qrcode-terminal": "^0.12.0",
        "qrcode": "^1.5.3",
        "moment": "^2.29.4",
        "sqlite3": "^5.1.6",
        "chalk": "^4.1.2",
        "node-cron": "^3.0.2",
        "axios": "^1.6.0",
        "mercadopago": "^2.1.0"
    }
}
PKGEOF

echo -e "${YELLOW}📦 Instalando dependencias Node.js...${NC}"
npm install --silent

# BOT.JS COMPLETO Y FUNCIONAL
cat > "bot.js" << 'BOTEOF'
// ================================================
// SSH BOT PRO - VERSIÓN COMPLETA
// Estados persistentes + MercadoPago real
// ================================================

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

// Cargar configuración
const config = require('./config/config.json');
const db = new sqlite3.Database('./data/users.db');
const stateDb = new sqlite3.Database('./data/states.db');

console.log(chalk.green.bold('\n🚀 SSH BOT PRO - INICIANDO'));
console.log(chalk.cyan(`📱 IP: ${config.bot.server_ip}`));
console.log(chalk.cyan(`🔑 Contraseña: ${config.bot.default_password}`));

// Sistema de estados persistente
function getState(phone) {
    return new Promise((resolve) => {
        stateDb.get('SELECT state, data FROM states WHERE phone = ?', [phone], (err, row) => {
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

function setState(phone, state, data = null) {
    return new Promise((resolve) => {
        const dataStr = data ? JSON.stringify(data) : null;
        stateDb.run(
            `INSERT OR REPLACE INTO states (phone, state, data, timestamp) VALUES (?, ?, ?, CURRENT_TIMESTAMP)`,
            [phone, state, dataStr],
            (err) => {
                if (err) console.error(chalk.red('❌ Error estado:'), err.message);
                resolve();
            }
        );
    });
}

function clearState(phone) {
    stateDb.run('DELETE FROM states WHERE phone = ?', [phone]);
}

// Funciones auxiliares
function generateUsername() {
    return 'user' + Math.floor(1000 + Math.random() * 9000);
}

async function createSSHUser(phone, username, days) {
    const password = config.bot.default_password;
    
    try {
        if (days === 0) {
            // Test
            const expireFull = moment().add(config.prices.test_hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
            await execPromise(`useradd -m -s /bin/bash ${username} && echo "${username}:${password}" | chpasswd`);
            
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at) VALUES (?, ?, ?, 'test', ?)`,
                [phone, username, password, expireFull]);
            
            return { success: true, username, password, expires: expireFull };
        } else {
            // Premium
            const expireFull = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
            await execPromise(`useradd -M -s /bin/false -e ${moment().add(days, 'days').format('YYYY-MM-DD')} ${username} && echo "${username}:${password}" | chpasswd`);
            
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at) VALUES (?, ?, ?, 'premium', ?)`,
                [phone, username, password, expireFull]);
            
            return { success: true, username, password, expires: expireFull };
        }
    } catch (error) {
        console.error(chalk.red('❌ Error creando SSH:'), error.message);
        return { success: false, error: error.message };
    }
}

// MERCADOPAGO FUNCIONAL
async function createMercadoPagoPayment(phone, days, amount, planName) {
    try {
        if (!config.mercadopago.access_token) {
            return { success: false, error: 'MercadoPago no configurado' };
        }
        
        const phoneClean = phone.replace('@c.us', '');
        const paymentId = `ssh-${phoneClean}-${days}d-${Date.now()}`;
        
        console.log(chalk.cyan(`🔄 Creando pago MP: ${paymentId}`));
        
        // Datos para la preferencia
        const preferenceData = {
            items: [{
                title: `SSH PREMIUM ${days} DÍAS`,
                description: `Acceso SSH Premium por ${days} días - 1 conexión`,
                quantity: 1,
                currency_id: config.prices.currency,
                unit_price: parseFloat(amount)
            }],
            external_reference: paymentId,
            expires: true,
            expiration_date_from: moment().toISOString(),
            expiration_date_to: moment().add(24, 'hours').toISOString(),
            back_urls: {
                success: `https://wa.me/${phoneClean}`,
                failure: `https://wa.me/${phoneClean}`,
                pending: `https://wa.me/${phoneClean}`
            },
            auto_return: 'approved'
        };
        
        // Llamada a API de MercadoPago
        const response = await axios.post(
            'https://api.mercadopago.com/checkout/preferences',
            preferenceData,
            {
                headers: {
                    'Authorization': `Bearer ${config.mercadopago.access_token}`,
                    'Content-Type': 'application/json'
                }
            }
        );
        
        if (response.data && response.data.id) {
            const paymentUrl = response.data.init_point;
            const qrPath = `./qr_codes/${paymentId}.png`;
            
            // Generar QR
            await QRCode.toFile(qrPath, paymentUrl, { 
                width: 400,
                margin: 2
            });
            
            // Guardar en BD
            db.run(
                `INSERT INTO payments (payment_id, phone, plan, days, amount, payment_url, qr_code) VALUES (?, ?, ?, ?, ?, ?, ?)`,
                [paymentId, phone, `${days}d`, days, amount, paymentUrl, qrPath]
            );
            
            console.log(chalk.green(`✅ Pago creado: ${paymentId}`));
            
            return { 
                success: true, 
                paymentId, 
                paymentUrl, 
                qrPath,
                amount: parseFloat(amount)
            };
        }
        
        return { success: false, error: 'Error en respuesta de MP' };
        
    } catch (error) {
        console.error(chalk.red('❌ Error MercadoPago:'), error.message);
        return { success: false, error: error.message };
    }
}

// Inicializar bot
async function startBot() {
    try {
        console.log(chalk.yellow('🚀 Conectando WhatsApp...'));
        
        const client = await wppconnect.create({
            session: 'sshbot-pro',
            headless: true,
            devtools: false,
            useChrome: true,
            debug: false,
            logQR: true,
            browserArgs: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage'
            ],
            puppeteerOptions: {
                executablePath: '/usr/bin/google-chrome',
                headless: 'new'
            },
            disableWelcome: true,
            updatesLog: false
        });
        
        console.log(chalk.green('✅ WhatsApp conectado!'));
        
        // Manejar mensajes
        client.onMessage(async (message) => {
            try {
                const text = message.body.toLowerCase().trim();
                const from = message.from;
                
                // Ignorar grupos
                if (from.includes('@g.us')) return;
                
                console.log(chalk.cyan(`📩 [${from.split('@')[0]}]: ${text}`));
                
                // Obtener estado actual
                const userState = await getState(from);
                
                // ========== MENÚ PRINCIPAL ==========
                if (['menu', 'hola', 'start', 'hi', '0'].includes(text)) {
                    await setState(from, 'main_menu');
                    
                    const menu = `🤖 *SSH BOT PRO* - ${config.bot.server_ip}

*Elija una opción:*

1️⃣ *PRUEBA GRATIS* (${config.prices.test_hours} hora)
2️⃣ *COMPRAR PLAN* (Planes disponibles)
3️⃣ *DESCARGAR APP*
4️⃣ *SOPORTE*

👉 *Escribe el número:*`;
                    
                    await client.sendText(from, menu);
                    return;
                }
                
                // ========== OPCIÓN 1: PRUEBA ==========
                if (text === '1' && userState.state === 'main_menu') {
                    await client.sendText(from, '⏳ Creando prueba gratuita...');
                    
                    const username = 'test' + Math.floor(1000 + Math.random() * 9000);
                    const result = await createSSHUser(from, username, 0);
                    
                    if (result.success) {
                        const msg = `✅ *PRUEBA CREADA*

👤 *Usuario:* \`${username}\`
🔑 *Contraseña:* \`${config.bot.default_password}\`
⏰ *Expira:* ${config.prices.test_hours} hora
📱 *App:* ${config.links.app_download}

¡Disfruta tu prueba!`;
                        
                        await client.sendText(from, msg);
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    
                    await setState(from, 'main_menu');
                    return;
                }
                
                // ========== OPCIÓN 2: COMPRAR ==========
                if (text === '2' && userState.state === 'main_menu') {
                    await setState(from, 'selecting_plan_type');
                    
                    const plansMenu = `📋 *SELECCIONAR TIPO DE PLAN*

1️⃣ *PLANES DIARIOS* (7-15 días)
2️⃣ *PLANES MENSUALES* (30-50 días)

0️⃣ Volver`;
                    
                    await client.sendText(from, plansMenu);
                    return;
                }
                
                // ========== SELECCIONAR TIPO DE PLAN ==========
                if (userState.state === 'selecting_plan_type') {
                    if (text === '1') {
                        await setState(from, 'selecting_daily_plan');
                        
                        const dailyPlans = `🗓️ *PLANES DIARIOS*

1️⃣ 7 DÍAS - $${config.prices.price_7d}
2️⃣ 15 DÍAS - $${config.prices.price_15d}

0️⃣ Volver`;
                        
                        await client.sendText(from, dailyPlans);
                        return;
                    }
                    
                    if (text === '2') {
                        await setState(from, 'selecting_monthly_plan');
                        
                        const monthlyPlans = `🗓️ *PLANES MENSUALES*

1️⃣ 30 DÍAS - $${config.prices.price_30d}
2️⃣ 50 DÍAS - $${config.prices.price_50d}

0️⃣ Volver`;
                        
                        await client.sendText(from, monthlyPlans);
                        return;
                    }
                    
                    if (text === '0') {
                        await setState(from, 'main_menu');
                        await client.sendText(from, 'Volviendo al menú principal...');
                        return;
                    }
                }
                
                // ========== SELECCIONAR PLAN DIARIO ==========
                if (userState.state === 'selecting_daily_plan') {
                    const planMap = {
                        '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                        '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' }
                    };
                    
                    if (planMap[text]) {
                        const plan = planMap[text];
                        await setState(from, 'processing_payment', plan);
                        
                        // Verificar MercadoPago
                        if (!config.mercadopago.access_token) {
                            const msg = `📋 *PLAN ${plan.name}*

💰 *Precio:* $${plan.price}
⏰ *Duración:* ${plan.days} días
🔑 *Contraseña:* ${config.bot.default_password}

⚠️ *MercadoPago no configurado*
Contacta al administrador:
${config.links.support}`;
                            
                            await client.sendText(from, msg);
                            await setState(from, 'main_menu');
                            return;
                        }
                        
                        // Crear pago con MercadoPago
                        await client.sendText(from, `⏳ Generando pago para plan ${plan.name}...`);
                        
                        const payment = await createMercadoPagoPayment(
                            from, 
                            plan.days, 
                            plan.price, 
                            plan.name
                        );
                        
                        if (payment.success) {
                            // Mensaje con enlace
                            const msg = `💳 *PAGO ${plan.name}*

✅ *Enlace de pago generado:*
${payment.paymentUrl}

💰 *Monto:* $${payment.amount}
⏰ *Válido por:* 24 horas

📱 *Escanear QR:* (se enviará a continuación)`;
                            
                            await client.sendText(from, msg);
                            
                            // Enviar QR
                            if (fs.existsSync(payment.qrPath)) {
                                await client.sendImage(
                                    from,
                                    payment.qrPath,
                                    'qr-pago.jpg',
                                    `Escanea con MercadoPago\nPlan: ${plan.name}\nMonto: $${payment.amount}`
                                );
                            }
                            
                        } else {
                            await client.sendText(from, `❌ *ERROR AL GENERAR PAGO*

${payment.error}

Contacta soporte:
${config.links.support}`);
                        }
                        
                        await setState(from, 'main_menu');
                        return;
                    }
                    
                    if (text === '0') {
                        await setState(from, 'selecting_plan_type');
                        await client.sendText(from, 'Volviendo...');
                        return;
                    }
                }
                
                // ========== SELECCIONAR PLAN MENSUAL ==========
                if (userState.state === 'selecting_monthly_plan') {
                    const planMap = {
                        '1': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                        '2': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                    };
                    
                    if (planMap[text]) {
                        const plan = planMap[text];
                        await setState(from, 'processing_payment', plan);
                        
                        // Verificar MercadoPago
                        if (!config.mercadopago.access_token) {
                            const msg = `📋 *PLAN ${plan.name}*

💰 *Precio:* $${plan.price}
⏰ *Duración:* ${plan.days} días
🔑 *Contraseña:* ${config.bot.default_password}

⚠️ *MercadoPago no configurado*
Contacta al administrador:
${config.links.support}`;
                            
                            await client.sendText(from, msg);
                            await setState(from, 'main_menu');
                            return;
                        }
                        
                        // Crear pago con MercadoPago
                        await client.sendText(from, `⏳ Generando pago para plan ${plan.name}...`);
                        
                        const payment = await createMercadoPagoPayment(
                            from, 
                            plan.days, 
                            plan.price, 
                            plan.name
                        );
                        
                        if (payment.success) {
                            // Mensaje con enlace
                            const msg = `💳 *PAGO ${plan.name}*

✅ *Enlace de pago generado:*
${payment.paymentUrl}

💰 *Monto:* $${payment.amount}
⏰ *Válido por:* 24 horas

📱 *Escanear QR:* (se enviará a continuación)`;
                            
                            await client.sendText(from, msg);
                            
                            // Enviar QR
                            if (fs.existsSync(payment.qrPath)) {
                                await client.sendImage(
                                    from,
                                    payment.qrPath,
                                    'qr-pago.jpg',
                                    `Escanea con MercadoPago\nPlan: ${plan.name}\nMonto: $${payment.amount}`
                                );
                            }
                            
                        } else {
                            await client.sendText(from, `❌ *ERROR AL GENERAR PAGO*

${payment.error}

Contacta soporte:
${config.links.support}`);
                        }
                        
                        await setState(from, 'main_menu');
                        return;
                    }
                    
                    if (text === '0') {
                        await setState(from, 'selecting_plan_type');
                        await client.sendText(from, 'Volviendo...');
                        return;
                    }
                }
                
                // ========== OPCIÓN 3: APP ==========
                if (text === '3' && userState.state === 'main_menu') {
                    const msg = `📱 *DESCARGAR APLICACIÓN*

🔗 *Enlace:* ${config.links.app_download}

💡 *Instrucciones:*
1. Descarga el APK
2. Click en "Más detalles"
3. Click en "Instalar de todas formas"
4. Configura con tus credenciales

🔑 *Credenciales:*
Usuario: (se te proporcionará)
Contraseña: ${config.bot.default_password}`;
                    
                    await client.sendText(from, msg);
                    await setState(from, 'main_menu');
                    return;
                }
                
                // ========== OPCIÓN 4: SOPORTE ==========
                if (text === '4' && userState.state === 'main_menu') {
                    const msg = `📞 *SOPORTE*

Para ayuda personalizada:
${config.links.support}

Horario: 24/7`;
                    
                    await client.sendText(from, msg);
                    await setState(from, 'main_menu');
                    return;
                }
                
                // ========== MENSAJE NO RECONOCIDO ==========
                if (userState.state === 'main_menu') {
                    await client.sendText(from, '⚠️ *Comando no reconocido*\nEscribe *menu* para ver las opciones.');
                } else {
                    await client.sendText(from, '⚠️ *Opción no válida en este menú*\nEscribe *0* para volver.');
                }
                
            } catch (error) {
                console.error(chalk.red('❌ Error en mensaje:'), error);
            }
        });
        
        // Limpiar estados antiguos cada hora
        cron.schedule('0 * * * *', () => {
            stateDb.run("DELETE FROM states WHERE timestamp < datetime('now', '-1 hour')");
        });
        
        // Verificar pagos pendientes
        cron.schedule('*/2 * * * *', async () => {
            if (!config.mercadopago.access_token) return;
            
            console.log(chalk.yellow('🔍 Verificando pagos...'));
            
            db.all('SELECT * FROM payments WHERE status = "pending"', async (err, payments) => {
                if (err || !payments) return;
                
                for (const payment of payments) {
                    try {
                        // Verificar con API de MP
                        const response = await axios.get(
                            `https://api.mercadopago.com/v1/payments/search?external_reference=${payment.payment_id}`,
                            {
                                headers: {
                                    'Authorization': `Bearer ${config.mercadopago.access_token}`
                                }
                            }
                        );
                        
                        if (response.data.results && response.data.results[0]?.status === 'approved') {
                            console.log(chalk.green(`✅ Pago aprobado: ${payment.payment_id}`));
                            
                            // Crear usuario
                            const username = generateUsername();
                            await createSSHUser(payment.phone, username, payment.days);
                            
                            // Actualizar estado
                            db.run('UPDATE payments SET status = "approved" WHERE payment_id = ?', [payment.payment_id]);
                            
                            // Notificar al usuario
                            await client.sendText(payment.phone, 
                                `✅ *PAGO APROBADO*\n\nTu cuenta ha sido creada:\n👤 Usuario: ${username}\n🔑 Contraseña: ${config.bot.default_password}\n⏰ Duración: ${payment.days} días`
                            );
                        }
                    } catch (error) {
                        console.error(chalk.red(`❌ Error verificando pago: ${error.message}`));
                    }
                }
            });
        });
        
        console.log(chalk.green.bold('✅ Bot listo para recibir mensajes!'));
        
    } catch (error) {
        console.error(chalk.red('❌ Error inicializando bot:'), error);
        setTimeout(startBot, 5000);
    }
}

// Iniciar
startBot();

process.on('SIGINT', () => {
    console.log(chalk.yellow('\n🛑 Cerrando bot...'));
    process.exit();
});
BOTEOF

echo -e "${GREEN}✅ Bot creado${NC}"

# ================================================
# CREAR PANEL DE CONTROL
# ================================================
echo -e "\n${CYAN}🎛️  Creando panel de control...${NC}"

cat > /usr/local/bin/sshbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="/root/sshbot-pro"
DB="$INSTALL_DIR/data/users.db"
CONFIG="$INSTALL_DIR/config/config.json"

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
    echo -e "${CYAN}║                🎛️  PANEL SSH BOT PRO                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

while true; do
    show_header
    
    # Estadísticas
    TOTAL_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1" 2>/dev/null || echo "0")
    PENDING_PAYMENTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='pending'" 2>/dev/null || echo "0")
    
    # Estado bot
    if pm2 status | grep -q "online.*sshbot-pro"; then
        BOT_STATUS="${GREEN}● ACTIVO${NC}"
    else
        BOT_STATUS="${RED}● DETENIDO${NC}"
    fi
    
    # Estado MP
    MP_TOKEN=$(get_val '.mercadopago.access_token')
    if [[ -n "$MP_TOKEN" ]]; then
        MP_STATUS="${GREEN}✅ CONFIGURADO${NC}"
    else
        MP_STATUS="${RED}❌ NO CONFIGURADO${NC}"
    fi
    
    echo -e "${YELLOW}📊 ESTADO DEL SISTEMA${NC}"
    echo -e "  Bot: $BOT_STATUS"
    echo -e "  MP: $MP_STATUS"
    echo -e "  Usuarios: ${CYAN}$ACTIVE_USERS/$TOTAL_USERS${NC} activos/total"
    echo -e "  Pagos pendientes: ${CYAN}$PENDING_PAYMENTS${NC}"
    echo -e ""
    
    echo -e "${YELLOW}💰 PRECIOS${NC}"
    echo -e "  📅 Diarios:"
    echo -e "    7d: $ $(get_val '.prices.price_7d')"
    echo -e "    15d: $ $(get_val '.prices.price_15d')"
    echo -e "  📅 Mensuales:"
    echo -e "    30d: $ $(get_val '.prices.price_30d')"
    echo -e "    50d: $ $(get_val '.prices.price_50d')"
    echo -e ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC} 🚀 Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC} 🛑 Detener bot"
    echo -e "${CYAN}[3]${NC} 📱 Ver logs"
    echo -e "${CYAN}[4]${NC} 👤 Crear usuario"
    echo -e "${CYAN}[5]${NC} 👥 Listar usuarios"
    echo -e "${CYAN}[6]${NC} 🔑 Configurar MP"
    echo -e "${CYAN}[7]${NC} 💰 Cambiar precios"
    echo -e "${CYAN}[8]${NC} 💳 Ver pagos"
    echo -e "${CYAN}[9]${NC} 🧹 Limpiar sesión"
    echo -e "${CYAN}[0]${NC} 🚪 Salir"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "👉 Opción: " OPT
    
    case $OPT in
        1)
            echo -e "\n${YELLOW}🔄 Iniciando...${NC}"
            cd "$INSTALL_DIR"
            pm2 start bot.js --name sshbot-pro 2>/dev/null || pm2 restart sshbot-pro
            echo -e "${GREEN}✅ Listo${NC}"
            sleep 2
            ;;
        2)
            echo -e "\n${YELLOW}🛑 Deteniendo...${NC}"
            pm2 stop sshbot-pro
            echo -e "${GREEN}✅ Detenido${NC}"
            sleep 2
            ;;
        3)
            echo -e "\n${YELLOW}📱 Mostrando logs...${NC}"
            pm2 logs sshbot-pro --lines 100
            ;;
        4)
            echo -e "\n${CYAN}👤 CREAR USUARIO${NC}"
            read -p "Teléfono: " PHONE
            read -p "Tipo (test/premium): " TIPO
            read -p "Días (0=test): " DAYS
            
            if [[ "$TIPO" == "test" ]]; then
                USERNAME="test$(shuf -i 1000-9999 -n 1)"
                DAYS=0
                EXPIRE=$(date -d "+1 hour" +"%Y-%m-%d %H:%M:%S")
            else
                USERNAME="user$(shuf -i 1000-9999 -n 1)"
                EXPIRE=$(date -d "+$DAYS days" +"%Y-%m-%d 23:59:59")
            fi
            
            PASSWORD="mgvpn247"
            
            # Crear en sistema
            useradd -M -s /bin/false "$USERNAME" && echo "$USERNAME:$PASSWORD" | chpasswd
            if [[ "$TIPO" == "premium" ]]; then
                usermod -e "$(date -d "+$DAYS days" +%Y-%m-%d)" "$USERNAME"
            fi
            
            # Guardar en BD
            sqlite3 "$DB" "INSERT INTO users (phone, username, password, tipo, expires_at) VALUES ('$PHONE', '$USERNAME', '$PASSWORD', '$TIPO', '$EXPIRE')"
            
            echo -e "\n${GREEN}✅ CREADO${NC}"
            echo -e "👤 $USERNAME"
            echo -e "🔑 $PASSWORD"
            echo -e "⏰ $EXPIRE"
            read -p "Enter..."
            ;;
        5)
            echo -e "\n${CYAN}👥 USUARIOS${NC}"
            sqlite3 -column -header "$DB" "SELECT username, tipo, expires_at FROM users WHERE status=1 ORDER BY expires_at"
            echo -e "\n${YELLOW}Total: $ACTIVE_USERS activos${NC}"
            read -p "Enter..."
            ;;
        6)
            echo -e "\n${CYAN}🔑 CONFIGURAR MERCADOPAGO${NC}"
            echo -e "Obtén tu token en:"
            echo -e "https://www.mercadopago.com.ar/developers"
            echo -e "Ve a: Tus credenciales → Access Token PRODUCCIÓN"
            echo -e ""
            
            CURRENT=$(get_val '.mercadopago.access_token')
            if [[ -n "$CURRENT" ]]; then
                echo -e "Token actual: ${CURRENT:0:20}..."
            fi
            
            read -p "Nuevo token: " TOKEN
            if [[ -n "$TOKEN" ]]; then
                set_val '.mercadopago.access_token' "\"$TOKEN\""
                set_val '.mercadopago.enabled' "true"
                echo -e "${GREEN}✅ Token guardado${NC}"
                
                # Test conexión
                echo -e "${YELLOW}🔄 Probando conexión...${NC}"
                RESP=$(curl -s -H "Authorization: Bearer $TOKEN" "https://api.mercadopago.com/v1/payment_methods")
                if echo "$RESP" | grep -q "id"; then
                    echo -e "${GREEN}✅ Conexión exitosa${NC}"
                else
                    echo -e "${RED}❌ Error en token${NC}"
                fi
            fi
            read -p "Enter..."
            ;;
        7)
            echo -e "\n${CYAN}💰 CAMBIAR PRECIOS${NC}"
            
            CURRENT_7D=$(get_val '.prices.price_7d')
            CURRENT_15D=$(get_val '.prices.price_15d')
            CURRENT_30D=$(get_val '.prices.price_30d')
            CURRENT_50D=$(get_val '.prices.price_50d')
            
            echo -e "Actual: 7d=\$$CURRENT_7D 15d=\$$CURRENT_15D 30d=\$$CURRENT_30D 50d=\$$CURRENT_50D"
            
            read -p "Nuevo 7d: " NEW_7D
            read -p "Nuevo 15d: " NEW_15D
            read -p "Nuevo 30d: " NEW_30D
            read -p "Nuevo 50d: " NEW_50D
            
            [[ -n "$NEW_7D" ]] && set_val '.prices.price_7d' "$NEW_7D"
            [[ -n "$NEW_15D" ]] && set_val '.prices.price_15d' "$NEW_15D"
            [[ -n "$NEW_30D" ]] && set_val '.prices.price_30d' "$NEW_30D"
            [[ -n "$NEW_50D" ]] && set_val '.prices.price_50d' "$NEW_50D"
            
            echo -e "${GREEN}✅ Precios actualizados${NC}"
            read -p "Enter..."
            ;;
        8)
            echo -e "\n${CYAN}💳 PAGOS${NC}"
            echo -e "${YELLOW}Pendientes:${NC}"
            sqlite3 -column -header "$DB" "SELECT payment_id, plan, amount, created_at FROM payments WHERE status='pending' ORDER BY created_at"
            echo -e "\n${YELLOW}Aprobados:${NC}"
            sqlite3 -column -header "$DB" "SELECT payment_id, plan, amount, approved_at FROM payments WHERE status='approved' ORDER BY approved_at"
            read -p "Enter..."
            ;;
        9)
            echo -e "\n${YELLOW}🧹 Limpiando...${NC}"
            pm2 stop sshbot-pro
            rm -rf /root/.wppconnect/*
            echo -e "${GREEN}✅ Sesión limpiada${NC}"
            echo -e "${YELLOW}📱 Escanea nuevo QR${NC}"
            sleep 2
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
echo -e "${GREEN}✅ Panel creado${NC}"

# ================================================
# INICIAR BOT
# ================================================
echo -e "\n${CYAN}🚀 Iniciando bot...${NC}"

cd "$INSTALL_DIR"
pm2 start bot.js --name sshbot-pro
pm2 save
pm2 startup systemd -u root --hp /root > /dev/null 2>&1

sleep 2

# ================================================
# MENSAJE FINAL
# ================================================
clear
echo -e "${GREEN}${BOLD}"
cat << "FINAL"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║         ✅ SSH BOT PRO - INSTALACIÓN COMPLETADA            ║
║                🚀 LISTO PARA USAR                          ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Estados persistentes${NC} - No vuelve al menú"
echo -e "${GREEN}✅ MercadoPago integrado${NC} - Links reales de pago"
echo -e "${GREEN}✅ QR de pago${NC} - Generado automáticamente"
echo -e "${GREEN}✅ Panel completo${NC} - sshbot para gestionar"
echo -e "${GREEN}✅ Base de datos SQLite${NC} - Datos persistentes"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 PRIMEROS PASOS:${NC}"
echo -e "1. Ver QR: ${GREEN}pm2 logs sshbot-pro${NC}"
echo -e "2. Escanear con WhatsApp"
echo -e "3. Enviar 'menu' al bot"
echo -e "4. Probar opción 1 (prueba gratis)"
echo -e "5. Configurar MP: ${GREEN}sshbot → Opción 6${NC}"
echo -e "\n"

echo -e "${YELLOW}🔑 CONFIGURAR MERCADOPAGO:${NC}"
echo -e "• Ve a: https://www.mercadopago.com.ar/developers"
echo -e "• Inicia sesión"
echo -e "• 'Tus credenciales' → 'Access Token PRODUCCIÓN'"
echo -e "• Copia el token (empieza con APP_USR-...)"
echo -e "• Ejecuta: ${GREEN}sshbot${NC} → Opción 6"
echo -e "• Pega el token y prueba conexión"
echo -e "\n"

echo -e "${YELLOW}⚡ COMANDOS RÁPIDOS:${NC}"
echo -e "  ${GREEN}sshbot${NC}          - Panel de control"
echo -e "  ${GREEN}pm2 logs sshbot-pro${NC} - Ver logs/QR"
echo -e "  ${GREEN}pm2 restart sshbot-pro${NC} - Reiniciar bot"
echo -e "\n"

echo -e "${GREEN}${BOLD}¡El bot está funcionando! Escanea el QR y prueba 🚀${NC}\n"

read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}📱 Espera el QR...${NC}\n"
    pm2 logs sshbot-pro
fi

exit 0