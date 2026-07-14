# encoding: UTF-8

require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_dashboard'
  s.version     = Spree.version
  s.authors     = ['Vendo Connect Inc.']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'Hosts the Spree React Dashboard from your Spree server'
  s.description = 'Serves a built Spree React Dashboard at /dashboard with SPA semantics — the single-node topology where the dashboard and the Admin API share one origin. Developer Preview; becomes the default admin delivery in Spree 6.'
  s.homepage    = 'https://spreecommerce.org'
  s.license     = 'BSD-3-Clause'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://spreecommerce.org/docs/developer/dashboard/deployment",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 3.2'

  s.files        = Dir["{app,config,lib,vendor}/**/*", "Rakefile", "README.md"].reject { |f| f.match(/^spec/) }
  s.require_path = 'lib'

  s.add_dependency 'spree', ">= #{s.version}"
end
