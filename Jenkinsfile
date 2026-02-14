pipeline {
    agent any

    environment {
        DOCKER_CREDS = credentials('docker-hub-creds')
        // Évite les prompts SSH pour Ansible
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
                        
                        # Vérification et build backend
                        if [ -d "apps/backend" ]; then
                            echo "Build backend..."
                            docker build -t faso01/blog-backend:latest apps/backend
                            docker push faso01/blog-backend:latest
                        else
                            error "Dossier apps/backend non trouvé !"
                        fi
                        
                        # Vérification et build frontend
                        if [ -d "apps/frontend" ]; then
                            echo "Build frontend..."
                            docker build -t faso01/blog-frontend:latest apps/frontend
                            docker push faso01/blog-frontend:latest
                        else
                            error "Dossier apps/frontend non trouvé !"
                        fi
                        
                        echo "✅ Images buildées et pushées avec succès"
                    '''
                }
            }
        }

        stage('Déploiement avec Ansible') {
            agent {
                docker {
                    image 'cytopia/ansible:latest-tools'
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
                        echo "🚀 Déploiement avec Ansible..."
                        
                        # Vérification de l'inventaire
                        if [ ! -f "ansible/inventory/hosts.ini" ]; then
                            echo "❌ Inventaire non trouvé !"
                            echo "Contenu du dossier ansible :"
                            ls -la ansible/
                            exit 1
                        fi
                        
                        # Test de connexion aux hôtes
                        echo "Test de connexion aux hôtes..."
                        ansible all -i ansible/inventory/hosts.ini -m ping
                        
                        # Vérification du playbook
                        if [ ! -f "ansible/playbooks/deploy_blog.yml" ]; then
                            echo "❌ Playbook non trouvé !"
                            exit 1
                        fi
                        
                        # Déploiement avec variables Docker
                        echo "Lancement du playbook de déploiement..."
                        ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy_blog.yml \
                            --extra-vars "docker_user=${DOCKER_CREDS_USR} docker_pass=${DOCKER_CREDS_PSW}"
                    '''
                }
            }
        }

        stage('Lancement Monitoring') {
            steps {
                script {
                    sh '''
                        echo "📊 Configuration du monitoring..."
                        
                        # Vérification du fichier docker-compose
                        if [ ! -f "docker-compose-monitoring.yml" ]; then
                            echo "❌ Fichier docker-compose-monitoring.yml non trouvé !"
                            exit 1
                        fi
                        
                        # Arrêt des anciens conteneurs (si existants)
                        docker-compose -f docker-compose-monitoring.yml down --remove-orphans || true
                        
                        # Démarrage du monitoring
                        docker-compose -f docker-compose-monitoring.yml up -d
                        
                        # Attente du démarrage
                        echo "Attente du démarrage des services..."
                        sleep 10
                        
                        # Vérification des services
                        echo "✅ Services monitoring :"
                        docker-compose -f docker-compose-monitoring.yml ps
                        
                        # Test des endpoints
                        echo "Test des endpoints :"
                        curl -s -f http://localhost:9090 > /dev/null && echo "✅ Prometheus OK" || echo "⚠️ Prometheus non accessible"
                        curl -s -f http://localhost:3000 > /dev/null && echo "✅ Grafana OK" || echo "⚠️ Grafana non accessible"
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
            }
            echo "✅ Pipeline terminé"
        }
        success {
            echo "🎉 SUCCÈS ! L'application est déployée !"
            echo "   - Frontend: http://localhost:3000"
            echo "   - Backend: http://localhost:8000"
            echo "   - Prometheus: http://localhost:9090"
            echo "   - Grafana: http://localhost:3000 (admin/admin)"
        }
        failure {
            echo "❌ ÉCHEC ! Vérifiez les logs ci-dessus."
        }
    }
}
