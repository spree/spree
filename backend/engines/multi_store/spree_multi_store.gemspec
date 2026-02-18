# encoding: UTF-8

require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_multi_store'
  s.version     = Spree.version
  s.authors     = ['Vendo Connect Inc.', 'Vendo Sp. z o.o.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'Multi-store switching and resolution for Spree Commerce'
  s.description = 'Adds multi-store switching, custom domains, and store resolution to Spree Commerce'
  s.homepage    = 'https://spreecommerce.org'
  s.licenses    = ['AGPL-3.0-or-later']

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://docs.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 3.2'

  s.files        = Dir["{app,config,lib}/**/*", "LICENSE.md", "Rakefile", "README.md"]
  s.require_path = 'lib'

  s.add_dependency 'spree', s.version
end
