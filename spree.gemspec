# encoding: UTF-8
require_relative 'core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree'
  s.version     = Spree.version
  s.authors     = ['Sean Schofield', 'Spark Solutions']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'Headless API-first open source eCommerce platform'
  s.description = 'A complete open source e-commerce solution with multi-store, multi-currency and multi-language capabilities'
  s.homepage    = 'https://spreecommerce.org'
  s.license     = 'BSD-3-Clause'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://dev-docs.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 2.5'

  s.files        = Dir['README.md', 'lib/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', s.version
  s.add_dependency 'spree_api', s.version
  s.add_dependency 'spree_cli', s.version
end
