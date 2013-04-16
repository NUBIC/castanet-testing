require 'castanet/testing'
require 'castanet/testing/asset_paths'
require 'castanet/testing/common_tasks'
require 'castanet/testing/namespacing'
require 'erb'
require 'json'
require 'rake'
require 'shellwords'
require 'openssl'
require 'uri'

module Castanet::Testing
  class JasigServerTasks
    extend AssetPaths
    include CommonTasks
    include Rake::DSL
    include Namespacing
    include Shellwords

    DEFAULT_SCRATCH_DIR = '/tmp/castanet-testing/jasig'
    DEFAULT_JASIG_URL = 'http://downloads.jasig.org/cas/cas-server-3.5.2-release.tar.gz'
    DEFAULT_JETTY_URL = 'http://archive.eclipse.org/jetty/8.1.7.v20120910/dist/jetty-distribution-8.1.7.v20120910.tar.gz'
    DEFAULT_JASIG_CHECKSUM = 'e93e05acad4975c5caa1c20dff7c57ff8e846253bbf68ea8a5fc0199ce608cba'
    DEFAULT_JETTY_CHECKSUM = 'a65d20367839bf3df7d32a05992678487ba8daeebb41d9833975aee46ffe86c2'
    DEFAULT_MOUNT_POINT = '/cas'
    DEFAULT_HOST = 'localhost'
    DEFAULT_SSL_KEY = ssl_key_path
    DEFAULT_SSL_CERT = ssl_cert_path
    DEFAULT_TIMEOUT = 120

    JETTY_SSL_CONFIG_TEMPLATE = asset_path('jasig/jetty.xml.erb')
    JETTY_CONFIG_PATCHFILE = asset_path('jasig/jetty.xml.patch')
    RUNNER = asset_path('jasig/run.sh')

    ##
    # This is a ridiculous amount of setup for a CAS server.
    #
    # @option opts [String] :root ('castanet:testing:jasig') namespaces for
    #   this task; an empty string means toplevel namespace
    # @option opts [String] :scratch_dir ('/tmp/castanet-testing/jasig') sets
    #   a path for downloads, server scratch space, etc.
    # @option opts [String] :jasig_url (DEFAULT_JASIG_URL) the Jasig CAS Server
    #   package to download
    # @option opts [String] :jasig_checksum (DEFAULT_JASIG_CHECKSUM) SHA256
    #   checksum of the CAS package
    # @option opts [String] :jetty_url (DEFAULT_JETTY_URL) the Jetty
    #   distribution to download
    # @option opts [String] :jetty_checksum (DEFAULT_JETTY_CHECKSUM) SHA256
    #   checksum of the Jetty package
    # @option opts [String] :mount_point ('/cas') where the CAS server will be
    #   mounted
    # @option opts [String] :host ('localhost') hostname to bind
    # @option opts [String] :ssl_cert (DEFAULT_SSL_CERT) the SSL certificate
    #   file to use
    # @option opts [String] :ssl_key (DEFAULT_SSL_KEY) the SSL key file to use
    # @option opts [String] :timeout (DEFAULT_TIMEOUT) timeout for waitall
    def initialize(options = {})
      root = options[:root] || 'castanet:testing:jasig'
      scratch_dir = options[:scratch_dir] || DEFAULT_SCRATCH_DIR
      jasig_url = options[:jasig_url] || DEFAULT_JASIG_URL
      jasig_checksum = options[:jasig_checksum] || DEFAULT_JASIG_CHECKSUM
      jetty_url = options[:jetty_url] || DEFAULT_JETTY_URL
      jetty_checksum = options[:jetty_checksum] || DEFAULT_JETTY_CHECKSUM
      mount_point = options[:mount_point] || DEFAULT_MOUNT_POINT
      host = options[:host] || DEFAULT_HOST
      ssl_cert = options[:ssl_cert] || DEFAULT_SSL_CERT
      ssl_key = options[:ssl_key] || DEFAULT_SSL_KEY
      timeout = options[:timeout] || DEFAULT_TIMEOUT

      instance_dir = "#{scratch_dir}/jasig.#{$$}"
      port = ENV['PORT']

      jasig_fn = URI.parse(jasig_url).path.split('/').last
      jasig_package_dest = "#{scratch_dir}/#{jasig_fn}"
      jasig_extract_dest = "#{scratch_dir}/#{jasig_fn}-extract"
      jasig_war_filename = mount_point.split('/').last + '.war'

      jasig_package_name = lambda do
        FileList["#{jasig_extract_dest}/modules/cas-server-uber-webapp*.war"].first
      end

      jetty_fn = URI.parse(jetty_url).path.split('/').last
      jetty_package_dest = "#{scratch_dir}/#{jetty_fn}"
      jetty_war_filename = mount_point.split('/').last + '.war'

      jetty_package_name = lambda do
        FileList["#{instance_dir}/modules/cas-server-uber-webapp*.war"].first
      end

      jetty_keystore = "#{instance_dir}/jetty.ks"
      jetty_storepass = "secret"
      jetty_ssl_config = "#{jetty_package_dest}/etc/jetty-cas-ssl.xml"

      namespaces(root.split(':')) do
        file jasig_package_dest do
          mkdir_p scratch_dir
          sh "curl -s #{e jasig_url} > #{e jasig_package_dest}"
          verify_checksum(jasig_package_dest, jasig_checksum)
        end

        file jetty_package_dest do
          mkdir_p scratch_dir
          sh "curl -s #{e jetty_url} > #{e jetty_package_dest}"
          verify_checksum(jetty_package_dest, jetty_checksum)
        end

        file jasig_extract_dest do
          mkdir_p jasig_extract_dest
          sh "tar xf #{e jasig_package_dest} -C #{e jasig_extract_dest} --strip-components 1"
        end

        file instance_dir do
          mkdir_p instance_dir
          sh "tar xf #{e jetty_package_dest} -C #{e instance_dir} --strip-components 1"
        end

        task :ensure_port do
          raise "PORT is not set" unless port
        end

        desc 'Download the CAS server'
        task :download => [jasig_package_dest, jasig_extract_dest, jetty_package_dest]

        task :prep => [:download, :ensure_port, instance_dir] do
          mkdir_p instance_dir
          cp jasig_package_name.call, "#{instance_dir}/webapps/#{jasig_war_filename}"

          sh %Q{openssl pkcs12 -inkey #{e ssl_key} -in #{e ssl_cert} -export \
                -out #{e "#{instance_dir}/jetty.pkcs12"} \
                -password #{e "pass:#{jetty_storepass}"}}

          sh %Q{keytool -destkeystore #{e jetty_keystore} -importkeystore \
                -srckeystore #{e "#{instance_dir}/jetty.pkcs12"} \
                -srcstoretype PKCS12 -srcstorepass #{e jetty_storepass} \
                -storepass #{e jetty_storepass} -noprompt}

          ssl_config = ERB.new(File.read(JETTY_SSL_CONFIG_TEMPLATE)).result(binding)
          ssl_file = "#{instance_dir}/etc/jetty-cas-ssl.xml"

          File.open(ssl_file, 'w') { |f| f.write(ssl_config) }

          ini = File.read("#{instance_dir}/start.ini")

          unless ini.include?(ssl_file)
            File.open("#{instance_dir}/start.ini", 'a+') do |f|
              f.write(ssl_file)
            end
          end

          # Delete the default connector.
          patchfile = File.expand_path('../jetty.xml.patch', __FILE__)

          cd "#{instance_dir}/etc" do
            sh "patch -p1 < #{e JETTY_CONFIG_PATCHFILE}"
          end
        end

        desc 'Start a Jasig CAS Server instance (requires PORT to be set)'
        task :start => :prep do
          cd(instance_dir) { exec 'java -jar start.jar' }
        end

        desc "Wait for all Jasig CAS Server instances in #{scratch_dir} to become ready"
        task(:waitall) { wait_all(scratch_dir, timeout) }

        desc "Clean up all Jasig CAS Server instances under #{scratch_dir}"
        task(:cleanall) { clean_all(scratch_dir, 'jasig') }

        desc "Delete #{scratch_dir}"
        task :delete_scratch_dir do
          rm_rf scratch_dir
        end
      end
    end

    private

    alias_method :e, :shellescape

    def verify_checksum(fn, expected)
      sha = OpenSSL::Digest::SHA256.new

      File.open(fn, 'r') do |f|
        until f.eof?
          sha << f.read(65536)
        end
      end

      actual = sha.to_s
      raise "checksum mismatch: #{actual} != #{expected}" if actual != expected
    end
  end
end
