#!/bin/bash
# ================================================
# SSH BOT PRO - VERSIÓN REVENDEDORES
# CON PANEL DE CONTROL PARA REVENDEDORES
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
║     ███████╗███████╗██║  ██║    ██████╗  ██████╗ ████████╗  ║
║     ██╔════╝██╔════╝██║  ██║    ██╔══██╗██╔═══██╗╚══██╔══╝  ║
║     ███████╗███████╗███████║    ██████╔╝██║   ██║   ██║     ║
║     ╚════██║╚════██║██╔══██║    ██╔══██╗██║   ██║   ██║     ║
║     ███████║███████║██║  ██║    ██████╔╝╚██████╔╝   ██║     ║
║     ╚══════╝╚══════╝╚═╝  ╚═╝    ╚═════╝  ╚═════╝    ╚═╝     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║          🤖 SSH BOT PRO - VERSIÓN REVENDEDORES              ║
║               📱 WhatsApp API FUNCIONANDO                   ║
║               💰 MercadoPago SDK v2.x INTEGRADO            ║
║               👥 SISTEMA DE REVENDEDORES                    ║
║               🔐 ACCESO CON CONTRASEÑA                      ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Debes ejecutar como root${NC}"
    exit 1
fi

# Detectar IP
SERVER_IP=$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
if [[ -z "$SERVER_IP" ]]; then
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
    unzip cron ufw openssl

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
DB_FILE="$INSTALL_DIR/data/users.db"
CONFIG_FILE="$INSTALL_DIR/config/config.json"

# Limpiar anterior
pm2 delete sshbot-pro 2>/dev/null || true
rm -rf "$INSTALL_DIR" "$USER_HOME" 2>/dev/null || true
rm -rf /root/.wppconnect 2>/dev/null || true

# Crear directorios
mkdir -p "$INSTALL_DIR"/{data,config,sessions,logs,qr_codes}
mkdir -p "$USER_HOME"
mkdir -p /root/.wppconnect
chmod -R 755 "$INSTALL_DIR"
chmod -R 700 /root/.wppconnect

# Configuración inicial
cat > "$CONFIG_FILE" << EOF
{
    "bot": {
        "name": "SSH Bot Pro - Revendedores",
        "version": "3.0-REVENDEDORES",
        "server_ip": "$SERVER_IP",
        "default_password": "mgvpn247"
    },
    "prices": {
        "test_hours": 2,
        "price_7d": 3000.00,
        "price_15d": 4000.00,
        "price_30d": 7000.00,
        "price_50d": 10000.00,
        "currency": "ARS"
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false
    },
    "reminders": {
        "enabled": true,
        "times": [24, 12, 6, 1]
    },
    "admin": {
        "username": "admin",
        "password": "",
        "created_at": ""
    },
    "links": {
        "app_download": "https://www.mediafire.com/file/tvt0vpmyfg3xqhj/mgvpn.apk/file",
        "support": "https://wa.me/543435071016"
    },
    "paths": {
        "database": "$DB_FILE",
        "qr_codes": "$INSTALL_DIR/qr_codes",
        "sessions": "/root/.wppconnect"
    }
}
EOF

# Crear base de datos COMPLETA con tabla de revendedores
sqlite3 "$DB_FILE" << 'SQL'
-- Tabla de usuarios SSH
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    username TEXT UNIQUE,
    password TEXT DEFAULT 'mgvpn247',
    tipo TEXT DEFAULT 'test',
    expires_at DATETIME,
    status INTEGER DEFAULT 1,
    created_by TEXT, -- teléfono o username del revendedor
    last_reminder_hours INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de tests diarios
CREATE TABLE daily_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(phone, date)
);

-- Tabla de pagos
CREATE TABLE payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_id TEXT UNIQUE,
    phone TEXT,
    plan TEXT,
    days INTEGER,
    amount REAL,
    status TEXT DEFAULT 'pending',
    payment_url TEXT,
    qr_code TEXT,
    preference_id TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    approved_at DATETIME
);

-- Tabla de logs
CREATE TABLE logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT,
    message TEXT,
    data TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de estados de usuario en WhatsApp
CREATE TABLE user_state (
    phone TEXT PRIMARY KEY,
    state TEXT DEFAULT 'main_menu',
    data TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ✅ NUEVA TABLA: REVENDEDORES
CREATE TABLE resellers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    phone TEXT,
    name TEXT,
    email TEXT,
    credit_limit INTEGER DEFAULT 0, -- Crédito en pesos o cantidad de usuarios
    total_sales INTEGER DEFAULT 0,
    commission_percent INTEGER DEFAULT 10, -- Comisión %
    status INTEGER DEFAULT 1,
    last_login DATETIME,
    created_by TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ✅ NUEVA TABLA: LOGS DE REVENDEDORES
CREATE TABLE reseller_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    reseller_username TEXT,
    action TEXT,
    details TEXT,
    ip_address TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ✅ NUEVA TABLA: COMISIONES
CREATE TABLE commissions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    reseller_username TEXT,
    payment_id TEXT,
    amount REAL,
    commission_amount REAL,
    status TEXT DEFAULT 'pending',
    paid_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Índices
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_created_by ON users(created_by);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_resellers_username ON resellers(username);
SQL

echo -e "${GREEN}✅ Estructura creada con tabla de revendedores${NC}"

# ================================================
# CREAR ADMIN POR DEFECTO
# ================================================
echo -e "\n${CYAN}🔐 Creando usuario administrador...${NC}"

ADMIN_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-16)
HASHED_PASS=$(echo -n "$ADMIN_PASS" | sha256sum | awk '{print $1}')

sqlite3 "$DB_FILE" "INSERT INTO resellers (username, password, name, credit_limit, commission_percent, status) 
                    VALUES ('admin', '$HASHED_PASS', 'Administrador Principal', 999999, 0, 1)"

# Guardar en config
jq ".admin.password = \"$ADMIN_PASS\" | .admin.created_at = \"$(date)\"" "$CONFIG_FILE" > tmp.json && mv tmp.json "$CONFIG_FILE"

echo -e "${GREEN}✅ Administrador creado${NC}"

# ================================================
# CREAR BOT CON SOPORTE PARA REVENDEDORES
# ================================================
echo -e "\n${CYAN}🤖 Creando bot con soporte para revendedores...${NC}"

cd "$USER_HOME"

# package.json
cat > package.json << 'PKGEOF'
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
        "mercadopago": "^2.0.15",
        "axios": "^1.6.5",
        "sharp": "^0.33.2",
        "express": "^4.18.2",
        "jsonwebtoken": "^9.0.2",
        "cors": "^2.8.5",
        "bcryptjs": "^2.4.3"
    }
}
PKGEOF

echo -e "${YELLOW}📦 Instalando dependencias...${NC}"
npm install --silent 2>&1 | grep -v "npm WARN" || true

# Crear bot.js MODIFICADO para revendedores
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
const crypto = require('crypto');

const execPromise = util.promisify(exec);
moment.locale('es');

console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════════════════╗'));
console.log(chalk.cyan.bold('║      🤖 SSH BOT PRO - VERSIÓN REVENDEDORES v3.0           ║'));
console.log(chalk.cyan.bold('║                    👥 CON PANEL DE REVENDEDORES             ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════════════════╝\n'));

