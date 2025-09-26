# Prosora Ghost Blog CMS - Setup Guide

## 🚀 Quick Start

### Prerequisites

Before starting, ensure you have:

- **VPS/Server**: Ubuntu 20.04+ or similar Linux distribution
- **Domain**: A domain name pointing to your server's IP
- **Docker**: Version 20.10+
- **Docker Compose**: Version 2.0+
- **Git**: For cloning the repository
- **Minimum Resources**: 1GB RAM, 1 CPU core, 10GB storage

### One-Command Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/prosora-ghost-blog-CMS.git
cd prosora-ghost-blog-CMS

# Run the automated setup
./deploy.sh
```

The setup script will:
1. Check prerequisites
2. Configure environment variables interactively
3. Deploy all services
4. Set up SSL certificates
5. Provide next steps

## 📋 Detailed Setup Process

### Step 1: Server Preparation

#### Update System
```bash
sudo apt update && sudo apt upgrade -y
```

#### Install Docker
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again for group changes to take effect
```

#### Install Git
```bash
sudo apt install git -y
```

### Step 2: Clone Repository

```bash
git clone https://github.com/yourusername/prosora-ghost-blog-CMS.git
cd prosora-ghost-blog-CMS
```

### Step 3: Environment Configuration

#### Copy Environment Template
```bash
cp .env.example .env
```

#### Configure Required Variables

Edit `.env` file with your settings:

```bash
# Domain and Site Configuration
SITE_URL=https://yourdomain.com
ADMIN_EMAIL=admin@yourdomain.com

# Database Configuration
MYSQL_ROOT_PASSWORD=your_secure_root_password
MYSQL_DATABASE=ghost_production
MYSQL_USER=ghost_user
MYSQL_PASSWORD=your_secure_db_password

# Email Configuration (Resend)
RESEND_API_KEY=your_resend_api_key
MAIL_FROM=noreply@yourdomain.com

# Media Storage (Cloudinary)
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

# Payment Processing (Stripe)
STRIPE_PUBLISHABLE_KEY=pk_live_your_publishable_key
STRIPE_SECRET_KEY=sk_live_your_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# Analytics (TinyBird)
TINYBIRD_API_KEY=your_tinybird_api_key
TINYBIRD_DATASOURCE=your_datasource_name
```

### Step 4: DNS Configuration

Point your domain to your server:

```
A Record: @ -> YOUR_SERVER_IP
A Record: www -> YOUR_SERVER_IP
```

### Step 5: Deploy Services

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps
```

### Step 6: SSL Certificate Setup

SSL certificates are automatically handled by Caddy. Verify:

```bash
# Check Caddy logs
docker logs prosora-caddy

# Test SSL
curl -I https://yourdomain.com
```

### Step 7: Ghost Initial Setup

1. Visit `https://yourdomain.com/ghost`
2. Create your admin account
3. Configure your site settings
4. Set up your theme

## 🔧 Service Integration

### Email Setup (Resend)

