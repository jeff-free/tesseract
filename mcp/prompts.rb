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
         - `index.md` and `## Changelog` are automatically maintained by Tesseract MCP tools.
    MARKDOWN

    PROMPTS_LIST = [
      {
        name: 'tesseract_instructions',
        description: 'Core behavior guidelines and principles for interacting with the Tesseract personal knowledge base.',
        arguments: []
      }
    ].freeze

    def self.get_prompt(name, _arguments = {})
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
      else
        nil
      end
    end
  end
end
