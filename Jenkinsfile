pipeline {
    agent any

    environment {
        DOCKER_CREDS = credentials('docker-hub-creds')
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Build & Push Images') {
            steps {
                script {
                    // Login sécurisé (utilisation de guillemets simples pour éviter l'interpolation Groovy non sécurisée)
                    sh 'echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin'
                    
                    // Build & Push Backend
                    sh "docker build -t faso01/blog-backend:latest apps/backend"
                    sh "docker push faso01/blog-backend:latest"
                    
                    // Build & Push Frontend
                    sh "docker build -t faso01/blog-frontend:latest apps/frontend"
                    sh "docker push faso01/blog-frontend:latest"
                }
            }
        }

        stage('Install Ansible') {
            steps {
                echo 'Installation d’Ansible dans l’agent...'
                // On met à jour et on installe Ansible. Le "|| true" évite de bloquer si déjà installé.
                sh "apt-get update && apt-get install -y ansible"
            }
        }

        stage('Deploy with Ansible') {
            steps {
                // Exécution du playbook
                sh "ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy_dind.yml"
            }
        }
    }
}
