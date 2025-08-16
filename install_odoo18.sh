
#!/bin/bash

# Odoo 18 Docker Installation Script - COMPLETE FIXED VERSION
# User: salam
# OS: Ubuntu 22 LTS
# Version: 2.4

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
USER="salam"
HOME_DIR="/home/$USER"
ODOO_DIR="$HOME_DIR/odoo18"

echo -e "${BLUE}=== Odoo 18 Docker Installation Script v2.4 ===${NC}"
echo -e "${YELLOW}Starting installation for user: $USER${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run this script as root (sudo)"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for service
wait_for_service() {
    local service=$1
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for $service to be ready..."
    while [ $attempt -le $max_attempts ]; do
        if systemctl is-active --quiet $service; then
            print_success "$service is running!"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    print_error "$service failed to start after $max_attempts attempts"
    return 1
}

# Update system
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install required packages
print_status "Installing required packages..."
apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    nginx \
    ufw \
    git \
    wget \
    unzip

# Check if Docker is already installed
if command_exists docker; then
    print_warning "Docker is already installed. Checking version..."
    docker --version
    
    # Check if Docker service is running
    if ! systemctl is-active --quiet docker; then
        print_status "Starting Docker service..."
        systemctl start docker
        systemctl enable docker
        wait_for_service docker
    else
        print_success "Docker service is already running!"
    fi
else
    # Install Docker
    print_status "Installing Docker..."
    
    # Remove old versions if any
    apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index
    apt update
    
    # Install Docker
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Wait for Docker to be ready
    wait_for_service docker
fi

# Add user to docker group
print_status "Adding user $USER to docker group..."
if ! groups $USER | grep -q docker; then
    usermod -aG docker $USER
    print_success "User $USER added to docker group"
else
    print_warning "User $USER is already in docker group"
fi

# Test Docker daemon
print_status "Testing Docker daemon..."
if ! docker ps >/dev/null 2>&1; then
    print_status "Docker daemon not responding, restarting..."
    systemctl restart docker
    wait_for_service docker
    
    # Test again
    if ! docker ps >/dev/null 2>&1; then
        print_error "Docker daemon still not responding. Manual intervention required."
        print_status "Try running: sudo systemctl status docker"
        exit 1
    fi
fi

print_success "Docker is working correctly!"

# Create directory structure
print_status "Creating directory structure..."
if [ -d "$ODOO_DIR" ]; then
    print_warning "Directory $ODOO_DIR already exists. Backing up..."
    mv "$ODOO_DIR" "${ODOO_DIR}_backup_$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
fi

mkdir -p $ODOO_DIR/config
mkdir -p $ODOO_DIR/addons
mkdir -p $ODOO_DIR/filestore
mkdir -p $ODOO_DIR/backups
mkdir -p $ODOO_DIR/logs
mkdir -p $ODOO_DIR/nginx/sites-available
mkdir -p $ODOO_DIR/nginx/ssl
mkdir -p $ODOO_DIR/instances/domain1/config
mkdir -p $ODOO_DIR/instances/domain1/addons
mkdir -p $ODOO_DIR/instances/domain1/filestore
mkdir -p $ODOO_DIR/instances/domain2/config
mkdir -p $ODOO_DIR/instances/domain2/addons
mkdir -p $ODOO_DIR/instances/domain2/filestore
mkdir -p $ODOO_DIR/instances/domain2/config
mkdir -p $ODOO_DIR/instances/domain2/addons
mkdir -p $ODOO_DIR/instances/domain2/filestore

# Set ownership
chown -R $USER:$USER $ODOO_DIR

# Create Docker volumes
print_status "Creating Docker volumes..."

# Create volumes one by one
if docker volume ls | grep -q odoo18_postgres_data; then
    print_warning "Volume odoo18_postgres_data already exists, skipping..."
else
    docker volume create odoo18_postgres_data
    print_success "Created volume: odoo18_postgres_data"
