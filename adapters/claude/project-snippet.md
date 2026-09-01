<!-- tesseract-start -->
# Tesseract 知識庫

此專案連結了 Tesseract domain：**{{DOMAIN_NAME}}**

知識庫路徑：`{{DOMAIN_DIR}}`
本機 symlink：`tesseract/`

## 結構

- `tesseract/index.md`：索引頁，列出所有知識檔案（`## Files`）與 Changelog
- `tesseract/<topic>.md`：知識本體，一個主題一個檔案

## 使用規則

1. 工作開始前，讀 `tesseract/index.md` 了解有哪些知識檔；讀與任務相關的 `<topic>.md`
2. 主動強化時機：設計決策、問題解決、使用者偏好、重要洞見 → 立即更新
3. 強化方式：
   - 找到對應 `<topic>.md` 更新；找不到就新增
   - 使用 `#tag` 標記主題，`[[檔名]]` 連結相關知識
   - 不把知識寫進 `index.md`（它只是索引）
   - 新增檔案後在 `index.md` 的 `## Files` 加一行
   - 在 `index.md` 的 `## Changelog` 最下方 append 一行
4. 不把程式碼存進知識庫
<!-- tesseract-end -->
