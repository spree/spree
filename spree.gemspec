# encoding: UTF-8
require_relative 'core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree'
  s.version     = Spree.version
  s.authors     = ['Sean Schofield', 'Spark Solutions']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'Full-stack e-commerce framework for Ruby on Rails.'
  s.description = 'Spree is an open source e-commerce framework for Ruby on Rails. Join us on http://slack.spreecommerce.org'
  s.homepage    = 'https://spreecommerce.org'
  s.license     = 'BSD-3-Clause'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://guides.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 2.5.0'

  s.files        = Dir['README.md', 'lib/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', s.version
  s.add_dependency 'spree_api', s.version
  s.add_dependency 'spree_backend', s.version
  s.add_dependency 'spree_frontend', s.version
  s.add_dependency 'spree_sample', s.version
  s.add_dependency 'spree_cmd', s.version
end