// Cargar configuración
function loadConfig() {
    delete require.cache[require.resolve('/opt/sshbot-pro/config/config.json')];
    return require('/opt/sshbot-pro/config/config.json');
}

let config = loadConfig();
const db = new sqlite3.Database('/opt/sshbot-pro/data/users.db');

// ✅ FUNCIÓN PARA HASH DE CONTRASEÑAS
function hashPassword(password) {
    return crypto.createHash('sha256').update(password).digest('hex');
}

// ✅ VERIFICAR REVENDEDOR
function verifyReseller(username, password) {
    return new Promise((resolve) => {
        const hashed = hashPassword(password);
        db.get('SELECT * FROM resellers WHERE username = ? AND password = ? AND status = 1', 
            [username, hashed], (err, row) => {
            if (err || !row) {
                resolve(null);
            } else {
                // Actualizar último login
                db.run('UPDATE resellers SET last_login = CURRENT_TIMESTAMP WHERE username = ?', [username]);
                resolve(row);
            }
        });
    });
}

// ✅ LOG DE ACCIONES DE REVENDEDOR
function logResellerAction(username, action, details, ip = 'local') {
    db.run('INSERT INTO reseller_logs (reseller_username, action, details, ip_address) VALUES (?, ?, ?, ?)',
        [username, action, details, ip]);
}

// ✅ CREAR USUARIO SSH (con registro de quién lo creó)
async function createSSHUser(phone, username, days, tipo = 'premium', createdBy = 'system') {
    const password = config.bot.default_password;
    
    if (tipo === 'test' || days === 0) {
        const expireFull = moment().add(config.prices.test_hours, 'hours').format('YYYY-MM-DD HH:mm:ss');
        
        try {
            await execPromise(`useradd -m -s /bin/bash ${username} && echo "${username}:${password}" | chpasswd`);
            
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at, created_by) VALUES (?, ?, ?, 'test', ?, ?)`,
                [phone, username, password, expireFull, createdBy]);
            
            return { success: true, username, password, expires: expireFull };
        } catch (error) {
            return { success: false, error: error.message };
        }
    } else {
        const expireFull = moment().add(days, 'days').format('YYYY-MM-DD 23:59:59');
        
        try {
            await execPromise(`useradd -M -s /bin/false -e ${moment().add(days, 'days').format('YYYY-MM-DD')} ${username} && echo "${username}:${password}" | chpasswd`);
            
            db.run(`INSERT INTO users (phone, username, password, tipo, expires_at, created_by) VALUES (?, ?, ?, 'premium', ?, ?)`,
                [phone, username, password, expireFull, createdBy]);
            
            return { success: true, username, password, expires: expireFull };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }
}

// ✅ MERCADOPAGO - CREAR PAGO (con registro de comisión para revendedor)
async function createMercadoPagoPayment(phone, days, amount, planName, resellerUsername = null) {
    try {
        const { MercadoPagoConfig, Preference } = require('mercadopago');
        
        const mpClient = new MercadoPagoConfig({ 
            accessToken: config.mercadopago.access_token,
            options: { timeout: 5000 }
        });
        
        const mpPreference = new Preference(mpClient);
        const phoneClean = phone.replace('@c.us', '');
        const paymentId = `SSH-${phoneClean}-${days}d-${Date.now()}`;
        
        const preferenceData = {
            items: [{
                title: `SSH PREMIUM ${days} DÍAS`,
                description: `Acceso SSH Premium por ${days} días`,
                quantity: 1,
                currency_id: config.prices.currency || 'ARS',
                unit_price: parseFloat(amount)
            }],
            external_reference: paymentId,
            expires: true,
            expiration_date_to: moment().add(24, 'hours').toISOString(),
            back_urls: {
                success: `https://wa.me/${phoneClean}`,
                failure: `https://wa.me/${phoneClean}`,
                pending: `https://wa.me/${phoneClean}`
            },
            auto_return: 'approved'
        };
        
        const response = await mpPreference.create({ body: preferenceData });
        
        if (response && response.id) {
            const paymentUrl = response.init_point;
            const qrPath = `${config.paths.qr_codes}/${paymentId}.png`;
            
            await QRCode.toFile(qrPath, paymentUrl, { width: 400 });
            
            db.run(
                `INSERT INTO payments (payment_id, phone, plan, days, amount, status, payment_url, qr_code, preference_id) 
                 VALUES (?, ?, ?, ?, ?, 'pending', ?, ?, ?)`,
                [paymentId, phone, `${days}d`, days, amount, paymentUrl, qrPath, response.id]
            );
            
            // Si hay revendedor, registrar comisión pendiente
            if (resellerUsername) {
                db.get('SELECT commission_percent FROM resellers WHERE username = ?', [resellerUsername], (err, reseller) => {
                    if (!err && reseller) {
                        const commissionAmount = (amount * reseller.commission_percent) / 100;
                        db.run(
                            'INSERT INTO commissions (reseller_username, payment_id, amount, commission_amount, status) VALUES (?, ?, ?, ?, ?)',
                            [resellerUsername, paymentId, amount, commissionAmount, 'pending']
                        );
                    }
                });
            }
            
            return { success: true, paymentId, paymentUrl, qrPath };
        }
        
        throw new Error('Respuesta inválida de MercadoPago');
        
    } catch (error) {
        console.error(chalk.red('❌ Error MercadoPago:'), error.message);
        return { success: false, error: error.message };
    }
}

// ================================================
// API WEB PARA PANEL DE REVENDEDORES
// ================================================
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');

const app = express();
const JWT_SECRET = crypto.randomBytes(32).toString('hex');

app.use(cors());
app.use(express.json());

// Middleware de autenticación JWT
function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    
    if (!token) return res.status(401).json({ error: 'No autorizado' });
    
    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) return res.status(403).json({ error: 'Token inválido' });
        req.user = user;
        next();
    });
}

// ✅ LOGIN DE REVENDEDORES
app.post('/api/login', async (req, res) => {
    const { username, password } = req.body;
    
    const hashed = hashPassword(password);
    db.get('SELECT * FROM resellers WHERE username = ? AND password = ? AND status = 1', 
        [username, hashed], (err, row) => {
        if (err || !row) {
            res.status(401).json({ error: 'Credenciales inválidas' });
        } else {
            const token = jwt.sign(
                { username: row.username, isAdmin: row.username === 'admin' }, 
                JWT_SECRET, 
                { expiresIn: '24h' }
            );
            
            db.run('UPDATE resellers SET last_login = CURRENT_TIMESTAMP WHERE username = ?', [username]);
            logResellerAction(username, 'login', 'Inicio de sesión exitoso', req.ip);
            
            res.json({ 
                token, 
                user: { 
                    username: row.username, 
                    name: row.name, 
                    isAdmin: row.username === 'admin',
                    credit_limit: row.credit_limit,
                    commission_percent: row.commission_percent
                } 
            });
        }
    });
});

