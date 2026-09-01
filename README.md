# Tesseract — 個人知識庫系統

Tesseract 是一個以「知識與產出分離」為核心的個人知識管理架構。AI 在各個專案中工作時，會持續讀取並強化 Tesseract 中的知識；使用者可以直接在 IDE 中手動修正 AI 產出的知識紀錄。

---

## 設計原則

1. **知識與產出分離**：知識存在 Tesseract，程式碼與產出存在各自的專案
2. **AI 雙向互動**：AI 讀取知識以輔助工作，工作後寫回知識以持續強化
3. **人工可介入**：透過 symlink 讓知識資料夾出現在 IDE 的 file tree 中，使用者可直接修正
4. **Git 版控**：所有知識變更有完整歷史紀錄

---

## 系統全景

```
┌─────────────────────────────────────────────────────────────────┐
│                         使用者的機器                             │
│                                                                 │
│  ┌─────────────────────────┐    ┌──────────────────────────┐   │
│  │   ~/Documents/tesseract │    │   iCloud Drive/Tesseract │   │
│  │   （此 repo，工具箱）    │    │   （知識資料，同步備份） │   │
│  │                         │    │                          │   │
│  │  bin/tesseract  ←────── │────│──► new-domain.sh         │   │
│  │  scripts/               │    │    建立 domain 資料夾     │   │
│  │  adapters/              │    │                          │   │
│  │  skills/                │    │  tesseract/              │   │
│  │  templates/             │    │    index.md              │   │
│  └─────────────────────────┘    │    <topic>.md            │   │
│                                 │    assets/               │   │
│                                 │                          │   │
│                                 │  product/                │   │
│                                 │    index.md              │   │
│                                 │    <topic>.md            │   │
│                                 └──────────────────────────┘   │
│                                           ▲                     │
│                        symlink            │                     │
│  ~/code/my-project/tesseract/ ───────────┘                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 初始化與安裝流程

```
使用者執行：

  1. echo 'export PATH=...' >> ~/.zshrc      # 加 CLI 到 PATH
  2. tesseract init                           # 建立 ~/.tesseractrc
  3. tesseract install-adapters               # 安裝 global skill

            └─► ~/.claude/skills/tesseract.md  (Claude adapter)
                ~/.tesseractrc                  (設定檔)
                  TESSERACT_DOMAINS=~/iCloud/Tesseract
                  TESSERACT_ADAPTERS=claude
```

---

## Domain 建立與專案連結

```
tesseract new <名稱> [路徑]        ← 一步完成（推薦）
  │
  ├─► 在 ~/code/ 建立專案資料夾
  ├─► 在 iCloud/Tesseract/<名稱>/ 建立 domain
  └─► 執行 link（見下方）

─────────────────────────────────────────────────

tesseract link <專案路徑> <domain>  ← 連結現有專案到現有 domain
  │
  ├─► 建立 symlink
  │     <專案>/tesseract/ ──→ iCloud/Tesseract/<domain>/
  │
  └─► 寫入 adapter 片段到 <專案>/CLAUDE.md
        <!-- tesseract-start -->
          domain 名稱、路徑、使用規則
        <!-- tesseract-end -->

結果：IDE file tree 中可見知識資料夾，AI 也收到操作規則
```

---

## Adapter 系統

```
adapters/
  _behavior.md          ← 唯一真實來源（所有 AI 的行為規範）
       │
       ├─► adapters/claude/
       │     meta.sh              (ADAPTER_FILENAME=CLAUDE.md)
       │     project-snippet.md   (寫入專案的片段，含 {{DOMAIN_NAME}} 變數)
       │     global-skill.md      (安裝到 ~/.claude/skills/)
       │
       └─► adapters/gemini/
             meta.sh
             project-snippet.md

install-adapters.sh 讀取 TESSERACT_ADAPTERS=claude,gemini
  → 對每個 adapter 執行對應的安裝步驟
```

---

## AI 工作時的讀寫循環

```
AI 收到任務
     │
     ▼
┌─────────────────────────────────┐
│  工作前（載入知識）              │
│                                 │
│  1. 讀 tesseract/index.md       │
│     → 看 ## Files 有哪些主題    │
│  2. 讀相關的 <topic>.md         │
│  3. 告知使用者已載入哪個 domain  │
└────────────────┬────────────────┘
                 │
                 ▼
           執行實際工作
                 │
                 ▼
