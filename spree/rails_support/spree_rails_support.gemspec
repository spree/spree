# encoding: UTF-8

require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_rails_support'
  s.version     = Spree.version
  s.authors     = ['Sean Schofield', 'Spark Solutions Sp. z o.o.', 'Vendo Connect Inc.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'Rails view helpers, presenters and controller concerns for Spree storefronts'
  s.description = 'Optional Rails presenters, finders and controller helpers for building traditional server-rendered Spree storefronts'
  s.homepage    = 'https://spreecommerce.org'
  s.license     = 'BSD-3-Clause'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://docs.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 3.2'

  s.files        = Dir["{app,config,lib}/**/*", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) }
  s.require_path = 'lib'

  s.add_dependency 'spree_core', ">= #{s.version}"
end
