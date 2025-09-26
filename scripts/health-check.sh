#!/bin/bash

# Prosora Ghost Blog CMS - Health Check Script
# Comprehensive health monitoring for all system components

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
LOG_DIR="$PROJECT_DIR/logs"
HEALTH_LOG="$LOG_DIR/health-check.log"

# Create log directory
mkdir -p "$LOG_DIR"

# Load environment variables
if [[ -f "$PROJECT_DIR/.env" ]]; then
    source "$PROJECT_DIR/.env"
fi

# Default values
GHOST_URL="${GHOST_URL:-http://localhost}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-10}"
ALERT_EMAIL="${ALERT_EMAIL:-}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

# Health check results
HEALTH_STATUS="HEALTHY"
FAILED_CHECKS=()
WARNING_CHECKS=()
HEALTH_DETAILS=()

# Logging function
log_health() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$HEALTH_LOG"
}

# Print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "PASS")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "FAIL")
            echo -e "${RED}✗${NC} $message"
            HEALTH_STATUS="CRITICAL"
            FAILED_CHECKS+=("$message")
            ;;
        "WARN")
            echo -e "${YELLOW}⚠${NC} $message"
            if [[ "$HEALTH_STATUS" == "HEALTHY" ]]; then
                HEALTH_STATUS="WARNING"
            fi
            WARNING_CHECKS+=("$message")
            ;;
        "INFO")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
        "SKIP")
            echo -e "${CYAN}⊘${NC} $message"
            ;;
    esac
    
    HEALTH_DETAILS+=("$status: $message")
    log_health "$status" "$message"
}

# Check if Docker is running
check_docker() {
    echo "=== Docker Health Check ==="
    
    if command -v docker >/dev/null 2>&1; then
        if docker info >/dev/null 2>&1; then
            print_status "PASS" "Docker daemon is running"
            
            # Check Docker version
            local docker_version=$(docker --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
            print_status "INFO" "Docker version: $docker_version"
            
            # Check Docker disk usage
            local disk_usage=$(docker system df --format "table {{.Type}}\t{{.Size}}" | tail -n +2)
            print_status "INFO" "Docker disk usage:"
            echo "$disk_usage" | while read -r line; do
                echo "    $line"
            done
            
        else
            print_status "FAIL" "Docker daemon is not responding"
            return 1
        fi
    else
        print_status "FAIL" "Docker is not installed"
        return 1
    fi
}

# Check Docker Compose services
check_docker_compose() {
    echo
    echo "=== Docker Compose Services ==="
    
    cd "$PROJECT_DIR"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        print_status "FAIL" "docker-compose.yml not found"
        return 1
    fi
    
    # Get list of services
    local services=$(docker-compose config --services 2>/dev/null || echo "")
    
    if [[ -z "$services" ]]; then
        print_status "FAIL" "No services found in docker-compose.yml"
        return 1
    fi
    
    # Check each service
    for service in $services; do
        local container_id=$(docker-compose ps -q "$service" 2>/dev/null || echo "")
        
        if [[ -n "$container_id" ]]; then
            local status=$(docker inspect --format='{{.State.Status}}' "$container_id" 2>/dev/null || echo "unknown")
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null || echo "none")
            
            case $status in
                "running")
                    if [[ "$health" == "healthy" ]] || [[ "$health" == "none" ]]; then
                        print_status "PASS" "Service $service is running"
                    elif [[ "$health" == "unhealthy" ]]; then
                        print_status "FAIL" "Service $service is unhealthy"
                    else
                        print_status "WARN" "Service $service health status: $health"
                    fi
                    ;;
                "exited")
                    print_status "FAIL" "Service $service has exited"
                    ;;
                *)
                    print_status "WARN" "Service $service status: $status"
                    ;;
            esac
        else
            print_status "FAIL" "Service $service is not running"
        fi
    done
}

