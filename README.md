# Tesseract — 人機共生個人知識庫系統

Tesseract 是一個以「**知識與產出分離、人機共生、超維摺疊（Hyperfold）**」為核心架構的個人知識管理（PKM）系統。

使用者可以透過 **Obsidian** 或 **IDE 檔案樹** 直接瀏覽、手寫與整理筆記；同時，各大主流 AI Agent（Google Antigravity / Gemini CLI、Claude Code、Cursor、Claude Desktop、Windsurf 等）透過標準 **MCP (Model Context Protocol)** 即時讀寫知識、自動沉澱技術決策，並透過 **Hyperfold（超維摺疊）** 擴充套件與技能，以極低阻力（Zero-Friction）反向吸收人類在 Markdown 中沉澱的工程思考與規範。

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
│    ├── .gitignore (含捷徑)   │       │    │     ├── rule.md  (跨專案通用偏好)│
│    └── tesseract/ ───────────┼──────►│    │     └── skills/  (雲端 AI 技能庫)│
│        (Symlink 隨時編輯)    │       │    │           └── hyperfold/         │
│                              │       │    │               └── SKILL.md       │
│    [ ⬡ Hyperfold 按鈕 ]      │       │    └── my-project/     (專案專屬知識)  │
│    (Cmd + Opt + H)           │       │          ├── index.md                 │
│           │                  │       │          └── db-schema.md             │
└───────────┼──────────────────┘       └───────────────────▲───────────────────┘
            │ (一鍵喚醒 Agent)                             │
            ▼                                     (即時讀寫 Markdown 檔案)
┌──────────────────────────────┐                           │
│  Antigravity / VS Code Chat  │       ┌───────────────────┴───────────────────┐
│    (Plan Review 認知審查)    │◄─────►│         bin/tesseract-mcp             │
│   • 規範提煉 (rule.md)       │ (MCP) │    (純 Ruby 3.0+ Stdlib 打造)          │
│   • 維度織網 ([[links]])     │       └───────────────────▲───────────────────┘
│   • 原子化確認套用 [Proceed] │                           │ (JSON-RPC 2.0 stdio)
└──────────────────────────────┘       ┌───────────────────┴───────────────────┐
                                       │          各大 AI Agents / IDEs        │
                                       │  (Antigravity / Claude / Cursor / etc)│
                                       └───────────────────────────────────────┘
