# encoding: UTF-8

require_relative '../../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_easypost'
  s.version     = Spree.version
  s.authors     = ['Spark Solutions Sp. z o.o.', 'Vendo Connect Inc.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'EasyPost delivery rates for Spree eCommerce platform'
  s.description = 'Live multi-carrier delivery rates for Spree via EasyPost — the reference DeliveryRateProvider implementation'
  s.homepage    = 'https://spreecommerce.org'
  s.license     = 'BSD-3-Clause'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://docs.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 3.2'

  s.files        = Dir["{app,config,db,lib,vendor}/**/*", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'

  s.add_dependency 'easypost', '~> 7.0'
  s.add_dependency 'spree_core', ">= #{s.version}"

  s.add_development_dependency 'vcr'
end
