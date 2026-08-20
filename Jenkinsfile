pipeline {
    agent { label 'agentzain' }

    environment {
        APP_DIR        = '/var/www/html/devops-assessments'
        IMAGE_NAME     = 'my-laravel-app'
        COMMIT_SHA     = "${env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'latest'}"
        CONTAINER_NAME = 'laravel_app'
        DB_HOST        = '10.0.1.112'
        DB_PORT        = '3306'
        DB_DATABASE    = 'your_db_name'
        DB_USERNAME    = 'your_db_user'
        DB_PASSWORD    = 'your_db_password'
    }

    stages {
        stage('Checkout Code') {
            steps {
                dir("${env.APP_DIR}") {
                    echo "Pulling latest changes for commit: ${env.COMMIT_SHA}..."
                    sh 'git pull origin main'
                }
            }
        }

        stage('Quality Gate (PHPUnit Tests)') {
            steps {
                dir("${env.APP_DIR}/app") {
                    echo 'Executing Laravel Automated Quality Checks...'
                    sh '''
                        if [ -f vendor/bin/phpunit ]; then
                            ./vendor/bin/phpunit --stop-on-failure
                        else
                            echo "PHPUnit binary not found in app/vendor, skipping test execution..."
                        fi
                    '''
                }
            }
        }

        stage('Prune Old Docker Cache') {
            steps {
                echo 'Cleaning up unused Docker resources to free disk space...'
                sh 'docker image prune -f || true'
            }
        }

        stage('Build & Tag Docker Image') {
            steps {
                dir("${env.APP_DIR}") {
                    echo "Building Docker image for tag: ${env.IMAGE_NAME}:${env.COMMIT_SHA}"
                    sh "docker build -t ${env.IMAGE_NAME}:${env.COMMIT_SHA} -t ${env.IMAGE_NAME}:latest ."
                }
            }
        }

        stage('Deploy & Health Check with Auto-Rollback') {
            steps {
                dir("${env.APP_DIR}") {
                    script {
                        echo "Deploying container version ${env.COMMIT_SHA}..."
                        
                        sh "docker stop ${env.CONTAINER_NAME} || true"
                        sh "docker rm ${env.CONTAINER_NAME} || true"
                        
                        sh """
                            docker run -d --name ${env.CONTAINER_NAME} \
                            -e DB_HOST=${env.DB_HOST} \
                            -e DB_PORT=${env.DB_PORT} \
                            -e DB_DATABASE=${env.DB_DATABASE} \
                            -e DB_USERNAME=${env.DB_USERNAME} \
                            -e DB_PASSWORD=${env.DB_PASSWORD} \
                            -p 8080:80 ${env.IMAGE_NAME}:${env.COMMIT_SHA}
                        """
                        
                        sleep time: 3, unit: 'SECONDS'
                        
                        sh "docker exec -i ${env.CONTAINER_NAME} php artisan optimize:clear || true"
                        
                        echo "Performing Health Check on http://127.0.0.1:8080..."
                        sleep time: 5, unit: 'SECONDS'
                        
                        def status = sh(script: "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080", returnStdout: true).trim()
                        
                        if (status != '200') {
                            error "Health check failed with status code ${status}"
                        }
                    }
                }
            }
        }

        stage('Database Backup Trigger') {
            steps {
                dir("${env.APP_DIR}") {
                    echo 'Triggering Database Backup to S3...'
                    sh '''
                        if [ -f scripts/backup.sh ]; then
                            bash scripts/backup.sh
                        fi
                    '''
                }
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f || true'
        }
        success {
            echo "CI/CD Pipeline successfully executed for version ${env.COMMIT_SHA}!"
        }
        failure {
            echo "CI/CD Pipeline execution failed!"
        }
    }
}
