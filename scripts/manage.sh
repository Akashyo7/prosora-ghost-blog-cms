#!/bin/bash

# Prosora Ghost Blog CMS - Management Script
# Common operations and maintenance tasks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Function to show system status
show_status() {
    echo -e "${BLUE}📊 Prosora Ghost Blog CMS - System Status${NC}"
    echo -e "${BLUE}================================================${NC}"
    
    # Docker containers status
    echo -e "\n${CYAN}🐳 Docker Containers:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" --filter "name=prosora"
    
    # System resources
    echo -e "\n${CYAN}💻 System Resources:${NC}"
    echo -e "Memory Usage:"
    free -h | grep -E "Mem|Swap" || echo "Memory info not available"
    
    echo -e "\nDisk Usage:"
    df -h / | tail -1
    
    # Docker volumes
    echo -e "\n${CYAN}📦 Docker Volumes:${NC}"
    docker volume ls --filter "name=prosora" --format "table {{.Name}}\t{{.Driver}}\t{{.Size}}" 2>/dev/null || \
    docker volume ls --filter "name=prosora"
    
    # Service health checks
    echo -e "\n${CYAN}🏥 Service Health:${NC}"
    
    # Check Ghost
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:2368" | grep -q "200\|301\|302"; then
        echo -e "Ghost: ${GREEN}✅ Healthy${NC}"
    else
        echo -e "Ghost: ${RED}❌ Unhealthy${NC}"
    fi
    
    # Check MySQL
    if docker exec prosora-mysql mysqladmin ping -h localhost -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" &>/dev/null; then
        echo -e "MySQL: ${GREEN}✅ Healthy${NC}"
    else
        echo -e "MySQL: ${RED}❌ Unhealthy${NC}"
    fi
    
    # Check Redis
    if docker exec prosora-redis redis-cli ping | grep -q "PONG"; then
        echo -e "Redis: ${GREEN}✅ Healthy${NC}"
    else
        echo -e "Redis: ${RED}❌ Unhealthy${NC}"
    fi
    
    # Check Caddy
    if docker exec prosora-caddy caddy version &>/dev/null; then
        echo -e "Caddy: ${GREEN}✅ Healthy${NC}"
    else
        echo -e "Caddy: ${RED}❌ Unhealthy${NC}"
    fi
    
    # SSL Certificate status
    echo -e "\n${CYAN}🔒 SSL Certificate:${NC}"
    if [ -n "$SITE_URL" ]; then
        local domain=$(echo "$SITE_URL" | sed 's|https\?://||' | sed 's|/.*||')
        local cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "Certificate check failed")
        if [[ "$cert_info" != "Certificate check failed" ]]; then
            echo -e "Certificate: ${GREEN}✅ Valid${NC}"
            echo "$cert_info" | sed 's/^/  /'
        else
            echo -e "Certificate: ${YELLOW}⚠️ Unable to verify${NC}"
        fi
    else
        echo -e "Certificate: ${YELLOW}⚠️ SITE_URL not configured${NC}"
    fi
}

# Function to show logs
show_logs() {
    local service="$1"
    local lines="${2:-50}"
    
    case "$service" in
        "ghost")
            echo -e "${BLUE}📋 Ghost Logs (last $lines lines):${NC}"
            docker logs --tail "$lines" prosora-ghost
            ;;
        "mysql")
            echo -e "${BLUE}📋 MySQL Logs (last $lines lines):${NC}"
            docker logs --tail "$lines" prosora-mysql
            ;;
        "redis")
            echo -e "${BLUE}📋 Redis Logs (last $lines lines):${NC}"
            docker logs --tail "$lines" prosora-redis
            ;;
        "caddy")
            echo -e "${BLUE}📋 Caddy Logs (last $lines lines):${NC}"
            docker logs --tail "$lines" prosora-caddy
            ;;
        "all")
            echo -e "${BLUE}📋 All Service Logs (last $lines lines each):${NC}"
            echo -e "\n${CYAN}=== Ghost ===${NC}"
            docker logs --tail "$lines" prosora-ghost
            echo -e "\n${CYAN}=== MySQL ===${NC}"
            docker logs --tail "$lines" prosora-mysql
            echo -e "\n${CYAN}=== Redis ===${NC}"
            docker logs --tail "$lines" prosora-redis
            echo -e "\n${CYAN}=== Caddy ===${NC}"
            docker logs --tail "$lines" prosora-caddy
            ;;
        *)
            echo -e "${RED}Error: Unknown service '$service'${NC}"
            echo "Available services: ghost, mysql, redis, caddy, all"
            exit 1
            ;;
    esac
}

