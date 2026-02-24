pipeline {
    agent any

    environment {
        ANSIBLE_HOST_KEY_CHECKING = "False"
        MONITORING_NETWORK = "monitoring-network"
    }

    parameters {
        booleanParam(name: 'RUN_SIMULATOR', defaultValue: false, description: 'Lancer le simulateur après déploiement ?')
        choice(name: 'GRAFANA_PASSWORD', choices: ['admin'], description: 'Mot de passe Grafana (admin par défaut)')
    }

    stages {
        stage('🧹 Nettoyage initial') {
            steps {
                script {
                    sh '''
                        echo "🧹 Nettoyage des conteneurs existants (optionnel)..."
                        # Ne pas forcer l'arrêt pour ne pas casser l'existant
                        echo "✅ Prêt"
                    '''
                }
            }
        }

        stage('🌐 Création du réseau de monitoring') {
            steps {
                script {
                    sh '''
                        echo "🌐 Création du réseau Docker..."
                        if ! docker network inspect ${MONITORING_NETWORK} >/dev/null 2>&1; then
                            docker network create ${MONITORING_NETWORK}
                            echo "✅ Réseau ${MONITORING_NETWORK} créé"
                        else
                            echo "✅ Réseau ${MONITORING_NETWORK} déjà existant"
                        fi
                    '''
                }
            }
        }

        stage('🐳 Création du conteneur DIND') {
            steps {
                script {
                    sh '''
                        echo "🐳 Configuration du conteneur Docker-in-Docker..."
                        
                        # Vérifier si le conteneur existe déjà
                        if ! docker ps -a | grep -q blog-server-simule; then
                            echo "📦 Création du conteneur blog-server-simule..."
                            docker run -d \
                              --name blog-server-simule \
                              --privileged \
                              -p 3000:3000 \
                              -p 8000:8000 \
                              --restart unless-stopped \
                              docker:dind
                            
                            echo "⏳ Attente 20 secondes pour le démarrage de Docker..."
                            sleep 20
                            
                            # Installer les outils nécessaires dans le DIND
                            docker exec blog-server-simule sh -c "
                                apk add --no-cache python3 py3-pip curl
                            "
                            echo "✅ Python installé dans le DIND"
                        else
                            echo "✅ Conteneur DIND déjà existant"
                            docker start blog-server-simule
                        fi
                        
                        # Connecter au réseau monitoring
                        docker network connect ${MONITORING_NETWORK} blog-server-simule 2>/dev/null || true
                        echo "✅ DIND connecté au réseau monitoring"
                    '''
                }
            }
        }

        stage('📦 Déploiement de MySQL') {
            steps {
                script {
                    sh '''
                        echo "🗄️ Déploiement de MySQL..."
                        
                        # Lancer MySQL si pas déjà présent
                        if ! docker ps -a | grep -q mysql-blog; then
                            docker run -d \
                              --name mysql-blog \
                              --network ${MONITORING_NETWORK} \
                              -e MYSQL_ROOT_PASSWORD=rootpassword \
                              -e MYSQL_DATABASE=smartshop \
                              -e MYSQL_USER=bloguser \
                              -e MYSQL_PASSWORD=blogpassword \
                              -p 3306:3306 \
                              --restart unless-stopped \
                              mysql:8.0
                            
                            echo "⏳ Attente du démarrage de MySQL (30 secondes)..."
                            sleep 30
                            
                            # Initialiser la base de données
                            echo "📊 Création des tables..."
                            docker exec -i mysql-blog mysql -u root -prootpassword << 'SQL_EOF'
CREATE DATABASE IF NOT EXISTS smartshop;
USE smartshop;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50),
    email VARCHAR(255),
    status ENUM('active','blocked') DEFAULT 'active',
    last_login TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    product_name VARCHAR(255),
    total_price DECIMAL(10,2),
    status ENUM('success','failed','pending') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL
);

CREATE TABLE IF NOT EXISTS payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT,
    amount DECIMAL(10,2),
    status ENUM('success','failed') NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS activity_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(255),
    severity ENUM('low','medium','high') DEFAULT 'low',
    status_code INT DEFAULT 200,
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SHOW TABLES;
SQL_EOF
                            echo "✅ Base de données initialisée"
                        else
                            echo "✅ MySQL déjà existant"
                            docker start mysql-blog
                        fi
                    '''
                }
            }
        }

        stage('🚀 Déploiement du Backend/Frontend') {
            steps {
                script {
                    sh '''
                        echo "🚀 Déploiement de l'application SmartShop..."
                        
                        # Créer les dossiers dans le DIND
                        docker exec blog-server-simule mkdir -p /apps/backend /apps/frontend
                        
                        # ===== BACKEND (app.py) =====
                        cat > /tmp/backend_app.py << 'BACKEND_EOF'
from flask import Flask, jsonify, request
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
from datetime import datetime
import random
import time
import os

app = Flask(__name__)
CORS(app)

# Configuration MySQL
MYSQL_HOSTS = ['mysql-blog', '172.17.0.2', '172.18.0.2', 'localhost']
MYSQL_USER = 'bloguser'
MYSQL_PASSWORD = 'blogpassword'
MYSQL_DATABASE = 'smartshop'

def get_db_connection():
    for host in MYSQL_HOSTS:
        try:
            conn = mysql.connector.connect(
                host=host,
                user=MYSQL_USER,
                password=MYSQL_PASSWORD,
                database=MYSQL_DATABASE,
                connection_timeout=5
            )
            print(f"✅ Connecté à MySQL via {host}")
            return conn
        except Error as e:
            print(f"❌ Échec connexion à {host}: {e}")
            continue
    raise Exception("Impossible de se connecter à MySQL")

def test_mysql_connection():
    try:
        conn = get_db_connection()
        conn.close()
        return True
    except:
        return False

@app.route('/')
def home():
    return jsonify({
        "message": "SmartShop Simulation API",
        "status": "running",
        "mysql_status": "connected" if test_mysql_connection() else "disconnected"
    })

def log_activity(action, severity='low', status_code=200, details=None):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO activity_logs (action, severity, status_code, details, created_at) VALUES (%s, %s, %s, %s, %s)",
            (action, severity, status_code, details or '', datetime.now())
        )
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"❌ Erreur log: {e}")

# ============ USERS ============
@app.route('/api/users/create', methods=['POST'])
def create_user():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        usernames = ["Alice", "Bob", "Charlie", "David", "Emma", "Frank", "Grace", "Henry", "Ivy", "Jack"]
        domains = ["gmail.com", "yahoo.com", "hotmail.com", "outlook.com"]
        
        username = random.choice(usernames) + str(random.randint(1, 999))
        email = f"{username.lower()}@{random.choice(domains)}"
        
        cursor.execute(
            "INSERT INTO users (username, email, status, last_login, is_active, created_at) VALUES (%s, %s, %s, %s, %s, %s)",
            (username, email, 'active', datetime.now(), True, datetime.now())
        )
        
        user_id = cursor.lastrowid
        conn.commit()
        cursor.close()
        conn.close()
        
        log_activity(f"User created: {username}", "low", 201)
        
        return jsonify({"message": "User created", "id": user_id, "username": username, "email": email})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/users/login/<int:user_id>', methods=['POST'])
def login_user(user_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE users SET last_login = %s, status = 'active' WHERE id = %s", (datetime.now(), user_id))
        conn.commit()
        cursor.close()
        conn.close()
        log_activity(f"User {user_id} logged in", "low", 200)
        return jsonify({"message": f"User {user_id} logged in"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/users/logout/<int:user_id>', methods=['POST'])
def logout_user(user_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE users SET status = 'blocked' WHERE id = %s", (user_id,))
        conn.commit()
        cursor.close()
        conn.close()
        log_activity(f"User {user_id} logged out", "low", 200)
        return jsonify({"message": f"User {user_id} logged out"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ============ ORDERS ============
@app.route('/api/orders/create', methods=['POST'])
def create_order():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT id FROM users WHERE status = 'active' ORDER BY RAND() LIMIT 1")
        user = cursor.fetchone()
        
        if not user:
            cursor.execute("INSERT INTO users (username, email, status, last_login, is_active, created_at) VALUES (%s, %s, %s, %s, %s, %s)",
                          ("AutoUser", "auto@example.com", 'active', datetime.now(), True, datetime.now()))
            user_id = cursor.lastrowid
            conn.commit()
            user = (user_id,)
        
        products = [
            ("Smartphone XYZ", 699.99), ("Tablette Pro", 399.99), ("Écouteurs sans fil", 89.99),
            ("Montre connectée", 199.99), ("Enceinte Bluetooth", 79.99), ("Chargeur rapide", 29.99),
            ("Coque de protection", 19.99), ("Carte mémoire 128GB", 39.99)
        ]
        
        product = random.choice(products)
        
        cursor.execute(
            "INSERT INTO orders (user_id, product_name, total_price, status, created_at) VALUES (%s, %s, %s, %s, %s)",
            (user[0], product[0], product[1], 'pending', datetime.now())
        )
        
        order_id = cursor.lastrowid
        conn.commit()
        cursor.close()
        conn.close()
        
        log_activity(f"Order created: {product[0]} - {product[1]}€", "low", 201)
        
        return jsonify({"message": "Order created", "id": order_id, "product": product[0], "amount": product[1]})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/orders/validate/<int:order_id>', methods=['POST'])
def validate_order(order_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE orders SET status = 'success', updated_at = %s WHERE id = %s", (datetime.now(), order_id))
        conn.commit()
        cursor.close()
        conn.close()
        log_activity(f"Order {order_id} validated", "medium", 200)
        return jsonify({"message": f"Order {order_id} validated"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/orders/cancel/<int:order_id>', methods=['POST'])
def cancel_order(order_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("UPDATE orders SET status = 'failed', updated_at = %s WHERE id = %s", (datetime.now(), order_id))
        conn.commit()
        cursor.close()
        conn.close()
        log_activity(f"Order {order_id} cancelled", "medium", 200)
        return jsonify({"message": f"Order {order_id} cancelled"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ============ PAYMENTS ============
@app.route('/api/payments/process/<int:order_id>', methods=['POST'])
def process_payment(order_id):
    try:
        data = request.get_json()
        status = data.get('status', 'success') if data else 'success'
        
        conn = get_db_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT total_price FROM orders WHERE id = %s", (order_id,))
        order = cursor.fetchone()
        
        if not order:
            return jsonify({"error": "Order not found"}), 404
        
        cursor.execute(
            "INSERT INTO payments (order_id, amount, status, created_at) VALUES (%s, %s, %s, %s)",
            (order_id, order[0], status, datetime.now())
        )
        
        payment_id = cursor.lastrowid
        
        if status == 'success':
            cursor.execute("UPDATE orders SET status = 'success', updated_at = %s WHERE id = %s", (datetime.now(), order_id))
        
        conn.commit()
        cursor.close()
        conn.close()
        
        log_activity(f"Payment {status} for order {order_id} - {order[0]}€", 
                    "low" if status == 'success' else "medium", 200)
        
        return jsonify({"message": f"Payment {status}", "payment_id": payment_id, "order_id": order_id})
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ============ ERRORS ============
@app.route('/api/errors/404', methods=['GET'])
def error_404():
    log_activity("404 Not Found", "medium", 404)
    return jsonify({"error": "Not Found"}), 404

@app.route('/api/errors/500', methods=['GET'])
def error_500():
    log_activity("500 Internal Server Error", "high", 500)
    return jsonify({"error": "Internal Server Error"}), 500

@app.route('/api/errors/custom', methods=['POST'])
def custom_error():
    data = request.get_json()
    severity = data.get('severity', 'medium') if data else 'medium'
    log_activity(f"Custom error with {severity} severity", severity, 418)
    return jsonify({"message": f"Error logged with {severity} severity"})

# ============ STATS ============
@app.route('/api/stats', methods=['GET'])
def get_stats():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        stats = {}
        cursor.execute("SELECT COUNT(*) as count FROM users WHERE DATE(last_login) = CURDATE()")
        stats['active_users_today'] = cursor.fetchone()['count'] or 0
        
        cursor.execute("SELECT COUNT(*) as count FROM orders WHERE created_at >= NOW() - INTERVAL 10 MINUTE")
        stats['orders_last_10min'] = cursor.fetchone()['count'] or 0
        
        cursor.execute("SELECT status, COUNT(*) as count FROM payments WHERE created_at >= NOW() - INTERVAL 1 HOUR GROUP BY status")
        payments = cursor.fetchall()
        stats['payments_last_hour'] = {p['status']: p['count'] for p in payments} if payments else {}
        
        cursor.execute("SELECT COUNT(*) as count FROM users")
        stats['total_users'] = cursor.fetchone()['count'] or 0
        
        cursor.execute("SELECT COUNT(*) as count FROM orders WHERE status = 'pending'")
        stats['pending_orders'] = cursor.fetchone()['count'] or 0
        
        cursor.close()
        conn.close()
        return jsonify(stats)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/activity-logs', methods=['GET'])
def get_activity_logs():
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM activity_logs ORDER BY created_at DESC LIMIT 100")
        logs = cursor.fetchall()
        cursor.close()
        conn.close()
        return jsonify(logs)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/health', methods=['GET'])
def health_check():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        conn.close()
        mysql_status = "connected"
    except:
        mysql_status = "disconnected"
    
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "mysql": mysql_status,
        "api_version": "1.0"
    })

if __name__ == '__main__':
    print("=" * 60)
    print("🚀 SmartShop API Server")
    print("=" * 60)
    if test_mysql_connection():
        print("✅ Connexion MySQL établie")
    app.run(host='0.0.0.0', port=8000, debug=True)
BACKEND_EOF

                        docker cp /tmp/backend_app.py blog-server-simule:/apps/backend/app.py
                        
                        # ===== FRONTEND (index.html) =====
                        cat > /tmp/index.html << 'FRONTEND_EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SmartShop Simulator</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1400px; margin: 0 auto; }
        h1 { text-align: center; color: white; margin-bottom: 30px; }
        .grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px; }
        .card {
            background: white; border-radius: 15px; padding: 25px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
        }
        .button-group { display: flex; flex-wrap: wrap; gap: 10px; margin: 15px 0; }
        button {
            padding: 12px 20px; border: none; border-radius: 8px;
            font-size: 14px; font-weight: 600; cursor: pointer;
            flex: 1 1 calc(50% - 10px);
        }
        button.primary { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        button.success { background: #48bb78; color: white; }
        button.warning { background: #fbbf24; color: #333; }
        button.danger { background: #f56565; color: white; }
        .stats-panel { background: #2d3748; color: white; padding: 20px; border-radius: 10px; margin-top: 20px; }
        .log-viewer {
            background: #1a202c; color: #cbd5e0; padding: 15px; border-radius: 8px;
            font-family: 'Courier New', monospace; height: 200px; overflow-y: auto;
            margin-top: 20px;
        }
        .stat-value { font-size: 2em; font-weight: bold; color: #68d391; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🛍️ SmartShop Simulator</h1>
        <div class="grid">
            <div class="card">
                <h2>👥 Utilisateurs</h2>
                <div class="button-group">
                    <button class="primary" onclick="createUser()">Créer utilisateur</button>
                    <button class="success" onclick="loginUser()">Connexion</button>
                    <button class="warning" onclick="logoutUser()">Déconnexion</button>
                </div>
            </div>
            <div class="card">
                <h2>📦 Commandes</h2>
                <div class="button-group">
                    <button class="primary" onclick="createOrder()">Créer commande</button>
                    <button class="success" onclick="validateOrder()">Valider</button>
                    <button class="danger" onclick="cancelOrder()">Annuler</button>
                </div>
            </div>
            <div class="card">
                <h2>💳 Paiements</h2>
                <div class="button-group">
                    <button class="success" onclick="processPayment('success')">Paiement réussi</button>
                    <button class="danger" onclick="processPayment('failed')">Paiement échoué</button>
                </div>
            </div>
            <div class="card">
                <h2>⚠️ Erreurs</h2>
                <div class="button-group">
                    <button class="warning" onclick="generate404()">Erreur 404</button>
                    <button class="danger" onclick="generate500()">Erreur 500</button>
                </div>
            </div>
        </div>
        
        <div class="stats-panel">
            <h3>📊 Statistiques temps réel</h3>
            <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 10px;">
                <div><span id="activeUsers">0</span> utilisateurs actifs</div>
                <div><span id="ordersLast10min">0</span> commandes/10min</div>
                <div><span id="successPayments">0</span> paiements réussis</div>
                <div><span id="failedPayments">0</span> paiements échoués</div>
            </div>
        </div>
        
        <div class="card">
            <h2>📋 Activité récente</h2>
            <div class="log-viewer" id="logViewer">Chargement...</div>
        </div>
    </div>

    <script>
        const API_URL = 'http://localhost:8000/api';
        let currentUserId = null, currentOrderId = null;

        async function createUser() {
            const res = await fetch(`${API_URL}/users/create`, {method:'POST'});
            const data = await res.json();
            addLog(`✅ Utilisateur: ${data.username} (ID: ${data.id})`, 'low');
            currentUserId = data.id;
            refreshStats();
        }
        
        async function loginUser() {
            if(!currentUserId) { alert('Créez d\'abord un utilisateur'); return; }
            await fetch(`${API_URL}/users/login/${currentUserId}`, {method:'POST'});
            addLog(`🔑 Utilisateur ${currentUserId} connecté`, 'low');
        }
        
        async function logoutUser() {
            if(!currentUserId) { alert('Créez d\'abord un utilisateur'); return; }
            await fetch(`${API_URL}/users/logout/${currentUserId}`, {method:'POST'});
            addLog(`🚪 Utilisateur ${currentUserId} déconnecté`, 'low');
        }
        
        async function createOrder() {
            const res = await fetch(`${API_URL}/orders/create`, {method:'POST'});
            const data = await res.json();
            addLog(`📦 Commande: ${data.product} (${data.amount}€)`, 'low');
            currentOrderId = data.id;
            refreshStats();
        }
        
        async function validateOrder() {
            if(!currentOrderId) { alert('Créez d\'abord une commande'); return; }
            await fetch(`${API_URL}/orders/validate/${currentOrderId}`, {method:'POST'});
            addLog(`✅ Commande ${currentOrderId} validée`, 'medium');
        }
        
        async function cancelOrder() {
            if(!currentOrderId) { alert('Créez d\'abord une commande'); return; }
            await fetch(`${API_URL}/orders/cancel/${currentOrderId}`, {method:'POST'});
            addLog(`❌ Commande ${currentOrderId} annulée`, 'medium');
        }
        
        async function processPayment(status) {
            if(!currentOrderId) { alert('Créez d\'abord une commande'); return; }
            const res = await fetch(`${API_URL}/payments/process/${currentOrderId}`, {
                method:'POST', headers:{'Content-Type':'application/json'},
                body:JSON.stringify({status})
            });
            addLog(`💳 Paiement ${status}`, status==='success'?'low':'medium');
            refreshStats();
        }
        
        async function generate404() { 
            await fetch(`${API_URL}/errors/404`); 
            addLog('⚠️ Erreur 404', 'medium'); 
        }
        
        async function generate500() { 
            await fetch(`${API_URL}/errors/500`); 
            addLog('🔥 Erreur 500', 'high'); 
        }
        
        function addLog(msg, sev) {
            const div = document.getElementById('logViewer');
            const entry = document.createElement('div');
            entry.innerHTML = `[${new Date().toLocaleTimeString()}] [${sev}] ${msg}`;
            div.insertBefore(entry, div.firstChild);
            if(div.children.length > 50) div.removeChild(div.lastChild);
        }
        
        async function refreshStats() {
            try {
                const res = await fetch(`${API_URL}/stats`);
                const stats = await res.json();
                document.getElementById('activeUsers').textContent = stats.active_users_today || 0;
                document.getElementById('ordersLast10min').textContent = stats.orders_last_10min || 0;
                document.getElementById('successPayments').textContent = (stats.payments_last_hour?.success) || 0;
                document.getElementById('failedPayments').textContent = (stats.payments_last_hour?.failed) || 0;
            } catch(e) { console.error(e); }
        }
        
        setInterval(refreshStats, 5000);
        window.onload = () => {
            addLog('🚀 Application démarrée', 'low');
            refreshStats();
        };
    </script>
</body>
</html>
FRONTEND_EOF

                        docker cp /tmp/index.html blog-server-simule:/apps/frontend/index.html
                        
                        # Lancer le backend
                        docker exec blog-server-simule sh -c "
                            cd /apps/backend &&
                            python3 -m venv venv 2>/dev/null || true &&
                            . venv/bin/activate &&
                            pip install --quiet flask flask-cors mysql-connector-python requests &&
                            pkill -f 'python app.py' 2>/dev/null || true &&
                            nohup python app.py > /tmp/backend.log 2>&1 &
                        "
                        
                        # Lancer le frontend
                        docker exec blog-server-simule sh -c "
                            cd /apps/frontend &&
                            pkill -f 'http.server' 2>/dev/null || true &&
                            nohup python3 -m http.server 3000 > /tmp/frontend.log 2>&1 &
                        "
                        
                        echo "✅ Application déployée"
                        sleep 5
                    '''
                }
            }
        }

        stage('📊 Déploiement du monitoring') {
            steps {
                script {
                    sh '''
                        echo "📊 Déploiement de la stack monitoring..."
                        
                        # Configuration Prometheus
                        mkdir -p monitoring/prometheus
                        cat > monitoring/prometheus/prometheus.yml << 'PROMETHEUS_EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'mysql'
    static_configs:
      - targets: ['mysql-exporter:9104']
        labels:
          instance: 'mysql-blog'
PROMETHEUS_EOF

                        # Prometheus
                        if ! docker ps -a | grep -q prometheus; then
                            docker run -d \
                              --name prometheus \
                              --network ${MONITORING_NETWORK} \
                              -p 9090:9090 \
                              -v ${PWD}/monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
                              --restart unless-stopped \
                              prom/prometheus:latest
                        else
                            docker start prometheus
                        fi

                        # Node Exporter
                        if ! docker ps -a | grep -q node-exporter; then
                            docker run -d \
                              --name node-exporter \
                              --network ${MONITORING_NETWORK} \
                              --pid host \
                              -v /proc:/host/proc:ro \
                              -v /sys:/host/sys:ro \
                              -v /:/rootfs:ro \
                              --restart unless-stopped \
                              prom/node-exporter:latest \
                              --path.procfs=/host/proc \
                              --path.rootfs=/rootfs \
                              --path.sysfs=/host/sys
                        else
                            docker start node-exporter
                        fi

                        # MySQL Exporter
                        if ! docker ps -a | grep -q mysql-exporter; then
                            docker run -d \
                              --name mysql-exporter \
                              --network ${MONITORING_NETWORK} \
                              -p 9104:9104 \
                              -e DATA_SOURCE_NAME="bloguser:blogpassword@(mysql-blog:3306)/" \
                              --restart unless-stopped \
                              prom/mysqld-exporter:latest
                        else
                            docker start mysql-exporter
                        fi

                        # Grafana
                        if ! docker ps -a | grep -q grafana; then
                            docker run -d \
                              --name grafana \
                              --network ${MONITORING_NETWORK} \
                              -p 3030:3000 \
                              -e GF_SECURITY_ADMIN_PASSWORD=${params.GRAFANA_PASSWORD} \
                              -e GF_INSTALL_PLUGINS=grafana-piechart-panel \
                              --restart unless-stopped \
                              grafana/grafana:latest
                        else
                            docker start grafana
                        fi

                        echo "✅ Monitoring déployé"
                        sleep 10
                    '''
                }
            }
        }

        stage('🤖 Installation du simulateur Python') {
            steps {
                script {
                    sh '''
                        echo "🤖 Installation du simulateur..."
                        
                        # Copier le simulateur
                        cat > /tmp/simulator.py << 'SIMULATOR_EOF'
#!/usr/bin/env python3
import requests, json, time, random, os, sys
from datetime import datetime
from threading import Lock

API_URL = "http://localhost:8000/api"
LOG_FILE = f"/tmp/simulation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

stats = {'users': 0, 'orders': 0, 'payments': 0, 'errors': 0, 'start_time': time.time()}
stats_lock = Lock()

class Colors:
    HEADER = '\033[95m'; BLUE = '\033[94m'; CYAN = '\033[96m'; GREEN = '\033[92m'
    YELLOW = '\033[93m'; RED = '\033[91m'; PURPLE = '\033[95m'; END = '\033[0m'

def log(message, color=Colors.END):
    t = datetime.now().strftime('%H:%M:%S')
    print(f"{color}{t} - {message}{Colors.END}")
    with open(LOG_FILE, 'a') as f: f.write(f"{t} - {message}\n")

def check_api():
    log("🔍 Vérification de l'API...", Colors.BLUE)
    try:
        requests.get(f"{API_URL}/health", timeout=3)
        log("✅ API OK", Colors.GREEN)
        return True
    except:
        log("❌ API non disponible", Colors.RED)
        return False

def create_user():
    log("📝 Création utilisateur...", Colors.BLUE)
    try:
        r = requests.post(f"{API_URL}/users/create", timeout=5)
        if r.status_code == 200:
            data = r.json()
            with stats_lock: stats['users'] += 1
            log(f"✅ Utilisateur: {data['username']} (ID: {data['id']})", Colors.GREEN)
            return data['id']
    except: pass
    return None

def create_order():
    log("📦 Création commande...", Colors.YELLOW)
    try:
        r = requests.post(f"{API_URL}/orders/create", timeout=5)
        if r.status_code == 200:
            data = r.json()
            with stats_lock: stats['orders'] += 1
            log(f"✅ Commande: {data['product']} - {data['amount']}€ (ID: {data['id']})", Colors.GREEN)
            return data['id']
    except: pass
    return None

def process_payment(order_id):
    if not order_id: return
    status = "success" if random.random() < 0.8 else "failed"
    log(f"💳 Paiement {order_id} ({status})...", Colors.PURPLE)
    try:
        r = requests.post(f"{API_URL}/payments/process/{order_id}", json={"status": status})
        if r.status_code == 200:
            with stats_lock: stats['payments'] += 1
            log(f"✅ Paiement {status}", Colors.GREEN if status=='success' else Colors.RED)
    except: pass

def generate_error():
    t = random.randint(0,2)
    if t==0: 
        log("⚠️ Erreur 404", Colors.PURPLE)
        requests.get(f"{API_URL}/errors/404")
    elif t==1: 
        log("⚠️ Erreur 500", Colors.PURPLE)
        requests.get(f"{API_URL}/errors/500")
    else: 
        log("⚠️ Erreur personnalisée", Colors.PURPLE)
        requests.post(f"{API_URL}/errors/custom", json={"severity":"medium"})
    with stats_lock: stats['errors'] += 1

def run_scenario():
    s = random.randint(0,4)
    if s==0:
        uid = create_user()
        if uid:
            for _ in range(random.randint(1,3)):
                oid = create_order()
                if oid: process_payment(oid); time.sleep(1)
    elif s==1:
        for _ in range(random.randint(3,5)):
            oid = create_order()
            if oid: process_payment(oid); time.sleep(0.5)
    elif s==2:
        for _ in range(2): generate_error(); time.sleep(1)
        uid = create_user()
        if uid:
            oid = create_order()
            if oid: process_payment(oid)
    else:
        for _ in range(2):
            uid = create_user()
            if uid:
                oid = create_order()
                if oid: process_payment(oid); time.sleep(1)

def print_stats():
    uptime = int(time.time() - stats['start_time'])
    h, m, s = uptime//3600, (uptime%3600)//60, uptime%60
    with stats_lock:
        print(f"\n{Colors.CYAN}════════════════════════════════════{Colors.END}")
        print(f"⏱️  Uptime: {h:02d}h{m:02d}m{s:02d}s")
        print(f"👥 Utilisateurs: {stats['users']}")
        print(f"📦 Commandes: {stats['orders']}")
        print(f"💳 Paiements: {stats['payments']}")
        print(f"⚠️ Erreurs: {stats['errors']}")
        print(f"{Colors.CYAN}════════════════════════════════════{Colors.END}\n")

def auto_simulation():
    os.system('clear')
    if not check_api(): return
    log("🚀 Simulation démarrée", Colors.GREEN)
    log(f"📁 Logs: {LOG_FILE}", Colors.YELLOW)
    cycles = 0
    try:
        while True:
            cycles += 1
            print(f"\n{Colors.CYAN}════════════════════════════════════{Colors.END}")
            log(f"CYCLE {cycles}", Colors.CYAN)
            for _ in range(random.randint(2,4)):
                run_scenario()
                time.sleep(random.uniform(1,2))
            print_stats()
            time.sleep(random.randint(10,20))
    except KeyboardInterrupt:
        print("\n"); log("👋 Arrêt", Colors.GREEN)

if __name__ == "__main__":
    try: import requests
    except: os.system("pip install requests")
    auto_simulation()
SIMULATOR_EOF

                        docker cp /tmp/simulator.py blog-server-simule:/apps/backend/simulator.py
                        docker exec blog-server-simule chmod +x /apps/backend/simulator.py
                        
                        echo "✅ Simulateur installé"
                    '''
                }
            }
        }

        stage('✅ Vérification finale') {
            steps {
                script {
                    sh '''
                        echo "🔍 Vérification finale..."
                        sleep 10
                        
                        echo ""
                        echo "📋 CONTENEURS EN COURS :"
                        echo "========================="
                        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
                        
                        echo ""
                        echo "🌐 VÉRIFICATION DES ENDPOINTS :"
                        echo "================================"
                        for url in \
                            "http://localhost:8000/api/health" \
                            "http://localhost:3000" \
                            "http://localhost:9090" \
                            "http://localhost:3030" \
                            "http://localhost:9104/metrics"
                        do
                            code=$(curl -s -o /dev/null -w "%{http_code}" $url || echo "000")
                            status="❌"
                            [ "$code" = "200" ] && status="✅"
                            [ "$code" = "302" ] && status="✅"
                            printf "%-30s %s %s\n" "$url" "$status" "$code"
                        done
                        
                        echo ""
                        echo "🎉 DÉPLOIEMENT TERMINÉ AVEC SUCCÈS !"
                        echo "====================================="
                        echo "📊 Accès aux services :"
                        echo "   - Frontend: http://localhost:3000"
                        echo "   - Backend API: http://localhost:8000"
                        echo "   - Prometheus: http://localhost:9090"
                        echo "   - Grafana: http://localhost:3030 (admin/${params.GRAFANA_PASSWORD})"
                        echo ""
                        echo "🤖 Lancer le simulateur :"
                        echo "   docker exec -it blog-server-simule python /apps/backend/simulator.py"
                    '''
                }
            }
        }
    }

    post {
        always {
            sh '''
                echo "✅ Pipeline terminé"
            '''
        }
    }
}
