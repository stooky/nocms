#!/bin/bash
#
# Member Solutions Website Deployment Script
# For Ubuntu 22.04/24.04 LTS on Vultr
#
# Usage: ./deploy.sh <domain> [options]
# Example: ./deploy.sh membersolutions.com
#          ./deploy.sh membersolutions.com --skip-ssl
#          ./deploy.sh membersolutions.com --deploy-only
#
# Options:
#   --skip-system    Skip system package installation
#   --skip-ssl       Skip SSL certificate setup
#   --deploy-only    Only deploy files (skip all setup)
#

set -e  # Exit on any error

# =============================================================================
# CONFIGURATION
# =============================================================================

# Parse arguments - extract domain and flags
DOMAIN=""
SKIP_SYSTEM=false
SKIP_SSL=false
DEPLOY_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-system)
            SKIP_SYSTEM=true
            shift
            ;;
        --skip-ssl)
            SKIP_SSL=true
            shift
            ;;
        --deploy-only)
            DEPLOY_ONLY=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            if [ -z "$DOMAIN" ]; then
                DOMAIN="$1"
            fi
            shift
            ;;
    esac
done

# Default domain if not provided
DOMAIN="${DOMAIN:-membersolutions.com}"

SITE_NAME="${DOMAIN//./-}"  # Convert dots to dashes for directory names
WEB_ROOT="/var/www/${DOMAIN}"
DEPLOY_USER="deploy"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

get_nginx_version() {
    nginx -v 2>&1 | grep -oP 'nginx/\K[0-9]+\.[0-9]+' | head -1
}

# Compare versions: returns 0 if $1 >= $2
version_gte() {
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

# =============================================================================
# SYSTEM SETUP
# =============================================================================

setup_system() {
    log_info "Updating system packages..."
    apt update && apt upgrade -y

    log_info "Installing required packages..."
    apt install -y \
        nginx \
        certbot \
        python3-certbot-nginx \
        git \
        curl \
        wget \
        ufw \
        htop \
        unzip \
        rsync \
        fail2ban

    # Enable and start fail2ban for basic security
    systemctl enable fail2ban
    systemctl start fail2ban

    log_success "System packages installed"
}

setup_firewall() {
    log_info "Configuring firewall..."

    # Don't reset if already configured - just ensure rules exist
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 'Nginx Full'

    # Enable if not already enabled
    if ! ufw status | grep -q "Status: active"; then
        ufw --force enable
    fi

    log_success "Firewall configured (SSH + Nginx allowed)"
}

create_deploy_user() {
    log_info "Setting up deploy user..."

    if ! id "${DEPLOY_USER}" &>/dev/null; then
        useradd -m -s /bin/bash ${DEPLOY_USER}
        log_success "Deploy user '${DEPLOY_USER}' created"
    else
        log_info "Deploy user '${DEPLOY_USER}' already exists"
    fi

    # Add to www-data group for nginx file access
    usermod -aG www-data ${DEPLOY_USER}

    # Allow deploy user to reload nginx without password
    cat > /etc/sudoers.d/${DEPLOY_USER} << EOF
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /usr/bin/systemctl reload nginx
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart nginx
${DEPLOY_USER} ALL=(ALL) NOPASSWD: /usr/sbin/nginx -t
EOF
    chmod 440 /etc/sudoers.d/${DEPLOY_USER}

    # Setup SSH directory if it doesn't exist
    if [ ! -d "/home/${DEPLOY_USER}/.ssh" ]; then
        mkdir -p /home/${DEPLOY_USER}/.ssh
        chmod 700 /home/${DEPLOY_USER}/.ssh
        touch /home/${DEPLOY_USER}/.ssh/authorized_keys
        chmod 600 /home/${DEPLOY_USER}/.ssh/authorized_keys
        chown -R ${DEPLOY_USER}:${DEPLOY_USER} /home/${DEPLOY_USER}/.ssh
    fi

    log_success "Deploy user configured"
}

# =============================================================================
# WEBSITE SETUP
# =============================================================================

setup_web_directory() {
    log_info "Setting up web directory for ${DOMAIN}..."

    # Create directory structure
    mkdir -p ${WEB_ROOT}/html
    mkdir -p ${WEB_ROOT}/logs

    # Create a placeholder index.html
    if [ ! -f "${WEB_ROOT}/html/index.html" ]; then
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
    fi

    # Set ownership - deploy user owns files, www-data group for nginx access
    chown -R ${DEPLOY_USER}:www-data ${WEB_ROOT}
    chmod -R 755 ${WEB_ROOT}

    log_success "Web directory created at ${WEB_ROOT}"
}

setup_nginx_site() {
    log_info "Configuring Nginx for ${DOMAIN}..."

    # Detect Nginx version for HTTP/2 configuration
    NGINX_VERSION=$(get_nginx_version)

    # Nginx 1.25.1+ uses 'http2 on;' instead of 'listen ... http2'
    if version_gte "$NGINX_VERSION" "1.25"; then
        HTTP2_CONFIG="http2 on;"
        LISTEN_SSL="listen 443 ssl;"
        LISTEN_SSL_IPV6="listen [::]:443 ssl;"
    else
        HTTP2_CONFIG=""
        LISTEN_SSL="listen 443 ssl http2;"
        LISTEN_SSL_IPV6="listen [::]:443 ssl http2;"
    fi

    # Create Nginx site configuration
    cat > /etc/nginx/sites-available/${DOMAIN} << NGINX_CONFIG
# ------------------------------------------------------------------------------
# ${DOMAIN} - Astro Static Site Configuration
# Generated: $(date)
# ------------------------------------------------------------------------------

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};

    root ${WEB_ROOT}/html;
    index index.html;

    # Logging
    access_log ${WEB_ROOT}/logs/access.log;
    error_log ${WEB_ROOT}/logs/error.log;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;

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
        application/atom+xml
        image/svg+xml
        font/truetype
        font/opentype
        application/vnd.ms-fontobject;

    # Static file caching - Astro uses content hashing so long cache is safe
    location ~* \.(jpg|jpeg|png|gif|ico|svg|webp|avif)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    location ~* \.(woff|woff2|ttf|eot|otf)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header Access-Control-Allow-Origin "*";
        access_log off;
    }

    location ~* \.(css|js)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # HTML files - shorter cache for content updates
    location ~* \.html$ {
        expires 1h;
        add_header Cache-Control "public, must-revalidate";
    }

    # Main location block
    location / {
        try_files \$uri \$uri/ \$uri.html =404;
    }

    # Custom error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;

    # Deny access to hidden files (except .well-known for SSL verification)
    location ~ /\.(?!well-known) {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Deny access to sensitive file types
    location ~* \.(bak|conf|dist|fla|inc|ini|log|psd|sh|sql|swp)$ {
        deny all;
        access_log off;
        log_not_found off;
    }
}
NGINX_CONFIG

    # Remove default site if it exists
    if [ -f /etc/nginx/sites-enabled/default ]; then
        rm -f /etc/nginx/sites-enabled/default
    fi

    # Enable site
    ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/

    # Test and reload nginx
    if nginx -t; then
        systemctl reload nginx
        log_success "Nginx configured for ${DOMAIN}"
    else
        log_error "Nginx configuration test failed!"
        exit 1
    fi
}

