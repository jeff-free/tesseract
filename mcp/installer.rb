# frozen_string_literal: true

require 'json'
require 'pathname'
require 'fileutils'

module Tesseract
  class MCPInstaller
    attr_reader :mcp_bin

    def initialize(mcp_bin = nil)
      @mcp_bin = mcp_bin || File.expand_path('../bin/tesseract-mcp', __dir__)
    end

    # Auto-detects and installs MCP config into all found AI tool configuration files
    def install_all(_store = nil)
      results = []
      results << install_claude_code
      results << install_antigravity
      results << install_claude_desktop
      results << install_cursor
      results.compact
    end

    # Installs and symlinks Tesseract skills from iCloud Vault into AI agents
    def install_skills(store)
      return [] unless store

      store.ensure_default_skills!
      results = []

      # 1. Google Antigravity / Gemini Skills (~/.gemini/config/skills/)
      gemini_root = Pathname.new(File.expand_path('~/.gemini/config'))
      if File.exist?(File.expand_path('~/.gemini'))
        skills_dir = gemini_root.join('skills')
        FileUtils.mkdir_p(skills_dir)

        store.list_skills.each do |skill|
          target = skills_dir.join(skill[:name])
          source_dir = Pathname.new(skill[:path]).parent

          target.unlink if target.symlink? || target.file?

          next if target.exist?

          begin
            File.symlink(source_dir.to_s, target.to_s)
            results << { target: 'Google Antigravity / Gemini', skill: skill[:name], path: target.to_s,
                         success: true }
          rescue StandardError => e
            results << { target: 'Google Antigravity / Gemini', skill: skill[:name], error: e.message,
                         success: false }
          end
        end
      end

      # 2. Claude Code Global Skills (~/.claude/skills/)
      claude_root = Pathname.new(File.expand_path('~/.claude'))
      if claude_root.exist?
        skills_dir = claude_root.join('skills')
        FileUtils.mkdir_p(skills_dir)

        store.list_skills.each do |skill|
          target = skills_dir.join(skill[:name])
          source_dir = Pathname.new(skill[:path]).parent

          target.unlink if target.symlink? || target.file?

          next if target.exist?

          begin
            File.symlink(source_dir.to_s, target.to_s)
            results << { target: 'Claude Code', skill: skill[:name], path: target.to_s, success: true }
          rescue StandardError => e
            results << { target: 'Claude Code', skill: skill[:name], error: e.message, success: false }
          end
        end
      end

      results
    end

    # Checks registration status across all AI tools
    def check_status
      [
        check_claude_code,
        check_antigravity,
        check_claude_desktop,
        check_cursor
      ].compact
    end

    def check_claude_code
      path = Pathname.new(File.expand_path('~/.claude.json'))
      return { name: 'Claude Code', path: path.to_s, installed: false, detected: false } unless path.file?

      data = begin
        JSON.parse(path.read(encoding: 'UTF-8'))
      rescue StandardError
        {}
      end
      installed = !data.dig('mcpServers', 'tesseract').nil?
      {
        name: 'Claude Code',
        path: path.to_s,
        installed: installed,
        detected: true,
        command: data.dig('mcpServers', 'tesseract', 'command')
      }
    rescue StandardError => e
      { name: 'Claude Code', path: path.to_s, installed: false, detected: true, error: e.message }
    end

    def check_antigravity
      path = Pathname.new(File.expand_path('~/.gemini/antigravity-ide/mcp_config.json'))
      alt_path = Pathname.new(File.expand_path('~/.gemini/config/mcp_config.json'))
      target = path.file? ? path : alt_path

      unless target.file? || target.parent.directory?
        return { name: 'Google Antigravity / Gemini', path: path.to_s, installed: false,
                 detected: false }
      end

      content = target.file? ? target.read(encoding: 'UTF-8').strip : ''
      data = if content.empty?
               {}
             else
               begin
                 JSON.parse(content)
               rescue StandardError
                 {}
               end
             end
      installed = !data.dig('mcpServers', 'tesseract').nil?
      {
        name: 'Google Antigravity / Gemini',
        path: target.to_s,
        installed: installed,
        detected: true,
        command: data.dig('mcpServers', 'tesseract', 'command')
      }
    rescue StandardError => e
      { name: 'Google Antigravity / Gemini', path: target.to_s, installed: false, detected: true, error: e.message }
    end

    def check_claude_desktop
      dir = Pathname.new(File.expand_path('~/Library/Application Support/Claude'))
      path = dir.join('claude_desktop_config.json')
      return { name: 'Claude Desktop', path: path.to_s, installed: false, detected: false } unless dir.directory?

      content = path.file? ? path.read(encoding: 'UTF-8').strip : ''
      data = if content.empty?
               {}
             else
               begin
                 JSON.parse(content)
               rescue StandardError
                 {}
               end
             end
      installed = !data.dig('mcpServers', 'tesseract').nil?
      {
        name: 'Claude Desktop',
        path: path.to_s,
        installed: installed,
        detected: true,
        command: data.dig('mcpServers', 'tesseract', 'command')
      }
    rescue StandardError => e
      { name: 'Claude Desktop', path: path.to_s, installed: false, detected: true, error: e.message }
    end

    def check_cursor
      dir = Pathname.new(File.expand_path('~/.cursor'))
      path = dir.join('mcp.json')
      return { name: 'Cursor', path: path.to_s, installed: false, detected: false } unless dir.directory?

      content = path.file? ? path.read(encoding: 'UTF-8').strip : ''
      data = if content.empty?
               {}
             else
               begin
                 JSON.parse(content)
               rescue StandardError
                 {}
               end
             end
      installed = !data.dig('mcpServers', 'tesseract').nil?
      {
        name: 'Cursor',
        path: path.to_s,
        installed: installed,
        detected: true,
        command: data.dig('mcpServers', 'tesseract', 'command')
      }
    rescue StandardError => e
      { name: 'Cursor', path: path.to_s, installed: false, detected: true, error: e.message }
    end

    def install_claude_code
      path = Pathname.new(File.expand_path('~/.claude.json'))
      data = if path.file?
               begin
                 JSON.parse(path.read(encoding: 'UTF-8'))
               rescue StandardError
                 {}
               end
             else
               {}
             end

      data['mcpServers'] ||= {}
      data['mcpServers']['tesseract'] = { 'command' => @mcp_bin }
      path.write(JSON.pretty_generate(data), encoding: 'UTF-8')

      { name: 'Claude Code', path: path.to_s, success: true }
    rescue StandardError => e
      { name: 'Claude Code', error: e.message, success: false }
    end

    def install_antigravity
      candidates = [
        Pathname.new(File.expand_path('~/.gemini/antigravity-ide/mcp_config.json')),
        Pathname.new(File.expand_path('~/.gemini/config/mcp_config.json'))
      ]

      installed_paths = []
      candidates.each do |path|
        next unless path.parent.parent.directory? || path.parent.directory? || path.file?

        FileUtils.mkdir_p(path.parent)
        data = if path.file?
                 begin
                   content = path.read(encoding: 'UTF-8').strip
                   content.empty? ? {} : JSON.parse(content)
                 rescue StandardError
                   {}
                 end
               else
                 {}
               end

        data['mcpServers'] ||= {}
        data['mcpServers']['tesseract'] = { 'command' => @mcp_bin }
        path.write(JSON.pretty_generate(data), encoding: 'UTF-8')
        installed_paths << path.to_s
      end

      { name: 'Google Antigravity / Gemini', path: installed_paths.first, success: true } if installed_paths.any?
    rescue StandardError => e
      { name: 'Google Antigravity / Gemini', error: e.message, success: false }
    end

    def install_claude_desktop
      dir = Pathname.new(File.expand_path('~/Library/Application Support/Claude'))
      return nil unless dir.directory?

      path = dir.join('claude_desktop_config.json')
      data = if path.file?
               begin
                 content = path.read(encoding: 'UTF-8').strip
                 content.empty? ? {} : JSON.parse(content)
               rescue StandardError
                 {}
               end
             else
               {}
             end

      data['mcpServers'] ||= {}
      data['mcpServers']['tesseract'] = { 'command' => @mcp_bin }
      path.write(JSON.pretty_generate(data), encoding: 'UTF-8')

      { name: 'Claude Desktop', path: path.to_s, success: true }
    rescue StandardError => e
      { name: 'Claude Desktop', error: e.message, success: false }
    end

    def install_cursor
      dir = Pathname.new(File.expand_path('~/.cursor'))
      return nil unless dir.directory?

      path = dir.join('mcp.json')
      data = if path.file?
               begin
                 content = path.read(encoding: 'UTF-8').strip
                 content.empty? ? {} : JSON.parse(content)
               rescue StandardError
                 {}
               end
             else
               {}
             end

      data['mcpServers'] ||= {}
      data['mcpServers']['tesseract'] = { 'command' => @mcp_bin }
      path.write(JSON.pretty_generate(data), encoding: 'UTF-8')

      { name: 'Cursor', path: path.to_s, success: true }
    rescue StandardError => e
      { name: 'Cursor', error: e.message, success: false }
    end
  end
end
