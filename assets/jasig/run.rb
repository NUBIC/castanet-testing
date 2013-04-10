#!/usr/bin/env ruby

require 'fileutils'

include FileUtils

instance_dir = ARGV[0]
cleanup = lambda { |sig| Process.kill('TERM', $pid) }

trap('TERM', &cleanup)
trap('QUIT', &cleanup)
trap('INT', &cleanup)

$pid = Process.spawn('bin/jetty.sh', 'run', :chdir => instance_dir)

Process.wait $pid

rm_rf instance_dir, :verbose => true