// ✅ OBTENER ESTADÍSTICAS DEL REVENDEDOR
app.get('/api/stats', authenticateToken, (req, res) => {
    const username = req.user.username;
    
    if (username === 'admin') {
        // Admin: ver todo
        db.get(`
            SELECT 
                (SELECT COUNT(*) FROM users) as total_users,
                (SELECT COUNT(*) FROM users WHERE status=1) as active_users,
                (SELECT COUNT(*) FROM payments WHERE status='approved') as total_sales,
                (SELECT SUM(amount) FROM payments WHERE status='approved') as total_revenue,
                (SELECT COUNT(*) FROM resellers) as total_resellers
        `, (err, stats) => {
            if (err) return res.status(500).json({ error: err.message });
            res.json(stats);
        });
    } else {
        // Revendedor: ver sus estadísticas
        db.get(`
            SELECT 
                (SELECT COUNT(*) FROM users WHERE created_by = ?) as my_users,
                (SELECT COUNT(*) FROM users WHERE created_by = ? AND status=1) as my_active_users,
                (SELECT SUM(commission_amount) FROM commissions WHERE reseller_username = ? AND status='pending') as pending_commissions,
                (SELECT SUM(commission_amount) FROM commissions WHERE reseller_username = ? AND status='paid') as paid_commissions
        `, [username, username, username, username], (err, stats) => {
            if (err) return res.status(500).json({ error: err.message });
            
            db.get('SELECT credit_limit FROM resellers WHERE username = ?', [username], (err2, reseller) => {
                if (err2) return res.status(500).json({ error: err2.message });
                res.json({ ...stats, credit_limit: reseller?.credit_limit || 0 });
            });
        });
    }
});

// ✅ LISTAR USUARIOS (solo los propios si no es admin)
app.get('/api/users', authenticateToken, (req, res) => {
    const username = req.user.username;
    
    let query = 'SELECT * FROM users';
    let params = [];
    
    if (username !== 'admin') {
        query += ' WHERE created_by = ?';
        params.push(username);
    }
    
    query += ' ORDER BY created_at DESC LIMIT 50';
    
    db.all(query, params, (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
    });
});

// ✅ CREAR USUARIO SSH (revendedor crea usuario)
app.post('/api/users/create', authenticateToken, async (req, res) => {
    const { phone, days, tipo = 'premium' } = req.body;
    const username = req.user.username;
    
    if (!phone || !days) {
        return res.status(400).json({ error: 'Teléfono y días requeridos' });
    }
    
    // Verificar límite de crédito para revendedores no-admin
    if (username !== 'admin') {
        db.get('SELECT credit_limit, (SELECT COUNT(*) FROM users WHERE created_by = ? AND status=1) as active_created FROM resellers WHERE username = ?', 
            [username, username], (err, reseller) => {
            if (err || !reseller) return res.status(500).json({ error: 'Error verificando crédito' });
            
            if (reseller.active_created >= reseller.credit_limit) {
                return res.status(400).json({ error: 'Has alcanzado tu límite de usuarios' });
            }
            
            // Proceder a crear usuario
            createUserForReseller(req, res, username, phone, days, tipo);
        });
    } else {
        // Admin: crear sin límite
        createUserForReseller(req, res, username, phone, days, tipo);
    }
});

async function createUserForReseller(req, res, resellerUsername, phone, days, tipo) {
    const userUsername = tipo === 'test' ? 
        `test${Math.floor(1000 + Math.random() * 9000)}` : 
        `user${Math.floor(1000 + Math.random() * 9000)}`;
    
    const result = await createSSHUser(phone, userUsername, days, tipo, resellerUsername);
    
    if (result.success) {
        logResellerAction(resellerUsername, 'create_user', `Usuario ${userUsername} creado (${days} días)`);
        res.json({ success: true, user: result });
    } else {
        res.status(500).json({ error: result.error });
    }
}

// ✅ ADMIN: GESTIÓN DE REVENDEDORES
app.get('/api/resellers', authenticateToken, (req, res) => {
    if (req.user.username !== 'admin') {
        return res.status(403).json({ error: 'Solo administradores' });
    }
    
    db.all('SELECT id, username, phone, name, email, credit_limit, commission_percent, status, last_login, created_at FROM resellers ORDER BY created_at DESC', 
        (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
    });
});

app.post('/api/resellers/create', authenticateToken, (req, res) => {
    if (req.user.username !== 'admin') {
        return res.status(403).json({ error: 'Solo administradores' });
    }
    
    const { username, password, name, phone, email, credit_limit, commission_percent } = req.body;
    
    if (!username || !password) {
        return res.status(400).json({ error: 'Usuario y contraseña requeridos' });
    }
    
    const hashed = hashPassword(password);
    
    db.run(
        'INSERT INTO resellers (username, password, name, phone, email, credit_limit, commission_percent, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [username, hashed, name, phone, email, credit_limit || 0, commission_percent || 10, 'admin'],
        function(err) {
            if (err) {
                if (err.message.includes('UNIQUE')) {
                    res.status(400).json({ error: 'El nombre de usuario ya existe' });
                } else {
                    res.status(500).json({ error: err.message });
                }
            } else {
                logResellerAction('admin', 'create_reseller', `Revendedor ${username} creado`);
                res.json({ success: true, id: this.lastID });
            }
        }
    );
});

app.put('/api/resellers/:username', authenticateToken, (req, res) => {
    if (req.user.username !== 'admin') {
        return res.status(403).json({ error: 'Solo administradores' });
    }
    
    const { username } = req.params;
    const { credit_limit, commission_percent, status, name, phone, email } = req.body;
    
    let updates = [];
    let params = [];
    
    if (credit_limit !== undefined) {
        updates.push('credit_limit = ?');
        params.push(credit_limit);
    }
    if (commission_percent !== undefined) {
        updates.push('commission_percent = ?');
        params.push(commission_percent);
    }
    if (status !== undefined) {
        updates.push('status = ?');
        params.push(status);
    }
    if (name !== undefined) {
        updates.push('name = ?');
        params.push(name);
    }
    if (phone !== undefined) {
        updates.push('phone = ?');
        params.push(phone);
    }
    if (email !== undefined) {
        updates.push('email = ?');
        params.push(email);
    }
    
    if (updates.length === 0) {
        return res.status(400).json({ error: 'No hay datos para actualizar' });
    }
    
    params.push(username);
    
    db.run(`UPDATE resellers SET ${updates.join(', ')} WHERE username = ?`, params, function(err) {
        if (err) return res.status(500).json({ error: err.message });
        logResellerAction('admin', 'update_reseller', `Revendedor ${username} actualizado`);
        res.json({ success: true, changes: this.changes });
    });
});

// ✅ OBTENER COMISIONES DEL REVENDEDOR
app.get('/api/commissions', authenticateToken, (req, res) => {
    const username = req.user.username;
    
    let query = 'SELECT * FROM commissions';
    let params = [];
    
    if (username !== 'admin') {
        query += ' WHERE reseller_username = ?';
        params.push(username);
    }
    
    query += ' ORDER BY created_at DESC LIMIT 100';
    
    db.all(query, params, (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json(rows);
    });
});

// ✅ INICIAR API
const API_PORT = 3000;
app.listen(API_PORT, '0.0.0.0', () => {
    console.log(chalk.green(`✅ API de revendedores en puerto ${API_PORT}`));
});

