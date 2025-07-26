#!/bin/sh
set -e

if [ -f "/app/storage/oauth-private.key" ]; then
    echo "Found oauth-private.key, copying to Janus directory..."
    cp /app/storage/oauth-private.key /opt/janus/oauth-private.key
else
    echo "Warning: /app/storage/oauth-private.key not found. Janus may fail to start."
fi

if [ ! -f "/opt/janus/.env" ]; then
    echo "Warning: Janus config file /opt/janus/.env not found. Janus will likely fail."
fi
if [ ! -f "/opt/janus/prisma/schema.prisma" ]; then
    echo "Warning: Janus schema file /opt/janus/prisma/schema.prisma not found. Database migration will fail."
fi

if [ -f "/etc/apache2/sites-available/001-janus-proxy.conf" ]; then
    echo "Enabling janus proxy site..."
    a2ensite 001-janus-proxy.conf
fi

echo "Starting supervisor..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf