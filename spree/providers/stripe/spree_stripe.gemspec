# encoding: UTF-8

require_relative '../../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_stripe'
  s.version     = Spree.version
  s.authors     = ['Vendo Connect Inc.', 'Vendo Sp. z o.o.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'Official Stripe & Stripe Connect payment gateway for Spree Commerce'
  s.description = 'Supports credit cards, wallets (Apple Pay/Google pay), pay-now-pay-later, regional payment methods and marketplace workflows with Stripe Connect. Fully PCI compliant'
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

  s.add_dependency 'spree_core', s.version
  s.add_dependency 'stripe', '>= 10.1', '< 20'

  s.add_development_dependency 'vcr'
end
