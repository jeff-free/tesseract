# Domain: tesseract

## Context

個人通用知識庫。存放跨專案的知識、個人工作哲學、學習洞見、
以及 AI 在各種情境下觀察到的使用者偏好。

此 domain 作為所有其他 domain 的基礎，存放不屬於特定專案但值得長期保留的知識。

---

## Knowledge

### Tesseract 系統本身

- **核心設計**：知識與產出分離。Tesseract 存放知識，各專案存放產出
- **雙向互動**：AI 讀取知識輔助工作，工作後寫回知識強化系統
- **Symlink 用途**：`.tesseract/` symlink 讓知識資料夾出現在 IDE file tree，使使用者可直接修正 AI 寫入的內容

### 系統架構觀念

- Domain 是一個知識領域的最小單位，應保持單一責任
- 知識應抽象而非具體：存「使用者偏好 RSpec one-liner 語法」而非貼上整段測試程式碼
- Reindex 產生 `summary.md`，用於 context 緊張時的快速載入

---

## User Preferences

（AI 在與使用者互動後填入觀察到的個人習慣與偏好）

---

## Open Questions

- Tesseract 在知識庫規模變大後，是否需要加入 vector search（如 Khoj 或 Anything-LLM）？
- 多個 domain 之間的知識合成機制尚未設計

---

## Changelog

- 2026-09-01: Domain 初始化，系統首次啟動（AI）
