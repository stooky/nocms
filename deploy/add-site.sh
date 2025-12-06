#!/bin/bash
# ------------------------------------------------------------------------------
# Add New Site Script
# Run on your Ubuntu server to quickly add a new website
# ------------------------------------------------------------------------------
# Usage: sudo ./add-site.sh <domain> [email]
# Example: sudo ./add-site.sh mysite.com admin@mysite.com
# ------------------------------------------------------------------------------

set -e

DOMAIN=$1
EMAIL="${2:-admin@${DOMAIN}}"
WEB_ROOT="/var/www/${DOMAIN}"
DEPLOY_USER="deploy"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check arguments
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Usage: $0 <domain> [email]${NC}"
    echo "Example: $0 mysite.com admin@mysite.com"
    exit 1
fi

# Check root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (sudo)"
    exit 1
fi

# Check if deploy user exists
if ! id "${DEPLOY_USER}" &>/dev/null; then
    log_error "Deploy user '${DEPLOY_USER}' does not exist. Run deploy.sh first."
    exit 1
fi

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Adding new site: ${DOMAIN}${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Step 1: Create directories
log_info "[1/5] Creating directories..."
mkdir -p ${WEB_ROOT}/html
mkdir -p ${WEB_ROOT}/logs

# Create placeholder index
cat > ${WEB_ROOT}/html/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${DOMAIN} - Coming Soon</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container { text-align: center; padding: 2rem; }
        h1 { font-size: 3rem; margin-bottom: 1rem; }
        p { font-size: 1.25rem; opacity: 0.9; }
    </style>
</head>
<body>
    <div class="container">
        <h1>${DOMAIN}</h1>
        <p>Coming Soon</p>
    </div>
</body>
</html>
EOF

# Set ownership
chown -R ${DEPLOY_USER}:www-data ${WEB_ROOT}
chmod -R 755 ${WEB_ROOT}

log_success "Created ${WEB_ROOT}"

# Step 2: Create Nginx config
log_info "[2/5] Creating Nginx configuration..."

cat > /etc/nginx/sites-available/${DOMAIN} << EOF
# ------------------------------------------------------------------------------
# ${DOMAIN} - Static Site Configuration
# Generated: $(date)
# ------------------------------------------------------------------------------

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};

    root ${WEB_ROOT}/html;
    index index.html;

    access_log ${WEB_ROOT}/logs/access.log;
    error_log ${WEB_ROOT}/logs/error.log;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/javascript application/json application/javascript application/xml image/svg+xml;

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp|avif|woff|woff2|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Main location
    location / {
        try_files \$uri \$uri/ \$uri.html =404;
    }

    error_page 404 /404.html;

    # Deny hidden files except .well-known
    location ~ /\.(?!well-known) {
        deny all;
    }
}
EOF

log_success "Created /etc/nginx/sites-available/${DOMAIN}"

# Step 3: Enable site
log_info "[3/5] Enabling site..."
ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/

# Test nginx config
if nginx -t 2>/dev/null; then
    systemctl reload nginx
    log_success "Site enabled and Nginx reloaded"
else
    log_error "Nginx configuration test failed!"
    rm -f /etc/nginx/sites-enabled/${DOMAIN}
    exit 1
fi

# Step 4: Setup SSL (optional)
echo ""
log_info "[4/5] SSL Certificate"
echo ""

SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")
echo "Before getting SSL, ensure DNS is configured:"
echo "  A record: ${DOMAIN} -> ${SERVER_IP}"
echo "  A record: www.${DOMAIN} -> ${SERVER_IP}"
echo ""

read -p "Setup SSL now? DNS must be configured first (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Check DNS
    DOMAIN_IP=$(dig +short ${DOMAIN} 2>/dev/null | head -1)
    if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
        log_warning "DNS may not be pointing to this server yet."
        log_warning "Server IP: ${SERVER_IP}"
        log_warning "Domain resolves to: ${DOMAIN_IP:-not found}"
        read -p "Continue anyway? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "Skipped SSL. Run later: sudo certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}"
        else
            certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --non-interactive --agree-tos --email ${EMAIL} --redirect --staple-ocsp
            log_success "SSL certificate installed"
        fi
    else
        certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --non-interactive --agree-tos --email ${EMAIL} --redirect --staple-ocsp
        log_success "SSL certificate installed"
    fi
else
    log_warning "Skipped SSL. Run later:"
    echo "  sudo certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}"
fi

# Step 5: Summary
echo ""
log_info "[5/5] Complete!"
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Site Added Successfully!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Site Details:"
echo "  Domain:     ${DOMAIN}"
echo "  Web Root:   ${WEB_ROOT}/html"
echo "  Logs:       ${WEB_ROOT}/logs"
echo "  Nginx:      /etc/nginx/sites-available/${DOMAIN}"
echo ""
echo "To deploy your site files from your local machine:"
echo "  rsync -avz --delete dist/ ${DEPLOY_USER}@${SERVER_IP}:${WEB_ROOT}/html/"
echo ""
echo "Current placeholder page: http://${DOMAIN}"
echo ""
