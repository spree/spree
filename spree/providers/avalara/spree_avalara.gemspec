# encoding: UTF-8

require_relative '../../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_avalara'
  s.version     = Spree.version
  s.authors     = ['Spark Solutions Sp. z o.o.', 'Vendo Connect Inc.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'The official certified Avalara AvaTax extension for Spree Commerce'
  s.description = 'The officially supported Avalara AvaTax extension for Spree Commerce using Avalara REST API v2 — ' \
                  'sales tax, VAT and GST calculation, exemptions, address validation and document filing'
  s.homepage    = 'https://spreecommerce.org'
  s.license     = 'MIT'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    'documentation_uri' => 'https://spreecommerce.org/docs/integrations/tax/avalara',
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 3.2'

  s.files        = Dir['{app,config,db,lib,vendor}/**/*', 'Rakefile', 'LICENSE', 'README.md']
  s.require_path = 'lib'

  s.add_dependency 'avatax', '>= 19.3'
  s.add_dependency 'spree_core', s.version

  s.add_development_dependency 'vcr'
end
