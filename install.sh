#!/bin/bash
# ================================================
# SSH BOT PRO - WPPCONNECT + MERCADOPAGO + HWID
# INTEGRADO CON CHUMOGH - CREA USUARIOS EN /etc/passwd
# VERSION CORREGIDA - ENVÍA APP Y VIDEO POR WHATSAPP
# ================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}"
cat << "BANNER"
╔══════════════════════════════════════════════════════════════╗
║         🤖 SSH BOT PRO - MGVPN + MERCADOPAGO              ║
║         🔐 Crea usuarios HWID en /etc/passwd                ║
║         📲 ENVÍA APP Y VIDEO POR WHATSAPP                  ║
║         ⏱️  PRUEBA 2 HORAS - PAGO AUTOMATICO                ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Ejecuta como root${NC}"
    exit 1
fi

echo -e "${CYAN}🔍 Detectando IP...${NC}"
SERVER_IP=$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
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

apt-get remove -y libnode-dev libnode-devel nodejs-doc 2>/dev/null || true
apt-get autoremove -y

curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs gcc g++ make

wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get update -y
apt-get install -y google-chrome-stable

apt-get install -y git curl wget sqlite3 jq build-essential \
    libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev \
    librsvg2-dev python3 python3-pip ffmpeg unzip cron ufw

ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8001/tcp
ufw allow 3000/tcp
ufw --force enable

npm install -g pm2
pm2 update

if ! getent group cloudvpn > /dev/null 2>&1; then
    groupadd cloudvpn
    echo -e "${GREEN}✅ Grupo cloudvpn creado${NC}"
else
    echo -e "${GREEN}✅ Grupo cloudvpn existe${NC}"
fi

echo -e "${GREEN}✅ Dependencias instaladas${NC}"

# ================================================
# PREPARAR ESTRUCTURA
# ================================================
echo -e "\n${CYAN}📁 Creando estructura...${NC}"

INSTALL_DIR="/opt/sshbot-pro"
USER_HOME="/root/sshbot-pro"
DB_FILE="$INSTALL_DIR/data/hwid.db"
CONFIG_FILE="$INSTALL_DIR/config/config.json"
APK_PATH="/opt/sshbot-pro/apps/MGVPN.apk"
VIDEO_PATH="/opt/sshbot-pro/apps/tutorial.mp4"

pm2 delete sshbot-pro 2>/dev/null || true
rm -rf "$INSTALL_DIR" "$USER_HOME" 2>/dev/null || true
rm -rf /root/.wppconnect 2>/dev/null || true

mkdir -p "$INSTALL_DIR"/{data,config,sessions,logs,qr_codes,apps}
mkdir -p "$USER_HOME"
mkdir -p /root/.wppconnect
chmod -R 755 "$INSTALL_DIR"

cat > "$CONFIG_FILE" << CONFIGEOF
{
    "bot": {
        "name": "SSH Bot Pro HWID",
        "version": "5.0-CHUMOGH",
        "server_ip": "$SERVER_IP"
    },
    "prices": {
        "test_hours": 2,
        "price_7d": 3500.00,
        "price_15d": 4500.00,
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
        "app_download": "https://play.google.com/store/apps/details?id=google.android.b6",
        "support": "https://wa.me/54"
    },
    "paths": {
        "database": "$DB_FILE",
        "qr_codes": "$INSTALL_DIR/qr_codes",
        "sessions": "/root/.wppconnect",
        "apk_file": "$APK_PATH",
        "video_file": "$VIDEO_PATH"
    }
}
CONFIGEOF

sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE hwid_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    nombre TEXT,
    hwid TEXT UNIQUE,
    tipo TEXT DEFAULT 'test',
    expires_at TEXT,
    status INTEGER DEFAULT 1,
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
CREATE TABLE user_state (
    phone TEXT PRIMARY KEY,
    state TEXT DEFAULT 'main_menu',
    data TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_hwid_users_hwid ON hwid_users(hwid);
CREATE INDEX idx_payments_status ON payments(status);
SQL

echo -e "${GREEN}✅ Estructura creada${NC}"

# ================================================
# CREAR BOT
# ================================================
echo -e "\n${CYAN}🤖 Creando bot...${NC}"

cd "$USER_HOME"

cat > package.json << 'PKGEOF'
{
    "name": "sshbot-pro-chumogh",
    "version": "5.0.0",
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

npm install --silent 2>&1 | grep -v "npm WARN" || true

cat > "bot.js" << 'BOTEOF'
const wppconnect = require('@wppconnect-team/wppconnect');
const QRCode = require('qrcode');
const moment = require('moment');
const sqlite3 = require('sqlite3').verbose();
const chalk = require('chalk');
const cron = require('node-cron');
const fs = require('fs');
const axios = require('axios');
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);

moment.locale('es');

console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════╗'));
console.log(chalk.cyan.bold('║   🤖 SSH BOT PRO - CHUMOGH                          ║'));
console.log(chalk.cyan.bold('║   🔐 Crea usuarios HWID en /etc/passwd              ║'));
console.log(chalk.cyan.bold('║   📱 ENVÍA APP Y VIDEO POR WHATSAPP                 ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════╝\n'));

function loadConfig() {
    delete require.cache[require.resolve('/opt/sshbot-pro/config/config.json')];
    return require('/opt/sshbot-pro/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/sshbot-pro/data/hwid.db');

// ================================================
// MERCADOPAGO SDK V2
// ================================================
let mpEnabled = false;
let mpPreference = null;

function initMercadoPago() {
    config = loadConfig();
    if (config.mercadopago.access_token && config.mercadopago.access_token !== '') {
        try {
            const { MercadoPagoConfig, Preference } = require('mercadopago');
            const mpClient = new MercadoPagoConfig({
                accessToken: config.mercadopago.access_token,
                options: { timeout: 5000 }
            });
            mpPreference = new Preference(mpClient);
            mpEnabled = true;
            console.log(chalk.green('✅ MercadoPago SDK v2 ACTIVO'));
        } catch (e) {
            console.log(chalk.red('❌ Error MP:'), e.message);
        }
    } else {
        console.log(chalk.yellow('⚠️  MercadoPago NO configurado'));
    }
}

initMercadoPago();

let client = null;

// ================================================
// ENVIAR APK POR WHATSAPP
// ================================================
async function sendAPK(phone) {
    const apkPath = '/opt/sshbot-pro/apps/MGVPN.apk';

    if (!fs.existsSync(apkPath)) {
        await client.sendText(phone,
            `❌ *APP NO DISPONIBLE*\n\n📱 La aplicación no está disponible actualmente.\n👨‍💻 Contacta al administrador.\n\n🔗 Link alternativo:\n${config.links.app_download}`
        );
        return false;
    }

    try {
        await client.sendFile(
            phone,
            apkPath,
            'MGVPN.apk',
            `📲 *APP MGVPN*\n\n✅ *APK LISTA PARA INSTALAR*\n\n⚠️ *IMPORTANTE:*\nSi te sale el cartel de advertencia, dale en:\n\n🔹 *MÁS DETALLES*\n🔹 *INSTALAR DE TODAS FORMAS*\n\n📦 *Tamaño:* ${(fs.statSync(apkPath).size / 1024 / 1024).toFixed(2)} MB\n\n🔧 *Pasos:*\n1️⃣ Instala la APK\n2️⃣ Abre la app\n3️⃣ Selecciona Personal 1\n4️⃣ ¡Conéctate!\n\n🌐 *Soporte:* ${config.links.support}`
        );
        console.log(chalk.green(`✅ APK enviado a ${phone}`));
        return true;
    } catch (error) {
        console.error(chalk.red(`❌ Error enviando APK: ${error.message}`));
        await client.sendText(phone,
            `❌ *Error al enviar la app*\n\n🔗 Descarga directa:\n${config.links.app_download}\n\n👨‍💻 Contacta soporte: ${config.links.support}`
        );
        return false;
    }
}

// ================================================
// ENVIAR VIDEO TUTORIAL POR WHATSAPP
// ================================================
async function sendTutorialVideo(phone) {
    const videoPath = '/opt/sshbot-pro/apps/tutorial.mp4';

    if (!fs.existsSync(videoPath)) {
        await client.sendText(phone,
            `❌ *TUTORIAL NO DISPONIBLE*\n\n📹 El video tutorial no está cargado aún.\n👨‍💻 Contacta al administrador:\n${config.links.support}`
        );
        return false;
    }

    try {
        await client.sendFile(
            phone,
            videoPath,
            'tutorial.mp4',
            `🎥 *VIDEO TUTORIAL MGVPN*\n\n📋 *Pasos:*\n1️⃣ Instala la APK (opción 4️⃣)\n2️⃣ Abre la app\n3️⃣ Selecciona Personal 1\n4️⃣ ¡Conéctate y listo!\n\n❓ Dudas: ${config.links.support}`
        );
        console.log(chalk.green(`✅ Video tutorial enviado a ${phone}`));
        return true;
    } catch (error) {
        console.error(chalk.red(`❌ Error enviando video: ${error.message}`));
        await client.sendText(phone,
            `❌ *Error al enviar el tutorial*\n\n👨‍💻 Contacta soporte: ${config.links.support}`
        );
        return false;
    }
}

// ================================================
// FUNCIONES HWID
// ================================================
function normalizeHWID(hwid) {
    hwid = hwid.trim().toUpperCase();
    if (hwid.startsWith('APP-')) {
        return 'APP-' + hwid.substring(4).replace(/[^A-F0-9]/g, '');
    }
    return hwid.replace(/[^A-F0-9]/g, '');
}

function validateHWID(hwid) {
    return /^APP-[A-F0-9]{16}$/.test(hwid) || /^[A-F0-9]{32}$/.test(hwid);
}

function hwidExistsInSystem(hwid) {
    try {
        const passwd = fs.readFileSync('/etc/passwd', 'utf8');
        return passwd.includes(hwid + ':');
    } catch (e) {
        return false;
    }
}

async function createSystemUser(hwid, nombre, expireDate) {
    try {
        const cmd = `useradd -e ${expireDate} -g cloudvpn -c "HWID,${nombre}" -s /bin/false -M ${hwid}`;
        await execPromise(cmd);
        await execPromise(`echo "${hwid}:${hwid}" | chpasswd`);
        const days = moment(expireDate).diff(moment(), 'days') + 1;
        await execPromise(`chage -M ${days} -E ${expireDate} ${hwid}`);
        console.log(chalk.green(`✅ Usuario creado: ${hwid} - expira: ${expireDate}`));
        return true;
    } catch (e) {
        console.error(chalk.red('❌ Error creando usuario:'), e.message);
        return false;
    }
}

async function deleteSystemUser(hwid) {
    try {
        await execPromise(`userdel -r ${hwid} 2>/dev/null || userdel ${hwid}`);
        console.log(chalk.yellow(`🗑️  Usuario eliminado: ${hwid}`));
    } catch (e) {
        console.error(chalk.red('❌ Error eliminando usuario:'), e.message);
    }
}

async function registerHWID(phone, nombre, rawHwid, days, tipo = 'premium') {
    try {
        const hwid = normalizeHWID(rawHwid);

        if (hwidExistsInSystem(hwid)) {
            return { success: false, error: 'HWID ya registrado en el sistema' };
        }

        let expireDate;
        let expireFull;

        if (days === 0) {
            expireDate = moment().add(1, 'days').format('YYYY-MM-DD');
            expireFull = moment().add(2, 'hours').format('YYYY-MM-DD HH:mm:ss');
        } else {
            expireDate = moment().add(days, 'days').format('YYYY-MM-DD');
            expireFull = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
        }

        const created = await createSystemUser(hwid, nombre, expireDate);
        if (!created) {
            return { success: false, error: 'Error al crear usuario en el sistema' };
        }

        await new Promise((resolve, reject) => {
            db.run(
                `INSERT INTO hwid_users (phone, nombre, hwid, tipo, expires_at, status) VALUES (?, ?, ?, ?, ?, 1)`,
                [phone, nombre, hwid, tipo, expireFull],
                function(err) { if (err) reject(err); else resolve(); }
            );
        });

        return { success: true, hwid, nombre, expires: expireFull, expireDate, tipo };

    } catch (error) {
        console.error(chalk.red('❌ Error registerHWID:'), error.message);
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

function isHWIDActive(hwid) {
    return new Promise((resolve) => {
        db.get('SELECT * FROM hwid_users WHERE hwid = ? AND status = 1 AND expires_at > datetime("now")',
            [hwid], (err, row) => resolve(!err && row));
    });
}

function getHWIDInfo(hwid) {
    return new Promise((resolve) => {
        db.get('SELECT * FROM hwid_users WHERE hwid = ?', [hwid], (err, row) => {
            resolve(err || !row ? null : row);
        });
    });
}

// ================================================
// ESTADOS
// ================================================
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
        db.run(
            `INSERT OR REPLACE INTO user_state (phone, state, data, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)`,
            [phone, state, dataStr], (err) => { if (err) console.error(err); resolve(); }
        );
    });
}

// ================================================
// MERCADOPAGO
// ================================================
async function createMercadoPagoPayment(phone, days, amount, planName) {
    try {
        if (!mpEnabled || !mpPreference) return { success: false, error: 'MercadoPago no configurado' };

        const phoneClean = phone.replace('@c.us', '');
        const paymentId = `HWID-${phoneClean}-${days}d-${Date.now()}`;

        const response = await mpPreference.create({
            body: {
                items: [{
                    title: `HWID SSH PREMIUM ${days} DÍAS`,
                    quantity: 1,
                    currency_id: config.prices.currency || 'ARS',
                    unit_price: parseFloat(amount)
                }],
                external_reference: paymentId,
                expires: true,
                expiration_date_from: moment().toISOString(),
                expiration_date_to: moment().add(24, 'hours').toISOString(),
                back_urls: {
                    success: `https://wa.me/${phoneClean}?text=Ya+pague`,
                    failure: `https://wa.me/${phoneClean}?text=Pago+fallido`,
                    pending: `https://wa.me/${phoneClean}?text=Pago+pendiente`
                },
                auto_return: 'approved'
            }
        });

        if (response && response.id) {
            const qrPath = `${config.paths.qr_codes}/${paymentId}.png`;
            await QRCode.toFile(qrPath, response.init_point, { width: 400 });

            db.run(
                `INSERT INTO payments (payment_id, phone, plan, days, amount, status, payment_url, qr_code, preference_id) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
                [paymentId, phone, `${days}d`, days, amount, response.init_point, qrPath, response.id]
            );

            return { success: true, paymentId, paymentUrl: response.init_point, qrPath, amount: parseFloat(amount) };
        }

        throw new Error('Respuesta inválida de MercadoPago');

    } catch (error) {
        console.error(chalk.red('❌ Error MP:'), error.message);
        return { success: false, error: error.message };
    }
}

async function checkPendingPayments() {
    if (!mpEnabled) return;

    db.all('SELECT * FROM payments WHERE status = "pending" AND created_at > datetime("now", "-48 hours")',
        async (err, payments) => {
            if (err || !payments || payments.length === 0) return;

            for (const payment of payments) {
                try {
                    const response = await axios.get(
                        `https://api.mercadopago.com/v1/payments/search?external_reference=${payment.payment_id}`,
                        { headers: { 'Authorization': `Bearer ${config.mercadopago.access_token}` }, timeout: 15000 }
                    );

                    if (response.data?.results?.length > 0) {
                        const mpPayment = response.data.results[0];
                        if (mpPayment.status === 'approved') {
                            console.log(chalk.green(`✅ PAGO APROBADO: ${payment.payment_id}`));
                            db.run(`UPDATE payments SET status = 'approved', approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?`, [payment.payment_id]);

                            if (client) {
                                await client.sendText(payment.phone,
                                    `✅ PAGO CONFIRMADO\n\n🎉 Tu pago fue aprobado\n\n📝 Primero escribe tu NOMBRE:`
                                );
                                await setUserState(payment.phone, 'awaiting_hwid', {
                                    payment_id: payment.payment_id,
                                    days: payment.days,
                                    plan: payment.plan
                                });
                            }
                        }
                    }
                } catch (e) {
                    console.error(chalk.red(`❌ Error verificando pago:`), e.message);
                }
            }
        });
}

