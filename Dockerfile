# ============================================================
# Stage 1: Composer dependencies
# ============================================================
FROM composer:2 AS vendor

WORKDIR /var/www/html

# Copy only Composer files first.
# This allows Docker to reuse the dependency layer when
# application source code changes but composer files do not.
COPY app/composer.json app/composer.lock ./

# Install production dependencies
RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader \
    --no-scripts


# ============================================================
# Stage 2: Production Laravel + Apache image
# ============================================================
FROM php:8.2-apache

WORKDIR /var/www/html

# Install system dependencies required for PHP extensions
RUN apt-get update && apt-get install -y \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    unzip \
    && docker-php-ext-install \
        pdo_mysql \
        mbstring \
        bcmath \
        exif \
        pcntl \
        gd \
        zip \
    && rm -rf /var/lib/apt/lists/*

# Enable Apache rewrite module
RUN a2enmod rewrite

# Configure Apache DocumentRoot for Laravel
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public

RUN sed -ri \
    -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' \
    /etc/apache2/sites-available/000-default.conf \
    /etc/apache2/conf-available/*.conf

# Copy Laravel application source
COPY app/ /var/www/html/

# Copy Composer dependencies from vendor stage
COPY --from=vendor /var/www/html/vendor /var/www/html/vendor

# Copy entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Container health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS http://localhost/health || exit 1

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["apache2-foreground"]
