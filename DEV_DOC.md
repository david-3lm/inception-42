# Developer Documentation

## Setting Up the Environment from Scratch

### Prerequisites

Before starting, ensure you have:

1. **Docker Engine** (version 20.10 or higher)
2. **Docker Compose** (V2 - use `docker compose` not `docker-compose`)
3. **GNU Make**
4. **Sudo privileges** (for managing data directories)
5. **2GB free disk space**

**Installation check:**
```bash
docker --version
docker compose version
make --version
```

### Project Structure

```
inception/
├── Makefile                           # Build automation
├── README.md                          # Project documentation
├── USER_DOC.md                        # User documentation
├── DEV_DOC.md                         # Developer documentation
└── srcs/
    ├── docker-compose.yml             # Service orchestration
    ├── .env                           # Environment variables
    ├── secrets/                       # Sensitive credentials
    │   ├── db_root_password.txt
    │   └── db_password.txt
    └── requirements/                  # Service configurations
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── 50-server.cnf      # MariaDB configuration
        │   └── tools/
        │       └── init_db.sh         # Database initialization script
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/
        │   │   └── www.conf           # PHP-FPM configuration
        │   └── tools/
        │       └── setup_wordpress.sh # WordPress setup script
        └── nginx/
            ├── Dockerfile
            ├── conf/
            │   └── nginx.conf         # NGINX configuration
            └── tools/
                └── generate_ssl.sh    # SSL certificate generation
```

### Initial Configuration

#### 1. Create Secret Files

Create the secrets directory and password files:

```bash
mkdir -p srcs/secrets
echo -n "your_root_password" > srcs/secrets/db_root_password.txt
echo -n "your_db_password" > srcs/secrets/db_password.txt
chmod 600 srcs/secrets/*.txt
```

**Important:** 
- Use `-n` flag to avoid trailing newlines
- Passwords should be at least 8 characters
- Use `chmod 600` to restrict file permissions

#### 2. Configure Environment Variables

Create or edit `srcs/.env`:

```bash
# Domain configuration
DOMAIN_NAME=dlopez.42.fr
USER=your_unix_username

# MariaDB configuration
MYSQL_DATABASE=wordpress_db
MYSQL_USER=wordpress_user

# WordPress admin account
WP_ADMIN_USER=admin
WP_ADMIN_PASSWORD=secure_admin_password
WP_ADMIN_EMAIL=admin@dlopez.42.fr

# WordPress regular user account
WP_USER=editor
WP_USER_EMAIL=editor@dlopez.42.fr
WP_USER_PASSWORD=secure_user_password
```

**Required variables:**
- `DOMAIN_NAME` - Must match the domain in `/etc/hosts`
- `USER` - Your Linux username (used for data directory paths)
- `MYSQL_DATABASE` - Database name (must not contain spaces)
- `MYSQL_USER` - Database username
- WordPress credentials for both admin and regular user

#### 3. Configure Local Domain Resolution

Add the domain to your hosts file:

```bash
sudo nano /etc/hosts
```

Add this line:
```
127.0.0.1    dlopez.42.fr
```

Save and exit (Ctrl+X, Y, Enter).

#### 4. Create Data Directories

The Makefile creates these automatically, but you can create them manually:

```bash
mkdir -p /home/${USER}/data/mariadb
mkdir -p /home/${USER}/data/wordpress
```

## Building and Launching the Project

### Using the Makefile

The Makefile provides several targets:

```bash
# Build and start everything (most common)
make

# Individual steps
make build      # Build Docker images only
make up         # Start containers in detached mode
make down       # Stop containers (keeps data)
make clean      # Stop containers and remove images
make fclean     # Stop containers, remove images, volumes, and data
make re         # Clean rebuild (fclean + all)
```

### Using Docker Compose Directly

If you prefer to use Docker Compose commands directly:

```bash
# Build images
docker compose -f srcs/docker-compose.yml build

# Start services
docker compose -f srcs/docker-compose.yml up -d

# Stop services
docker compose -f srcs/docker-compose.yml down

# View logs
docker compose -f srcs/docker-compose.yml logs

# Follow logs in real-time
docker compose -f srcs/docker-compose.yml logs -f
```

### Build Process Explained

When you run `make build`:

1. **Data directories** are created in `/home/${USER}/data/`
2. **MariaDB image** is built:
   - Installs MariaDB server
   - Copies configuration files
   - Adds initialization script
3. **WordPress image** is built:
   - Installs PHP-FPM and extensions
   - Installs WP-CLI
   - Copies setup script
4. **NGINX image** is built:
   - Installs NGINX and OpenSSL
   - Copies configuration
   - Adds SSL generation script

### Startup Sequence

When you run `make up`:

1. **MariaDB starts first**:
   - Runs `init_db.sh`
   - Checks if database exists
   - If first run: initializes database, creates users
   - If subsequent run: skips initialization
   - Starts mysqld daemon

2. **WordPress waits for MariaDB healthcheck**:
   - MariaDB must pass healthcheck before WordPress starts
   - Runs `setup_wordpress.sh`
   - Downloads WordPress if needed
   - Creates `wp-config.php`
   - Runs WP-CLI installation
   - Creates admin and regular users
   - Starts PHP-FPM

3. **NGINX starts after WordPress**:
   - Runs `generate_ssl.sh`
   - Generates self-signed SSL certificate
   - Substitutes domain name in config
   - Starts NGINX daemon

## Managing Containers and Volumes

### Container Management Commands

```bash
# List all containers
docker compose -f srcs/docker-compose.yml ps

# View logs for all services
docker compose -f srcs/docker-compose.yml logs

# View logs for specific service
docker compose -f srcs/docker-compose.yml logs mariadb
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs nginx

# Follow logs in real-time
docker compose -f srcs/docker-compose.yml logs -f nginx

# Access container shell
docker exec -it mariadb bash
docker exec -it wordpress bash
docker exec -it nginx bash

# Restart a specific service
docker compose -f srcs/docker-compose.yml restart mariadb

# Stop a specific service
docker compose -f srcs/docker-compose.yml stop nginx

# Start a specific service
docker compose -f srcs/docker-compose.yml start nginx

# Rebuild and restart a service
docker compose -f srcs/docker-compose.yml up -d --build nginx
```

### Volume Management Commands

```bash
# List all volumes
docker volume ls

# Inspect volume details
docker volume inspect srcs_mariadb_data
docker volume inspect srcs_wordpress_data

# Remove all volumes (data will be lost!)
docker volume prune -f

# Remove specific volume
docker volume rm srcs_mariadb_data
```

### Network Management Commands

```bash
# List networks
docker network ls

# Inspect the project network
docker network inspect srcs_inception-network

# See which containers are on the network
docker network inspect srcs_inception-network -f '{{range .Containers}}{{.Name}} {{end}}'
```

### Image Management Commands

```bash
# List images
docker images

# Remove project images
docker rmi mariadb:inception
docker rmi wordpress:inception
docker rmi nginx:inception

# Remove all unused images
docker image prune -a
```

### Useful Debugging Commands

```bash
# Check if MariaDB is accepting connections
docker exec -it mariadb mysqladmin ping -p

# Connect to MariaDB database
docker exec -it mariadb mysql -u root -p

# Check WordPress files
docker exec -it wordpress ls -la /var/www/html/

# Check NGINX configuration syntax
docker exec -it nginx nginx -t

# Test website response
curl -Ik https://dlopez.42.fr

# Check which process is using port 443
sudo netstat -tulpn | grep :443
# or
sudo ss -tulpn | grep :443
```

## Data Storage and Persistence

### Where Data Is Stored

The project uses **bind mounts** to store persistent data on the host filesystem:

#### MariaDB Data
- **Container path:** `/var/lib/mysql`
- **Host path:** `/home/${USER}/data/mariadb`
- **Contains:**
  - Database files (`.ibd`, `.frm` files)
  - InnoDB system tablespace
  - Binary logs
  - MySQL system tables

#### WordPress Data
- **Container path:** `/var/www/html`
- **Host path:** `/home/${USER}/data/wordpress`
- **Contains:**
  - WordPress core files
  - `wp-config.php` (database configuration)
  - Uploaded media (`wp-content/uploads/`)
  - Installed themes (`wp-content/themes/`)
  - Installed plugins (`wp-content/plugins/`)

### How Persistence Works