// ================================================
// INICIALIZAR WPPCONNECT
// ================================================
let client = null;

async function initializeBot() {
    try {
        console.log(chalk.yellow('🚀 Inicializando WPPConnect...'));
        
        client = await wppconnect.create({
            session: 'sshbot-pro-session',
            headless: true,
            useChrome: true,
            debug: false,
            logQR: true,
            browserArgs: [
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-dev-shm-usage',
                '--disable-gpu'
            ],
            puppeteerOptions: {
                executablePath: '/usr/bin/google-chrome',
                headless: 'new',
                args: ['--no-sandbox', '--disable-setuid-sandbox']
            },
            folderNameToken: '/root/.wppconnect'
        });
        
        console.log(chalk.green('✅ WPPConnect conectado!'));
        
        client.onMessage(async (message) => {
            try {
                const text = message.body.toLowerCase().trim();
                const from = message.from;
                
                console.log(chalk.cyan(`📩 [${from}]: ${text.substring(0, 30)}`));
                
                if (text === 'menu' || text === 'hola' || text === 'start') {
                    await client.sendText(from, `🤖 BOT SSH PREMIUM

Elija una opción:

1️⃣ - CREAR PRUEBA (2 HORAS)
2️⃣ - COMPRAR USUARIO SSH
3️⃣ - RENOVAR USUARIO
4️⃣ - DESCARGAR APLICACIÓN

💡 Para soporte: ${config.links.support}`);
                }
                
                else if (text === '1') {
                    // Verificar si ya usó prueba hoy
                    const today = moment().format('YYYY-MM-DD');
                    db.get('SELECT COUNT(*) as count FROM daily_tests WHERE phone = ? AND date = ?', 
                        [from, today], async (err, row) => {
                        if (!err && row && row.count > 0) {
                            await client.sendText(from, '❌ Ya usaste tu prueba hoy.\n⏳ Vuelve mañana.');
                        } else {
                            await client.sendText(from, '⏳ Creando cuenta de prueba...');
                            
                            const username = `test${Math.floor(1000 + Math.random() * 9000)}`;
                            const result = await createSSHUser(from, username, 0, 'test', 'whatsapp');
                            
                            if (result.success) {
                                db.run('INSERT INTO daily_tests (phone, date) VALUES (?, ?)', [from, today]);
                                
                                await client.sendText(from, `✅ PRUEBA CREADA

👤 Usuario: ${username}
🔐 Contraseña: ${config.bot.default_password}
⏰ Expira: ${result.expires}

📱 APP: ${config.links.app_download}`);
                            } else {
                                await client.sendText(from, `❌ Error: ${result.error}`);
                            }
                        }
                    });
                }
                
                else if (text === '2') {
                    await client.sendText(from, `💰 PLANES DISPONIBLES

1️⃣ - 7 DÍAS: $${config.prices.price_7d}
2️⃣ - 15 DÍAS: $${config.prices.price_15d}
3️⃣ - 30 DÍAS: $${config.prices.price_30d}
4️⃣ - 50 DÍAS: $${config.prices.price_50d}

Responde con el número del plan que deseas.`);
                    
                    // Guardar estado
                    db.run('INSERT OR REPLACE INTO user_state (phone, state) VALUES (?, "buying")', [from]);
                }
                
                else if (['1', '2', '3', '4'].includes(text) && message.from.includes('@c.us')) {
                    // Verificar si está en proceso de compra
                    db.get('SELECT state FROM user_state WHERE phone = ?', [from], async (err, row) => {
                        if (row && row.state === 'buying') {
                            const planMap = {
                                '1': { days: 7, price: config.prices.price_7d, name: '7 DÍAS' },
                                '2': { days: 15, price: config.prices.price_15d, name: '15 DÍAS' },
                                '3': { days: 30, price: config.prices.price_30d, name: '30 DÍAS' },
                                '4': { days: 50, price: config.prices.price_50d, name: '50 DÍAS' }
                            };
                            
                            const plan = planMap[text];
                            
                            if (config.mercadopago.enabled && config.mercadopago.access_token) {
                                await client.sendText(from, '⏳ Generando pago...');
                                
                                const payment = await createMercadoPagoPayment(from, plan.days, plan.price, plan.name);
                                
                                if (payment.success) {
                                    await client.sendText(from, `💳 LINK DE PAGO

Plan: ${plan.name}
Monto: $${plan.price}

${payment.paymentUrl}

⏰ Expira en 24 horas`);
                                    
                                    if (fs.existsSync(payment.qrPath)) {
                                        try {
                                            await client.sendImage(from, payment.qrPath, 'qr.jpg', '📱 O escanea el código QR');
                                        } catch (e) {}
                                    }
                                } else {
                                    await client.sendText(from, `❌ Error: ${payment.error}`);
                                }
                            } else {
                                await client.sendText(from, `📞 Contacta al administrador para comprar:
${config.links.support}`);
                            }
                            
                            // Limpiar estado
                            db.run('DELETE FROM user_state WHERE phone = ?', [from]);
                        }
                    });
                }
                
            } catch (error) {
                console.error(chalk.red('❌ Error:'), error.message);
            }
        });
        
        // Tareas programadas
        cron.schedule('*/2 * * * *', () => {
            // Verificar pagos
            console.log(chalk.yellow('🔄 Verificando pagos...'));
        });
        
        cron.schedule('*/15 * * * *', () => {
            // Limpiar usuarios expirados
            console.log(chalk.yellow('🧹 Limpiando usuarios...'));
            db.all('SELECT username FROM users WHERE expires_at < datetime("now") AND status = 1', async (err, rows) => {
                for (const r of rows) {
                    try {
                        await execPromise(`userdel -f ${r.username} 2>/dev/null || true`);
                        db.run('UPDATE users SET status = 0 WHERE username = ?', [r.username]);
                    } catch (e) {}
                }
            });
        });
        
    } catch (error) {
        console.error(chalk.red('❌ Error:'), error.message);
        setTimeout(initializeBot, 10000);
    }
}

initializeBot();
BOTEOF

echo -e "${GREEN}✅ Bot creado con API de revendedores${NC}"

# ================================================
# CREAR PANEL DE CONTROL PRINCIPAL
# ================================================
echo -e "\n${CYAN}🎛️  Creando panel de control...${NC}"

