#!/usr/bin/env bash
set -euo pipefail

TESSERACT_HOME="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$HOME/.tesseractrc"
TEMPLATES_DIR="$TESSERACT_HOME/templates"
NO_PROMPT=false

# 解析參數
DOMAIN_NAME=""
for arg in "$@"; do
    case "$arg" in
        --no-prompt) NO_PROMPT=true ;;
        *) DOMAIN_NAME="$arg" ;;
    esac
done

if [[ -z "$DOMAIN_NAME" ]]; then
    echo "用法: tesseract new-domain <domain 名稱>" >&2
    exit 1
fi

# 驗證名稱（只允許英數字和連字號）
if [[ ! "$DOMAIN_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "錯誤：Domain 名稱只能包含英文字母、數字、底線、連字號" >&2
    exit 1
fi

# 讀取設定
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    TESSERACT_DOMAINS="$TESSERACT_HOME/domains"
fi

DOMAIN_DIR="$TESSERACT_DOMAINS/$DOMAIN_NAME"

if [[ -d "$DOMAIN_DIR" ]]; then
    echo "錯誤：Domain '$DOMAIN_NAME' 已存在：$DOMAIN_DIR" >&2
    exit 1
fi

# 詢問 domain 描述
if [[ "$NO_PROMPT" == "false" ]]; then
    echo "建立新 domain：$DOMAIN_NAME"
    read -rp "簡短描述此 domain 的用途（用於 index.md Context）: " DOMAIN_DESC
else
    DOMAIN_DESC="待填寫"
fi

# 建立資料夾結構
mkdir -p "$DOMAIN_DIR/assets"

# 從模板產生 index.md
TODAY=$(date +%Y-%m-%d)
sed \
    -e "s/{{DOMAIN_NAME}}/$DOMAIN_NAME/g" \
    -e "s/{{DOMAIN_DESC}}/$DOMAIN_DESC/g" \
    -e "s/{{TODAY}}/$TODAY/g" \
    "$TEMPLATES_DIR/index.md" > "$DOMAIN_DIR/index.md"

echo "✓ 已建立 domain：$DOMAIN_DIR"
echo "  - $DOMAIN_DIR/index.md"
echo "  - $DOMAIN_DIR/assets/"
