# Tesseract — 人機共生個人知識庫系統

Tesseract 是一個以「**知識與產出分離、人機共生**」為核心的個人知識管理（PKM）架構。

使用者可以透過 **Obsidian** 或 **IDE** 檔案樹直接瀏覽與手動維護知識庫；同時，AI Agent（Claude Code、Google Antigravity / Gemini CLI、Cursor、Claude Desktop 等）透過標準 **MCP (Model Context Protocol)** 讀取知識並自動記錄架構決策。

---

## 系統全景架構

```
                              ┌─────────────────────────────────────────┐
                              │       Obsidian / Foam / Finder          │
                              │ (直接將 iCloud/Tesseract/ 開啟為 Vault) │
                              └────────────────────┬────────────────────┘
                                                   │
                                                   ▼
┌──────────────────────────────┐       ┌───────────────────────────────────────┐
│     使用者專案 (IDE)         │◄─────►│    iCloud Drive/Tesseract/ (Vault)    │
│    ~/code/my-project/        │       │                                       │
│    ├── src/                  │       │    ├── _global/       (自然置頂全域庫)│
│    ├── package.json          │       │    │     ├── index.md (全域知識索引)  │
│    ├── .gitignore (含捷徑)   │       │    │     └── rules.md (跨專案通用偏好)│
│    └── tesseract/ ───────────┼──────►│    │                                  │
│        (Symlink 隨時編輯)    │       │    └── my-project/     (專案專屬知識)  │
│                              │       │          ├── index.md                 │
└──────────────────────────────┘       │          └── db-schema.md             │
                                       └───────────────────▲───────────────────┘
                                                           │
                                                  (即時讀寫 Markdown 檔案)
                                                           │
                                       ┌───────────────────┴───────────────────┐
                                       │         bin/tesseract-mcp             │
                                       │    (純 Ruby 3.0+ Stdlib 打造)          │
                                       └───────────────────▲───────────────────┘
                                                           │ (JSON-RPC 2.0 stdio)
                                       ┌───────────────────┴───────────────────┐
                                       │          各大 AI Agents / IDEs        │
                                       │  (Claude / Antigravity / Cursor / etc)│
                                       └───────────────────────────────────────┘
```

---

## 設計原則

1. **知識與產出分離**：知識集中在 iCloud Tesseract 知識庫（Obsidian 原生相容），程式碼產出留在各自專案。
2. **人是知識庫的主人（Human-in-the-loop）**：透過 Symlink 讓知識資料夾出現在 IDE 檔案樹中，或直接用 Obsidian 打開，使用者隨時手動修正 AI 的筆記或整理知識圖譜。
3. **AI 透過標準 MCP 存取**：不再向專案強行注入或覆蓋 `CLAUDE.md` / `GEMINI.md`，走標準 MCP 通訊，乾淨且零專案污染。
4. **雙軌領域感知（Global + Project）**：
   - **`_global/`**：跨專案通用的個人開發習慣、系統設計心法（在 Obsidian 檔案樹中自然置頂）。
   - **`<project_name>/`**：各專案獨立的特定架構與技術決策。
5. **Zero-Dependency（純 Ruby 3.0+ 標準庫）**：不依賴任何外部 Gem，啟動速度小於 0.02 秒，無版本衝突。

---

## 系統需求

- **macOS**（預設支援 iCloud Drive 同步）
- **Ruby >= 3.0.0**（使用純內建標準庫，無需 `bundle install`）
  - 支援系統 Ruby、`rbenv`、`asdf`、`mise` 或 Homebrew Ruby (`brew install ruby`)。

---

## 快速開始（兩步驟）

### 1. 加入 PATH

將此行加入您的 `~/.zshrc`（放在最前方以確保優先權）：

```bash
export PATH="$HOME/Documents/tesseract/bin:$PATH"
```

套用設定：
```bash
source ~/.zshrc
```

### 2. 一鍵初始化與自動配置 AI Agent

```bash
tesseract init
```

**`tesseract init` 會自動完成兩件事：**
1. 在 iCloud Drive 建立 `Tesseract/` 知識庫與 `_global/index.md`。
2. **自動偵測並設定** 電腦中已安裝的 AI 工具：
   - **Claude Code CLI**（寫入 `~/.claude.json`）
   - **Google Antigravity / Gemini CLI**（寫入 `mcp_config.json`）
   - **Claude Desktop**（寫入 `claude_desktop_config.json`）
   - **Cursor**（寫入 `~/.cursor/mcp.json`）

---

## 日常工作指令

### 建立新專案（一步到位）

```bash
tesseract new my-app
```
**自動完成：**
1. 建立專案目錄 `~/code/my-app`
2. 在 iCloud 建立專屬知識庫 `iCloud/Tesseract/my-app/`（含 `index.md`、`rule.md` 與 `assets/`）
3. 在專案中建立 `my-app/tesseract/` 捷徑，並提供 Git 忽略設定提示

---

### 連結既有專案

進入任何現有專案目錄，直接執行：

```bash
cd ~/code/existing-project
tesseract link
```
*（也可以指定自訂 domain：`tesseract link . custom-domain`）*