```

---

## 核心設計原則

1. **知識與產出分離**：知識集中在個人的 iCloud Tesseract 知識庫（與 Obsidian 100% 原生相容），程式碼產出留在各自的專案 Repo 中，確保不同專案間的架構決策與實戰踩坑可以跨專案沉澱。
2. **人是知識庫的主人（Human-in-the-loop）**：透過 Symlink 將知識目錄直接掛載於專案的 IDE 檔案樹中（`tesseract/`），隨時可直接用 Markdown 編輯修正；AI 絕不擅自覆寫使用者的筆記。
3. **超維摺疊（Hyperfold）心流共生**：人類在 Markdown 中自由撰寫與修改筆記，無需手動切換視窗複製貼上 Prompt；按下右上角按鈕或快捷鍵，立即驅動側邊 AI 進行「差分分析、習慣提煉、雙向織網與拓撲更新」，並以 **Plan Review 卡片** 供人一鍵確認套用。
4. **技能庫即雲端個人資產**：AI Skills 存放在 iCloud Vault 的 `_global/skills/` 中，成為個人的跨設備數位資產。在 Obsidian 內亦可直接手動編修，並由 Tesseract 自動派發至本地各大 AI 工具（Gemini/Antigravity、Claude 等）。
5. **標準 MCP 協定通訊**：不向專案根目錄強行注入或覆蓋 `CLAUDE.md` / `GEMINI.md`，全程透過標準 MCP 存取，專案乾淨且零汙染。
6. **雙軌領域感知（Global + Project）**：
   - **`_global/`**：跨專案通用的個人開發習慣、系統設計心法與通用技能庫（在 Obsidian 檔案樹中自然置頂）。
   - **`<project_name>/`**：各專案獨立的特定架構與技術決策。
7. **Zero-Dependency（純 Ruby 3.0+ 標準庫）**：核心工具箱不依賴任何外部 Gem，啟動速度小於 0.02 秒，無版本衝突，乾淨輕量。

---

## 系統需求

- **macOS**（預設支援 iCloud Drive 同步；亦可自訂同步目錄）
- **Ruby >= 3.0.0**（使用純內建標準庫，無需 `bundle install`）
  - 支援 macOS 系統 Ruby、`rbenv`、`asdf`、`mise` 或 Homebrew Ruby (`brew install ruby`)。
- **Node.js >= 18.0.0**（僅於自行重新打包 VS Code / Antigravity 外掛時需要）

---

## 快速開始（三步驟）

### 步驟一：設定 PATH 環境變數

將此行加入您的 `~/.zshrc` 或 `~/.bashrc`（建議放在最前方以確保優先權）：

```bash
export PATH="$HOME/Documents/tesseract/bin:$PATH"
```

套用設定：
```bash
source ~/.zshrc
```

---

### 步驟二：一鍵初始化知識庫與 AI 設定

執行全自動初始化指令：

```bash
tesseract init
```

**`tesseract init` 會自動完成：**
1. **建立雲端知識庫**：在 iCloud Drive 建立 `Tesseract/` 知識庫、`_global/index.md`、`rule.md` 與 `_global/skills/`。
2. **派發雲端 AI Skills**（如 `tesseract-hyperfold`）：
   - **Google Antigravity / Gemini CLI**：軟連結至 `~/.gemini/config/skills/tesseract-hyperfold`
   - **Claude Code CLI**：軟連結至 `~/.claude/skills/tesseract-hyperfold`
3. **自動配置本機 AI Agent MCP 服務**：
   - **Google Antigravity / Gemini CLI**（寫入 `mcp_config.json`）
   - **Claude Code CLI**（寫入 `~/.claude.json`）
   - **Claude Desktop**（寫入 `claude_desktop_config.json`）
   - **Cursor**（寫入 `~/.cursor/mcp.json`）

---

### 步驟三：安裝 IDE 擴充套件（Hyperfold Plugin）

Tesseract 提供專屬的 IDE 擴充套件，讓您在 Markdown 中一鍵呼叫 AI 認知審查。

套件已預先編譯為 `extensions/vscode/tesseract-hyperfold-0.1.0.vsix`，提供以下幾種安裝方式：

#### 方式 A：GUI 介面安裝（最直覺推薦）
1. 在 **Antigravity IDE** 或 **VS Code** 中按下 `Cmd + Shift + P`（Windows/Linux: `Ctrl + Shift + P`）。
2. 輸入並選擇：**`Extensions: Install from VSIX...`**
3. 瀏覽並選擇本專案中的 `extensions/vscode/tesseract-hyperfold-0.1.0.vsix`。
4. 安裝完成後，再次按下 `Cmd + Shift + P` 執行 **`Developer: Reload Window`** 重整視窗。

#### 方式 B：終端機 CLI 一鍵安裝
- **安裝至 Antigravity IDE (推薦)**：
  ```bash
  "/Applications/Antigravity IDE.app/Contents/Resources/app/bin/antigravity-ide" --install-extension extensions/vscode/tesseract-hyperfold-0.1.0.vsix --force
  ```
- **安裝至 VS Code**：
  ```bash
  code --install-extension extensions/vscode/tesseract-hyperfold-0.1.0.vsix --force
  ```

#### 方式 C：開發軟連結模式（即時改碼即時生效）
若您想直接修改擴充套件 TypeScript 原始碼並即時測試：
```bash
# Antigravity IDE
ln -s "$(pwd)/extensions/vscode" ~/.antigravity-ide/extensions/tesseract-hyperfold

