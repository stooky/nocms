#!/bin/bash
# ------------------------------------------------------------------------------
# Local Deploy Script
# Run this from your local machine to build and deploy to server
# ------------------------------------------------------------------------------
# Usage: ./deploy/deploy-local.sh [domain] [server-ip]
# Example: ./deploy/deploy-local.sh membersolutions.com 149.28.xx.xx
# ------------------------------------------------------------------------------

set -e

# Configuration - Update these defaults for your setup
DOMAIN="${1:-membersolutions.com}"
SERVER="${2:-YOUR_SERVER_IP}"
USER="deploy"
REMOTE_PATH="/var/www/${DOMAIN}/html"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Deploying ${DOMAIN}${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Check if we're in the project root
if [ ! -f "package.json" ]; then
    echo -e "${YELLOW}Error: package.json not found. Run from project root.${NC}"
    exit 1
fi

# Step 1: Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo -e "${BLUE}Installing dependencies...${NC}"
    npm install
fi

# Step 2: Build the site
echo -e "${BLUE}Building site...${NC}"
npm run build

# Check if build succeeded
if [ ! -d "dist" ]; then
    echo -e "${YELLOW}Error: Build failed. No dist directory.${NC}"
    exit 1
fi

# Step 3: Deploy to server
echo -e "${BLUE}Deploying to ${SERVER}...${NC}"
rsync -avz --delete \
    --exclude '.git' \
    --exclude '.gitignore' \
    --exclude 'node_modules' \
    --exclude '.DS_Store' \
    dist/ ${USER}@${SERVER}:${REMOTE_PATH}/

# Step 4: Done!
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "Site deployed to: https://${DOMAIN}"
echo ""