- 自動以當前目錄名稱作為知識庫 Domain。
- 若 iCloud 中尚無該 Domain，會自動在雲端建立 `index.md` 與 `rule.md`。
- 自動建立 `tesseract/` symlink，並提示 Git 忽略設定：
  - **團隊共用忽略**：加入 `.gitignore`
  - **僅本機忽略（不影響他人）**：加入 `.git/info/exclude`

---

### 專案專屬規範與跨 AI 同步 (`rule.md` & `sync-rules`)

每個專案都擁有獨立的 `tesseract/rule.md`，用來定義該專案的**知識庫強化方式、筆記格式或開發習慣**（例如 ADR 規範、Debug 踩坑記錄時機等）：

1. **使用者主導**：直接在 `tesseract/rule.md` 用 Markdown 書寫規範（單一真實來源）。
2. **跨 AI 安全同步**：
   ```bash
   tesseract sync-rules
   ```
   *（也可以指定目標，如：`tesseract sync-rules claude cursor`）*
   - 自動在專案根目錄的 `CLAUDE.md`、`.cursorrules`、`GEMINI.md`、`.windsurfrules` 嵌入指針。
   - **非破壞性更新**：以標記區塊（`<!-- tesseract-rule-start -->`）插入，100% 保留現有檔案中原本的 build、test 等指令。
   - 所有的 AI Agent 進到該專案時，都會自然遵循 `tesseract/rule.md` 的專案規範！

---

### 查看與管理設定（MCP 狀態）

```bash
tesseract config
```
檢視目前 iCloud 知識庫路徑，以及所有 AI Agent 的 MCP 啟用狀態。

- `tesseract config mcp install`：一鍵自動更新/註冊 MCP 到所有已安裝的 AI 工具。
- `tesseract config mcp show`：檢視手動配置用的 JSON 程式碼。

---

### 查看目前知識庫狀態

```bash
tesseract status
```
列出 iCloud 中的 `_global`、所有專案 Domain 與最後更新時間，以及本機上已連結的專案。

---

### 重建知識庫索引清單

```bash
tesseract reindex
```
自動掃描所有 Domain 中的知識檔案，重建各自 `index.md` 中的 `## Files` 清單。

---

## MCP Tools 清單（AI Agent 自動呼叫）

Tesseract MCP Server 內建以下標準工具，AI Agent 會在對話中視任務自動調用：

| 工具名稱 | 說明 | 參數範例 |
| :--- | :--- | :--- |
| `tesseract_read_knowledge` | 讀取特定主題筆記或 `index.md` | `{"topic": "db-schema", "domain": "auto"}` |
| `tesseract_save_knowledge` | 儲存知識（自動維護標籤、Files 清單與 Changelog） | `{"topic": "auth", "content": "...", "tags": ["#security"], "summary": "採用 JWT"}` |
| `tesseract_search_knowledge` | 跨領域全文與 `#tag` 搜尋 | `{"query": "#database"}` 或 `{"query": "cors"}` |
| `tesseract_list_topics` | 列出當前專案或全域的所有知識主題 | `{"domain": "auto"}` |
| `tesseract_get_domain_status` | 取得當前知識庫狀態與活動 Domain | `{}` |
| `tesseract_create_domain` | 動態建立新的知識 Domain | `{"domain": "payment-service", "description": "金流微服務"}` |
| `tesseract_sync_project_rules` | 同步專案各 AI 設定檔（CLAUDE.md、.cursorrules 等）指向 `tesseract/rule.md` | `{"targets": ["claude", "cursor"]}` |

---

## 與 Obsidian / PKM 整合

1. 打開 **Obsidian**。
2. 點擊 **Open folder as vault**，選擇：
   `~/Library/Mobile Documents/com~apple~CloudDocs/Tesseract`
3. 您的知識庫會呈現：
   - **`_global/`**：置頂於最上方，存放通用規則與心法。
   - **各專案資料夾**：存放特定專案的筆記。
   - 支援完整的 `[[wikilinks]]` 雙向連結與 `#tags` 知識圖譜。

---

## 目錄結構

```
~/Documents/tesseract/                ← 工具箱 Repo
├── bin/
│   ├── tesseract                    ← CLI 工具引導（由 mcp/cli.rb 驅動）
│   └── tesseract-mcp                ← MCP 服務引導（由 mcp/server.rb 驅動）
├── mcp/                             ← 核心純 Ruby 3.0+ 模組
│   ├── cli.rb                       ← 所有 CLI 指令核心
│   ├── store.rb                     ← 雙軌儲存與全文搜尋引擎
│   ├── installer.rb                 ← AI Agent MCP 自動配置器
│   ├── server.rb                    ← JSON-RPC 2.0 stdio 協定處理器
│   ├── tools.rb                     ← 6 大核心 MCP 工具定義與執行器
│   └── prompts.rb                   ← 系統行為提示詞
├── test/
│   └── test_mcp_server.rb           ← 自動化單元與整合測試套件
└── README.md
```

---

## 執行測試

```bash
ruby test/test_mcp_server.rb
```
