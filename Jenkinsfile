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

        stage('Install Tools') {
            steps {
                // On installe Ansible pour le déploiement
                sh "apt-get update && apt-get install -y ansible"
            }
        }

        stage('Deploy App with Ansible') {
            steps {
                // Déploiement du Backend/Frontend sur le serveur simulé
                sh "ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy_blog.yml"
            }
        }

        stage('Launch Monitoring Stack') {
            steps {
                echo 'Lancement de Prometheus et Grafana...'
                // Utilisation du fichier compose présent à la racine de ton repo
                sh "docker-compose -f docker-compose-monitoring.yml up -d"
            }
        }
    }
}
