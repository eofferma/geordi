# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "geordi/version"

Gem::Specification.new do |s|
  s.name        = "geordi"
  s.version     = Geordi::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Henning Koch"]
  s.email       = ["henning.koch@makandra.de"]
  s.homepage    = "http://makandra.com"
  s.summary     = 'Fix: Collection of command line tools we use in our daily work with Ruby, Rails and Linux at makandra.'
  s.description = 'Fix: Collection of command line tools we use in our daily work with Ruby, Rails and Linux at makandra.'

  s.rubyforge_project = "geordi"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.add_dependency 'pivotal-tracker', '0.5.10'
  s.add_dependency 'tzinfo', '0.3.37'
  s.add_dependency 'highline', '1.6.15'
  s.add_dependency 'activesupport', '3.2.9'
  s.add_dependency 'git', '1.2.5'
  s.add_dependency(%q<httparty>, ["~> 0.7.4"])
  s.add_dependency(%q<oauth2>)
  s.add_dependency(%q<json>, ["~> 1.8.1"])
  s.require_paths = ["lib"]
end
