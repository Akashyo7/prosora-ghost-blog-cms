# Prosora Ghost Blog CMS - Troubleshooting Guide

## 🚨 Quick Diagnostics

### System Health Check
```bash
# Run comprehensive health check
./scripts/manage.sh

# Check all service status
docker-compose ps

# View system resources
docker stats --no-stream

# Check disk space
df -h
```

### Service Status Commands
```bash
# Check individual services
docker-compose logs ghost
docker-compose logs caddy
docker-compose logs mysql
docker-compose logs redis

# Follow logs in real-time
docker-compose logs -f ghost

# Check service health
docker-compose exec ghost ghost doctor
```

---

## 🐳 Docker & Container Issues

### Container Won't Start

#### Symptoms
- Service shows as "Exited" status
- Container restarts continuously
- Error messages in logs

#### Diagnosis
```bash
# Check container status
docker-compose ps

# View detailed logs
docker-compose logs [service-name]

# Check resource usage
docker system df
docker system prune  # Clean up if needed
```

#### Common Solutions

**Port Conflicts**
```bash
# Check what's using port 80/443
sudo lsof -i :80
sudo lsof -i :443

# Kill conflicting processes
sudo kill -9 [PID]

# Or change ports in docker-compose.yml
ports:
  - "8080:80"  # Use different port
```

**Permission Issues**
```bash
# Fix file permissions
sudo chown -R $USER:$USER .
chmod +x scripts/*.sh

# Fix Docker socket permissions
sudo chmod 666 /var/run/docker.sock
```

**Memory Issues**
```bash
# Check available memory
free -h

# Increase Docker memory limit
# Docker Desktop: Settings → Resources → Memory

# Optimize MySQL memory usage
# Edit config/mysql/my.cnf:
innodb_buffer_pool_size = 128M  # Reduce if needed
```

### Docker Compose Issues

#### Service Dependencies
```bash
# Ensure services start in correct order
docker-compose up --build

# Start specific service
docker-compose up mysql
docker-compose up ghost

# Force recreate containers
docker-compose up --force-recreate
```

#### Network Issues
```bash
# Recreate network
docker network rm prosora-network
docker-compose up

# Check network connectivity
docker-compose exec ghost ping mysql
docker-compose exec ghost ping redis
```

---

## 👻 Ghost CMS Issues

### Ghost Won't Start

#### Database Connection Issues
```bash
# Check MySQL status
docker-compose exec mysql mysql -u root -p -e "SHOW DATABASES;"

# Test Ghost database connection
docker-compose exec ghost node -e "
const knex = require('knex')({
  client: 'mysql2',
  connection: {
    host: 'mysql',
    user: process.env.MYSQL_USER,
    password: process.env.MYSQL_PASSWORD,
    database: process.env.MYSQL_DATABASE
  }
});
knex.raw('SELECT 1').then(() => console.log('DB Connected')).catch(console.error);
"
```

#### Configuration Issues
```bash
# Check Ghost configuration
docker-compose exec ghost cat /var/lib/ghost/config.production.json

# Validate environment variables
docker-compose exec ghost env | grep -E "(database|mail|storage)"

# Reset Ghost configuration
docker-compose exec ghost ghost config --help
```

#### Migration Issues
```bash
# Run database migrations manually
docker-compose exec ghost ghost migrate

# Check migration status
docker-compose exec ghost ghost migrate --help

# Reset database (DANGER: Deletes all data)
docker-compose exec mysql mysql -u root -p -e "
DROP DATABASE IF EXISTS ghost_production;
CREATE DATABASE ghost_production;
"
docker-compose restart ghost
```

### Ghost Admin Access Issues

#### Can't Access Admin Panel
```bash
# Check Ghost URL configuration
docker-compose exec ghost ghost config get url

# Update Ghost URL
docker-compose exec ghost ghost config set url https://yourdomain.com

# Reset admin user
docker-compose exec ghost ghost user add \
  --email admin@yourdomain.com \
  --name "Admin User" \
  --password "newpassword123" \
  --role Administrator
```

