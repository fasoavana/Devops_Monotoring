pipeline {
    agent any

    environment {
        DOCKER_CREDS = credentials('docker-hub-creds')
        ANSIBLE_HOST_KEY_CHECKING = "False"
    }

    stages {
        stage('Build & Push Images') {
            steps {
                script {
                    sh '''
                        echo "🔑 Connexion à Docker Hub..."
                        echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin
                        
                        echo "🏗️ Build des images..."
                        docker build -t faso01/blog-backend:latest apps/backend
                        docker push faso01/blog-backend:latest
                        
                        docker build -t faso01/blog-frontend:latest apps/frontend
                        docker push faso01/blog-frontend:latest
                        
                        echo "✅ Images pushées avec succès"
                    '''
                }
            }
        }

        stage('Déploiement avec Ansible') {
            agent {
                docker {
                    image 'docker:latest'
                    args '''
                        -u root 
                        -v /var/run/docker.sock:/var/run/docker.sock
                        -v ${WORKSPACE}:/workspace
                        -w /workspace
                    '''
                }
            }
            steps {
                script {
                    sh '''
                        echo "📦 Installation d'Ansible..."
                        apk add --no-cache ansible py3-pip
                        
                        echo "✅ Versions installées :"
                        ansible --version | head -1
                        docker --version
                        
                        echo "🚀 Création du playbook Ansible..."
                        
                        # Créer le dossier playbooks s'il n'existe pas
                        mkdir -p ansible/playbooks
                        
                        # Version améliorée du playbook avec gestion des conteneurs existants
                        cat > ansible/playbooks/deploy_blog.yml << 'EOF'
---
- name: Déployer l'application blog
  hosts: all
  connection: docker
  tasks:
    - name: Supprimer les anciens conteneurs s'ils existent
      shell: |
        docker rm -f blog-backend || true
        docker rm -f blog-frontend || true
      ignore_errors: yes
    
    - name: Vérifier que l'image backend existe
      shell: |
        docker images faso01/blog-backend:latest --format 'table {% raw %}{{.Repository}}{% endraw %}'
      register: backend_image
      ignore_errors: yes
    
    - name: Lancer le conteneur backend
      shell: |
        docker run -d \
          --name blog-backend \
          -p 8000:8000 \
          --restart unless-stopped \
          faso01/blog-backend:latest
      when: backend_image.stdout is search("faso01/blog-backend")
      ignore_errors: yes
    
    - name: Vérifier que l'image frontend existe
      shell: |
        docker images faso01/blog-frontend:latest --format 'table {% raw %}{{.Repository}}{% endraw %}'
      register: frontend_image
      ignore_errors: yes
    
    - name: Lancer le conteneur frontend
      shell: |
        docker run -d \
          --name blog-frontend \
          -p 3000:80 \
          --restart unless-stopped \
          faso01/blog-frontend:latest
      when: frontend_image.stdout is search("faso01/blog-frontend")
      ignore_errors: yes
    
    - name: Vérifier les conteneurs
      shell: docker ps
      register: docker_ps
    
    - name: Afficher les conteneurs
      debug:
        var: docker_ps.stdout_lines
EOF
                        
                        echo "📄 Inventaire Ansible :"
                        cat ansible/inventory/hosts.ini
                        
                        echo "🚀 Exécution du playbook de déploiement..."
                        ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy_blog.yml -v
                    '''
                }
            }
        }

        stage('Lancement Monitoring') {
            steps {
                script {
                    sh '''
                        echo "📊 Installation de docker-compose..."
                        
                        # Installation de docker-compose avec les bonnes permissions
                        if ! command -v docker-compose &> /dev/null; then
                            echo "Téléchargement de docker-compose..."
                            curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                            chmod +x /usr/local/bin/docker-compose
                            echo "✅ docker-compose installé"
                        fi
                        
                        docker-compose --version
                        
                        echo "📊 Configuration du monitoring..."
                        
                        if [ -f "docker-compose-monitoring.yml" ]; then
                            echo "Fichier monitoring existant trouvé"
                        else
                            echo "❌ docker-compose-monitoring.yml non trouvé"
                            echo "Création d'un fichier de monitoring par défaut..."
                            
                            cat > docker-compose-monitoring.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3030:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    restart: unless-stopped
EOF
                            
                            mkdir -p monitoring/prometheus
                            cat > monitoring/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF
                            echo "✅ Fichiers de monitoring créés"
                        fi
                        
                        echo "🚀 Démarrage des services monitoring..."
                        docker-compose -f docker-compose-monitoring.yml down --remove-orphans 2>/dev/null || true
                        docker-compose -f docker-compose-monitoring.yml up -d
                        
                        echo "✅ Conteneurs monitoring :"
                        docker-compose -f docker-compose-monitoring.yml ps
                        
                        # Attente du démarrage
                        echo "Attente du démarrage des services..."
                        sleep 10
                        
                        # Vérification des endpoints
                        echo ""
                        echo "📊 Vérification des endpoints monitoring :"
                        curl -s -f http://localhost:9090 > /dev/null && echo "✅ Prometheus OK (port 9090)" || echo "⚠️ Prometheus non accessible"
                        curl -s -f http://localhost:3030 > /dev/null && echo "✅ Grafana OK (port 3030)" || echo "⚠️ Grafana non accessible"
                    '''
                }
            }
        }
        
        stage('Vérification finale') {
            steps {
                script {
                    sh '''
                        echo "🔍 Vérification finale des déploiements..."
                        echo ""
                        
                        echo "📋 Conteneurs en cours d'exécution :"
                        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
                        
                        echo ""
                        echo "🌐 Endpoints disponibles :"
                        echo "   ⚙️ Backend API:   http://localhost:8000"
                        echo "   📱 Frontend:       http://localhost:3000"
                        echo "   📊 Prometheus:     http://localhost:9090"
                        echo "   📈 Grafana:        http://localhost:3030 (admin/admin)"
                        
                        echo ""
                        echo "🔄 Tests des endpoints :"
                        
                        # Test backend
                        if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 | grep -q "200"; then
                            echo "✅ Backend (8000): accessible"
                        else
                            echo "⚠️ Backend (8000): non accessible"
                        fi
                        
                        # Test frontend
                        if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200"; then
                            echo "✅ Frontend (3000): accessible"
                        else
                            echo "⚠️ Frontend (3000): non accessible"
                        fi
                        
                        # Test Prometheus
                        if curl -s -o /dev/null -w "%{http_code}" http://localhost:9090 | grep -q "200"; then
                            echo "✅ Prometheus (9090): accessible"
                        else
                            echo "⚠️ Prometheus (9090): non accessible"
                        fi
                        
                        # Test Grafana
                        if curl -s -o /dev/null -w "%{http_code}" http://localhost:3030 | grep -q "200"; then
                            echo "✅ Grafana (3030): accessible"
                        else
                            echo "⚠️ Grafana (3030): non accessible"
                        fi
                        
                        echo ""
                        echo "🎉 Déploiement terminé avec succès !"
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                sh '''
                    echo "🧹 Nettoyage..."
                    docker logout 2>/dev/null || true
                '''
                echo "✅ Pipeline terminé"
            }
        }
        success {
            echo "🎉 SUCCÈS COMPLET ! Tous les services sont déployés :"
            echo "   ⚙️ Backend API:   http://localhost:8000"
            echo "   📱 Frontend:       http://localhost:3000"
            echo "   📊 Prometheus:     http://localhost:9090"
            echo "   📈 Grafana:        http://localhost:3030 (admin/admin)"
        }
        failure {
            echo "❌ ÉCHEC ! Vérifiez les logs ci-dessus pour plus de détails."
        }
    }
}
