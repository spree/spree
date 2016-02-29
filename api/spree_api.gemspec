# -*- encoding: utf-8 -*-
require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.authors       = ["Ryan Bigg"]
  s.email         = ["ryan@spreecommerce.com"]
  s.description   = %q{Spree's API}
  s.summary       = %q{Spree's API}
  s.homepage      = 'https://spreecommerce.com'
  s.license       = 'BSD-3'

  s.files         = `git ls-files`.split($\)
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.name          = "spree_api"
  s.require_paths = ["lib"]
  s.version       = Spree.version

  s.add_dependency 'spree_core', s.version
  s.add_dependency 'rabl', '~> 0.11.6'
  s.add_dependency 'versioncake', '~> 2.3.1'
end
