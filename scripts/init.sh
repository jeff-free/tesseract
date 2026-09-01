#!/usr/bin/env bash
set -euo pipefail

TESSERACT_HOME="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$HOME/.tesseractrc"

echo "=== Tesseract 初始化 ==="
echo ""

# 讀取現有設定（如果存在）
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    echo "發現現有設定：$CONFIG_FILE"
    echo "TESSERACT_DOMAINS=$TESSERACT_DOMAINS"
    echo ""
    read -rp "是否重新設定？[y/N] " answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
        echo "保留現有設定，結束。"
        exit 0
    fi
fi

# 設定 domains 路徑（知識庫，預設放在 iCloud Drive）
DEFAULT_DOMAINS="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Tesseract"
echo "知識庫路徑（iCloud，預設：$DEFAULT_DOMAINS）"
read -rp "請輸入路徑，或直接按 Enter 使用預設值: " input_domains
DOMAINS_PATH="${input_domains:-$DEFAULT_DOMAINS}"
DOMAINS_PATH="${DOMAINS_PATH/#\~/$HOME}"
mkdir -p "$DOMAINS_PATH"

# 選擇 AI adapters
echo ""
echo "要使用哪些 AI adapter？（逗號分隔，預設：claude）"
echo "可用：claude, gemini"
read -rp "Adapters: " input_adapters
ADAPTERS="${input_adapters:-claude}"

# 寫入設定檔
cat > "$CONFIG_FILE" <<EOF
# Tesseract 設定檔
# 由 tesseract init 自動產生
TESSERACT_HOME="$TESSERACT_HOME"
TESSERACT_DOMAINS="$DOMAINS_PATH"
TESSERACT_ADAPTERS="$ADAPTERS"
EOF

echo ""
echo "✓ 設定檔已建立：$CONFIG_FILE"
echo "✓ Domains 資料夾：$DOMAINS_PATH"
echo "✓ Adapters：$ADAPTERS"

# 安裝 global skill（各 adapter 自行決定是否需要）
bash "$(dirname "$0")/install-adapters.sh"

# 建立預設 tesseract domain（個人通用知識庫）
TESSERACT_DOMAIN_DIR="$DOMAINS_PATH/tesseract"
if [[ ! -d "$TESSERACT_DOMAIN_DIR" ]]; then
    bash "$(dirname "$0")/new-domain.sh" "tesseract" --no-prompt
    echo "✓ 已建立預設 domain：tesseract（個人通用知識庫）"
fi

echo ""
echo "=== 初始化完成 ==="
echo ""
echo "下一步："
echo "  1. 確認 PATH 設定：export PATH=\"\$PATH:$TESSERACT_HOME/bin\""
echo "     （將此行加入 ~/.zshrc 讓設定永久生效）"
echo "  2. 建立或進入專案：tesseract new <名稱>"
echo "  3. 使用 AI 開始工作，知識庫會自動讀寫"