# Function to restart services
restart_service() {
    local service="$1"
    
    case "$service" in
        "ghost")
            echo -e "${YELLOW}🔄 Restarting Ghost...${NC}"
            docker restart prosora-ghost
            echo -e "${GREEN}✅ Ghost restarted${NC}"
            ;;
        "mysql")
            echo -e "${YELLOW}🔄 Restarting MySQL...${NC}"
            docker restart prosora-mysql
            echo -e "${GREEN}✅ MySQL restarted${NC}"
            ;;
        "redis")
            echo -e "${YELLOW}🔄 Restarting Redis...${NC}"
            docker restart prosora-redis
            echo -e "${GREEN}✅ Redis restarted${NC}"
            ;;
        "caddy")
            echo -e "${YELLOW}🔄 Restarting Caddy...${NC}"
            docker restart prosora-caddy
            echo -e "${GREEN}✅ Caddy restarted${NC}"
            ;;
        "all")
            echo -e "${YELLOW}🔄 Restarting all services...${NC}"
            docker-compose restart
            echo -e "${GREEN}✅ All services restarted${NC}"
            ;;
        *)
            echo -e "${RED}Error: Unknown service '$service'${NC}"
            echo "Available services: ghost, mysql, redis, caddy, all"
            exit 1
            ;;
    esac
}

# Function to update services
update_services() {
    echo -e "${BLUE}🔄 Updating Prosora Ghost Blog CMS...${NC}"
    
    # Pull latest images
    echo -e "${YELLOW}📥 Pulling latest Docker images...${NC}"
    docker-compose pull
    
    # Recreate containers with new images
    echo -e "${YELLOW}🔄 Recreating containers...${NC}"
    docker-compose up -d
    
    # Clean up old images
    echo -e "${YELLOW}🧹 Cleaning up old images...${NC}"
    docker image prune -f
    
    echo -e "${GREEN}✅ Update completed${NC}"
}

# Function to optimize database
optimize_database() {
    echo -e "${BLUE}🔧 Optimizing MySQL database...${NC}"
    
    # Confirm optimization
    echo -e "${YELLOW}⚠️  This will optimize database tables and may take some time.${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Optimization cancelled."
        return 0
    fi
    
    # Run optimization
    docker exec prosora-mysql mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "
        USE $MYSQL_DATABASE;
        OPTIMIZE TABLE posts;
        OPTIMIZE TABLE users;
        OPTIMIZE TABLE tags;
        OPTIMIZE TABLE posts_tags;
        OPTIMIZE TABLE posts_authors;
        OPTIMIZE TABLE settings;
        ANALYZE TABLE posts;
        ANALYZE TABLE users;
        ANALYZE TABLE tags;
    "
    
    echo -e "${GREEN}✅ Database optimization completed${NC}"
}

# Function to clear cache
clear_cache() {
    echo -e "${BLUE}🧹 Clearing cache...${NC}"
    
    # Clear Redis cache
    echo -e "${YELLOW}Clearing Redis cache...${NC}"
    docker exec prosora-redis redis-cli FLUSHALL
    
    # Restart Ghost to clear internal cache
    echo -e "${YELLOW}Restarting Ghost to clear internal cache...${NC}"
    docker restart prosora-ghost
    
    echo -e "${GREEN}✅ Cache cleared${NC}"
}

