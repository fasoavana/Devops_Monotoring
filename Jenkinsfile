pipeline {
    agent any

    environment {
        DOCKER_CREDS = credentials('docker-hub-creds')
    }

    stages {
        stage('Build & Push Blog') {
            steps {
                script {
                    // Utilisation de guillemets simples pour la sécurité
                    // On tente un login avec un petit timeout de sécurité
                    sh 'echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin'
                    
                    // Build des images
                    sh "docker build -t faso01/blog-backend:latest apps/backend"
                    sh "docker build -t faso01/blog-frontend:latest apps/frontend"
                    
                    // Push vers Docker Hub
                    sh "docker push faso01/blog-backend:latest"
                    sh "docker push faso01/blog-frontend:latest"
                }
            }
        }

        stage('Deploy App with Ansible') {
            steps {
                echo 'Déploiement via Ansible (Conteneur éphémère)...'
                // On monte le socket docker pour qu'Ansible puisse piloter le serveur simulé
                sh """
                docker run --rm \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    -v ${WORKSPACE}:/work \
                    -w /work \
                    williamyeh/ansible:alpine-light \
                    ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy_blog.yml
                """
            }
        }

        stage('Monitoring Setup') {
            steps {
                echo 'Lancement de la stack Prometheus/Grafana...'
                sh "docker-compose -f docker-compose-monitoring.yml up -d"
            }
        }
    }

    post {
        always {
            echo 'Nettoyage des credentials...'
            sh "docker logout"
        }
        success {
            echo 'Félicitations ! Pipeline Devops_Monitoring terminé avec succès.'
        }
    }
}
