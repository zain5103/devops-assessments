pipeline {
    agent {
        label 'agentzain'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
    }

    environment {
        IMAGE_NAME      = 'my-laravel-app'
        CONTAINER_NAME  = 'laravel_app'

        HOST_PORT       = '8080'
        CONTAINER_PORT  = '80'
        HEALTH_URL      = 'http://127.0.0.1:8080/health'

        DB_CONNECTION   = 'mysql'
        DB_HOST         = '10.0.1.112'
        DB_PORT         = '3306'
        DB_DATABASE     = 'devops'
        DB_USERNAME     = 'root'

        DEPLOY_DIR      = "${HOME}/jenkins-deploy"
        STABLE_TAG_FILE = "${HOME}/jenkins-deploy/last_stable_image"
        
        DOCKER_BUILDKIT = '1'
    }

    stages {
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

        stage('Install Test Dependencies') {
            steps {
                echo 'Installing Composer dependencies...'
                sh '''
                    docker run --rm \
                        -v "$WORKSPACE/app:/app" \
                        -w /app \
                        composer:2 \
                        composer install --no-interaction --prefer-dist
                '''
            }
        }

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

        stage('Build Docker Image') {
            steps {
                echo "Building image: ${IMAGE_TAG}"
                timeout(time: 15, unit: 'MINUTES') {
                    sh '''
                        docker build \
                            --progress=plain \
                            --no-cache \
                            -t "$IMAGE_TAG" \
                            .
                    '''
                }
            }
        }

        stage('Trivy Image Scan') {
            steps {
                echo "Running Trivy scan on ${IMAGE_TAG}..."
                sh '''
                    if ! command -v trivy >/dev/null 2>&1; then
                        echo "WARNING: Trivy is not installed on this agent. Skipping scan."
                    else
                        trivy image --severity HIGH,CRITICAL --ignore-unfixed "$IMAGE_TAG"
                    fi
                '''
            }
        }

        stage('Prepare Deployment') {
            steps {
                sh '''
                    mkdir -p "$DEPLOY_DIR"
                    if [ -f "$STABLE_TAG_FILE" ]; then
                        echo "Previous stable image: $(cat "$STABLE_TAG_FILE")"
                    else
                        echo "First successful deployment."
                    fi
                '''
            }
        }

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
                        docker stop "$CONTAINER_NAME" 2>/dev/null || true
                        docker rm "$CONTAINER_NAME" 2>/dev/null || true

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
                    '''
                }
            }
        }

        stage('Container Health Check') {
            steps {
                sh '''
                    for i in $(seq 1 12); do
                        STATUS=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "not-found")
                        if [ "$STATUS" = "running" ]; then
                            echo "Container is running."
                            exit 0
                        fi
                        sleep 5
                    done
                    exit 1
                '''
            }
        }

        stage('Mark Release Stable') {
            steps {
                sh '''
                    mkdir -p "$DEPLOY_DIR"
                    echo "$IMAGE_TAG" > "$STABLE_TAG_FILE"
                '''
            }
        }

        stage('Cleanup Dangling Images') {
            steps {
                sh 'docker image prune -f'
            }
        }
    }

    post {
        failure {
            echo "Pipeline failed."
        }
        success {
            echo "CI/CD Pipeline Completed Successfully!"
        }
    }
}
