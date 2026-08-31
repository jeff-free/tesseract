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

# 設定 domains 路徑（預設放在 iCloud Drive）
DEFAULT_DOMAINS="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Tesseract"
echo "Domains 資料夾路徑（預設：$DEFAULT_DOMAINS）"
read -rp "請輸入路徑，或直接按 Enter 使用預設值: " input_domains
DOMAINS_PATH="${input_domains:-$DEFAULT_DOMAINS}"

# 展開 ~
DOMAINS_PATH="${DOMAINS_PATH/#\~/$HOME}"

# 建立 domains 資料夾
mkdir -p "$DOMAINS_PATH"

# 寫入設定檔
cat > "$CONFIG_FILE" <<EOF
# Tesseract 設定檔
# 由 tesseract init 自動產生
TESSERACT_HOME="$TESSERACT_HOME"
TESSERACT_DOMAINS="$DOMAINS_PATH"
EOF

echo ""
echo "✓ 設定檔已建立：$CONFIG_FILE"
echo "✓ Domains 資料夾：$DOMAINS_PATH"

# 安裝 Claude Code Skill
SKILL_DIR="$HOME/.claude/skills"
SKILL_SRC="$TESSERACT_HOME/skills/tesseract.md"
SKILL_DEST="$SKILL_DIR/tesseract.md"

if [[ -f "$SKILL_SRC" ]]; then
    mkdir -p "$SKILL_DIR"
    if [[ -L "$SKILL_DEST" ]]; then
        echo "✓ Claude Code Skill 已安裝（symlink）"
    else
        ln -sf "$SKILL_SRC" "$SKILL_DEST"
        echo "✓ Claude Code Skill 已安裝：$SKILL_DEST"
    fi
fi

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
echo "  2. 建立專案連結：cd <專案路徑> && tesseract link . <domain>"
echo "  3. 使用 Claude Code，AI 會自動讀取並強化知識庫"