#### SSL/HTTPS Issues
```bash
# Check Caddy SSL status
docker-compose logs caddy | grep -i ssl

# Force SSL certificate renewal
docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile

# Check certificate status
echo | openssl s_client -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates
```

### Performance Issues

#### Slow Loading Times
```bash
# Check Ghost performance
docker-compose exec ghost ghost doctor

# Analyze slow queries
docker-compose exec mysql mysql -u root -p -e "
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;
SHOW VARIABLES LIKE 'slow_query_log%';
"

# Monitor resource usage
docker stats prosora-ghost prosora-mysql prosora-redis
```

#### Memory Issues
```bash
# Check Ghost memory usage
docker-compose exec ghost node -e "
console.log('Memory Usage:', process.memoryUsage());
console.log('Uptime:', process.uptime(), 'seconds');
"

# Restart Ghost to clear memory
docker-compose restart ghost

# Optimize MySQL memory
# Edit config/mysql/my.cnf and restart
```

---

## 🗄️ Database Issues

### MySQL Connection Problems

#### Can't Connect to Database
```bash
# Check MySQL status
docker-compose exec mysql mysqladmin -u root -p status

# Test connection from Ghost container
docker-compose exec ghost mysql -h mysql -u ghost_user -p ghost_production

# Check MySQL error logs
docker-compose logs mysql | grep -i error
```

#### Database Corruption
```bash
# Check database integrity
docker-compose exec mysql mysqlcheck -u root -p --all-databases

# Repair corrupted tables
docker-compose exec mysql mysqlcheck -u root -p --auto-repair ghost_production

# Optimize database
docker-compose exec mysql mysqlcheck -u root -p --optimize ghost_production
```

### Backup and Recovery Issues

#### Backup Failures
```bash
# Test backup script
./scripts/backup.sh --test

# Check backup directory permissions
ls -la backups/

# Manual database backup
docker-compose exec mysql mysqldump -u root -p ghost_production > manual_backup.sql

# Check disk space for backups
df -h backups/
```

#### Recovery Issues
```bash
# List available backups
./scripts/restore.sh --list

# Test restore (dry run)
./scripts/restore.sh --test 2024-01-15

# Manual database restore
docker-compose exec -T mysql mysql -u root -p ghost_production < backup.sql
```

---

## 🌐 Network & SSL Issues

### Domain and DNS Problems

#### Domain Not Resolving
```bash
# Check DNS propagation
dig yourdomain.com
nslookup yourdomain.com

# Test from different locations
# Use online tools like whatsmydns.net

# Check DNS records
dig A yourdomain.com
dig CNAME www.yourdomain.com
```

#### SSL Certificate Issues
```bash
# Check certificate status
curl -I https://yourdomain.com

# View certificate details
echo | openssl s_client -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -text

# Force certificate renewal
docker-compose exec caddy caddy reload

# Check Caddy logs for SSL errors
docker-compose logs caddy | grep -i "certificate\|ssl\|tls"
```

### Caddy Web Server Issues

#### Caddy Configuration Problems
```bash
# Test Caddy configuration
docker-compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# Reload Caddy configuration
docker-compose exec caddy caddy reload --config /etc/caddy/Caddyfile

# Check Caddy status
docker-compose exec caddy caddy list-certificates
```

#### Reverse Proxy Issues
```bash
# Test backend connectivity
docker-compose exec caddy curl http://ghost:2368

# Check proxy headers
curl -H "Host: yourdomain.com" http://localhost/

# Debug proxy configuration
# Add to Caddyfile temporarily:
log {
    output file /var/log/caddy/access.log
    level DEBUG
}
```

---

## 📧 Email & Integration Issues

### Email Delivery Problems

#### Resend Integration Issues
```bash
# Test Resend API connection
curl -X POST "https://api.resend.com/emails" \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "from": "test@yourdomain.com",
    "to": ["admin@yourdomain.com"],
    "subject": "Test Email",
    "text": "This is a test email"
  }'

# Check Ghost email configuration
docker-compose exec ghost ghost config get mail

# Test email from Ghost
docker-compose exec ghost ghost email-test admin@yourdomain.com
```

