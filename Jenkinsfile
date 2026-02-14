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
                        
                        echo "🚀 PRÉPARATION DU CONTENEUR DIND..."
                        
                        # Installer Python dans le conteneur DIND
                        docker exec blog-server-simule sh -c "
                            apk add --no-cache python3 && \
                            ln -sf /usr/bin/python3 /usr/bin/python
                        " || echo "Python déjà installé"
                        
                        echo "🚀 Création du playbook Ansible..."
                        
                        # Créer le dossier playbooks s'il n'existe pas
                        mkdir -p ansible/playbooks
                        
                        # Version SIMPLIFIÉE - commandes shell directes
                        cat > ansible/playbooks/deploy_blog.yml << 'EOF'
---
- name: Déployer l'application blog
  hosts: all
  connection: docker
  gather_facts: no  # Désactive la collecte de faits qui nécessite Python
  
  tasks:
    - name: Supprimer les anciens conteneurs s'ils existent
      shell: |
        docker rm -f blog-backend 2>/dev/null || true
        docker rm -f blog-frontend 2>/dev/null || true
    
    - name: Lancer le conteneur backend
      shell: |
        docker run -d \
          --name blog-backend \
          -p 8000:8000 \
          --restart unless-stopped \
          faso01/blog-backend:latest
    
    - name: Lancer le conteneur frontend
      shell: |
        docker run -d \
          --name blog-frontend \
          -p 3000:80 \
          --restart unless-stopped \
          faso01/blog-frontend:latest
    
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
                        
                        # Installation simple de docker-compose
                        if ! command -v docker-compose &> /dev/null; then
                            echo "Téléchargement de docker-compose..."
                            curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /tmp/docker-compose
                            chmod +x /tmp/docker-compose
                        fi
                        
                        DOCKER_COMPOSE_CMD="docker-compose"
                        [ -f "/tmp/docker-compose" ] && DOCKER_COMPOSE_CMD="/tmp/docker-compose"
                        
                        echo "📊 FORCER LE REDÉMARRAGE DU MONITORING..."
                        
                        # Supprimer les anciens conteneurs
                        docker rm -f monitoring-prometheus monitoring-grafana 2>/dev/null || true
                        
                        # Créer les fichiers de monitoring si nécessaire
                        if [ ! -f "docker-compose-monitoring.yml" ]; then
                            cat > docker-compose-monitoring.yml << 'EOF'
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: monitoring-prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: monitoring-grafana
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
EOF
                        fi
                        
                        echo "🚀 Démarrage du monitoring..."
                        $DOCKER_COMPOSE_CMD -f docker-compose-monitoring.yml up -d
                        
                        echo "✅ Conteneurs monitoring :"
                        docker ps | grep -E "prometheus|grafana"
                        
                        sleep 10
                        
                        echo ""
                        echo "📊 Vérification finale :"
                        curl -s -o /dev/null -w "Prometheus (9090): %{http_code}\n" http://localhost:9090 || echo "Prometheus: KO"
                        curl -s -o /dev/null -w "Grafana (3030): %{http_code}\n" http://localhost:3030 || echo "Grafana: KO"
                    '''
                }
            }
        }
        
        stage('Vérification finale') {
            steps {
                script {
                    sh '''
                        echo ""
                        echo "🎉 RÉSULTAT FINAL :"
                        echo "==================="
                        docker ps --format "table {{.Names}}\t{{.Ports}}"
                        echo ""
                        echo "Backend:  http://localhost:8000"
                        echo "Frontend: http://localhost:3000" 
                        echo "Prometheus: http://localhost:9090"
                        echo "Grafana: http://localhost:3030 (admin/admin)"
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout 2>/dev/null || true'
            echo "✅ Pipeline terminé"
        }
    }
}
