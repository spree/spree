# encoding: UTF-8

require_relative '../../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_vies'
  s.version     = Spree.version
  s.authors     = ['Vendo Connect Inc.', 'Vendo Sp. z o.o.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'EU VAT number verification against VIES for Spree eCommerce platform'
  s.description = "Asks the EU VIES registry whether a customer's VAT number is registered, and records the evidence"
  s.homepage    = 'https://spreecommerce.org'
  s.license     = 'MIT'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://docs.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 3.2'

  s.files        = Dir["{app,config,db,lib,vendor}/**/*", "Rakefile", "LICENSE", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'

  s.add_dependency 'valvat', '~> 2.0'
  s.add_dependency 'spree_core', s.version
end
