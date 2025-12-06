#!/bin/bash
# ------------------------------------------------------------------------------
# Add New Site Script
# Run on your Ubuntu server to quickly add a new website
# ------------------------------------------------------------------------------
# Usage: sudo ./add-site.sh domain.com [email]
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

# Check arguments
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Usage: $0 domain.com [email]${NC}"
    echo "Example: $0 mysite.com admin@mysite.com"
    exit 1
fi

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Adding new site: ${DOMAIN}${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Step 1: Create directories
echo -e "${BLUE}[1/5] Creating directories...${NC}"
mkdir -p ${WEB_ROOT}/html
mkdir -p ${WEB_ROOT}/logs

# Create placeholder index
cat > ${WEB_ROOT}/html/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>${DOMAIN} - Coming Soon</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container { text-align: center; }
        h1 { font-size: 3rem; margin-bottom: 0.5rem; }
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
chown -R ${DEPLOY_USER}:${DEPLOY_USER} ${WEB_ROOT}
chmod -R 755 ${WEB_ROOT}

echo -e "${GREEN}  Created ${WEB_ROOT}${NC}"

# Step 2: Create Nginx config
echo -e "${BLUE}[2/5] Creating Nginx configuration...${NC}"

cat > /etc/nginx/sites-available/${DOMAIN} << EOF
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
    add_header X-XSS-Protection "1; mode=block" always;

    # Gzip
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml image/svg+xml;

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp|woff|woff2|css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location / {
        try_files \$uri \$uri/ \$uri.html =404;
    }

    error_page 404 /404.html;

    location ~ /\. {
        deny all;
    }
}
EOF

echo -e "${GREEN}  Created /etc/nginx/sites-available/${DOMAIN}${NC}"

# Step 3: Enable site
echo -e "${BLUE}[3/5] Enabling site...${NC}"
ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/

# Test nginx config
nginx -t

# Reload nginx
systemctl reload nginx

echo -e "${GREEN}  Site enabled and Nginx reloaded${NC}"

# Step 4: Setup SSL (optional)
echo ""
echo -e "${BLUE}[4/5] SSL Certificate${NC}"
echo ""
echo "Before getting SSL, ensure DNS is configured:"
echo "  A record: ${DOMAIN} -> $(curl -s ifconfig.me)"
echo "  A record: www.${DOMAIN} -> $(curl -s ifconfig.me)"
echo ""
read -p "Setup SSL now? DNS must be configured first (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --non-interactive --agree-tos --email ${EMAIL} --redirect
    echo -e "${GREEN}  SSL certificate installed${NC}"
else
    echo -e "${YELLOW}  Skipped SSL. Run later:${NC}"
    echo "  sudo certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}"
fi

# Step 5: Summary
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
echo "To deploy your site files:"
echo "  rsync -avz --delete dist/ deploy@$(hostname -I | awk '{print $1}'):${WEB_ROOT}/html/"
echo ""
echo "Current test page: http://${DOMAIN}"
echo ""