# Function to show database info
show_database_info() {
    echo -e "${BLUE}📊 Database Information${NC}"
    echo -e "${BLUE}======================${NC}"
    
    # Database size
    echo -e "\n${CYAN}💾 Database Size:${NC}"
    docker exec prosora-mysql mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "
        SELECT 
            table_schema AS 'Database',
            ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
        FROM information_schema.tables 
        WHERE table_schema = '$MYSQL_DATABASE'
        GROUP BY table_schema;
    "
    
    # Table information
    echo -e "\n${CYAN}📋 Table Information:${NC}"
    docker exec prosora-mysql mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "
        SELECT 
            table_name AS 'Table',
            table_rows AS 'Rows',
            ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
        FROM information_schema.tables 
        WHERE table_schema = '$MYSQL_DATABASE'
        ORDER BY (data_length + index_length) DESC;
    "
}

# Function to create SSL certificate manually
renew_ssl() {
    echo -e "${BLUE}🔒 Renewing SSL Certificate...${NC}"
    
    if [ -z "$SITE_URL" ]; then
        echo -e "${RED}Error: SITE_URL not configured in .env${NC}"
        exit 1
    fi
    
    local domain=$(echo "$SITE_URL" | sed 's|https\?://||' | sed 's|/.*||')
    
    echo -e "${YELLOW}Reloading Caddy configuration...${NC}"
    docker exec prosora-caddy caddy reload --config /etc/caddy/Caddyfile
    
    echo -e "${GREEN}✅ SSL certificate renewal initiated${NC}"
    echo -e "${BLUE}Note: Caddy handles SSL automatically. Check logs if issues persist.${NC}"
}

# Function to show performance metrics
show_performance() {
    echo -e "${BLUE}📈 Performance Metrics${NC}"
    echo -e "${BLUE}=====================${NC}"
    
    # Container resource usage
    echo -e "\n${CYAN}🐳 Container Resource Usage:${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" \
        prosora-ghost prosora-mysql prosora-redis prosora-caddy 2>/dev/null || \
        echo "Unable to get container stats"
    
    # Redis info
    echo -e "\n${CYAN}📊 Redis Statistics:${NC}"
    docker exec prosora-redis redis-cli info stats | grep -E "total_commands_processed|total_connections_received|keyspace_hits|keyspace_misses" || \
        echo "Unable to get Redis stats"
    
    # MySQL process list
    echo -e "\n${CYAN}🗄️ MySQL Active Connections:${NC}"
    docker exec prosora-mysql mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW PROCESSLIST;" | head -10
}

# Function to show usage information
show_usage() {
    echo -e "${BLUE}Prosora Ghost Blog CMS - Management Script${NC}"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo -e "  ${GREEN}status${NC}                    - Show system status and health"
    echo -e "  ${GREEN}logs${NC} <service> [lines]    - Show service logs (ghost|mysql|redis|caddy|all)"
    echo -e "  ${GREEN}restart${NC} <service>         - Restart service (ghost|mysql|redis|caddy|all)"
    echo -e "  ${GREEN}update${NC}                    - Update all services to latest versions"
    echo -e "  ${GREEN}optimize${NC}                  - Optimize MySQL database"
    echo -e "  ${GREEN}cache${NC}                     - Clear all caches"
    echo -e "  ${GREEN}database${NC}                  - Show database information"
    echo -e "  ${GREEN}ssl${NC}                       - Renew SSL certificate"
    echo -e "  ${GREEN}performance${NC}               - Show performance metrics"
    echo -e "  ${GREEN}backup${NC}                    - Run backup script"
    echo -e "  ${GREEN}restore${NC}                   - Run restore script"
    echo
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 logs ghost 100"
    echo "  $0 restart all"
    echo "  $0 update"
    echo "  $0 optimize"
}

# Main script logic
case "${1:-}" in
    "status")
        show_status
        ;;
    "logs")
        show_logs "$2" "$3"
        ;;
    "restart")
        restart_service "$2"
        ;;
    "update")
        update_services
        ;;
    "optimize")
        optimize_database
        ;;
    "cache")
        clear_cache
        ;;
    "database")
        show_database_info
        ;;
    "ssl")
        renew_ssl
        ;;
    "performance")
        show_performance
        ;;
    "backup")
        ./scripts/backup.sh
        ;;
    "restore")
        ./scripts/restore.sh "$@"
        ;;
    *)
        show_usage
        ;;
esac