# Check Ghost CMS
check_ghost() {
    echo
    echo "=== Ghost CMS Health Check ==="
    
    cd "$PROJECT_DIR"
    
    # Check if Ghost container is running
    local ghost_container=$(docker-compose ps -q ghost 2>/dev/null || echo "")
    
    if [[ -z "$ghost_container" ]]; then
        print_status "FAIL" "Ghost container not found"
        return 1
    fi
    
    # Check Ghost process inside container
    if docker-compose exec -T ghost ps aux | grep -q "node current/index.js"; then
        print_status "PASS" "Ghost process is running"
    else
        print_status "FAIL" "Ghost process not found"
    fi
    
    # Check Ghost version
    local ghost_version=$(docker-compose exec -T ghost ghost version 2>/dev/null | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
    print_status "INFO" "Ghost version: $ghost_version"
    
    # Check Ghost status
    if docker-compose exec -T ghost ghost status >/dev/null 2>&1; then
        print_status "PASS" "Ghost status check passed"
    else
        print_status "WARN" "Ghost status check failed"
    fi
    
    # Test HTTP response
    if command -v curl >/dev/null 2>&1; then
        local response_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "$HEALTH_CHECK_TIMEOUT" "$GHOST_URL" || echo "000")
        
        case $response_code in
            200)
                print_status "PASS" "Ghost HTTP response: $response_code"
                ;;
            000)
                print_status "FAIL" "Ghost is not accessible (connection failed)"
                ;;
            *)
                print_status "WARN" "Ghost HTTP response: $response_code"
                ;;
        esac
        
        # Test response time
        local response_time=$(curl -s -o /dev/null -w "%{time_total}" --connect-timeout "$HEALTH_CHECK_TIMEOUT" "$GHOST_URL" 2>/dev/null || echo "0")
        local response_ms=$(echo "$response_time * 1000" | bc -l 2>/dev/null | cut -d. -f1 || echo "0")
        
        if [[ $response_ms -lt 1000 ]]; then
            print_status "PASS" "Ghost response time: ${response_ms}ms"
        elif [[ $response_ms -lt 3000 ]]; then
            print_status "WARN" "Ghost response time: ${response_ms}ms (slow)"
        else
            print_status "FAIL" "Ghost response time: ${response_ms}ms (very slow)"
        fi
    else
        print_status "SKIP" "curl not available, skipping HTTP checks"
    fi
}

