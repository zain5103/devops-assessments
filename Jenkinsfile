pipeline {
    agent {
        label 'agentzain'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        
        // =========================================================
        // APPLICATION / DOCKER
        // =========================================================
    IMAGE_NAME      = 'my-laravel-app'
    CONTAINER_NAME  = 'laravel_app'

    HOST_PORT       = '8080'
    CONTAINER_PORT  = '80'
    HEALTH_URL      = 'http://localhost:8080/health'

    DB_CONNECTION   = 'mysql'

    // Jenkins Agent ka private IP, kyunki MariaDB isi EC2 par installed hai
    DB_HOST         = '10.0.1.112'

    DB_PORT         = '3306'
    DB_DATABASE     = 'devops'
    DB_USERNAME     = 'root'

    DEPLOY_DIR      = "${HOME}/jenkins-deploy"
    STABLE_TAG_FILE = "${HOME}/jenkins-deploy/last_stable_image"
    }

    stages {

        // =========================================================
        // 1. CHECKOUT CODE
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
        // Docker cache enabled - NO --no-cache
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
        // CRITICAL = blocks deployment
        // =========================================================
        stage('Trivy Image Scan') {
            steps {
                echo "Running Trivy scan on ${IMAGE_TAG}..."

                sh '''
                    if ! command -v trivy >/dev/null 2>&1; then
                        echo "ERROR: Trivy is not installed on this Jenkins Agent."
                        exit 1
                    fi

                    echo "=============================================="
                    echo "IMAGE SECURITY REPORT"
                    echo "=============================================="

                    trivy image \
                        --severity HIGH,CRITICAL \
                        --ignore-unfixed \
                        "$IMAGE_TAG"

                    echo ""
                    echo "=============================================="
                    echo "CRITICAL VULNERABILITY QUALITY GATE"
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
                        echo "No previous stable image found."
                        echo "This is the first successful deployment."
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

        withCredentials([
            string(credentialsId: 'laravel-app-key', variable: 'LARAVEL_APP_KEY'),
            string(credentialsId: 'mariadb-password', variable: 'MARIADB_PASSWORD')
        ]) {
            sh '''
                set -e

                echo "Stopping old container..."
                docker stop "$CONTAINER_NAME" 2>/dev/null || true
                docker rm "$CONTAINER_NAME" 2>/dev/null || true

                echo "Starting new container..."
                echo "Database: $DB_DATABASE"
                echo "Database User: $DB_USERNAME"
                echo "Database Host: $DB_HOST"

                docker run -d \
                    --name "$CONTAINER_NAME" \
                    --restart unless-stopped \
                    -p "$HOST_PORT:$CONTAINER_PORT" \
                    -e APP_ENV=production \
                    -e APP_DEBUG=false \
                    -e APP_KEY="$LARAVEL_APP_KEY" \
                    -e DB_CONNECTION="$DB_CONNECTION" \
                    -e DB_HOST="$DB_HOST" \
                    -e DB_PORT="$DB_PORT" \
                    -e DB_DATABASE="$DB_DATABASE" \
                    -e DB_USERNAME="$DB_USERNAME" \
                    -e DB_PASSWORD="$MARIADB_PASSWORD" \
                    "$IMAGE_TAG"

                echo "Container started successfully."
            '''
        }
    }
}


        // =========================================================
        // 9. CONTAINER STATUS CHECK
        // =========================================================
        stage('Container Health Check') {
            steps {
                echo 'Waiting for Laravel container to start...'

                sh '''
                    for i in $(seq 1 12); do

                        STATUS=$(docker inspect \
                            --format='{{.State.Status}}' \
                            "$CONTAINER_NAME" 2>/dev/null || echo "not-found")

                        echo "Attempt $i/12 - Container status: $STATUS"

                        if [ "$STATUS" = "running" ]; then
                            echo "Container is running."
                            exit 0
                        fi

                        if [ "$STATUS" = "exited" ] || \
                           [ "$STATUS" = "dead" ] || \
                           [ "$STATUS" = "not-found" ]; then

                            echo "ERROR: Container failed to start."

                            docker logs "$CONTAINER_NAME" 2>/dev/null || true
                            exit 1
                        fi

                        sleep 5
                    done

                    echo "ERROR: Container did not start in time."

                    docker logs "$CONTAINER_NAME" 2>/dev/null || true
                    exit 1
                '''
            }
        }


        // =========================================================
        // 10. APPLICATION HEALTH CHECK + SMOKE TEST
        // =========================================================
        stage('Application Smoke Test') {
            steps {
                echo "Checking application: ${HEALTH_URL}"

                sh '''
                    MAX_TRIES=12
                    COUNT=1
                    HTTP_CODE="000"

                    while [ "$COUNT" -le "$MAX_TRIES" ]; do

                        HTTP_CODE=$(curl \
                            --silent \
                            --show-error \
                            --output /dev/null \
                            --write-out "%{http_code}" \
                            "$HEALTH_URL" || true)

                        echo "Attempt $COUNT/$MAX_TRIES - HTTP Status: $HTTP_CODE"

                        if [ "$HTTP_CODE" = "200" ]; then
                            echo "Application health check passed."
                            exit 0
                        fi

                        COUNT=$((COUNT + 1))
                        sleep 5
                    done

                    echo "ERROR: Application health check failed."
                    echo "Final HTTP status: $HTTP_CODE"

                    echo "Container logs:"
                    docker logs "$CONTAINER_NAME" || true

                    exit 1
                '''
            }
        }


        // =========================================================
        // 11. MARK CURRENT VERSION AS STABLE
        // =========================================================
        stage('Mark Release Stable') {
            steps {
                echo "Marking ${IMAGE_TAG} as stable..."

                sh '''
                    mkdir -p "$DEPLOY_DIR"

                    echo "$IMAGE_TAG" > "$STABLE_TAG_FILE"

                    echo "Stable release:"
                    cat "$STABLE_TAG_FILE"
                '''
            }
        }


        // =========================================================
        // 12. DATABASE BACKUP
        // =========================================================
        stage('Database Backup') {
            steps {
                echo 'Running MariaDB backup...'

                withCredentials([
                    string(
                        credentialsId: 'mariadb-password',
                        variable: 'MARIADB_PASSWORD'
                    )
                ]) {
                    sh '''
                        if [ ! -f "$WORKSPACE/scripts/backup.sh" ]; then
                            echo "ERROR: scripts/backup.sh not found."
                            exit 1
                        fi

                        chmod +x "$WORKSPACE/scripts/backup.sh"

                        export DB_HOST="127.0.0.1"
                        export DB_PORT="$DB_PORT"
                        export DB_DATABASE="$DB_DATABASE"
                        export DB_USERNAME="$DB_USERNAME"
                        export DB_PASSWORD="$MARIADB_PASSWORD"

                        bash "$WORKSPACE/scripts/backup.sh"
                    '''
                }
            }
        }


        // =========================================================
        // 13. CLEANUP DANGLING IMAGES
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
                if (env.DEPLOYMENT_STARTED == 'true') {

                    echo 'Deployment failure detected.'
                    echo 'Starting automatic rollback...'

                    withCredentials([
                        string(
                            credentialsId: 'laravel-app-key',
                            variable: 'LARAVEL_APP_KEY'
                        ),
                        string(
                            credentialsId: 'mariadb-password',
                            variable: 'MARIADB_PASSWORD'
                        )
                    ]) {
                        sh '''
                            if [ ! -f "$STABLE_TAG_FILE" ]; then
                                echo "No previous stable release available for rollback."
                                exit 0
                            fi

                            PREVIOUS_IMAGE=$(cat "$STABLE_TAG_FILE")

                            echo "Previous stable image: $PREVIOUS_IMAGE"

                            if ! docker image inspect "$PREVIOUS_IMAGE" >/dev/null 2>&1; then
                                echo "ERROR: Previous stable image does not exist locally."
                                exit 0
                            fi

                            echo "Stopping failed container..."

                            docker stop "$CONTAINER_NAME" 2>/dev/null || true
                            docker rm "$CONTAINER_NAME" 2>/dev/null || true

                            echo "Starting previous stable release..."

                            docker run -d \
                                --name "$CONTAINER_NAME" \
                                --restart unless-stopped \
                                --add-host=host.docker.internal:host-gateway \
                                -p "$HOST_PORT:$CONTAINER_PORT" \
                                -e APP_ENV=production \
                                -e APP_DEBUG=false \
                                -e APP_KEY="$LARAVEL_APP_KEY" \
                                -e DB_CONNECTION="$DB_CONNECTION" \
                                -e DB_HOST="$DB_HOST" \
                                -e DB_PORT="$DB_PORT" \
                                -e DB_DATABASE="$DB_DATABASE" \
                                -e DB_USERNAME="$DB_USERNAME" \
                                -e DB_PASSWORD="$MARIADB_PASSWORD" \
                                "$PREVIOUS_IMAGE"

                            echo "Waiting for rollback application..."

                            MAX_TRIES=12
                            COUNT=1
                            ROLLBACK_CODE="000"

                            while [ "$COUNT" -le "$MAX_TRIES" ]; do

                                ROLLBACK_CODE=$(curl \
                                    --silent \
                                    --show-error \
                                    --output /dev/null \
                                    --write-out "%{http_code}" \
                                    "$HEALTH_URL" || true)

                                echo "Rollback attempt $COUNT/$MAX_TRIES - HTTP $ROLLBACK_CODE"

                                if [ "$ROLLBACK_CODE" = "200" ]; then
                                    echo "Rollback verification successful."
                                    exit 0
                                fi

                                COUNT=$((COUNT + 1))
                                sleep 5
                            done

                            echo "WARNING: Rollback container started but health check failed."
                            docker logs "$CONTAINER_NAME" || true
                        '''
                    }

                } else {
                    echo 'Pipeline failed before deployment.'
                    echo 'Rollback is not required.'
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
