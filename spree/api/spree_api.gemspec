require_relative '../core/lib/spree/core/version'

Gem::Specification.new do |s|
  s.name          = 'spree_api'
  s.version       = Spree.version
  s.authors       = ['Vendo Connect Inc.']
  s.email         = ['hello@spreecommerce.org']
  s.summary       = %q{Spree's API}
  s.description   = %q{Spree's API}
  s.homepage      = 'https://spreecommerce.org'
  s.licenses       = ['AGPL-3.0-or-later']

  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/spree/spree/issues',
    'changelog_uri' => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    'documentation_uri' => 'https://docs.spreecommerce.org/',
    'source_code_uri' => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 3.2'

  s.files         = Dir["{app,config,db,lib,vendor}/**/*", "LICENSE.md", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_paths = ['lib']

  s.add_development_dependency 'rswag-specs'

  s.add_dependency 'alba', '~> 3.0'
  s.add_dependency 'oj', '~> 3.16'
  s.add_dependency 'pagy', '~> 43.0'
  s.add_dependency 'typelizer', '~> 0.8'

  s.add_dependency 'spree_core', s.version
end