cat > /usr/local/bin/sshbot << 'PANELEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; NC='\033[0m'

DB="/opt/sshbot-pro/data/users.db"
CONFIG="/opt/sshbot-pro/config/config.json"

get_val() { jq -r "$1" "$CONFIG" 2>/dev/null; }
set_val() { local t=$(mktemp); jq "$1 = $2" "$CONFIG" > "$t" && mv "$t" "$CONFIG"; }

show_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         🎛️  PANEL SSH BOT PRO - REVENDEDORES v3.0          ║${NC}"
    echo -e "${CYAN}║              👥 CON GESTIÓN DE REVENDEDORES                 ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

while true; do
    show_header
    
    # Estadísticas
    TOTAL_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    ACTIVE_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE status=1" 2>/dev/null || echo "0")
    TOTAL_RESELLERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM resellers" 2>/dev/null || echo "0")
    PENDING_PAYMENTS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM payments WHERE status='pending'" 2>/dev/null || echo "0")
    
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
    
    ADMIN_PASS=$(get_val '.admin.password')
    
    echo -e "${YELLOW}📊 ESTADO DEL SISTEMA${NC}"
    echo -e "  Bot: $BOT_STATUS"
    echo -e "  Usuarios: ${CYAN}$ACTIVE_USERS/$TOTAL_USERS${NC} activos"
    echo -e "  Revendedores: ${CYAN}$TOTAL_RESELLERS${NC}"
    echo -e "  Pagos pendientes: ${YELLOW}$PENDING_PAYMENTS${NC}"
    echo -e "  MercadoPago: $MP_STATUS"
    echo -e "  IP: $(get_val '.bot.server_ip')"
    echo -e ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC} 🚀  Iniciar/Reiniciar bot"
    echo -e "${CYAN}[2]${NC} 🛑  Detener bot"
    echo -e "${CYAN}[3]${NC} 📱  Ver logs y QR"
    echo -e "${CYAN}[4]${NC} 👤  Crear usuario manual"
    echo -e "${CYAN}[5]${NC} 👥  Listar usuarios"
    echo -e "${CYAN}[6]${NC} 💰  Cambiar precios"
    echo -e "${CYAN}[7]${NC} 🔑  Configurar MercadoPago"
    echo -e "${CYAN}[8]${NC} 👥  GESTIÓN DE REVENDEDORES"
    echo -e "${CYAN}[9]${NC} 📊 Estadísticas de revendedores"
    echo -e "${CYAN}[10]${NC} 🔧 Configurar límites"
    echo -e "${CYAN}[11]${NC} 💳 Ver comisiones"
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
            echo -e "${CYAN}👤 CREAR USUARIO MANUAL${NC}\n"
            
            read -p "Teléfono (ej: 5491122334455@c.us): " PHONE
            read -p "Usuario (dejar vacío para auto-generar): " USERNAME
            read -p "Tipo (test/premium): " TIPO
            read -p "Días (0=test 2h, 7,15,30,50): " DAYS
            read -p "Creado por (admin/username revendedor): " CREATED_BY
            
            [[ -z "$DAYS" ]] && DAYS="30"
            [[ -z "$CREATED_BY" ]] && CREATED_BY="admin"
            
            if [[ -z "$USERNAME" ]]; then
                if [[ "$TIPO" == "test" ]]; then
                    USERNAME="test$(shuf -i 1000-9999 -n 1)"
                else
                    USERNAME="user$(shuf -i 1000-9999 -n 1)"
                fi
            fi
            
            PASSWORD=$(get_val '.bot.default_password')
            
            if [[ "$TIPO" == "test" ]]; then
                DAYS="0"
                EXPIRE_DATE=$(date -d "+$(get_val '.prices.test_hours') hours" +"%Y-%m-%d %H:%M:%S")
                useradd -m -s /bin/bash "$USERNAME" && echo "$USERNAME:$PASSWORD" | chpasswd
            else
                EXPIRE_DATE=$(date -d "+$DAYS days" +"%Y-%m-%d 23:59:59")
                useradd -M -s /bin/false -e "$(date -d "+$DAYS days" +%Y-%m-%d)" "$USERNAME" && echo "$USERNAME:$PASSWORD" | chpasswd
            fi
            
            if [[ $? -eq 0 ]]; then
                sqlite3 "$DB" "INSERT INTO users (phone, username, password, tipo, expires_at, status, created_by) VALUES ('$PHONE', '$USERNAME', '$PASSWORD', '$TIPO', '$EXPIRE_DATE', 1, '$CREATED_BY')"
                echo -e "\n${GREEN}✅ USUARIO CREADO${NC}"
                echo -e "📱 Teléfono: ${PHONE}"
                echo -e "👤 Usuario: ${USERNAME}"
                echo -e "🔑 Contraseña: ${PASSWORD}"
                echo -e "⏰ Expira: ${EXPIRE_DATE}"
            else
                echo -e "\n${RED}❌ Error al crear usuario${NC}"
            fi
            read -p "Presiona Enter..."
            ;;
        5)
            clear
            echo -e "${CYAN}👥 LISTA DE USUARIOS${NC}\n"
            
            echo -e "${YELLOW}Últimos 20 usuarios activos:${NC}"
            sqlite3 -column -header "$DB" "SELECT username, phone, tipo, expires_at, created_by FROM users WHERE status = 1 ORDER BY expires_at ASC LIMIT 20"
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
            CURRENT_TEST=$(get_val '.prices.test_hours')
            
            echo -e "${YELLOW}Precios actuales:${NC}"
            echo -e "  • 7 días: $${CURRENT_7D} ARS"
            echo -e "  • 15 días: $${CURRENT_15D} ARS"
            echo -e "  • 30 días: $${CURRENT_30D} ARS"
            echo -e "  • 50 días: $${CURRENT_50D} ARS"
            echo -e "  • Test: ${CURRENT_TEST} horas\n"
            
            read -p "Nuevo precio 7d [$CURRENT_7D]: " NEW_7D
            read -p "Nuevo precio 15d [$CURRENT_15D]: " NEW_15D
            read -p "Nuevo precio 30d [$CURRENT_30D]: " NEW_30D
            read -p "Nuevo precio 50d [$CURRENT_50D]: " NEW_50D
            read -p "Horas de prueba [$CURRENT_TEST]: " NEW_TEST
            
            [[ -n "$NEW_7D" ]] && set_val '.prices.price_7d' "$NEW_7D"
            [[ -n "$NEW_15D" ]] && set_val '.prices.price_15d' "$NEW_15D"
            [[ -n "$NEW_30D" ]] && set_val '.prices.price_30d' "$NEW_30D"
            [[ -n "$NEW_50D" ]] && set_val '.prices.price_50d' "$NEW_50D"
            [[ -n "$NEW_TEST" ]] && set_val '.prices.test_hours' "$NEW_TEST"
            
            echo -e "\n${GREEN}✅ Precios actualizados${NC}"
            read -p "Presiona Enter..."
            ;;
        7)
            clear
            echo -e "${CYAN}🔑 CONFIGURAR MERCADOPAGO${NC}\n"
            
            CURRENT_TOKEN=$(get_val '.mercadopago.access_token')
            
            if [[ -n "$CURRENT_TOKEN" && "$CURRENT_TOKEN" != "null" ]]; then
                echo -e "${GREEN}✅ Token configurado${NC}"
                echo -e "Preview: ${CURRENT_TOKEN:0:30}...\n"
            fi
            
            read -p "¿Configurar nuevo token? (s/N): " CONF
            if [[ "$CONF" == "s" ]]; then
                echo ""
                read -p "Pega el Access Token: " NEW_TOKEN
                
                if [[ "$NEW_TOKEN" =~ ^APP_USR- ]] || [[ "$NEW_TOKEN" =~ ^TEST- ]]; then
                    set_val '.mercadopago.access_token' "\"$NEW_TOKEN\""
                    set_val '.mercadopago.enabled' "true"
                    echo -e "\n${GREEN}✅ Token configurado${NC}"
                    cd /root/sshbot-pro && pm2 restart sshbot-pro
                else
                    echo -e "${RED}❌ Token inválido${NC}"
                fi
            fi
            read -p "Presiona Enter..."
            ;;
        8)
            # GESTIÓN DE REVENDEDORES
            while true; do
                clear
                echo -e "${CYAN}👥 GESTIÓN DE REVENDEDORES${NC}\n"
                
                echo -e "${YELLOW}Lista de revendedores:${NC}"
                sqlite3 -column -header "$DB" "SELECT username, name, credit_limit, commission_percent, status, last_login FROM resellers ORDER BY created_at DESC"
                
                echo -e "\n${CYAN}Opciones:${NC}"
                echo -e "  ${GREEN}[1]${NC} Crear nuevo revendedor"
                echo -e "  ${GREEN}[2]${NC} Editar revendedor"
                echo -e "  ${GREEN}[3]${NC} Ver detalles"
                echo -e "  ${GREEN}[4]${NC} Ver logs"
                echo -e "  ${GREEN}[0]${NC} Volver"
                
                read -p "Selecciona: " RES_OPT
                
                case $RES_OPT in
                    1)
                        clear
                        echo -e "${CYAN}CREAR NUEVO REVENDEDOR${NC}\n"
                        
                        read -p "Username: " NEW_USER
                        read -p "Contraseña: " NEW_PASS
                        read -p "Nombre completo: " NEW_NAME
                        read -p "Teléfono: " NEW_PHONE
                        read -p "Email: " NEW_EMAIL
                        read -p "Límite de crédito (usuarios): " NEW_LIMIT
                        read -p "Comisión % (ej: 10): " NEW_COMM
                        
                        [[ -z "$NEW_LIMIT" ]] && NEW_LIMIT=0
                        [[ -z "$NEW_COMM" ]] && NEW_COMM=10
                        
                        HASHED=$(echo -n "$NEW_PASS" | sha256sum | awk '{print $1}')
                        
                        sqlite3 "$DB" "INSERT INTO resellers (username, password, name, phone, email, credit_limit, commission_percent, created_by) VALUES ('$NEW_USER', '$HASHED', '$NEW_NAME', '$NEW_PHONE', '$NEW_EMAIL', $NEW_LIMIT, $NEW_COMM, 'admin')" 2>/dev/null
                        
                        if [[ $? -eq 0 ]]; then
                            echo -e "\n${GREEN}✅ Revendedor creado${NC}"
                        else
                            echo -e "\n${RED}❌ Error - ¿username ya existe?${NC}"
                        fi
                        read -p "Presiona Enter..."
                        ;;
                    2)
                        clear
                        read -p "Username del revendedor a editar: " EDIT_USER
                        
                        echo -e "\n${YELLOW}Dejar vacío para no cambiar${NC}\n"
                        read -p "Nuevo límite: " EDIT_LIMIT
                        read -p "Nueva comisión %: " EDIT_COMM
                        read -p "Estado (1=activo, 0=inactivo): " EDIT_STATUS
                        
                        UPDATES=""
                        [[ -n "$EDIT_LIMIT" ]] && UPDATES="credit_limit = $EDIT_LIMIT"
                        [[ -n "$EDIT_COMM" ]] && UPDATES="${UPDATES:+$UPDATES, }commission_percent = $EDIT_COMM"
                        [[ -n "$EDIT_STATUS" ]] && UPDATES="${UPDATES:+$UPDATES, }status = $EDIT_STATUS"
                        
                        if [[ -n "$UPDATES" ]]; then
                            sqlite3 "$DB" "UPDATE resellers SET $UPDATES WHERE username = '$EDIT_USER'"
                            echo -e "${GREEN}✅ Actualizado${NC}"
                        fi
                        read -p "Presiona Enter..."
                        ;;
                    3)
                        clear
                        read -p "Username: " DETAIL_USER
                        
                        echo -e "\n${CYAN}Detalles del revendedor:${NC}"
                        sqlite3 "$DB" "SELECT * FROM resellers WHERE username = '$DETAIL_USER'" | while IFS='|' read id user pass name phone email limit comm status last created_by created_at; do
                            echo -e "Username: $user"
                            echo -e "Nombre: $name"
                            echo -e "Teléfono: $phone"
                            echo -e "Email: $email"
                            echo -e "Límite: $limit usuarios"
                            echo -e "Comisión: $comm%"
                            echo -e "Estado: $([ "$status" == "1" ] && echo "Activo" || echo "Inactivo")"
                            echo -e "Último login: $last"
                            echo -e "Creado por: $created_by"
                            echo -e "Creado: $created_at"
                            
                            # Estadísticas
                            USERS_CREATED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE created_by = '$user'")
                            ACTIVE_CREATED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE created_by = '$user' AND status=1")
                            PENDING_COMM=$(sqlite3 "$DB" "SELECT SUM(commission_amount) FROM commissions WHERE reseller_username = '$user' AND status='pending'")
                            PAID_COMM=$(sqlite3 "$DB" "SELECT SUM(commission_amount) FROM commissions WHERE reseller_username = '$user' AND status='paid'")
                            
                            echo -e "\n${YELLOW}Estadísticas:${NC}"
                            echo -e "Usuarios creados: $USERS_CREATED (activos: $ACTIVE_CREATED)"
                            echo -e "Comisiones pendientes: $$([ -z "$PENDING_COMM" ] && echo "0" || echo "$PENDING_COMM")"
                            echo -e "Comisiones pagadas: $$([ -z "$PAID_COMM" ] && echo "0" || echo "$PAID_COMM")"
                        done
                        read -p "Presiona Enter..."
                        ;;
                    4)
                        clear
                        read -p "Username (vacío=todos): " LOG_USER
                        
                        if [[ -n "$LOG_USER" ]]; then
                            sqlite3 -column -header "$DB" "SELECT created_at, action, details, ip_address FROM reseller_logs WHERE reseller_username = '$LOG_USER' ORDER BY created_at DESC LIMIT 20"
                        else
                            sqlite3 -column -header "$DB" "SELECT reseller_username, created_at, action, details FROM reseller_logs ORDER BY created_at DESC LIMIT 20"
                        fi
                        read -p "Presiona Enter..."
                        ;;
                    0)
                        break
                        ;;
                esac
            done
            ;;
        9)
            clear
            echo -e "${CYAN}📊 ESTADÍSTICAS DE REVENDEDORES${NC}\n"
            
            echo -e "${YELLOW}Ranking de ventas:${NC}"
            sqlite3 -column -header "$DB" "
                SELECT 
                    r.username,
                    r.name,
                    COUNT(u.id) as total_users,
                    SUM(CASE WHEN u.status=1 THEN 1 ELSE 0 END) as active_users,
                    (SELECT SUM(commission_amount) FROM commissions WHERE reseller_username = r.username AND status='paid') as paid_commissions
                FROM resellers r
                LEFT JOIN users u ON u.created_by = r.username
                GROUP BY r.username
                ORDER BY total_users DESC
                LIMIT 10"
            
            echo -e "\n${YELLOW}Resumen general:${NC}"
            sqlite3 "$DB" "
                SELECT 
                    'Total revendedores: ' || COUNT(*) || 
                    ' | Activos: ' || SUM(CASE WHEN status=1 THEN 1 ELSE 0 END) ||
                    ' | Con ventas: ' || COUNT(DISTINCT CASE WHEN (SELECT COUNT(*) FROM users WHERE created_by = resellers.username) > 0 THEN username END)
                FROM resellers"
            
            read -p "\nPresiona Enter..."
            ;;
        10)
            clear
            echo -e "${CYAN}🔧 CONFIGURACIÓN GLOBAL${NC}\n"
            
            echo -e "${YELLOW}Configuración actual:${NC}"
            echo -e "  • Contraseña por defecto: $(get_val '.bot.default_password')"
            echo -e "  • Horas de prueba: $(get_val '.prices.test_hours')"
            echo -e "  • Moneda: $(get_val '.prices.currency')"
            echo -e "  • Recordatorios: $(get_val '.reminders.enabled')"
            echo -e "  • Horarios recordatorios: $(get_val '.reminders.times')"
            
            echo -e "\n${YELLOW}Modificar:${NC}"
            read -p "Nueva contraseña por defecto [mgvpn247]: " NEW_DEF_PASS
            read -p "Activar recordatorios (true/false): " NEW_REM
            read -p "Horarios recordatorios [24,12,6,1]: " NEW_TIMES
            
            [[ -n "$NEW_DEF_PASS" ]] && set_val '.bot.default_password' "\"$NEW_DEF_PASS\""
            [[ -n "$NEW_REM" ]] && set_val '.reminders.enabled' "$NEW_REM"
            [[ -n "$NEW_TIMES" ]] && set_val '.reminders.times' "$NEW_TIMES"
            
            echo -e "\n${GREEN}✅ Configuración actualizada${NC}"
            read -p "Presiona Enter..."
            ;;
        11)
            clear
            echo -e "${CYAN}💳 COMISIONES${NC}\n"
            
            echo -e "${YELLOW}Comisiones pendientes:${NC}"
            sqlite3 -column -header "$DB" "
                SELECT 
                    c.reseller_username,
                    r.name,
                    COUNT(*) as num_payments,
                    SUM(c.commission_amount) as total_pending
                FROM commissions c
                JOIN resellers r ON r.username = c.reseller_username
                WHERE c.status = 'pending'
                GROUP BY c.reseller_username"
            
            echo -e "\n${YELLOW}Últimas comisiones pagadas:${NC}"
            sqlite3 -column -header "$DB" "
                SELECT reseller_username, amount, commission_amount, paid_at
                FROM commissions
                WHERE status = 'paid'
                ORDER BY paid_at DESC
                LIMIT 10"
            
            echo -e "\n${CYAN}Acciones:${NC}"
            echo -e "  ${GREEN}[1]${NC} Marcar comisión como pagada"
            echo -e "  ${GREEN}[2]${NC} Ver detalle por revendedor"
            echo -e "  ${GREEN}[0]${NC} Volver"
            
            read -p "Selecciona: " COMM_OPT
            
            if [[ "$COMM_OPT" == "1" ]]; then
                read -p "ID de comisión a pagar: " COMM_ID
                sqlite3 "$DB" "UPDATE commissions SET status='paid', paid_at=CURRENT_TIMESTAMP WHERE id=$COMM_ID"
                echo -e "${GREEN}✅ Actualizado${NC}"
                read -p "Presiona Enter..."
            elif [[ "$COMM_OPT" == "2" ]]; then
                read -p "Username revendedor: " COMM_USER
                sqlite3 -column -header "$DB" "SELECT * FROM commissions WHERE reseller_username='$COMM_USER' ORDER BY created_at DESC"
                read -p "Presiona Enter..."
            fi
            ;;
        0)
            echo -e "\n${GREEN}👋 Hasta pronto${NC}"
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
# CREAR SCRIPT PARA QUE REVENDEDORES ACCEDAN
# ================================================
cat > /usr/local/bin/revendedor << 'REVEOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         🔐 PORTAL DE ACCESO PARA REVENDEDORES               ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"

