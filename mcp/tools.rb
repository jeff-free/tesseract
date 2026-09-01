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

      else
        raise ArgumentError, "Unknown tool: #{name}"
      end
    rescue StandardError => e
      format_text("Tesseract Tool Error: #{e.message}")
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
