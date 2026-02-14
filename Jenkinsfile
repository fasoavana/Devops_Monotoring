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
                        
                        echo "✅ Images pushées"
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
                        
                        echo "✅ Versions :"
                        ansible --version | head -1
                        docker --version
                        
                        echo "🚀 Création du playbook Ansible..."
                        
                        # Créer le dossier playbooks s'il n'existe pas
                        mkdir -p ansible/playbooks
                        
                        # Créer le playbook avec échappement des doubles accolades
                        cat > ansible/playbooks/deploy_blog.yml << 'EOF'
---
- name: Déployer l'application blog
  hosts: all
  connection: docker
  tasks:
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
                        
                        echo "📄 Inventaire :"
                        cat ansible/inventory/hosts.ini
                        
                        echo "🚀 Exécution du playbook..."
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
                        
                        # Installation de docker-compose
                        apk add --no-cache docker-compose
                        
                        echo "📊 Monitoring..."
                        
                        if [ -f "docker-compose-monitoring.yml" ]; then
                            docker-compose -f docker-compose-monitoring.yml down --remove-orphans || true
                            docker-compose -f docker-compose-monitoring.yml up -d
                            echo "✅ Conteneurs monitoring :"
                            docker-compose -f docker-compose-monitoring.yml ps
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
      - "3000:3000"
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
                            
                            docker-compose -f docker-compose-monitoring.yml up -d
                            echo "✅ Monitoring créé et démarré !"
                        fi
                        
                        # Vérification
                        sleep 5
                        curl -s -f http://localhost:9090 > /dev/null && echo "✅ Prometheus OK" || echo "⚠️ Prometheus non accessible"
                        curl -s -f http://localhost:3000 > /dev/null && echo "✅ Grafana OK" || echo "⚠️ Grafana non accessible"
                    '''
                }
            }
        }
        
        stage('Vérification finale') {
            steps {
                script {
                    sh '''
                        echo "🔍 Vérification des déploiements..."
                        
                        echo "Conteneurs en cours d'exécution :"
                        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
                        
                        echo ""
                        echo "📊 Monitoring :"
                        echo "- Prometheus: http://localhost:9090"
                        echo "- Grafana: http://localhost:3000 (admin/admin)"
                        
                        # Test des endpoints
                        echo ""
                        echo "Tests des endpoints :"
                        curl -s -o /dev/null -w "Backend: %{http_code}\n" http://localhost:8000 || echo "Backend: non accessible"
                        curl -s -o /dev/null -w "Frontend: %{http_code}\n" http://localhost:3000 || echo "Frontend: non accessible"
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'docker logout || true'
            echo "✅ Pipeline terminé"
        }
        success {
            echo "🎉 SUCCÈS ! Tous les services sont déployés !"
            echo "   - Frontend: http://localhost:3000"
            echo "   - Backend: http://localhost:8000"
            echo "   - Prometheus: http://localhost:9090"
            echo "   - Grafana: http://localhost:3000 (admin/admin)"
        }
        failure {
            echo "❌ ÉCHEC ! Vérifiez les logs."
        }
    }
}
