pipeline {
    agent {
        node {
            label ''
            // On force l'exécution du pipeline en tant que ROOT sur le noeud
            customWorkspace "/var/jenkins_home/workspace/${JOB_NAME}"
        }
    }

    environment {
        DOCKER_CREDS = credentials('docker-hub-creds')
    }

    stages {
        stage('Install Ansible (Root Escalation)') {
            steps {
                // On utilise le flag -u 0 pour s'assurer d'être root si l'agent le permet
                // Sinon, on exécute simplement l'installation
                sh """
                    apt-get update && apt-get install -y ansible
                    ansible --version
                """
            }
        }

        stage('Build & Push Blog') {
            steps {
                script {
                    sh 'echo ${DOCKER_CREDS_PSW} | docker login -u ${DOCKER_CREDS_USR} --password-stdin'
                    sh "docker build -t faso01/blog-backend:latest apps/backend"
                    sh "docker build -t faso01/blog-frontend:latest apps/frontend"
                    sh "docker push faso01/blog-backend:latest"
                    sh "docker push faso01/blog-frontend:latest"
                }
            }
        }

        stage('Deploy App with Ansible') {
            steps {
                // Ici, Ansible est déjà installé dans le système du conteneur Jenkins
                sh "ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy_blog.yml"
            }
        }

        stage('Monitoring Setup') {
            steps {
                sh "docker-compose -f docker-compose-monitoring.yml up -d"
            }
        }
    }
}