# VS Code
ln -s "$(pwd)/extensions/vscode" ~/.vscode/extensions/tesseract-hyperfold
```

---

## ⬡ 超維摺疊 (Hyperfold) 使用指南

### 核心痛點與設計理念

> **為什麼需要 Hyperfold？**
> 
> 在過去的人機協作中，當人類在 Markdown 筆記中修訂了設計決策，若想讓 AI 吸收並更新全域規範，必須：
> 1. 打開 Chat 視窗 -> 2. 手動打字或複製貼上 Prompt -> 3. 等待 AI 回覆 -> 4. 手動把更新的內容貼回各處。
> 
> **Hyperfold 徹底消除了所有複製貼上的雜音：**
> 人類留在 Markdown 筆記中專注思考；按下按鈕或快捷鍵，AI 立即在側邊以 **Plan Review** 呈現審查建議，人類點擊 `[Proceed]`，全域規範、雙向鏈結與索引拓撲即刻原子化更新！

```
人類直接在 Markdown 編輯
          │
          ▼
點擊 [ ⬡ Hyperfold ] 按鈕 或 按下 Cmd + Opt + H
          │
          ▼
IDE 擴充套件自動喚醒側邊 AI Agent
          │
          ▼
AI 執行雲端 tesseract-hyperfold 技能：
┌────────────────────────────────────────────────────────┐
│  ✦ 提煉規範建議：提煉出可泛化習慣至 rule.md            │
│  ✦ 維度織網建議：跨筆記檢索並提供雙向鏈結 ([[wikilinks]]) │
│  ✦ 拓撲索引更新：更新 index.md 檔案清單與 Changelog     │
└────────────────────────────────────────────────────────┘
          │
          ▼
人類檢視 Plan Review 卡片，點擊 [ Proceed (執行) ]
          │
          ▼
