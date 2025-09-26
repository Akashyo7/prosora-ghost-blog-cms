#!/bin/bash

# Prosora Ghost Blog CMS - Update Script
# Automated updates for Ghost, Docker images, and system components

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backups"
LOG_DIR="$PROJECT_DIR/logs"

# Create directories
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

# Load environment variables
if [[ -f "$PROJECT_DIR/.env" ]]; then
    source "$PROJECT_DIR/.env"
fi

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/update.log"
}

# Print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}✗${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
        "STEP")
            echo -e "${CYAN}▶${NC} $message"
            ;;
    esac
}

# Confirmation prompt
confirm() {
    local message=$1
    local default=${2:-"n"}
    
    if [[ "$default" == "y" ]]; then
        local prompt="$message [Y/n]: "
    else
        local prompt="$message [y/N]: "
    fi
    
    read -p "$prompt" -r response
    response=${response:-$default}
    
    [[ "$response" =~ ^[Yy]$ ]]
}

# Check prerequisites
check_prerequisites() {
    print_status "STEP" "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_status "ERROR" "Docker is not running"
        exit 1
    fi
    
    # Check if project directory exists
    if [[ ! -f "$PROJECT_DIR/docker-compose.yml" ]]; then
        print_status "ERROR" "docker-compose.yml not found in $PROJECT_DIR"
        exit 1
    fi
    
    # Check if services are running
    cd "$PROJECT_DIR"
    if ! docker-compose ps | grep -q "Up"; then
        print_status "WARNING" "No services appear to be running"
        if ! confirm "Continue anyway?"; then
            exit 1
        fi
    fi
    
    print_status "OK" "Prerequisites check passed"
}

# Create backup before update
create_backup() {
    print_status "STEP" "Creating backup before update..."
    
    if [[ -f "$PROJECT_DIR/scripts/backup.sh" ]]; then
        if "$PROJECT_DIR/scripts/backup.sh" --quick; then
            print_status "OK" "Backup created successfully"
        else
            print_status "ERROR" "Backup failed"
            if ! confirm "Continue without backup? (NOT RECOMMENDED)"; then
                exit 1
            fi
        fi
    else
        print_status "WARNING" "Backup script not found, skipping backup"
        if ! confirm "Continue without backup? (NOT RECOMMENDED)"; then
            exit 1
        fi
    fi
}

# Update Docker images
update_docker_images() {
    print_status "STEP" "Updating Docker images..."
    
    cd "$PROJECT_DIR"
    
    # Pull latest images
    if docker-compose pull; then
        print_status "OK" "Docker images updated successfully"
    else
        print_status "ERROR" "Failed to update Docker images"
        return 1
    fi
    
    # Show image changes
    print_status "INFO" "Image update summary:"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}\t{{.Size}}" | grep -E "(ghost|mysql|redis|caddy|containrrr/watchtower)"
}

