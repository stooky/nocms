# Ubuntu Deployment Guide for Astro Static Sites

This guide covers deploying Astro static sites to a Vultr Ubuntu instance, with support for hosting multiple websites on a single IP address.

## Table of Contents

1. [Initial Server Setup](#initial-server-setup)
2. [Quick Deploy (Single Site)](#quick-deploy-single-site)
3. [Multi-Site Nginx Configuration](#multi-site-nginx-configuration)
4. [Manual Deployment Steps](#manual-deployment-steps)
5. [Automated Deployments](#automated-deployments)
6. [Maintenance & Troubleshooting](#maintenance--troubleshooting)

---

## Initial Server Setup

### 1. Create Vultr Instance

1. Log into [Vultr](https://vultr.com)
2. Deploy a new server:
   - **Type**: Cloud Compute (Shared or Dedicated CPU)
   - **Location**: Choose closest to your audience
   - **Image**: Ubuntu 24.04 LTS (or 22.04 LTS)
   - **Plan**: $6/month (1 vCPU, 1GB RAM) is sufficient for multiple static sites
   - **Additional Features**: Enable IPv6, disable auto-backups initially

3. Note your server's IP address after deployment

### 2. Initial SSH Access

```bash
# Connect to your server
ssh root@YOUR_SERVER_IP

# Update system
apt update && apt upgrade -y

# Set timezone
timedatectl set-timezone America/New_York  # Change to your timezone

# Create a non-root user (recommended)
adduser deploy
usermod -aG sudo deploy

# Setup SSH key authentication (more secure)
mkdir -p /home/deploy/.ssh
cp ~/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
```

### 3. Install Required Packages

```bash
# Install Nginx and essentials
apt install -y nginx certbot python3-certbot-nginx git curl ufw

# Configure firewall
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# Start Nginx
systemctl enable nginx
systemctl start nginx
```

---

## Quick Deploy (Single Site)

### Using the Deploy Script

```bash
# On your local machine, build the site
npm run build

# Copy deploy script and dist to server
scp -r deploy/ dist/ root@YOUR_SERVER_IP:/tmp/

# SSH into server and run
ssh root@YOUR_SERVER_IP
cd /tmp
chmod +x deploy/deploy.sh
./deploy/deploy.sh yourdomain.com
```

---

## Multi-Site Nginx Configuration

This is the key section for hosting multiple websites on a single IP address.

### How It Works

Nginx uses **server blocks** (similar to Apache's virtual hosts) to serve different websites based on the domain name in the HTTP request. Each website gets its own configuration file.

### Directory Structure

```
/var/www/
├── site1.com/
│   ├── html/           # Built website files
│   └── logs/           # Access and error logs
├── site2.com/
│   ├── html/
│   └── logs/
└── site3.com/
    ├── html/
    └── logs/

/etc/nginx/
├── nginx.conf          # Main config
├── sites-available/    # All site configs
│   ├── site1.com
│   ├── site2.com
│   └── site3.com
└── sites-enabled/      # Symlinks to active sites
    ├── site1.com -> ../sites-available/site1.com
    ├── site2.com -> ../sites-available/site2.com
    └── site3.com -> ../sites-available/site3.com
```

### Step-by-Step: Adding a New Site

#### 1. Create Directory Structure

```bash
# Replace "example.com" with your actual domain
export DOMAIN="example.com"

# Create directories
sudo mkdir -p /var/www/${DOMAIN}/html
sudo mkdir -p /var/www/${DOMAIN}/logs

# Set ownership
sudo chown -R deploy:deploy /var/www/${DOMAIN}
sudo chmod -R 755 /var/www/${DOMAIN}
```

#### 2. Create Nginx Site Configuration

```bash
sudo nano /etc/nginx/sites-available/${DOMAIN}
```

Paste this configuration:

```nginx
# ------------------------------------------------------------------------------
# example.com - Static Site Configuration
# ------------------------------------------------------------------------------

server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;

    root /var/www/example.com/html;
    index index.html;

    # Logging
    access_log /var/www/example.com/logs/access.log;
    error_log /var/www/example.com/logs/error.log;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml
        application/xml+rss
        image/svg+xml;

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    location ~* \.(css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # HTML - shorter cache
    location ~* \.html$ {
        expires 1h;
        add_header Cache-Control "public, must-revalidate";
    }

    # Main location
    location / {
        try_files $uri $uri/ $uri.html =404;
    }

    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;

    # Deny hidden files
    location ~ /\. {
        deny all;
    }
}
```

#### 3. Enable the Site

```bash
# Create symlink to enable site
sudo ln -s /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

#### 4. Setup DNS

In your domain registrar (Namecheap, Cloudflare, etc.):

| Type | Host | Value | TTL |
|------|------|-------|-----|
| A | @ | YOUR_SERVER_IP | 300 |
| A | www | YOUR_SERVER_IP | 300 |
| AAAA | @ | YOUR_IPV6 (if enabled) | 300 |
| AAAA | www | YOUR_IPV6 (if enabled) | 300 |

#### 5. Setup SSL Certificate

```bash
# Get SSL certificate (will auto-configure Nginx)
sudo certbot --nginx -d example.com -d www.example.com

# Verify auto-renewal is set up
sudo certbot renew --dry-run
```

#### 6. Deploy Your Site Files

From your local machine:

```bash
# Build your Astro site
npm run build

# Copy to server
rsync -avz --delete dist/ deploy@YOUR_SERVER_IP:/var/www/example.com/html/
```

### Complete Multi-Site Example

Here's a complete example with three sites:

```bash
# Site 1: membersolutions.com
sudo mkdir -p /var/www/membersolutions.com/{html,logs}
# (create nginx config, enable, get SSL, deploy)

# Site 2: myfitnessstudio.com
sudo mkdir -p /var/www/myfitnessstudio.com/{html,logs}
# (create nginx config, enable, get SSL, deploy)

# Site 3: martialarts-school.com
sudo mkdir -p /var/www/martialarts-school.com/{html,logs}
# (create nginx config, enable, get SSL, deploy)
```

### Quick Add Site Script

Save this as `/home/deploy/add-site.sh`:

```bash
#!/bin/bash
# Quick script to add a new site
# Usage: sudo ./add-site.sh domain.com

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 domain.com"
    exit 1
fi

# Create directories
mkdir -p /var/www/${DOMAIN}/{html,logs}
chown -R deploy:deploy /var/www/${DOMAIN}

# Create nginx config
cat > /etc/nginx/sites-available/${DOMAIN} << EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};

    root /var/www/${DOMAIN}/html;
    index index.html;

    access_log /var/www/${DOMAIN}/logs/access.log;
    error_log /var/www/${DOMAIN}/logs/error.log;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml image/svg+xml;

    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp|woff|woff2|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location / {
        try_files \$uri \$uri/ \$uri.html =404;
    }

    error_page 404 /404.html;
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/

# Test and reload
nginx -t && systemctl reload nginx

echo ""
echo "Site ${DOMAIN} configured!"
echo ""
echo "Next steps:"
echo "  1. Point DNS A record to this server"
echo "  2. Run: sudo certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}"
echo "  3. Deploy files to: /var/www/${DOMAIN}/html/"
```

---

## Manual Deployment Steps

### Build Locally, Deploy via rsync

This is the recommended approach for Astro static sites:

```bash
# On your local machine

# 1. Build the site
npm run build

# 2. Deploy to server
rsync -avz --delete \
    --exclude '.git' \
    --exclude 'node_modules' \
    dist/ deploy@YOUR_SERVER_IP:/var/www/yourdomain.com/html/

# 3. (Optional) Reload Nginx if needed
ssh deploy@YOUR_SERVER_IP 'sudo systemctl reload nginx'
```

### Create a Local Deploy Script

Save as `deploy-to-server.sh` in your project root:

```bash
#!/bin/bash
# Local deployment script
# Usage: ./deploy-to-server.sh

DOMAIN="membersolutions.com"
SERVER="YOUR_SERVER_IP"
USER="deploy"

echo "Building site..."
npm run build

echo "Deploying to ${DOMAIN}..."
rsync -avz --delete dist/ ${USER}@${SERVER}:/var/www/${DOMAIN}/html/

echo "Done! Site deployed to https://${DOMAIN}"
```

---

## Automated Deployments

### GitHub Actions Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Build site
        run: npm run build

      - name: Deploy to server
        uses: easingthemes/ssh-deploy@main
        with:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
          REMOTE_HOST: ${{ secrets.SERVER_IP }}
          REMOTE_USER: deploy
          SOURCE: "dist/"
          TARGET: "/var/www/${{ secrets.DOMAIN }}/html/"
          ARGS: "-avz --delete"
```

### Required GitHub Secrets

In your GitHub repo, go to Settings > Secrets and add:

- `SSH_PRIVATE_KEY`: Your SSH private key for the deploy user
- `SERVER_IP`: Your Vultr server IP
- `DOMAIN`: Your domain (e.g., `membersolutions.com`)

### Generate Deploy SSH Key

```bash
# On your local machine
ssh-keygen -t ed25519 -C "github-deploy" -f ~/.ssh/github-deploy

# Copy public key to server
ssh-copy-id -i ~/.ssh/github-deploy.pub deploy@YOUR_SERVER_IP

# Add private key content to GitHub secrets
cat ~/.ssh/github-deploy
```

---

## Maintenance & Troubleshooting

### Useful Commands

```bash
# Check Nginx status
sudo systemctl status nginx

# View Nginx errors
sudo nginx -t
sudo tail -f /var/log/nginx/error.log

# View site-specific logs
tail -f /var/www/yourdomain.com/logs/error.log
tail -f /var/www/yourdomain.com/logs/access.log

# Reload Nginx after config changes
sudo systemctl reload nginx

# Restart Nginx completely
sudo systemctl restart nginx

# List all enabled sites
ls -la /etc/nginx/sites-enabled/

# Check SSL certificate status
sudo certbot certificates

# Renew all certificates manually
sudo certbot renew

# Check disk usage
df -h
du -sh /var/www/*

# Check memory usage
free -h
htop
```

### Common Issues

#### 1. "502 Bad Gateway"
- Check if the site files exist in the html directory
- Verify file permissions: `ls -la /var/www/yourdomain.com/html/`

#### 2. "403 Forbidden"
```bash
# Fix permissions
sudo chown -R deploy:deploy /var/www/yourdomain.com
sudo chmod -R 755 /var/www/yourdomain.com
```

#### 3. DNS not resolving
- Wait 5-10 minutes for DNS propagation
- Check DNS: `dig yourdomain.com`
- Verify A record points to correct IP

#### 4. SSL certificate errors
```bash
# Re-run certbot
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com --force-renewal
```

#### 5. Site showing old content
```bash
# Clear browser cache or test in incognito
# Check if correct files are deployed
ls -la /var/www/yourdomain.com/html/
```

### Log Rotation

Add log rotation to prevent disk filling up:

```bash
sudo nano /etc/logrotate.d/websites
```

```
/var/www/*/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 deploy deploy
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}
```

### Backup Script

Save as `/home/deploy/backup-sites.sh`:

```bash
#!/bin/bash
# Backup all website files

BACKUP_DIR="/home/deploy/backups"
DATE=$(date +%Y%m%d)

mkdir -p ${BACKUP_DIR}

for site in /var/www/*/; do
    sitename=$(basename $site)
    tar -czf ${BACKUP_DIR}/${sitename}-${DATE}.tar.gz -C /var/www ${sitename}
done

# Keep only last 7 days
find ${BACKUP_DIR} -name "*.tar.gz" -mtime +7 -delete

echo "Backup complete: ${BACKUP_DIR}"
```

Add to crontab for daily backups:

```bash
crontab -e
# Add this line:
0 2 * * * /home/deploy/backup-sites.sh
```

---

## Quick Reference

### Adding a New Site Checklist

- [ ] Create directories: `/var/www/domain.com/{html,logs}`
- [ ] Create Nginx config: `/etc/nginx/sites-available/domain.com`
- [ ] Enable site: `ln -s sites-available/domain.com sites-enabled/`
- [ ] Test config: `nginx -t`
- [ ] Reload Nginx: `systemctl reload nginx`
- [ ] Setup DNS A records pointing to server IP
- [ ] Get SSL: `certbot --nginx -d domain.com -d www.domain.com`
- [ ] Deploy files to `/var/www/domain.com/html/`
- [ ] Test the site

### Deploy New Version

```bash
# Local machine
npm run build
rsync -avz --delete dist/ deploy@SERVER:/var/www/domain.com/html/
```

### Server Info Template

Keep this info handy:

```
Server IP: _______________
SSH User: deploy
SSH Key: ~/.ssh/your-key

Sites:
- membersolutions.com -> /var/www/membersolutions.com/html/
- site2.com -> /var/www/site2.com/html/
- site3.com -> /var/www/site3.com/html/
```
