#!/bin/bash

# =============================================================================
# PROSORA GHOST BLOG CMS - DEPLOYMENT SCRIPT
# =============================================================================
# One-command deployment for modern Ghost Pro equivalent
# Usage: ./deploy.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emojis for better UX
ROCKET="🚀"
CHECK="✅"
WARNING="⚠️"
ERROR="❌"
INFO="ℹ️"
GEAR="⚙️"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

print_header() {
    echo -e "\n${PURPLE}=================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}=================================${NC}\n"
}

print_step() {
    echo -e "${BLUE}${GEAR} $1${NC}"
}

print_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}${WARNING} $1${NC}"
}

print_error() {
    echo -e "${RED}${ERROR} $1${NC}"
}

print_info() {
    echo -e "${CYAN}${INFO} $1${NC}"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

# =============================================================================
# WELCOME MESSAGE
# =============================================================================

clear
echo -e "${PURPLE}"
cat << "EOF"
 ____                                   
|  _ \ _ __ ___  ___  ___  _ __ __ _ 
| |_) | '__/ _ \/ __|/ _ \| '__/ _` |
|  __/| | | (_) \__ \ (_) | | | (_| |
|_|   |_|  \___/|___/\___/|_|  \__,_|

Ghost Blog CMS - Modern Stack Deployment
EOF
echo -e "${NC}"

print_header "${ROCKET} Welcome to Prosora Ghost Blog CMS Deployment!"

echo -e "This script will deploy a ${GREEN}modern, production-ready Ghost blog${NC} with:"
echo -e "  ${CHECK} Ghost 6 (Latest version)"
echo -e "  ${CHECK} Caddy (Auto-SSL web server)"
echo -e "  ${CHECK} MySQL 8 (Reliable database)"
echo -e "  ${CHECK} Redis (Caching layer)"
echo -e "  ${CHECK} Resend (Modern email)"
echo -e "  ${CHECK} Cloudinary (Media optimization)"
echo -e "  ${CHECK} Stripe (Payment processing)"
echo -e "  ${CHECK} TinyBird (Real-time analytics)"
echo -e "\n${CYAN}Total cost: ~$4/month (vs Ghost Pro $9-199/month)${NC}\n"

# =============================================================================
# PREREQUISITES CHECK
# =============================================================================

print_header "${GEAR} Checking Prerequisites"

print_step "Checking required commands..."
check_command "docker"
check_command "docker-compose"
check_command "curl"
check_command "git"

print_success "All required commands are available"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    print_warning "Running as root. Consider using a non-root user with sudo access."
fi

# Check Docker daemon
print_step "Checking Docker daemon..."
if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running. Please start Docker first."
    exit 1
fi
print_success "Docker daemon is running"

# =============================================================================
# ENVIRONMENT CONFIGURATION
# =============================================================================

print_header "${GEAR} Environment Configuration"

# Check if .env exists
if [[ ! -f ".env" ]]; then
    print_step "Creating environment configuration..."
    
    # Interactive setup
    echo -e "${YELLOW}Let's configure your Ghost blog!${NC}\n"
    
    # Domain configuration
    read -p "Enter your domain name (e.g., myblog.com): " DOMAIN
    while [[ -z "$DOMAIN" ]]; do
        print_warning "Domain name is required!"
        read -p "Enter your domain name (e.g., myblog.com): " DOMAIN
    done
    
    # Admin email
    read -p "Enter admin email address: " ADMIN_EMAIL
    while [[ -z "$ADMIN_EMAIL" ]]; do
        print_warning "Admin email is required!"
        read -p "Enter admin email address: " ADMIN_EMAIL
    done
    
    # Site title
    read -p "Enter your blog title: " SITE_TITLE
    [[ -z "$SITE_TITLE" ]] && SITE_TITLE="My Awesome Blog"
    
    # Generate secure passwords
    print_step "Generating secure passwords..."
    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
    MYSQL_PASSWORD=$(openssl rand -base64 32)
    SESSION_SECRET=$(openssl rand -base64 64)
    
    # Create .env file
    cat > .env << EOF
# =============================================================================
# PROSORA GHOST BLOG CMS - ENVIRONMENT CONFIGURATION
# Generated on $(date)
# =============================================================================

# Domain & Site Configuration
DOMAIN=$DOMAIN
GHOST_URL=https://$DOMAIN
SITE_TITLE=$SITE_TITLE
ADMIN_EMAIL=$ADMIN_EMAIL
GHOST_FROM_EMAIL=noreply@$DOMAIN

# Database Configuration
MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
MYSQL_DATABASE=ghost_production
MYSQL_USER=ghost_user
MYSQL_PASSWORD=$MYSQL_PASSWORD

# Security
SESSION_SECRET=$SESSION_SECRET

# Performance Settings
NODE_ENV=production
DEBUG_MODE=false
REDIS_ENABLED=true
REDIS_TTL=3600
IMAGE_OPTIMIZATION=true
IMAGE_QUALITY=80
RATE_LIMIT_MAX=100

# =============================================================================
# SERVICE INTEGRATIONS (Configure these later)
# =============================================================================

# Email Configuration (Resend)
RESEND_API_KEY=your_resend_api_key_here
RESEND_SMTP_HOST=smtp.resend.com
RESEND_SMTP_PORT=587
RESEND_SMTP_USER=resend

# Media Storage (Cloudinary)
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

# Payment Processing (Stripe)
STRIPE_PUBLISHABLE_KEY=pk_live_your_publishable_key_here
STRIPE_SECRET_KEY=sk_live_your_secret_key_here
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret_here

# Analytics (TinyBird)
TINYBIRD_API_TOKEN=your_tinybird_token_here
TINYBIRD_WORKSPACE=your_workspace_name
EOF

    print_success "Environment configuration created"
    print_info "You can edit .env file later to add service integrations"
else
    print_success "Environment configuration already exists"
fi

# =============================================================================
# DOCKER DEPLOYMENT
# =============================================================================

print_header "${ROCKET} Deploying Services"

print_step "Pulling Docker images..."
docker-compose pull

print_step "Starting services..."
docker-compose up -d

print_step "Waiting for services to be ready..."
sleep 30

# Check if services are running
print_step "Checking service health..."
if docker-compose ps | grep -q "Up"; then
    print_success "Services are running"
else
    print_error "Some services failed to start. Check logs with: docker-compose logs"
    exit 1
fi

# =============================================================================
# HEALTH CHECKS
# =============================================================================

print_header "${CHECK} Health Checks"

# Wait for MySQL to be ready
print_step "Waiting for MySQL to be ready..."
timeout=60
while ! docker-compose exec -T mysql mysqladmin ping -h localhost --silent; do
    sleep 2
    timeout=$((timeout - 2))
    if [[ $timeout -le 0 ]]; then
        print_error "MySQL failed to start within 60 seconds"
        exit 1
    fi
done
print_success "MySQL is ready"

# Wait for Ghost to be ready
print_step "Waiting for Ghost to be ready..."
timeout=120
while ! curl -s -o /dev/null -w "%{http_code}" http://localhost:2368 | grep -q "200\|301\|302"; do
    sleep 5
    timeout=$((timeout - 5))
    if [[ $timeout -le 0 ]]; then
        print_error "Ghost failed to start within 120 seconds"
        print_info "Check logs with: docker-compose logs ghost"
        exit 1
    fi
done
print_success "Ghost is ready"

# Check Caddy
print_step "Checking Caddy web server..."
if docker-compose ps caddy | grep -q "Up"; then
    print_success "Caddy is running"
else
    print_warning "Caddy may not be running properly"
fi

# =============================================================================
# SSL CERTIFICATE
# =============================================================================

print_header "${GEAR} SSL Certificate Setup"

print_step "Caddy will automatically obtain SSL certificates from Let's Encrypt"
print_info "This may take a few minutes on first run..."

# Wait a bit for Caddy to obtain certificates
sleep 10

print_success "SSL setup initiated (certificates will be obtained automatically)"

# =============================================================================
# FINAL SETUP INSTRUCTIONS
# =============================================================================

print_header "${CHECK} Deployment Complete!"

echo -e "${GREEN}${ROCKET} Your Ghost blog is now running!${NC}\n"

echo -e "${CYAN}Next Steps:${NC}"
echo -e "1. ${YELLOW}DNS Setup:${NC}"
echo -e "   - Point your domain '$DOMAIN' to this server's IP address"
echo -e "   - Create an A record: $DOMAIN -> $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_SERVER_IP')"
echo -e ""
echo -e "2. ${YELLOW}Ghost Admin Setup:${NC}"
echo -e "   - Visit: ${BLUE}https://$DOMAIN/ghost${NC}"
echo -e "   - Create your admin account"
echo -e "   - Configure your blog settings"
echo -e ""
echo -e "3. ${YELLOW}Service Integrations:${NC}"
echo -e "   - Edit .env file to add API keys for:"
echo -e "     • Resend (email delivery)"
echo -e "     • Cloudinary (media storage)"
echo -e "     • Stripe (payments)"
echo -e "     • TinyBird (analytics)"
echo -e "   - Restart services: ${BLUE}docker-compose restart${NC}"
echo -e ""

echo -e "${CYAN}Useful Commands:${NC}"
echo -e "  ${BLUE}docker-compose logs -f${NC}        # View logs"
echo -e "  ${BLUE}docker-compose restart${NC}        # Restart services"
echo -e "  ${BLUE}docker-compose down${NC}           # Stop services"
echo -e "  ${BLUE}./scripts/backup.sh${NC}           # Backup database"
echo -e "  ${BLUE}./scripts/update.sh${NC}           # Update Ghost"
echo -e ""

echo -e "${CYAN}Monitoring:${NC}"
echo -e "  ${BLUE}http://localhost:8080/health${NC}  # Health check"
echo -e "  ${BLUE}docker-compose ps${NC}             # Service status"
echo -e ""

echo -e "${GREEN}${CHECK} Deployment successful! Your Ghost blog is ready to use.${NC}"
echo -e "${PURPLE}${ROCKET} Welcome to the modern Ghost Pro experience for just $4/month!${NC}\n"

# =============================================================================
# OPTIONAL: OPEN BROWSER
# =============================================================================

if command -v open &> /dev/null; then
    read -p "Would you like to open your blog in the browser? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "https://$DOMAIN"
    fi
fi