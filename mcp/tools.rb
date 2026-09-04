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
              description: 'Topic name to read (e.g. "index", "database-schema", "auth-flow"). Default is "index".'
            },
            domain: {
              type: 'string',
              description: 'Domain name ("auto" for current project context, "global" for root vault, or a specific domain name). Defaults to "auto".'
            }
          },
          required: []
        }
      },
      {
        name: 'tesseract_save_knowledge',
        description: 'Save or update a knowledge topic in Tesseract. Automatically updates index.md and changelog.',
        inputSchema: {
          type: 'object',
          properties: {
            topic: {
              type: 'string',
              description: 'Topic name (without .md extension, e.g. "api-design", "state-management").'
            },
            content: {
              type: 'string',
              description: 'The Markdown content to save for this topic.'
            },
            summary: {
              type: 'string',
              description: 'Short 1-sentence summary of the decision or insight for index.md Changelog.'
            },
            tags: {
              type: 'array',
              items: { type: 'string' },
              description: 'Optional tags to associate with this topic (e.g. ["#auth", "#security"]).'
            },
            domain: {
              type: 'string',
              description: 'Target domain ("auto" for current project, "global" for root vault, or specific domain name). Defaults to "auto".'
            }
          },
          required: %w[topic content]
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
        description: 'Synchronize project-level AI config files (CLAUDE.md, .cursorrules, GEMINI.md, .windsurfrules) with safe pointer to tesseract/rule.md.',
        inputSchema: {
          type: 'object',
          properties: {
            targets: {
              type: 'array',
              items: { type: 'string' },
              description: 'AI targets to sync: "claude", "cursor", "gemini", "windsurf", or "all". Defaults to ["all"].'
            },
            project_path: {
              type: 'string',
              description: 'Optional project root path. Defaults to active project working directory.'
            }
          },
          required: []
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

        raise ArgumentError, 'Topic and content are required' unless topic && content

        result = store.save_topic(
          topic: topic,
          content: content,
          domain: domain,
          summary: summary,
          tags: tags
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

      else
        raise ArgumentError, "Unknown tool: #{name}"
      end
    rescue StandardError => e
      format_text("Tesseract Tool Error: #{e.message}")
    end

    AI_TARGET_FILES = {
      'claude' => 'CLAUDE.md',
      'cursor' => '.cursorrules',
      'gemini' => 'GEMINI.md',
      'windsurf' => '.windsurfrules'
    }.freeze

    def self.sync_project_rules(store, targets: ['all'], project_path: nil)
      proj_path = Pathname.new(project_path || store.cwd)

      # Ensure the active domain has rule.md
      domain_dir = store.resolve_domain_dir('auto')
      domain_name = (domain_dir == store.global_dir) ? '_global' : domain_dir.basename.to_s
      store.ensure_rule_file(domain_dir, domain_name) if store.respond_to?(:ensure_rule_file)

      rule_rel_path = 'tesseract/rule.md'
      marker_start = '<!-- tesseract-rule-start -->'
      marker_end = '<!-- tesseract-rule-end -->'
      snippet = <<~MARKDOWN.strip
        #{marker_start}
        ## Tesseract 專案知識庫與自訂規範
        請遵守本專案 `#{rule_rel_path}` 中定義的知識庫筆記方式與開發規範。
        在處理任務前，可先閱讀 `#{rule_rel_path}` 或呼叫 `tesseract_read_knowledge(topic: "rule")`。
        #{marker_end}
      MARKDOWN

      raw_targets = Array(targets).flatten.map(&:to_s).map(&:downcase)
      selected = if raw_targets.empty? || raw_targets.include?('all')
                   AI_TARGET_FILES.keys
                 else
                   raw_targets & AI_TARGET_FILES.keys
                 end

      synced = []
      selected.each do |key|
        filename = AI_TARGET_FILES[key]
        file_path = proj_path.join(filename)

        if file_path.file?
          content = file_path.read(encoding: 'UTF-8')
          new_content = if content.include?(marker_start) && content.include?(marker_end)
                          content.sub(/#{Regexp.escape(marker_start)}.*?#{Regexp.escape(marker_end)}/m, snippet)
                        else
                          "#{content.rstrip}\n\n#{snippet}\n"
                        end
          file_path.write(new_content, encoding: 'UTF-8')
          synced << "#{filename} (updated)"
        else
          file_path.write("#{snippet}\n", encoding: 'UTF-8')
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