# Check MySQL database
check_mysql() {
    echo
    echo "=== MySQL Database Health Check ==="
    
    cd "$PROJECT_DIR"
    
    # Check if MySQL container is running
    local mysql_container=$(docker-compose ps -q mysql 2>/dev/null || echo "")
    
    if [[ -z "$mysql_container" ]]; then
        print_status "FAIL" "MySQL container not found"
        return 1
    fi
    
    # Check MySQL process
    if docker-compose exec -T mysql ps aux | grep -q "mysqld"; then
        print_status "PASS" "MySQL process is running"
    else
        print_status "FAIL" "MySQL process not found"
    fi
    
    # Check MySQL version
    local mysql_version=$(docker-compose exec -T mysql mysql --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 || echo "unknown")
    print_status "INFO" "MySQL version: $mysql_version"
    
    # Test database connectivity
    if [[ -n "$MYSQL_ROOT_PASSWORD" ]]; then
        if docker-compose exec -T mysql mysqladmin -u root -p"$MYSQL_ROOT_PASSWORD" ping >/dev/null 2>&1; then
            print_status "PASS" "MySQL connectivity test passed"
            
            # Check database size
            local db_size=$(docker-compose exec -T mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
                SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'DB Size (MB)'
                FROM information_schema.tables
                WHERE table_schema='${MYSQL_DATABASE:-ghost}';
            " 2>/dev/null | tail -n 1 || echo "unknown")
            
            if [[ "$db_size" != "unknown" ]] && [[ "$db_size" != "NULL" ]]; then
                print_status "INFO" "Database size: ${db_size} MB"
            fi
            
            # Check table status
            local table_count=$(docker-compose exec -T mysql mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "
                SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${MYSQL_DATABASE:-ghost}';
            " 2>/dev/null | tail -n 1 || echo "0")
            
            if [[ $table_count -gt 0 ]]; then
                print_status "PASS" "Database contains $table_count tables"
            else
                print_status "WARN" "Database appears to be empty"
            fi
            
        else
            print_status "FAIL" "MySQL connectivity test failed"
        fi
    else
        print_status "SKIP" "MySQL root password not set, skipping connectivity test"
    fi
}

# Check Redis cache
check_redis() {
    echo
    echo "=== Redis Cache Health Check ==="
    
    cd "$PROJECT_DIR"
    
    # Check if Redis container is running
    local redis_container=$(docker-compose ps -q redis 2>/dev/null || echo "")
    
    if [[ -z "$redis_container" ]]; then
        print_status "SKIP" "Redis container not found (optional service)"
        return 0
    fi
    
    # Check Redis process
    if docker-compose exec -T redis ps aux | grep -q "redis-server"; then
        print_status "PASS" "Redis process is running"
    else
        print_status "FAIL" "Redis process not found"
    fi
    
    # Test Redis connectivity
    if docker-compose exec -T redis redis-cli ping >/dev/null 2>&1; then
        print_status "PASS" "Redis connectivity test passed"
        
        # Check Redis info
        local redis_version=$(docker-compose exec -T redis redis-cli info server | grep "redis_version:" | cut -d: -f2 | tr -d '\r' || echo "unknown")
        print_status "INFO" "Redis version: $redis_version"
        
        # Check memory usage
        local used_memory=$(docker-compose exec -T redis redis-cli info memory | grep "used_memory_human:" | cut -d: -f2 | tr -d '\r' || echo "unknown")
        print_status "INFO" "Redis memory usage: $used_memory"
        
        # Check connected clients
        local connected_clients=$(docker-compose exec -T redis redis-cli info clients | grep "connected_clients:" | cut -d: -f2 | tr -d '\r' || echo "unknown")
        print_status "INFO" "Redis connected clients: $connected_clients"
        
    else
        print_status "FAIL" "Redis connectivity test failed"
    fi
}

# Check Caddy web server
check_caddy() {
    echo
    echo "=== Caddy Web Server Health Check ==="
    
    cd "$PROJECT_DIR"
    
    # Check if Caddy container is running
    local caddy_container=$(docker-compose ps -q caddy 2>/dev/null || echo "")
    
    if [[ -z "$caddy_container" ]]; then
        print_status "FAIL" "Caddy container not found"
        return 1
    fi
    
    # Check Caddy process
    if docker-compose exec -T caddy ps aux | grep -q "caddy"; then
        print_status "PASS" "Caddy process is running"
    else
        print_status "FAIL" "Caddy process not found"
    fi
    
    # Check Caddy version
    local caddy_version=$(docker-compose exec -T caddy caddy version | head -1 || echo "unknown")
    print_status "INFO" "Caddy version: $caddy_version"
    
    # Test Caddy admin API
    if docker-compose exec -T caddy curl -s http://localhost:2019/config/ >/dev/null 2>&1; then
        print_status "PASS" "Caddy admin API is accessible"
    else
        print_status "WARN" "Caddy admin API is not accessible"
    fi
    
    # Check SSL certificate status (if HTTPS is configured)
    if [[ "$GHOST_URL" == https://* ]]; then
        local domain=$(echo "$GHOST_URL" | sed 's|https://||' | sed 's|/.*||')
        
        if command -v openssl >/dev/null 2>&1; then
            local cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
            
            if [[ -n "$cert_info" ]]; then
                local expiry_date=$(echo "$cert_info" | grep "notAfter=" | cut -d= -f2)
                local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
                local current_timestamp=$(date +%s)
                local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
                
                if [[ $days_until_expiry -gt 30 ]]; then
                    print_status "PASS" "SSL certificate expires in $days_until_expiry days"
                elif [[ $days_until_expiry -gt 7 ]]; then
                    print_status "WARN" "SSL certificate expires in $days_until_expiry days"
                else
                    print_status "FAIL" "SSL certificate expires in $days_until_expiry days"
                fi
            else
                print_status "WARN" "Could not retrieve SSL certificate information"
            fi
        else
            print_status "SKIP" "openssl not available, skipping SSL certificate check"
        fi
    fi
}

# Check system resources
check_system_resources() {
    echo
    echo "=== System Resources Health Check ==="
    
    # Check disk space
    local disk_usage=$(df -h "$PROJECT_DIR" | tail -1 | awk '{print $5}' | sed 's/%//')
    
    if [[ $disk_usage -lt 80 ]]; then
        print_status "PASS" "Disk usage: ${disk_usage}%"
    elif [[ $disk_usage -lt 90 ]]; then
        print_status "WARN" "Disk usage: ${disk_usage}% (high)"
    else
        print_status "FAIL" "Disk usage: ${disk_usage}% (critical)"
    fi
    
    # Check memory usage
    if command -v free >/dev/null 2>&1; then
        local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
        
        if [[ $mem_usage -lt 80 ]]; then
            print_status "PASS" "Memory usage: ${mem_usage}%"
        elif [[ $mem_usage -lt 90 ]]; then
            print_status "WARN" "Memory usage: ${mem_usage}% (high)"
        else
            print_status "FAIL" "Memory usage: ${mem_usage}% (critical)"
        fi
    else
        print_status "SKIP" "Memory usage check not available on this system"
    fi
    
    # Check CPU load
    if command -v uptime >/dev/null 2>&1; then
        local load_avg=$(uptime | grep -o 'load average: [0-9.]*' | cut -d' ' -f3 | cut -d',' -f1)
        local cpu_cores=$(nproc 2>/dev/null || echo "1")
        local load_percentage=$(echo "scale=0; $load_avg * 100 / $cpu_cores" | bc -l 2>/dev/null || echo "0")
        
        if [[ $load_percentage -lt 70 ]]; then
            print_status "PASS" "CPU load: ${load_avg} (${load_percentage}%)"
        elif [[ $load_percentage -lt 90 ]]; then
            print_status "WARN" "CPU load: ${load_avg} (${load_percentage}%)"
        else
            print_status "FAIL" "CPU load: ${load_avg} (${load_percentage}%)"
        fi
    else
        print_status "SKIP" "CPU load check not available"
    fi
}

# Check backup status
check_backup_status() {
    echo
    echo "=== Backup Status Check ==="
    
    local backup_dir="$PROJECT_DIR/backups"
    
    if [[ -d "$backup_dir" ]]; then
        local latest_backup=$(find "$backup_dir" -name "*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2- || echo "")
        
        if [[ -n "$latest_backup" ]]; then
            local backup_age=$(( ($(date +%s) - $(stat -c %Y "$latest_backup" 2>/dev/null || echo "0")) / 86400 ))
            
            if [[ $backup_age -eq 0 ]]; then
                print_status "PASS" "Latest backup: today"
            elif [[ $backup_age -le 1 ]]; then
                print_status "PASS" "Latest backup: $backup_age day ago"
            elif [[ $backup_age -le 7 ]]; then
                print_status "WARN" "Latest backup: $backup_age days ago"
            else
                print_status "FAIL" "Latest backup: $backup_age days ago (too old)"
            fi
            
            # Check backup size
            local backup_size=$(du -h "$latest_backup" 2>/dev/null | cut -f1 || echo "unknown")
            print_status "INFO" "Latest backup size: $backup_size"
            
        else
            print_status "FAIL" "No backups found"
        fi
    else
        print_status "WARN" "Backup directory not found"
    fi
}

# Check log files
check_log_files() {
    echo
    echo "=== Log Files Check ==="
    
    # Check Ghost logs
    cd "$PROJECT_DIR"
    
    local ghost_logs=$(docker-compose logs --tail=10 ghost 2>/dev/null | grep -i error || echo "")
    if [[ -n "$ghost_logs" ]]; then
        print_status "WARN" "Recent Ghost errors found in logs"
    else
        print_status "PASS" "No recent Ghost errors in logs"
    fi
    
    # Check MySQL logs
    local mysql_logs=$(docker-compose logs --tail=10 mysql 2>/dev/null | grep -i error || echo "")
    if [[ -n "$mysql_logs" ]]; then
        print_status "WARN" "Recent MySQL errors found in logs"
    else
        print_status "PASS" "No recent MySQL errors in logs"
    fi
    
    # Check log file sizes
    if [[ -d "$LOG_DIR" ]]; then
        local large_logs=$(find "$LOG_DIR" -name "*.log" -size +100M 2>/dev/null || echo "")
        if [[ -n "$large_logs" ]]; then
            print_status "WARN" "Large log files found (>100MB)"
        else
            print_status "PASS" "Log file sizes are reasonable"
        fi
    fi
}

# Send alert notification
send_alert() {
    local status=$1
    local message=$2
    
    # Email alert
    if [[ -n "$ALERT_EMAIL" ]] && command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "Ghost CMS Health Alert - $status" "$ALERT_EMAIL"
    fi
    
    # Webhook alert
    if [[ -n "$WEBHOOK_URL" ]] && command -v curl >/dev/null 2>&1; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"status\":\"$status\",\"message\":\"$message\",\"timestamp\":\"$(date -Iseconds)\"}" \
            >/dev/null 2>&1 || true
    fi
}

# Generate health report
generate_health_report() {
    echo
    echo "=== Health Check Summary ==="
    echo "Timestamp: $(date)"
    echo "Overall Status: $HEALTH_STATUS"
    echo
    
    if [[ ${#FAILED_CHECKS[@]} -gt 0 ]]; then
        echo "Failed Checks:"
        for check in "${FAILED_CHECKS[@]}"; do
            echo "  - $check"
        done
        echo
    fi
    
    if [[ ${#WARNING_CHECKS[@]} -gt 0 ]]; then
        echo "Warning Checks:"
        for check in "${WARNING_CHECKS[@]}"; do
            echo "  - $check"
        done
        echo
    fi
    
    # Send alert if needed
    if [[ "$HEALTH_STATUS" == "CRITICAL" ]]; then
        local alert_message="Ghost CMS health check failed with critical issues:\n$(printf '%s\n' "${FAILED_CHECKS[@]}")"
        send_alert "CRITICAL" "$alert_message"
    elif [[ "$HEALTH_STATUS" == "WARNING" ]]; then
        local alert_message="Ghost CMS health check completed with warnings:\n$(printf '%s\n' "${WARNING_CHECKS[@]}")"
        send_alert "WARNING" "$alert_message"
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --all           Run all health checks (default)"
    echo "  --docker        Check Docker and containers only"
    echo "  --ghost         Check Ghost CMS only"
    echo "  --mysql         Check MySQL database only"
    echo "  --redis         Check Redis cache only"
    echo "  --caddy         Check Caddy web server only"
    echo "  --system        Check system resources only"
    echo "  --backup        Check backup status only"
    echo "  --logs          Check log files only"
    echo "  --json          Output results in JSON format"
    echo "  --quiet         Suppress output (exit code only)"
    echo "  --help          Show this help message"
    echo
    echo "Exit codes:"
    echo "  0 - All checks passed (HEALTHY)"
    echo "  1 - Some checks failed with warnings (WARNING)"
    echo "  2 - Critical checks failed (CRITICAL)"
}

# JSON output
output_json() {
    local json_output="{
        \"timestamp\": \"$(date -Iseconds)\",
        \"status\": \"$HEALTH_STATUS\",
        \"failed_checks\": $(printf '%s\n' "${FAILED_CHECKS[@]}" | jq -R . | jq -s .),
        \"warning_checks\": $(printf '%s\n' "${WARNING_CHECKS[@]}" | jq -R . | jq -s .),
        \"details\": $(printf '%s\n' "${HEALTH_DETAILS[@]}" | jq -R . | jq -s .)
    }"
    
    echo "$json_output"
}

# Main function
main() {
    local json_output=false
    local quiet_mode=false
    
    case "${1:-}" in
        --all|"")
            check_docker
            check_docker_compose
            check_ghost
            check_mysql
            check_redis
            check_caddy
            check_system_resources
            check_backup_status
            check_log_files
            ;;
        --docker)
            check_docker
            check_docker_compose
            ;;
        --ghost)
            check_ghost
            ;;
        --mysql)
            check_mysql
            ;;
        --redis)
            check_redis
            ;;
        --caddy)
            check_caddy
            ;;
        --system)
            check_system_resources
            ;;
        --backup)
            check_backup_status
            ;;
        --logs)
            check_log_files
            ;;
        --json)
            json_output=true
            check_docker
            check_docker_compose
            check_ghost
            check_mysql
            check_redis
            check_caddy
            check_system_resources
            check_backup_status
            check_log_files
            ;;
        --quiet)
            quiet_mode=true
            check_docker >/dev/null 2>&1
            check_docker_compose >/dev/null 2>&1
            check_ghost >/dev/null 2>&1
            check_mysql >/dev/null 2>&1
            check_redis >/dev/null 2>&1
            check_caddy >/dev/null 2>&1
            check_system_resources >/dev/null 2>&1
            check_backup_status >/dev/null 2>&1
            check_log_files >/dev/null 2>&1
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            show_usage
            exit 1
            ;;
    esac
    
    if [[ "$json_output" == true ]]; then
        output_json
    elif [[ "$quiet_mode" == false ]]; then
        generate_health_report
    fi
    
    # Set exit code based on health status
    case "$HEALTH_STATUS" in
        "HEALTHY")
            exit 0
            ;;
        "WARNING")
            exit 1
            ;;
        "CRITICAL")
            exit 2
            ;;
    esac
}

# Run main function with all arguments
main "$@"