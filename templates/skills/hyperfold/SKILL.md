---
name: tesseract-hyperfold
description: 執行 Tesseract 4D 知識庫超維摺疊 (Hyperfold)。當使用者手動修改筆記或請求摺疊時，自動進行差分分析、提煉可泛化工程習慣至 rule.md、檢索知識庫並建立雙向鏈結 ([[wikilinks]])，以 Plan Review 形式呈現審查卡片並原子化寫入。
---

# Tesseract Hyperfold (超維摺疊) 標準作業協議

本 Skill 為 Tesseract 人機協同知識庫的認知強化協議，適用於各主流 AI Agent（Claude Code, Google Antigravity / Gemini, Cursor 等）。

---

## 觸發時機 (When to Activate)
1. 使用者在編輯器按下 **`[ ⬡ Hyperfold ]`** 按鈕或快捷鍵（`Cmd + Opt + H`）。
2. 使用者在對話中呼叫 `/hyperfold`、`@tesseract /hyperfold` 或指示：「*幫我摺疊 / 強化這篇筆記*」。
3. 使用者手動大幅修改了 `tesseract/*.md` 筆記，需要反向吸收時。

---

## 核心執行流程 (SOP)

### Step 1: 筆記讀取與差分分析
- 讀取目標筆記（透過 `tesseract_read_knowledge` 或直接讀取檔案路徑）。
- 檢視人類手動新增、修正或標記的重點（例如：架構選型、Bug 解決方案、特殊約束或 TODO）。

### Step 2: 規範提煉 (Rule Extraction)
- 判斷該修改是否蘊含可泛化的工程習慣、偏好或技術準則。
- 若有，草擬一條精準簡練的規範：
  - 目標位置：優先寫入當前專案 `tesseract/rule.md`；若具備跨專案普適性，建議寫入全域 `_global/rule.md`。
  - 格式範例：`「在 <情境> 下，優先採用 <方案>，避免 <負面後果>」`。

### Step 3: 維度織網 (Dimensional Weaving)
- 調用 `tesseract_search_knowledge` 搜尋整個知識庫（Vault）中與該筆記核心概念相關的主題。
- 挑選 1 ~ 3 個最具關聯性的筆記節點，產出建議的 Obsidian 雙向鏈結（`[[topic-name]]`）。

### Step 4: Plan Review 審查卡片呈現
**嚴禁未經確認直接覆寫人類文字**。請務必以清晰的 Markdown 結構呈現審查清單：

```markdown
### ⬡ Tesseract Hyperfold Review: `[topic]`

#### 1. ✦ 提煉規範建議 (rule.md)
- [ ] **<提煉出的工程規範>** (目標: `專案 rule.md` 或 `全域 rule.md`)

#### 2. ✦ 維度織網建議 (雙向鏈結)
- [ ] 關聯至 `[[相關主題A]]`：<關聯原因簡述>
- [ ] 關聯至 `[[相關主題B]]`：<關聯原因簡述>

#### 3. ✦ 索引拓撲更新 (index.md)
- 更新 Changelog 摘要：`<一句話總結本次決策>`

---
> 💡 請審閱以上摺疊建議。若同意套用，請點擊下方的 **`[ Proceed ]`** 按鈕或回覆「**確認套用**」；亦可直接在對話中提出微調要求。
```

### Step 5: 原子化套用 (Commit)
當使用者確認套用後，調用 `tesseract_hyperfold` MCP 工具將結果寫入 iCloud 雲端知識庫：
- `topic`: 目標主題名稱
- `rule`: 提煉出的規則文字（若使用者同意）
- `rule_domain`: `auto` 或 `global`
- `backlinks`: 欲追加的 `[[wikilinks]]`
- `summary`: Changelog 摘要