┌─────────────────────────────────┐
│  主動強化（不等使用者）          │
│                                 │
│  觸發條件：                     │
│  • 設計/架構決策確定             │
│  • 問題解決（根因、workaround）  │
│  • 觀察到使用者偏好              │
│  • 對話中出現重要洞見            │
│                                 │
│  步驟：                         │
│  1. 找 index.md ## Files        │
│     → 找到 → 更新 <topic>.md    │
│     → 找不到 → 新增 <topic>.md  │
│  2. 若新增：在 index.md         │
│     ## Files 加一行              │
│  3. 在 index.md ## Changelog    │
│     最下方 append 一行           │
└─────────────────────────────────┘
```

---

## Domain 內部結構

```
iCloud/Tesseract/<domain>/
│
├── index.md                    ← 索引（只存目錄，不存知識內容）
│   │
│   ├── ## Context              ← 此 domain 的目的與範疇
│   ├── ## Files                ← 知識檔清單
│   │     - [[topic-a]] — 說明 #tag
│   │     - [[topic-b]] — 說明 #tag
│   └── ## Changelog            ← Append-only，不得刪除
│         - 2026-01-01: 說明（AI）
│
├── topic-a.md                  ← 知識本體（一主題一檔案）
│   ├── #tag 主題標記
│   └── [[topic-b]] 跨檔連結
│
├── topic-b.md
└── assets/                     ← 圖片等附件
```

---

## 目錄結構

```
~/Documents/tesseract/          ← 此 repo（工具箱）
  bin/
    tesseract                   ← CLI 主入口
  scripts/
    init.sh                     ← 初始化設定（建立 ~/.tesseractrc）
    new.sh                      ← 一步建立專案 + domain + 連結
    new-domain.sh               ← 僅建立 iCloud domain
    link.sh                     ← 連結 domain 到專案
    install-adapters.sh         ← 安裝各 AI 的 global skill
    status.sh                   ← 查看所有連結狀態
    reindex.sh                  ← 重建各 domain 的 index.md Files 清單
  adapters/
    _behavior.md                ← 行為規範唯一真實來源
    claude/
      meta.sh
      project-snippet.md
      global-skill.md
    gemini/
      meta.sh
      project-snippet.md
  templates/
    index.md                    ← 新 domain 的初始 index.md 模板
    knowledge.md                ← 新知識檔模板
    CLAUDE.md.snippet           ← （舊版，已由 adapters/ 取代）
  skills/
    tesseract.md                ← 開發中的 skill（安裝前的原始檔）
```

**知識資料**（`iCloud Drive/Tesseract/`，由 iCloud 同步備份）：
```
Tesseract/
  tesseract/                    ← 個人通用知識庫（預設 domain）
    index.md
    <topic>.md
    assets/
  <其他 domain>/
    index.md
    <topic>.md
    assets/
```

**專案中**：
```
my-project/
  tesseract/  →  ln -s  →  iCloud/Tesseract/<domain>/
  CLAUDE.md   →  包含 tesseract-start/end 片段（AI 操作規則）
```

---

## 安裝

```bash
# 1. 加入 PATH（加到 ~/.zshrc 或 ~/.bashrc）
echo 'export PATH="$PATH:$HOME/Documents/tesseract/bin"' >> ~/.zshrc
source ~/.zshrc

# 2. 初始化（建立設定檔 ~/.tesseractrc）
tesseract init

# 3. 安裝 AI adapter global skill
tesseract install-adapters
```

---

## 基本使用

```bash
# 建立新專案（一步完成：資料夾 + domain + 連結）
tesseract new my-project

# 或分步操作：
#   建立新 domain
tesseract new-domain product
#   將現有專案連結到 domain
cd ~/code/my-project
tesseract link . product

# 查看目前所有連結
tesseract status

# 重新產生各 domain 的 index.md Files 清單
tesseract reindex
```

---

## Skill 使用說明

安裝後，在任何有 `tesseract/` symlink 的專案中使用 Claude Code，Claude 會自動：
1. 讀取 `tesseract/index.md` 作為工作前置知識
2. 工作結束後更新知識庫並寫入 Changelog

可以在對話中直接告訴 Claude：「更新 Tesseract」或「把這個記錄到知識庫」。
