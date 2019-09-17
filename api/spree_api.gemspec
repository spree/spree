# -*- encoding: utf-8 -*-
require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.authors       = ["Ryan Bigg"]
  s.email         = ["ryan@spreecommerce.com"]
  s.description   = %q{Spree's API}
  s.summary       = %q{Spree's API}
  s.homepage      = 'http://spreecommerce.org'
  s.license       = 'BSD-3-Clause'

  s.required_ruby_version = '>= 2.5.0'

  s.files         = `git ls-files`.split($\).reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.name          = "spree_api"
  s.require_paths = ["lib"]
  s.version       = Spree.version

  s.add_development_dependency 'jsonapi-rspec'

  s.add_dependency 'spree_core', s.version
  s.add_dependency 'rabl', '~> 0.14.2'
  s.add_dependency 'fast_jsonapi', '~> 1.5'
  s.add_dependency 'doorkeeper', '~> 5.2', '>= 5.2.1'
end
