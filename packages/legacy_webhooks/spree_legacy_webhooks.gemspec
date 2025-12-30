# frozen_string_literal: true

require_relative '../../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_legacy_webhooks'
  s.version     = Spree.version
  s.authors     = ['Spark Solutions Sp. z o.o.', 'Vendo Connect Inc.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'Legacy webhooks system for Spree Commerce'
  s.description = 'HTTP webhooks for Spree Commerce using the legacy callback-based system. Consider migrating to the new event-based webhooks in spree_api.'
  s.homepage    = 'https://spreecommerce.org'
  s.licenses    = ['AGPL-3.0-or-later', 'BSD-3-Clause']

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://docs.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version     = '>= 3.2'

  s.files        = Dir["{app,config,db,lib}/**/*", "LICENSE.md", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'

  s.add_dependency 'spree_core', ">= #{s.version}"
  s.add_dependency 'spree_api', ">= #{s.version}"
  s.add_dependency 'spree_admin', ">= #{s.version}"
end
