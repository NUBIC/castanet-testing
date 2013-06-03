require 'castanet/testing'
require 'castanet/testing/connection_testing'
require 'json'
require 'rake'
require 'timeout'

module Castanet::Testing
  module CommonTasks
    include Castanet::Testing::ConnectionTesting
    include Rake::DSL

    def wait_all(scratch_dir, timeout)
      Timeout.timeout(timeout) do
        loop do
          urls = Dir["#{scratch_dir}/**/.urls"].map { |x| JSON.parse(File.read(x))['status'] }
          urls.reject! { |u| responding?(u) }
          break true if urls.empty?
          sleep 1
        end
      end
    end
    
    def clean_all(scratch_dir, prefix)
      files = FileList["#{scratch_dir}/#{prefix}.*"]

      rm_rf files unless files.empty?
    end
  end
end
