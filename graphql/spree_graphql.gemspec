# -*- encoding: utf-8 -*-
require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.authors       = ['Spark Solutions']
  s.email         = ['we@sparksolutions.co']
  s.description   = %q{GraphQL API for Spree Commerce}
  s.summary       = %q{GraphQL API for Spree Commerce}
  s.homepage      = 'https://spreecommerce.org'
  s.license       = 'BSD-3-Clause'

  s.required_ruby_version = '>= 2.5.0'

  s.files         = `git ls-files`.split($\).reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  s.name          = 'spree_graphql'
  s.require_paths = ['lib']
  s.version       = Spree.version

  s.add_dependency 'spree_core', s.version
  s.add_dependency 'graphql', '~> 1.9'
  s.add_dependency 'jwt', '~> 2.2'
end
