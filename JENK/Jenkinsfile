pipeline {
    agent any
    stages {
        stage('Deploy Hotel Application') {
            steps {
                script {
                    dir('/home/ubuntu/Music/local_deploy') {
                        sh 'rm -rf *'
                        sh 'git clone https://github.com/AnasMahmoud007/3_tier_Hotel_App'
                    }
                    dir('/home/ubuntu/Music/local_deploy/3_tier_Hotel_App') {
                        sh 'chmod +x ./run_hotel_project.sh'
                        sh './run_hotel_project.sh'
                    }
                }
            }
        }
    }
}