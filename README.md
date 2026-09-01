# Tesseract — 人機共生個人知識庫系統

Tesseract 是一個以「知識與產出分離、人機共生」為核心的個人知識管理（PKM）架構。
使用者可以透過 **Obsidian** 或 **IDE** 檔案樹直接瀏覽與手動維護知識庫；同時，AI Agent（Claude Code、Gemini/Antigravity、Cursor 等）透過標準 **MCP (Model Context Protocol)** 讀取知識並自動記錄架構決策。

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
│    ├── src/                  │       │    ├── index.md        (全域知識索引)  │
│    ├── package.json          │       │    ├── dev-rules.md    (跨專案通用偏好)│
│    ├── .gitignore (含捷徑)   │       │    │                                  │
│    └── tesseract/ ───────────┼──────►│    └── my-project/     (專案專屬知識)  │
│        (Symlink 隨時編輯)    │       │          ├── index.md                 │
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
                                       │        (Claude / Gemini / Cursor)     │
                                       └───────────────────────────────────────┘
```

---

## 設計原則

1. **知識與產出分離**：知識集中在 iCloud Tesseract 知識庫（Obsidian 相容），程式碼留在各專案。
2. **人是知識庫的主人**：透過 Symlink 讓知識資料夾出現在 IDE 檔案樹中，或直接用 Obsidian 打開，隨時手動修正與整理。
3. **AI 透過 MCP 標準存取**：不再向專案強行注入或覆蓋 `CLAUDE.md` / `GEMINI.md`，走標準 MCP 通訊，乾淨且零專案污染。
4. **雙軌領域感知（Global + Project）**：AI 能同時讀取「全域通用原則」與「當前專案專屬架構」。

---

## 系統需求

- **macOS**（預設支援 iCloud Drive 同步）
- **Ruby >= 3.0.0**（純標準庫，**零外部 Gem 相依性**，無需 `bundle install`）
  - 支援系統 Ruby、`rbenv`、`asdf`、`mise` 或 Homebrew Ruby (`brew install ruby`)。

---

## 快速開始（三步驟）

### 1. 加入 PATH（提高優先權，避免與系統 OCR 工具衝突）

將此行加入您的 `~/.zshrc`：

```bash
export PATH="$HOME/Documents/tesseract/bin:$PATH"
```

套用設定：
```bash
source ~/.zshrc
```

### 2. 初始化知識庫

```bash
tesseract init
```
此步驟會在 iCloud Drive 建立 `Tesseract/` 資料夾與全域 `index.md`。

### 3. 配置 AI Agent 的 MCP Server

執行以下指令查看各大 AI 工具的設定方式：
```bash
tesseract mcp-config
```

#### 各 AI 工具設定範例：

* **Claude Code CLI**：
  ```bash
  claude mcp add tesseract -- "$HOME/Documents/tesseract/bin/tesseract-mcp"
  ```

* **Google Antigravity / Gemini CLI**（在 `mcp_config.json` 中加入）：
  ```json
  {
    "mcpServers": {
      "tesseract": {
        "command": "/Users/jfree/Documents/tesseract/bin/tesseract-mcp"
      }
    }
  }
  ```

* **Claude Desktop**（`~/Library/Application Support/Claude/claude_desktop_config.json`）：
  ```json
  {
    "mcpServers": {
      "tesseract": {
        "command": "/Users/jfree/Documents/tesseract/bin/tesseract-mcp"
      }
    }
  }
  ```

* **Cursor**（`.cursor/mcp.json`）：
  ```json
  {
    "mcpServers": {
      "tesseract": {
        "command": "/Users/jfree/Documents/tesseract/bin/tesseract-mcp"
      }
    }
  }
  ```

---

## 日常工作流程

### 建立新專案（一步到位）

```bash
tesseract new my-app
```
**自動完成三件事：**
1. 建立專案目錄 `~/code/my-app`
2. 在 iCloud 建立專屬知識庫 `iCloud/Tesseract/my-app/`（含 `index.md` 與 `assets/`）
3. 在專案中建立 `my-app/tesseract/` 捷徑，並自動將 `tesseract` 加入 `.gitignore`

### 連結現有專案到既有知識 Domain

```bash
cd ~/code/existing-project
tesseract link . my-domain
```

### 查看目前狀態

```bash
tesseract status
```

### 重建知識庫索引清單

```bash
tesseract reindex
```

---

## MCP Tools 清單（AI 自動呼叫）

Tesseract MCP Server 內建以下標準工具：

| 工具名稱 | 說明 | 參數範例 |
| :--- | :--- | :--- |
| `tesseract_read_knowledge` | 讀取特定主題筆記或 `index.md` | `{"topic": "db-schema", "domain": "auto"}` |
| `tesseract_save_knowledge` | 儲存知識（自動維護標籤、Files 清單與 Changelog） | `{"topic": "auth", "content": "...", "tags": ["#security"], "summary": "採用 JWT"}` |
| `tesseract_search_knowledge` | 跨領域全文與 `#tag` 搜尋 | `{"query": "#database"}` 或 `{"query": "cors"}` |
| `tesseract_list_topics` | 列出當前專案或全域的所有知識主題 | `{"domain": "auto"}` |
| `tesseract_get_domain_status` | 取得當前知識庫狀態與活動 Domain | `{}` |
| `tesseract_create_domain` | 動態建立新的知識 Domain | `{"domain": "payment-service", "description": "金流微服務"}` |

---

## 目錄結構

```
~/Documents/tesseract/                ← 工具箱 Repo
├── bin/
│   ├── tesseract                    ← 使用者操作 CLI
│   └── tesseract-mcp                ← AI 呼叫的 MCP 服務入口（Ruby 3.0+）
├── mcp/
│   ├── server.rb                    ← JSON-RPC 2.0 stdio 協定引擎
│   ├── store.rb                     ← 雙軌儲存與搜尋引擎（零 Gem 相依）
│   ├── tools.rb                     ← MCP 工具定義與執行器
│   └── prompts.rb                   ← 行為引導與規範
├── scripts/                         ← CLI 各功能 Shell 腳本
├── templates/                       ← index.md 模板
├── test/                            ← 自動化單元與整合測試
└── README.md
```
