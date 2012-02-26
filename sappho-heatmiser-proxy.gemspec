# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "sappho-heatmiser-proxy/version"

# See http://docs.rubygems.org/read/chapter/20#page85 for info on writing gemspecs

Gem::Specification.new do |s|
  s.name        = "sappho-heatmiser-proxy"
  s.version     = Sappho::Heatmiser::Proxy::VERSION
  s.authors     = ["Andrew Heald"]
  s.email       = ["andrew@heald.co.uk"]
  s.homepage    = Sappho::Heatmiser::Proxy::HOMEPAGE
  s.summary     = "Acts as a proxy for Heatmiser hardware to allow continuous monitoring and control by many controllers"
  s.description = "See the project home page for more information"

  s.rubyforge_project = "sappho-heatmiser-proxy"

  s.files         = `git ls-files -- {bin,lib}/*`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # specify any dependencies here; for example:
  # s.add_development_dependency "rspec"
  # s.add_runtime_dependency "rest-client"
  s.add_development_dependency 'rake', '>= 0.9.2.2'

end
