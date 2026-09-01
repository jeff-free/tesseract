#!/usr/bin/env ruby
# frozen_string_literal: true

if RUBY_VERSION < '3.0.0'
  $stderr.puts "[Tesseract MCP] Error: Ruby 3.0.0 or higher is required. Found #{RUBY_VERSION}"
  exit 1
end

require_relative 'store'
require_relative 'prompts'
require_relative 'tools'
require 'json'
require 'logger'

module Tesseract
  class MCPServer
    SERVER_NAME = 'tesseract-mcp'
    SERVER_VERSION = '1.0.0'
    PROTOCOL_VERSION = '2024-11-05'

    def initialize(domains_root: nil, cwd: Dir.pwd)
      @store = Store.new(domains_root: domains_root, cwd: cwd)
      @logger = Logger.new($stderr)
      @logger.level = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO
      @logger.formatter = proc do |severity, datetime, _progname, msg|
        "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] [#{severity}] [Tesseract MCP] #{msg}\n"
      end
    end

    def start
      @logger.info("Starting Tesseract MCP Server v#{SERVER_VERSION} (Ruby #{RUBY_VERSION})")
      @logger.info("Vault root: #{@store.domains_root}")
      @logger.info("Working directory: #{@store.cwd}")

      $stdin.each_line do |line|
        trimmed = line.strip
        next if trimmed.empty?

        @logger.debug("Received raw: #{trimmed}")
        begin
          request = JSON.parse(trimmed)
          handle_message(request)
        rescue JSON::ParserError => e
          @logger.error("JSON parse error: #{e.message}")
          send_error(nil, -32_700, "Parse error: #{e.message}")
        rescue StandardError => e
          @logger.error("Unexpected error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
          send_error(nil, -32_603, "Internal server error: #{e.message}")
        end
      end
    rescue Interrupt
      @logger.info('Shutting down Tesseract MCP Server gracefully.')
    end

    private

    def handle_message(req)
      id = req['id']
      method = req['method']
      params = req['params'] || {}

      # Notifications (no id)
      if id.nil?
        handle_notification(method, params)
        return
      end

      case method
      when 'initialize'
        handle_initialize(id, params)
      when 'ping'
        send_response(id, {})
      when 'tools/list'
        send_response(id, { tools: Tools::TOOLS_LIST })
      when 'tools/call'
        handle_tool_call(id, params)
      when 'resources/list'
        handle_resources_list(id, params)
      when 'resources/read'
        handle_resources_read(id, params)
      when 'prompts/list'
        send_response(id, { prompts: Prompts::PROMPTS_LIST })
      when 'prompts/get'
        handle_prompts_get(id, params)
      else
        @logger.warn("Method not found: #{method}")
        send_error(id, -32_601, "Method not found: #{method}")
      end
    end

    def handle_notification(method, _params)
      case method
      when 'notifications/initialized'
        @logger.info('Client connection initialized successfully.')
      when 'notifications/cancelled'
        @logger.info('Client cancelled request.')
      else
        @logger.debug("Received notification: #{method}")
      end
    end

    def handle_initialize(id, params)
      client_info = params['clientInfo'] || {}
      @logger.info("Connected to client: #{client_info['name']} v#{client_info['version']}")

      send_response(id, {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: {
          tools: {},
          resources: {},
          prompts: {}
        },
        serverInfo: {
          name: SERVER_NAME,
          version: SERVER_VERSION
        }
      })
    end

    def handle_tool_call(id, params)
      tool_name = params['name']
      arguments = params['arguments'] || {}
      @logger.info("Executing tool: #{tool_name} with #{arguments.keys.join(', ')}")

      result = Tools.handle_tool_call(@store, tool_name, arguments)
      send_response(id, result)
    rescue StandardError => e
      @logger.error("Tool execution failed: #{e.message}")
      send_response(id, {
        content: [{ type: 'text', text: "Error executing tool #{tool_name}: #{e.message}" }],
        isError: true
      })
    end

    def handle_resources_list(id, _params)
      resources = [
        {
          uri: 'tesseract://global/index',
          name: 'Global Knowledge Index',
          mimeType: 'text/markdown',
          description: 'Master index and context for global personal knowledge'
        }
      ]

      current_domain = @store.current_domain_name
      if current_domain && current_domain != 'global'
        resources << {
          uri: "tesseract://project/#{current_domain}/index",
          name: "Project Knowledge Index (#{current_domain})",
          mimeType: 'text/markdown',
          description: "Index and files list for current project domain #{current_domain}"
        }
      end

      send_response(id, { resources: resources })
    end

    def handle_resources_read(id, params)
      uri = params['uri'].to_s
      @logger.info("Reading resource: #{uri}")

      if uri =~ %r{\Atesseract://global/(.+)\z}
        topic = Regexp.last_match(1)
        res = @store.read_topic(domain: 'global', topic: topic)
      elsif uri =~ %r{\Atesseract://project/([^/]+)/(.+)\z}
        domain = Regexp.last_match(1)
        topic = Regexp.last_match(2)
        res = @store.read_topic(domain: domain, topic: topic)
      else
        send_error(id, -32_602, "Invalid resource URI: #{uri}")
        return
      end

      if res[:found]
        send_response(id, {
          contents: [
            {
              uri: uri,
              mimeType: 'text/markdown',
              text: res[:content]
            }
          ]
        })
      else
        send_error(id, -32_602, "Resource not found: #{uri}")
      end
    end

    def handle_prompts_get(id, params)
      name = params['name']
      args = params['arguments'] || {}
      prompt = Prompts.get_prompt(name, args)

      if prompt
        send_response(id, prompt)
      else
        send_error(id, -32_602, "Prompt not found: #{name}")
      end
    end

    def send_response(id, result)
      payload = {
        jsonrpc: '2.0',
        id: id,
        result: result
      }
      send_raw(payload)
    end

    def send_error(id, code, message, data = nil)
      payload = {
        jsonrpc: '2.0',
        id: id,
        error: {
          code: code,
          message: message
        }
      }
      payload[:error][:data] = data if data
      send_raw(payload)
    end

    def send_raw(hash)
      json_str = JSON.generate(hash)
      @logger.debug("Sending raw: #{json_str}")
      $stdout.puts(json_str)
      $stdout.flush
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  domains_arg = nil
  cwd_arg = Dir.pwd

  # Simple argument parsing
  ARGV.each_with_index do |arg, i|
    domains_arg = ARGV[i + 1] if arg == '--domains'
    cwd_arg = ARGV[i + 1] if arg == '--cwd'
  end

  server = Tesseract::MCPServer.new(domains_root: domains_arg, cwd: cwd_arg)
  server.start
end
