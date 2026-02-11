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
                    // Login
                    sh "echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin"
                    
                    // Build & Push Backend
                    sh "docker build -t faso01/blog-backend:latest apps/backend"
                    sh "docker push faso01/blog-backend:latest"
                    
                    // Build & Push Frontend
                    sh "docker build -t faso01/blog-frontend:latest apps/frontend"
                    sh "docker push faso01/blog-frontend:latest"
                }
            }
        }

        stage('Deploy with Ansible') {
            steps {
                sh "ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy_dind.yml"
            }
        }
    }
}
