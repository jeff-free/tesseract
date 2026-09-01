# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'pathname'
require 'date'

module Tesseract
  class Store
    DEFAULT_ICLOUD_PATH = File.expand_path(
      '~/Library/Mobile Documents/com~apple~CloudDocs/Tesseract'
    ).freeze
    GLOBAL_DIR_NAME = '_global'

    attr_reader :domains_root, :cwd

    def initialize(domains_root: nil, cwd: Dir.pwd)
      @domains_root = Pathname.new(
        domains_root || ENV['TESSERACT_DOMAINS'] || DEFAULT_ICLOUD_PATH
      )
      @cwd = Pathname.new(cwd)
      ensure_root_exists!
    end

    def global_dir
      @domains_root.join(GLOBAL_DIR_NAME)
    end

    def ensure_root_exists!
      FileUtils.mkdir_p(global_dir.join('assets'))
      ensure_index_file(global_dir, '_global', 'Global personal knowledge base, general architecture decisions, and cross-project preferences')
    end

    # Resolves domain name: "global" / "_global" -> _global folder, "auto" -> based on cwd, other -> subfolder
    def resolve_domain_dir(domain = 'auto')
      domain_str = domain.to_s.strip.downcase
      if domain_str == 'global' || domain_str == '_global' || domain_str == '.' || domain_str.empty?
        global_dir
      elsif domain_str == 'auto'
        detected = detect_domain_from_cwd
        detected ? @domains_root.join(detected) : global_dir
      else
        @domains_root.join(domain_str)
      end
    end

    def detect_domain_from_cwd
      # Check if current directory has a tesseract symlink
      symlink_path = @cwd.join('tesseract')
      if symlink_path.symlink?
        target = symlink_path.readlink.expand_path(@cwd)
        if target.to_s.start_with?(@domains_root.to_s)
          rel = target.relative_path_from(@domains_root).to_s
          return rel unless rel == '.' || rel.empty?
        end
      end

      # Check if cwd basename matches a domain folder in domains_root
      project_name = @cwd.basename.to_s
      domain_candidate = @domains_root.join(project_name)
      return project_name if domain_candidate.directory? && project_name != GLOBAL_DIR_NAME

      nil
    end

    def current_domain_name
      detected = detect_domain_from_cwd
      detected || '_global'
    end

    def list_domains
      domains = [GLOBAL_DIR_NAME]
      return domains unless @domains_root.exist?

      @domains_root.children.select(&:directory?).each do |dir|
        name = dir.basename.to_s
        next if name.start_with?('.') || name == 'assets' || name == GLOBAL_DIR_NAME

        domains << name
      end
      domains.sort
    end

    def list_topics(domain: 'auto')
      domain_dir = resolve_domain_dir(domain)
      return [] unless domain_dir.exist?

      topics = []
      domain_name = (domain_dir == global_dir) ? '_global' : domain_dir.basename.to_s

      domain_dir.children.select { |f| f.file? && f.extname == '.md' }.sort.each do |file|
        topic_name = file.basename('.md').to_s
        next if topic_name == 'index'

        title, tags = extract_title_and_tags(file)
        topics << {
          domain: domain_name,
          topic: topic_name,
          title: title,
          tags: tags,
          path: file.to_s,
          updated_at: file.mtime.strftime('%Y-%m-%d %H:%M')
        }
      end
      topics
    end

    def read_topic(domain: 'auto', topic: 'index')
      domain_dir = resolve_domain_dir(domain)
      clean_topic = topic.to_s.sub(/\.md$/, '')
      file_path = domain_dir.join("#{clean_topic}.md")

      unless file_path.exist?
        return {
          error: "Topic '#{clean_topic}' not found in domain '#{domain_dir.basename}'",
          found: false,
          path: file_path.to_s
        }
      end

      {
        domain: (domain_dir == global_dir) ? '_global' : domain_dir.basename.to_s,
        topic: clean_topic,
        content: file_path.read(encoding: 'UTF-8'),
        found: true,
        path: file_path.to_s
      }
    end

    def save_topic(topic:, content:, domain: 'auto', summary: nil, tags: [])
      domain_dir = resolve_domain_dir(domain)
      FileUtils.mkdir_p(domain_dir) unless domain_dir.exist?

      clean_topic = topic.to_s.sub(/\.md$/, '').strip
      raise ArgumentError, "Topic name cannot be 'index' or empty" if clean_topic.empty? || clean_topic == 'index'

      file_path = domain_dir.join("#{clean_topic}.md")
      is_new = !file_path.exist?

      # Format tags
      formatted_tags = Array(tags).map { |t| t.start_with?('#') ? t : "##{t}" }.uniq

      # Process content to ensure proper title and tags
      final_content = format_topic_content(clean_topic, content, formatted_tags)
      file_path.write(final_content, encoding: 'UTF-8')

      # Ensure index.md exists and is updated
      domain_name = (domain_dir == global_dir) ? '_global' : domain_dir.basename.to_s
      ensure_index_file(domain_dir, domain_name)
      update_index_files_section(domain_dir)

      # Append Changelog entry
      today = Date.today.strftime('%Y-%m-%d')
      log_desc = summary || (is_new ? "Created #{clean_topic}" : "Updated #{clean_topic}")
      append_changelog(domain_dir, "- #{today}: #{log_desc} (AI)")

      {
        success: true,
        domain: domain_name,
        topic: clean_topic,
        is_new: is_new,
        path: file_path.to_s,
        message: "Successfully saved '#{clean_topic}' to #{domain_name} domain and updated index.md"
      }
    end

    def search(query, domain: nil)
      q = query.to_s.downcase.strip
      return [] if q.empty?

      target_dirs = if domain
                      [resolve_domain_dir(domain)]
                    else
                      @domains_root.children.select(&:directory?)
                    end

      results = []

      target_dirs.each do |dir|
        next unless dir.exist?

        dom_name = (dir == global_dir) ? '_global' : dir.basename.to_s

        dir.children.select { |f| f.file? && f.extname == '.md' }.each do |file|
          topic_name = file.basename('.md').to_s
          next if topic_name == 'index'

          content = file.read(encoding: 'UTF-8')

          # Match topic name, title, tags, or content body
          title, tags = extract_title_and_tags(file)
          match_topic = topic_name.downcase.include?(q)
          match_title = title.downcase.include?(q)
          match_tags = tags.any? { |t| t.downcase.include?(q) }
          match_content = content.downcase.include?(q)

          if match_topic || match_title || match_tags || match_content
            snippet = extract_snippet(content, q)
            results << {
              domain: dom_name,
              topic: topic_name,
              title: title,
              tags: tags,
              path: file.to_s,
              snippet: snippet
            }
          end
        end
      end

      results
    end

    def create_domain(domain_name, description: 'Project knowledge domain')
      clean_name = domain_name.to_s.strip
      raise ArgumentError, 'Domain name contains invalid characters' unless clean_name.match?(/\A[a-zA-Z0-9_-]+\z/)

      domain_dir = @domains_root.join(clean_name)
      if domain_dir.exist?
        return { success: false, message: "Domain '#{clean_name}' already exists at #{domain_dir}" }
      end

      FileUtils.mkdir_p(domain_dir.join('assets'))
      ensure_index_file(domain_dir, clean_name, description)

      {
        success: true,
        domain: clean_name,
        path: domain_dir.to_s,
        message: "Successfully created domain '#{clean_name}'"
      }
    end

    def reindex_all
      reindexed = []
      @domains_root.children.select(&:directory?).each do |dir|
        next unless dir.exist? && dir.join('index.md').exist?

        update_index_files_section(dir)
        reindexed << ((dir == global_dir) ? '_global' : dir.basename.to_s)
      end
      reindexed
    end

    private

    def extract_title_and_tags(file_or_content)
      content = file_or_content.is_a?(Pathname) ? file_or_content.read(encoding: 'UTF-8') : file_or_content.to_s
      lines = content.lines

      title = lines.find { |l| l.start_with?('# ') }&.sub(/^#\s*/, '')&.strip || (file_or_content.is_a?(Pathname) ? file_or_content.basename('.md').to_s : 'Untitled')
      tags = []
      lines.each do |l|
        tags += l.scan(/#[a-zA-Z0-9_\-\/]+/)
      end

      [title, tags.uniq]
    end

    def extract_snippet(content, query)
      lines = content.lines
      matching_line = lines.find { |l| l.downcase.include?(query) }
      if matching_line
        matching_line.strip[0..150]
      else
        lines.first(3).map(&:strip).reject(&:empty?).join(' ')[0..150]
      end
    end

    def format_topic_content(topic, content, tags)
      lines = content.strip.lines
      has_h1 = lines.any? { |l| l.start_with?('# ') }

      res = []
      res << "# #{topic.capitalize.tr('-', ' ')}\n\n" unless has_h1

      lines.each { |l| res << l }

      # If tags provided and not yet in content, add them near the top
      if tags.any? && !lines.join.include?(tags.first)
        idx = res.find_index { |l| l.start_with?('# ') }
        if idx
          res.insert(idx + 1, "\n#{tags.join(' ')}\n")
        else
          res.unshift("#{tags.join(' ')}\n\n")
        end
      end

      res.join
    end

    def ensure_index_file(domain_dir, domain_name, description = 'Knowledge domain')
      index_file = domain_dir.join('index.md')
      return if index_file.exist?

      today = Date.today.strftime('%Y-%m-%d')
      content = <<~MARKDOWN
        # #{domain_name}

        ## Context
        #{description}

        ## Files
        （尚無知識檔案）

        ## Changelog
        - #{today}: Domain initialized
      MARKDOWN

      index_file.write(content, encoding: 'UTF-8')
    end

    def update_index_files_section(domain_dir)
      index_file = domain_dir.join('index.md')
      return unless index_file.exist?

      # Collect all markdown files
      md_files = domain_dir.children.select { |f| f.file? && f.extname == '.md' && f.basename.to_s != 'index.md' }.sort

      files_block = if md_files.empty?
                      "（尚無知識檔案）\n"
                    else
                      md_files.map do |file|
                        topic_name = file.basename('.md').to_s
                        title, tags = extract_title_and_tags(file)
                        tag_str = tags.any? ? " #{tags.join(' ')}" : ''
                        "- [[#{topic_name}]] — #{title}#{tag_str}"
                      end.join("\n") + "\n"
                    end

      content = index_file.read(encoding: 'UTF-8')

      # Replace ## Files section
      new_content = content.sub(/## Files\n.*?(?=\n## |\Z)/m, "## Files\n#{files_block}")
      # If replacement did not happen (section missing), append it
      unless new_content.include?('## Files')
        new_content += "\n## Files\n#{files_block}"
      end

      index_file.write(new_content, encoding: 'UTF-8')
    end

    def append_changelog(domain_dir, entry)
      index_file = domain_dir.join('index.md')
      return unless index_file.exist?

      content = index_file.read(encoding: 'UTF-8')
      if content.include?('## Changelog')
        new_content = content.rstrip + "\n#{entry}\n"
        index_file.write(new_content, encoding: 'UTF-8')
      else
        new_content = "#{content.rstrip}\n\n## Changelog\n#{entry}\n"
        index_file.write(new_content, encoding: 'UTF-8')
      end
    end
  end
end
