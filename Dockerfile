# Stage 1: Build dependencies with Composer (Lightweight PHP 8.4 Alpine)
FROM php:8.4-cli-alpine AS builder

WORKDIR /var/www/html

# Core tools without heavy C++ packages
RUN apk add --no-cache \
    git \
    curl \
    unzip

# Install lightweight required extensions
RUN docker-php-ext-install pdo_mysql bcmath

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy composer files for caching
COPY app/composer.json app/composer.lock* ./

RUN composer install --no-dev --optimize-autoloader --no-scripts

# Copy application source code
COPY app/ .

RUN composer dump-autoload --optimize


# Stage 2: Production Image with Apache (PHP 8.4 Apache)
FROM php:8.4-apache

WORKDIR /var/www/html

ENV DEBIAN_FRONTEND=noninteractive

# Essential packages & extensions in a single optimized layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    zip \
    unzip \
    curl \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Apache modules setup
RUN a2enmod rewrite

# Update Apache DocumentRoot to point to public/
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/conf-available/*.conf

# Copy application from builder
COPY --from=builder /var/www/html /var/www/html

# Entrypoint setup
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Permissions setup (FIXED)
# 1. Laravel ke zaroori folders create karein (sahi paths ke sath)
# Zaroori folders create karein exact us path par jo error mein hai
# 1. Laravel ke zaroori folders create karein
RUN mkdir -p /var/www/html/storage/framework/{sessions,views,cache} \
    && mkdir -p /var/www/html/storage/logs \
    && mkdir -p /var/www/html/bootstrap/cache

# 2. Ownership aur Permissions www-data aur sahi paths ke sath set karein
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/storage \
    && chmod -R 775 /var/www/html/bootstrap/cache

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
