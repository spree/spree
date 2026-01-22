require_relative '../core/lib/spree/core/version'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_page_builder'
  s.version     = Spree.version
  s.authors     = ['Vendo Connect Inc.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'Visual Page Builder for Spree Commerce'
  s.description = 'Visual page builder and theme management for Spree Commerce storefronts'
  s.homepage    = 'https://getvendo.com'
  s.license     = 'AGPL-3.0-or-later'

  s.metadata = {
    'bug_tracker_uri' => 'https://github.com/spree/spree/issues',
    'changelog_uri' => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    'documentation_uri' => 'https://docs.spreecommerce.org/',
    'source_code_uri' => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version     = '>= 3.2'

  s.files        = Dir["{app,config,db,lib,vendor}/**/*", "LICENSE.md", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'

  s.add_dependency 'spree', ">= #{s.version}"
  s.add_dependency 'spree_admin', ">= #{s.version}"
end