// ================================================
// NOTIFICACIONES DE VENCIMIENTO
// ================================================
async function checkExpiringHWIDs() {
    try {
        const expiringSoon = await new Promise((resolve, reject) => {
            db.all(`SELECT * FROM hwid_users WHERE status = 1 AND tipo = 'premium'
                AND expires_at > datetime('now') AND expires_at < datetime('now', '+1 day')`,
                (err, rows) => { if (err) reject(err); else resolve(rows || []); });
        });

        for (const h of expiringSoon) {
            const hoursLeft = moment(h.expires_at).diff(moment(), 'hours');
            if (client) {
                await client.sendText(h.phone,
                    `⏰ RECORDATORIO\n\nHola ${h.nombre}, tu acceso expira en ${hoursLeft} horas.\n\n🔐 HWID: ${h.hwid}\n\nEnvía 2 para renovar.`
                );
            }
        }
    } catch (e) {
        console.error(chalk.red('❌ Error notificaciones:'), e.message);
    }
}

// ================================================
// LIMPIAR EXPIRADOS
// ================================================
async function cleanExpiredHWIDs() {
    try {
        const expired = await new Promise((resolve, reject) => {
            db.all(`SELECT hwid FROM hwid_users WHERE status = 1 AND expires_at < datetime('now')`,
                (err, rows) => { if (err) reject(err); else resolve(rows || []); });
        });

        for (const h of expired) {
            await deleteSystemUser(h.hwid);
        }

        db.run(`UPDATE hwid_users SET status = 0 WHERE expires_at < datetime('now') AND status = 1`);

        if (expired.length > 0) {
            console.log(chalk.yellow(`🧹 ${expired.length} HWIDs expirados eliminados`));
        }
    } catch (e) {
        console.error(chalk.red('❌ Error limpiando expirados:'), e.message);
    }
}

