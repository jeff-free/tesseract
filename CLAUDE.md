<!-- tesseract-start -->
# Tesseract 知識庫

此專案連結了 Tesseract domain：**tesseract**

知識庫路徑：`/Users/jfree/Library/Mobile Documents/com~apple~CloudDocs/Tesseract/tesseract`
本機 symlink：`tesseract/`（在此專案根目錄）

## 結構

- `tesseract/index.md`：索引頁，列出所有知識檔案（`## Files`）與 Changelog
- `tesseract/<topic>.md`：知識本體，一個主題一個檔案

## 使用規則

1. 工作開始前，讀 `tesseract/index.md` 了解有哪些知識檔；讀與任務相關的 `<topic>.md`
2. 主動強化時機（不等使用者）：設計決策、問題解決、發現使用者偏好、重要洞見
3. 強化方式：
   - 找到對應的 `<topic>.md` 更新；找不到就新增一個
   - 使用 `#tag` 標記主題，`[[檔名]]` 連結相關知識
   - **不把知識寫進 index.md**，它只是索引
   - 新增檔案後，在 `index.md` 的 `## Files` 加入連結
   - 在 `index.md` 的 `## Changelog` 最下方 append 一行
4. 不把程式碼存進知識庫；只存知識、洞見、決策、使用者偏好
<!-- tesseract-end -->
