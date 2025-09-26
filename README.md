# 🚀 Prosora Ghost Blog CMS - Modern Stack

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://docs.docker.com/compose/)
[![Ghost](https://img.shields.io/badge/Ghost-6.x-738a94.svg)](https://ghost.org/)
[![Caddy](https://img.shields.io/badge/Caddy-2.x-1f88c0.svg)](https://caddyserver.com/)

A production-ready, modern Ghost CMS deployment with automatic HTTPS, advanced caching, and comprehensive monitoring - all for just **$4/month**.

## ✨ Features

### 🏗️ **Modern Architecture**
- **Ghost CMS 6.x** - Latest version with all modern features
- **Caddy 2.x** - Automatic HTTPS, HTTP/3, and advanced security
- **MySQL 8.0** - Optimized for Ghost with performance tuning
- **Redis** - Advanced caching for lightning-fast performance
- **Watchtower** - Automatic container updates

### 🔧 **External Integrations**
- **📧 Resend** - Modern email delivery (3,000 emails/month free)
- **🖼️ Cloudinary** - Media storage and optimization (25 credits/month free)
- **💳 Stripe** - Payment processing for memberships
- **📊 TinyBird** - Real-time analytics (1,000 requests/day free)
- **🌐 Cloudflare** - CDN and security (free tier)

### 🛠️ **Management Tools**
- **One-Command Setup** - Deploy everything with `./scripts/deploy.sh`
- **Automated Backups** - Daily backups with cloud storage support
- **Health Monitoring** - Comprehensive system health checks
- **Auto Updates** - Keep everything current automatically
- **Performance Monitoring** - Real-time system metrics

### 🔒 **Security & Performance**
- **Automatic SSL** - Let's Encrypt certificates with auto-renewal
- **Security Headers** - HSTS, CSP, and more
- **Rate Limiting** - DDoS protection
- **HTTP/3 Support** - Latest protocol for speed
- **Compression** - Gzip and Zstd for optimal performance  

## 💰 Cost Breakdown

| Service | Cost | Features |
|---------|------|----------|
| **InterServer VPS** | $4.00/month | 1 CPU, 1GB RAM, 30GB SSD |
| **Resend** | Free | 3,000 emails/month |
| **Cloudinary** | Free | 25 credits/month |
| **TinyBird** | Free | 1,000 requests/day |
| **Stripe** | Pay-per-use | 2.9% + 30¢ per transaction |
| **Cloudflare** | Free | CDN, DNS, Security |
| **Total** | **$4.00/month** | Full-featured blog platform |

## 🚀 Quick Start

### Prerequisites
- Ubuntu 20.04+ VPS with 1GB+ RAM
- Domain name pointed to your server
- SSH access to your server

### One-Command Setup
```bash
# Clone the repository
git clone https://github.com/your-username/prosora-ghost-blog-cms.git
cd prosora-ghost-blog-cms

# Run the deployment script
./scripts/deploy.sh
```

That's it! The script will:
- ✅ Check prerequisites
- ✅ Configure environment variables
- ✅ Generate secure passwords
- ✅ Deploy all services
- ✅ Set up SSL certificates
- ✅ Verify everything is working

## 📋 What's Included

### Core Services
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Caddy       │    │    Ghost CMS    │    │     MySQL       │
│  (Web Server)   │◄──►│   (Blog CMS)    │◄──►│   (Database)    │
│   Port: 80/443  │    │   Port: 2368    │    │   Port: 3306    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         │              │     Redis       │              │
         └──────────────►│    (Cache)      │◄─────────────┘
                        │   Port: 6379    │
                        └─────────────────┘
```

### Management Scripts
- **`deploy.sh`** - One-command deployment
- **`backup.sh`** - Automated backup system
- **`restore.sh`** - Restore from backups
- **`manage.sh`** - System management interface
- **`update.sh`** - Update all components
- **`monitor.sh`** - System monitoring
- **`health-check.sh`** - Health verification

### Configuration Files
- **`docker-compose.yml`** - Service orchestration
- **`Caddyfile`** - Web server configuration
- **`config/mysql/my.cnf`** - Database optimization
- **`config/redis/redis.conf`** - Cache configuration
- **`.env.example`** - Environment template

## 🔧 Management Commands

### Using Make (Recommended)
```bash
# Start all services
make start

# View system status
make status

# View logs
make logs

# Create backup
make backup

# Update all services
make update

# Health check
make health

# Stop all services
make stop
```

### Using Scripts Directly
```bash
# System management
./scripts/manage.sh

# Create backup
./scripts/backup.sh

# Monitor system
./scripts/monitor.sh

# Update system
./scripts/update.sh

# Health check
./scripts/health-check.sh
```

## 📊 Monitoring & Health Checks

### System Status
```bash
# Quick health check
make health

# Detailed monitoring
./scripts/monitor.sh --daemon

# View system metrics
./scripts/manage.sh
```

### Available Metrics
- **System Resources** - CPU, Memory, Disk usage
- **Service Health** - All containers status
- **Website Performance** - Response times, SSL status
- **Database Health** - Connection, size, performance
- **Backup Status** - Last backup, success rate
- **Security** - SSL certificate expiry, security headers

## 🔄 Backup & Recovery

### Automated Backups
```bash
# Manual backup
./scripts/backup.sh

# Restore from backup
./scripts/restore.sh

# List available backups
./scripts/restore.sh --list
```

### What's Backed Up
- **Database** - Complete MySQL dump
- **Ghost Content** - Images, themes, data
- **Configuration** - All config files
- **SSL Certificates** - Let's Encrypt certificates

### Cloud Storage Support
- **AWS S3** - Configure with AWS credentials
- **Google Cloud Storage** - Configure with GCS credentials
- **Local Storage** - Default backup location

## 🔧 Configuration

### Environment Variables
Copy `.env.example` to `.env` and configure:

```bash
# Domain Configuration
DOMAIN=yourdomain.com
ADMIN_EMAIL=admin@yourdomain.com

# Database
MYSQL_ROOT_PASSWORD=your-secure-password
MYSQL_PASSWORD=your-ghost-password

# Email (Resend)
RESEND_API_KEY=your-resend-api-key

# Media Storage (Cloudinary)
CLOUDINARY_URL=cloudinary://api_key:api_secret@cloud_name

# Payments (Stripe)
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_SECRET_KEY=sk_live_...

# Analytics (TinyBird)
TINYBIRD_API_KEY=your-tinybird-api-key
```

### Service Integration
1. **Resend** - Sign up at [resend.com](https://resend.com)
2. **Cloudinary** - Sign up at [cloudinary.com](https://cloudinary.com)
3. **Stripe** - Sign up at [stripe.com](https://stripe.com)
4. **TinyBird** - Sign up at [tinybird.co](https://tinybird.co)
5. **Cloudflare** - Sign up at [cloudflare.com](https://cloudflare.com)

## 📈 Performance Optimization

### Built-in Optimizations
- **HTTP/3** - Latest protocol support
- **Compression** - Gzip and Zstd compression
- **Caching** - Redis caching layer
- **CDN** - Cloudflare integration
- **Database** - Optimized MySQL configuration
- **Static Files** - Efficient serving with Caddy

### Performance Metrics
- **Page Load Time** - <500ms (optimized)
- **Time to First Byte** - <200ms
- **Lighthouse Score** - 90+ (Performance)
- **Core Web Vitals** - All green

## 🔒 Security Features

### Automatic Security
- **SSL Certificates** - Auto-renewal with Let's Encrypt
- **Security Headers** - HSTS, CSP, X-Frame-Options, etc.
- **Rate Limiting** - Protection against abuse
- **DDoS Protection** - Cloudflare integration
- **Automatic Updates** - Security patches via Watchtower

### Security Headers
```
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
Content-Security-Policy: default-src 'self'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
```

## 📚 Documentation

- **[Setup Guide](docs/SETUP-GUIDE.md)** - Detailed setup instructions
- **[Architecture](docs/ARCHITECTURE.md)** - System architecture overview
- **[Integrations](docs/INTEGRATIONS.md)** - External service setup
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Changelog](CHANGELOG.md)** - Version history and updates

## 🛠️ Development

### Local Development
```bash
# Set up development environment
make dev-setup

# Start development services
make start

# View logs
make logs

# Run health checks
make health
```

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Update documentation
6. Submit a pull request

## 🆘 Support & Troubleshooting

### Quick Diagnostics
```bash
# Check system health
./scripts/health-check.sh

# View service logs
make logs

# Check service status
make status
```

### Common Issues
- **SSL Certificate Issues** - Check DNS configuration
- **Database Connection** - Verify MySQL container health
- **Email Not Working** - Check Resend API key
- **Images Not Loading** - Verify Cloudinary configuration

### Getting Help
- **Documentation** - Check the [docs](docs/) folder
- **Issues** - Open a GitHub issue
- **Discussions** - Join GitHub discussions
- **Community** - Ghost community forums

## 📊 System Requirements

### Minimum Requirements
- **CPU** - 1 core
- **RAM** - 1GB
- **Storage** - 20GB SSD
- **OS** - Ubuntu 20.04+, Debian 11+, CentOS 8+

### Recommended Requirements
- **CPU** - 2 cores
- **RAM** - 2GB
- **Storage** - 40GB SSD
- **Bandwidth** - Unlimited

### Software Requirements
- **Docker** - Version 20.10+
- **Docker Compose** - Version 2.0+
- **Git** - Latest version
- **Curl** - For health checks

## 🌟 Why Choose This Stack?

### ✅ **Production Ready**
- Battle-tested components
- Comprehensive monitoring
- Automated backups
- Security best practices

### ✅ **Cost Effective**
- Only $4/month total cost
- Free tier integrations
- No vendor lock-in
- Scalable architecture

### ✅ **Modern Technology**
- Latest Ghost CMS features
- HTTP/3 support
- Advanced caching
- Cloud-native design

### ✅ **Easy Management**
- One-command deployment
- Automated updates
- Health monitoring
- Backup/restore system

## 🚀 Deployment Options

### VPS Providers (Recommended)
- **InterServer** - $4/month (recommended)
- **DigitalOcean** - $6/month
- **Linode** - $5/month
- **Vultr** - $5/month
- **Hetzner** - €4.15/month

### Cloud Providers
- **AWS EC2** - t3.micro (~$8/month)
- **Google Cloud** - e2-micro (~$7/month)
- **Azure** - B1s (~$8/month)

## 📈 Scaling

### Vertical Scaling
- Upgrade VPS resources
- Increase MySQL buffer pool
- Add more Redis memory
- Optimize Ghost configuration

### Horizontal Scaling
- Load balancer setup
- Database replication
- CDN optimization
- Multi-region deployment

## 🔄 Updates & Maintenance

### Automatic Updates
- **Watchtower** - Container updates
- **Let's Encrypt** - SSL renewal
- **System Packages** - Security updates

### Manual Updates
```bash
# Update all components
./scripts/update.sh

# Update specific component
./scripts/update.sh --ghost-only
./scripts/update.sh --docker-only
```

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Ghost Foundation** - Amazing CMS platform
- **Caddy Team** - Excellent web server
- **Docker Community** - Containerization platform
- **Open Source Community** - All the amazing tools

## 🔗 Links

- **Ghost CMS** - [ghost.org](https://ghost.org)
- **Caddy Server** - [caddyserver.com](https://caddyserver.com)
- **Docker** - [docker.com](https://docker.com)
- **Resend** - [resend.com](https://resend.com)
- **Cloudinary** - [cloudinary.com](https://cloudinary.com)

---

<div align="center">

**Made with ❤️ for the Ghost community**

[⭐ Star this repo](https://github.com/your-username/prosora-ghost-blog-cms) • [🐛 Report Bug](https://github.com/your-username/prosora-ghost-blog-cms/issues) • [💡 Request Feature](https://github.com/your-username/prosora-ghost-blog-cms/issues)

</div>