pipeline {
    agent {
        label 'agentzain'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAME       = 'my-laravel-app'
        CONTAINER_NAME   = 'laravel_app'

        // Application runs on port 80 of Jenkins Agent
        HOST_PORT        = '80'
        CONTAINER_PORT   = '80'

        HEALTH_URL       = 'http://localhost/health'

        // Stores the last successfully deployed immutable image
        STABLE_TAG_FILE  = '/opt/jenkins-deploy/last_stable_image'
    }

    stages {

        // =========================================================
        // 1. CHECKOUT
        // =========================================================
        stage('Checkout Code') {
            steps {
                checkout scm

                script {
                    env.COMMIT_SHA = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG = "${env.IMAGE_NAME}:${env.COMMIT_SHA}"

                    echo "Commit SHA: ${env.COMMIT_SHA}"
                    echo "Image Tag: ${env.IMAGE_TAG}"
                }
            }
        }


        // =========================================================
        // 2. INSTALL DEPENDENCIES FOR TESTING
        // =========================================================
        stage('Install Test Dependencies') {
            steps {
                echo 'Installing Composer dependencies...'

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


        // =========================================================
        // 3. QUALITY GATE - LARAVEL TESTS
        // =========================================================
        stage('Run Laravel Tests') {
            steps {
                echo 'Running Laravel automated tests...'

                sh '''
                    cd app

                    if [ ! -f artisan ]; then
                        echo "ERROR: Laravel artisan file not found."
                        exit 1
                    fi

                    php artisan test --stop-on-failure
                '''
            }
        }


        // =========================================================
        // 4. DEPENDENCY SECURITY SCAN
        // =========================================================
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


        // =========================================================
        // 5. BUILD DOCKER IMAGE
        // Uses Docker layer caching - NO --no-cache
        // =========================================================
        stage('Build Docker Image') {
            steps {
                echo "Building immutable image: ${IMAGE_TAG}"

                sh '''
                    docker build \
                        -t ${IMAGE_TAG} \
                        .
                '''
            }
        }


        // =========================================================
        // 6. TRIVY IMAGE SECURITY SCAN
        // HIGH/CRITICAL vulnerabilities fail the pipeline
        // =========================================================
        stage('Trivy Image Scan') {
            steps {
        echo "Running Trivy security scan on ${IMAGE_TAG}..."

        sh '''
            if ! command -v trivy >/dev/null 2>&1; then
                echo "ERROR: Trivy is not installed on this Jenkins Agent."
                exit 1
            fi

            echo "=============================================="
            echo "FULL IMAGE SECURITY REPORT"
            echo "HIGH vulnerabilities will be reported."
            echo "CRITICAL vulnerabilities will block deployment."
            echo "=============================================="

            trivy image \
                --severity HIGH,CRITICAL \
                --ignore-unfixed \
                ${IMAGE_TAG}

            echo ""
            echo "=============================================="
            echo "CHECKING FOR CRITICAL VULNERABILITIES"
            echo "=============================================="

            trivy image \
                --exit-code 1 \
                --severity CRITICAL \
                --ignore-unfixed \
                ${IMAGE_TAG}
        '''
    }
}

        // =========================================================
        // 7. READ PREVIOUS STABLE IMAGE
        // =========================================================
        stage('Prepare Deployment') {
            steps {
                script {
                    env.DEPLOYMENT_STARTED = 'false'

                    sh '''
                        mkdir -p "$(dirname ${STABLE_TAG_FILE})"

                        echo "Current stable release:"

                        if [ -f ${STABLE_TAG_FILE} ]; then
                            cat ${STABLE_TAG_FILE}
                        else
                            echo "No previous stable release found."
                        fi
                    '''
                }
            }
        }


        // =========================================================
        // 8. DEPLOY NEW VERSION
        // =========================================================
        stage('Deploy New Version') {
            steps {
                script {
                    // From this point, a failure can require rollback
                    env.DEPLOYMENT_STARTED = 'true'
                }

                echo "Deploying ${IMAGE_TAG}..."

                sh '''
                    docker stop ${CONTAINER_NAME} 2>/dev/null || true
                    docker rm ${CONTAINER_NAME} 2>/dev/null || true

                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        --restart unless-stopped \
                        -p ${HOST_PORT}:${CONTAINER_PORT} \
                        ${IMAGE_TAG}
                '''
            }
        }


        // =========================================================
        // 9. DOCKER CONTAINER HEALTH CHECK
        // =========================================================
        stage('Container Health Check') {
            steps {
                echo 'Waiting for container health check...'

                sh '''
                    for i in $(seq 1 12); do

                        STATUS=$(docker inspect \
                            --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
                            ${CONTAINER_NAME})

                        echo "Container status: $STATUS"

                        if [ "$STATUS" = "healthy" ]; then
                            echo "Container is healthy."
                            exit 0
                        fi

                        if [ "$STATUS" = "unhealthy" ] || [ "$STATUS" = "exited" ]; then
                            echo "Container failed."
                            docker logs ${CONTAINER_NAME} || true
                            exit 1
                        fi

                        sleep 5
                    done

                    echo "Container did not become healthy in time."
                    docker logs ${CONTAINER_NAME} || true
                    exit 1
                '''
            }
        }


        // =========================================================
        // 10. APPLICATION SMOKE TEST
        // =========================================================
        stage('Application Smoke Test') {
            steps {
                echo "Testing ${HEALTH_URL}..."

                sh '''
                    HTTP_CODE=$(curl \
                        --silent \
                        --show-error \
                        --output /dev/null \
                        --write-out "%{http_code}" \
                        ${HEALTH_URL})

                    echo "Health endpoint returned HTTP $HTTP_CODE"

                    if [ "$HTTP_CODE" != "200" ]; then
                        echo "ERROR: Smoke test failed."
                        exit 1
                    fi
                '''
            }
        }


        // =========================================================
        // 11. MARK NEW RELEASE AS STABLE
        // =========================================================
        stage('Mark Release Stable') {
            steps {
                echo "Marking ${IMAGE_TAG} as the last stable release..."

                sh '''
                    mkdir -p "$(dirname ${STABLE_TAG_FILE})"

                    echo "${IMAGE_TAG}" > ${STABLE_TAG_FILE}

                    echo "Stable release saved:"
                    cat ${STABLE_TAG_FILE}
                '''
            }
        }


        // =========================================================
        // 12. DATABASE BACKUP
        // =========================================================
        stage('Database Backup') {
            steps {
                echo 'Running database backup...'

                sh '''
                    if [ -f scripts/backup.sh ]; then
                        chmod +x scripts/backup.sh
                        bash scripts/backup.sh
                    else
                        echo "ERROR: scripts/backup.sh not found."
                        exit 1
                    fi
                '''
            }
        }


        // =========================================================
        // 13. CLEANUP
        // =========================================================
        stage('Cleanup Docker Images') {
            steps {
                sh '''
                    echo "Removing dangling Docker images..."
                    docker image prune -f
                '''
            }
        }
    }


    // =============================================================
    // POST ACTIONS
    // =============================================================
    post {

        failure {
            script {
                // Rollback ONLY if deployment had actually started
                if (env.DEPLOYMENT_STARTED == 'true') {

                    echo 'Deployment-related failure detected. Starting rollback...'

                    sh '''
                        if [ -f ${STABLE_TAG_FILE} ]; then

                            PREVIOUS_IMAGE=$(cat ${STABLE_TAG_FILE})

                            echo "Previous stable image: $PREVIOUS_IMAGE"

                            if docker image inspect "$PREVIOUS_IMAGE" >/dev/null 2>&1; then

                                echo "Stopping failed release..."

                                docker stop ${CONTAINER_NAME} 2>/dev/null || true
                                docker rm ${CONTAINER_NAME} 2>/dev/null || true

                                echo "Starting previous stable release..."

                                docker run -d \
                                    --name ${CONTAINER_NAME} \
                                    --restart unless-stopped \
                                    -p ${HOST_PORT}:${CONTAINER_PORT} \
                                    "$PREVIOUS_IMAGE"

                                echo "Rollback completed successfully."

                            else
                                echo "ERROR: Previous stable image does not exist locally."
                            fi

                        else
                            echo "No previous stable release available for rollback."
                        fi
                    '''

                } else {
                    echo 'Pipeline failed before deployment. Rollback is not required.'
                }
            }
        }

        success {
            echo '=========================================='
            echo 'CI/CD PIPELINE COMPLETED SUCCESSFULLY'
            echo "Deployed version: ${COMMIT_SHA}"
            echo "Image: ${IMAGE_TAG}"
            echo '=========================================='
        }

        always {
            echo 'Pipeline execution finished.'
        }
    }
}
