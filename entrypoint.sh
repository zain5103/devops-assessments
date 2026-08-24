#!/bin/sh
set -e

cd /var/www/html

echo "=========================================="
echo "Starting Laravel container..."
echo "=========================================="

# -------------------------------------------------
# Environment defaults & validation
# -------------------------------------------------
: "${DB_CONNECTION:=mysql}"
: "${DB_HOST:=db}"
: "${DB_PORT:=3306}"

echo "Database Host: ${DB_HOST}"
echo "Database Port: ${DB_PORT}"
echo "Database Name: ${DB_DATABASE:-not-set}"

if [ -z "${DB_DATABASE:-}" ] || [ -z "${DB_USERNAME:-}" ] || [ -z "${DB_PASSWORD:-}" ]; then
    echo "WARNING: Required database environment variables are missing."
    echo "Required: DB_DATABASE, DB_USERNAME, DB_PASSWORD"
    echo "Skipping DB-dependent setup and starting Apache..."
    exec apache2-foreground
fi

# -------------------------------------------------
# Wait for MySQL database
# -------------------------------------------------
echo "Waiting for database connection..."

MAX_TRIES=30
COUNT=1

until php -r "
try {
    \$dsn = 'mysql:host=' . getenv('DB_HOST') . ';port=' . getenv('DB_PORT') . ';dbname=' . getenv('DB_DATABASE');
    new PDO(\$dsn, getenv('DB_USERNAME'), getenv('DB_PASSWORD'), [
        PDO::ATTR_TIMEOUT => 5
    ]);
    echo 'Database connection successful\n';
    exit(0);
} catch (Exception \$e) {
    echo 'Database not ready: ' . \$e->getMessage() . '\n';
    exit(1);
}
"; do

    if [ "$COUNT" -ge "$MAX_TRIES" ]; then
        echo "ERROR: Database was not reachable after $MAX_TRIES attempts."
        exit 1
    fi

    echo "Database not ready. Retry $COUNT/$MAX_TRIES..."
    COUNT=$((COUNT + 1))
    sleep 2
done

echo "=========================================="
echo "Database connection successful."
echo "=========================================="

# -------------------------------------------------
# Laravel setup & deployment optimization
# -------------------------------------------------
echo "Clearing old Laravel caches..."
php artisan optimize:clear || true

echo "Running database migrations..."
php artisan migrate --force || true


echo "Caching Laravel configuration & routes..."
php artisan config:cache || true
php artisan route:cache || true
php artisan view:cache || true

echo "=========================================="
echo "Laravel setup completed."
echo "Starting Apache in foreground..."
echo "=========================================="

exec apache2-foreground
