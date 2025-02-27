require_relative '../core/lib/spree/core/version'

Gem::Specification.new do |s|
  s.name          = 'spree_api'
  s.version       = Spree.version
  s.authors       = ['Ryan Bigg', 'Spark Solutions Sp. z o.o.', 'Vendo Connect Inc.']
  s.email         = ['hello@spreecommerce.org']
  s.summary       = %q{Spree's API}
  s.description   = %q{Spree's API}
  s.homepage      = 'https://spreecommerce.org'
  s.licenses       = ['AGPL-3.0-or-later', 'BSD-3-Clause']

  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/spree/spree/issues',
    'changelog_uri' => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    'documentation_uri' => 'https://docs.spreecommerce.org/',
    'source_code_uri' => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 3.0'

  s.files        = Dir["{app,config,db,lib}/**/*", "LICENSE.md", "Rakefile"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.executables   = s.files.grep(%r{^bin/}).map { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_development_dependency 'jsonapi-rspec'
  s.add_development_dependency 'multi_json'
  s.add_development_dependency 'rswag-specs'

  s.add_dependency 'bcrypt', '~> 3.1'
  s.add_dependency 'doorkeeper', '~> 5.3'
  s.add_dependency 'jsonapi-serializer', '~> 2.1'
  s.add_dependency 'spree_core', s.version
end
