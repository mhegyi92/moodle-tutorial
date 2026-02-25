# Moodle Docker Image
# Based on official MoodleHQ PHP/Apache image

ARG PHP_VERSION=8.3
ARG MOODLE_VERSION=MOODLE_500_STABLE

FROM moodlehq/moodle-php-apache:${PHP_VERSION}-bookworm

ARG MOODLE_VERSION
ARG DEBIAN_FRONTEND=noninteractive

# Apache document root (required by base image)
ENV APACHE_DOCUMENT_ROOT=/var/www/html

# PHP settings for Moodle
ENV PHP_INI-memory_limit=256M \
    PHP_INI-max_input_vars=5000 \
    PHP_INI-upload_max_filesize=100M \
    PHP_INI-post_max_size=110M \
    PHP_INI-max_execution_time=300

# Install additional tools
# git, unzip: for managing plugins
# cron: for scheduled tasks
# curl: for API requests
# python3: for scripts and integrations
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    unzip \
    cron \
    curl \
    ca-certificates \
    python3 \
    python3-pip \
    python3-venv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create data directory for Moodle uploads and cache
RUN mkdir -p /var/www/moodledata \
    && chown -R www-data:www-data /var/www/moodledata \
    && chmod 755 /var/www/moodledata

# Download Moodle from official repository
WORKDIR /var/www/html
RUN git clone --depth 1 --branch ${MOODLE_VERSION} https://github.com/moodle/moodle.git . \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# Copy startup script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80

WORKDIR /var/www/html

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