// ================================================
// INICIALIZAR BOT
// ================================================
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
            browserArgs: [
                '--no-sandbox', '--disable-setuid-sandbox',
                '--disable-dev-shm-usage', '--disable-gpu',
                '--no-first-run', '--no-zygote'
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

        client.onMessage(async (message) => {
            try {
                const text = message.body.toLowerCase().trim();
                const from = message.from;
                const userState = await getUserState(from);

                // MENÚ PRINCIPAL
                if (['menu', 'hola', 'start', 'hi', 'volver', '0'].includes(text)) {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from,
                        `🚀 *MGVPN-BOT*\n\n` +
                        `┌─────────────────────────┐\n` +
                        `│ 1️⃣ • PROBAR INTERNET    │\n` +
                        `│ 2️⃣ • COMPRAR INTERNET   │\n` +
                        `│ 3️⃣ • VERIFICAR HWID     │\n` +
                        `│ 4️⃣ • 📱 DESCARGAR APP    │\n` +
                        `│ 5️⃣ • 🎥 VIDEO TUTORIAL   │\n` +
                        `└─────────────────────────┘\n\n` +
                        `⚡ *2 horas de prueba gratis*\n` +
                        `💳 *Aceptamos MercadoPago*`
                    );
                }

                // OPCIÓN 1: PRUEBA
                else if (text === '1' && userState.state === 'main_menu') {
                    await setUserState(from, 'awaiting_test_nombre');
                    await client.sendText(from, `⏳️ PRUEBA GRATUITA - 2 HORAS\n\nPrimero, dime tu nombre:`);
                }

                // OPCIÓN 2: COMPRAR
                else if (text === '2' && userState.state === 'main_menu') {
                    await setUserState(from, 'buying_hwid');
                    await client.sendText(from,
                        `💰 PLANES DE INTERNET\n\n 1️⃣ - 7 DÍAS - $${config.prices.price_7d}\n 2️⃣ - 15 DÍAS - $${config.prices.price_15d}\n 3️⃣ - 30 DÍAS - $${config.prices.price_30d}\n 4️⃣ - 50 DÍAS - $${config.prices.price_50d}\n\n 0️⃣ - VOLVER`
                    );
                }

                // OPCIÓN 3: VERIFICAR
                else if (text === '3' && userState.state === 'main_menu') {
                    await setUserState(from, 'awaiting_check_hwid');
                    await client.sendText(from, `🔍 VERIFICAR HWID\n\nEnvía tu HWID:\n\nEjemplo: APP-E3E4D5CBB7636907\n`);
                }

                // OPCIÓN 4: DESCARGAR APP
                else if (text === '4' && userState.state === 'main_menu') {
                    await client.sendText(from, '⏳ *Preparando envío de la app...*\n\n📱 Un momento por favor');
                    await sendAPK(from);
                }

                // OPCIÓN 5: VIDEO TUTORIAL
                else if (text === '5' && userState.state === 'main_menu') {
                    await client.sendText(from, '⏳ *Preparando video tutorial...*\n\n🎥 Un momento por favor');
                    await sendTutorialVideo(from);
                }

                // NOMBRE PARA PRUEBA
                else if (userState.state === 'awaiting_test_nombre') {
                    const nombre = message.body.trim();
                    if (nombre.length < 2) {
                        await client.sendText(from, '❌ El nombre debe tener al menos 2 caracteres:');
                        return;
                    }
                    await setUserState(from, 'awaiting_test_hwid', { nombre });
                    await client.sendText(from,
                        `✅ Gracias ${nombre}\n\nAhora envía tu HWID:\n\nEjemplo:\nAPP-E3E4D5CBB7636907\n\n\n⏳ Una prueba por día`
                    );
                }

                // HWID PARA PRUEBA
                else if (userState.state === 'awaiting_test_hwid') {
                    const rawHwid = message.body.trim();
                    const nombre = userState.data.nombre;

                    if (!validateHWID(rawHwid)) {
                        await client.sendText(from, `❌ HWID inválido\n\nFormato:\nAPP-XXXXXXXXXXXXXXXX (16 hex)\no 32 caracteres hex\n\nIntenta de nuevo:`);
                        return;
                    }

                    const hwid = normalizeHWID(rawHwid);

                    if (!(await canCreateTest(from))) {
                        await client.sendText(from, `❌ Ya usaste tu prueba hoy\n\nVuelve mañana o compra un plan`);
                        await setUserState(from, 'main_menu');
                        return;
                    }

                    if (hwidExistsInSystem(hwid) || await isHWIDActive(hwid)) {
                        await client.sendText(from, `❌ Este HWID ya está activo en el sistema`);
                        await setUserState(from, 'main_menu');
                        return;
                    }

                    await client.sendText(from, '⏳ Activando prueba...');
                    const result = await registerHWID(from, nombre, rawHwid, 0, 'test');

                    if (result.success) {
                        registerTest(from, nombre);
                        const expireTime = moment(result.expires).format('HH:mm DD/MM/YYYY');
                        await client.sendText(from,
                            `✅ PRUEBA ACTIVADA ${nombre}\n\n🔐 HWID: ${result.hwid}\n⏰ Expira: ${expireTime}\n⚡ Tipo: PRUEBA (2 horas)\n\n📱 Abre la app y conéctate`
                        );
                        console.log(chalk.green(`✅ Test activado: ${result.hwid} - ${nombre}`));
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    await setUserState(from, 'main_menu');
                }

                // PLAN DE COMPRA
                else if (userState.state === 'buying_hwid' && ['1','2','3','4'].includes(text)) {
                    const plans = {
                        '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                        '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' },
                        '3': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                        '4': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                    };
                    const plan = plans[text];

                    if (mpEnabled) {
                        await client.sendText(from, '⏳ Generando pago...');
                        const payment = await createMercadoPagoPayment(from, plan.days, plan.price, plan.name);

                        if (payment.success) {
                            await client.sendText(from,
                                `💰 PAGO PARA HWID\n\n🌐 Plan: ${plan.name}\n💰 Precio: $${payment.amount}\n\nLINK DE PAGO:\n${payment.paymentUrl}\n\n⏰ Válido 24 horas\n\n📌 Después de pagar:\n1. Espera la confirmación\n2. Te pediremos tu nombre\n3. Luego tu HWID\n4. Se activa automático`
                            );
                            if (fs.existsSync(payment.qrPath)) {
                                await client.sendImage(from, payment.qrPath, 'qr-pago.jpg',
                                    `Escanea con MercadoPago\n${plan.name} - $${payment.amount}`
                                ).catch(e => console.error('⚠️ Error QR:', e.message));
                            }
                        } else {
                            await client.sendText(from, `❌ Error al generar pago\n\nContacta al administrador:\n${config.links.support}`);
                        }
                    } else {
                        await client.sendText(from,
                            `📋 PLAN: ${plan.name}\nPrecio: $${plan.price} ARS\n\nContacta al administrador:\n${config.links.support}`
                        );
                    }
                    await setUserState(from, 'main_menu');
                }

                else if (text === '0' && userState.state === 'buying_hwid') {
                    await setUserState(from, 'main_menu');
                    await client.sendText(from,
                        `🚀 *MGVPN-BOT*\n\n` +
                        `┌─────────────────────────┐\n` +
                        `│ 1️⃣ • PROBAR INTERNET    │\n` +
                        `│ 2️⃣ • COMPRAR INTERNET   │\n` +
                        `│ 3️⃣ • VERIFICAR HWID     │\n` +
                        `│ 4️⃣ • 📱 DESCARGAR APP    │\n` +
                        `│ 5️⃣ • 🎥 VIDEO TUTORIAL   │\n` +
                        `└─────────────────────────┘`
                    );
                }

                // VERIFICAR HWID
                else if (userState.state === 'awaiting_check_hwid') {
                    const rawHwid = message.body.trim();

                    if (!validateHWID(rawHwid)) {
                        await client.sendText(from, `❌ Formato inválido\n\nEjemplo: APP-E3E4D5CBB7636907 o 32 hex`);
                        return;
                    }

                    const hwid = normalizeHWID(rawHwid);
                    const info = await getHWIDInfo(hwid);
                    const enSistema = hwidExistsInSystem(hwid);

                    if (info && info.status === 1 && enSistema) {
                        const expires = moment(info.expires_at).format('DD/MM/YYYY HH:mm');
                        const remaining = moment(info.expires_at).fromNow();
                        await client.sendText(from,
                            `✅ HWID ACTIVO\n\n👤 ${info.nombre}\n🔐 ${hwid}\n📅 ${info.tipo === 'test' ? 'PRUEBA' : 'PREMIUM'}\n⏰ Hasta: ${expires}\n⌛ ${remaining}`
                        );
                    } else {
                        await client.sendText(from,
                            `❌ HWID NO ACTIVO\n\nEnvía 1 para prueba gratis o 2 para comprar`
                        );
                    }
                    await setUserState(from, 'main_menu');
                }

                // POST-PAGO: NOMBRE -> HWID
                else if (userState.state === 'awaiting_hwid') {
                    if (!userState.data.nombre) {
                        const nombre = message.body.trim();
                        if (nombre.length < 2) {
                            await client.sendText(from, '❌ Nombre debe tener al menos 2 caracteres:');
                            return;
                        }
                        userState.data.nombre = nombre;
                        await setUserState(from, 'awaiting_hwid', userState.data);
                        await client.sendText(from,
                            `✅ Gracias ${nombre}\n\nAhora envía tu HWID:\nEjemplo: APP-E3E4D5CBB7636907`
                        );
                        return;
                    }

                    const rawHwid = message.body.trim();
                    const nombre = userState.data.nombre;

                    if (!validateHWID(rawHwid)) {
                        await client.sendText(from, `❌ Formato incorrecto\n\nEjemplo: APP-E3E4D5CBB7636907 o 32 hex`);
                        return;
                    }

                    const hwid = normalizeHWID(rawHwid);

                    if (hwidExistsInSystem(hwid) || await isHWIDActive(hwid)) {
                        await client.sendText(from, `❌ Este HWID ya está activo\n\nContacta soporte.`);
                        return;
                    }

                    await client.sendText(from, '⏳ Activando tu HWID...');
                    const result = await registerHWID(from, nombre, rawHwid, userState.data.days, 'premium');

                    if (result.success) {
                        db.run(`UPDATE payments SET hwid = ?, nombre = ? WHERE payment_id = ?`,
                            [result.hwid, nombre, userState.data.payment_id]);
                        const expireDate = moment(result.expires).format('DD/MM/YYYY');
                        await client.sendText(from,
                            `✅ ACTIVADO ${nombre}\n\n🔐 HWID: ${result.hwid}\n⏰ Válido hasta: ${expireDate}\n\n¡Ya puedes usar la app!`
                        );
                        console.log(chalk.green(`✅ Premium activado: ${result.hwid} - ${nombre}`));
                    } else {
                        await client.sendText(from, `❌ Error: ${result.error}`);
                    }
                    await setUserState(from, 'main_menu');
                }

            } catch (error) {
                console.error(chalk.red('❌ Error mensaje:'), error.message);
            }
        });

        // Crons
        cron.schedule('*/2 * * * *', () => checkPendingPayments());
        cron.schedule('0 * * * *', () => checkExpiringHWIDs());
        cron.schedule('*/15 * * * *', () => cleanExpiredHWIDs());
        cron.schedule('0 * * * *', () => {
            db.run(`DELETE FROM user_state WHERE updated_at < datetime('now', '-1 hour')`);
        });

        console.log(chalk.green('✅ Bot listo y escuchando mensajes'));

    } catch (error) {
        console.error(chalk.red('❌ Error iniciando:'), error.message);
        console.log(chalk.yellow('🔄 Reintentando en 10s...'));
        setTimeout(initializeBot, 10000);
    }
}

