# Codex Model Alias Proxy

Proxy local nhẹ giúp **remap tên model** trước khi forward request đến provider OpenAI-compatible. Giải quyết vấn đề Codex CLI/Extension gửi model slug (ví dụ `gpt-5.5`) nhưng provider yêu cầu tên có prefix (ví dụ `cx/gpt-5.5`).

## Vấn đề

Codex CLI v0.130.0+ sử dụng **Responses API** (WebSocket) và gửi model slug từ catalog nội bộ (ví dụ `gpt-5.5`). Tuy nhiên, một số provider OpenAI-compatible yêu cầu tên model có prefix (ví dụ `cx/gpt-5.5`), dẫn đến lỗi:

```
unexpected status 403 Forbidden: Model not allowed for this API key: gpt-5.5
```

## Giải pháp

Proxy chạy local tại `http://127.0.0.1:18080`, nhận request từ Codex, **tự động đổi tên model**, rồi forward đến provider thực.

```
Codex → http://127.0.0.1:18080 (proxy) → https://provider.com (API)
         model: gpt-5.5 → cx/gpt-5.5
```

## Cài đặt nhanh

```bash
git clone https://github.com/maigiadn/codex-proxy-local.git
cd codex-proxy-local
chmod +x install.sh
./install.sh
```

Script sẽ hỏi bạn:
- **Provider URL** - URL của provider API (mặc định: `https://apikey.maivangia.com`)
- **Proxy port** - Port cho proxy local (mặc định: `18080`)
- **API Key** - API key để xác thực với provider
- **Model name** - Tên model để dùng (mặc định: `cx/gpt-5.5`)

## Cài đặt thủ công

### 1. Copy proxy script

```bash
mkdir -p ~/.codex
cp model-proxy.js ~/.codex/model-proxy.js
```

### 2. Chạy thử

```bash
node ~/.codex/model-proxy.js
```

### 3. Tạo systemd service

```bash
sudo cp codex-proxy.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable codex-proxy
sudo systemctl start codex-proxy
```

### 4. Cấu hình Codex CLI

Thêm vào `~/.codex/config.toml`:

```toml
model_provider = "maivangia"
model = "cx/gpt-5.5"
model_reasoning_effort = "medium"

[model_providers.maivangia]
name = "Mai Van Gia Provider"
base_url = "http://127.0.0.1:18080/v1"
env_key = "OPENAI_API_KEY"
wire_api = "responses"
```

### 5. Cấu hình API Key

```bash
# Thêm vào ~/.profile và ~/.bashrc
export OPENAI_BASE_URL='http://127.0.0.1:18080/v1'
export OPENAI_API_KEY='your-api-key-here'
```

### 6. Đăng nhập Codex CLI

```bash
echo "your-api-key-here" | codex login --with-api-key
```

### 7. Reload VS Code

`Ctrl+Shift+P` → `Reload Window`

## Tùy chỉnh Model Aliases

Sửa file `model-proxy.js`, phần `MODEL_ALIASES`:

```javascript
const MODEL_ALIASES = {
  "gpt-5.5": "cx/gpt-5.5",
  "gpt-5.4": "cx/gpt-5.4",
  "gpt-5.3-codex": "cx/gpt-5.3-codex",
  // Thêm alias mới ở đây
};
```

Sau khi sửa, restart service:

```bash
sudo systemctl restart codex-proxy
```

## Hướng dẫn sử dụng & Thay đổi Model

Người dùng có thể lựa chọn linh hoạt giữa các model có sẵn (ví dụ: `cx/gpt-5.5`, `cx/gpt-5.4`, `cx/gpt-5.3-codex`) thông qua 3 cách sau:

### Cách 1: Chọn trực tiếp trên giao diện VS Code

VS Code Extension của Codex hiển thị các model rút gọn theo catalog của nó:
* Chọn **`GPT-5.5`** (gửi đi dưới dạng `gpt-5.5`)
* Chọn **`GPT-5.4`** (gửi đi dưới dạng `gpt-5.4`)
* Chọn **`GPT-5.3 (Codex)`** (gửi đi dưới dạng `gpt-5.3-codex`)

Khi click chọn trên thanh trạng thái (status bar) hoặc cài đặt Extension, proxy local sẽ tự động remap tên model tương ứng sang tên đầy đủ của provider (ví dụ: `cx/gpt-5.4`).

### Cách 2: Thiết lập model mặc định trong `config.toml`

Thay đổi giá trị tại trường `model` ở đầu file cấu hình `~/.codex/config.toml`:

```toml
# Chọn cx/gpt-5.4 làm mặc định
model_provider = "maivangia"
model = "cx/gpt-5.4"
model_reasoning_effort = "medium"
```

```toml
# Chọn cx/gpt-5.3-codex làm mặc định
model_provider = "maivangia"
model = "cx/gpt-5.3-codex"
model_reasoning_effort = "medium"
```

*Lưu ý: Sau khi lưu file cấu hình, hãy **Reload VS Code** (`Ctrl+Shift+P` -> `Reload Window`) để extension áp dụng cài đặt.*

### Cách 3: Thay đổi linh hoạt bằng CLI parameter

Khi chạy trực tiếp qua Codex CLI, bạn có thể truyền cờ `-m` hoặc `--model` để chỉ định model chạy riêng cho phiên làm việc đó:

```bash
# Sử dụng gpt-5.4
codex exec -m cx/gpt-5.4 "Viết một hàm Python"

# Sử dụng gpt-5.3
codex exec -m cx/gpt-5.3-codex "Review file này giúp tôi"
```

## Biến môi trường

| Biến | Mô tả | Mặc định |
|------|--------|----------|
| `PROXY_TARGET` | URL của provider API | `https://apikey.maivangia.com` |
| `PROXY_PORT` | Port cho proxy local | `18080` |

## Quản lý service

```bash
# Xem trạng thái
sudo systemctl status codex-proxy

# Xem log
sudo journalctl -u codex-proxy -f

# Restart
sudo systemctl restart codex-proxy

# Dừng
sudo systemctl stop codex-proxy
```

## Gỡ cài đặt

```bash
chmod +x uninstall.sh
./uninstall.sh
```

## Yêu cầu hệ thống

- **OS**: Ubuntu/Debian (Linux với systemd)
- **Node.js**: >= 14
- **Codex CLI**: >= 0.130.0 (khuyến nghị)

## Cấu trúc project

```
codex-proxy-local/
├── model-proxy.js       # Proxy script chính
├── install.sh           # Script cài đặt tự động
├── uninstall.sh         # Script gỡ cài đặt
├── codex-proxy.service  # Systemd service template
├── config.toml.example  # Ví dụ config Codex
└── README.md            # Tài liệu này
```

## License

MIT
