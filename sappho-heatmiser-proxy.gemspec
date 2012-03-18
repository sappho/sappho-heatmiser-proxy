# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "sappho-heatmiser-proxy/version"

# See http://docs.rubygems.org/read/chapter/20#page85 for info on writing gemspecs

Gem::Specification.new do |s|
  s.name        = Sappho::Heatmiser::Proxy::NAME
  s.version     = Sappho::Heatmiser::Proxy::VERSION
  s.authors     = Sappho::Heatmiser::Proxy::AUTHORS
  s.email       = Sappho::Heatmiser::Proxy::EMAILS
  s.homepage    = Sappho::Heatmiser::Proxy::HOMEPAGE
  s.summary     = Sappho::Heatmiser::Proxy::SUMMARY
  s.description = Sappho::Heatmiser::Proxy::DESCRIPTION

  s.rubyforge_project = Sappho::Heatmiser::Proxy::NAME

  s.files         = Dir['bin/*'] + Dir['lib/**/*']
  s.test_files    = Dir['test/**/*'] + Dir['spec/**/*'] + Dir['features/**/*']
  s.executables   = Dir['bin/*'].map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
  s.add_development_dependency 'rake', '>= 0.9.2.2'
  s.add_dependency 'sappho-socket', '>= 0.1.0'
  s.add_dependency 'sappho-basics', '>= 0.1.0'
end
