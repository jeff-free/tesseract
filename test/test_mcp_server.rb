# frozen_string_literal: true

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
end

class TestMCPInstaller < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir('tesseract_inst_test_')
    @mcp_bin = '/usr/local/bin/tesseract-mcp'
    @installer = Tesseract::MCPInstaller.new(@mcp_bin)
  end

  def teardown
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
  def setup
    @tmpdir = Dir.mktmpdir('tesseract_cli_test_')
    @project_dir = Dir.mktmpdir('tesseract_cli_proj_')
    @old_env = ENV['TESSERACT_DOMAINS']
    ENV['TESSERACT_DOMAINS'] = @tmpdir
  end

  def teardown
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

    # Verify symlink and gitignore
    symlink_path = File.join(existing_repo, 'tesseract')
    assert File.symlink?(symlink_path)
    assert_includes File.read(File.join(existing_repo, '.gitignore')), 'tesseract'
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
end
