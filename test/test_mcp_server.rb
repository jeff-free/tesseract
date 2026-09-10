# frozen_string_literal: true

# The suite must run on a machine with no LANG/LC_ALL (the very environment that produced
# the Encoding::CompatibilityError this file regression-tests). Without this, the test
# process itself reads files and child stdout as US-ASCII and blows up on its own fixtures.
Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = nil

require 'minitest/autorun'
require 'tmpdir'
require 'pathname'
require 'json'
require 'open3'
require 'stringio'

require_relative '../mcp/store'
require_relative '../mcp/prompts'
require_relative '../mcp/tools'
require_relative '../mcp/server'
require_relative '../mcp/installer'
require_relative '../mcp/cli'

class TestTesseractStore < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir('tesseract_test_')
    @project_dir = Dir.mktmpdir('tesseract_project_')
    @store = Tesseract::Store.new(domains_root: @tmpdir, cwd: @project_dir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if File.exist?(@tmpdir)
    FileUtils.remove_entry(@project_dir) if File.exist?(@project_dir)
  end

  def test_root_initialization
    index_file = File.join(@tmpdir, '_global', 'index.md')
    assert File.exist?(index_file), '_global/index.md should exist'
    content = File.read(index_file)
    assert_includes content, '# _global'
    assert_includes content, '## Files'
    assert_includes content, '## Changelog'
  end

  def test_save_and_read_global_topic
    res = @store.save_topic(
      domain: 'global',
      topic: 'auth-pattern',
      content: "JWT based authentication pattern.\nAlways use HttpOnly cookies.",
      tags: ['#security', '#auth'],
      summary: 'Initial auth pattern decision'
    )

    assert res[:success]
    assert_equal '_global', res[:domain]
    assert_equal 'auth-pattern', res[:topic]

    # Verify topic file inside _global/
    topic_file = File.join(@tmpdir, '_global', 'auth-pattern.md')
    assert File.exist?(topic_file)
    topic_content = File.read(topic_file)
    assert_includes topic_content, '# Auth pattern'
    assert_includes topic_content, '#security #auth'
    assert_includes topic_content, 'JWT based authentication'

    # Verify _global/index.md updated
    index_content = File.read(File.join(@tmpdir, '_global', 'index.md'))
    assert_includes index_content, '- [[auth-pattern]] — Auth pattern #security #auth'
    assert_includes index_content, 'Initial auth pattern decision (AI)'

    # Test read_topic
    read_res = @store.read_topic(domain: 'global', topic: 'auth-pattern')
    assert read_res[:found]
    assert_includes read_res[:content], 'JWT based authentication'
  end

  def test_create_project_domain_and_save_topic
    domain_res = @store.create_domain('my-app', description: 'Web application domain')
    assert domain_res[:success]

    project_domain_dir = File.join(@tmpdir, 'my-app')
    assert Dir.exist?(project_domain_dir)
    assert File.exist?(File.join(project_domain_dir, 'index.md'))

    # Save topic in project domain
    res = @store.save_topic(
      domain: 'my-app',
      topic: 'db-schema',
      content: "# PostgreSQL Schema\n\nUses UUID primary keys.",
      tags: ['#database'],
      summary: 'Decided UUID keys'
    )

    assert res[:success]
    assert_equal 'my-app', res[:domain]

    # Read from project domain
    read_res = @store.read_topic(domain: 'my-app', topic: 'db-schema')
    assert read_res[:found]
    assert_includes read_res[:content], 'PostgreSQL Schema'

    # Check project index.md
    proj_index = File.read(File.join(project_domain_dir, 'index.md'))
    assert_includes proj_index, '- [[db-schema]] — PostgreSQL Schema #database'
    assert_includes proj_index, 'Decided UUID keys (AI)'
  end

  def test_search_knowledge
    @store.save_topic(domain: 'global', topic: 'global-rule', content: 'Always write tests first', tags: ['#testing'])
    @store.create_domain('project-x')
    @store.save_topic(domain: 'project-x', topic: 'api-rule', content: 'RESTful endpoints with JSON schema', tags: ['#api'])

    # Search across all domains
    results = @store.search('tests')
    assert_equal 1, results.size
    assert_equal 'global-rule', results.first[:topic]

    results_api = @store.search('#api')
    assert_equal 1, results_api.size
    assert_equal 'api-rule', results_api.first[:topic]
  end

  def test_detect_domain_from_symlink
    @store.create_domain('linked-project')
    domain_path = File.join(@tmpdir, 'linked-project')

    # Create symlink in project_dir
    symlink_path = File.join(@project_dir, 'tesseract')
    File.symlink(domain_path, symlink_path)

    # Detect domain
    assert_equal 'linked-project', @store.detect_domain_from_cwd
    assert_equal 'linked-project', @store.current_domain_name
  end

  def test_append_rule
    res = @store.append_rule('Prefer Redis Token Bucket for rate limits', domain: 'global')
    assert res[:success]
    assert_equal false, res[:duplicate]

    rule_file = File.join(@tmpdir, '_global', 'rule.md')
    assert File.exist?(rule_file)
    content = File.read(rule_file)
    assert_includes content, 'Prefer Redis Token Bucket for rate limits'
    assert_includes content, '## 提煉偏好與習慣 (Hyperfold)'

    # Test duplicate prevention
    dup_res = @store.append_rule('Prefer Redis Token Bucket for rate limits', domain: 'global')
    assert dup_res[:success]
    assert_equal true, dup_res[:duplicate]
  end

  def test_hyperfold_tool
    res = Tesseract::Tools.handle_tool_call(
      @store,
      'tesseract_hyperfold',
      {
        'topic' => 'auth-ratelimit',
        'content' => 'Rate limit implementation details.',
        'rule' => 'Always use sliding window rate limiting',
        'rule_domain' => 'global',
        'backlinks' => ['[[api-gateway]]'],
        'summary' => 'Added rate limit guidelines'
      }
    )

    text = res.dig(:content, 0, :text)
    assert_includes text, 'Hyperfold Applied'
    assert_includes text, 'Rule committed'
    assert_includes text, 'Topic updated'

    # Verify content has backlink
    read_res = @store.read_topic(topic: 'auth-ratelimit', domain: 'global')
    assert_includes read_res[:content], '[[api-gateway]]'
  end

  def test_skills_initialization_and_listing
    skills = @store.list_skills
    assert skills.any?, 'Default skills should be initialized'
    hyperfold = skills.find { |s| s[:name] == 'tesseract-hyperfold' || s[:id] == 'hyperfold' }
    refute_nil hyperfold, 'tesseract-hyperfold skill should exist in _global/skills/'

    content = @store.read_skill('hyperfold')
    refute_nil content
    assert_includes content, 'tesseract-hyperfold'
    assert_includes content, 'Hyperfold'

    # Verify Prompts integration
    prompts = Tesseract::Prompts.list_prompts(@store)
    found = prompts.find { |p| p[:name] == 'tesseract-hyperfold' || p[:name] == 'tesseract_hyperfold_guide' }
    refute_nil found, 'Dynamic skills should be exposed in Prompts.list_prompts'
  end
end

class TestMCPInstaller < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir('tesseract_inst_test_')
    @old_home = ENV['HOME']
    ENV['HOME'] = @tmpdir
    @mcp_bin = File.join(@tmpdir, 'bin', 'tesseract-mcp')
    @installer = Tesseract::MCPInstaller.new(@mcp_bin)
  end

  def teardown
    ENV['HOME'] = @old_home
    FileUtils.remove_entry(@tmpdir) if File.exist?(@tmpdir)
  end

  def test_install_all_returns_valid_records
    results = @installer.install_all
    assert results.is_a?(Array)
    results.each do |r|
      assert r[:name]
      assert r.key?(:success)
    end
  end

  def test_check_status_returns_structured_results
    statuses = @installer.check_status
    assert statuses.is_a?(Array)
    statuses.each do |s|
      assert s[:name]
      assert s.key?(:installed)
      assert s.key?(:detected)
    end
  end
end

class TestTesseractCLI < Minitest::Test
  # A stdin that is never a TTY and never blocks. Pinned for every CLI test so a suite run
  # from a real terminal cannot stop on an interactive prompt waiting for a human — tests
  # that care about prompting swap in their own stdin via #with_stdin.
  class NonInteractiveStdin
    def tty? = false
    def gets = nil
  end

  def setup
    @tmpdir = Dir.mktmpdir('tesseract_cli_test_')
    @project_dir = Dir.mktmpdir('tesseract_cli_proj_')
    @old_env = ENV['TESSERACT_DOMAINS']
    ENV['TESSERACT_DOMAINS'] = @tmpdir
    @old_stdin = $stdin
    $stdin = NonInteractiveStdin.new
  end

  def teardown
    $stdin = @old_stdin
    ENV['TESSERACT_DOMAINS'] = @old_env
    FileUtils.remove_entry(@tmpdir) if File.exist?(@tmpdir)
    FileUtils.remove_entry(@project_dir) if File.exist?(@project_dir)
  end

  def test_cli_new_and_status
    out, = capture_io do
      cli = Tesseract::CLI.new(['new', 'test-app', File.join(@project_dir, 'test-app')], @project_dir)
      cli.run
    end

    assert_includes out, '建立新專案：test-app'
    assert Dir.exist?(File.join(@tmpdir, 'test-app'))
    assert File.symlink?(File.join(@project_dir, 'test-app', 'tesseract'))

    # Check status
    status_out, = capture_io do
      Tesseract::CLI.new(['status'], @project_dir).run
    end
    assert_includes status_out, 'test-app'
  end

  def test_cli_link_existing_project
    # Create an existing repo folder with gitignore
    existing_repo = File.join(@project_dir, 'my-service')
    FileUtils.mkdir_p(existing_repo)
    File.write(File.join(existing_repo, '.gitignore'), "node_modules\n.DS_Store\n")

    out, = capture_io do
      cli = Tesseract::CLI.new(['link'], existing_repo)
      cli.run
    end

    assert_includes out, '連結專案到 Tesseract 知識庫'
    assert_includes out, 'my-service'

    # Verify symlink and rule.md exist, and gitignore is untouched
    symlink_path = File.join(existing_repo, 'tesseract')
    assert File.symlink?(symlink_path)
    assert File.file?(File.join(existing_repo, 'tesseract', 'rule.md'))
    refute_includes File.read(File.join(existing_repo, '.gitignore')), 'tesseract'
    assert_includes out, '.git/info/exclude'
  end

  # Regression: `tesseract link` with no argument asks for a domain name. When stdin is a
  # TTY that question waits for a human — which silently hung the test suite depending on how
  # it was launched — and at EOF the old code died on `nil.strip`. CLI#ask must take the
  # default without touching stdin whenever stdin is not a TTY, so behaviour no longer
  # depends on the caller's stdin.
  def test_cli_prompts_use_defaults_when_stdin_is_not_a_tty
    existing_repo = File.join(@project_dir, 'noninteractive-proj')
    FileUtils.mkdir_p(existing_repo)

    # A TTY-less stdin that raises if anything reads it: the CLI must not consult stdin here.
    exploding_stdin = Class.new do
      def tty? = false
      def gets = raise('CLI must not read stdin when stdin is not a TTY')
    end.new

    out = with_stdin(exploding_stdin) do
      capture_io do
        cli = Tesseract::CLI.new(['link'], existing_repo)
        cli.run
      end.first
    end

    # Fell back to the directory name instead of asking.
    assert_includes out, 'noninteractive-proj'
    refute_includes out, 'Domain 名稱'
    assert File.symlink?(File.join(existing_repo, 'tesseract'))
  end

  # Regression: an interactive prompt that reaches EOF (piped input that ran out) must fall
  # back to its default rather than raising NoMethodError on nil.
  def test_cli_prompt_falls_back_to_default_on_eof
    existing_repo = File.join(@project_dir, 'eof-proj')
    FileUtils.mkdir_p(existing_repo)

    eof_tty_stdin = Class.new do
      def tty? = true
      def gets = nil # immediate EOF
    end.new

    out = with_stdin(eof_tty_stdin) do
      capture_io do
        cli = Tesseract::CLI.new(['link'], existing_repo)
        cli.run
      end.first
    end

    assert_includes out, 'Domain 名稱' # it did ask, this time
    assert_includes out, 'eof-proj'    # and defaulted when the answer never came
    assert File.symlink?(File.join(existing_repo, 'tesseract'))
  end

  def with_stdin(replacement)
    original = $stdin
    $stdin = replacement
    yield
  ensure
    $stdin = original
  end

  def test_sync_project_rules_creates_and_updates_cleanly
    existing_repo = File.join(@project_dir, 'rule-test-proj')
    FileUtils.mkdir_p(existing_repo)

    # Pre-populate CLAUDE.md with custom build command
    claude_file = File.join(existing_repo, 'CLAUDE.md')
    File.write(claude_file, "# Custom Project\n\n- Build: npm run build\n")

    store = Tesseract::Store.new(domains_root: @tmpdir, cwd: existing_repo)
    store.create_domain('rule-test-proj')
    File.symlink(File.join(@tmpdir, 'rule-test-proj'), File.join(existing_repo, 'tesseract'))

    res = Tesseract::Tools.sync_project_rules(store, project_path: existing_repo)
    assert res[:success]

    # Verify CLAUDE.md preserved build command and got marker block
    claude_content = File.read(claude_file)
    assert_includes claude_content, 'npm run build'
    assert_includes claude_content, '<!-- tesseract-rule-start -->'
    assert_includes claude_content, 'tesseract/rule.md'
    assert_includes claude_content, '<!-- tesseract-rule-end -->'

    # Verify .cursorrules was created
    cursor_file = File.join(existing_repo, '.cursorrules')
    assert File.file?(cursor_file)
    assert_includes File.read(cursor_file), 'tesseract/rule.md'

    # Test idempotency - running sync again replaces marker block without duplicating
    Tesseract::Tools.sync_project_rules(store, project_path: existing_repo)
    claude_content_v2 = File.read(claude_file)
    assert_equal 1, claude_content_v2.scan('<!-- tesseract-rule-start -->').size
    assert_includes claude_content_v2, 'npm run build'
  end

  def test_cli_sync_rules_command
    existing_repo = File.join(@project_dir, 'cli-sync-proj')
    FileUtils.mkdir_p(existing_repo)
    store = Tesseract::Store.new(domains_root: @tmpdir, cwd: existing_repo)
    store.create_domain('cli-sync-proj')
    File.symlink(File.join(@tmpdir, 'cli-sync-proj'), File.join(existing_repo, 'tesseract'))

    out, = capture_io do
      cli = Tesseract::CLI.new(['sync-rules', 'claude', 'cursor'], existing_repo)
      cli.run
    end

    assert_includes out, 'Successfully synchronized'
    assert File.file?(File.join(existing_repo, 'CLAUDE.md'))
    assert File.file?(File.join(existing_repo, '.cursorrules'))
    refute File.file?(File.join(existing_repo, 'GEMINI.md'))
  end

  def test_cli_config_overview
    out, = capture_io do
      cli = Tesseract::CLI.new(['config'], @project_dir)
      cli.run
    end

    assert_includes out, 'Tesseract 設定管理'
    assert_includes out, 'AI Agent MCP 註冊狀態'
    assert_includes out, 'Claude Code'
  end
end

class TestMCPProtocolIntegration < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir('tesseract_mcp_proto_')
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if File.exist?(@tmpdir)
  end

  def test_stdio_jsonrpc_communication
    bin_path = File.expand_path('../bin/tesseract-mcp', __dir__)

    requests = [
      { jsonrpc: '2.0', id: 1, method: 'initialize', params: { clientInfo: { name: 'test-agent', version: '1.0' } } },
      { jsonrpc: '2.0', id: 2, method: 'tools/list', params: {} },
      {
        jsonrpc: '2.0',
        id: 3,
        method: 'tools/call',
        params: {
          name: 'tesseract_save_knowledge',
          arguments: {
            topic: 'proto-test',
            content: 'Testing protocol save',
            tags: ['#mcp', '#protocol'],
            summary: 'Protocol test entry',
            domain: 'global'
          }
        }
      },
      {
        jsonrpc: '2.0',
        id: 4,
        method: 'tools/call',
        params: {
          name: 'tesseract_read_knowledge',
          arguments: { topic: 'proto-test', domain: 'global' }
        }
      },
      {
        jsonrpc: '2.0',
        id: 5,
        method: 'tools/call',
        params: {
          name: 'tesseract_search_knowledge',
          arguments: { query: 'protocol' }
        }
      }
    ]

    input_data = requests.map { |r| JSON.generate(r) }.join("\n") + "\n"

    stdout, stderr, status = Open3.capture3(
      { 'TESSERACT_DOMAINS' => @tmpdir },
      bin_path,
      stdin_data: input_data
    )

    assert status.success?, "Server process exited with error: #{stderr}"

    responses = stdout.lines.map(&:strip).reject(&:empty?).map { |l| JSON.parse(l) }
    assert_equal 5, responses.size

    # 1. Initialize response
    init_res = responses.find { |r| r['id'] == 1 }
    assert_equal 'tesseract-mcp', init_res['result']['serverInfo']['name']

    # 2. Tools list response
    tools_res = responses.find { |r| r['id'] == 2 }
    tool_names = tools_res['result']['tools'].map { |t| t['name'] }
    assert_includes tool_names, 'tesseract_read_knowledge'
    assert_includes tool_names, 'tesseract_save_knowledge'
    assert_includes tool_names, 'tesseract_search_knowledge'
    assert_includes tool_names, 'tesseract_hyperfold'

    # 3. Save knowledge response
    save_res = responses.find { |r| r['id'] == 3 }
    assert_includes save_res['result']['content'].first['text'], 'Successfully saved'

    # 4. Read knowledge response
    read_res = responses.find { |r| r['id'] == 4 }
    assert_includes read_res['result']['content'].first['text'], 'Testing protocol save'

    # 5. Search knowledge response
    search_res = responses.find { |r| r['id'] == 5 }
    assert_includes search_res['result']['content'].first['text'], 'proto-test'
  end

  # Regression: MCP clients send raw UTF-8 JSON, but a server launched without LANG/LC_ALL
  # boots with US-ASCII stdio. Reading such a line used to raise Encoding::CompatibilityError
  # in String#strip, outside the rescue, killing the process — the client only saw
  # "Connection closed". See mcp/server.rb#force_utf8_stdio! / #normalise_line.
  def test_multibyte_request_under_ascii_locale
    bin_path = File.expand_path('../bin/tesseract-mcp', __dir__)
    body = "# 中文標題\n\n狀態轉換：pay_run_finalising → pay_run_approved。破折號 — 也算非 ASCII。"

    requests = [
      { jsonrpc: '2.0', id: 1, method: 'initialize', params: { clientInfo: { name: 'test-agent', version: '1.0' } } },
      {
        jsonrpc: '2.0',
        id: 2,
        method: 'tools/call',
        params: {
          name: 'tesseract_save_knowledge',
          arguments: { topic: 'cjk-topic', content: body, summary: '中文摘要', domain: 'global' }
        }
      },
      {
        jsonrpc: '2.0',
        id: 3,
        method: 'tools/call',
        params: { name: 'tesseract_read_knowledge', arguments: { topic: 'cjk-topic', domain: 'global' } }
      }
    ]

    input_data = "#{requests.map { |r| JSON.generate(r) }.join("\n")}\n"
    refute input_data.ascii_only?, 'test input must carry raw multi-byte bytes'

    # LC_ALL=C is what makes Ruby pick US-ASCII for stdio — the condition that used to crash.
    stdout, stderr, status = Open3.capture3(
      { 'TESSERACT_DOMAINS' => @tmpdir, 'LC_ALL' => 'C', 'LANG' => 'C' },
      bin_path,
      stdin_data: input_data
    )

    assert status.success?, "Server died on a multi-byte request: #{stderr}"
    refute_includes stderr, 'Encoding::CompatibilityError'

    responses = stdout.lines.map(&:strip).reject(&:empty?).map { |l| JSON.parse(l) }
    assert_equal 3, responses.size

    save_res = responses.find { |r| r['id'] == 2 }
    assert_includes save_res['result']['content'].first['text'], 'Successfully saved'

    read_res = responses.find { |r| r['id'] == 3 }
    text = read_res['result']['content'].first['text']
    assert_includes text, '中文標題'
    assert_includes text, 'pay_run_finalising'

    saved = File.read(File.join(@tmpdir, '_global', 'cjk-topic.md'), encoding: 'UTF-8')
    assert_includes saved, '狀態轉換'
  end

  # Regression: one unreadable line must not drop the connection — the server answers with a
  # JSON-RPC error and keeps serving the requests that follow.
  def test_malformed_and_invalid_utf8_lines_do_not_kill_server
    bin_path = File.expand_path('../bin/tesseract-mcp', __dir__)

    init = JSON.generate({ jsonrpc: '2.0', id: 1, method: 'initialize',
                           params: { clientInfo: { name: 'test-agent', version: '1.0' } } })
    status_call = JSON.generate({ jsonrpc: '2.0', id: 2, method: 'tools/call',
                                  params: { name: 'tesseract_get_domain_status', arguments: {} } })

    input_data = +''
    input_data << init << "\n"
    input_data << "{ this is not json\n"
    input_data << "{\"jsonrpc\":\"2.0\",\"id\":9,\"method\":\"ping\",\"broken\":\"\xC3\x28\"}\n" # invalid UTF-8
    input_data << status_call << "\n"

    stdout, stderr, status = Open3.capture3(
      { 'TESSERACT_DOMAINS' => @tmpdir, 'LC_ALL' => 'C', 'LANG' => 'C' },
      bin_path,
      stdin_data: input_data.b
    )

    assert status.success?, "Server died on a bad line: #{stderr}"

    responses = stdout.lines.map(&:strip).reject(&:empty?).map { |l| JSON.parse(l) }
    parse_errors = responses.select { |r| r.dig('error', 'code') == -32_700 }
    refute_empty parse_errors, 'malformed line should produce a JSON-RPC parse error'

    # The request after the bad lines still gets served.
    status_res = responses.find { |r| r['id'] == 2 }
    refute_nil status_res, "server stopped serving after a bad line: #{stdout}"
    assert_includes status_res['result']['content'].first['text'], 'Tesseract Knowledge Base Status'
  end
end
