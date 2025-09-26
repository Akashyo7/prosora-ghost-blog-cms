#!/bin/bash

# Prosora Ghost Blog CMS - Restore Script
# Restore from backup files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="/var/backups/prosora-ghost"

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Function to list available backups
list_backups() {
    echo -e "${BLUE}📋 Available backups:${NC}"
    echo
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${RED}No backup directory found at $BACKUP_DIR${NC}"
        exit 1
    fi
    
    echo "Database backups:"
    ls -lh "$BACKUP_DIR"/database_*.sql.gz 2>/dev/null || echo "  No database backups found"
    
    echo
    echo "Content backups:"
    ls -lh "$BACKUP_DIR"/content_*.tar.gz 2>/dev/null || echo "  No content backups found"
    
    echo
    echo "Configuration backups:"
    ls -lh "$BACKUP_DIR"/configs_*.tar.gz 2>/dev/null || echo "  No configuration backups found"
}

# Function to restore database
restore_database() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        echo -e "${RED}Error: No backup file specified${NC}"
        echo "Usage: $0 database <backup_file>"
        echo "Example: $0 database database_20231201_120000.sql.gz"
        exit 1
    fi
    
    local full_path="$BACKUP_DIR/$backup_file"
    
    if [ ! -f "$full_path" ]; then
        echo -e "${RED}Error: Backup file not found: $full_path${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}📊 Restoring database from $backup_file...${NC}"
    
    # Confirm restoration
    echo -e "${RED}⚠️  WARNING: This will overwrite the current database!${NC}"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restoration cancelled."
        exit 0
    fi
    
    # Stop Ghost to prevent database conflicts
    echo -e "${YELLOW}Stopping Ghost container...${NC}"
    docker stop prosora-ghost || true
    
    # Restore database
    echo -e "${YELLOW}Restoring database...${NC}"
    gunzip -c "$full_path" | docker exec -i prosora-mysql mysql \
        -u"$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        "$MYSQL_DATABASE"
    
    # Restart Ghost
    echo -e "${YELLOW}Starting Ghost container...${NC}"
    docker start prosora-ghost
    
    echo -e "${GREEN}✅ Database restoration completed${NC}"
}

# Function to restore Ghost content
restore_content() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        echo -e "${RED}Error: No backup file specified${NC}"
        echo "Usage: $0 content <backup_file>"
        echo "Example: $0 content content_20231201_120000.tar.gz"
        exit 1
    fi
    
    local full_path="$BACKUP_DIR/$backup_file"
    
    if [ ! -f "$full_path" ]; then
        echo -e "${RED}Error: Backup file not found: $full_path${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}📁 Restoring content from $backup_file...${NC}"
    
    # Confirm restoration
    echo -e "${RED}⚠️  WARNING: This will overwrite current Ghost content (images, themes, etc.)!${NC}"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restoration cancelled."
        exit 0
    fi
    
    # Stop Ghost to prevent file conflicts
    echo -e "${YELLOW}Stopping Ghost container...${NC}"
    docker stop prosora-ghost || true
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    
    # Extract backup
    echo -e "${YELLOW}Extracting content backup...${NC}"
    tar -xzf "$full_path" -C "$temp_dir"
    
    # Remove existing content and restore from backup
    echo -e "${YELLOW}Restoring content files...${NC}"
    docker run --rm \
        -v prosora-ghost-content:/var/lib/ghost/content \
        -v "$temp_dir":/backup \
        alpine:latest \
        sh -c "rm -rf /var/lib/ghost/content/* && cp -r /backup/content_*/content/* /var/lib/ghost/content/"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Restart Ghost
    echo -e "${YELLOW}Starting Ghost container...${NC}"
    docker start prosora-ghost
    
    echo -e "${GREEN}✅ Content restoration completed${NC}"
}