fi

if docker volume ls | grep -q odoo18_domain1_filestore; then
    print_warning "Volume odoo18_domain1_filestore already exists, skipping..."
else
    docker volume create odoo18_domain1_filestore
    print_success "Created volume: odoo18_domain1_filestore"
fi

if docker volume ls | grep -q odoo18_domain2_filestore; then
    print_warning "Volume odoo18_domain2_filestore already exists, skipping..."
else
    docker volume create odoo18_domain2_filestore
    print_success "Created volume: odoo18_domain2_filestore"
fi

if docker volume ls | grep -q odoo18_domain2_filestore; then
    print_warning "Volume odoo18_domain2_filestore already exists, skipping..."
else
    docker volume create odoo18_domain2_filestore
    print_success "Created volume: odoo18_domain2_filestore"
fi

# Create configuration files
print_status "Creating configuration files..."

# Create main docker-compose.yml
cat > $ODOO_DIR/docker-compose.yml << 'DOCKER_COMPOSE_EOF'
services:
  # PostgreSQL Database
  postgres:
    image: postgres:15
    container_name: odoo18_postgres
    environment:
      POSTGRES_DB: postgres
      POSTGRES_USER: odoo
      POSTGRES_PASSWORD: odoo_password_2024
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - postgres_data:/var/lib/postgresql/data/pgdata
    ports:
      - "5432:5432"
    restart: unless-stopped
    networks:
      - odoo_network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U odoo"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Odoo Instance 1 - domain1.tld
  odoo_domain1:
    image: odoo:18
    container_name: odoo18_domain1
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - HOST=postgres
      - USER=odoo
      - PASSWORD=odoo_password_2024
    volumes:
      - ./instances/domain1/config:/etc/odoo
      - ./instances/domain1/addons:/mnt/extra-addons
      - domain1_filestore:/var/lib/odoo/filestore
      - ./logs:/var/log/odoo
    ports:
      - "8069:8069"
    restart: unless-stopped
    networks:
      - odoo_network

  # Odoo Instance 2 - domain2.tld
  odoo_domain2:
    image: odoo:18
    container_name: odoo18_domain2
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - HOST=postgres
      - USER=odoo
      - PASSWORD=odoo_password_2024
    volumes:
      - ./instances/domain2/config:/etc/odoo
      - ./instances/domain2/addons:/mnt/extra-addons
      - domain2_filestore:/var/lib/odoo/filestore
      - ./logs:/var/log/odoo
    ports:
      - "8070:8069"
    restart: unless-stopped
    networks:
      - odoo_network

  # Odoo Instance 3 - domain2.tld
  odoo_domain2:
    image: odoo:18
    container_name: odoo18_domain2
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - HOST=postgres
      - USER=odoo
      - PASSWORD=odoo_password_2024
    volumes:
      - ./instances/domain2/config:/etc/odoo
      - ./instances/domain2/addons:/mnt/extra-addons
      - domain2_filestore:/var/lib/odoo/filestore
      - ./logs:/var/log/odoo
    ports:
      - "8071:8069"
    restart: unless-stopped
    networks:
      - odoo_network

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: odoo18_nginx
    depends_on:
      - odoo_domain1
      - odoo_domain2
      - odoo_domain2
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/sites-available:/etc/nginx/sites-available
      - ./nginx/ssl:/etc/nginx/ssl
      - ./logs:/var/log/nginx
    ports:
      - "80:80"
      - "443:443"
    restart: unless-stopped
    networks:
      - odoo_network

volumes:
  postgres_data:
    external: true
    name: odoo18_postgres_data
  domain1_filestore:
    external: true
    name: odoo18_domain1_filestore
  domain2_filestore:
    external: true
    name: odoo18_domain2_filestore
  domain2_filestore:
    external: true
    name: odoo18_domain2_filestore

networks:
  odoo_network:
    driver: bridge
DOCKER_COMPOSE_EOF

