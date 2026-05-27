#!/bin/bash
# Gỡ cài đặt Codex Model Alias Proxy

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SERVICE_NAME="codex-proxy"

echo -e "${YELLOW}Gỡ cài đặt Codex Model Alias Proxy...${NC}"

# Stop and disable service
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo "  Dừng service..."
    sudo systemctl stop "$SERVICE_NAME"
fi

if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo "  Tắt service..."
    sudo systemctl disable "$SERVICE_NAME"
fi

if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
    echo "  Xóa service file..."
    sudo rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    sudo systemctl daemon-reload
fi

# Remove proxy script
if [ -f "$HOME/.codex/model-proxy.js" ]; then
    echo "  Xóa proxy script..."
    rm -f "$HOME/.codex/model-proxy.js"
fi

echo ""
echo -e "${GREEN}✓ Đã gỡ cài đặt proxy.${NC}"
echo ""
echo -e "${YELLOW}Lưu ý:${NC}"
echo "  - Config Codex (~/.codex/config.toml) không bị thay đổi"
echo "  - Biến môi trường trong ~/.profile và ~/.bashrc không bị thay đổi"
echo "  - Bạn cần cập nhật lại config thủ công nếu muốn dùng provider trực tiếp"
