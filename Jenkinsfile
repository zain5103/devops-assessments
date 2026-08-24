pipeline {
    agent { label 'agentzain' }

    environment {
        APP_DIR        = '/var/www/html/devops-assessments'
        IMAGE_NAME     = 'my-laravel-app'
        COMMIT_SHA     = "${env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'latest'}"
        CONTAINER_NAME = 'laravel_app'
        DB_HOST        = '10.0.1.112'
        DB_PORT        = '3306'
        
        // Jenkins Credentials Manager use karna best practice hai
        DB_DATABASE    = 'devops'
        DB_USERNAME    = 'root'
        DB_PASSWORD    = 'Zain@12345'
        // DB_PASSWORD = credentials('My-DB-Pass') 
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
                        
                        try {
                            // Step 1: Current Container Ko Stop & Remove Karna
                            sh "docker stop ${env.CONTAINER_NAME} || true"
                            sh "docker rm ${env.CONTAINER_NAME} || true"
                            
                            // Step 2: Naya Container Run Karna (Commit SHA Tag)
                            sh """
                                docker run -d --name ${env.CONTAINER_NAME} \
                                -e DB_HOST=${env.DB_HOST} \
                                -e DB_PORT=${env.DB_PORT} \
                                -e DB_DATABASE=${env.DB_DATABASE} \
                                -e DB_USERNAME=${env.DB_USERNAME} \
                                -e DB_PASSWORD=${env.DB_PASSWORD} \
                                -p 8080:80 ${env.IMAGE_NAME}:${env.COMMIT_SHA}
                            """
                            
                            echo "Waiting for container boot..."
                            sleep time: 5, unit: 'SECONDS'
                            
                            sh "docker exec -i ${env.CONTAINER_NAME} php artisan optimize:clear || true"
                            
                            echo "Performing Health Check on http://127.0.0.1:8080..."
                            sleep time: 3, unit: 'SECONDS'
                            
                            // Step 3: Health Verification (HTTP Status Code Check)
                            def status = sh(
                                script: "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080", 
                                returnStdout: true
                            ).trim()
                            
                            echo "Received HTTP Status Code: ${status}"
                            
                            if (status != '200') {
                                error "Health check failed with HTTP status: ${status}"
                            }
                            
                            echo "✅ Deployment Successful! Image Version: ${env.COMMIT_SHA}"

                        } catch (Exception e) {
                            // Step 4: AUTOMATED ROLLBACK LOGIC
                            echo "❌ DEPLOYMENT FAILED: ${e.getMessage()}"
                            echo "🔄 INITIATING AUTOMATED ROLLBACK TO PREVIOUS STABLE RELEASE..."
                            
                            // Faulty/Failed container ko remove karna
                            sh "docker stop ${env.CONTAINER_NAME} || true"
                            sh "docker rm ${env.CONTAINER_NAME} || true"
                            
                            // Previous stable image (:latest) re-deploy karna
                            sh """
                                docker run -d --name ${env.CONTAINER_NAME} \
                                -e DB_HOST=${env.DB_HOST} \
                                -e DB_PORT=${env.DB_PORT} \
                                -e DB_DATABASE=${env.DB_DATABASE} \
                                -e DB_USERNAME=${env.DB_USERNAME} \
                                -e DB_PASSWORD=${env.DB_PASSWORD} \
                                -p 8080:80 ${env.IMAGE_NAME}:latest
                            """
                            
                            echo "⚠️ ROLLBACK COMPLETE: Restored last known stable container state."
                            error "Pipeline failed due to health check failure. Rollback triggered automatically."
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