initializeBot();

process.on('SIGINT', async () => {
    if (client) await client.close();
    process.exit();
});
BOTEOF

echo -e "${GREEN}✅ Bot creado${NC}"

# ================================================
# PANEL DE CONTROL
# ================================================
echo -e "\n${CYAN}🎛️  Creando panel de control...${NC}"

cat > /usr/local/bin/sshbot-hwid << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'

DB="/opt/sshbot-pro/data/hwid.db"
CONFIG="/opt/sshbot-pro/config/config.json"
APPS_DIR="/opt/sshbot-pro/apps"
APK_PATH="$APPS_DIR/MGVPN.apk"
VIDEO_PATH="$APPS_DIR/tutorial.mp4"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }
set_val() { local t=$(mktemp); jq "$1 = $2" "$CONFIG" > "$t" && mv "$t" "$CONFIG"; }

normalize_hwid() {
    local h=$(echo "$1" | tr 'a-z' 'A-Z')
    echo "$h"
}

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║      🎛️  PANEL SSH BOT PRO - MGVPN                          ║${NC}"
    echo -e "${CYAN}║      🔐 Usuarios HWID en /etc/passwd                        ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

upload_apk() {
    clear
    echo -e "${CYAN}📤 SUBIR APK PARA ENVIAR POR WHATSAPP${NC}\n"

    mkdir -p "$APPS_DIR"

    if [[ -f "$APK_PATH" ]]; then
        echo -e "${GREEN}✅ App actual: $(du -h "$APK_PATH" | cut -f1)${NC}\n"
    else
        echo -e "${YELLOW}⚠️ No hay APK cargada actualmente${NC}\n"
    fi

    echo -e "  ${CYAN}[1]${NC} Descargar por URL"
    echo -e "  ${CYAN}[2]${NC} Subir por SCP (manual)"
    echo -e "  ${CYAN}[0]${NC} Cancelar"
    read -p "👉 Selecciona: " METODO

    case $METODO in
        1)
            read -p "URL del archivo APK: " APK_URL
            echo -e "\n${YELLOW}⬇️ Descargando...${NC}"
            wget --show-progress -O "$APK_PATH" "$APK_URL"
            if [ $? -eq 0 ]; then
                chmod 644 "$APK_PATH"
                echo -e "${GREEN}✅ APK descargada: $(du -h "$APK_PATH" | cut -f1)${NC}"
                echo -e "${GREEN}✅ Los usuarios pueden escribir 4 en el menú para recibirla${NC}"
            else
                echo -e "${RED}❌ Error en la descarga${NC}"
            fi
            ;;
        2)
            echo -e "\n${YELLOW}Comando SCP desde tu PC:${NC}"
            echo -e "  ${CYAN}scp tu_app.apk root@$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'):$APK_PATH${NC}"
            read -p "Presiona ENTER después de subir el archivo..."
            if [ -f "$APK_PATH" ]; then
                chmod 644 "$APK_PATH"
                echo -e "${GREEN}✅ APK encontrada: $(du -h "$APK_PATH" | cut -f1)${NC}"
                echo -e "${GREEN}✅ Los usuarios pueden escribir 4 en el menú para recibirla${NC}"
            else
                echo -e "${RED}❌ No se encontró el archivo en $APK_PATH${NC}"
            fi
            ;;
    esac

    echo ""
    read -p "Enter para continuar..."
}

