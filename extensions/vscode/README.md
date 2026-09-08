# Tesseract Hyperfold (VS Code & Antigravity Extension)

⬡ **Tesseract 超維摺疊擴充套件** — 為 Markdown 筆記提供極低阻力的人機協作認知強化。

---

## 核心功能

1. **編輯器右上角按鈕**：
   - 當開啟任何 Markdown 筆記時，標題列工具列顯示 `[ >|< Hyperfold ]` 綠色聚斂摺疊圖示按鈕。
2. **專屬快捷鍵**：
   - **macOS**：`Cmd + Option + H`
   - **Windows / Linux**：`Ctrl + Alt + H`
3. **無縫串接 IDE Chat**：
   - 點擊按鈕或按下快捷鍵，立即自動喚醒 Antigravity IDE / VS Code Chat 視窗。
   - 自動填入 `@tesseract /hyperfold` 帶入當前筆記進行 **Plan Review 認知審查**：
     - ✦ **提煉規則**：萃取習慣寫入專案 `rule.md` 或全域 `_global/rule.md`。
     - ✦ **維度織網**：檢索知識庫並建議雙向鏈結（`[[wikilinks]]`）。
     - ✦ **索引更新**：自動更新 `index.md` Changelog。
4. **Chat Participant**：
   - 支援在對話中直接使用 `@tesseract /hyperfold` 指令。

---

## 本機開發與安裝

### 方式一：開發測試模式（Extension Development Host）
1. 在 VS Code / Antigravity IDE 中開啟 `extensions/vscode` 目錄。
2. 按下 `F5`（或至 Run & Debug 選擇「Run Extension」），會啟動一個測試用的 VS Code 視窗。
3. 在測試視窗開啟任一 Markdown 檔案，即可看見右上角按鈕或使用 `Cmd+Opt+H`。

### 方式二：本機直接安裝至 VS Code
可在 `extensions/vscode` 目錄下建立軟連結至 VS Code 外掛目錄：
```bash
ln -s "$(pwd)" ~/.vscode/extensions/tesseract-hyperfold
```
重新啟動 VS Code 即可直接全域啟用。
