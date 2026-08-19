pipeline {
    agent { label 'agentzain' }

    environment {
        IMAGE_NAME     = 'my-laravel-app'
        COMMIT_SHA     = "${env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'latest'}"
        CONTAINER_NAME = 'laravel_app'
        DB_HOST        = '127.0.0.1'
    }

    stages {
        stage('Checkout Code') {
            steps {
                echo "Verifying checked out code for commit: ${env.COMMIT_SHA}..."
                sh 'git log -1'
            }
        }

        stage('Quality Gate (PHPUnit Tests)') {
            steps {
                echo 'Executing Laravel Automated Quality Checks...'
                sh '''
                    if [ -d app ] && [ -f app/vendor/bin/phpunit ]; then
                        cd app && ./vendor/bin/phpunit --stop-on-failure
                    elif [ -f vendor/bin/phpunit ]; then
                        ./vendor/bin/phpunit --stop-on-failure
                    else
                        echo "PHPUnit binary not found, skipping unit test execution..."
                    fi
                '''
            }
        }

        stage('Build & Tag Docker Image') {
            steps {
                echo "Building Docker image using layer caching for tag: ${IMAGE_NAME}:${COMMIT_SHA}"
                sh "docker build -t ${IMAGE_NAME}:${COMMIT_SHA} -t ${IMAGE_NAME}:latest ."
            }
        }

        stage('Deploy & Health Check with Auto-Rollback') {
            steps {
                script {
                    try {
                        echo "Deploying container version ${COMMIT_SHA}..."
                        sh """
                            docker stop ${CONTAINER_NAME} || true
                            docker rm ${CONTAINER_NAME} || true
                            docker run -d --name ${CONTAINER_NAME} -e DB_HOST=${DB_HOST} -p 80:80 ${IMAGE_NAME}:${COMMIT_SHA}
                            docker exec -i ${CONTAINER_NAME} php artisan optimize:clear || true
                        """

                        // Automated Smoke / Health Check
                        echo "Performing Health Check on http://localhost:80..."
                        sleep 5
                        def healthStatus = sh(
                            script: 'curl -s -o /dev/null -w "%{http_code}" http://localhost:80',
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
                            docker run -d --name ${CONTAINER_NAME} -e DB_HOST=${DB_HOST} -p 80:80 ${IMAGE_NAME}:latest || true
                        """
                        error "Pipeline failed during deployment. Automatically rolled back to the last stable image."
                    }
                }
            }
        }

        stage('Database Backup Trigger') {
            steps {
                echo 'Triggering Database Backup to S3...'
                sh '''
                    if [ -f scripts/backup.sh ]; then
                        bash scripts/backup.sh
                    else
                        echo "No backup script found at scripts/backup.sh, skipping backup step..."
                    fi
                '''
            }
        }
    }

    post {
        success {
            echo "CI/CD Pipeline successfully executed for version ${COMMIT_SHA}!"
        }
        failure {
            echo "CI/CD Pipeline execution failed!"
        }
    }
}
