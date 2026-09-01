# frozen_string_literal: true

require_relative 'store'
require_relative 'server'
require 'pathname'
require 'fileutils'

module Tesseract
  class CLI
    def initialize(argv = ARGV, cwd = Dir.pwd)
      @argv = argv
      @cwd = Pathname.new(cwd)
      @store = Store.new(cwd: @cwd)
    end

    def run
      command = @argv.first || 'help'
      args = @argv[1..] || []

      case command
      when 'new'
        cmd_new(args)
      when 'link'
        cmd_link(args)
      when 'new-domain'
        cmd_new_domain(args)
      when 'status'
        cmd_status
      when 'reindex'
        cmd_reindex
      when 'init'
        cmd_init(args)
      when 'mcp-config', 'config'
        cmd_mcp_config
      when 'mcp'
        cmd_mcp(args)
      when 'help', '--help', '-h'
        cmd_help
      else
        $stderr.puts "錯誤：不認識的指令 '#{command}'\n\n"
        cmd_help
        exit 1
      end
    end

    private

    def cmd_new(args)
      if args.empty?
        $stderr.puts '用法: tesseract new <專案名稱> [專案路徑]'
        $stderr.puts '範例: tesseract new honeymoon'
        exit 1
      end

      project_name = args[0]
      raw_path = args[1] || @cwd.join(project_name).to_s
      project_path = Pathname.new(File.expand_path(raw_path))

      puts "=== 建立新專案：#{project_name} ==="
      puts ''

      # 1. 建立專案資料夾
      if project_path.directory?
        puts "✓ 專案資料夾已存在：#{project_path}"
      else
        FileUtils.mkdir_p(project_path)
        puts "✓ 專案資料夾已建立：#{project_path}"
      end

      # 2. 建立 iCloud domain
      domain_dir = @store.domains_root.join(project_name)
      if domain_dir.directory?
        puts "✓ 知識 domain 已存在：#{domain_dir}"
      else
        @store.create_domain(project_name, description: "#{project_name} 專案知識庫")
        puts "✓ 已建立 iCloud domain：#{domain_dir}"
      end

      # 3. 建立 symlink & gitignore
      link_project_dir(project_path, domain_dir, project_name)

      puts ''
      puts '=== 完成 ==='
      puts "  專案資料夾：#{project_path}"
      puts "  知識庫（iCloud）：#{domain_dir}"
      puts "  IDE 捷徑：#{project_path.join('tesseract')} (已自動加入 .gitignore)"
      puts ''
      puts "在 IDE 中開啟 #{project_path} 即可開始，AI 透過 MCP 自動存取知識庫。"
      puts ''
    end

    def cmd_link(args)
      project_path = @cwd
      domain_name = nil

      if args.size >= 2
        project_path = Pathname.new(File.expand_path(args[0]))
        domain_name = args[1]
      elsif args.size == 1
        target = args[0]
        if File.directory?(File.expand_path(target))
          project_path = Pathname.new(File.expand_path(target))
          domain_name = project_path.basename.to_s
        else
          project_path = @cwd
          domain_name = target
        end
      else
        project_path = @cwd
        domain_name = project_path.basename.to_s
      end

      domain_dir = @store.domains_root.join(domain_name)

      puts '=== 連結專案到 Tesseract 知識庫 ==='
      puts "  專案路徑：#{project_path}"
      puts "  知識 Domain：#{domain_name}"
      puts ''

      # 自動建立不存在的 domain
      unless domain_dir.directory?
        puts "ℹ 知識 domain '#{domain_name}' 尚不存在於 iCloud，正在自動為您建立..."
        @store.create_domain(domain_name, description: "#{domain_name} 專案知識庫")
        puts "✓ 已建立 iCloud domain：#{domain_dir}"
      end

      link_project_dir(project_path, domain_dir, domain_name)

      puts ''
      puts '=== 連結完成 ==='
      puts "  • IDE 檔案樹：#{project_path.join('tesseract')} (已可直接查看/編輯)"
      puts "  • 雲端實體：#{domain_dir}"
      puts '  • AI MCP：已自動就緒'
      puts ''
    end

    def link_project_dir(project_path, domain_dir, domain_name)
      link_path = project_path.join('tesseract')

      if link_path.symlink?
        existing = link_path.readlink.expand_path(project_path)
        if existing == domain_dir
          puts "✓ Symlink 已存在且正確：#{link_path} → #{domain_dir}"
        else
          puts "警告：#{link_path} 目前指向 #{existing}"
          print "是否重新導向至 #{domain_dir}？[Y/n] "
          answer = $stdin.gets.strip
          answer = 'Y' if answer.empty?
          if answer.match?(/^[Yy]$/)
            link_path.unlink
            File.symlink(domain_dir.to_s, link_path.to_s)
            puts "✓ Symlink 已更新：#{link_path} → #{domain_dir}"
          else
            puts '保留原連結，結束。'
            return
          end
        end
      elsif link_path.exist?
        $stderr.puts "錯誤：#{link_path} 已存在且是實體檔案/資料夾，不是 symlink！"
        $stderr.puts "請先更名或移開 #{link_path} 後再執行 link。"
        exit 1
      else
        File.symlink(domain_dir.to_s, link_path.to_s)
        puts "✓ Symlink 已建立：#{link_path} → #{domain_dir}"
      end

      # 自動加入 .gitignore
      gitignore = project_path.join('.gitignore')
      if gitignore.file?
        content = gitignore.read(encoding: 'UTF-8')
        unless content.lines.any? { |l| l.strip == 'tesseract' || l.strip == 'tesseract/' }
          File.open(gitignore, 'a:UTF-8') do |f|
            f.puts "\n# Tesseract knowledge base symlink\ntesseract"
          end
          puts "✓ 已將 tesseract 加入 #{gitignore}"
        end
      end
    end

    def cmd_new_domain(args)
      if args.empty?
        $stderr.puts '用法: tesseract new-domain <名稱> [說明]'
        exit 1
      end

      domain_name = args[0]
      desc = args[1] || "#{domain_name} 知識庫"
      res = @store.create_domain(domain_name, description: desc)

      if res[:success]
        puts "✓ 已建立 domain：#{res[:path]}"
        puts "  - #{res[:path]}/index.md"
        puts "  - #{res[:path]}/assets/"
      else
        $stderr.puts "錯誤：#{res[:message]}"
        exit 1
      end
    end

    def cmd_status
      puts '=== Tesseract 狀態 ==='
      puts ''
      puts "iCloud 知識庫 Vault：#{@store.domains_root}"
      puts ''

      root_index = @store.domains_root.join('index.md')
      if root_index.file?
        last_mod = root_index.mtime.strftime('%Y-%m-%d %H:%M')
        puts '── 全域知識庫 (Global Domain) ───────────'
        puts "  ✓ global (最後更新：#{last_mod})"
      else
        puts '  ✗ global (尚未初始化，請執行 tesseract init)'
      end

      puts ''
      puts '── 專案知識 Domains ──────────────────────'

      domains = @store.list_domains.reject { |d| d == 'global' }
      if domains.empty?
        puts '  （目前沒有任何專案 domain）'
        puts '  建立新專案與 domain：tesseract new <專案名稱>'
      else
        domains.each do |dom|
          idx = @store.domains_root.join(dom, 'index.md')
          if idx.file?
            last_mod = idx.mtime.strftime('%Y-%m-%d %H:%M')
            puts "  ✓ #{dom}（最後更新：#{last_mod}）"
          else
            puts "  ✗ #{dom}（缺少 index.md）"
          end
        end
      end

      puts ''
      puts '── 已連結的本機專案 (Symlink) ───────────'

      search_roots = %w[code Documents projects workspace dev].map { |d| Pathname.new(Dir.home).join(d) }
      found = 0

      search_roots.each do |root|
        next unless root.directory?

        # Search depth 3
        Dir.glob(root.join('*', 'tesseract').to_s).each do |symlink|
          sym = Pathname.new(symlink)
          next unless sym.symlink?

          target = sym.readlink.expand_path(sym.parent)
          domain_name = target.basename.to_s

          if target.directory?
            puts "  ✓ #{sym.parent}"
            puts "    → #{domain_name} (#{target})"
          else
            puts "  ✗ #{sym.parent}"
            puts "    → #{target}（目標不存在）"
          end
          found += 1
        end
      end

      puts '  （尚未在常見專案目錄中偵測到 tesseract symlink）' if found.zero?
      puts ''
    end

    def cmd_reindex
      puts '=== Tesseract Reindex ==='
      puts ''
      reindexed = @store.reindex_all
      reindexed.each do |d|
        puts "  ✓ #{d}：index.md Files 清單已重建"
      end
      puts ''
      puts "完成：已重建 #{reindexed.size} 個 domain 的索引"
    end

    def cmd_init(args)
      puts '=== Tesseract 初始化 ==='
      puts ''

      default_path = Store::DEFAULT_ICLOUD_PATH
      puts "知識庫路徑（iCloud Vault，預設：#{default_path}）"

      input_path = args.first
      if input_path.nil?
        print '請輸入路徑，或直接按 Enter 使用預設值: '
        input = $stdin.gets.strip
        input_path = input.empty? ? default_path : input
      end

      target_dir = Pathname.new(File.expand_path(input_path))
      FileUtils.mkdir_p(target_dir)

      # Ensure global index
      store = Store.new(domains_root: target_dir)
      store.ensure_root_exists!

      puts ''
      puts "✓ 知識庫路徑已就緒：#{target_dir}"
      puts "✓ 全域索引已建立：#{target_dir.join('index.md')}"
      puts ''
      puts '=== 初始化完成 ==='
      puts ''
      puts '接下來的步驟：'
      puts '  1. 配置 AI Agent 的 MCP Server：'
      puts '     tesseract mcp-config'
      puts ''
      puts '  2. 建立或連結專案：'
      puts '     tesseract new <專案名稱>   或   tesseract link'
      puts ''
    end

    def cmd_mcp_config
      mcp_bin = Pathname.new(File.expand_path('../../bin/tesseract-mcp', __FILE__))

      puts '=== Tesseract MCP Configuration ==='
      puts ''
      puts "MCP Server 可執行路徑: #{mcp_bin}"
      puts ''
      puts '── 1. Claude Code CLI ─────────────────────────────────'
      puts '執行以下指令一鍵註冊到 Claude Code：'
      puts ''
      puts "  claude mcp add tesseract -- \"#{mcp_bin}\""
      puts ''
      puts '── 2. Google Antigravity / Gemini CLI ─────────────────'
      puts '在 ~/.gemini/antigravity-ide/mcp_config.json 或專案 .gemini/mcp_config.json 加入：'
      puts ''
      puts JSON.pretty_generate({
        mcpServers: {
          tesseract: {
            command: mcp_bin.to_s
          }
        }
      })
      puts ''
      puts '── 3. Claude Desktop (claude_desktop_config.json) ─────'
      puts '路徑: ~/Library/Application Support/Claude/claude_desktop_config.json'
      puts ''
      puts JSON.pretty_generate({
        mcpServers: {
          tesseract: {
            command: mcp_bin.to_s
          }
        }
      })
      puts ''
      puts '── 4. Cursor (.cursor/mcp.json) ───────────────────────'
      puts ''
      puts JSON.pretty_generate({
        mcpServers: {
          tesseract: {
            command: mcp_bin.to_s
          }
        }
      })
      puts ''
    end

    def cmd_mcp(args)
      server = MCPServer.new(cwd: @cwd)
      server.start
    end

    def cmd_help
      puts <<~HELP
        用法: tesseract <指令> [參數]

        常用指令:
          new <名稱> [路徑]            建立專案資料夾 + iCloud 知識庫 + 連結（一步完成）
          link [路徑] [domain]         將既有專案連結到知識 domain (建立 symlink，預設同資料夾名)
          status                       列出所有 domain 與已連結專案狀態
          mcp-config                   顯示各 AI 工具（Claude / Gemini / Cursor）的 MCP 設定
          mcp                          啟動 Tesseract MCP Server (Stdio JSON-RPC)
          init [路徑]                  初始化 Tesseract 知識庫
          new-domain <名稱> [說明]     建立新 iCloud 知識 domain
          reindex                      重建各 domain 的 index.md Files 清單
          help                         顯示此說明
      HELP
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  Tesseract::CLI.new.run
end
