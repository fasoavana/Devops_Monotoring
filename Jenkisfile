pipeline {
    agent any

    environment {
        DOCKER_USER = 'faso01'
        BACKEND_IMAGE = "faso01/blog-backend:latest"
        FRONTEND_IMAGE = "faso01/blog-frontend:latest"
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
                    docker.withRegistry('', 'docker-hub-creds') {
                        // Build et Push Backend
                        def backend = docker.build("${env.BACKEND_IMAGE}", "./apps/backend")
                        backend.push()
                        
                        // Build et Push Frontend
                        def frontend = docker.build("${env.FRONTEND_IMAGE}", "./apps/frontend")
                        frontend.push()
                    }
                }
            }
        }

        stage('Deploy with Ansible') {
            steps {
                // On lance Ansible directement depuis le node Jenkins
                // Note : Jenkins doit avoir accès au binaire 'ansible-playbook'
                sh "ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy_dind.yml"
            }
        }
    }
}
