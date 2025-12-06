#!/bin/bash
#
# Member Solutions Website Deployment Script
# For Ubuntu 22.04/24.04 LTS on Vultr
#
# Usage: ./deploy.sh [domain]
# Example: ./deploy.sh membersolutions.com
#

set -e  # Exit on any error

# =============================================================================
# CONFIGURATION
# =============================================================================

DOMAIN="${1:-membersolutions.com}"
SITE_NAME="${DOMAIN//./-}"  # Convert dots to dashes for directory names
WEB_ROOT="/var/www/${DOMAIN}"
REPO_URL=""  # Set your git repo URL here if using git deployment
DEPLOY_USER="deploy"
NODE_VERSION="20"

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
        rsync

    log_success "System packages installed"
}

setup_firewall() {
    log_info "Configuring firewall..."

    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 'Nginx Full'
    ufw --force enable

    log_success "Firewall configured (SSH + Nginx allowed)"
}

setup_node() {
    log_info "Installing Node.js ${NODE_VERSION}..."

    # Install nvm for the deploy user
    if [ ! -d "/home/${DEPLOY_USER}/.nvm" ]; then
        sudo -u ${DEPLOY_USER} bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
    fi

    # Install Node.js
    sudo -u ${DEPLOY_USER} bash -c "source ~/.nvm/nvm.sh && nvm install ${NODE_VERSION} && nvm use ${NODE_VERSION} && nvm alias default ${NODE_VERSION}"

    log_success "Node.js ${NODE_VERSION} installed"
}

create_deploy_user() {
    log_info "Creating deploy user..."

    if ! id "${DEPLOY_USER}" &>/dev/null; then
        useradd -m -s /bin/bash ${DEPLOY_USER}
        usermod -aG sudo ${DEPLOY_USER}

        # Allow deploy user to restart nginx without password
        echo "${DEPLOY_USER} ALL=(ALL) NOPASSWD: /usr/sbin/nginx, /bin/systemctl reload nginx, /bin/systemctl restart nginx" > /etc/sudoers.d/${DEPLOY_USER}
        chmod 440 /etc/sudoers.d/${DEPLOY_USER}

        log_success "Deploy user '${DEPLOY_USER}' created"
    else
        log_warning "Deploy user '${DEPLOY_USER}' already exists"
    fi
}

# =============================================================================
# WEBSITE SETUP
# =============================================================================

setup_web_directory() {
    log_info "Setting up web directory for ${DOMAIN}..."

    # Create directory structure
    mkdir -p ${WEB_ROOT}/html
    mkdir -p ${WEB_ROOT}/logs

    # Set ownership
    chown -R ${DEPLOY_USER}:${DEPLOY_USER} ${WEB_ROOT}
    chmod -R 755 ${WEB_ROOT}

    log_success "Web directory created at ${WEB_ROOT}"
}