AI 呼叫 tesseract_hyperfold MCP 工具原子化寫入 iCloud Vault！
```

### 操作步驟

1. **開啟 Markdown 檔案**：
   開啟任何專案中的 `tesseract/*.md`、`README.md` 或全域筆記。
2. **一鍵觸發 Hyperfold**：
   - **方式 1（按鈕）**：點擊編輯器右上角標題列的綠色超正方體 **`[ ⬡ Hyperfold ]`** 圖示按鈕。
   - **方式 2（快捷鍵）**：按下專屬快捷鍵：
     - **macOS**：`Cmd + Opt + H`
     - **Windows / Linux**：`Ctrl + Alt + H`
3. **自動喚醒 Agent 進入 Plan Review**：
   - 側邊 Agent 視窗會自動開啟並即刻展開差分分析。
   - 呈現清晰的結構化審查卡片：
     - **提煉規範 (Rule Extraction)**：將實作決策泛化為跨專案原則或專案特定規則。
     - **維度織網 (Dimensional Backlinks)**：檢索關聯主題並建議雙向鏈結（如 `[[auth-flow]]`）。
     - **索引拓撲維護 (Topology Update)**：更新 Domain 的 `index.md` 索引與 Changelog。
4. **一鍵確認套用**：
   - 點擊 Antigravity 原生的綠色 **`[ Proceed (執行) ]`** 按鈕（或回覆「確認套用」）。
   - Agent 自動調用 `tesseract_hyperfold` MCP 工具將結果原子化寫入 iCloud。

---

## 雲端技能庫 (Cloud Skills) 架構

Tesseract 將 AI Agent 的技能視為**個人的可攜式雲端數位資產**：

```
iCloud Drive/Tesseract/
└── _global/
    └── skills/
        └── hyperfold/
            └── SKILL.md   ← 單一真實來源 (Single Source of Truth)
```

- **單一來源，多端同步**：技能檔案位於 iCloud Vault，在 Obsidian 內亦可直接手動修訂。
- **主流模型無縫相容**：
  - **Google Antigravity / Gemini CLI**：透過 `~/.gemini/config/skills/tesseract-hyperfold` 軟連結即時取用。
  - **Claude Code CLI**：透過 `~/.claude/skills/tesseract-hyperfold` 軟連結即時取用。
  - **Cursor / Windsurf**：透過 `tesseract sync-rules` 非破壞性注入指針遵行規範。
- **新增自訂技能**：
  只要在 `_global/skills/<skill_name>/SKILL.md` 建立技能，執行 `tesseract config mcp install` 後即自動發布至所有本地 AI 工具。

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

### 查看與管理設定（MCP 與 Skills 狀態）

```bash
tesseract config
```
檢視目前 iCloud 知識庫路徑，以及所有 AI Agent 的 MCP 與 Skills 啟用狀態。

- `tesseract config mcp install`（或 `tesseract mcp-install`）：一鍵自動重新偵測、註冊 MCP 與派發雲端 Skills 到所有已安裝的 AI 工具。
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

Tesseract MCP Server 內建以下標準工具，AI Agent 會在對話與認知審查中視任務自動調用：

| 工具名稱 | 說明 | 參數範例 |
| :--- | :--- | :--- |
| `tesseract_read_knowledge` | 讀取特定主題筆記或 `index.md` | `{"topic": "db-schema", "domain": "auto"}` |
| `tesseract_save_knowledge` | 儲存知識（自動維護標籤、Files 清單與 Changelog） | `{"topic": "auth", "content": "...", "tags": ["#security"], "summary": "採用 JWT"}` |
| `tesseract_search_knowledge` | 跨領域全文與 `#tag` 搜尋 | `{"query": "#database"}` 或 `{"query": "cors"}` |
| `tesseract_list_topics` | 列出當前專案或全域的所有知識主題 | `{"domain": "auto"}` |
| `tesseract_get_domain_status` | 取得當前知識庫狀態與活動 Domain | `{}` |
| `tesseract_create_domain` | 動態建立新的知識 Domain | `{"domain": "payment-service", "description": "金流微服務"}` |
| `tesseract_sync_project_rules` | 同步專案各 AI 設定檔（CLAUDE.md、.cursorrules 等）指向 `tesseract/rule.md` | `{"targets": ["claude", "cursor"]}` |
| `tesseract_hyperfold` | 超維摺疊：原子化提煉習慣至 `rule.md`、更新筆記雙向鏈結與 `index.md` | `{"topic": "auth", "rule": "偏好 Redis 權杖桶", "backlinks": ["[[gateway]]"]}` |

---

## 與 Obsidian / PKM 整合

1. 打開 **Obsidian**。
2. 點擊 **Open folder as vault**，選擇：
   `~/Library/Mobile Documents/com~apple~CloudDocs/Tesseract`
3. 您的知識庫會呈現：
   - **`_global/`**：置頂於最上方，存放通用規則、心法與雲端 Skills（`_global/skills/`）。
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
│   ├── store.rb                     ← 雙軌儲存、全文搜尋與 Skills 管理引擎
│   ├── installer.rb                 ← AI Agent MCP 與 Skills 自動派發器
│   ├── server.rb                    ← JSON-RPC 2.0 stdio 協定處理器
│   ├── tools.rb                     ← 核心 MCP 工具定義與執行器
│   └── prompts.rb                   ← 系統行為提示詞與動態 Skills 轉化
├── extensions/
│   └── vscode/                      ← Tesseract Hyperfold IDE 外掛 (TypeScript)
│       ├── package.json             ← 按鈕、快捷鍵與 Chat 宣告
│       ├── src/extension.ts         ← 靜默呼叫 Agent 與審查流程
│       └── tesseract-hyperfold-0.1.0.vsix ← 預先編譯外掛包
├── templates/
│   ├── index.md                     ← 知識庫首頁範本
│   ├── knowledge.md                 ← 主題筆記範本
│   └── skills/                      ← 跨模型通用技能範本
│       └── hyperfold/SKILL.md
├── test/
│   └── test_mcp_server.rb           ← 自動化單元與整合測試套件
└── README.md
```

---

## 擴充套件原始碼重新打包（開發者用）

若您修改了 `extensions/vscode/src/extension.ts` 並希望重新編譯打包 `.vsix`：

```bash
cd extensions/vscode
npm install
npm run package
```

編譯完成後將在 `extensions/vscode/` 生成最新的 `tesseract-hyperfold-0.1.0.vsix`。

---

## 執行測試

本系統核心使用純 Ruby 3.0+ 標準庫，無需安裝任何測試依賴：

```bash
ruby test/test_mcp_server.rb
```
