#!/usr/bin/env bash
set -euo pipefail

TESSERACT_HOME="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$HOME/.tesseractrc"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    TESSERACT_DOMAINS="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Tesseract"
fi

if [[ ! -d "$TESSERACT_DOMAINS" ]]; then
    echo "錯誤：Domains 資料夾不存在：$TESSERACT_DOMAINS" >&2
    exit 1
fi

echo "=== Tesseract Reindex ==="
echo ""

rebuild_files_section() {
    local domain_dir="$1"
    local index_file="$domain_dir/index.md"

    # 收集所有知識檔（排除 index.md）
    local files_block=""
    while IFS= read -r -d '' md_file; do
        filename=$(basename "$md_file" .md)
        # 抓第一個 # 標題作為說明
        title=$(grep "^# " "$md_file" | head -1 | sed 's/^# //')
        # 抓 tags（第一個以 # 開頭的非標題行）
        tags=$(grep -m1 "^#[^#]" "$md_file" 2>/dev/null || echo "")
        if [[ -n "$title" ]]; then
            files_block="${files_block}- [[${filename}]] — ${title} ${tags}\n"
        else
            files_block="${files_block}- [[${filename}]]\n"
        fi
    done < <(find "$domain_dir" -maxdepth 1 -name "*.md" ! -name "index.md" -print0 2>/dev/null | sort -z)

    if [[ -z "$files_block" ]]; then
        files_block="（尚無知識檔案）"
    fi

    # 替換 ## Files 區塊內容
    awk -v new_content="$files_block" '
        /^## Files$/ { print; in_section=1; print ""; printf "%s", new_content; next }
        in_section && /^---$/ { in_section=0 }
        in_section && /^## / { in_section=0 }
        !in_section { print }
    ' "$index_file" > "${index_file}.tmp" && mv "${index_file}.tmp" "$index_file"
}

COUNT=0
for domain_path in "$TESSERACT_DOMAINS"/*/; do
    [[ -d "$domain_path" ]] || continue
    domain_name=$(basename "$domain_path")
    index_file="$domain_path/index.md"

    if [[ ! -f "$index_file" ]]; then
        echo "  ✗ $domain_name：缺少 index.md，跳過"
        continue
    fi

    rebuild_files_section "$domain_path"
    echo "  ✓ $domain_name：index.md Files 清單已重建"
    COUNT=$((COUNT + 1))
done

echo ""
echo "完成：已重建 $COUNT 個 domain 的索引"