setup_nginx_site() {
    log_info "Configuring Nginx for ${DOMAIN}..."

    # Create Nginx site configuration
    cat > /etc/nginx/sites-available/${DOMAIN} << 'NGINX_CONFIG'
# ------------------------------------------------------------------------------
# DOMAIN_PLACEHOLDER - Astro Static Site Configuration
# ------------------------------------------------------------------------------

server {
    listen 80;
    listen [::]:80;
    server_name DOMAIN_PLACEHOLDER www.DOMAIN_PLACEHOLDER;

    # Redirect to HTTPS (uncomment after SSL setup)
    # return 301 https://$server_name$request_uri;

    root WEB_ROOT_PLACEHOLDER/html;
    index index.html;

    # Logging
    access_log WEB_ROOT_PLACEHOLDER/logs/access.log;
    error_log WEB_ROOT_PLACEHOLDER/logs/error.log;

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
        application/atom+xml
        image/svg+xml;

    # Static file caching
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

    # HTML files - shorter cache for content updates
    location ~* \.html$ {
        expires 1h;
        add_header Cache-Control "public, must-revalidate";
    }

    # Main location block
    location / {
        try_files $uri $uri/ $uri.html =404;
    }

    # Custom error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}

# HTTPS server block (uncomment after SSL setup)
# server {
#     listen 443 ssl http2;
#     listen [::]:443 ssl http2;
#     server_name DOMAIN_PLACEHOLDER www.DOMAIN_PLACEHOLDER;
#
#     ssl_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/privkey.pem;
#     ssl_trusted_certificate /etc/letsencrypt/live/DOMAIN_PLACEHOLDER/chain.pem;
#
#     # SSL configuration
#     ssl_session_timeout 1d;
#     ssl_session_cache shared:SSL:50m;
#     ssl_session_tickets off;
#     ssl_protocols TLSv1.2 TLSv1.3;
#     ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
#     ssl_prefer_server_ciphers off;
#
#     # HSTS
#     add_header Strict-Transport-Security "max-age=63072000" always;
#
#     root WEB_ROOT_PLACEHOLDER/html;
#     index index.html;
#
#     # ... (copy location blocks from above)
# }
NGINX_CONFIG

    # Replace placeholders
    sed -i "s|DOMAIN_PLACEHOLDER|${DOMAIN}|g" /etc/nginx/sites-available/${DOMAIN}
    sed -i "s|WEB_ROOT_PLACEHOLDER|${WEB_ROOT}|g" /etc/nginx/sites-available/${DOMAIN}

    # Enable site
    ln -sf /etc/nginx/sites-available/${DOMAIN} /etc/nginx/sites-enabled/

    # Test and reload nginx
    nginx -t && systemctl reload nginx

    log_success "Nginx configured for ${DOMAIN}"
}

setup_ssl() {
    log_info "Setting up SSL certificate for ${DOMAIN}..."

    # Obtain SSL certificate
    certbot --nginx -d ${DOMAIN} -d www.${DOMAIN} --non-interactive --agree-tos --email admin@${DOMAIN} --redirect

    # Setup auto-renewal
    systemctl enable certbot.timer
    systemctl start certbot.timer

    log_success "SSL certificate installed and auto-renewal configured"
}

# =============================================================================
# DEPLOYMENT
# =============================================================================

deploy_site() {
    log_info "Deploying website files..."

    # If this script is run from the project directory with dist folder
    if [ -d "./dist" ]; then
        rsync -avz --delete ./dist/ ${WEB_ROOT}/html/
        chown -R ${DEPLOY_USER}:${DEPLOY_USER} ${WEB_ROOT}/html
        log_success "Site deployed from local dist folder"
    else
        log_warning "No dist folder found. Please build and deploy manually:"
        echo "  1. Run 'npm run build' locally"
        echo "  2. Copy dist/* to ${WEB_ROOT}/html/"
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

    # Parse command line options
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
            *)
                shift
                ;;
        esac
    done

    if [ "$DEPLOY_ONLY" = true ]; then
        deploy_site
        exit 0
    fi

    if [ "$SKIP_SYSTEM" = false ]; then
        setup_system
        setup_firewall
        create_deploy_user
        setup_node
    fi

    setup_web_directory
    setup_nginx_site

    if [ "$SKIP_SSL" = false ]; then
        read -p "Setup SSL certificate now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            setup_ssl
        else
            log_warning "Skipping SSL setup. Run 'certbot --nginx -d ${DOMAIN}' later"
        fi
    fi

    deploy_site

    echo ""
    echo "=============================================="
    echo "  Deployment Complete!"
    echo "=============================================="
    echo ""
    echo "Next steps:"
    echo "  1. Point your domain DNS to this server's IP"
    echo "  2. If SSL was skipped, run: sudo certbot --nginx -d ${DOMAIN}"
    echo "  3. Test your site at: http://${DOMAIN}"
    echo ""
}

main "$@"