#### SMTP Configuration Issues
```bash
# Check SMTP settings in Ghost
docker-compose exec ghost cat /var/lib/ghost/config.production.json | grep -A 10 mail

# Test SMTP connection
telnet smtp.resend.com 587

# Check email logs
docker-compose logs ghost | grep -i mail
```

### Media Storage Issues

#### Cloudinary Upload Problems
```bash
# Test Cloudinary API
curl -X GET "https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/usage" \
  -u "$CLOUDINARY_API_KEY:$CLOUDINARY_API_SECRET"

# Check Ghost storage configuration
docker-compose exec ghost ghost config get storage

# Test image upload
curl -X POST "https://api.cloudinary.com/v1_1/$CLOUDINARY_CLOUD_NAME/image/upload" \
  -F "file=@test-image.jpg" \
  -F "upload_preset=ghost-blog"
```

### Payment Integration Issues

#### Stripe Configuration Problems
```bash
# Test Stripe API connection
curl https://api.stripe.com/v1/customers \
  -u $STRIPE_SECRET_KEY:

# Check webhook endpoint
curl -X POST "https://yourdomain.com/members/webhooks/stripe/" \
  -H "Content-Type: application/json" \
  -d '{"type": "ping"}'

# Verify webhook signing
# Check Stripe dashboard for webhook delivery status
```

---

## 🔧 Performance Troubleshooting

### Slow Website Performance

#### Identify Bottlenecks
```bash
# Check response times
curl -w "@curl-format.txt" -o /dev/null -s https://yourdomain.com

# Create curl-format.txt:
cat > curl-format.txt << 'EOF'
     time_namelookup:  %{time_namelookup}\n
        time_connect:  %{time_connect}\n
     time_appconnect:  %{time_appconnect}\n
    time_pretransfer:  %{time_pretransfer}\n
       time_redirect:  %{time_redirect}\n
  time_starttransfer:  %{time_starttransfer}\n
                     ----------\n
          time_total:  %{time_total}\n
EOF

# Monitor resource usage
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
```

#### Database Performance
```bash
# Check slow queries
docker-compose exec mysql mysql -u root -p -e "
SHOW VARIABLES LIKE 'slow_query_log%';
SELECT * FROM mysql.slow_log ORDER BY start_time DESC LIMIT 10;
"

# Analyze query performance
docker-compose exec mysql mysql -u root -p -e "
SHOW PROCESSLIST;
SHOW ENGINE INNODB STATUS\G
"

# Optimize database
docker-compose exec mysql mysql -u root -p -e "
OPTIMIZE TABLE ghost_production.posts;
OPTIMIZE TABLE ghost_production.users;
ANALYZE TABLE ghost_production.posts;
"
```

### Memory Issues

#### High Memory Usage
```bash
# Check memory usage by service
docker stats --no-stream --format "table {{.Container}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Check system memory
free -h
cat /proc/meminfo

# Optimize MySQL memory
# Edit config/mysql/my.cnf:
innodb_buffer_pool_size = 256M
query_cache_size = 32M
tmp_table_size = 32M
max_heap_table_size = 32M
```

#### Memory Leaks
```bash
# Monitor Ghost memory over time
while true; do
  docker stats --no-stream prosora-ghost | grep prosora-ghost
  sleep 60
done

# Restart services if memory usage is high
docker-compose restart ghost
docker-compose restart mysql
```

---

## 🔍 Monitoring & Logging

### Log Analysis

#### Centralized Logging
```bash
# View all logs
docker-compose logs

# Filter by service and time
docker-compose logs --since="1h" ghost
docker-compose logs --tail=100 caddy

# Search for errors
docker-compose logs | grep -i error
docker-compose logs | grep -i warning
```

#### Log Rotation
```bash
# Configure log rotation
# Add to docker-compose.yml:
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"

# Manual log cleanup
docker system prune --volumes
```

### Health Monitoring