upload_video() {
    clear
    echo -e "${CYAN}🎥 SUBIR VIDEO TUTORIAL POR URL${NC}\n"

    mkdir -p "$APPS_DIR"

    if [[ -f "$VIDEO_PATH" ]]; then
        echo -e "${GREEN}✅ Video actual: $(du -h "$VIDEO_PATH" | cut -f1)${NC}\n"
    else
        echo -e "${YELLOW}⚠️ No hay video cargado actualmente${NC}\n"
    fi

    read -p "URL del video (.mp4): " VIDEO_URL

    if [[ -z "$VIDEO_URL" ]]; then
        echo -e "${RED}❌ URL vacía, cancelado${NC}"
        read -p "Enter para continuar..."
        return
    fi

    echo -e "\n${YELLOW}⬇️ Descargando video...${NC}"
    wget --show-progress -O "$VIDEO_PATH" "$VIDEO_URL"

    if [ $? -eq 0 ]; then
        chmod 644 "$VIDEO_PATH"
        echo -e "\n${GREEN}✅ Video descargado correctamente${NC}"
        echo -e "   🎥 Archivo: tutorial.mp4"
        echo -e "   💾 Tamaño: $(du -h "$VIDEO_PATH" | cut -f1)"
        echo -e "\n${GREEN}✅ Los usuarios pueden escribir 5 en el menú para recibirlo${NC}"
    else
        rm -f "$VIDEO_PATH" 2>/dev/null
        echo -e "${RED}❌ Error en la descarga. Verifica la URL e intenta de nuevo${NC}"
    fi

    echo ""
    read -p "Enter para continuar..."
}

habilitar_prueba_extra() {
    clear
    echo -e "${CYAN}🔄 HABILITAR PRUEBA EXTRA A CLIENTE${NC}\n"
    echo -e "  ${CYAN}[1]${NC} Por número de teléfono"
    echo -e "  ${CYAN}[2]${NC} Ver clientes que usaron prueba hoy"
    echo -e "  ${CYAN}[0]${NC} Cancelar"
    read -p "👉 Selecciona: " TOPT

    case $TOPT in
        1)
            read -p "Teléfono del cliente (ej: 5491122334455): " TPHONE
            if [[ -z "$TPHONE" ]]; then
                echo -e "${RED}❌ Teléfono vacío${NC}"
            else
                TODAY=$(date +"%Y-%m-%d")
                DELETED=$(sqlite3 "$DB" "DELETE FROM daily_tests WHERE phone LIKE '%$TPHONE%' AND date = '$TODAY'; SELECT changes();")
                if [[ "$DELETED" -gt 0 ]]; then
                    echo -e "${GREEN}✅ Prueba extra habilitada para $TPHONE${NC}"
                    echo -e "${YELLOW}ℹ️  El cliente puede volver a escribir 1 en el menú${NC}"
                else
                    echo -e "${YELLOW}⚠️ Ese número no tenía prueba registrada hoy${NC}"
                    echo -e "${GREEN}✅ De todas formas ya puede hacer una prueba${NC}"
                fi
            fi
            ;;
        2)
            echo -e "\n${YELLOW}Clientes que usaron prueba hoy:${NC}\n"
            sqlite3 -column -header "$DB" \
                "SELECT phone, nombre, date FROM daily_tests WHERE date = date('now') ORDER BY created_at DESC"
            ;;
        0)
            return
            ;;
    esac

    echo ""
    read -p "Enter para continuar..."
}

