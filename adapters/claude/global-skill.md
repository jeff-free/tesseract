# Tesseract 知識庫 Skill

## 觸發條件

當專案根目錄存在 `tesseract/` 資料夾（symlink），此 skill 自動生效。

---

## 工作前：載入知識庫

1. 讀取 `tesseract/index.md`，了解此 domain 有哪些知識檔案（`## Files` 清單）
2. 讀取與當前任務相關的知識檔案（按需讀取，不需全部讀）
3. 一句話告知使用者已載入哪個 domain

---

## 知識庫結構

```
tesseract/           ← symlink 到 iCloud/Tesseract/<domain>/
  index.md           ← 索引：domain 說明 + Files 清單 + Changelog
  <topic>.md         ← 知識本體，一個主題一個檔案
  assets/
```

**`index.md` 只是索引，不存知識內容。**

---

## 主動強化時機（不等使用者）

- 設計或架構決策確定
- 問題解決（根因、workaround）
- 使用者偏好被觀察到
- 對話中途出現重要洞見

更新後告知「已記錄到知識庫」（一句話），不中斷主要工作。

---

## 使用者觸發時機

使用者說「完成」、「謝謝」、「更新知識庫」、「記錄到 Tesseract」。

---

## 強化步驟

1. 在 `tesseract/index.md` 的 `## Files` 找到對應主題的 `<topic>.md`
2. 讀取並更新；若找不到，新增新的 `<topic>.md`
3. 知識檔格式：使用 `#tag` 標記主題，`[[檔名]]` 連結同 domain 的其他知識檔
4. 若新增了檔案：在 `index.md` 的 `## Files` 加一行 `- [[topic]] — 說明 #tag`
5. 在 `index.md` 的 `## Changelog` 最下方 append：`- YYYY-MM-DD: 說明（AI）`

---

## 連結規範

| 場景 | 語法 |
|------|------|
| 同 domain 內的檔案 | `[[topic-name]]` |
| 跨 domain | `[[domain]]` 或 `[[domain/topic]]` |
| 主題標籤 | `#tag`（放在檔案標題下方） |

---

## 禁止事項

- 不把知識內容寫進 `index.md`
- 不把程式碼存入知識庫
- 不刪除 Changelog 既有記錄
- 無實質新知識時不更新

---

## 跨 Domain 處理

若知識超出當前 domain 範疇：
1. 先記在當前 domain，標記「可能屬於其他 domain」
2. 提醒使用者：`tesseract new-domain <建議名稱>`