#### Service Health Checks
```bash
# Check service health
docker-compose ps
docker inspect prosora-ghost --format='{{.State.Health.Status}}'

# Custom health check script
cat > health-check.sh << 'EOF'
#!/bin/bash
echo "Checking Ghost..."
curl -f http://localhost:2368 || exit 1

echo "Checking MySQL..."
docker-compose exec mysql mysqladmin -u root -p ping || exit 1

echo "Checking Redis..."
docker-compose exec redis redis-cli ping || exit 1

echo "All services healthy!"
EOF
chmod +x health-check.sh
```

#### Automated Monitoring
```bash
# Set up cron job for health checks
crontab -e
# Add: */5 * * * * /path/to/health-check.sh >> /var/log/health-check.log 2>&1

# Monitor disk space
df -h | awk '$5 > 80 {print "Warning: " $1 " is " $5 " full"}'

# Monitor service uptime
docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
```

---

## 🚨 Emergency Procedures

### Complete System Recovery

#### Service Failure Recovery
```bash
# Stop all services
docker-compose down

# Clean up containers and networks
docker system prune -f

# Restore from backup
./scripts/restore.sh --full 2024-01-15

# Start services
docker-compose up -d

# Verify recovery
./scripts/manage.sh
```

#### Data Corruption Recovery
```bash
# Stop Ghost service
docker-compose stop ghost

# Backup current state
./scripts/backup.sh --emergency

# Restore database from backup
./scripts/restore.sh --database 2024-01-15

# Check database integrity
docker-compose exec mysql mysqlcheck -u root -p --check ghost_production

# Restart Ghost
docker-compose start ghost
```

### Security Incident Response

#### Suspected Breach
```bash
# Immediately change all passwords
# Update .env file with new credentials

# Check for unauthorized access
docker-compose logs | grep -i "unauthorized\|failed\|error"

# Review recent file changes
find . -type f -mtime -1 -ls

# Update all services
docker-compose pull
docker-compose up -d

# Enable additional security
# Add to Caddyfile:
rate_limit {
    zone dynamic {
        key {remote_host}
        events 10
        window 1m
    }
}
```

#### DDoS Attack Mitigation
```bash
# Enable Cloudflare DDoS protection
# Set security level to "High" in Cloudflare dashboard

# Implement rate limiting
# Add to Caddyfile:
rate_limit {
    zone api {
        key {remote_host}
        events 5
        window 1m
    }
    zone general {
        key {remote_host}
        events 30
        window 1m
    }
}

# Monitor attack patterns
docker-compose logs caddy | grep -E "rate_limit|blocked"
```

---

## 📞 Getting Help

### Community Support
- **Ghost Forum**: [forum.ghost.org](https://forum.ghost.org)
- **Docker Community**: [forums.docker.com](https://forums.docker.com)
- **GitHub Issues**: Create issue in project repository

### Professional Support
- **Ghost Pro Support**: For Ghost-specific issues
- **Server Management**: Consider managed hosting services
- **Custom Development**: Hire Ghost developers

### Documentation Resources
- **Ghost Documentation**: [ghost.org/docs](https://ghost.org/docs)
- **Docker Documentation**: [docs.docker.com](https://docs.docker.com)
- **Caddy Documentation**: [caddyserver.com/docs](https://caddyserver.com/docs)

### Emergency Contacts
```bash
# Create emergency contact list
cat > EMERGENCY-CONTACTS.md << 'EOF'
# Emergency Contacts

## Technical Support
- Server Provider: [Contact Info]
- Domain Registrar: [Contact Info]
- DNS Provider: [Contact Info]

## Service Providers
- Resend Support: support@resend.com
- Cloudinary Support: support@cloudinary.com
- Stripe Support: support@stripe.com

## Internal Team
- System Administrator: [Contact Info]
- Developer: [Contact Info]
- Content Manager: [Contact Info]
EOF
```

---

This comprehensive troubleshooting guide covers the most common issues you might encounter with your Prosora Ghost Blog CMS. Keep this guide handy and refer to it whenever you face any problems with your installation.