read -p "Usuario: " USERNAME
read -s -p "Contraseña: " PASSWORD
echo ""

HASHED=$(echo -n "$PASSWORD" | sha256sum | awk '{print $1}')
DB="/opt/sshbot-pro/data/users.db"

RESELLER=$(sqlite3 "$DB" "SELECT username, name, credit_limit FROM resellers WHERE username='$USERNAME' AND password='$HASHED' AND status=1")

if [[ -z "$RESELLER" ]]; then
    echo -e "\n${RED}❌ Credenciales inválidas${NC}"
    exit 1
fi

echo -e "\n${GREEN}✅ Acceso concedido${NC}\n"

while true; do
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         📊 PANEL DEL REVENDEDOR - $(echo $RESELLER | cut -d'|' -f1)              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    
    # Estadísticas del revendedor
    MY_USERS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE created_by='$USERNAME'")
    MY_ACTIVE=$(sqlite3 "$DB" "SELECT COUNT(*) FROM users WHERE created_by='$USERNAME' AND status=1")
    MY_LIMIT=$(echo "$RESELLER" | cut -d'|' -f3)
    PENDING_COMM=$(sqlite3 "$DB" "SELECT SUM(commission_amount) FROM commissions WHERE reseller_username='$USERNAME' AND status='pending'")
    
    echo -e "${YELLOW}Tus estadísticas:${NC}"
    echo -e "  Usuarios creados: $MY_USERS (activos: $MY_ACTIVE)"
    echo -e "  Límite: $MY_LIMIT usuarios"
    echo -e "  Comisiones pendientes: $$([ -z "$PENDING_COMM" ] && echo "0" || echo "$PENDING_COMM")"
    echo -e ""
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}[1]${NC} 👤 Crear nuevo usuario"
    echo -e "${CYAN}[2]${NC} 👥 Listar mis usuarios"
    echo -e "${CYAN}[3]${NC} 💰 Ver mis comisiones"
    echo -e "${CYAN}[4]${NC} 📊 Estadísticas"
    echo -e "${CYAN}[0]${NC} Salir"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    read -p "Selecciona: " OPT
    
    case $OPT in
        1)
            clear
            echo -e "${CYAN}CREAR NUEVO USUARIO${NC}\n"
            
            # Verificar límite
            if [[ $MY_USERS -ge $MY_LIMIT ]]; then
                echo -e "${RED}❌ Has alcanzado tu límite de usuarios ($MY_LIMIT)${NC}"
                read -p "Presiona Enter..."
                continue
            fi
            
            read -p "Teléfono del cliente (ej: 5491122334455@c.us): " PHONE
            echo -e "\nPlanes disponibles:"
            echo -e "  1) 7 días"
            echo -e "  2) 15 días"
            echo -e "  3) 30 días"
            echo -e "  4) 50 días"
            echo -e "  t) Test (2 horas)"
            read -p "Selecciona: " PLAN
            
            case $PLAN in
                1) DAYS=7; TIPO="premium" ;;
                2) DAYS=15; TIPO="premium" ;;
                3) DAYS=30; TIPO="premium" ;;
                4) DAYS=50; TIPO="premium" ;;
                t|T) DAYS=0; TIPO="test" ;;
                *) echo -e "${RED}Opción inválida${NC}"; continue ;;
            esac
            
            # Generar username
            if [[ "$TIPO" == "test" ]]; then
                USER="test$(shuf -i 1000-9999 -n 1)"
            else
                USER="user$(shuf -i 1000-9999 -n 1)"
            fi
            
            PASS=$(jq -r '.bot.default_password' /opt/sshbot-pro/config/config.json)
            
            # Crear usuario en sistema
            if [[ "$TIPO" == "test" ]]; then
                EXPIRE=$(date -d "+$(jq -r '.prices.test_hours' /opt/sshbot-pro/config/config.json) hours" +"%Y-%m-%d %H:%M:%S")
                useradd -m -s /bin/bash "$USER" && echo "$USER:$PASS" | chpasswd
            else
                EXPIRE=$(date -d "+$DAYS days" +"%Y-%m-%d 23:59:59")
                useradd -M -s /bin/false -e "$(date -d "+$DAYS days" +%Y-%m-%d)" "$USER" && echo "$USER:$PASS" | chpasswd
            fi
            
            if [[ $? -eq 0 ]]; then
                sqlite3 "$DB" "INSERT INTO users (phone, username, password, tipo, expires_at, created_by) VALUES ('$PHONE', '$USER', '$PASS', '$TIPO', '$EXPIRE', '$USERNAME')"
                
                echo -e "\n${GREEN}✅ USUARIO CREADO${NC}"
                echo -e "Usuario: $USER"
                echo -e "Contraseña: $PASS"
                echo -e "Expira: $EXPIRE"
                
                # Log
                sqlite3 "$DB" "INSERT INTO reseller_logs (reseller_username, action, details) VALUES ('$USERNAME', 'create_user', 'Usuario $USER creado ($DAYS días)')"
            else
                echo -e "\n${RED}❌ Error al crear usuario${NC}"
            fi
            read -p "Presiona Enter..."
            ;;
        2)
            clear
            echo -e "${CYAN}TUS USUARIOS CREADOS${NC}\n"
            sqlite3 -column -header "$DB" "SELECT username, phone, tipo, expires_at, status FROM users WHERE created_by='$USERNAME' ORDER BY created_at DESC LIMIT 20"
            read -p "Presiona Enter..."
            ;;
        3)
            clear
            echo -e "${CYAN}TUS COMISIONES${NC}\n"
            sqlite3 -column -header "$DB" "SELECT created_at, amount, commission_amount, status FROM commissions WHERE reseller_username='$USERNAME' ORDER BY created_at DESC LIMIT 20"
            read -p "Presiona Enter..."
            ;;
        4)
            clear
            echo -e "${CYAN}TUS ESTADÍSTICAS DETALLADAS${NC}\n"
            
            echo -e "${YELLOW}Resumen:${NC}"
            sqlite3 "$DB" "
                SELECT 
                    'Total usuarios: ' || COUNT(*) || 
                    ' | Activos: ' || SUM(CASE WHEN status=1 THEN 1 ELSE 0 END) ||
                    ' | Tests: ' || SUM(CASE WHEN tipo='test' THEN 1 ELSE 0 END) ||
                    ' | Premium: ' || SUM(CASE WHEN tipo='premium' THEN 1 ELSE 0 END)
                FROM users WHERE created_by='$USERNAME'"
            
            echo -e "\n${YELLOW}Usuarios por mes:${NC}"
            sqlite3 "$DB" "SELECT strftime('%Y-%m', created_at) as mes, COUNT(*) FROM users WHERE created_by='$USERNAME' GROUP BY mes ORDER BY mes DESC LIMIT 6"
            
            echo -e "\n${YELLOW}Comisiones totales:${NC}"
            sqlite3 "$DB" "
                SELECT 
                    'Pendientes: $' || COALESCE(SUM(CASE WHEN status='pending' THEN commission_amount ELSE 0 END), 0) ||
                    ' | Pagadas: $' || COALESCE(SUM(CASE WHEN status='paid' THEN commission_amount ELSE 0 END), 0)
                FROM commissions WHERE reseller_username='$USERNAME'"
            
            read -p "Presiona Enter..."
            ;;
        0)
            echo -e "\n${GREEN}👋 Hasta luego${NC}"
            exit 0
            ;;
    esac
