pipeline {
    agent {
        label 'agentzain'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAME     = 'my-laravel-app'
        CONTAINER_NAME = 'laravel_app'

        // Application ports
        HOST_PORT      = '80'
        CONTAINER_PORT = '80'

        // Laravel health endpoint
        HEALTH_URL     = 'http://localhost/health'

        // Persistent deployment state inside the Jenkins Agent user's HOME
        DEPLOY_DIR     = "${HOME}/jenkins-deploy"
        STABLE_TAG_FILE = "${HOME}/jenkins-deploy/last_stable_image"
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
        // 2. INSTALL TEST DEPENDENCIES
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
                    cd "$WORKSPACE/app"

                    if [ ! -f artisan ]; then
                        echo "ERROR: Laravel artisan file not found."
                        exit 1
                    fi

                    php artisan test --stop-on-failure
                '''
            }
        }


        // =========================================================
        // 4. DEPENDENCY SECURITY AUDIT
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
        // 5. BUILD IMMUTABLE DOCKER IMAGE
        // Docker layer caching enabled
        // =========================================================
        stage('Build Docker Image') {
            steps {
                echo "Building image: ${IMAGE_TAG}"

                sh '''
                    docker build \
                        -t "$IMAGE_TAG" \
                        .
                '''
            }
        }


        // =========================================================
        // 6. TRIVY IMAGE SECURITY SCAN
        // HIGH = report
        // CRITICAL = block deployment
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
                    echo "=============================================="

                    trivy image \
                        --severity HIGH,CRITICAL \
                        --ignore-unfixed \
                        "$IMAGE_TAG"

                    echo ""
                    echo "=============================================="
                    echo "CRITICAL VULNERABILITY GATE"
                    echo "=============================================="

                    trivy image \
                        --exit-code 1 \
                        --severity CRITICAL \
                        --ignore-unfixed \
                        "$IMAGE_TAG"
                '''
            }
        }


        // =========================================================
        // 7. PREPARE DEPLOYMENT
        // Read previous stable image
        // =========================================================
        stage('Prepare Deployment') {
            steps {
                sh '''
                    mkdir -p "$DEPLOY_DIR"

                    echo "Deployment directory: $DEPLOY_DIR"

                    if [ -f "$STABLE_TAG_FILE" ]; then
                        echo "Previous stable image:"
                        cat "$STABLE_TAG_FILE"
                    else
                        echo "No previous stable image found. First deployment."
                    fi
                '''
            }
        }


        // =========================================================
        // 8. DEPLOY NEW VERSION
        // =========================================================
        stage('Deploy New Version') {
            steps {
                script {
                    env.DEPLOYMENT_STARTED = 'true'
                }

                echo "Deploying ${IMAGE_TAG}..."

                sh '''
                    echo "Stopping existing container..."

                    docker stop "$CONTAINER_NAME" 2>/dev/null || true
                    docker rm "$CONTAINER_NAME" 2>/dev/null || true

                    echo "Starting new container..."

                    docker run -d \
                        --name "$CONTAINER_NAME" \
                        --restart unless-stopped \
                        -p "$HOST_PORT:$CONTAINER_PORT" \
                        "$IMAGE_TAG"
                '''
            }
        }


        // =========================================================
        // 9. CONTAINER STARTUP CHECK
        // Works even if Dockerfile has no HEALTHCHECK
        // =========================================================
        stage('Container Health Check') {
            steps {
                echo 'Waiting for container to start...'

                sh '''
                    for i in $(seq 1 12); do

                        STATUS=$(docker inspect \
                            --format='{{.State.Status}}' \
                            "$CONTAINER_NAME" 2>/dev/null || echo "not-found")

                        echo "Container status: $STATUS"

                        if [ "$STATUS" = "running" ]; then
                            echo "Container is running."
                            exit 0
                        fi

                        if [ "$STATUS" = "exited" ] || [ "$STATUS" = "dead" ] || [ "$STATUS" = "not-found" ]; then
                            echo "Container failed to start."
                            docker logs "$CONTAINER_NAME" || true
                            exit 1
                        fi

                        sleep 5
                    done

                    echo "Container did not start in time."
                    docker logs "$CONTAINER_NAME" || true
                    exit 1
                '''
            }
        }


        // =========================================================
        // 10. APPLICATION HEALTH / SMOKE TEST
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
                        "$HEALTH_URL" || true)

                    echo "Health endpoint returned HTTP $HTTP_CODE"

                    if [ "$HTTP_CODE" != "200" ]; then
                        echo "ERROR: Application smoke test failed."
                        docker logs "$CONTAINER_NAME" || true
                        exit 1
                    fi
                '''
            }
        }


        // =========================================================
        // 11. MARK RELEASE AS STABLE
        // Only runs after successful smoke test
        // =========================================================
        stage('Mark Release Stable') {
            steps {
                echo "Marking ${IMAGE_TAG} as stable..."

                sh '''
                    mkdir -p "$DEPLOY_DIR"

                    echo "$IMAGE_TAG" > "$STABLE_TAG_FILE"

                    echo "Stable release saved:"
                    cat "$STABLE_TAG_FILE"
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
                    if [ -f "$WORKSPACE/scripts/backup.sh" ]; then
                        chmod +x "$WORKSPACE/scripts/backup.sh"
                        bash "$WORKSPACE/scripts/backup.sh"
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
    // POST ACTIONS - AUTOMATIC ROLLBACK
    // =============================================================
    post {

        failure {
            script {
                if (env.DEPLOYMENT_STARTED == 'true') {

                    echo 'Deployment failure detected. Starting automatic rollback...'

                    sh '''
                        if [ -f "$STABLE_TAG_FILE" ]; then

                            PREVIOUS_IMAGE=$(cat "$STABLE_TAG_FILE")

                            echo "Previous stable image: $PREVIOUS_IMAGE"

                            if docker image inspect "$PREVIOUS_IMAGE" >/dev/null 2>&1; then

                                echo "Stopping failed release..."

                                docker stop "$CONTAINER_NAME" 2>/dev/null || true
                                docker rm "$CONTAINER_NAME" 2>/dev/null || true

                                echo "Starting previous stable release..."

                                docker run -d \
                                    --name "$CONTAINER_NAME" \
                                    --restart unless-stopped \
                                    -p "$HOST_PORT:$CONTAINER_PORT" \
                                    "$PREVIOUS_IMAGE"

                                echo "Rollback completed."

                                sleep 5

                                ROLLBACK_CODE=$(curl \
                                    --silent \
                                    --output /dev/null \
                                    --write-out "%{http_code}" \
                                    "$HEALTH_URL" || true)

                                echo "Rollback health check HTTP: $ROLLBACK_CODE"

                                if [ "$ROLLBACK_CODE" = "200" ]; then
                                    echo "Rollback verification successful."
                                else
                                    echo "WARNING: Rollback container started but health check failed."
                                    docker logs "$CONTAINER_NAME" || true
                                fi

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
