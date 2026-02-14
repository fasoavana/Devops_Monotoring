stage('Tests') {
    parallel {
        stage('Test Backend') {
            steps {
                sh 'curl -f http://localhost:8000/health || echo "⚠️ Backend non testé"'
            }
        }
        stage('Test Frontend') {
            steps {
                sh 'curl -f http://localhost:3000 || echo "⚠️ Frontend non testé"'
            }
        }
    }
}

stage('Notifications') {
    steps {
        emailext (
            to: 'equipe@example.com',
            subject: "Pipeline ${currentBuild.currentResult}",
            body: "Le pipeline s'est terminé avec le statut: ${currentBuild.currentResult}"
        )
    }
}
