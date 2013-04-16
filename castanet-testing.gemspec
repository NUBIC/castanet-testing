# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'castanet/testing/version'

Gem::Specification.new do |spec|
  spec.name          = "castanet-testing"
  spec.version       = Castanet::Testing::VERSION
  spec.authors       = ["David Yip"]
  spec.email         = ["yipdw@northwestern.edu"]
  spec.summary       = %q{Contains Rake tasks for managing CAS servers in test environments}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "foreman", "0.63.0"
  spec.add_development_dependency "yard"
  spec.add_dependency "json"
  spec.add_dependency "rack"
  spec.add_dependency "rake", "~> 10.0"
end