# Function to restore configurations
restore_configs() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        echo -e "${RED}Error: No backup file specified${NC}"
        echo "Usage: $0 configs <backup_file>"
        echo "Example: $0 configs configs_20231201_120000.tar.gz"
        exit 1
    fi
    
    local full_path="$BACKUP_DIR/$backup_file"
    
    if [ ! -f "$full_path" ]; then
        echo -e "${RED}Error: Backup file not found: $full_path${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}⚙️ Restoring configurations from $backup_file...${NC}"
    
    # Confirm restoration
    echo -e "${RED}⚠️  WARNING: This will overwrite current configuration files!${NC}"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restoration cancelled."
        exit 0
    fi
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    
    # Extract backup
    echo -e "${YELLOW}Extracting configuration backup...${NC}"
    tar -xzf "$full_path" -C "$temp_dir"
    
    # Restore configuration files
    echo -e "${YELLOW}Restoring configuration files...${NC}"
    
    # Backup current configs
    local backup_current_dir="./config_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_current_dir"
    cp -r config/ "$backup_current_dir/" 2>/dev/null || true
    cp .env "$backup_current_dir/" 2>/dev/null || true
    
    # Restore from backup
    cp -r "$temp_dir"/configs_*/config/* ./config/ 2>/dev/null || true
    cp "$temp_dir"/configs_*/.env ./ 2>/dev/null || true
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo -e "${GREEN}✅ Configuration restoration completed${NC}"
    echo -e "${BLUE}Current configs backed up to: $backup_current_dir${NC}"
    echo -e "${YELLOW}Note: You may need to restart services for changes to take effect${NC}"
}

# Function to perform full restoration
restore_full() {
    local date_pattern="$1"
    
    if [ -z "$date_pattern" ]; then
        echo -e "${RED}Error: No date pattern specified${NC}"
        echo "Usage: $0 full <date_pattern>"
        echo "Example: $0 full 20231201_120000"
        exit 1
    fi
    
    echo -e "${BLUE}🔄 Starting full restoration for date: $date_pattern${NC}"
    
    # Check if all backup files exist
    local db_backup="database_${date_pattern}.sql.gz"
    local content_backup="content_${date_pattern}.tar.gz"
    local config_backup="configs_${date_pattern}.tar.gz"
    
    local missing_files=()
    
    [ ! -f "$BACKUP_DIR/$db_backup" ] && missing_files+=("$db_backup")
    [ ! -f "$BACKUP_DIR/$content_backup" ] && missing_files+=("$content_backup")
    [ ! -f "$BACKUP_DIR/$config_backup" ] && missing_files+=("$config_backup")
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing backup files:${NC}"
        printf '%s\n' "${missing_files[@]}"
        exit 1
    fi
    
    # Confirm full restoration
    echo -e "${RED}⚠️  WARNING: This will completely restore your Ghost installation!${NC}"
    echo -e "This will restore:"
    echo -e "  - Database: $db_backup"
    echo -e "  - Content: $content_backup"
    echo -e "  - Configs: $config_backup"
    echo
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Restoration cancelled."
        exit 0
    fi
    
    # Perform full restoration
    restore_configs "$config_backup"
    restore_content "$content_backup"
    restore_database "$db_backup"
    
    echo -e "\n${GREEN}🎉 Full restoration completed successfully!${NC}"
    echo -e "${BLUE}Your Ghost blog has been restored to the state from $date_pattern${NC}"
}

# Show usage information
show_usage() {
    echo -e "${BLUE}Prosora Ghost Blog CMS - Restore Script${NC}"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  list                    - List available backups"
    echo "  database <backup_file>  - Restore database from backup"
    echo "  content <backup_file>   - Restore Ghost content from backup"
    echo "  configs <backup_file>   - Restore configuration files from backup"
    echo "  full <date_pattern>     - Restore everything from a specific date"
    echo
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 database database_20231201_120000.sql.gz"
    echo "  $0 content content_20231201_120000.tar.gz"
    echo "  $0 configs configs_20231201_120000.tar.gz"
    echo "  $0 full 20231201_120000"
}

# Main script logic
case "${1:-}" in
    "list")
        list_backups
        ;;
    "database")
        restore_database "$2"
        ;;
    "content")
        restore_content "$2"
        ;;
    "configs")
        restore_configs "$2"
        ;;
    "full")
        restore_full "$2"
        ;;
    *)
        show_usage
        ;;
esac