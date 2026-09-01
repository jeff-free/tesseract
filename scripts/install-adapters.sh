#!/usr/bin/env bash
set -euo pipefail

TESSERACT_HOME="$(cd "$(dirname "$0")/.." && pwd)"
ADAPTERS_DIR="$TESSERACT_HOME/adapters"
CONFIG_FILE="$HOME/.tesseractrc"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi
TESSERACT_ADAPTERS="${TESSERACT_ADAPTERS:-claude}"

echo "安裝 global skill（適用的 adapter）..."

IFS=',' read -ra ADAPTER_LIST <<< "$TESSERACT_ADAPTERS"

for adapter in "${ADAPTER_LIST[@]}"; do
    adapter="$(echo "$adapter" | tr -d ' ')"
    adapter_dir="$ADAPTERS_DIR/$adapter"
    meta_file="$adapter_dir/meta.sh"

    [[ -f "$meta_file" ]] || continue
    source "$meta_file"

    [[ -z "$ADAPTER_GLOBAL_SKILL_DEST" ]] && continue

    GLOBAL_SKILL_SRC="$adapter_dir/global-skill.md"
    [[ -f "$GLOBAL_SKILL_SRC" ]] || continue

    mkdir -p "$(dirname "$ADAPTER_GLOBAL_SKILL_DEST")"
    ln -sf "$GLOBAL_SKILL_SRC" "$ADAPTER_GLOBAL_SKILL_DEST"
    echo "  ✓ $adapter: $ADAPTER_GLOBAL_SKILL_DEST"
done

echo "完成。"
