pipeline {
    // On définit l'agent Docker au niveau global pour tout le pipeline
    agent {
        docker {
            image 'appleboy/drone-ansible:latest' // Cette image contient Ansible et Docker CLI
            args '-u root -v /var/run/docker.sock:/var/run/docker.sock' 
        }
    }

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
            steps {
                // Ansible est déjà installé dans l'image de l'agent
                sh "ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy_blog.yml"
            }
        }

        stage('Launch Monitoring Stack') {
            steps {
                // Docker-compose est aussi disponible ou simulable via docker
                sh "docker-compose -f docker-compose-monitoring.yml up -d"
            }
        }
    }
}
