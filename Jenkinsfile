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
                        
                        # Backend
                        if [ -d "apps/backend" ]; then
                            docker build -t faso01/blog-backend:latest apps/backend
                            docker push faso01/blog-backend:latest
                        fi
                        
                        # Frontend
                        if [ -d "apps/frontend" ]; then
                            docker build -t faso01/blog-frontend:latest apps/frontend
                            docker push faso01/blog-frontend:latest
                        fi
                        
                        echo "✅ Images pushées"
                    '''
                }
            }
        }

        stage('Déploiement avec Ansible') {
            agent {
                docker {
                    // Cette image contient Ansible ET Docker
                    image 'williamyeh/ansible:alpine3'
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
                        
                        # Vérification des outils
                        echo "Ansible version:"
                        ansible --version | head -1
                        
                        echo "Docker version:"
                        docker --version
                        
                        # Vérification de l'inventaire
                        if [ -f "ansible/inventory/hosts.ini" ]; then
                            echo "📄 Inventaire trouvé :"
                            cat ansible/inventory/hosts.ini
                            
                            # Ping des hôtes
                            ansible all -i ansible/inventory/hosts.ini -m ping
                            
                            # Déploiement
                            ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy_blog.yml
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
