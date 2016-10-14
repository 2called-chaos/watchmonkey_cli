# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'watchmonkey_cli/version'

Gem::Specification.new do |spec|
  spec.name          = "watchmonkey_cli"
  spec.version       = WatchmonkeyCli::VERSION
  spec.authors       = ["Sven Pachnit"]
  spec.email         = ["sven@bmonkeys.net"]
  spec.summary       = %q{Watchmonkey CLI - dead simple agentless monitoring via SSH, HTTP, FTP, etc.}
  spec.description   = %q{If you want an easy way to monitor services without the need of installing agents let a monkey do the job by polling status information via transport protocols.}
  spec.homepage      = "https://github.com/2called-chaos/watchmonkey_cli"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "pry"
  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "httparty"
end
