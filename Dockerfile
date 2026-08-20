# Stage 1: Build dependencies with Composer (PHP 8.4 Alpine)
FROM php:8.4-cli-alpine AS builder

WORKDIR /var/www/html

RUN apk add --no-cache \
    git \
    curl \
    libpng-dev \
    oniguruma-dev \
    libxml2-dev \
    zip \
    unzip

RUN docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Layer caching optimization
COPY app/composer.json app/composer.lock* ./

RUN composer install --no-dev --optimize-autoloader --no-scripts

# App source code copy
COPY app/ .

RUN composer dump-autoload --optimize


# Stage 2: Production Image with Apache (PHP 8.4 Apache)
FROM php:8.4-apache

WORKDIR /var/www/html

ENV DEBIAN_FRONTEND=noninteractive

# System Dependencies & Extensions
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

# Apache DocumentRoot pointing to public folder
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/conf-available/*.conf

# Copy compiled code from builder
COPY --from=builder /var/www/html /var/www/html

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Permissions setup
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["apache2-foreground"]
