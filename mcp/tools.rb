# frozen_string_literal: true

require 'json'

module Tesseract
  module Tools
    TOOLS_LIST = [
      {
        name: 'tesseract_read_knowledge',
        description: 'Read a topic or index from the Tesseract knowledge base (global or project domain).',
        inputSchema: {
          type: 'object',
          properties: {
            topic: {
              type: 'string',
              description: 'Topic name to read (e.g. "index", "rule", "database-schema", "auth-flow"). Default is "index".'
            },
            domain: {
              type: 'string',
              description: 'Domain name (e.g. "journapy", "tesseract", "global", or "auto"). IMPORTANT: When working in a known project, explicitly pass the project domain name instead of relying on "auto". Defaults to "auto".'
            }
          },
          required: []
        }
      },
      {
        name: 'tesseract_save_knowledge',
        description: 'Proactively save or update a durable knowledge topic in Tesseract. ' \
                     'CRITICAL: (1) Autonomously invoke this tool whenever resolving non-trivial bugs, establishing architectural patterns/decisions, or discovering gotchas. ' \
                     '(2) Before calling this tool, briefly output 1 sentence in chat explaining what is being saved and why. ' \
                     '(3) Always provide a clear, informative summary explaining the change for user approval prompts and changelogs. ' \
                     '(4) Always pass the explicit project domain name (e.g. "journapy") when saving project knowledge so it does not fall back to "_global". ' \
                     'Automatically updates index.md and changelog.',
        inputSchema: {
          type: 'object',
          properties: {
            topic: {
              type: 'string',
              description: 'Topic name (without .md extension, e.g. "api-design", "troubleshooting").'
            },
            summary: {
              type: 'string',
              description: 'Clear 1-sentence summary of what is being recorded and why. Crucial: Displayed directly in user confirmation/approval dialogs and recorded in index.md Changelog.'
            },
            content: {
              type: 'string',
              description: 'The Markdown content to save for this topic.'
            },
            tags: {
              type: 'array',
              items: { type: 'string' },
              description: 'Optional tags to associate with this topic (e.g. ["#auth", "#security"]).'
            },
            domain: {
              type: 'string',
              description: 'Target domain (explicit project domain name like "journapy", "global" for cross-project root vault, or "auto"). Always prefer explicit project domain name over "auto". Defaults to "auto".'
            },
            append: {
              type: 'boolean',
              description: 'Optional. If true, appends the new content to the existing topic file instead of overwriting it. Strongly recommended when adding entries to cumulative topics like "troubleshooting".'
            }
          },
          required: %w[topic summary content]
        }
      },
      {
        name: 'tesseract_search_knowledge',
        description: 'Search for keywords, topics, or tags across the Tesseract knowledge base.',
        inputSchema: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Search term or tag (e.g. "JWT", "#database", "cors workaround").'
            },
            domain: {
              type: 'string',
              description: 'Optional domain to limit search to ("auto", "global", or specific domain name). Leave blank to search all domains.'
            }
          },
          required: ['query']
        }
      },
      {
        name: 'tesseract_list_topics',
        description: 'List all knowledge topics and metadata in a domain or all domains.',
        inputSchema: {
          type: 'object',
          properties: {
            domain: {
              type: 'string',
              description: 'Domain to list ("auto", "global", or specific domain name). Defaults to "auto".'
            }
          },
          required: []
        }
      },
      {
        name: 'tesseract_get_domain_status',
        description: 'Get status of Tesseract knowledge base, detected active domain, and list of all domains.',
        inputSchema: {
          type: 'object',
          properties: {},
          required: []
        }
      },
      {
        name: 'tesseract_create_domain',
        description: 'Create a new project domain in the Tesseract knowledge vault.',
        inputSchema: {
          type: 'object',
          properties: {
            domain: {
              type: 'string',
              description: 'Name of the new domain (alphanumeric, underscores, hyphens).'
            },
            description: {
              type: 'string',
              description: 'Brief description of the domain scope and purpose.'
            }
          },
          required: ['domain']
        }
      },
      {
        name: 'tesseract_sync_project_rules',
        description: 'Synchronize project-level AI config files (AGENTS.md, CLAUDE.md, and optional GEMINI.md, .cursorrules, .windsurfrules) with safe pointer to tesseract/rule.md.',
        inputSchema: {
          type: 'object',
          properties: {
            targets: {
              type: 'array',
              items: { type: 'string' },
              description: 'AI targets to sync: "agents", "claude", "gemini", "cursor", "windsurf", or "all" (defaults to universal AGENTS.md + CLAUDE.md, while cleaning up redundant legacy pointer-only files). Defaults to ["all"].'
            },
            project_path: {
              type: 'string',
              description: 'Optional project root path. Defaults to active project working directory.'
            }
          },
          required: []
        }
      },
      {
        name: 'tesseract_hyperfold',
        description: 'Commit 4D Hyperfold results: atomically records extracted rules into rule.md, updates topic content with backlinks, and registers index.md changelog.',
        inputSchema: {
          type: 'object',
          properties: {
            topic: {
              type: 'string',
              description: 'Topic name (e.g. "auth-flow", "db-schema").'
            },
            content: {
              type: 'string',
              description: 'Optional updated Markdown content for this topic.'
            },
            rule: {
              type: 'string',
              description: 'Optional extracted engineering rule or preference to append to rule.md.'
            },
            rule_domain: {
              type: 'string',
              description: 'Domain for the rule: "auto" (current project rule.md) or "global" (_global/rule.md). Defaults to "auto".'
            },
            backlinks: {
              type: 'array',
              items: { type: 'string' },
              description: 'Optional array of backlinks to append or weave into the topic (e.g. ["[[security-spec]]"]).'
            },
            summary: {
              type: 'string',
              description: '1-sentence summary for the index.md changelog.'
            },
            tags: {
              type: 'array',
              items: { type: 'string' },
              description: 'Tags to associate with this topic.'
            },
            domain: {
              type: 'string',
              description: 'Target domain for the topic ("auto", "global", etc.). Defaults to "auto".'
            }
          },
          required: ['topic']
        }
      }
    ].freeze

    def self.handle_tool_call(store, name, arguments)
      args = arguments || {}

      case name
      when 'tesseract_read_knowledge'
        topic = args['topic'] || 'index'
        domain = args['domain'] || 'auto'
        result = store.read_topic(domain: domain, topic: topic)
        if result[:found]
          format_text(result[:content])
        else
          format_text("Error: #{result[:error]} (Path: #{result[:path]})")
        end

      when 'tesseract_save_knowledge'
        topic = args['topic']
        content = args['content']
        domain = args['domain'] || 'auto'
        summary = args['summary']
        tags = args['tags'] || []
        append = args['append'] == true || args['append'].to_s.downcase == 'true'

        raise ArgumentError, 'Topic and content are required' unless topic && content

        # Ensure summary fallback if client omitted it
        summary ||= (content.lines.find { |l| l.strip.start_with?('#') }&.sub(/^#+\s*/, '')&.strip || "Updated #{topic}")

        result = store.save_topic(
          topic: topic,
          content: content,
          domain: domain,
          summary: summary,
          tags: tags,
          append: append
        )
        format_text(result[:message])

      when 'tesseract_search_knowledge'
        query = args['query']
        domain = args['domain']
        results = store.search(query, domain: domain)

        if results.empty?
          format_text("No knowledge entries found matching '#{query}'.")
        else
          text = "### Tesseract Search Results for '#{query}' (#{results.size} matches):\n\n"
          results.each do |r|
            tag_str = r[:tags].any? ? " (#{r[:tags].join(' ')})" : ''
            text += "- **[#{r[:domain]}] [[#{r[:topic]}]]**: #{r[:title]}#{tag_str}\n"
            text += "  > #{r[:snippet]}\n\n"
          end
          format_text(text)
        end

      when 'tesseract_list_topics'
        domain = args['domain'] || 'auto'
        topics = store.list_topics(domain: domain)
        active_domain = store.resolve_domain_dir(domain).basename.to_s
        active_domain = 'global' if store.resolve_domain_dir(domain) == store.domains_root

        if topics.empty?
          format_text("Domain '#{active_domain}' has no knowledge topics yet (only index.md).")
        else
          text = "### Knowledge Topics in Domain '#{active_domain}' (#{topics.size} topics):\n\n"
          topics.each do |t|
            tag_str = t[:tags].any? ? " #{t[:tags].join(' ')}" : ''
            text += "- **[[#{t[:topic]}]]** — #{t[:title]}#{tag_str} *(Updated: #{t[:updated_at]})*\n"
          end
          format_text(text)
        end

      when 'tesseract_get_domain_status'
        domains = store.list_domains
        current = store.current_domain_name
        text = <<~STATUS
          ### Tesseract Knowledge Base Status
          - **Vault Root**: `#{store.domains_root}`
          - **Working Directory**: `#{store.cwd}`
          - **Detected Active Domain**: `#{current}`
          - **Total Domains**: #{domains.size} (#{domains.join(', ')})
        STATUS
        format_text(text)

      when 'tesseract_create_domain'
        domain = args['domain']
        desc = args['description'] || 'Project knowledge domain'
        res = store.create_domain(domain, description: desc)
        format_text(res[:message])

      when 'tesseract_sync_project_rules'
        targets = args['targets'] || ['all']
        project_path = args['project_path']
        res = sync_project_rules(store, targets: targets, project_path: project_path)
        format_text(res[:message])

      when 'tesseract_hyperfold'
        topic = args['topic']
        content = args['content']
        rule = args['rule']
        rule_domain = args['rule_domain'] || 'auto'
        backlinks = args['backlinks'] || []
        domain = args['domain'] || 'auto'
        summary = args['summary'] || 'Hyperfold review and reinforcement'
        tags = args['tags'] || []

        reports = []

        # 1. Append rule if provided
        if rule && !rule.strip.empty?
          rule_res = store.append_rule(rule, domain: rule_domain)
          if rule_res[:success]
            dup_msg = rule_res[:duplicate] ? ' (already existed)' : ''
            reports << "✦ Rule committed to #{File.basename(rule_res[:path])}#{dup_msg}: \"#{rule_res[:rule]}\""
          else
            reports << "⚠ Failed to commit rule: #{rule_res[:error]}"
          end
        end

        # 2. Update content if provided
        if content && !content.strip.empty?
          if backlinks.any?
            missing_links = backlinks.reject { |link| content.include?(link) }
            if missing_links.any?
              content = "#{content.rstrip}\n\n## 維度關聯 (Hyperfold Backlinks)\n#{missing_links.map { |l| "- #{l}" }.join("\n")}\n"
            end
          end

          save_res = store.save_topic(
            topic: topic,
            content: content,
            domain: domain,
            summary: summary,
            tags: tags
          )
          reports << "✦ Topic updated: #{save_res[:message]}"
        end

        reports << "✦ Hyperfold complete for topic [[#{topic}]]." if reports.empty?
        format_text("### ⬡ Tesseract Hyperfold Applied\n\n#{reports.join("\n")}")

      else
        raise ArgumentError, "Unknown tool: #{name}"
      end
    rescue StandardError => e
      format_text("Tesseract Tool Error: #{e.message}")
    end

    AI_TARGET_FILES = {
      'agents' => 'AGENTS.md',
      'claude' => 'CLAUDE.md',
      'gemini' => 'GEMINI.md',
      'cursor' => '.cursorrules',
      'windsurf' => '.windsurfrules'
    }.freeze

    DEFAULT_PRIMARY_TARGETS = %w[agents].freeze

    def self.sync_project_rules(store, targets: ['all'], project_path: nil)
      proj_path = Pathname.new(project_path || store.cwd)
      proj_store = project_path ? Store.new(domains_root: store.domains_root, cwd: proj_path) : store

      # Ensure the active domain has rule.md
      domain_dir = proj_store.resolve_domain_dir('auto')
      domain_name = (domain_dir == proj_store.global_dir) ? '_global' : domain_dir.basename.to_s
      proj_store.ensure_rule_file(domain_dir, domain_name) if proj_store.respond_to?(:ensure_rule_file)

      target_domain = (domain_name == '_global') ? 'global' : domain_name
      rule_rel_path = 'tesseract/rule.md'
      marker_start = '<!-- tesseract-rule-start -->'
      marker_end = '<!-- tesseract-rule-end -->'
      snippet = <<~MARKDOWN.strip
        #{marker_start}
        ## Tesseract 專案知識庫與即時沉澱規範
        本專案與個人的 Tesseract 知識庫連動（專屬 Domain：`#{target_domain}`），請遵循以下規範：
        1. **任務開始前**：若涉及架構決策或專案規範，先閱讀 `#{rule_rel_path}` 或呼叫 `tesseract_read_knowledge(topic: "rule", domain: "#{target_domain}")`（或終端執行 `tesseract read rule -d #{target_domain}`）。
        2. **結案前主動知識沉澱 (Proactive Knowledge Retention)**：
           每次完成實質任務或除錯後，在回覆使用者前**必須自我檢查**：
           - 是否解決了未記錄的重大 Bug、相依性衝突或踩坑解法？ ➔ 立即記錄至 `troubleshooting` 主題（請傳入 `append: true` 或先讀取既有內容再追加，避免覆蓋歷史紀錄）
           - 是否確立了重要架構決策或技術約定？ ➔ 立即記錄至 `adr-<name>` 主題
           - 記錄應側重於「為什麼這樣做 (Why)」，而非只是陳列程式碼。
        3. **雙軌通道與透明審查原則 (Dual-Channel & Transparency)**：
           - **本地優先 (MCP)**：呼叫 `tesseract_save_knowledge`（**務必明確傳入 `domain: "#{target_domain}"`**，避免省略時因 GUI 宿主工作目錄不同而誤寫入 `_global`；僅跨專案通用規範才存至 `"global"`）。呼叫前先在對話中簡述內容，並提供具體 `summary` 供審批確認。
           - **行動端 / 遠端 Fallback (CLI or File)**：若處於無法呼叫 local MCP 的環境（例如手機版 Gemini Spark 操作），改由終端執行純 Ruby CLI：
             `tesseract save <topic> -d #{target_domain} -s "摘要" -c "Markdown 內容"`
             或直接編輯專案內的 `tesseract/<topic>.md` 與 `tesseract/index.md`，確保知識沉澱不中斷。
        #{marker_end}
      MARKDOWN

      raw_targets = Array(targets).flatten.map(&:to_s).map(&:downcase)
      default_mode = raw_targets.empty? || raw_targets.include?('all')

      selected = if default_mode
                   DEFAULT_PRIMARY_TARGETS
                 else
                   raw_targets & AI_TARGET_FILES.keys
                 end

      synced = []
      migrated_blocks = []

      # In default mode, inspect existing legacy/tool-specific files (CLAUDE.md, GEMINI.md, .cursorrules, .windsurfrules):
      # - Extract any custom user instructions outside the marker block to migrate into AGENTS.md
      # - Remove the legacy files so the project root stays clean with only AGENTS.md
      if default_mode
        (AI_TARGET_FILES.keys - DEFAULT_PRIMARY_TARGETS).each do |key|
          filename = AI_TARGET_FILES[key]
          file_path = proj_path.join(filename)
          next unless file_path.file?

          content = file_path.read(encoding: 'UTF-8')
          remaining = content.sub(/#{Regexp.escape(marker_start)}.*?#{Regexp.escape(marker_end)}/m, '').strip
          file_path.unlink
          if remaining.empty?
            synced << "#{filename} (removed redundant file; superseded by AGENTS.md)"
          else
            migrated_blocks << remaining
            synced << "#{filename} (migrated custom rules to AGENTS.md and removed)"
          end
        end
      end

      selected.each do |key|
        filename = AI_TARGET_FILES[key]
        file_path = proj_path.join(filename)

        if file_path.file?
          content = file_path.read(encoding: 'UTF-8')
          if key == 'agents' && migrated_blocks.any?
            extra = migrated_blocks.reject { |b| content.include?(b) }.join("\n\n")
            content = "#{extra}\n\n#{content}" unless extra.empty?
          end
          new_content = if content.include?(marker_start) && content.include?(marker_end)
                          content.sub(/#{Regexp.escape(marker_start)}.*?#{Regexp.escape(marker_end)}/m, snippet)
                        else
                          "#{content.rstrip}\n\n#{snippet}\n"
                        end
          file_path.write(new_content, encoding: 'UTF-8')
          synced << "#{filename} (updated)"
        else
          prefix = (key == 'agents' && migrated_blocks.any?) ? "#{migrated_blocks.join("\n\n")}\n\n" : ''
          file_path.write("#{prefix}#{snippet}\n", encoding: 'UTF-8')
          synced << "#{filename} (created)"
        end
      end

      {
        success: true,
        project_path: proj_path.to_s,
        synced: synced,
        message: "Successfully synchronized Tesseract rule pointers in #{proj_path}:\n" + synced.map { |s| "  - #{s}" }.join("\n")
      }
    end

    def self.format_text(text)
      {
        content: [
          {
            type: 'text',
            text: text.to_s
          }
        ]
      }
    end
  end
end