done
REVEOF

chmod +x /usr/local/bin/revendedor

# ================================================
# INICIAR TODO
# ================================================
echo -e "\n${CYAN}🚀 Iniciando sistema...${NC}"

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
║          🎉 INSTALACIÓN COMPLETADA - REVENDEDORES 🎉        ║
║                                                              ║
║       🤖 SSH BOT PRO - VERSIÓN REVENDEDORES v3.0           ║
║       👥 CON SISTEMA COMPLETO DE REVENDEDORES              ║
║       🔐 ACCESO CON CONTRASEÑA                             ║
║       💰 COMISIONES AUTOMÁTICAS                            ║
║       📊 PANEL INDIVIDUAL PARA CADA REVENDEDOR             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 CREDENCIALES DE ADMINISTRADOR:${NC}\n"
echo -e "  Usuario: ${GREEN}admin${NC}"
echo -e "  Contraseña: ${GREEN}$ADMIN_PASS${NC}"
echo -e "\n${RED}⚠️  GUARDA ESTA CONTRASEÑA - ES ÚNICA${NC}\n"

echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 COMANDOS DISPONIBLES:${NC}\n"
echo -e "  ${GREEN}sshbot${NC}        - Panel principal de administración"
echo -e "  ${GREEN}revendedor${NC}    - Portal de acceso para revendedores"
echo -e "  ${GREEN}pm2 logs sshbot-pro${NC} - Ver logs del bot"
echo -e "\n"

