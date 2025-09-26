# 🚀 Ghost CMS Deployment Commands

## Server Details
- **IP Address:** 157.250.195.253
- **OS:** Ubuntu (KVM Linux VPS)
- **User:** Will create 'ghost' user for security

## Phase 1: Initial Server Setup

### Step 1: Connect to Server
```bash
ssh root@157.250.195.253
```

### Step 2: Update System
```bash
apt update && apt upgrade -y
```

### Step 3: Install Essential Packages
```bash
apt install -y curl wget git ufw fail2ban htop nano
```

### Step 4: Create Ghost User
```bash
adduser ghost
usermod -aG sudo ghost
su - ghost
```

### Step 5: Install Docker
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker
```

### Step 6: Install Docker Compose
```bash
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

### Step 7: Verify Installation
```bash
docker --version
docker-compose --version
docker run hello-world
```

## Phase 2: Deploy Ghost CMS

### Step 8: Clone Repository
```bash
cd ~
git clone https://github.com/akashpatel/prosora-ghost-blog-cms.git
cd prosora-ghost-blog-cms
chmod +x scripts/*.sh
chmod +x deploy.sh
```

### Step 9: Configure Environment
```bash
cp .env.example .env
nano .env
```

### Step 10: Deploy Ghost
```bash
./deploy.sh
```

### Step 11: Verify Deployment
```bash
make status
./scripts/health-check.sh
```

## Access URLs
- **Website:** http://157.250.195.253
- **Admin Panel:** http://157.250.195.253/ghost
- **With Domain:** https://yourdomain.com (after DNS setup)