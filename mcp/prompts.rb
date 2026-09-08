# frozen_string_literal: true

module Tesseract
  module Prompts
    INSTRUCTIONS = <<~MARKDOWN
      # Tesseract Knowledge Base Guidelines

      You have access to the user's personal knowledge base via Tesseract MCP tools.
      Tesseract separates durable knowledge, architectural insights, and preferences from ephemeral project code.

      ## Working Principles:

      1. **Before Starting Tasks**:
         - List or read relevant knowledge topics using `tesseract_list_topics` or `tesseract_read_knowledge(topic: "index")`.
         - Check project-specific rules in `tesseract/rule.md` or via `tesseract_read_knowledge(topic: "rule")`.
         - Use `tesseract_search_knowledge` if looking for specific concepts, keywords, or tags.

      2. **Proactive Knowledge Retention (Do not wait for user prompt)**:
         - Capture key architectural decisions, resolved root causes, workarounds, or user preferences.
         - Use `tesseract_save_knowledge` to record insights.
         - If the user specifies or updates project-specific note-taking rules or preferences, record them in `tesseract/rule.md` (and use `tesseract_sync_project_rules` to keep project AI configs updated).

      3. **Structure & Formatting**:
         - One clear topic per file (e.g. `auth-flow`, `database-conventions`, `api-design`).
         - Use `#tags` for categorization (e.g. `#architecture`, `#security`, `#backend`).
         - Use `[[wikilinks]]` (e.g. `[[database-conventions]]`) to link related topics within the knowledge base.
         - Do not store raw source code files in knowledge base — store decisions, mental models, patterns, and insights.
      4. **Hyperfold (超維摺疊) Protocol**:
         - Triggered when the user invokes `/hyperfold` or clicks the Hyperfold action in the IDE.
         - **Analyze & Discover**: Read the specified note (or recent edits). Inspect human modifications, corrections, and architecture choices.
         - **Rule Extraction**: Identify generalized engineering preferences or habits to append to `tesseract/rule.md` (project) or `_global/rule.md` (cross-project).
         - **Dimensional Weaving**: Use `tesseract_search_knowledge` to find 1-3 related topics and suggest bidirectional `[[wikilinks]]`.
         - **Plan Review Presentation**: Present findings in an Antigravity Plan Review card with clear checkboxes/actions.
         - **Commitment**: Upon user approval, call `tesseract_hyperfold` to commit rules, backlinks, and index updates into the iCloud Vault.
    MARKDOWN

    HYPERFOLD_GUIDE = <<~MARKDOWN
      # ⬡ Tesseract Hyperfold (超維摺疊) 執行指引

      當使用者發起 Hyperfold 請求時，請依照以下四步執行認知審查（Plan Review 模式）：

      ### Step 1: 讀取與差分分析
      - 讀取該筆記目前內容（若有指定主題，呼叫 `tesseract_read_knowledge` 或直接讀取檔案）。
      - 比對人類的手動修改：關注使用者修正了哪些設定、選用了什麼架構、或留下了哪些備忘筆記。

      ### Step 2: 全域維度織網
      - 呼叫 `tesseract_search_knowledge`，尋找 Vault 中語意相關的筆記。
      - 找出 1~3 個最適合關聯的 `[[wikilinks]]`。

      ### Step 3: 呈現 Plan Review 審查卡片
      請以清晰的 Markdown 結構呈現給使用者審查：
      ```markdown
      ### ⬡ Tesseract Hyperfold Review: `<topic>`
      
      #### 1. ✦ 提煉規範建議 (rule.md)
      - [ ] **<一條可泛化的開發習慣或架構標準>** (目標: `tesseract/rule.md` 或 `_global/rule.md`)

      #### 2. ✦ 維度織網 (建議雙向鏈結)
      - [ ] `[[相關筆記名稱]]`：<關聯理由>

      #### 3. ✦ 索引摘要更新 (index.md)
      - <針對 Changelog 的一句話摘要>
      ```
      並提示使用者：「確認套用請回覆『確認』或點擊套用；亦可直接提出微調要求。」

      ### Step 4: 原子化寫入
      - 當使用者確認後，呼叫 `tesseract_hyperfold` 工具，將規則寫入 `rule.md`，並更新筆記與索引。
    MARKDOWN

    PROMPTS_LIST = [
      {
        name: 'tesseract_instructions',
        description: 'Core behavior guidelines and principles for interacting with the Tesseract personal knowledge base.',
        arguments: []
      },
      {
        name: 'tesseract_hyperfold_guide',
        description: 'Instructions for handling 4D Hyperfold requests in Chat, formatting Plan Review cards, and committing knowledge.',
        arguments: [
          {
            name: 'topic',
            description: 'Topic name or file path to hyperfold',
            required: false
          }
        ]
      }
    ].freeze

    def self.list_prompts(store = nil)
      list = PROMPTS_LIST.dup
      if store && store.respond_to?(:list_skills)
        store.list_skills.each do |skill|
          next if list.any? { |p| p[:name] == skill[:name] || p[:name] == skill[:id] }

          list << {
            name: skill[:name],
            description: skill[:description],
            arguments: [
              {
                name: 'topic',
                description: 'Target note or file path for the skill workflow',
                required: false
              }
            ]
          }
        end
      end
      list
    end

    def self.get_prompt(name, _arguments = {}, store: nil)
      case name
      when 'tesseract_instructions'
        {
          description: 'Tesseract Knowledge Base Guidelines',
          messages: [
            {
              role: 'user',
              content: {
                type: 'text',
                text: INSTRUCTIONS
              }
            }
          ]
        }
      when 'tesseract_hyperfold_guide', 'tesseract-hyperfold', 'hyperfold'
        {
          description: 'Tesseract Hyperfold Protocol and Plan Review Guidelines',
          messages: [
            {
              role: 'user',
              content: {
                type: 'text',
                text: HYPERFOLD_GUIDE
              }
            }
          ]
        }
      else
        if store && store.respond_to?(:read_skill)
          skill_content = store.read_skill(name) || store.read_skill(name.sub(/^tesseract-/, ''))
          if skill_content
            return {
              description: "Tesseract Skill: #{name}",
              messages: [
                {
                  role: 'user',
                  content: {
                    type: 'text',
                    text: skill_content
                  }
                }
              ]
            }
          end
        end
        nil
      end
    end
  end
end
