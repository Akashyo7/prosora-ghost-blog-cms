#!/bin/bash

# Prosora Ghost Blog CMS - Monitoring Script
# Comprehensive system monitoring and alerting

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
ALERT_EMAIL="${ALERT_EMAIL:-admin@yourdomain.com}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

# Thresholds
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
RESPONSE_TIME_THRESHOLD=3000  # milliseconds

# Create logs directory
mkdir -p "$LOG_DIR"

# Load environment variables
if [[ -f "$PROJECT_DIR/.env" ]]; then
    source "$PROJECT_DIR/.env"
fi

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/monitor.log"
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
    esac
}

# Send alert function
send_alert() {
    local subject=$1
    local message=$2
    local severity=${3:-"WARNING"}
    
    log "ALERT [$severity]: $subject - $message"
    
    # Send email alert if configured
    if command -v mail >/dev/null 2>&1 && [[ -n "$ALERT_EMAIL" ]]; then
        echo "$message" | mail -s "[$severity] Prosora Ghost CMS: $subject" "$ALERT_EMAIL"
    fi
    
    # Send webhook alert if configured
    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -s -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"subject\":\"$subject\",\"message\":\"$message\",\"severity\":\"$severity\"}" \
            >/dev/null 2>&1 || true
    fi
}

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_status "ERROR" "Docker is not running"
        send_alert "Docker Service Down" "Docker daemon is not running" "ERROR"
        return 1
    fi
    print_status "OK" "Docker is running"
    return 0
}

# Check Docker Compose services
check_services() {
    local failed_services=()
    
    cd "$PROJECT_DIR"
    
    # Get service status
    local services=$(docker-compose ps --services)
    
    for service in $services; do
        local status=$(docker-compose ps -q "$service" | xargs docker inspect --format='{{.State.Status}}' 2>/dev/null || echo "not_found")
        
        if [[ "$status" == "running" ]]; then
            print_status "OK" "Service $service is running"
        else
            print_status "ERROR" "Service $service is $status"
            failed_services+=("$service")
        fi
    done
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        send_alert "Services Down" "Failed services: ${failed_services[*]}" "ERROR"
        return 1
    fi
    
    return 0
}

