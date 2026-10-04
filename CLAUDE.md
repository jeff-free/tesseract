# Tesseract 專案開發指引

此專案為 Tesseract 個人知識庫系統的本體工具箱，採用 **純 Ruby 3.0+ (Zero-Dependency) MCP 架構**。

## 核心元件與目錄
- `bin/tesseract`：CLI 工具引導入口（由 `mcp/cli.rb` 驅動）
- `bin/tesseract-mcp`：MCP Server 執行入口（由 `mcp/server.rb` 驅動）
- `mcp/`：核心 Ruby 模組（`store.rb`, `server.rb`, `tools.rb`, `installer.rb`, `prompts.rb`, `cli.rb`）
- `extensions/vscode/`：Tesseract Hyperfold VS Code / Antigravity 擴充套件（TypeScript）
- `test/test_mcp_server.rb`：單元與整合測試套件

## 測試指令
```bash
ruby test/test_mcp_server.rb
```

## 知識庫記錄（Dogfooding / 自我記錄）
- 本專案透過 MCP 連結至 iCloud 知識庫中的 `tesseract` domain。
- 開發本專案過程中的任何架構設計決策、重構心得與問題解法，請透過 `tesseract_save_knowledge` 即時記錄並更新知識庫。

<!-- tesseract-rule-start -->
## Tesseract 專案知識庫與即時沉澱規範
本專案與個人的 Tesseract 知識庫連動，請遵循以下規範：
1. **任務開始前**：若涉及架構決策或專案規範，先閱讀 `tesseract/rule.md` 或呼叫 `tesseract_read_knowledge(topic: "rule")`。
2. **結案前主動知識沉澱 (Proactive Knowledge Retention)**：
   每次完成實質任務或除錯後，在回覆使用者前**必須自我檢查**：
   - 是否解決了未記錄的重大 Bug、相依性衝突或踩坑解法？ ➔ 立即呼叫 `tesseract_save_knowledge(topic: "troubleshooting", ...)`
   - 是否確立了重要架構決策或技術約定？ ➔ 立即呼叫 `tesseract_save_knowledge(topic: "adr-<name>", ...)`
   - 記錄應側重於「為什麼這樣做 (Why)」，而非只是陳列程式碼。
3. **透明審查與確認提示 (Transparency in Tool Calls)**：
   呼叫 `tesseract_save_knowledge` 前，**必須先在對話中簡述欲儲存的內容與緣由**，並在參數中提供清晰具體的 `summary`，讓使用者在 IDE 授權審批視窗（Approval Dialog）中能一目了然改動內容與意圖。
<!-- tesseract-rule-end -->
