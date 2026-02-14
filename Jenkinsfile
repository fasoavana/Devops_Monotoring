pipeline {
    agent any

    environment {
        DOCKER_CREDS = credentials('docker-hub-creds')
        ANSIBLE_HOST_KEY_CHECKING = "False"
        // On force le PATH pour trouver Ansible installé par pip
        PATH = "${env.HOME}/.local/bin:${env.PATH}"
    }

    stages {
        stage('Installation d\'Ansible') {
            steps {
                script {
                    sh '''
                        echo "🔧 Installation d'Ansible via Pip (Mode utilisateur)..."
                        # On installe sans root
                        python3 -m pip install --user --upgrade pip
                        python3 -m pip install --user ansible
                        
                        echo "✅ Version installée :"
                        ansible --version | head -1
                    '''
                }
            }
        }

        stage('Build & Push Docker Hub') {
            steps {
                script {
                    sh '''
                        echo "🔑 Login Docker Hub..."
                        echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin
                        
                        echo "🏗️ Building Images..."
                        # Build Backend
                        docker build -t faso01/blog-backend:latest apps/backend
                        docker push faso01/blog-backend:latest
                        
                        # Build Frontend
                        docker build -t faso01/blog-frontend:latest apps/frontend
                        docker push faso01/blog-frontend:latest
                    '''
                }
            }
        }

        stage('Déploiement Ansible') {
            steps {
                script {
                    sh '''
                        echo "🚀 Lancement du déploiement..."
                        
                        # On s'assure que l'inventaire pointe sur localhost pour un déploiement local
                        # ou sur l'IP de ta machine cible.
                        ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy_blog.yml
                    '''
                }
            }
        }

        stage('Stack Monitoring') {
            steps {
                script {
                    sh '''
                        echo "📊 Démarrage Prometheus & Grafana..."
                        # On utilise -d pour lancer en arrière-plan
                        docker-compose -f docker-compose-monitoring.yml up -d
                        
                        echo "✨ État des services :"
                        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "🎉 Pipeline Réussi !"
            echo "Frontend : http://localhost:8080"
            echo "Backend  : http://localhost:8000"
            echo "Grafana  : http://localhost:3000"
        }
        always {
            sh 'docker logout || true'
        }
    }
}
