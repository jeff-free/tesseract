# Tesseract 專案開發指引

此專案為 Tesseract 個人知識庫系統的本體工具箱，採用 **純 Ruby 3.0+ (Zero-Dependency) MCP 架構**。

## 核心元件與目錄
- `bin/tesseract`：CLI 工具引導入口（由 `mcp/cli.rb` 驅動）
- `bin/tesseract-mcp`：MCP Server 執行入口（由 `mcp/server.rb` 驅動）
- `mcp/`：核心 Ruby 模組（`store.rb`, `server.rb`, `tools.rb`, `installer.rb`, `prompts.rb`, `cli.rb`）
- `test/test_mcp_server.rb`：單元與整合測試套件

## 測試指令
```bash
ruby test/test_mcp_server.rb
```

## 知識庫記錄（Dogfooding / 自我記錄）
- 本專案透過 MCP 連結至 iCloud 知識庫中的 `tesseract` domain。
- 開發本專案過程中的任何架構設計決策、重構心得與問題解法，請透過 `tesseract_save_knowledge` 即時記錄並更新知識庫。

<!-- tesseract-rule-start -->
## Tesseract 專案知識庫與自訂規範
請遵守本專案 `tesseract/rule.md` 中定義的知識庫筆記方式與開發規範。
在處理任務前，可先閱讀 `tesseract/rule.md` 或呼叫 `tesseract_read_knowledge(topic: "rule")`。
<!-- tesseract-rule-end -->