while true; do
    show_header

    TOTAL=$(sqlite3 "$DB" "SELECT COUNT(*) FROM hwid_users" 2>/dev/null || echo "0")
    ACTIVOS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM hwid_users WHERE status=1" 2>/dev/null || echo "0")
    TESTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM daily_tests WHERE date = date('now')" 2>/dev/null || echo "0")
    STATUS=$(pm2 jlist 2>/dev/null | jq -r '.[] | select(.name=="sshbot-pro") | .pm2_env.status' 2>/dev/null || echo "stopped")
    [[ "$STATUS" == "online" ]] && BOT_STATUS="${GREEN}● ACTIVO${NC}" || BOT_STATUS="${RED}● DETENIDO${NC}"
    MP_TOKEN=$(get_val '.mercadopago.access_token')
    [[ -n "$MP_TOKEN" && "$MP_TOKEN" != "null" && "$MP_TOKEN" != "" ]] && MP_STATUS="${GREEN}✅ CONFIG${NC}" || MP_STATUS="${RED}❌ NO CONFIG${NC}"

    APK_INFO="${RED}❌ NO CARGADA${NC}"
    [ -f "$APK_PATH" ] && APK_INFO="${GREEN}✅ $(du -h "$APK_PATH" | cut -f1)${NC}"

    VIDEO_INFO="${RED}❌ NO CARGADO${NC}"
    [ -f "$VIDEO_PATH" ] && VIDEO_INFO="${GREEN}✅ $(du -h "$VIDEO_PATH" | cut -f1)${NC}"

    echo -e "${YELLOW}📊 ESTADO:${NC}"
    echo -e "  Bot:             $BOT_STATUS"
    echo -e "  HWIDs activos:   ${CYAN}$ACTIVOS/$TOTAL${NC}"
    echo -e "  Tests hoy:       ${CYAN}$TESTS${NC}"
    echo -e "  MercadoPago:     $MP_STATUS"
    echo -e "  APK (opción 4):  $APK_INFO"
    echo -e "  Video (opción 5): $VIDEO_INFO"
    echo -e ""
    echo -e "${YELLOW}💰 PRECIOS:${NC}"
    echo -e "  7d: \$$(get_val '.prices.price_7d') | 15d: \$$(get_val '.prices.price_15d') | 30d: \$$(get_val '.prices.price_30d') | 50d: \$$(get_val '.prices.price_50d')"
    echo -e ""
    echo -e "${CYAN}[1]${NC}  🚀 Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC}  🛑 Detener bot"
    echo -e "${CYAN}[3]${NC}  📱 Ver logs y QR"
    echo -e "${CYAN}[4]${NC}  🔐 Registrar HWID manual"
    echo -e "${CYAN}[5]${NC}  👥 Listar HWIDs activos"
    echo -e "${CYAN}[6]${NC}  💰 Cambiar precios"
    echo -e "${CYAN}[7]${NC}  🔑 Configurar MercadoPago"
    echo -e "${CYAN}[8]${NC}  📊 Estadísticas"
    echo -e "${CYAN}[9]${NC}  🔄 Limpiar sesión WhatsApp"
    echo -e "${CYAN}[10]${NC} 🗑️  Eliminar HWID"
    echo -e "${CYAN}[11]${NC} 📱 Subir/Actualizar APK"
    echo -e "${CYAN}[12]${NC} 🎥 Subir/Actualizar Video Tutorial (URL)"
    echo -e "${CYAN}[13]${NC} 🔓 Habilitar prueba extra a cliente"
    echo -e "${CYAN}[0]${NC}  🚪 Salir"
    echo -e ""
    read -p "👉 Selecciona: " OPT

    case $OPT in
        1)
            cd /root/sshbot-pro
            pm2 restart sshbot-pro 2>/dev/null || pm2 start bot.js --name sshbot-pro
            pm2 save
            echo -e "${GREEN}✅ Bot reiniciado${NC}"
            sleep 2
            ;;
        2)
            pm2 stop sshbot-pro
            echo -e "${GREEN}✅ Bot detenido${NC}"
            sleep 2
            ;;
        3)
            pm2 logs sshbot-pro --lines 100
            ;;
        4)
            clear
            echo -e "${CYAN}🔐 REGISTRAR HWID MANUAL${NC}\n"
            read -p "Teléfono (ej: 5491122334455): " PHONE
            read -p "Nombre: " NOMBRE
            read -p "HWID (APP-XXXX o hex): " RAWHWID
            read -p "Días (0=prueba 2h, 7/15/30/50): " DAYS

            HWID=$(normalize_hwid "$RAWHWID")

            if [[ "$DAYS" == "0" ]]; then
                EXPIRE_DATE=$(date -d "+1 day" +"%Y-%m-%d")
                EXPIRE_FULL=$(date -d "+2 hours" +"%Y-%m-%d %H:%M:%S")
                TIPO="test"
            else
                EXPIRE_DATE=$(date -d "+$DAYS days" +"%Y-%m-%d")
                EXPIRE_FULL=$(date -d "+$DAYS days" +"%Y-%m-%d 23:59:59")
                TIPO="premium"
            fi

            useradd -e "$EXPIRE_DATE" -g cloudvpn -c "HWID,$NOMBRE" -s /bin/false -M "$HWID" 2>/dev/null
            echo "${HWID}:${HWID}" | chpasswd 2>/dev/null
            chage -E "$EXPIRE_DATE" "$HWID" 2>/dev/null

            sqlite3 "$DB" "INSERT OR IGNORE INTO hwid_users (phone, nombre, hwid, tipo, expires_at, status) VALUES ('$PHONE', '$NOMBRE', '$HWID', '$TIPO', '$EXPIRE_FULL', 1)"

            echo -e "\n${GREEN}✅ HWID REGISTRADO${NC}"
            echo -e "  Usuario Linux: ${HWID}"
            echo -e "  Nombre: ${NOMBRE}"
            echo -e "  Expira: ${EXPIRE_DATE}"
            read -p "Enter..."
            ;;
        5)
            clear
            echo -e "${CYAN}👥 HWIDs ACTIVOS${NC}\n"
            sqlite3 -column -header "$DB" "SELECT nombre, hwid, tipo, expires_at FROM hwid_users WHERE status=1 ORDER BY expires_at DESC LIMIT 20"
            read -p "\nEnter..."
            ;;
        6)
            clear
            read -p "Precio 7d [$(get_val '.prices.price_7d')]: " P7
            read -p "Precio 15d [$(get_val '.prices.price_15d')]: " P15
            read -p "Precio 30d [$(get_val '.prices.price_30d')]: " P30
            read -p "Precio 50d [$(get_val '.prices.price_50d')]: " P50
            [[ -n "$P7" ]] && set_val '.prices.price_7d' "$P7"
            [[ -n "$P15" ]] && set_val '.prices.price_15d' "$P15"
            [[ -n "$P30" ]] && set_val '.prices.price_30d' "$P30"
            [[ -n "$P50" ]] && set_val '.prices.price_50d' "$P50"
            echo -e "${GREEN}✅ Precios actualizados${NC}"
            sleep 2
            ;;
        7)
            clear
            echo -e "${CYAN}🔑 CONFIGURAR MERCADOPAGO${NC}\n"
            echo -e "1. https://www.mercadopago.com.ar/developers"
            echo -e "2. Tus credenciales → Access Token PRODUCCIÓN\n"
            read -p "¿Configurar token? (s/N): " C
            if [[ "$C" == "s" ]]; then
                read -p "Access Token: " TOKEN
                if [[ "$TOKEN" =~ ^APP_USR- ]] || [[ "$TOKEN" =~ ^TEST- ]]; then
                    set_val '.mercadopago.access_token' "\"$TOKEN\""
                    set_val '.mercadopago.enabled' "true"
                    cd /root/sshbot-pro && pm2 restart sshbot-pro
                    echo -e "${GREEN}✅ MercadoPago configurado${NC}"
                else
                    echo -e "${RED}❌ Token inválido${NC}"
                fi
            fi
            read -p "Enter..."
            ;;
        8)
            clear
            echo -e "${CYAN}📊 ESTADÍSTICAS${NC}\n"
            echo -e "${YELLOW}HWIDs:${NC}"
            sqlite3 "$DB" "SELECT 'Total: '||COUNT(*)||' | Activos: '||SUM(CASE WHEN status=1 THEN 1 ELSE 0 END)||' | Tests hoy: '||(SELECT COUNT(*) FROM daily_tests WHERE date=date('now')) FROM hwid_users"
            echo -e "\n${YELLOW}Pagos:${NC}"
            sqlite3 "$DB" "SELECT 'Pendientes: '||SUM(CASE WHEN status='pending' THEN 1 ELSE 0 END)||' | Aprobados: '||SUM(CASE WHEN status='approved' THEN 1 ELSE 0 END)||' | Total $'||printf('%.2f',SUM(CASE WHEN status='approved' THEN amount ELSE 0 END)) FROM payments"
            read -p "\nEnter..."
            ;;
        9)
            pm2 stop sshbot-pro
            rm -rf /root/.wppconnect/*
            echo -e "${GREEN}✅ Sesión limpiada${NC}"
            sleep 2
            ;;
        10)
            clear
            echo -e "${CYAN}🗑️  ELIMINAR HWID${NC}\n"
            read -p "HWID a eliminar: " RAWHWID
            HWID=$(normalize_hwid "$RAWHWID")
            userdel -r "$HWID" 2>/dev/null || userdel "$HWID" 2>/dev/null
            sqlite3 "$DB" "UPDATE hwid_users SET status=0 WHERE hwid='$HWID'"
            echo -e "${GREEN}✅ HWID eliminado${NC}"
            read -p "Enter..."
            ;;
        11)
            upload_apk
            ;;
        12)
            upload_video
            ;;
        13)
            habilitar_prueba_extra
            ;;
        0)
            echo -e "${GREEN}👋 Hasta pronto${NC}"
            exit 0
            ;;
    esac
done
PANELEOF

chmod +x /usr/local/bin/sshbot-hwid
ln -sf /usr/local/bin/sshbot-hwid /usr/local/bin/sshbot

# ================================================
# COMANDO RÁPIDO SUBIR APK
# ================================================
cat > /usr/local/bin/subir-apk << 'SUBIRAPK'
#!/bin/bash
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
APPS_DIR="/opt/sshbot-pro/apps"
APK_PATH="$APPS_DIR/MGVPN.apk"
mkdir -p "$APPS_DIR"

echo -e "${CYAN}╔════════════════════════════════╗${NC}"
echo -e "${CYAN}║   📤 SUBIR APK POR WHATSAPP    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════╝${NC}\n"

if [ $# -gt 0 ]; then
    if [[ "$1" =~ ^https?:// ]]; then
        echo -e "${YELLOW}⬇️ Descargando...${NC}"
        wget -O "$APK_PATH" "$1" && chmod 644 "$APK_PATH" && echo -e "${GREEN}✅ APK descargada${NC}" || echo -e "${RED}❌ Error${NC}"
    elif [ -f "$1" ]; then
        cp "$1" "$APK_PATH" && chmod 644 "$APK_PATH"
        echo -e "${GREEN}✅ APK copiada${NC}"
    else
        echo -e "${RED}❌ Archivo no encontrado: $1${NC}"
    fi
    [ -f "$APK_PATH" ] && ls -lh "$APK_PATH"
    echo -e "\n${GREEN}✅ Los usuarios escriben ${CYAN}4${GREEN} para recibir la app${NC}"
    exit 0
fi

echo -e "  ${CYAN}[1]${NC} Por URL"
echo -e "  ${CYAN}[2]${NC} Por SCP (manual)"
read -p "Opción: " opt
case $opt in
    1)
        read -p "URL: " url
        wget -O "$APK_PATH" "$url" && chmod 644 "$APK_PATH"
        ls -lh "$APK_PATH"
        ;;
    2)
        echo -e "\n${YELLOW}Comando SCP:${NC}"
        echo "scp tu_app.apk root@$(curl -4 -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'):$APK_PATH"
        read -p "Presiona ENTER después de subir..."
        [ -f "$APK_PATH" ] && chmod 644 "$APK_PATH" && ls -lh "$APK_PATH" || echo -e "${RED}❌ No se encontró APK${NC}"
        ;;
esac
echo -e "\n${GREEN}✅ Los usuarios escriben ${CYAN}4${GREEN} para recibir la app${NC}"
SUBIRAPK

chmod +x /usr/local/bin/subir-apk

# ================================================
# INICIAR BOT
# ================================================
echo -e "\n${CYAN}🚀 Iniciando bot...${NC}"
cd "$USER_HOME"
pm2 start bot.js --name sshbot-pro
pm2 save
pm2 startup systemd -u root --hp /root > /dev/null 2>&1

clear
echo -e "${GREEN}"
cat << "FINAL"
╔══════════════════════════════════════════════════════════════╗
║         🎉 INSTALACIÓN COMPLETADA                           ║
║                                                              ║
║  ✅ Bot integrado con ChumoGH                               ║
║  ✅ Crea usuarios en /etc/passwd con useradd                ║
║  ✅ Opción 4: ENVÍA APK POR WHATSAPP                        ║
║  ✅ Opción 5: ENVÍA VIDEO TUTORIAL POR WHATSAPP             ║
║  ✅ Prueba extra desde el panel (opción 13)                  ║
║  ✅ Expiración automática con chage                         ║
║  ✅ Limpieza automática de expirados                        ║
║  ✅ MercadoPago integrado                                   ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${YELLOW}📋 COMANDOS:${NC}"
echo -e "  ${GREEN}sshbot${NC}               - Panel de control"
echo -e "  ${GREEN}subir-apk${NC}            - Subir APK (archivo o URL)"
echo -e "  ${GREEN}pm2 logs sshbot-pro${NC}  - Ver logs y QR"
echo -e "  ${GREEN}pm2 restart sshbot-pro${NC} - Reiniciar bot"
echo -e ""
echo -e "${YELLOW}📱 MENÚ DEL BOT (usuarios):${NC}"
echo -e "  1️⃣  PROBAR INTERNET"
echo -e "  2️⃣  COMPRAR INTERNET"
echo -e "  3️⃣  VERIFICAR HWID"
echo -e "  4️⃣  📱 DESCARGAR APP (envía el APK)"
echo -e "  5️⃣  🎥 VIDEO TUTORIAL (envía el video)"
echo -e ""
echo -e "${YELLOW}🎛️  PANEL (admin):${NC}"
echo -e "  Opción 11 → Subir APK"
echo -e "  Opción 12 → Subir Video por URL"
echo -e "  Opción 13 → Habilitar prueba extra a cliente"

read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
[[ $REPLY =~ ^[Ss]$ ]] && pm2 logs sshbot-pro

exit 0
