<!-- tesseract-rule-start -->
## Tesseract 專案知識庫與即時沉澱規範
本專案與個人的 Tesseract 知識庫連動，請遵循以下規範：
1. **任務開始前**：若涉及架構決策或專案規範，先閱讀 `tesseract/rule.md` 或呼叫 `tesseract_read_knowledge(topic: "rule")`（或終端執行 `tesseract read rule`）。
2. **結案前主動知識沉澱 (Proactive Knowledge Retention)**：
   每次完成實質任務或除錯後，在回覆使用者前**必須自我檢查**：
   - 是否解決了未記錄的重大 Bug、相依性衝突或踩坑解法？ ➔ 立即記錄至 `troubleshooting` 主題
   - 是否確立了重要架構決策或技術約定？ ➔ 立即記錄至 `adr-<name>` 主題
   - 記錄應側重於「為什麼這樣做 (Why)」，而非只是陳列程式碼。
3. **雙軌通道與透明審查原則 (Dual-Channel & Transparency)**：
   - **本地優先 (MCP)**：呼叫 `tesseract_save_knowledge`。呼叫前先在對話中簡述內容，並提供具體 `summary` 供審批確認。
   - **行動端 / 遠端 Fallback (CLI or File)**：若處於無法呼叫 local MCP 的環境（例如手機版 Gemini Spark 操作），改由終端執行純 Ruby CLI：
     `tesseract save <topic> -s "摘要" -c "Markdown 內容"`
     或直接編輯專案內的 `tesseract/<topic>.md` 與 `tesseract/index.md`，確保知識沉澱不中斷。
<!-- tesseract-rule-end -->
