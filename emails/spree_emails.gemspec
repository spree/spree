# encoding: UTF-8

require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_emails'
  s.version     = Spree.version
  s.authors     = ['Sean Schofield', 'Spark Solutions Sp. z o.o.', 'Vendo Connect Inc.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'Transactional emails for Spree eCommerce platform'
  s.description = 'Optional transactional emails for Spree such as Order placed or Shipment notification emails'
  s.homepage    = 'https://spreecommerce.org'
  s.licenses    = ['AGPL-3.0-or-later', 'BSD-3-Clause']

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://docs.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version     = '>= 3.0'
  s.required_rubygems_version = '>= 1.8.23'

  s.files        = Dir["{app,config,db,lib,vendor}/**/*", "LICENSE.md", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'

  s.add_dependency 'spree_core', ">= #{s.version}"

  s.add_development_dependency 'email_spec', '~> 2.2'
end
