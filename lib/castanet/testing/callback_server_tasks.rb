require 'castanet/testing'
require 'castanet/testing/asset_paths'
require 'castanet/testing/common_tasks'
require 'castanet/testing/namespacing'
require 'rake'

module Castanet::Testing
  class CallbackServerTasks
    extend AssetPaths
    include CommonTasks
    include Namespacing
    include Rake::DSL

    DEFAULT_SCRATCH_DIR = '/tmp/castanet-testing/callback'
    DEFAULT_HOST = 'localhost'
    DEFAULT_SSL_KEY = ssl_key_path
    DEFAULT_SSL_CERT = ssl_cert_path
    DEFAULT_TIMEOUT = 120

    CALLBACK_PATH = asset_path('callback/callback.rb')
    RUNNER = asset_path('run.rb')

    # @option opts [String] :root ('castanet:testing:callback') namespaces for
    #   this task; an empty string means toplevel namespace
    # @option opts [String] :scratch_dir ('/tmp/castanet-testing/callback')
    #   sets a path for downloads, server scratch space, etc.
    # @option opts [String] :host ('localhost') hostname to bind
    # @option opts [String] :ssl_cert (DEFAULT_SSL_CERT) the SSL certificate
    #   file to use
    # @option opts [String] :ssl_key (DEFAULT_SSL_KEY) the SSL key file to use
    # @option opts [String] :timeout (DEFAULT_TIMEOUT) timeout for waitall
    def initialize(options = {})
      root = options[:root] || 'castanet:testing:callback'
      scratch_dir = options[:scratch_dir] || DEFAULT_SCRATCH_DIR
      host = options[:host] || DEFAULT_HOST
      ssl_cert = options[:ssl_cert] || DEFAULT_SSL_CERT
      ssl_key = options[:ssl_key] || DEFAULT_SSL_KEY
      timeout = options[:timeout] || DEFAULT_TIMEOUT

      port = ENV['PORT']
      instance_dir = "#{scratch_dir}/callback.#{$$}"

      namespaces(root.split(':')) do
        file instance_dir do
          mkdir_p instance_dir
        end

        task :ensure_port do
          raise "PORT is not set" unless port
        end

        task :write_url => instance_dir do
          cd instance_dir do
            server_url = "https://#{host}:#{port}"
            data = {
              status: "#{server_url}/",
              retrieval: "#{server_url}/retrieve_pgt",
              callback: "#{server_url}/receive_pgt"
            }

            File.open('.urls', 'w') { |f| f.write(data.to_json) }
          end
        end

        task :prep => [:ensure_port, :write_url]

        desc 'Start a CAS proxy callback instance (requires PORT to be set)'
        task :start => :prep do
          ENV['HOST'] = host
          ENV['SSL_CERT_PATH'] = ssl_cert
          ENV['SSL_KEY_PATH'] = ssl_key

          handler = lambda do |*|
            rm_rf(instance_dir, :verbose => true)
            exit! 0
          end

          trap('TERM', &handler)
          trap('INT', &handler)
          trap('QUIT', &handler) unless RUBY_PLATFORM =~ /java/

          load CALLBACK_PATH
        end

        desc "Wait for all CAS proxy callback instances in #{scratch_dir} to become ready"
        task(:waitall) { wait_all(scratch_dir, timeout) }

        desc "Clean up all CAS proxy callback instances under #{scratch_dir}"
        task(:cleanall) { clean_all(scratch_dir, 'callback') }

        desc "Delete #{scratch_dir}"
        task :delete_scratch_dir do
          rm_rf scratch_dir
        end
      end
    end
  end
end
