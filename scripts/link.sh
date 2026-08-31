#!/usr/bin/env bash
set -euo pipefail

TESSERACT_HOME="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$HOME/.tesseractrc"
TEMPLATES_DIR="$TESSERACT_HOME/templates"

if [[ $# -lt 2 ]]; then
    echo "用法: tesseract link <專案路徑> <domain 名稱>" >&2
    echo "範例: tesseract link . product" >&2
    exit 1
fi

PROJECT_PATH="$(cd "$1" && pwd)"
DOMAIN_NAME="$2"

# 讀取設定
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    TESSERACT_DOMAINS="$TESSERACT_HOME/domains"
fi

DOMAIN_DIR="$TESSERACT_DOMAINS/$DOMAIN_NAME"
LINK_PATH="$PROJECT_PATH/tesseract"

# 確認 domain 存在
if [[ ! -d "$DOMAIN_DIR" ]]; then
    echo "錯誤：Domain '$DOMAIN_NAME' 不存在" >&2
    echo "請先執行: tesseract new-domain $DOMAIN_NAME" >&2
    exit 1
fi

# 處理現有 symlink
if [[ -L "$LINK_PATH" ]]; then
    EXISTING=$(readlink "$LINK_PATH")
    if [[ "$EXISTING" == "$DOMAIN_DIR" ]]; then
        echo "✓ Symlink 已存在且指向正確的 domain"
        exit 0
    else
        echo "警告：tesseract 已連結到 $EXISTING"
        read -rp "是否更新連結到 $DOMAIN_DIR？[y/N] " answer
        if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
            echo "取消，保留現有連結。"
            exit 0
        fi
        rm "$LINK_PATH"
    fi
elif [[ -e "$LINK_PATH" ]]; then
    echo "錯誤：$LINK_PATH 已存在且不是 symlink" >&2
    exit 1
fi

# 建立 symlink
ln -s "$DOMAIN_DIR" "$LINK_PATH"
echo "✓ Symlink 已建立：$LINK_PATH → $DOMAIN_DIR"

# 更新專案的 CLAUDE.md
CLAUDE_MD="$PROJECT_PATH/CLAUDE.md"
SNIPPET_FILE="$TEMPLATES_DIR/CLAUDE.md.snippet"
MARKER="<!-- tesseract-start -->"

if [[ -f "$CLAUDE_MD" ]] && grep -q "$MARKER" "$CLAUDE_MD"; then
    echo "✓ CLAUDE.md 中已有 Tesseract 設定，跳過更新"
else
    SNIPPET=$(sed \
        -e "s|{{DOMAIN_NAME}}|$DOMAIN_NAME|g" \
        -e "s|{{DOMAIN_DIR}}|$DOMAIN_DIR|g" \
        "$SNIPPET_FILE")

    if [[ -f "$CLAUDE_MD" ]]; then
        echo "" >> "$CLAUDE_MD"
        echo "$SNIPPET" >> "$CLAUDE_MD"
        echo "✓ Tesseract 設定已附加到現有 CLAUDE.md"
    else
        echo "$SNIPPET" > "$CLAUDE_MD"
        echo "✓ 已建立 CLAUDE.md 並加入 Tesseract 設定"
    fi
fi

echo ""
echo "連結完成！"
echo "  專案：$PROJECT_PATH"
echo "  Domain：$DOMAIN_NAME（$DOMAIN_DIR）"
echo ""
echo "在此專案中使用 Claude Code 時，AI 會自動讀取並強化知識庫。"
