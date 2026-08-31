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

if [[ ! -d "$TESSERACT_DOMAINS" ]]; then
    echo "錯誤：Domains 資料夾不存在：$TESSERACT_DOMAINS" >&2
    exit 1
fi

echo "=== Tesseract Reindex ==="
echo ""

# 從 index.md 提取結構化摘要（不需 AI）
extract_summary() {
    local input_file="$1"
    local output_file="$2"

    awk '
        BEGIN { header = ""; content = ""; count = 0 }
        /^# / {
            # 頂層標題：直接輸出
            if (header != "") { print header; if (content != "") print content; print "" }
            header = $0; content = ""; count = 0
            next
        }
        /^## / {
            if (header != "") { print header; if (content != "") print content; print "" }
            header = $0; content = ""; count = 0
            next
        }
        /^### / {
            if (header != "") { print header; if (content != "") print content; print "" }
            header = $0; content = ""; count = 0
            next
        }
        header != "" && /[^ \t]/ && count < 2 {
            if (content == "") content = $0
            else content = content " | " $0
            count++
            next
        }
        /^- / && header != "" && count < 5 {
            if (content == "") content = $0
            else content = content "\n" $0
            count++
        }
        END { if (header != "") { print header; if (content != "") print content } }
    ' "$input_file" > "$output_file"
}

# 更新 manifest（JSON 格式）
update_manifest() {
    local domain_dir="$1"
    local domain_name="$2"
    local index_file="$domain_dir/index.md"
    local manifest_file="$domain_dir/manifest.json"

    local file_count
    file_count=$(find "$domain_dir/assets" -type f 2>/dev/null | wc -l | tr -d ' ')

    local last_updated
    last_updated=$(stat -f "%Sm" -t "%Y-%m-%dT%H:%M:%S" "$index_file" 2>/dev/null \
        || date -r "$index_file" "+%Y-%m-%dT%H:%M:%S" 2>/dev/null \
        || echo "unknown")

    # 取得 Changelog 最後一筆
    local last_change
    last_change=$(grep "^- " "$index_file" | tail -1 | sed 's/^- //')

    cat > "$manifest_file" <<JSON
{
  "domain": "$domain_name",
  "last_updated": "$last_updated",
  "asset_count": $file_count,
  "last_change": "$last_change",
  "reindexed_at": "$(date +%Y-%m-%dT%H:%M:%S)"
}
JSON
}

COUNT=0
for domain_path in "$TESSERACT_DOMAINS"/*/; do
    [[ -d "$domain_path" ]] || continue
    domain_name=$(basename "$domain_path")
    index_file="$domain_path/index.md"
    summary_file="$domain_path/summary.md"

    if [[ ! -f "$index_file" ]]; then
        echo "  ✗ $domain_name：缺少 index.md，跳過"
        continue
    fi

    # 產生結構摘要
    extract_summary "$index_file" "$summary_file"
    echo "  ✓ $domain_name：summary.md 已更新"

    # 更新 manifest
    update_manifest "$domain_path" "$domain_name"
    echo "    manifest.json 已更新"

    COUNT=$((COUNT + 1))
done

echo ""
echo "完成：已處理 $COUNT 個 domain"
echo ""
echo "提示：summary.md 是從 index.md 結構自動提取的簡化版本。"
echo "若需要 AI 語意摘要，在 Claude Code 中執行：「更新 Tesseract 所有 domain 的 summary」"
