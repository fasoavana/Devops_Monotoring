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
            steps {
                echo 'Exécution d’Ansible via un conteneur éphémère...'
                // On utilise une image Ansible officielle et légère
                // On monte le dossier courant (${WORKSPACE}) pour qu'Ansible voit tes fichiers
                sh """
                docker run --rm \
                    -v ${WORKSPACE}:/work \
                    -w /work \
                    williamyeh/ansible:alpine-light \
                    ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/deploy_blog.yml
                """
            }
        }

        stage('Launch Monitoring Stack') {
            steps {
                echo 'Démarrage du monitoring...'
                sh "docker-compose -f docker-compose-monitoring.yml up -d"
            }
        }
    }
}