echo -e "${YELLOW}🌐 API PARA REVENDEDORES:${NC}"
echo -e "  URL: http://$SERVER_IP:3000"
echo -e "  Endpoints:"
echo -e "    POST /api/login"
echo -e "    GET  /api/stats"
echo -e "    GET  /api/users"
echo -e "    POST /api/users/create"
echo -e "    GET  /api/commissions"
echo -e "\n"

echo -e "${YELLOW}🚀 PRIMEROS PASOS:${NC}\n"
echo -e "  1. Guarda la contraseña de admin: ${GREEN}$ADMIN_PASS${NC}"
echo -e "  2. Ver logs y escanear QR: ${GREEN}pm2 logs sshbot-pro${NC}"
echo -e "  3. Configurar MercadoPago: ${GREEN}sshbot${NC} → Opción 7"
echo -e "  4. Crear revendedores: ${GREEN}sshbot${NC} → Opción 8"
echo -e "  5. Probar acceso revendedor: ${GREEN}revendedor${NC}"
echo -e "\n"

echo -e "${GREEN}✅ Sistema listo para usar con revendedores!${NC}\n"

# Preguntar si ver logs
read -p "$(echo -e "${YELLOW}¿Ver logs ahora? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}Mostrando logs...${NC}"
    echo -e "${YELLOW}📱 Espera que aparezca el QR para escanear...${NC}\n"
    sleep 2
    pm2 logs sshbot-pro
fi

exit 0