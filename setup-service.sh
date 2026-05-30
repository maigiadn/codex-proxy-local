#!/bin/bash
# ==============================================================================
# Script to install and start the Codex Model Proxy systemd service on Ubuntu
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# Setup colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SERVICE_NAME="codex-proxy"
SERVICE_SOURCE="/home/teopc/.codex/codex-proxy.service"
SERVICE_DEST="/etc/systemd/system/${SERVICE_NAME}.service"

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}  Installing & Configuring ${SERVICE_NAME} Service  ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo ""

# 1. Check if source service file exists
if [ ! -f "$SERVICE_SOURCE" ]; then
    echo -e "${RED}Error: Source service file not found at:${NC}"
    echo -e "  $SERVICE_SOURCE"
    exit 1
fi

echo -e "${YELLOW}[1/4] Copying service file to system directory...${NC}"
sudo cp "$SERVICE_SOURCE" "$SERVICE_DEST"
echo -e "${GREEN}✓ Successfully copied to $SERVICE_DEST${NC}"
echo ""

# 2. Reload systemd manager configuration
echo -e "${YELLOW}[2/4] Reloading systemd daemon...${NC}"
sudo systemctl daemon-reload
echo -e "${GREEN}✓ Systemd daemon reloaded${NC}"
echo ""

# 3. Enable the service to start on boot
echo -e "${YELLOW}[3/4] Enabling service to run on boot...${NC}"
sudo systemctl enable "$SERVICE_NAME"
echo -e "${GREEN}✓ Service enabled${NC}"
echo ""

# 4. Start the service immediately
echo -e "${YELLOW}[4/4] Starting the service...${NC}"
sudo systemctl restart "$SERVICE_NAME"
echo -e "${GREEN}✓ Service started successfully${NC}"
echo ""

# Verify service status
echo -e "${YELLOW}Checking service status...${NC}"
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "${GREEN}● $SERVICE_NAME is running successfully!${NC}"
else
    echo -e "${RED}● $SERVICE_NAME is not running. Please check logs using:${NC}"
    echo "  journalctl -u $SERVICE_NAME -n 50 --no-pager"
fi
echo ""
echo -e "${BLUE}====================================================${NC}"