# Check system resources
check_resources() {
    local alerts=()
    
    # Check CPU usage
    local cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | sed 's/%//' | cut -d. -f1)
    if [[ $cpu_usage -gt $CPU_THRESHOLD ]]; then
        print_status "WARNING" "High CPU usage: ${cpu_usage}%"
        alerts+=("CPU usage: ${cpu_usage}%")
    else
        print_status "OK" "CPU usage: ${cpu_usage}%"
    fi
    
    # Check memory usage
    local memory_info=$(vm_stat | grep -E "Pages (free|active|inactive|speculative|wired down)")
    local page_size=$(vm_stat | grep "page size" | awk '{print $8}')
    local free_pages=$(echo "$memory_info" | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
    local total_pages=$(echo "$memory_info" | awk '{sum += $3} END {print sum}')
    local memory_usage=$(( (total_pages - free_pages) * 100 / total_pages ))
    
    if [[ $memory_usage -gt $MEMORY_THRESHOLD ]]; then
        print_status "WARNING" "High memory usage: ${memory_usage}%"
        alerts+=("Memory usage: ${memory_usage}%")
    else
        print_status "OK" "Memory usage: ${memory_usage}%"
    fi
    
    # Check disk usage
    local disk_usage=$(df -h "$PROJECT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt $DISK_THRESHOLD ]]; then
        print_status "WARNING" "High disk usage: ${disk_usage}%"
        alerts+=("Disk usage: ${disk_usage}%")
    else
        print_status "OK" "Disk usage: ${disk_usage}%"
    fi
    
    # Send alerts if any
    if [[ ${#alerts[@]} -gt 0 ]]; then
        send_alert "High Resource Usage" "Resource alerts: ${alerts[*]}" "WARNING"
        return 1
    fi
    
    return 0
}

# Check website response time
check_response_time() {
    local domain=${GHOST_URL:-"http://localhost"}
    
    # Remove protocol for curl
    local test_url=$(echo "$domain" | sed 's|^https\?://||')
    
    # Test response time
    local response_time=$(curl -o /dev/null -s -w '%{time_total}' "http://$test_url" 2>/dev/null || echo "999")
    local response_ms=$(echo "$response_time * 1000" | bc | cut -d. -f1)
    
    if [[ $response_ms -gt $RESPONSE_TIME_THRESHOLD ]]; then
        print_status "WARNING" "Slow response time: ${response_ms}ms"
        send_alert "Slow Response Time" "Website response time: ${response_ms}ms" "WARNING"
        return 1
    else
        print_status "OK" "Response time: ${response_ms}ms"
    fi
    
    return 0
}

# Check SSL certificate
check_ssl() {
    local domain=${GHOST_URL:-""}
    
    if [[ -z "$domain" ]] || [[ "$domain" == *"localhost"* ]] || [[ "$domain" == *"127.0.0.1"* ]]; then
        print_status "INFO" "SSL check skipped (localhost)"
        return 0
    fi
    
    # Extract domain from URL
    local clean_domain=$(echo "$domain" | sed 's|^https\?://||' | sed 's|/.*||')
    
    # Check SSL certificate expiry
    local cert_info=$(echo | openssl s_client -connect "$clean_domain:443" -servername "$clean_domain" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
    
    if [[ -n "$cert_info" ]]; then
        local expiry_date=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
        local expiry_timestamp=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" "+%s" 2>/dev/null || echo "0")
        local current_timestamp=$(date "+%s")
        local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        if [[ $days_until_expiry -lt 30 ]]; then
            print_status "WARNING" "SSL certificate expires in $days_until_expiry days"
            send_alert "SSL Certificate Expiring" "Certificate expires in $days_until_expiry days" "WARNING"
            return 1
        else
            print_status "OK" "SSL certificate valid for $days_until_expiry days"
        fi
    else
        print_status "ERROR" "Could not check SSL certificate"
        send_alert "SSL Certificate Check Failed" "Unable to verify SSL certificate" "ERROR"
        return 1
    fi
    
    return 0
}

# Check database connectivity
check_database() {
    cd "$PROJECT_DIR"
    
    # Test MySQL connection
    if docker-compose exec -T mysql mysqladmin -u root -p"${MYSQL_ROOT_PASSWORD}" ping >/dev/null 2>&1; then
        print_status "OK" "MySQL database is accessible"
    else
        print_status "ERROR" "MySQL database is not accessible"
        send_alert "Database Connection Failed" "Cannot connect to MySQL database" "ERROR"
        return 1
    fi
    
    # Check database size
    local db_size=$(docker-compose exec -T mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}" -e "
        SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'DB Size in MB' 
        FROM information_schema.tables 
        WHERE table_schema='${MYSQL_DATABASE}';" 2>/dev/null | tail -n 1)
    
    if [[ -n "$db_size" ]]; then
        print_status "INFO" "Database size: ${db_size}MB"
    fi
    
    return 0
}

# Check backup status
check_backups() {
    local backup_dir="$PROJECT_DIR/backups"
    
    if [[ ! -d "$backup_dir" ]]; then
        print_status "WARNING" "Backup directory does not exist"
        return 1
    fi
    
    # Check for recent backups
    local latest_backup=$(find "$backup_dir" -name "*.tar.gz" -type f -mtime -1 | head -n 1)
    
    if [[ -n "$latest_backup" ]]; then
        local backup_age=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$latest_backup")
        print_status "OK" "Latest backup: $backup_age"
    else
        print_status "WARNING" "No recent backups found (last 24 hours)"
        send_alert "No Recent Backups" "No backups found in the last 24 hours" "WARNING"
        return 1
    fi
    
    return 0
}

# Check log file sizes
check_logs() {
    local log_alerts=()
    
    # Check Docker logs
    cd "$PROJECT_DIR"
    local services=$(docker-compose ps --services)
    
    for service in $services; do
        local container_id=$(docker-compose ps -q "$service" 2>/dev/null || echo "")
        if [[ -n "$container_id" ]]; then
            local log_size=$(docker logs "$container_id" 2>&1 | wc -c)
            local log_size_mb=$((log_size / 1024 / 1024))
            
            if [[ $log_size_mb -gt 100 ]]; then
                log_alerts+=("$service: ${log_size_mb}MB")
            fi
        fi
    done
    
    if [[ ${#log_alerts[@]} -gt 0 ]]; then
        print_status "WARNING" "Large log files detected: ${log_alerts[*]}"
        send_alert "Large Log Files" "Services with large logs: ${log_alerts[*]}" "WARNING"
        return 1
    else
        print_status "OK" "Log file sizes are normal"
    fi
    
    return 0
}

# Generate system report
generate_report() {
    local report_file="$LOG_DIR/system-report-$(date +%Y%m%d-%H%M%S).txt"
    
    {
        echo "Prosora Ghost CMS - System Report"
        echo "Generated: $(date)"
        echo "=================================="
        echo
        
        echo "System Information:"
        echo "- OS: $(uname -s) $(uname -r)"
        echo "- Hostname: $(hostname)"
        echo "- Uptime: $(uptime)"
        echo
        
        echo "Docker Information:"
        docker version --format "- Docker: {{.Server.Version}}"
        docker-compose version --short | sed 's/^/- /'
        echo
        
        echo "Service Status:"
        cd "$PROJECT_DIR"
        docker-compose ps
        echo
        
        echo "Resource Usage:"
        echo "- CPU: $(top -l 1 | grep "CPU usage" | awk '{print $3}')"
        echo "- Memory: $(vm_stat | head -n 5)"
        echo "- Disk: $(df -h "$PROJECT_DIR")"
        echo
        
        echo "Network Connectivity:"
        echo "- Ghost Response: $(curl -o /dev/null -s -w '%{http_code} (%{time_total}s)' "${GHOST_URL:-http://localhost}" 2>/dev/null || echo "Failed")"
        echo
        
        echo "Recent Logs (last 50 lines):"
        docker-compose logs --tail=50
        
    } > "$report_file"
    
    print_status "INFO" "System report generated: $report_file"
}

# Main monitoring function
run_monitoring() {
    local failed_checks=0
    
    echo -e "${CYAN}Prosora Ghost CMS - System Monitor${NC}"
    echo "=================================="
    echo "Timestamp: $(date)"
    echo
    
    # Run all checks
    echo -e "${BLUE}Checking Docker...${NC}"
    check_docker || ((failed_checks++))
    echo
    
    echo -e "${BLUE}Checking Services...${NC}"
    check_services || ((failed_checks++))
    echo
    
    echo -e "${BLUE}Checking Resources...${NC}"
    check_resources || ((failed_checks++))
    echo
    
    echo -e "${BLUE}Checking Response Time...${NC}"
    check_response_time || ((failed_checks++))
    echo
    
    echo -e "${BLUE}Checking SSL Certificate...${NC}"
    check_ssl || ((failed_checks++))
    echo
    
    echo -e "${BLUE}Checking Database...${NC}"
    check_database || ((failed_checks++))
    echo
    
    echo -e "${BLUE}Checking Backups...${NC}"
    check_backups || ((failed_checks++))
    echo
    
    echo -e "${BLUE}Checking Logs...${NC}"
    check_logs || ((failed_checks++))
    echo
    
    # Summary
    if [[ $failed_checks -eq 0 ]]; then
        print_status "OK" "All checks passed successfully"
        log "Monitoring completed successfully - all checks passed"
    else
        print_status "WARNING" "$failed_checks checks failed"
        log "Monitoring completed with $failed_checks failed checks"
        send_alert "Monitoring Alert" "$failed_checks system checks failed" "WARNING"
    fi
    
    return $failed_checks
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --check-all     Run all monitoring checks (default)"
    echo "  --docker        Check Docker status only"
    echo "  --services      Check service status only"
    echo "  --resources     Check system resources only"
    echo "  --response      Check website response time only"
    echo "  --ssl           Check SSL certificate only"
    echo "  --database      Check database connectivity only"
    echo "  --backups       Check backup status only"
    echo "  --logs          Check log file sizes only"
    echo "  --report        Generate detailed system report"
    echo "  --daemon        Run in daemon mode (continuous monitoring)"
    echo "  --interval N    Set monitoring interval in seconds (default: 300)"
    echo "  --help          Show this help message"
    echo
    echo "Environment Variables:"
    echo "  ALERT_EMAIL     Email address for alerts"
    echo "  WEBHOOK_URL     Webhook URL for alerts"
    echo "  CPU_THRESHOLD   CPU usage threshold (default: 80%)"
    echo "  MEMORY_THRESHOLD Memory usage threshold (default: 85%)"
    echo "  DISK_THRESHOLD  Disk usage threshold (default: 90%)"
}

# Daemon mode
run_daemon() {
    local interval=${1:-300}  # Default 5 minutes
    
    echo -e "${CYAN}Starting Prosora Ghost CMS Monitor Daemon${NC}"
    echo "Monitoring interval: ${interval} seconds"
    echo "Press Ctrl+C to stop"
    echo
    
    # Create PID file
    echo $$ > "$LOG_DIR/monitor.pid"
    
    # Trap signals for clean shutdown
    trap 'echo "Stopping monitor daemon..."; rm -f "$LOG_DIR/monitor.pid"; exit 0' SIGINT SIGTERM
    
    while true; do
        run_monitoring
        echo
        echo "Next check in ${interval} seconds..."
        sleep "$interval"
    done
}

# Main script logic
main() {
    case "${1:-}" in
        --docker)
            check_docker
            ;;
        --services)
            check_services
            ;;
        --resources)
            check_resources
            ;;
        --response)
            check_response_time
            ;;
        --ssl)
            check_ssl
            ;;
        --database)
            check_database
            ;;
        --backups)
            check_backups
            ;;
        --logs)
            check_logs
            ;;
        --report)
            generate_report
            ;;
        --daemon)
            run_daemon "${2:-300}"
            ;;
        --interval)
            if [[ -n "${2:-}" ]]; then
                run_daemon "$2"
            else
                echo "Error: --interval requires a number of seconds"
                exit 1
            fi
            ;;
        --help)
            show_usage
            ;;
        --check-all|"")
            run_monitoring
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