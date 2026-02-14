pipeline {
    agent any

    environment {
        DOCKER_CREDS = credentials('docker-hub-creds')
        ANSIBLE_HOST_KEY_CHECKING = "False"
        // Ajout pour éviter les problèmes de tmp
        ANSIBLE_REMOTE_TMP = "/tmp/ansible-${BUILD_TAG}"
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

        stage('Vérification conteneur DIND') {
            steps {
                script {
                    sh '''
                        echo "🔍 Vérification du conteneur Docker-in-Docker..."
                        
                        # Vérifier si le conteneur existe et est en cours d'exécution
                        if ! docker ps --format '{{.Names}}' | grep -q "blog-server-simule"; then
                            echo "❌ Conteneur blog-server-simule non trouvé !"
                            echo "Création du conteneur Docker-in-Docker..."
                            
                            # Supprimer l'ancien s'il existe mais est arrêté
                            docker rm -f blog-server-simule 2>/dev/null || true
                            
                            # Créer un nouveau conteneur DIND
                            docker run -d \
                                --privileged \
                                --name blog-server-simule \
                                -p 2375:2375 \
                                docker:dind
                            
                            echo "✅ Conteneur blog-server-simule créé"
                            
                            # Attendre que Docker démarre dans le conteneur
                            echo "Attente du démarrage de Docker dans le conteneur..."
                            sleep 10
                        else
                            echo "✅ Conteneur blog-server-simule trouvé"
                        fi
                        
                        docker ps | grep blog-server-simule
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
                        
                        # Version améliorée du playbook
                        cat > ansible/playbooks/deploy_blog.yml << 'EOF'
---
- name: Déployer l'application blog
  hosts: all
  connection: docker
  vars:
    ansible_remote_tmp: /tmp/ansible-${BUILD_TAG}
  tasks:
    - name: Créer le répertoire tmp avec les bons droits
      shell: |
        mkdir -p /tmp/ansible && chmod 777 /tmp/ansible
      ignore_errors: yes
    
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
                        
                        # Télécharger docker-compose
                        if ! command -v docker-compose &> /dev/null && [ ! -f "/tmp/docker-compose" ]; then
                            echo "Téléchargement de docker-compose..."
                            curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /tmp/docker-compose
                            chmod +x /tmp/docker-compose
                        fi
                        
                        DOCKER_COMPOSE_CMD="docker-compose"
                        [ -f "/tmp/docker-compose" ] && DOCKER_COMPOSE_CMD="/tmp/docker-compose"
                        
                        echo "📊 Configuration du monitoring..."
                        
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
  
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF
                        fi
                        
                        echo "🚀 Démarrage des services monitoring..."
                        $DOCKER_COMPOSE_CMD -f docker-compose-monitoring.yml down --remove-orphans 2>/dev/null || true
                        $DOCKER_COMPOSE_CMD -f docker-compose-monitoring.yml up -d
                        
                        echo "✅ Conteneurs monitoring :"
                        $DOCKER_COMPOSE_CMD -f docker-compose-monitoring.yml ps
                        
                        sleep 10
                        
                        echo ""
                        echo "📊 Vérification des endpoints :"
                        curl -s -f http://localhost:9090 > /dev/null && echo "✅ Prometheus OK (9090)" || echo "⚠️ Prometheus non accessible"
                        curl -s -f http://localhost:3030 > /dev/null && echo "✅ Grafana OK (3030)" || echo "⚠️ Grafana non accessible"
                    '''
                }
            }
        }
        
        stage('Vérification finale') {
            steps {
                script {
                    sh '''
                        echo "🔍 Vérification finale..."
                        echo ""
                        
                        echo "📋 Tous les conteneurs :"
                        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
                        
                        echo ""
                        echo "🌐 Endpoints :"
                        echo "   Backend:  http://localhost:8000"
                        echo "   Frontend: http://localhost:3000"
                        echo "   Prometheus: http://localhost:9090"
                        echo "   Grafana: http://localhost:3030 (admin/admin)"
                        
                        echo ""
                        echo "🎉 Déploiement terminé !"
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
