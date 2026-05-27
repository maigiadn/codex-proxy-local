#!/bin/bash
# ============================================================
# Codex Model Alias Proxy - Installer
# Tự động cài đặt proxy local để remap model names cho Codex CLI
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Codex Model Alias Proxy - Installer         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# ---- Configuration ----
PROXY_PORT="${PROXY_PORT:-18080}"
PROXY_TARGET="${PROXY_TARGET:-https://apikey.maivangia.com}"
INSTALL_DIR="$HOME/.codex"
PROXY_FILE="$INSTALL_DIR/model-proxy.js"
SERVICE_NAME="codex-proxy"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---- Check prerequisites ----
echo -e "${YELLOW}[1/6] Kiểm tra prerequisites...${NC}"

if ! command -v node &>/dev/null; then
    echo -e "${RED}❌ Node.js chưa được cài đặt. Vui lòng cài đặt Node.js trước.${NC}"
    echo "   sudo apt install -y nodejs"
    exit 1
fi
echo -e "${GREEN}  ✓ Node.js $(node --version)${NC}"

if ! command -v codex &>/dev/null; then
    echo -e "${YELLOW}  ⚠ Codex CLI chưa được cài. Proxy vẫn sẽ được cài đặt.${NC}"
else
    echo -e "${GREEN}  ✓ Codex CLI $(codex --version 2>/dev/null | head -1)${NC}"
fi

# ---- Prompt for configuration ----
echo ""
echo -e "${YELLOW}[2/6] Cấu hình...${NC}"

read -rp "  Provider URL [$PROXY_TARGET]: " input_target
PROXY_TARGET="${input_target:-$PROXY_TARGET}"

read -rp "  Proxy port [$PROXY_PORT]: " input_port
PROXY_PORT="${input_port:-$PROXY_PORT}"

read -rp "  API Key (OPENAI_API_KEY): " input_key
if [ -z "$input_key" ]; then
    echo -e "${RED}❌ API Key là bắt buộc.${NC}"
    exit 1
fi
API_KEY="$input_key"

read -rp "  Model name [cx/gpt-5.5]: " input_model
MODEL="${input_model:-cx/gpt-5.5}"

echo ""
echo -e "${GREEN}  Provider: $PROXY_TARGET${NC}"
echo -e "${GREEN}  Port:     $PROXY_PORT${NC}"
echo -e "${GREEN}  Model:    $MODEL${NC}"

# ---- Install proxy script ----
echo ""
echo -e "${YELLOW}[3/6] Cài đặt proxy script...${NC}"

mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/model-proxy.js" "$PROXY_FILE"

# Update PROXY_TARGET and PROXY_PORT in the proxy script defaults
sed -i "s|https://apikey.maivangia.com|$PROXY_TARGET|g" "$PROXY_FILE"
sed -i "s|18080|$PROXY_PORT|g" "$PROXY_FILE"

echo -e "${GREEN}  ✓ Proxy script: $PROXY_FILE${NC}"

# ---- Configure systemd service ----
echo ""
echo -e "${YELLOW}[4/6] Cài đặt systemd service...${NC}"

SERVICE_FILE="/tmp/${SERVICE_NAME}.service"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Codex Model Alias Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/node $PROXY_FILE
Restart=always
RestartSec=5
User=$USER
Environment=NODE_ENV=production
Environment=PROXY_TARGET=$PROXY_TARGET
Environment=PROXY_PORT=$PROXY_PORT

[Install]
WantedBy=multi-user.target
EOF

echo -e "${BLUE}  Cần quyền sudo để cài systemd service...${NC}"
sudo cp "$SERVICE_FILE" /etc/systemd/system/${SERVICE_NAME}.service
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"
rm -f "$SERVICE_FILE"

# Check if service is running
sleep 1
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo -e "${GREEN}  ✓ Service đang chạy${NC}"
else
    echo -e "${RED}  ❌ Service không khởi động được. Kiểm tra: sudo journalctl -u $SERVICE_NAME${NC}"
    exit 1
fi

# ---- Configure Codex CLI ----
echo ""
echo -e "${YELLOW}[5/6] Cấu hình Codex CLI...${NC}"

CONFIG_FILE="$HOME/.codex/config.toml"

# Backup existing config
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    echo -e "${GREEN}  ✓ Backup config cũ${NC}"
fi

