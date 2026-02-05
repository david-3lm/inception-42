# Inception

_This project has been created as part of the 42 curriculum by dlopez-l._

## Description

Inception is a system administration and DevOps project focused on Docker containerization and orchestration. The goal is to set up a complete web infrastructure using Docker containers, implementing a WordPress website with NGINX as a reverse proxy and MariaDB as the database backend.

The project demonstrates understanding of containerization, Docker networking, persistent storage, secure credential management, and service orchestration using Docker Compose. Each service runs in its own dedicated container, following Docker best practices and the principle of running one process per container.

### Key Objectives:
- Build custom Docker images from Debian base images (no pre-built application images allowed)
- Configure secure HTTPS communication with TLS 1.2/1.3
- Implement proper networking between containers
- Manage persistent data using Docker volumes
- Handle sensitive credentials securely using Docker secrets
- Ensure proper service initialization order and health checking

## Project Architecture

### Services Overview

The infrastructure consists of three main services:

1. **NGINX** - Web server and reverse proxy
   - Handles HTTPS termination with self-signed SSL certificates
   - Redirects HTTP (port 80) to HTTPS (port 443)
   - Forwards PHP requests to WordPress via FastCGI
   - Serves static files directly

2. **WordPress** - Content Management System
   - Runs on PHP-FPM 8.2
   - Configured automatically using WP-CLI (no manual installation wizard)
   - Connects to MariaDB for data storage
   - Accessible only through NGINX (not directly exposed)

3. **MariaDB** - Database Server
   - Stores WordPress data and configuration
   - Initializes database and users on first run
   - Uses persistent volume for data storage
   - Protected on internal network (not publicly accessible)

### Network Architecture

All containers communicate through a custom bridge network (`inception-network`), which provides:
- Service discovery by container name (e.g., WordPress connects to `mariadb:3306`)
- Network isolation from the host and other Docker networks
- Internal DNS resolution between containers

Only NGINX exposes ports to the host machine (80 and 443), creating a secure perimeter.

## Instructions

### Prerequisites

- Docker Engine and Docker Compose installed
- GNU Make
- Sudo privileges (for volume management)
- Minimum 2GB free disk space

### Project Structure

```
.
├── Makefile
├── srcs/
│   ├── docker-compose.yml
│   ├── .env
│   ├── requirements/
│   │   ├── mariadb/
│   │   │   ├── Dockerfile
│   │   │   ├── conf/
│   │   │   │   └── 50-server.cnf
│   │   │   └── tools/
│   │   │       └── init_db.sh
│   │   ├── wordpress/
│   │   │   ├── Dockerfile
│   │   │   ├── conf/
│   │   │   │   └── www.conf
│   │   │   └── tools/
│   │   │       └── setup_wordpress.sh
│   │   └── nginx/
│   │       ├── Dockerfile
│   │       ├── conf/
│   │       │   └── nginx.conf
│   │       └── tools/
│   │           └── generate_ssl.sh
│   └── secrets/
│       ├── db_root_password.txt
│       └── db_password.txt
└── README.md
```

### Configuration

1. **Create secret files** (if not already present):

```bash
mkdir -p srcs/secrets
echo -n "your_root_password" > srcs/secrets/db_root_password.txt
echo -n "your_db_password" > srcs/secrets/db_password.txt
chmod 600 srcs/secrets/*.txt
```

2. **Configure environment variables** in `srcs/.env`:

```bash
# Domain configuration
DOMAIN_NAME=dlopez.42.fr
USER=your_username

# MariaDB configuration
MYSQL_DATABASE=basedato
MYSQL_USER=userdato

# WordPress admin user
WP_ADMIN_USER=admin
WP_ADMIN_PASSWORD=your_admin_password
WP_ADMIN_EMAIL=admin@dlopez.42.fr

# WordPress additional user
WP_USER=dlopez
WP_USER_EMAIL=dlopez@student.42.fr
WP_USER_PASSWORD=your_user_password
```

3. **Add domain to `/etc/hosts`**:

```bash
sudo nano /etc/hosts
# Add this line:
127.0.0.1    dlopez.42.fr
```

### Installation and Execution

The Makefile provides several targets for managing the infrastructure:

```bash
# Build images and start all services
make

# Or step by step:
make build    # Build Docker images
make up       # Start containers in detached mode

# Stop containers (preserves data)
make down

# Clean containers and images
make clean

# Complete cleanup (removes volumes and data)
make fclean

# Rebuild everything from scratch
make re
```

### Accessing the Application

After running `make`:

1. **WordPress Site**: https://dlopez.42.fr
   - Your browser will warn about the self-signed certificate
   - Click "Advanced" → "Accept Risk and Continue"
   - WordPress should load automatically (no installation wizard)

2. **WordPress Admin Panel**: https://dlopez.42.fr/wp-admin
   - Username: Value from `WP_ADMIN_USER` in .env
   - Password: Value from `WP_ADMIN_PASSWORD` in .env

### Monitoring and Debugging

```bash
# Check container status
docker compose -f srcs/docker-compose.yml ps

# View logs
docker compose -f srcs/docker-compose.yml logs mariadb
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs nginx

# Access container shell
docker exec -it mariadb bash
docker exec -it wordpress bash
docker exec -it nginx bash

# Test database connection
docker exec -it mariadb mysql -u root -p

# Check persistent data
ls -la /home/${USER}/data/mariadb/
ls -la /home/${USER}/data/wordpress/
```

## Technical Design Choices

### Docker Concepts and Comparisons

#### Virtual Machines vs Docker

**Virtual Machines:**
- Include full operating system (kernel + userspace)
- Hardware virtualization through hypervisor
- Heavy resource consumption (GBs of RAM per VM)
- Slower startup time (minutes)
- Strong isolation at hardware level
- Each VM runs its own kernel

**Docker Containers:**
- Share host OS kernel
- OS-level virtualization using namespaces and cgroups
- Lightweight (MBs of disk space)
- Fast startup time (seconds)
- Process-level isolation
- More efficient resource utilization

**Why Docker for this project:**
Docker is ideal for this web stack because:
- Lightweight and fast iteration during development
- Easy to replicate exact environment
- Services can be independently scaled
- Simpler dependency management
- Better resource efficiency for multiple services on one host

#### Secrets vs Environment Variables

**Environment Variables:**
- Visible in container inspect (`docker inspect`)
- Appear in process listings
- Can be logged accidentally
- Passed as plaintext in docker-compose.yml
- Suitable for non-sensitive configuration

**Docker Secrets:**
- Stored in tmpfs (RAM) at `/run/secrets/`
- Never written to disk
- Not visible in `docker inspect`
- Can't be accidentally logged
- Automatically cleaned up when container stops
- **Used in this project** for database passwords

**Implementation in this project:**
```yaml
secrets:
  db_root_password:
    file: ../secrets/db_root_password.txt
  db_password:
    file: ../secrets/db_password.txt
```

Containers read passwords from `/run/secrets/db_password` instead of environment variables, preventing credential exposure.

#### Docker Network vs Host Network

**Host Network (`network_mode: host`):**
- Container uses host's network stack directly
- No network isolation
- Can cause port conflicts
- Container accessible at host IP
- Slightly better performance (no NAT overhead)

**Docker Bridge Network (Custom):**
- Containers on isolated virtual network
- Internal DNS for service discovery
- Port mapping required for external access
- Better security through isolation
- Containers can communicate by name

**Why Bridge Network in this project:**
```yaml
networks:
  inception-network:
    driver: bridge
```

Bridge network provides:
- **Service Discovery**: WordPress connects to `mariadb:3306` by name
- **Security**: MariaDB not accessible from outside
- **Flexibility**: Only NGINX exposed to host via port mapping
- **Isolation**: Services separated from host network

#### Docker Volumes vs Bind Mounts

**Docker Volumes:**
- Managed by Docker in `/var/lib/docker/volumes/`
- Created with `docker volume create`
- Portable across systems
- Docker handles permissions
- Can be backed up/restored with Docker tools