# Update Ghost CMS
update_ghost() {
    print_status "STEP" "Updating Ghost CMS..."
    
    cd "$PROJECT_DIR"
    
    # Get current Ghost version
    local current_version=$(docker-compose exec -T ghost ghost version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    print_status "INFO" "Current Ghost version: $current_version"
    
    # Stop Ghost service
    print_status "INFO" "Stopping Ghost service..."
    docker-compose stop ghost
    
    # Pull latest Ghost image
    docker-compose pull ghost
    
    # Start Ghost service
    print_status "INFO" "Starting Ghost service..."
    docker-compose up -d ghost
    
    # Wait for Ghost to be ready
    print_status "INFO" "Waiting for Ghost to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if docker-compose exec -T ghost ghost status >/dev/null 2>&1; then
            break
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            print_status "ERROR" "Ghost failed to start after update"
            return 1
        fi
        
        sleep 2
        ((attempt++))
    done
    
    # Get new Ghost version
    local new_version=$(docker-compose exec -T ghost ghost version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    
    if [[ "$current_version" != "$new_version" ]]; then
        print_status "OK" "Ghost updated from $current_version to $new_version"
    else
        print_status "INFO" "Ghost is already up to date ($current_version)"
    fi
}

# Update system packages (if running on Linux)
update_system_packages() {
    if [[ "$(uname)" == "Linux" ]]; then
        print_status "STEP" "Updating system packages..."
        
        if command -v apt-get >/dev/null 2>&1; then
            # Ubuntu/Debian
            if confirm "Update system packages with apt?"; then
                sudo apt-get update && sudo apt-get upgrade -y
                print_status "OK" "System packages updated"
            fi
        elif command -v yum >/dev/null 2>&1; then
            # CentOS/RHEL
            if confirm "Update system packages with yum?"; then
                sudo yum update -y
                print_status "OK" "System packages updated"
            fi
        else
            print_status "INFO" "Unknown package manager, skipping system updates"
        fi
    else
        print_status "INFO" "Not running on Linux, skipping system package updates"
    fi
}

# Update Docker and Docker Compose
update_docker() {
    print_status "STEP" "Checking Docker updates..."
    
    # Check Docker version
    local docker_version=$(docker --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
    print_status "INFO" "Current Docker version: $docker_version"
    
    # Check Docker Compose version
    local compose_version=$(docker-compose --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
    print_status "INFO" "Current Docker Compose version: $compose_version"
    
    if [[ "$(uname)" == "Linux" ]]; then
        if confirm "Update Docker and Docker Compose?"; then
            # Update Docker (Ubuntu/Debian method)
            if command -v apt-get >/dev/null 2>&1; then
                curl -fsSL https://get.docker.com -o get-docker.sh
                sudo sh get-docker.sh
                rm get-docker.sh
                
                # Update Docker Compose
                local latest_compose=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -o '"tag_name": "[^"]*' | grep -o '[^"]*$')
                sudo curl -L "https://github.com/docker/compose/releases/download/${latest_compose}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                sudo chmod +x /usr/local/bin/docker-compose
                
                print_status "OK" "Docker and Docker Compose updated"
            fi
        fi
    else
        print_status "INFO" "Please update Docker Desktop manually on macOS/Windows"
    fi
}

# Update SSL certificates
update_ssl_certificates() {
    print_status "STEP" "Updating SSL certificates..."
    
    cd "$PROJECT_DIR"
    
    # Reload Caddy to refresh certificates
    if docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile; then
        print_status "OK" "SSL certificates refreshed"
    else
        print_status "WARNING" "Failed to refresh SSL certificates"
    fi
}

# Update configuration files
update_configurations() {
    print_status "STEP" "Checking configuration updates..."
    
    # Check if there are any configuration updates needed
    local config_updated=false
    
    # Update Caddyfile if needed
    if [[ -f "$PROJECT_DIR/config/caddy/Caddyfile" ]]; then
        print_status "INFO" "Caddyfile is present"
    fi
    
    # Update MySQL configuration if needed
    if [[ -f "$PROJECT_DIR/config/mysql/my.cnf" ]]; then
        print_status "INFO" "MySQL configuration is present"
    fi
    
    # Update Redis configuration if needed
    if [[ -f "$PROJECT_DIR/config/redis/redis.conf" ]]; then
        print_status "INFO" "Redis configuration is present"
    fi
    
    if [[ "$config_updated" == true ]]; then
        print_status "INFO" "Restarting services to apply configuration changes..."
        docker-compose restart
    fi
}

# Optimize database
optimize_database() {
    print_status "STEP" "Optimizing database..."
    
    cd "$PROJECT_DIR"
    
    # Run database optimization
    if docker-compose exec -T mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "
        OPTIMIZE TABLE ${MYSQL_DATABASE}.posts;
        OPTIMIZE TABLE ${MYSQL_DATABASE}.users;
        OPTIMIZE TABLE ${MYSQL_DATABASE}.tags;
        OPTIMIZE TABLE ${MYSQL_DATABASE}.posts_tags;
        ANALYZE TABLE ${MYSQL_DATABASE}.posts;
        ANALYZE TABLE ${MYSQL_DATABASE}.users;
    " >/dev/null 2>&1; then
        print_status "OK" "Database optimized successfully"
    else
        print_status "WARNING" "Database optimization failed"
    fi
}

# Clean up old data
cleanup_old_data() {
    print_status "STEP" "Cleaning up old data..."
    
    # Clean up old Docker images
    if confirm "Remove unused Docker images?"; then
        docker image prune -f
        print_status "OK" "Unused Docker images removed"
    fi
    
    # Clean up old backups (keep last 30 days)
    if [[ -d "$BACKUP_DIR" ]]; then
        find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +30 -delete 2>/dev/null || true
        print_status "OK" "Old backups cleaned up"
    fi
    
    # Clean up old logs (keep last 7 days)
    if [[ -d "$LOG_DIR" ]]; then
        find "$LOG_DIR" -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
        print_status "OK" "Old logs cleaned up"
    fi
    
    # Clean up Docker system
    if confirm "Run Docker system cleanup?"; then
        docker system prune -f
        print_status "OK" "Docker system cleaned up"
    fi
}

# Verify system health after update
verify_system_health() {
    print_status "STEP" "Verifying system health..."
    
    cd "$PROJECT_DIR"
    
    # Check if all services are running
    local failed_services=()
    local services=$(docker-compose ps --services)
    
    for service in $services; do
        local status=$(docker-compose ps -q "$service" | xargs docker inspect --format='{{.State.Status}}' 2>/dev/null || echo "not_found")
        
        if [[ "$status" != "running" ]]; then
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        print_status "ERROR" "Services not running: ${failed_services[*]}"
        return 1
    fi
    
    # Test Ghost accessibility
    local ghost_url="${GHOST_URL:-http://localhost}"
    if curl -f -s "$ghost_url" >/dev/null; then
        print_status "OK" "Ghost is accessible"
    else
        print_status "ERROR" "Ghost is not accessible"
        return 1
    fi
    
    # Test database connectivity
    if docker-compose exec -T mysql mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" ping >/dev/null 2>&1; then
        print_status "OK" "Database is accessible"
    else
        print_status "ERROR" "Database is not accessible"
        return 1
    fi
    
    print_status "OK" "System health verification passed"
}

# Show update summary
show_update_summary() {
    print_status "STEP" "Update Summary"
    
    cd "$PROJECT_DIR"
    
    echo
    echo "=== Update Summary ==="
    echo "Timestamp: $(date)"
    echo
    
    # Show service versions
    echo "Service Versions:"
    echo "- Ghost: $(docker-compose exec -T ghost ghost version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo 'unknown')"
    echo "- MySQL: $(docker-compose exec -T mysql mysql --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo 'unknown')"
    echo "- Redis: $(docker-compose exec -T redis redis-server --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo 'unknown')"
    echo
    
    # Show system status
    echo "System Status:"
    docker-compose ps
    echo
    
    # Show resource usage
    echo "Resource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
    echo
}

# Main update functions
update_all() {
    print_status "INFO" "Starting complete system update..."
    
    check_prerequisites
    create_backup
    update_docker_images
    update_ghost
    update_ssl_certificates
    update_configurations
    optimize_database
    cleanup_old_data
    verify_system_health
    show_update_summary
    
    print_status "OK" "Complete system update finished successfully!"
}

update_ghost_only() {
    print_status "INFO" "Starting Ghost-only update..."
    
    check_prerequisites
    create_backup
    update_ghost
    verify_system_health
    
    print_status "OK" "Ghost update finished successfully!"
}

update_docker_only() {
    print_status "INFO" "Starting Docker images update..."
    
    check_prerequisites
    create_backup
    update_docker_images
    verify_system_health
    
    print_status "OK" "Docker images update finished successfully!"
}

update_security() {
    print_status "INFO" "Starting security updates..."
    
    check_prerequisites
    create_backup
    update_system_packages
    update_docker
    update_ssl_certificates
    verify_system_health
    
    print_status "OK" "Security updates finished successfully!"
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --all           Update everything (default)"
    echo "  --ghost         Update Ghost CMS only"
    echo "  --docker        Update Docker images only"
    echo "  --security      Update system packages and security components"
    echo "  --ssl           Update SSL certificates only"
    echo "  --cleanup       Clean up old data only"
    echo "  --verify        Verify system health only"
    echo "  --summary       Show current system summary"
    echo "  --help          Show this help message"
    echo
    echo "Examples:"
    echo "  $0                    # Update everything"
    echo "  $0 --ghost           # Update Ghost only"
    echo "  $0 --docker          # Update Docker images only"
    echo "  $0 --security        # Security updates only"
}

# Main script logic
main() {
    case "${1:-}" in
        --all|"")
            update_all
            ;;
        --ghost)
            update_ghost_only
            ;;
        --docker)
            update_docker_only
            ;;
        --security)
            update_security
            ;;
        --ssl)
            check_prerequisites
            update_ssl_certificates
            ;;
        --cleanup)
            cleanup_old_data
            ;;
        --verify)
            verify_system_health
            ;;
        --summary)
            show_update_summary
            ;;
        --help)
            show_usage
            ;;
        *)
            echo "Error: Unknown option $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"