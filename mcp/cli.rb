# frozen_string_literal: true

require_relative 'store'
require_relative 'server'
require_relative 'installer'
require 'pathname'
require 'fileutils'
require 'optparse'

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
      when 'save'
        cmd_save(args)
      when 'read'
        cmd_read(args)
      when 'search'
        cmd_search(args)
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
      when 'config'
        cmd_config(args)
      when 'mcp-install', 'install-mcp'
        cmd_mcp_install
      when 'mcp-config'
        cmd_mcp_config(args)
      when 'sync-rules'
        cmd_sync_rules(args)
      when 'mcp'
        cmd_mcp(args)
      when 'help', '--help', '-h'
        cmd_help
      else
        warn "錯誤：不認識的指令 '#{command}'\n\n"
        cmd_help
        exit 1
      end
    end

    private

    # Single entry point for every interactive question the CLI asks.
    #
    # Returns `default` without printing or reading when stdin is not a TTY — a piped
    # invocation, a CI run, or the test suite. Reading stdin unconditionally used to hang the
    # process (it waits forever for a human) or crash on `nil.strip` at EOF, and which of the
    # two you got depended on how the caller happened to be launched. Callers must therefore
    # supply a sensible `default` for the non-interactive path.
    def ask(question, default: nil)
      return default unless $stdin.tty?

      print question
      answer = $stdin.gets
      return default if answer.nil? # EOF

      answer = answer.strip
      answer.empty? ? default : answer
    end

    def cmd_new(args)
      if args.empty?
        warn '用法: tesseract new <專案名稱> [專案路徑]'
        warn '範例: tesseract new honeymoon'
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
        default_name = project_path.basename.to_s
        domain_name = ask("Domain 名稱 [#{default_name}]: ", default: default_name)
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

      # 確保 iCloud domain 目錄已存在，避免懸空 symlink
      unless domain_dir.directory?
        @store.create_domain(domain_name, description: "#{domain_name} 專案知識庫")
      end

      if link_path.symlink?
        existing = link_path.readlink.expand_path(project_path)
        if existing == domain_dir
          puts "✓ Symlink 已存在且正確：#{link_path} → #{domain_dir}"
        else
          puts "警告：#{link_path} 目前指向 #{existing}"
          answer = ask("是否重新導向至 #{domain_dir}？[Y/n] ", default: 'Y')
          if answer.match?(/^[Yy]$/)
            link_path.unlink
            File.symlink(domain_dir.to_s, link_path.to_s)
            puts "✓ Symlink 已更新：#{link_path} → #{domain_dir}"
          else
            puts '保留原連結，結束。'
            return
          end
        end
      elsif link_path.directory?
        puts "ℹ 偵測到現有實體資料夾：#{link_path}"
        answer = ask("是否將現有資料夾內的筆記遷移至 iCloud 知識庫並建立 symlink？[Y/n] ", default: 'Y')
        if answer.match?(/^[Yy]$/)
          link_path.children.each do |child|
            dest = domain_dir.join(child.basename)
            unless dest.exist?
              FileUtils.cp_r(child, dest)
              puts "  ✓ 遷移：#{child.basename} → iCloud"
            end
          end
          backup_path = project_path.join("tesseract.backup.#{Time.now.strftime('%Y%m%d%H%M%S')}")
          FileUtils.mv(link_path, backup_path)
          puts "  ✓ 原資料夾已備份至：#{backup_path}"
          File.symlink(domain_dir.to_s, link_path.to_s)
          puts "✓ Symlink 已建立：#{link_path} → #{domain_dir}"
        else
          warn "錯誤：#{link_path} 是實體資料夾，未建立 symlink。"
          return
        end
      elsif link_path.exist?
        warn "錯誤：#{link_path} 已存在且是檔案，不是 symlink！"
        warn "請先更名或移開 #{link_path} 後再執行。"
        exit 1
      else
        File.symlink(domain_dir.to_s, link_path.to_s)
        puts "✓ Symlink 已建立：#{link_path} → #{domain_dir}"
      end

      # 確保 domain 內有 rule.md
      @store.ensure_rule_file(domain_dir, domain_name) if @store.respond_to?(:ensure_rule_file)

      # 自動同步專案 AI 設定檔 (CLAUDE.md, .cursorrules 等) 指針
      require_relative 'tools' unless defined?(Tesseract::Tools)
      Tools.sync_project_rules(@store, targets: ['all'], project_path: project_path)

      # 輸出 Git 忽略建議，不強制修改使用者的 .gitignore
      puts ''
      puts '💡 提示：若這是 Git 專案，為避免 symlink 影響遠端或隊友，建議將 tesseract/ 忽略：'
      puts '   - 團隊共用忽略：在 .gitignore 加入「tesseract/」'
      puts '   - 僅本機忽略（不影響他人）：在 .git/info/exclude 加入「tesseract/」'
    end

    def cmd_new_domain(args)
      if args.empty?
        warn '用法: tesseract new-domain <名稱> [說明]'
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
        warn "錯誤：#{res[:message]}"
        exit 1
      end
    end

    def cmd_status
      puts '=== Tesseract 狀態 ==='
      puts ''
      puts "iCloud 知識庫 Vault：#{@store.domains_root}"
      puts ''

      puts '── 當前專案狀態 ──────────────────────────'
      detected = @store.detect_domain_from_cwd
      project_symlink = @cwd.join('tesseract')
      if project_symlink.symlink?
        target = project_symlink.readlink.expand_path(@cwd)
        if target.directory?
          puts "  ✓ 專案已連結：#{@cwd}"
          puts "    → Domain: #{detected || target.basename} (#{target})"
        else
          puts "  ✗ 專案 Symlink 指向不存在目標：#{target}"
        end
      elsif detected
        puts "  ○ 偵測到匹配 Domain：#{detected}（但當前目錄尚未建立 tesseract/ symlink，可執行 tesseract init 或 tesseract link）"
      else
        puts "  — 當前目錄 (#{@cwd.basename}) 尚未連結至專案知識庫"
      end
      puts ''

      root_index = @store.global_dir.join('index.md')
      if root_index.file?
        last_mod = root_index.mtime.strftime('%Y-%m-%d %H:%M')
        puts '── 全域知識庫 (Global Domain) ───────────'
        puts "  ✓ _global (最後更新：#{last_mod})"
      else
        puts '  ✗ _global (尚未初始化，請執行 tesseract init)'
      end

      puts ''
      puts '── 專案知識 Domains ──────────────────────'

      domains = @store.list_domains.reject { |d| d == '_global' }
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

      # 1. 判定參數 (全域模式、自訂 Vault、或專案 Domain 名稱)
      global_only = args.include?('--global') || args.include?('--vault-only')

      custom_vault_index = args.index('--vault')
      custom_vault = custom_vault_index ? args[custom_vault_index + 1] : nil

      # 排除選項後的剩餘參數
      pos_args = args.reject { |a| a.start_with?('--') || a == custom_vault }

      # 若第一位置參數看起來像自訂路徑且包含斜線或已是資料夾（且不是純專案名稱）
      if pos_args.first && (pos_args.first.start_with?('/', '~', './', '../') || (File.directory?(File.expand_path(pos_args.first)) && pos_args.first != '.' && pos_args.first != @cwd.basename.to_s))
        custom_vault ||= pos_args.shift
      end

      specified_domain = pos_args.first

      default_vault = Store::DEFAULT_ICLOUD_PATH
      vault_path = custom_vault || ENV['TESSERACT_DOMAINS'] || default_vault
      target_dir = Pathname.new(File.expand_path(vault_path))
      FileUtils.mkdir_p(target_dir)

      # Ensure global index & skills in iCloud Vault
      store = Store.new(domains_root: target_dir, cwd: @cwd)
      store.ensure_root_exists!

      puts "✓ 知識庫路徑已就緒：#{target_dir}"
      puts "✓ 全域索引已就緒：#{store.global_dir.join('index.md')}"
      puts ''

      # 自動配置各 AI Agent 的 MCP
      puts '── 1. 自動配置 AI Agent MCP 服務 ───────────'
      installer = MCPInstaller.new
      results = installer.install_all

      if results.empty?
        puts '  （尚未偵測到已安裝的 Claude / Gemini / Cursor 設定檔）'
      else
        results.each do |res|
          if res[:success]
            puts "  ✓ 已自動配置 #{res[:name]} (#{res[:path]})"
          else
            puts "  ✗ 配置 #{res[:name]} 失敗: #{res[:error]}"
          end
        end
      end

      puts ''
      puts '── 2. 自動派發雲端 AI Skills ──────────────────'
      skill_results = installer.install_skills(store)
      if skill_results.empty?
        puts '  （雲端 skills 已就緒）'
      else
        skill_results.each do |res|
          if res[:success]
            puts "  ✓ 已同步 Skill [#{res[:skill]}] 至 #{res[:target]} (#{res[:path]})"
          else
            puts "  ✗ 同步 Skill [#{res[:skill]}] 至 #{res[:target]} 失敗: #{res[:error]}"
          end
        end
      end

      # 3. 專案初始化與 Symlink 連結 (核心修復：確保專案擁有 tesseract/ symlink 並指向 iCloud)
      is_project_dir = !global_only &&
                       @cwd != Pathname.new(Dir.home) &&
                       @cwd != target_dir &&
                       @cwd != target_dir.parent &&
                       @cwd.to_s != '/'

      domain_name = nil
      if is_project_dir
        puts ''
        puts '── 3. 專案知識庫與 Symlink 連結 ──────────────'
        default_domain = @cwd.basename.to_s
        domain_name = specified_domain || (
          $stdin.tty? ? ask("專案知識庫 Domain 名稱 [#{default_domain}]: ", default: default_domain) : default_domain
        )

        domain_dir = store.domains_root.join(domain_name)
        unless domain_dir.directory?
          store.create_domain(domain_name, description: "#{domain_name} 專案知識庫")
          puts "✓ 已建立專屬 iCloud domain：#{domain_dir}"
        end

        link_project_dir(@cwd, domain_dir, domain_name)
      end

      puts ''
      puts '=== 初始化完成 ==='
      puts ''
      if is_project_dir
        puts "  • 專案路徑：#{@cwd}"
        puts "  • 知識庫 Domain：#{domain_name} (#{store.domains_root.join(domain_name)})"
        puts "  • IDE 檔案樹：#{@cwd.join('tesseract')} (可直接瀏覽與手寫筆記)"
        puts "  • AI Agent：已自動配置 MCP 與 rule.md 規範，可直接讀寫知識庫"
      else
        puts '接下來您可以：'
        puts '  1. 建立新專案：tesseract new <專案名稱>'
        puts '  2. 連結既有專案：cd <專案目錄> && tesseract init 或 tesseract link'
      end
      puts ''
    end

    def cmd_config(args)
      subcommand = args.first

      case subcommand
      when 'mcp'
        action = args[1]
        if action == 'install'
          cmd_mcp_install
        elsif action == 'show'
          cmd_mcp_config([])
        else
          show_config_overview(interactive: true)
        end
      when 'install', 'mcp-install'
        cmd_mcp_install
      when 'show'
        cmd_mcp_config([])
      else
        show_config_overview(interactive: $stdin.tty?)
      end
    end

    def show_config_overview(interactive: false)
      puts '=== Tesseract 設定管理 (Configuration) ==='
      puts ''
      puts "知識庫路徑 (Vault)：#{@store.domains_root}"
      puts ''
      puts '── AI Agent MCP 註冊狀態 ─────────────────'

      installer = MCPInstaller.new
      statuses = installer.check_status

      statuses.each do |s|
        if s[:installed]
          puts "  ✓ #{s[:name].ljust(26)} [已啟用] (#{s[:path]})"
        elsif s[:detected]
          puts "  ○ #{s[:name].ljust(26)} [未註冊] (#{s[:path]})"
        else
          puts "  — #{s[:name].ljust(26)} [未安裝/無設定檔]"
        end
      end

      puts ''
      puts '可用操作指令：'
      puts '  tesseract config mcp install   -> 自動註冊/更新 MCP 至所有偵測到的 AI 工具'
      puts '  tesseract config mcp show      -> 顯示手動設定用的 JSON 代碼'
      puts ''

      return unless interactive

      answer = ask('是否要立即自動更新/註冊 MCP 設定到所有工具？[y/N] ', default: 'N')
      return unless answer.match?(/^[Yy]$/)

      puts ''
      cmd_mcp_install
    end

    def cmd_mcp_install
      puts '=== 自動配置 AI Agent MCP 服務 ==='
      puts ''
      installer = MCPInstaller.new
      results = installer.install_all

      if results.empty?
        puts '（尚未偵測到支援的 AI 工具設定檔）'
      else
        results.each do |res|
          if res[:success]
            puts "  ✓ 已成功註冊至 #{res[:name]} (#{res[:path]})"
          else
            puts "  ✗ 註冊 #{res[:name]} 失敗: #{res[:error]}"
          end
        end
      end

      puts ''
      puts '── 自動派發雲端 AI Skills ──────────────────'
      skill_results = installer.install_skills(@store)
      if skill_results.empty?
        puts '  （雲端 skills 已就緒）'
      else
        skill_results.each do |res|
          if res[:success]
            puts "  ✓ 已同步 Skill [#{res[:skill]}] 至 #{res[:target]} (#{res[:path]})"
          else
            puts "  ✗ 同步 Skill [#{res[:skill]}] 至 #{res[:target]} 失敗: #{res[:error]}"
          end
        end
      end
      puts ''
    end

    def cmd_mcp_config(_args)
      mcp_bin = Pathname.new(File.expand_path('../bin/tesseract-mcp', __dir__))

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

    def cmd_mcp(_args)
      server = MCPServer.new(cwd: @cwd)
      server.start
    end

    def cmd_sync_rules(args)
      require_relative 'tools' unless defined?(Tesseract::Tools)
      targets = args.empty? ? ['all'] : args
      res = Tools.sync_project_rules(@store, targets: targets)
      puts res[:message]
    end

    def cmd_save(args)
      options = {
        summary: nil,
        content: nil,
        file: nil,
        tags: [],
        domain: 'auto'
      }

      parser = OptionParser.new do |opts|
        opts.banner = '用法: tesseract save <topic> [選項]'
        opts.on('-s', '--summary SUMMARY', '本次更動的一句話摘要（記錄於 Changelog 與審查視窗）') { |v| options[:summary] = v }
        opts.on('-c', '--content CONTENT', 'Markdown 筆記內容') { |v| options[:content] = v }
        opts.on('-f', '--file PATH', '從指定檔案讀取 Markdown 內容') { |v| options[:file] = v }
        opts.on('-t', '--tags TAGS', '標籤列表，以逗號分隔 (如 "#auth,#security")') { |v| options[:tags] = v.split(',').map(&:strip) }
        opts.on('-d', '--domain DOMAIN', '目標 domain ("auto", "global", 或指定名稱)') { |v| options[:domain] = v }
        opts.on('-h', '--help', '顯示此說明') do
          puts opts
          exit 0
        end
      end

      remaining = parser.parse(args.dup)
      topic = remaining.first

      if topic.nil? || topic.strip.empty?
        warn '錯誤: 請指定筆記主題名稱 (topic)'
        warn parser.help
        exit 1
      end

      # Content source: 1. -c, 2. -f, 3. stdin pipe
      content = options[:content]
      if content.nil? && options[:file]
        file_path = Pathname.new(File.expand_path(options[:file], @cwd))
        if file_path.file?
          content = file_path.read(encoding: 'UTF-8')
        else
          warn "錯誤: 檔案不存在: #{options[:file]}"
          exit 1
        end
      end

      if content.nil? && !$stdin.tty?
        content = $stdin.read
      end

      if content.nil? || content.strip.empty?
        warn '錯誤: 請提供筆記內容 (透過 -c, -f 或管線輸入)'
        warn parser.help
        exit 1
      end

      summary = options[:summary] || (content.lines.find { |l| l.strip.start_with?('#') }&.sub(/^#+\s*/, '')&.strip || "Updated #{topic}")

      res = @store.save_topic(
        topic: topic,
        content: content,
        domain: options[:domain],
        summary: summary,
        tags: options[:tags]
      )

      puts res[:message]
    end

    def cmd_read(args)
      options = {
        domain: 'auto'
      }

      parser = OptionParser.new do |opts|
        opts.banner = '用法: tesseract read [topic] [選項]'
        opts.on('-d', '--domain DOMAIN', '目標 domain ("auto", "global", 或指定名稱)') { |v| options[:domain] = v }
        opts.on('-h', '--help', '顯示此說明') do
          puts opts
          exit 0
        end
      end

      remaining = parser.parse(args.dup)
      topic = remaining.first || 'index'

      res = @store.read_topic(domain: options[:domain], topic: topic)
      if res[:found]
        puts res[:content]
      else
        warn "錯誤: 找不到主題 '#{topic}' (#{res[:error]})"
        exit 1
      end
    end

    def cmd_search(args)
      options = {
        domain: nil
      }

      parser = OptionParser.new do |opts|
        opts.banner = '用法: tesseract search <關鍵字或#標籤> [選項]'
        opts.on('-d', '--domain DOMAIN', '限制搜尋特定 domain') { |v| options[:domain] = v }
        opts.on('-h', '--help', '顯示此說明') do
          puts opts
          exit 0
        end
      end

      remaining = parser.parse(args.dup)
      query = remaining.join(' ').strip

      if query.empty?
        warn '錯誤: 請輸入搜尋關鍵字或標籤'
        warn parser.help
        exit 1
      end

      results = @store.search(query, domain: options[:domain])
      if results.empty?
        puts "找不到符合 '#{query}' 的知識筆記。"
      else
        puts "=== 找到 #{results.size} 筆相符知識 (查詢: '#{query}') ==="
        puts ''
        results.each do |r|
          tag_str = r[:tags].any? ? " (#{r[:tags].join(' ')})" : ''
          puts "- [#{r[:domain]}] [[#{r[:topic]}]]#{tag_str}: #{r[:title]}"
          puts "  > #{r[:snippet]}"
          puts ''
        end
      end
    end

    def cmd_help
      puts <<~HELP
        用法: tesseract <指令> [參數]

        知識庫即時讀寫指令:
          save <topic> [選項]          儲存或更新知識筆記 (自動更新 index 與 Changelog)
                                       選項: -s "摘要" -c "內容" -f 檔案 -t "標籤1,標籤2" -d domain
          read [topic]                 讀取特定筆記或 index.md (輸出 Markdown)
          search <關鍵字|#tag>         搜尋知識庫筆記與標籤

        專案與環境管理指令:
          init [domain] [--global]     初始化知識庫並連結當前專案 (自動建立 symlink、rule.md 與同步 AI 規範)
          link [路徑] [domain]         將既有專案連結到知識 domain (建立 symlink，預設同資料夾名)
          new <名稱> [路徑]            建立專案資料夾 + iCloud 知識庫 + 連結（一步完成）
          sync-rules [targets]         同步專案各 AI 設定檔（CLAUDE.md、.cursorrules 等）指向 tesseract/rule.md
          config                       查看與管理 Tesseract 設定 (MCP 狀態與管理)
          status                       列出當前專案、所有 domain 與已連結專案狀態
          mcp                          啟動 Tesseract MCP Server (Stdio JSON-RPC)
          new-domain <名稱> [說明]     建立新 iCloud 知識 domain
          reindex                      重建各 domain 的 index.md Files 清單
          help                         顯示此說明
      HELP
    end
  end
end

Tesseract::CLI.new.run if __FILE__ == $PROGRAM_NAME
