pipeline {

    agent {
        label 'agentzain'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAME          = 'my-laravel-app'
        CONTAINER_NAME      = 'laravel_app'
        APP_PORT            = '80'
        HEALTH_URL          = 'http://localhost/health'
        STABLE_TAG_FILE     = '/opt/jenkins-deploy/last_stable_image'
    }

    stages {

        // ====================================================
        // 1. CHECKOUT
        // ====================================================
        stage('Checkout Code') {
            steps {
                checkout scm

                script {
                    env.COMMIT_SHA = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()

                    echo "Building commit: ${env.COMMIT_SHA}"
                }
            }
        }


        // ====================================================
        // 2. INSTALL TEST DEPENDENCIES
        // ====================================================
        stage('Install Test Dependencies') {
            steps {
                echo 'Installing Composer dependencies for testing...'

                sh '''
                    docker run --rm \
                        -v "$WORKSPACE/app:/app" \
                        -w /app \
                        composer:2 \
                        composer install \
                            --no-interaction \
                            --prefer-dist
                '''
            }
        }


        // ====================================================
        // 3. QUALITY GATE - LARAVEL TESTS
        // ====================================================
        stage('Run Laravel Tests') {
            steps {
                echo 'Running Laravel automated tests...'

                sh '''
                    cd app

                    if [ ! -f artisan ]; then
                        echo "ERROR: Laravel artisan file not found."
                        exit 1
                    fi

                    if [ -f vendor/bin/phpunit ]; then
                        php artisan test --stop-on-failure
                    elif [ -f vendor/bin/pest ]; then
                        php artisan test
                    else
                        echo "ERROR: No PHPUnit or Pest test framework found."
                        exit 1
                    fi
                '''
            }
        }


        // ====================================================
        // 4. DEPENDENCY SECURITY SCAN
        // ====================================================
        stage('Composer Security Audit') {
            steps {
                echo 'Running Composer dependency security audit...'

                sh '''
                    docker run --rm \
                        -v "$WORKSPACE/app:/app" \
                        -w /app \
                        composer:2 \
                        composer audit
                '''
            }
        }


        // ====================================================
        // 5. BUILD IMAGE
        // ====================================================
        stage('Build Docker Image') {
            steps {
                echo "Building image with immutable tag: ${COMMIT_SHA}"

                sh '''
                    docker build \
                        -t ${IMAGE_NAME}:${COMMIT_SHA} \
                        .
                '''
            }
        }


        // ====================================================
        // 6. CONTAINER IMAGE SECURITY SCAN
        // ====================================================
        stage('Trivy Image Scan') {
            steps {
                echo 'Scanning Docker image for vulnerabilities...'

                sh '''
                    if ! command -v trivy >/dev/null 2>&1; then
                        echo "ERROR: Trivy is not installed on Jenkins Agent."
                        exit 1
                    fi

                    trivy image \
                        --exit-code 1 \
                        --severity HIGH,CRITICAL \
                        --ignore-unfixed \
                        ${IMAGE_NAME}:${COMMIT_SHA}
                '''
            }
        }


        // ====================================================
        // 7. SAVE PREVIOUS STABLE VERSION
        // ====================================================
        stage('Prepare Deployment') {
            steps {
                echo 'Saving current stable version for rollback...'

                sh '''
                    mkdir -p "$(dirname ${STABLE_TAG_FILE})"

                    if [ -f ${STABLE_TAG_FILE} ]; then
                        echo "Previous stable image:"
                        cat ${STABLE_TAG_FILE}
                    else
                        echo "No previous stable image recorded."
                    fi
                '''
            }
        }


        // ====================================================
        // 8. DEPLOY NEW VERSION
        // ====================================================
        stage('Deploy New Version') {
            steps {
                echo "Deploying ${IMAGE_NAME}:${COMMIT_SHA}"

                sh '''
                    docker stop ${CONTAINER_NAME} 2>/dev/null || true
                    docker rm ${CONTAINER_NAME} 2>/dev/null || true

                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        --restart unless-stopped \
                        -p ${APP_PORT}:80 \
                        ${IMAGE_NAME}:${COMMIT_SHA}
                '''
            }
        }


        // ====================================================
        // 9. CONTAINER HEALTH CHECK
        // ====================================================
        stage('Container Health Check') {
            steps {
                echo 'Waiting for Docker container to become healthy...'

                sh '''
                    for i in $(seq 1 12); do

                        STATUS=$(docker inspect \
                            --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
                            ${CONTAINER_NAME})

                        echo "Health status: $STATUS"

                        if [ "$STATUS" = "healthy" ]; then
                            exit 0
                        fi

                        if [ "$STATUS" = "unhealthy" ] || [ "$STATUS" = "exited" ]; then
                            docker logs ${CONTAINER_NAME} || true
                            exit 1
                        fi

                        sleep 5
                    done

                    echo "Container did not become healthy."
                    docker logs ${CONTAINER_NAME} || true
                    exit 1
                '''
            }
        }


        // ====================================================
        // 10. APPLICATION SMOKE TEST
        // ====================================================
        stage('Application Smoke Test') {
            steps {
                echo "Testing ${HEALTH_URL}"

                sh '''
                    HTTP_CODE=$(curl \
                        --silent \
                        --show-error \
                        --output /dev/null \
                        --write-out "%{http_code}" \
                        ${HEALTH_URL})

                    echo "Application returned HTTP $HTTP_CODE"

                    if [ "$HTTP_CODE" != "200" ]; then
                        echo "ERROR: Application health check failed."
                        exit 1
                    fi
                '''
            }
        }


        // ====================================================
        // 11. MARK VERSION AS STABLE
        // ====================================================
        stage('Mark Release Stable') {
            steps {
                echo "Marking ${IMAGE_NAME}:${COMMIT_SHA} as stable..."

                sh '''
                    mkdir -p "$(dirname ${STABLE_TAG_FILE})"

                    echo "${IMAGE_NAME}:${COMMIT_SHA}" \
                        > ${STABLE_TAG_FILE}

                    cat ${STABLE_TAG_FILE}
                '''
            }
        }


        // ====================================================
        // 12. BACKUP
        // ====================================================
        stage('Database Backup') {
            steps {
                sh '''
                    if [ -f scripts/backup.sh ]; then
                        chmod +x scripts/backup.sh
                        bash scripts/backup.sh
                    else
                        echo "WARNING: scripts/backup.sh not found."
                        exit 1
                    fi
                '''
            }
        }


        // ====================================================
        // 13. CLEANUP OLD IMAGES
        // ====================================================
        stage('Cleanup Old Images') {
            steps {
                sh '''
                    echo "Removing dangling Docker images..."
                    docker image prune -f
                '''
            }
        }
    }


    // ========================================================
    // AUTOMATIC ROLLBACK
    // ========================================================
    post {

        failure {

            script {

                echo 'Pipeline failed. Checking rollback availability...'

                sh '''
                    if [ -f ${STABLE_TAG_FILE} ]; then

                        PREVIOUS_IMAGE=$(cat ${STABLE_TAG_FILE})

                        echo "Rolling back to: $PREVIOUS_IMAGE"

                        if docker image inspect "$PREVIOUS_IMAGE" >/dev/null 2>&1; then

                            docker stop ${CONTAINER_NAME} 2>/dev/null || true
                            docker rm ${CONTAINER_NAME} 2>/dev/null || true

                            docker run -d \
                                --name ${CONTAINER_NAME} \
                                --restart unless-stopped \
                                -p ${APP_PORT}:80 \
                                "$PREVIOUS_IMAGE"

                            echo "Rollback container started."

                        else
                            echo "Rollback image not found locally: $PREVIOUS_IMAGE"
                        fi

                    else
                        echo "No stable release exists. Rollback skipped."
                    fi
                '''
            }
        }


        success {
            echo "SUCCESS: Deployment completed successfully."
            echo "Running version: ${COMMIT_SHA}"
        }


        always {
            echo 'Pipeline execution finished.'
        }
    }
}
