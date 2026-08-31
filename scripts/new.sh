#!/usr/bin/env bash
set -euo pipefail

TESSERACT_HOME="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$HOME/.tesseractrc"

if [[ $# -lt 1 ]]; then
    echo "用法: tesseract new <專案名稱> [專案路徑]" >&2
    echo "範例: tesseract new honeymoon" >&2
    echo "範例: tesseract new honeymoon ~/code/honeymoon" >&2
    exit 1
fi

# 讀取設定
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi
TESSERACT_DOMAINS="${TESSERACT_DOMAINS:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/Tesseract}"

PROJECT_NAME="$1"
PROJECT_PATH="${2:-$(pwd)/$PROJECT_NAME}"
PROJECT_PATH="${PROJECT_PATH/#\~/$HOME}"

echo "=== 建立新專案：$PROJECT_NAME ==="
echo ""

# 步驟 1：建立專案資料夾
if [[ -d "$PROJECT_PATH" ]]; then
    echo "✓ 專案資料夾已存在：$PROJECT_PATH"
else
    mkdir -p "$PROJECT_PATH"
    echo "✓ 專案資料夾已建立：$PROJECT_PATH"
fi

# 步驟 2：建立 iCloud domain（如果不存在）
DOMAIN_DIR="$TESSERACT_DOMAINS/$PROJECT_NAME"
if [[ -d "$DOMAIN_DIR" ]]; then
    echo "✓ 知識 domain 已存在：$DOMAIN_DIR"
else
    bash "$(dirname "$0")/new-domain.sh" "$PROJECT_NAME"
fi

# 步驟 3：連結
bash "$(dirname "$0")/link.sh" "$PROJECT_PATH" "$PROJECT_NAME"

echo ""
echo "=== 完成 ==="
echo ""
echo "  專案資料夾：$PROJECT_PATH"
echo "  知識庫（iCloud）：$DOMAIN_DIR"
echo "  Symlink：$PROJECT_PATH/tesseract/"
echo ""
echo "使用 Claude Code 開啟 $PROJECT_PATH 即可開始。"