setup_ssl() {
    log_info "Setting up SSL certificate for ${DOMAIN}..."

    # Check if DNS is pointing to this server
    SERVER_IP=$(curl -s ifconfig.me)
    DOMAIN_IP=$(dig +short ${DOMAIN} | head -1)

    if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
        log_warning "DNS may not be configured correctly."
        log_warning "Server IP: ${SERVER_IP}"
        log_warning "Domain IP: ${DOMAIN_IP:-not resolved}"
        read -p "Continue with SSL setup anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "Skipping SSL setup. Run later with: sudo certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}"
            return
        fi
    fi

    # Obtain SSL certificate
    certbot --nginx \
        -d ${DOMAIN} \
        -d www.${DOMAIN} \
        --non-interactive \
        --agree-tos \
        --email admin@${DOMAIN} \
        --redirect \
        --staple-ocsp

    # Certbot timer should already be enabled on Ubuntu, but ensure it is
    systemctl enable certbot.timer 2>/dev/null || true
    systemctl start certbot.timer 2>/dev/null || true

    log_success "SSL certificate installed and auto-renewal configured"
}

# =============================================================================
# DEPLOYMENT
# =============================================================================

deploy_site() {
    log_info "Deploying website files..."

    # If this script is run from the project directory with dist folder
    if [ -d "./dist" ]; then
        rsync -avz --delete \
            --exclude '.git' \
            --exclude '.DS_Store' \
            ./dist/ ${WEB_ROOT}/html/

        # Set proper ownership
        chown -R ${DEPLOY_USER}:www-data ${WEB_ROOT}/html
        chmod -R 755 ${WEB_ROOT}/html

        log_success "Site deployed from local dist folder"
    else
        log_warning "No dist folder found. Deploy manually with:"
        echo ""
        echo "  From your local machine:"
        echo "  npm run build"
        echo "  rsync -avz --delete dist/ ${DEPLOY_USER}@<server-ip>:${WEB_ROOT}/html/"
        echo ""
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo ""
    echo "=============================================="
    echo "  Website Deployment Script"
    echo "  Domain: ${DOMAIN}"
    echo "=============================================="
    echo ""

    check_root

    if [ "$DEPLOY_ONLY" = true ]; then
        deploy_site
        echo ""
        log_success "Deployment complete!"
        exit 0
    fi

    if [ "$SKIP_SYSTEM" = false ]; then
        setup_system
        setup_firewall
        create_deploy_user
    fi

    setup_web_directory
    setup_nginx_site

    if [ "$SKIP_SSL" = false ]; then
        read -p "Setup SSL certificate now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_ssl
        else
            log_warning "Skipping SSL setup. Run later: sudo certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}"
        fi
    fi

    deploy_site

    echo ""
    echo "=============================================="
    echo "  Deployment Complete!"
    echo "=============================================="
    echo ""
    echo "Summary:"
    echo "  Domain:     ${DOMAIN}"
    echo "  Web Root:   ${WEB_ROOT}/html"
    echo "  Logs:       ${WEB_ROOT}/logs"
    echo "  Deploy User: ${DEPLOY_USER}"
    echo ""
    echo "Next steps:"
    echo "  1. Point your domain DNS A record to this server's IP: $(curl -s ifconfig.me)"
    echo "  2. Add your SSH key to /home/${DEPLOY_USER}/.ssh/authorized_keys"
    echo "  3. Deploy your site: rsync -avz --delete dist/ ${DEPLOY_USER}@<ip>:${WEB_ROOT}/html/"
    if [ "$SKIP_SSL" = true ]; then
        echo "  4. Setup SSL: sudo certbot --nginx -d ${DOMAIN} -d www.${DOMAIN}"
    fi
    echo ""
}

main
