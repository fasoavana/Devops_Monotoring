pipeline {
    agent any 
    
    environment {
        DOCKER_CREDS = credentials('docker-hub-creds')
    }

    stages {
        stage('Build & Push Blog') {
            steps {
                script {
                    sh 'echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin'
                    sh "docker build -t faso01/blog-backend:latest apps/backend"
                    sh "docker push faso01/blog-backend:latest"
                }
            }
        }

        stage('Deploy App with Ansible') {
            agent {
                // On utilise une image qui a déjà Ansible installé !
                docker { image 'chilio/ansible:latest' } 
            }
            steps {
                // Ici, plus besoin d'apt-get install, ansible-playbook est déjà là
                sh "ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy_blog.yml"
            }
        }

        stage('Launch Monitoring Stack') {
            steps {
                // Retour sur l'agent principal pour lancer le compose
                sh "docker-compose -f docker-compose-monitoring.yml up -d"
            }
        }
    }
}
