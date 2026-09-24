# encoding: UTF-8
require_relative 'core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree'
  s.version     = Spree.version
  s.authors     = ['Sean Schofield', 'Spark Solutions Sp. z o.o.', 'Vendo Connect Inc.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'Open Source B2B eCommerce and Marketplace platform'
  s.description = 'Open Source Platform for DTC, B2B Commerce, Marketplaces & Omnichannel. REST APIs, TypeScript SDKs, and production-ready Next.js storefront. Self-host it. Own your data. No vendor lock-in. Zero platform fees.'
  s.homepage    = 'https://spreecommerce.org'
  s.license     = 'BSD-3-Clause'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://docs.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 3.2'

  s.files        = Dir['LICENSE', 'README.md', 'lib/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', s.version
  s.add_dependency 'spree_api', s.version
end