# Check if model_providers.maivangia section already exists
if grep -q "\[model_providers\.maivangia\]" "$CONFIG_FILE" 2>/dev/null; then
    echo -e "${YELLOW}  ⚠ Config đã có section [model_providers.maivangia], cập nhật...${NC}"
    # Use sed to update existing values
    sed -i "s|^model_provider = .*|model_provider = \"maivangia\"|" "$CONFIG_FILE"
    sed -i "s|^model = .*|model = \"$MODEL\"|" "$CONFIG_FILE"
    sed -i "/\[model_providers\.maivangia\]/,/^\[/{s|base_url = .*|base_url = \"http://127.0.0.1:$PROXY_PORT/v1\"|}" "$CONFIG_FILE"
else
    # Create or update top-level config
    if grep -q "^model_provider" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s|^model_provider = .*|model_provider = \"maivangia\"|" "$CONFIG_FILE"
        sed -i "s|^model = .*|model = \"$MODEL\"|" "$CONFIG_FILE"
    else
        # Prepend to config file
        {
            echo "model_provider = \"maivangia\""
            echo "model = \"$MODEL\""
            echo "model_reasoning_effort = \"medium\""
            echo ""
            cat "$CONFIG_FILE" 2>/dev/null || true
        } > "${CONFIG_FILE}.tmp"
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi

    # Append provider section
    cat >> "$CONFIG_FILE" <<EOF

[model_providers.maivangia]
name = "Mai Van Gia Provider"
base_url = "http://127.0.0.1:$PROXY_PORT/v1"
env_key = "OPENAI_API_KEY"
wire_api = "responses"
EOF
fi

echo -e "${GREEN}  ✓ Codex config đã cập nhật${NC}"

# ---- Set environment variables ----
echo ""
echo -e "${YELLOW}[6/6] Cấu hình biến môi trường...${NC}"

# Update .profile
PROFILE_FILE="$HOME/.profile"
BASHRC_FILE="$HOME/.bashrc"

# Function to update env var in a file
update_env() {
    local file="$1"
    local var_name="$2"
    local var_value="$3"

    if grep -q "^export ${var_name}=" "$file" 2>/dev/null; then
        sed -i "s|^export ${var_name}=.*|export ${var_name}='${var_value}'|" "$file"
    else
        echo "" >> "$file"
        echo "# Codex Proxy" >> "$file"
        echo "export ${var_name}='${var_value}'" >> "$file"
    fi
}

update_env "$PROFILE_FILE" "OPENAI_BASE_URL" "http://127.0.0.1:$PROXY_PORT/v1"
update_env "$PROFILE_FILE" "OPENAI_API_KEY" "$API_KEY"
update_env "$BASHRC_FILE" "OPENAI_BASE_URL" "http://127.0.0.1:$PROXY_PORT/v1"
update_env "$BASHRC_FILE" "OPENAI_API_KEY" "$API_KEY"

# Export for current session
export OPENAI_BASE_URL="http://127.0.0.1:$PROXY_PORT/v1"
export OPENAI_API_KEY="$API_KEY"

echo -e "${GREEN}  ✓ Biến môi trường đã cập nhật${NC}"

# ---- Login Codex CLI ----
if command -v codex &>/dev/null; then
    echo ""
    echo -e "${YELLOW}Đăng nhập Codex CLI...${NC}"
    echo "$API_KEY" | codex login --with-api-key 2>/dev/null && \
        echo -e "${GREEN}  ✓ Codex CLI đã đăng nhập${NC}" || \
        echo -e "${YELLOW}  ⚠ Không thể đăng nhập Codex CLI tự động${NC}"
fi

# ---- Test connection ----
echo ""
echo -e "${YELLOW}Test kết nối...${NC}"
sleep 1

RESULT=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    "http://127.0.0.1:$PROXY_PORT/v1/responses" \
    -d "{\"model\":\"gpt-5.5\",\"input\":\"Say hello\"}" 2>&1)

HTTP_CODE=$(echo "$RESULT" | tail -1)
BODY=$(echo "$RESULT" | head -1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}  ✓ Kết nối thành công! (HTTP $HTTP_CODE)${NC}"
else
    echo -e "${RED}  ❌ Kết nối thất bại (HTTP $HTTP_CODE)${NC}"
    echo -e "${RED}  Response: $BODY${NC}"
fi

# ---- Done ----
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  ✅ Cài đặt hoàn tất!                        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Proxy:    http://127.0.0.1:$PROXY_PORT"
echo -e "  Provider: $PROXY_TARGET"
echo -e "  Model:    $MODEL"
echo -e "  Service:  sudo systemctl status $SERVICE_NAME"
echo ""
echo -e "${YELLOW}Lưu ý:${NC}"
echo -e "  - Reload VS Code (Ctrl+Shift+P → Reload Window) để Codex nhận config"
echo -e "  - Hoặc logout/login lại Ubuntu để .profile có hiệu lực"
echo -e "  - Kiểm tra log proxy: sudo journalctl -u $SERVICE_NAME -f"
echo ""
