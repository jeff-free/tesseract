#!/usr/bin/env bash
set -euo pipefail

TESSERACT_HOME="$(cd "$(dirname "$0")/.." && pwd)"
ADAPTERS_DIR="$TESSERACT_HOME/adapters"
CONFIG_FILE="$HOME/.tesseractrc"

if [[ $# -lt 2 ]]; then
    echo "用法: tesseract link <專案路徑> <domain 名稱>" >&2
    echo "範例: tesseract link . honeymoon" >&2
    exit 1
fi

PROJECT_PATH="$(cd "$1" && pwd)"
DOMAIN_NAME="$2"

# 讀取設定
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi
TESSERACT_DOMAINS="${TESSERACT_DOMAINS:-$HOME/Library/Mobile Documents/com~apple~CloudDocs/Tesseract}"
TESSERACT_ADAPTERS="${TESSERACT_ADAPTERS:-claude}"

DOMAIN_DIR="$TESSERACT_DOMAINS/$DOMAIN_NAME"
LINK_PATH="$PROJECT_PATH/tesseract"

# 確認 domain 存在
if [[ ! -d "$DOMAIN_DIR" ]]; then
    echo "錯誤：Domain '$DOMAIN_NAME' 不存在" >&2
    echo "請先執行: tesseract new-domain $DOMAIN_NAME" >&2
    exit 1
fi

# 建立 symlink
if [[ -L "$LINK_PATH" ]]; then
    EXISTING=$(readlink "$LINK_PATH")
    if [[ "$EXISTING" == "$DOMAIN_DIR" ]]; then
        echo "✓ Symlink 已存在且正確"
    else
        echo "警告：tesseract/ 已連結到 $EXISTING"
        read -rp "是否更新連結到 $DOMAIN_DIR？[y/N] " answer
        [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "取消。"; exit 0; }
        rm "$LINK_PATH"
        ln -s "$DOMAIN_DIR" "$LINK_PATH"
        echo "✓ Symlink 已更新：$LINK_PATH → $DOMAIN_DIR"
    fi
elif [[ -e "$LINK_PATH" ]]; then
    echo "錯誤：$LINK_PATH 已存在且不是 symlink" >&2
    exit 1
else
    ln -s "$DOMAIN_DIR" "$LINK_PATH"
    echo "✓ Symlink 已建立：$LINK_PATH → $DOMAIN_DIR"
fi

# 對每個 adapter 生成 project 檔案
IFS=',' read -ra ADAPTER_LIST <<< "$TESSERACT_ADAPTERS"

for adapter in "${ADAPTER_LIST[@]}"; do
    adapter="$(echo "$adapter" | tr -d ' ')"
    adapter_dir="$ADAPTERS_DIR/$adapter"

    if [[ ! -d "$adapter_dir" ]]; then
        echo "警告：找不到 adapter '$adapter'，跳過" >&2
        continue
    fi

    # 讀取 adapter 設定
    source "$adapter_dir/meta.sh"
    SNIPPET_FILE="$adapter_dir/project-snippet.md"

    if [[ ! -f "$SNIPPET_FILE" ]]; then
        echo "警告：$adapter 缺少 project-snippet.md，跳過" >&2
        continue
    fi

    TARGET_FILE="$PROJECT_PATH/$ADAPTER_FILENAME"
    MARKER_START="<!-- ${ADAPTER_MARKER}-start -->"
    MARKER_END="<!-- ${ADAPTER_MARKER}-end -->"

    # 填入變數
    SNIPPET=$(sed \
        -e "s|{{DOMAIN_NAME}}|$DOMAIN_NAME|g" \
        -e "s|{{DOMAIN_DIR}}|$DOMAIN_DIR|g" \
        "$SNIPPET_FILE")

    if [[ -f "$TARGET_FILE" ]] && grep -q "$MARKER_START" "$TARGET_FILE"; then
        echo "✓ $ADAPTER_FILENAME 已有 Tesseract 設定，跳過"
    else
        if [[ -f "$TARGET_FILE" ]]; then
            echo "" >> "$TARGET_FILE"
            echo "$SNIPPET" >> "$TARGET_FILE"
            echo "✓ Tesseract 設定已附加到 $ADAPTER_FILENAME"
        else
            echo "$SNIPPET" > "$TARGET_FILE"
            echo "✓ 已建立 $ADAPTER_FILENAME（$adapter adapter）"
        fi
    fi
done

echo ""
echo "連結完成！"
echo "  專案：$PROJECT_PATH"
echo "  Domain：$DOMAIN_NAME"
echo "  Adapters：$TESSERACT_ADAPTERS"
