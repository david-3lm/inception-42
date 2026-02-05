#!/bin/bash
set -e

echo "Starting MariaDB initialization..."

# Read passwords from secret files if they exist
if [ -f /run/secrets/db_root_password ]; then
    MYSQL_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
fi

if [ -f /run/secrets/db_password ]; then
    MYSQL_PASSWORD=$(cat /run/secrets/db_password)
fi

# Initialize MySQL data directory if it doesn't exist (first run only)
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "First run - Initializing MySQL system tables..."
    mysql_install_db --user=mysql --datadir=/var/lib/mysql > /dev/null
fi

# Start MariaDB temporarily in the background
echo "Starting temporary MariaDB for configuration..."
mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking &
MYSQL_PID=$!

# Wait for MariaDB to start
echo "Waiting for MariaDB to start..."
until mysqladmin ping --silent 2>/dev/null; do
    sleep 1
done

echo "MariaDB started successfully!"

# Only configure if database doesn't exist (first run)
if [ ! -d "/var/lib/mysql/${MYSQL_DATABASE}" ]; then
    echo "Configuring database and users..."
    
    mysql -u root <<-EOSQL
		ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
		CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
		CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
		GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
		FLUSH PRIVILEGES;
	EOSQL
    
    echo "Database '${MYSQL_DATABASE}' configured successfully!"
else
    echo "Database '${MYSQL_DATABASE}' already exists, skipping configuration."
fi

# Shutdown temporary MariaDB
echo "Shutting down temporary MariaDB..."
mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown
wait $MYSQL_PID

# Start MariaDB normally in foreground
echo "Starting MariaDB in foreground..."
exec mysqld --user=mysql --datadir=/var/lib/mysql