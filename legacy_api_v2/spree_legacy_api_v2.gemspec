require_relative '../core/lib/spree/core/version'

Gem::Specification.new do |s|
  s.name          = 'spree_legacy_api_v2'
  s.version       = Spree.version
  s.authors       = ['Ryan Bigg', 'Spark Solutions Sp. z o.o.', 'Vendo Connect Inc.']
  s.email         = ['hello@spreecommerce.org']
  s.summary       = %q{Spree's Legacy API v2}
  s.description   = %q{Legacy API v2 endpoints for Spree Commerce.}
  s.homepage      = 'https://spreecommerce.org'
  s.licenses      = ['AGPL-3.0-or-later', 'BSD-3-Clause']

  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/spree/spree/issues',
    'changelog_uri' => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    'documentation_uri' => 'https://docs.spreecommerce.org/',
    'source_code_uri' => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 3.2'

  s.files         = Dir["{app,config,db,lib,vendor}/**/*", "LICENSE.md", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_paths = ['lib']

  s.add_development_dependency 'jsonapi-rspec'
  s.add_development_dependency 'multi_json'

  s.add_dependency 'doorkeeper', '~> 5.3'
  s.add_dependency 'jsonapi-serializer', '~> 2.1'
  s.add_dependency 'pagy', '~> 43.0'

  s.add_dependency 'spree', s.version
end
