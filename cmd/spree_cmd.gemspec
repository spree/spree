# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.name        = "spree_cmd"
  s.version     = Spree.version
  s.authors     = ['Chris Mar']
  s.email       = ['chris@spreecommerce.com']
  s.homepage    = 'http://spreecommerce.org'
  s.license     = 'BSD-3-Clause'
  s.summary     = 'Spree Commerce command line utility'
  s.description = 'tools to create new Spree stores and extensions'

  s.files         = `git ls-files`.split("\n").reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.bindir        = 'bin'
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_development_dependency 'rspec'
  # Temporary hack until https://github.com/wycats/thor/issues/234 is fixed
  s.add_dependency 'thor', '~> 0.14'
end