1. **First Run:**
   - Directories are empty
   - Containers initialize data
   - Files are written to host filesystem

2. **Subsequent Runs:**
   - Containers find existing data
   - Skip initialization
   - Continue using existing files

3. **After `make down`:**
   - Containers stop
   - Data remains on host filesystem
   - Next `make up` reuses existing data

4. **After `make fclean`:**
   - Containers stop
   - Data directories are deleted with `sudo rm -rf`
   - Next `make` starts from scratch

### Backing Up Data

```bash
# Backup MariaDB
sudo tar -czf mariadb_backup_$(date +%Y%m%d).tar.gz /home/${USER}/data/mariadb/

# Backup WordPress
sudo tar -czf wordpress_backup_$(date +%Y%m%d).tar.gz /home/${USER}/data/wordpress/

# Or backup both together
sudo tar -czf inception_backup_$(date +%Y%m%d).tar.gz /home/${USER}/data/
```

### Restoring Data

```bash
# Stop services
make down

# Remove current data
sudo rm -rf /home/${USER}/data/mariadb/*
sudo rm -rf /home/${USER}/data/wordpress/*

# Extract backup
sudo tar -xzf mariadb_backup_20260205.tar.gz -C /
sudo tar -xzf wordpress_backup_20260205.tar.gz -C /

# Fix permissions
sudo chown -R ${USER}:${USER} /home/${USER}/data/

# Restart services
make up
```

### Inspecting Data

```bash
# View MariaDB data
ls -la /home/${USER}/data/mariadb/

# View WordPress files
ls -la /home/${USER}/data/wordpress/

# Check database size
du -sh /home/${USER}/data/mariadb/

# Check WordPress size
du -sh /home/${USER}/data/wordpress/
```

## Development Workflow

### Making Changes to Services

**General workflow:**

1. Stop the services: `make down`
2. Edit Dockerfile or configuration files
3. Rebuild: `make build`
4. Start services: `make up`
5. Check logs: `docker compose -f srcs/docker-compose.yml logs`

**Quick rebuild for single service:**

```bash
# For example, after changing NGINX config:
docker compose -f srcs/docker-compose.yml up -d --build nginx
```

### Testing Changes Without Data Loss

```bash
# Stop containers but keep data
make down

# Make your changes

# Start with existing data
make up
```

### Complete Clean Rebuild

```bash
# Remove everything including data
make fclean

# Rebuild from scratch
make
```

### Debugging Container Issues

```bash
# Start in foreground to see output
docker compose -f srcs/docker-compose.yml up

# Start only one service
docker compose -f srcs/docker-compose.yml up mariadb

# Check why a container exited
docker compose -f srcs/docker-compose.yml ps -a
docker logs mariadb

# Access a stopped container
docker start mariadb
docker exec -it mariadb bash
```

## Common Development Tasks

### Updating WordPress

```bash
docker exec -it wordpress wp core update --allow-root
```

### Adding WordPress Plugins

```bash
docker exec -it wordpress wp plugin install plugin-name --activate --allow-root
```

### Running MySQL Queries

```bash
docker exec -it mariadb mysql -u root -p
# Then run SQL commands
```

### Checking PHP Configuration

```bash
docker exec -it wordpress php -i | grep "Configuration File"
docker exec -it wordpress php -v
```

### Rebuilding SSL Certificates

```bash
docker exec -it nginx rm -f /etc/nginx/ssl/*
docker compose -f srcs/docker-compose.yml restart nginx
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose -f srcs/docker-compose.yml logs service_name

# Try running in foreground
docker compose -f srcs/docker-compose.yml up service_name
```

### Permission Issues

```bash
# Fix data directory ownership
sudo chown -R ${USER}:${USER} /home/${USER}/data/
sudo chmod -R 755 /home/${USER}/data/
```

### Port Already in Use

```bash
# Find what's using the port
sudo netstat -tulpn | grep :443

# Kill the process
sudo kill -9 <PID>
```

### Database Connection Failed

```bash
# Check MariaDB is running
docker compose -f srcs/docker-compose.yml ps mariadb

# Check MariaDB logs
docker compose -f srcs/docker-compose.yml logs mariadb

# Verify database credentials match
cat srcs/.env
cat srcs/secrets/db_password.txt
```
