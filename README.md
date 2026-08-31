# Tesseract — 個人知識庫系統

Tesseract 是一個以「知識與產出分離」為核心的個人知識管理架構。AI 在各個專案中工作時，會持續讀取並強化 Tesseract 中的知識；使用者可以直接在 IDE 中手動修正 AI 產出的知識紀錄。

---

## 設計原則

1. **知識與產出分離**：知識存在 Tesseract，程式碼與產出存在各自的專案
2. **AI 雙向互動**：AI 讀取知識以輔助工作，工作後寫回知識以持續強化
3. **人工可介入**：透過 symlink 讓知識資料夾出現在 IDE 的 file tree 中，使用者可直接修正
4. **Git 版控**：所有知識變更有完整歷史紀錄

---

## 目錄結構

```
~/Documents/tesseract/
  bin/
    tesseract          ← CLI 主入口
  scripts/
    init.sh            ← 初始化設定
    new-domain.sh      ← 建立新 domain
    link.sh            ← 連結 domain 到專案
    status.sh          ← 查看所有連結狀態
    reindex.sh         ← 重新產生各 domain 的 summary.md
  templates/
    index.md           ← domain 知識檔模板
    CLAUDE.md.snippet  ← 自動寫入專案 CLAUDE.md 的片段
  skills/
    tesseract.md       ← Claude Code skill（需安裝）
  domains/
    akasha/            ← 個人通用知識庫（預設 domain）
      index.md
      assets/
```

---

## 安裝

```bash
# 1. 加入 PATH（加到 ~/.zshrc 或 ~/.bashrc）
echo 'export PATH="$PATH:$HOME/Documents/tesseract/bin"' >> ~/.zshrc
source ~/.zshrc

# 2. 安裝 Claude Code Skill
mkdir -p ~/.claude/skills
ln -sf ~/Documents/tesseract/skills/tesseract.md ~/.claude/skills/tesseract.md

# 3. 初始化（建立設定檔）
tesseract init
```

---

## 基本使用

```bash
# 建立新 domain
tesseract new-domain product

# 將 domain 連結到專案
cd ~/code/my-project
tesseract link . product
# → 在專案根目錄建立 .tesseract/ symlink
# → 自動更新專案的 CLAUDE.md

# 查看目前所有連結
tesseract status

# 重新產生各 domain 的 summary
tesseract reindex
```

---

## Domain 結構

每個 domain 是一個獨立的知識領域。`index.md` 是主要知識檔，包含固定 schema 讓 AI 能可靠讀寫：

- `## Context`：此 domain 的目的與範疇
- `## Knowledge`：核心知識，AI 持續更新
- `## User Preferences`：AI 學到的使用者習慣與偏好
- `## Open Questions`：尚未解決的問題
- `## Changelog`：Append-only 變更紀錄

---

## Symlink 的用途

`tesseract link` 在專案中建立 `.tesseract/` symlink，使 IDE（如 VS Code、RubyMine）可以在 file tree 中看到知識資料夾，讓使用者能直接手動修正 AI 寫入的內容，而不需要另外開啟 iCloud 資料夾。

---

## Git 版控

建議對整個 `tesseract/domains/` 資料夾進行 git 版控：

```bash
cd ~/Documents/tesseract
git init
echo "domains/*/assets/*.mp4" >> .gitignore
git add .
git commit -m "init: Tesseract 初始化"
```

---

## Skill 使用說明

安裝後，在任何有 `.tesseract/` symlink 的專案中使用 Claude Code，Claude 會自動：
1. 讀取 `.tesseract/index.md` 作為工作前置知識
2. 工作結束後更新知識庫並寫入 Changelog

可以在對話中直接告訴 Claude：「更新 Tesseract」或「把這個記錄到知識庫」。
