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
                    // Image avec Docker pré-installé
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
                        
                        # Mise à jour et installation
                        apk add --no-cache ansible py3-pip
                        
                        # Vérification
                        echo "✅ Versions installées :"
                        ansible --version | head -1
                        docker --version
                        
                        # Déploiement
                        echo "🚀 Déploiement avec Ansible..."
                        
                        if [ -f "ansible/inventory/hosts.ini" ]; then
                            echo "📄 Inventaire trouvé :"
                            cat ansible/inventory/hosts.ini
                            
                            # Ping des hôtes
                            ansible all -i ansible/inventory/hosts.ini -m ping || true
                            
                            # Déploiement
                            ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy_blog.yml || true
                        else
                            echo "❌ Inventaire non trouvé !"
                            exit 1
                        fi
                    '''
                }
            }
        }

        stage('Lancement Monitoring') {
            steps {
                script {
                    sh '''
                        echo "📊 Monitoring..."
                        
                        if [ -f "docker-compose-monitoring.yml" ]; then
                            docker-compose -f docker-compose-monitoring.yml down --remove-orphans || true
                            docker-compose -f docker-compose-monitoring.yml up -d
                            docker-compose -f docker-compose-monitoring.yml ps
                        else
                            echo "❌ docker-compose-monitoring.yml non trouvé"
                        fi
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
        failure {
            echo "❌ ÉCHEC ! Vérifiez les logs."
        }
    }
}
