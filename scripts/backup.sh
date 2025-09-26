#!/bin/bash

# Prosora Ghost Blog CMS - Backup Script
# Automated backup for MySQL database and Ghost content

set -e

# Configuration
BACKUP_DIR="/var/backups/prosora-ghost"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo -e "${BLUE}🔄 Starting Prosora Ghost Blog backup...${NC}"

# Function to backup MySQL database
backup_database() {
    echo -e "${YELLOW}📊 Backing up MySQL database...${NC}"
    
    docker exec prosora-mysql mysqldump \
        -u"$MYSQL_USER" \
        -p"$MYSQL_PASSWORD" \
        "$MYSQL_DATABASE" \
        --single-transaction \
        --routines \
        --triggers \
        > "$BACKUP_DIR/database_$DATE.sql"
    
    # Compress the database backup
    gzip "$BACKUP_DIR/database_$DATE.sql"
    
    echo -e "${GREEN}✅ Database backup completed: database_$DATE.sql.gz${NC}"
}

# Function to backup Ghost content
backup_ghost_content() {
    echo -e "${YELLOW}📁 Backing up Ghost content...${NC}"
    
    # Create content backup directory
    mkdir -p "$BACKUP_DIR/content_$DATE"
    
    # Copy Ghost content (images, themes, data)
    docker cp prosora-ghost:/var/lib/ghost/content "$BACKUP_DIR/content_$DATE/"
    
    # Create tar archive
    cd "$BACKUP_DIR"
    tar -czf "content_$DATE.tar.gz" "content_$DATE/"
    rm -rf "content_$DATE/"
    
    echo -e "${GREEN}✅ Content backup completed: content_$DATE.tar.gz${NC}"
}

# Function to backup configuration files
backup_configs() {
    echo -e "${YELLOW}⚙️ Backing up configuration files...${NC}"
    
    mkdir -p "$BACKUP_DIR/configs_$DATE"
    
    # Copy important config files
    cp .env "$BACKUP_DIR/configs_$DATE/" 2>/dev/null || echo "Warning: .env not found"
    cp docker-compose.yml "$BACKUP_DIR/configs_$DATE/" 2>/dev/null || echo "Warning: docker-compose.yml not found"
    cp -r config/ "$BACKUP_DIR/configs_$DATE/" 2>/dev/null || echo "Warning: config directory not found"
    
    # Create tar archive
    cd "$BACKUP_DIR"
    tar -czf "configs_$DATE.tar.gz" "configs_$DATE/"
    rm -rf "configs_$DATE/"
    
    echo -e "${GREEN}✅ Configuration backup completed: configs_$DATE.tar.gz${NC}"
}

# Function to clean old backups
cleanup_old_backups() {
    echo -e "${YELLOW}🧹 Cleaning up old backups (older than $RETENTION_DAYS days)...${NC}"
    
    find "$BACKUP_DIR" -name "*.gz" -type f -mtime +$RETENTION_DAYS -delete
    
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

# Function to show backup summary
show_summary() {
    echo -e "\n${BLUE}📋 Backup Summary${NC}"
    echo -e "Backup location: $BACKUP_DIR"
    echo -e "Backup date: $DATE"
    echo -e "\nFiles created:"
    ls -lh "$BACKUP_DIR"/*_$DATE.* 2>/dev/null || echo "No backup files found"
    
    # Calculate total backup size
    TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
    echo -e "\nTotal backup size: $TOTAL_SIZE"
}

# Main backup process
main() {
    # Check if Docker containers are running
    if ! docker ps | grep -q "prosora-mysql"; then
        echo -e "${RED}Error: MySQL container is not running${NC}"
        exit 1
    fi
    
    if ! docker ps | grep -q "prosora-ghost"; then
        echo -e "${RED}Error: Ghost container is not running${NC}"
        exit 1
    fi
    
    # Perform backups
    backup_database
    backup_ghost_content
    backup_configs
    cleanup_old_backups
    show_summary
    
    echo -e "\n${GREEN}🎉 Backup completed successfully!${NC}"
    
    # Optional: Upload to cloud storage (uncomment and configure as needed)
    # upload_to_cloud
}

# Function to upload backups to cloud storage (optional)
upload_to_cloud() {
    if [ -n "$BACKUP_CLOUD_PROVIDER" ]; then
        echo -e "${YELLOW}☁️ Uploading to cloud storage...${NC}"
        
        case "$BACKUP_CLOUD_PROVIDER" in
            "aws")
                # AWS S3 upload (requires aws-cli)
                aws s3 sync "$BACKUP_DIR" "s3://$BACKUP_S3_BUCKET/prosora-ghost-backups/"
                ;;
            "gcp")
                # Google Cloud Storage upload (requires gsutil)
                gsutil -m rsync -r "$BACKUP_DIR" "gs://$BACKUP_GCS_BUCKET/prosora-ghost-backups/"
                ;;
            *)
                echo -e "${YELLOW}Warning: Unknown cloud provider: $BACKUP_CLOUD_PROVIDER${NC}"
                ;;
        esac
        
        echo -e "${GREEN}✅ Cloud upload completed${NC}"
    fi
}

# Handle script arguments
case "${1:-}" in
    "database")
        backup_database
        ;;
    "content")
        backup_ghost_content
        ;;
    "configs")
        backup_configs
        ;;
    "cleanup")
        cleanup_old_backups
        ;;
    *)
        main
        ;;
esac