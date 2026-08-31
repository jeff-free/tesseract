<!-- tesseract-start -->
# Tesseract 知識庫

此專案連結了 Tesseract domain：**tesseract**

知識庫路徑：`/Users/jfree/Library/Mobile Documents/com~apple~CloudDocs/Tesseract/tesseract`
本機 symlink：`.tesseract/`（在此專案根目錄）

## 使用規則

1. 工作開始前，讀取 `.tesseract/index.md` 取得背景知識
   - 若 context 緊張且存在 `.tesseract/summary.md`，優先讀 summary
2. 工作結束時（或使用者說「完成」、「更新知識庫」），更新 `.tesseract/index.md`：
   - 在 `## Knowledge` 新增或精煉洞見（不刪除既有內容）
   - 在 `## User Preferences` 記錄新觀察到的使用者習慣
   - 在 `## Changelog` **最下方** append 一行：`- YYYY-MM-DD: 簡短說明（AI）`
3. 若發現超出此 domain 範疇的重要知識，提醒使用者考慮建立新 domain
4. 不要把程式碼存進知識庫；只存知識、洞見、架構決策、使用者偏好
<!-- tesseract-end -->