1. Sign up at [Resend](https://resend.com)
2. Create an API key
3. Add your domain and verify it
4. Update `.env` with your API key

### Media Storage (Cloudinary)

1. Sign up at [Cloudinary](https://cloudinary.com)
2. Get your cloud name, API key, and secret
3. Update `.env` with your credentials
4. Ghost will automatically use Cloudinary for image uploads

### Payment Processing (Stripe)

1. Sign up at [Stripe](https://stripe.com)
2. Get your publishable and secret keys
3. Set up webhook endpoints in Stripe dashboard:
   - Endpoint URL: `https://yourdomain.com/members/webhooks/stripe/`
   - Events: `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`, `invoice.payment_succeeded`, `invoice.payment_failed`
4. Update `.env` with your keys and webhook secret

### Analytics (TinyBird)

1. Sign up at [TinyBird](https://tinybird.co)
2. Create a data source for Ghost analytics
3. Get your API key
4. Update `.env` with your credentials

### CDN Setup (Cloudflare)

1. Sign up at [Cloudflare](https://cloudflare.com)
2. Add your domain
3. Update nameservers at your domain registrar
4. Enable proxy for your domain records
5. Configure SSL/TLS settings to "Full (strict)"

## 🛠️ Management Commands

### Daily Operations

```bash
# Check system status
./scripts/manage.sh status

# View logs
./scripts/manage.sh logs ghost
./scripts/manage.sh logs all

# Restart services
./scripts/manage.sh restart ghost
./scripts/manage.sh restart all
```

### Maintenance

```bash
# Update all services
./scripts/manage.sh update

# Optimize database
./scripts/manage.sh optimize

# Clear cache
./scripts/manage.sh cache

# Show performance metrics
./scripts/manage.sh performance
```

### Backup & Restore

```bash
# Create backup
./scripts/backup.sh

# List backups
./scripts/restore.sh list

# Restore from backup
./scripts/restore.sh full 20231201_120000
```

## 🔒 Security Configuration

### Firewall Setup

```bash
# Install UFW
sudo apt install ufw -y

# Configure firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

### Additional Security

1. **Change default SSH port**
2. **Set up SSH key authentication**
3. **Disable root login**
4. **Enable automatic security updates**
5. **Set up fail2ban**

### Ghost Security Settings

In Ghost admin panel:
1. Enable two-factor authentication
2. Set strong passwords
3. Limit admin access
4. Regular security updates

## 📊 Performance Optimization

### Database Optimization

```bash
# Optimize database tables
./scripts/manage.sh optimize

# Monitor database performance
./scripts/manage.sh database
```

### Caching Configuration

The setup includes:
- **Redis**: For session and object caching
- **Caddy**: For static file caching
- **Cloudflare**: For CDN caching (if configured)

### Resource Monitoring

```bash
# Check resource usage
./scripts/manage.sh performance

# Monitor containers
docker stats
```

## 🚨 Troubleshooting

### Common Issues

#### Ghost Not Starting
```bash
# Check Ghost logs
docker logs prosora-ghost

# Common fixes
docker restart prosora-ghost
./scripts/manage.sh cache
```

#### SSL Certificate Issues
```bash
# Check Caddy logs
docker logs prosora-caddy

# Reload Caddy configuration
docker exec prosora-caddy caddy reload --config /etc/caddy/Caddyfile
```

#### Database Connection Issues
```bash
# Check MySQL logs
docker logs prosora-mysql

# Test database connection
docker exec prosora-mysql mysql -u$MYSQL_USER -p$MYSQL_PASSWORD -e "SELECT 1;"
```

#### Email Not Working
1. Verify Resend API key
2. Check domain verification in Resend
3. Review Ghost email settings
4. Check email logs in Ghost admin

### Performance Issues

1. **High Memory Usage**:
   - Increase server RAM
   - Optimize MySQL configuration
   - Enable swap if needed

2. **Slow Loading**:
   - Enable Cloudflare CDN
   - Optimize images
   - Check database performance

3. **High CPU Usage**:
   - Monitor container resources
   - Check for runaway processes
   - Consider server upgrade

### Getting Help

1. **Check logs**: Always start with service logs
2. **Review configuration**: Verify `.env` settings
3. **Test connectivity**: Ensure services can communicate
4. **Monitor resources**: Check if resource limits are hit
5. **Community support**: Join Ghost community forums

## 📈 Scaling Considerations

### Vertical Scaling (Upgrade Server)
- More RAM for better database performance
- More CPU cores for concurrent users
- SSD storage for faster I/O

### Horizontal Scaling (Multiple Servers)
- Load balancer setup
- Database clustering
- Shared storage for media files
- CDN for global content delivery

### Performance Monitoring
- Set up monitoring with Grafana/Prometheus
- Configure alerts for resource usage
- Regular performance audits
- Database query optimization

## 🔄 Update Process

### Regular Updates

```bash
# Update all services
./scripts/manage.sh update

# Update Ghost specifically
docker-compose pull ghost
docker-compose up -d ghost
```

### Major Version Updates

1. **Backup everything**:
   ```bash
   ./scripts/backup.sh
   ```

2. **Test in staging environment**
3. **Update during low-traffic periods**
4. **Monitor for issues post-update**
5. **Have rollback plan ready**

## 💰 Cost Optimization

### Monthly Costs Breakdown
- **InterServer VPS**: $6.00/month
- **Domain**: $10-15/year
- **Resend**: Free tier (10k emails/month)
- **Cloudinary**: Free tier (25k transformations/month)
- **Stripe**: 2.9% + 30¢ per transaction
- **TinyBird**: Free tier (1GB/month)
- **Cloudflare**: Free tier

**Total**: ~$6-7/month for full Ghost Pro equivalent

### Cost Reduction Tips
1. Use free tiers of services
2. Optimize resource usage
3. Regular cleanup of unused data
4. Monitor and adjust service plans
5. Consider annual payments for discounts

## 🎯 Next Steps

After successful setup:

1. **Content Creation**: Start writing and publishing
2. **SEO Optimization**: Configure meta tags, sitemaps
3. **Theme Customization**: Customize or install new themes
4. **Member Setup**: Configure membership and subscriptions
5. **Analytics Setup**: Connect TinyBird for detailed analytics
6. **Marketing Integration**: Set up social media, newsletters
7. **Backup Strategy**: Schedule regular automated backups
8. **Monitoring**: Set up uptime and performance monitoring

## 📚 Additional Resources

- [Ghost Documentation](https://ghost.org/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [MySQL Optimization Guide](https://dev.mysql.com/doc/refman/8.0/en/optimization.html)
- [Resend Documentation](https://resend.com/docs)
- [Cloudinary Documentation](https://cloudinary.com/documentation)
- [Stripe Documentation](https://stripe.com/docs)
- [TinyBird Documentation](https://docs.tinybird.co/)

---

**Need help?** Open an issue in the repository or check the troubleshooting section above.