# Function to create Odoo configuration
create_odoo_config() {
    local instance=$1
    
    cat > $ODOO_DIR/instances/$instance/config/odoo.conf << ODOO_CONFIG_EOF
[options]
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/mnt/extra-addons
data_dir = /var/lib/odoo
logfile = /var/log/odoo/odoo-$instance.log
log_level = info
log_handler = :INFO
logrotate = True
max_cron_threads = 1
workers = 2
limit_memory_hard = 2684354560
limit_memory_soft = 2147483648
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200
max_file_upload_size = 524288000
proxy_mode = True
without_demo = False

# Database settings
db_host = postgres
db_port = 5432
db_user = odoo
db_password = odoo_password_2024
db_maxconn = 64

# Security
admin_passwd = admin_master_password_2024
list_db = True
dbfilter = ^$instance.*$

# Server settings
xmlrpc_port = 8069
longpolling_port = 8072
ODOO_CONFIG_EOF
}

# Create configurations for all instances
print_status "Creating Odoo configurations..."
create_odoo_config "domain1"
create_odoo_config "domain2"
create_odoo_config "domain2"

# Create Nginx configuration
print_status "Creating Nginx configurations..."

cat > $ODOO_DIR/nginx/nginx.conf << 'NGINX_CONF_EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 500M;
    client_body_buffer_size 128k;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 4k;

    # Gzip Settings
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Upstream definitions
    upstream odoo_domain1 {
        server odoo_domain1:8069;
    }

    upstream odoo_domain2 {
        server odoo_domain2:8069;
    }

    upstream odoo_domain2 {
        server odoo_domain2:8069;
    }

    # Include site configurations
    include /etc/nginx/sites-available/*.conf;
}
NGINX_CONF_EOF

# Function to create Nginx site configuration
create_nginx_site() {
    local instance=$1
    local domain=$2
    
    cat > $ODOO_DIR/nginx/sites-available/$instance.conf << NGINX_SITE_EOF
server {
    listen 80;
    server_name $domain;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Proxy settings
    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;
    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;

    # Log files
    access_log /var/log/nginx/${instance}_access.log;
    error_log /var/log/nginx/${instance}_error.log;

    # Handle longpolling requests
    location /longpolling {
        proxy_pass http://odoo_$instance;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # Handle all other requests
    location / {
        proxy_pass http://odoo_$instance;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_redirect off;
    }

    # Static files caching
    location ~* /web/static/ {
        proxy_cache_valid 200 90m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://odoo_$instance;
    }
}
NGINX_SITE_EOF
}

# Create site configurations
print_status "Creating Nginx site configurations..."
create_nginx_site "domain1" "domain1.tld"
create_nginx_site "domain2" "domain2.tld"
create_nginx_site "domain2" "domain2.tld"

# Create management scripts
print_status "Creating management scripts..."

# Create start script
cat > $ODOO_DIR/start.sh << 'START_SCRIPT_EOF'
#!/bin/bash
cd /home/salam/odoo18
echo "Starting Odoo 18 Multi-Instance Setup..."
docker compose up -d
echo "Waiting for services to be ready..."
sleep 30
docker compose ps
echo ""
echo "Access URLs:"
echo "Instance 1: http://domain1.tld or http://localhost:8069"
echo "Instance 2: http://domain2.tld or http://localhost:8070"
echo "Instance 3: http://domain2.tld or http://localhost:8071"
echo ""
echo "Database credentials:"
echo "User: odoo"
echo "Password: odoo_password_2024"
echo "Master Password: admin_master_password_2024"
START_SCRIPT_EOF

# Create stop script
cat > $ODOO_DIR/stop.sh << 'STOP_SCRIPT_EOF'
#!/bin/bash
cd /home/salam/odoo18
echo "Stopping Odoo 18 Multi-Instance Setup..."
docker compose down
echo "All services stopped."
STOP_SCRIPT_EOF

# Create restart script
cat > $ODOO_DIR/restart.sh << 'RESTART_SCRIPT_EOF'
#!/bin/bash
cd /home/salam/odoo18
echo "Restarting Odoo 18 Multi-Instance Setup..."
docker compose down
docker compose up -d
echo "All services restarted."
RESTART_SCRIPT_EOF

# Create logs script
cat > $ODOO_DIR/logs.sh << 'LOGS_SCRIPT_EOF'
#!/bin/bash
cd /home/salam/odoo18
if [ -z "$1" ]; then
    echo "Usage: ./logs.sh [service_name]"
    echo "Available services: postgres, odoo_domain1, odoo_domain2, odoo_domain2, nginx"
    echo "Or use 'all' to see all logs"
    exit 1
fi

if [ "$1" = "all" ]; then
    docker compose logs -f
else
    docker compose logs -f $1
fi
LOGS_SCRIPT_EOF

# Create backup script
cat > $ODOO_DIR/backup.sh << 'BACKUP_SCRIPT_EOF'
#!/bin/bash
cd /home/salam/odoo18

if [ -z "$1" ]; then
    echo "Usage: ./backup.sh [database_name]"
    echo "Example: ./backup.sh domain1_production"
    exit 1
fi

DB_NAME=$1
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql"

mkdir -p $BACKUP_DIR

echo "Backing up database: $DB_NAME"
docker exec odoo18_postgres pg_dump -U odoo $DB_NAME > $BACKUP_FILE

if [ $? -eq 0 ]; then
    echo "Backup successful: $BACKUP_FILE"
else
    echo "Backup failed!"
    exit 1
fi
BACKUP_SCRIPT_EOF

# Make scripts executable
chmod +x $ODOO_DIR/start.sh
chmod +x $ODOO_DIR/stop.sh
chmod +x $ODOO_DIR/restart.sh
chmod +x $ODOO_DIR/logs.sh
chmod +x $ODOO_DIR/backup.sh

# Set final ownership
chown -R $USER:$USER $ODOO_DIR

# Configure firewall
print_status "Configuring firewall..."
ufw allow ssh
ufw allow 80
ufw allow 443
ufw allow 8069
ufw allow 8070
ufw allow 8071
ufw allow 8072
ufw allow 8073
ufw allow 8074
ufw --force enable

# Create systemd service for auto-start
print_status "Creating systemd service..."
cat > /etc/systemd/system/odoo18-multi.service << SYSTEMD_SERVICE_EOF
[Unit]
Description=Odoo 18 Multi-Instance Docker Setup
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/salam/odoo18
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
User=salam
Group=docker

[Install]
WantedBy=multi-user.target
SYSTEMD_SERVICE_EOF

systemctl daemon-reload
systemctl enable odoo18-multi.service

print_success "Installation completed successfully!"
print_status "================================"
print_status "INSTALLATION SUMMARY"
print_status "================================"
print_status "Installation directory: $ODOO_DIR"
print_status "Docker volumes created for persistent data"
print_status "Three Odoo instances configured:"
print_status "  - domain1.tld (Port 8069)"
print_status "  - domain2.tld (Port 8070)"
print_status "  - domain2.tld (Port 8071)"
print_status ""
print_status "Management scripts created:"
print_status "  - start.sh    : Start all services"
print_status "  - stop.sh     : Stop all services"
print_status "  - restart.sh  : Restart all services"
print_status "  - logs.sh     : View logs"
print_status "  - backup.sh   : Backup database"
print_status ""
print_status "Next steps:"
print_status "1. Logout and login again: su - salam"
print_status "2. Go to Odoo directory: cd $ODOO_DIR"
print_status "3. Start services: ./start.sh"
print_status "4. Access via browser at the configured URLs"
print_status ""
print_warning "IMPORTANT: Change default passwords after first login!"
print_status "Master Password: admin_master_password_2024"
print_status "DB Password: odoo_password_2024"
print_status "================================"
