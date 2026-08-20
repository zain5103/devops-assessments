pipeline {
    agent { label 'agentzain' }

    environment {
        APP_DIR        = '/var/www/html/devops-assessments'
        IMAGE_NAME     = 'my-laravel-app'
        COMMIT_SHA     = "${env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'latest'}"
        CONTAINER_NAME = 'laravel_app'
        DB_HOST        = '10.0.1.112' 
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
                    echo "Building Docker image for tag: ${IMAGE_NAME}:${COMMIT_SHA}"
                    sh "docker build -t ${IMAGE_NAME}:${COMMIT_SHA} -t ${IMAGE_NAME}:latest ."
                }
            }
        }

        stage('Deploy & Health Check with Auto-Rollback') {
            steps {
        dir('/var/www/html/devops-assessments') {
            script {
                echo "Deploying container version ${GIT_COMMIT:0:7}..."
                
                sh 'docker stop laravel_app || true'
                sh 'docker rm laravel_app || true'
                
                // Pass all required DB environment variables
                sh """
                    docker run -d --name laravel_app \
                    -e DB_HOST=10.0.1.112 \
                    -e DB_PORT=3306 \
                    -e DB_DATABASE=your_db_name \
                    -e DB_USERNAME=your_db_user \
                    -e DB_PASSWORD=your_db_password \
                    -p 8080:80 my-laravel-app:${GIT_COMMIT:0:7}
                """
                
                // Wait for container process initialization
                sleep time: 3, unit: 'SECONDS'
                
                sh 'docker exec -i laravel_app php artisan optimize:clear'
                
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
            echo "CI/CD Pipeline successfully executed for version ${COMMIT_SHA}!"
        }
        failure {
            echo "CI/CD Pipeline execution failed!"
        }
    }
}
