#!/usr/bin/env bash
set -euo pipefail

TESSERACT_HOME="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$HOME/.tesseractrc"

# 讀取設定
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    TESSERACT_DOMAINS="$TESSERACT_HOME/domains"
fi

echo "=== Tesseract 狀態 ==="
echo ""
echo "設定檔：${CONFIG_FILE:-（未找到）}"
echo "Domains 路徑：$TESSERACT_DOMAINS"
echo ""

# 列出所有 domains
if [[ ! -d "$TESSERACT_DOMAINS" ]]; then
    echo "（Domains 資料夾不存在）"
    exit 0
fi

DOMAINS=("$TESSERACT_DOMAINS"/*)
if [[ ${#DOMAINS[@]} -eq 0 ]] || [[ ! -d "${DOMAINS[0]}" ]]; then
    echo "（目前沒有任何 domain）"
    echo ""
    echo "建立第一個 domain：tesseract new-domain <名稱>"
    exit 0
fi

echo "── Domains ──────────────────────────────"
for domain_path in "$TESSERACT_DOMAINS"/*/; do
    [[ -d "$domain_path" ]] || continue
    domain_name=$(basename "$domain_path")
    index_file="$domain_path/index.md"

    if [[ -f "$index_file" ]]; then
        last_modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$index_file" 2>/dev/null || date -r "$index_file" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "未知")
        summary_exists=""
        [[ -f "$domain_path/summary.md" ]] && summary_exists=" [有 summary]"
        echo "  ✓ $domain_name（最後更新：$last_modified）$summary_exists"
    else
        echo "  ✗ $domain_name（缺少 index.md）"
    fi
done

echo ""
echo "── 已連結的專案 ──────────────────────────"

# 在常見的專案目錄中搜尋 .tesseract symlink
SEARCH_PATHS=(
    "$HOME/code"
    "$HOME/Documents"
    "$HOME/projects"
    "$HOME/workspace"
    "$HOME/dev"
)

FOUND_COUNT=0
for search_path in "${SEARCH_PATHS[@]}"; do
    [[ -d "$search_path" ]] || continue

    while IFS= read -r -d '' link; do
        project_dir=$(dirname "$link")
        target=$(readlink "$link" 2>/dev/null || echo "（無法讀取）")
        domain_name=$(basename "$target")

        if [[ -d "$target" ]]; then
            echo "  ✓ $project_dir"
            echo "    → $domain_name"
        else
            echo "  ✗ $project_dir"
            echo "    → $target（目標不存在）"
        fi
        FOUND_COUNT=$((FOUND_COUNT + 1))
    done < <(find "$search_path" -maxdepth 3 -name ".tesseract" -type l -print0 2>/dev/null)
done

if [[ $FOUND_COUNT -eq 0 ]]; then
    echo "  （未找到任何已連結的專案）"
    echo ""
    echo "連結專案：cd <專案路徑> && tesseract link . <domain>"
fi

echo ""