**Bind Mounts:**
- Map specific host path to container path
- Full control over location
- Require manual permission management
- Easier to inspect and backup manually
- Path must exist before container starts

**Implementation in this project:**
```yaml
volumes:
  mariadb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/${USER}/data/mariadb
  wordpress_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/${USER}/data/wordpress
```

**Why bind mounts:** The project requirements specify data must be stored in `/home/${USER}/data/`, making bind mounts necessary. This approach:
- Meets project requirements for specific data location
- Makes data easily accessible for backup
- Allows direct inspection without Docker commands
- Survives `docker system prune`

### Service Initialization and Dependencies

**Problem:** Services must start in correct order:
1. MariaDB must be ready before WordPress connects
2. WordPress must be running before NGINX forwards requests

**Solution - Health Checks:**
```yaml
mariadb:
  healthcheck:
    test: ["CMD-SHELL", "pgrep mysqld || exit 1"]
    interval: 5s
    timeout: 3s
    retries: 10
    start_period: 30s

wordpress:
  depends_on:
    mariadb:
      condition: service_healthy
```

This ensures WordPress only starts after MariaDB passes health checks.

### SSL/TLS Configuration

- Self-signed certificates generated automatically on container startup
- TLS 1.2 and 1.3 enabled (modern, secure protocols)
- Strong cipher suites (ECDHE-RSA-AES)
- HTTP automatically redirects to HTTPS
- Certificates valid for 365 days

### Persistent Data Strategy

**MariaDB Data** (`/var/lib/mysql`):
- Database files persist across container restarts
- First run: `init_db.sh` initializes database
- Subsequent runs: Detects existing data and skips initialization
- Ensures data isn't lost when containers are recreated

**WordPress Data** (`/var/www/html`):
- WordPress core files
- Uploaded media
- Themes and plugins
- Configuration (`wp-config.php`)
- Shared with NGINX for serving static files

## Resources

### Official Documentation

- [Docker Documentation](https://docs.docker.com/) - Complete Docker reference
- [Docker Compose Documentation](https://docs.docker.com/compose/) - Compose file specification
- [NGINX Documentation](https://nginx.org/en/docs/) - NGINX configuration reference
- [MariaDB Documentation](https://mariadb.com/kb/en/documentation/) - Database setup and administration
- [WordPress Developer Resources](https://developer.wordpress.org/) - WordPress configuration
- [WP-CLI Documentation](https://wp-cli.org/) - WordPress command-line tool

### Tutorials and Articles

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Docker Security](https://docs.docker.com/engine/security/)
- [NGINX FastCGI Configuration](https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/)
- [Docker Networking Deep Dive](https://docs.docker.com/network/)
- [Understanding Docker Volumes](https://docs.docker.com/storage/volumes/)


### AI Usage in This Project

**Claude AI (Anthropic) was used for:**

1. **Debugging and troubleshooting:**
   - Diagnosing MariaDB healthcheck failures
   - Fixing container dependency issues
   - Resolving nginx configuration problems
   - Addressing data persistence errors on container restart

2. **Script development:**
   - Implementing proper error handling and conditional logic
   - Adding secret file reading functionality

3. **Configuration optimization:**
   - NGINX FastCGI parameters for PHP-FPM
   - MariaDB server configuration for Docker environment
   - Docker Compose healthcheck strategies
   - TLS/SSL best practices

4. **Documentation:**
   - Explaining technical concepts (VMs vs containers, secrets vs env vars)
   - Creating this comprehensive README
   - Generating inline code comments

**Parts completed without AI:**
- Initial project structure and Dockerfile skeletons
- Selection of base images and services
- Environment variable planning
- Manual testing and validation
- Understanding project requirements

**How AI was used:**
- Provided complete code snippets that were reviewed and adapted
- Explained concepts to deepen understanding
- Suggested debugging approaches when issues arose
- Helped compare different technical approaches

---


**Last updated:** February 2026
