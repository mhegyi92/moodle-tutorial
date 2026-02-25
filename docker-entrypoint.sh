#!/bin/bash
set -e

# Wait for database to be ready
echo "Waiting for database connection..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if php -r "
        \$host = getenv('MOODLE_DB_HOST') ?: 'mariadb';
        \$port = getenv('MOODLE_DB_PORT') ?: '3306';
        \$conn = @fsockopen(\$host, \$port, \$errno, \$errstr, 5);
        if (\$conn) { fclose(\$conn); exit(0); }
        exit(1);
    " 2>/dev/null; then
        echo "Database is ready!"
        break
    fi
    attempt=$((attempt + 1))
    echo "Waiting for database... (attempt $attempt/$max_attempts)"
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "Error: Could not connect to database after $max_attempts attempts"
    exit 1
fi

# Check if Moodle is already installed (config.php exists and has content)
if [ -f /var/www/html/config.php ] && [ -s /var/www/html/config.php ]; then
    echo "Moodle config.php found, skipping installation"
else
    echo "Installing Moodle..."

    # Run Moodle CLI installer
    php /var/www/html/admin/cli/install.php \
        --wwwroot="${MOODLE_URL:-http://localhost}" \
        --dataroot=/var/www/moodledata \
        --dbtype="${MOODLE_DB_TYPE:-mariadb}" \
        --dbhost="${MOODLE_DB_HOST:-mariadb}" \
        --dbport="${MOODLE_DB_PORT:-3306}" \
        --dbname="${MOODLE_DB_NAME:-moodle}" \
        --dbuser="${MOODLE_DB_USER:-moodleuser}" \
        --dbpass="${MOODLE_DB_PASSWORD:-moodlepass}" \
        --fullname="${MOODLE_SITE_NAME:-Moodle Site}" \
        --shortname="${MOODLE_SITE_SHORTNAME:-Moodle}" \
        --adminuser="${MOODLE_ADMIN_USER:-admin}" \
        --adminpass="${MOODLE_ADMIN_PASSWORD:-Admin123!}" \
        --adminemail="${MOODLE_ADMIN_EMAIL:-admin@example.com}" \
        --non-interactive \
        --agree-license

    echo "Moodle installation complete!"

    # Set proper permissions on config.php
    chown www-data:www-data /var/www/html/config.php
    chmod 644 /var/www/html/config.php
fi

# Configure Redis if available
if [ -n "$MOODLE_REDIS_HOST" ]; then
    echo "Configuring Redis session handler..."

    # Append Redis config to config.php if not already present
    if ! grep -q "session_handler_class" /var/www/html/config.php; then
        # Remove the closing require_once line temporarily
        sed -i '/require_once.*setup.php/d' /var/www/html/config.php

        # Add Redis configuration
        cat >> /var/www/html/config.php << EOF

// Redis session configuration
\$CFG->session_handler_class = '\core\session\redis';
\$CFG->session_redis_host = '${MOODLE_REDIS_HOST}';
\$CFG->session_redis_port = ${MOODLE_REDIS_PORT:-6379};
\$CFG->session_redis_database = 0;
\$CFG->session_redis_prefix = 'moodle_';
\$CFG->session_redis_acquire_lock_timeout = 120;
\$CFG->session_redis_lock_expire = 7200;

require_once(__DIR__ . '/lib/setup.php');
EOF
        echo "Redis configuration added"
    fi
fi

# Configure SMTP if available
if [ -n "$MOODLE_SMTP_HOST" ]; then
    echo "SMTP configuration should be done via Moodle admin interface"
    echo "SMTP Host: $MOODLE_SMTP_HOST:${MOODLE_SMTP_PORT:-1025}"
fi

# Ensure proper permissions
chown -R www-data:www-data /var/www/moodledata
chmod -R 755 /var/www/moodledata

echo "Starting Apache..."
exec "$@"
