# User Documentation

## What Services Are Provided

This project provides a complete WordPress website infrastructure with three services:

1. **WordPress** - A content management system where you can create and manage website content
2. **NGINX** - A web server that handles incoming connections and serves your website securely over HTTPS
3. **MariaDB** - A database that stores all your WordPress data (posts, pages, users, settings)

All services run in isolated Docker containers and work together to provide a fully functional website.

## Starting and Stopping the Project

### Starting the Services

Open a terminal in the project root directory and run:

```bash
make
```

This will:
- Build all Docker images (first time only)
- Start all three containers
- Set up the database automatically
- Install and configure WordPress

Wait about 30-60 seconds for all services to become ready.

### Stopping the Services

To stop all services while keeping your data:

```bash
make down
```

Your website data, database, and all content will be preserved.

### Restarting After Stopping

Simply run `make` again:

```bash
make
```

The services will restart with all your existing data intact.

## Accessing the Website

### Viewing Your Website

1. Open your web browser
2. Go to: **https://dlopez.42.fr**
3. Your browser will show a security warning (because we use a self-signed certificate)
4. Click **Advanced** → **Accept the Risk and Continue**
5. Your WordPress website will load

### Accessing the Administration Panel

1. Go to: **https://dlopez.42.fr/wp-admin**
2. Log in with your admin credentials (see Credentials section below)
3. You can now manage your website content, install themes, add plugins, etc.

## Managing Credentials

### Where Credentials Are Stored

All passwords are stored in two locations:

1. **Secret files** (for Docker containers):
   - `srcs/secrets/db_root_password.txt` - Database root password
   - `srcs/secrets/db_password.txt` - Database user password

2. **Environment file** (for WordPress users):
   - `srcs/.env` - Contains WordPress admin and user credentials

### Viewing Your WordPress Login Credentials

Open the file `srcs/.env` and look for these lines:

```bash
WP_ADMIN_USER=admin                    # Your admin username
WP_ADMIN_PASSWORD=your_admin_password  # Your admin password
WP_ADMIN_EMAIL=admin@dlopez.42.fr      # Admin email
```

Use the `WP_ADMIN_USER` and `WP_ADMIN_PASSWORD` values to log in to WordPress.

### Changing Passwords

**To change the WordPress admin password:**

1. Stop the services: `make down`
2. Delete all data: `make fclean`
3. Edit `srcs/.env` and change `WP_ADMIN_PASSWORD=new_password`
4. Restart: `make`

**To change database passwords:**

1. Stop the services: `make down`
2. Delete all data: `make fclean`
3. Edit `srcs/secrets/db_root_password.txt` and `srcs/secrets/db_password.txt`
4. Restart: `make`

⚠️ **Warning:** Changing passwords requires deleting all data and starting fresh.

## Checking Service Status

### Quick Status Check

To see if all services are running:

```bash
docker compose -f srcs/docker-compose.yml ps
```

You should see three containers with "Up" status:
- `mariadb` - Running
- `wordpress` - Running  
- `nginx` - Running

### Detailed Health Check

Check each service individually:

```bash
# Check MariaDB (database)
docker compose -f srcs/docker-compose.yml logs mariadb

# Check WordPress
docker compose -f srcs/docker-compose.yml logs wordpress

# Check NGINX (web server)
docker compose -f srcs/docker-compose.yml logs nginx
```

Look for error messages in red. If everything is working, you'll see normal startup messages.

### Testing the Website Connection

From your terminal:

```bash
curl -Ik https://dlopez.42.fr
```

You should see `HTTP/2 200` or `HTTP/2 302` in the response, indicating the website is accessible.

## Common Issues

### "Site can't be reached"

**Problem:** Browser can't find dlopez.42.fr

**Solution:** Make sure you added the domain to `/etc/hosts`:
```bash
# Check if it's there
cat /etc/hosts | grep dlopez

# If not, add it
echo "127.0.0.1 dlopez.42.fr" | sudo tee -a /etc/hosts
```

### "Database connection error"

**Problem:** WordPress can't connect to the database

**Solution:** Wait 30-60 seconds after starting. If it persists:
```bash
make down
make up
```

### Services won't start

**Problem:** Containers fail to start

**Solution:** Clean everything and rebuild:
```bash
make fclean
make
```

### Forgot admin password

**Problem:** Can't log in to WordPress admin panel

**Solution:** Check your credentials in `srcs/.env`:
```bash
cat srcs/.env | grep WP_ADMIN
```

## Getting Help

If you encounter issues:

1. Check the logs: `docker compose -f srcs/docker-compose.yml logs`
2. Verify all containers are running: `docker compose -f srcs/docker-compose.yml ps`
3. Try a clean restart: `make fclean && make`
4. Contact your system administrator or the developer who set up this project
