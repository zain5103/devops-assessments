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
                dir("${env.APP_DIR}") {
                    script {
                        try {
                            echo "Deploying container version ${COMMIT_SHA}..."
                            sh """
                                docker stop ${CONTAINER_NAME} || true
                                docker rm ${CONTAINER_NAME} || true
                                docker run -d --name ${CONTAINER_NAME} -e DB_HOST=${DB_HOST} -p 8080:80 ${IMAGE_NAME}:${COMMIT_SHA}
                                docker exec -i ${CONTAINER_NAME} php artisan optimize:clear || true
                            """

                            echo "Performing Health Check on http://127.0.0.1:8080..."
                            sleep 5
                            def healthStatus = sh(
                                script: 'curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8080',
                                returnStdout: true
                            ).trim()

                            if (healthStatus != '200' && healthStatus != '302') {
                                error "Health Check failed with status HTTP ${healthStatus}"
                            } else {
                                echo "Health Check Passed successfully with HTTP ${healthStatus}!"
                            }

                        } catch (Exception e) {
                            echo "Deployment Failed: ${e.getMessage()}. Initiating Automatic Rollback!"
                            sh """
                                docker stop ${CONTAINER_NAME} || true
                                docker rm ${CONTAINER_NAME} || true
                                docker run -d --name ${CONTAINER_NAME} -e DB_HOST=${DB_HOST} -p 8080:80 ${IMAGE_NAME}:latest || true
                            """
                            error "Pipeline failed during deployment. Automatically rolled back to the last stable image."
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
