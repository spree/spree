# encoding: UTF-8
require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_frontend'
  s.version     = Spree.version
  s.authors     = ['Sean Schofield', 'Spark Solutions']
  s.email       = 'hello@spreecommerce.org'
  s.summary     = 'Frontend e-commerce functionality for the Spree project.'
  s.description = s.summary
  s.homepage    = 'https://spreecommerce.org'
  s.license     = 'BSD-3-Clause'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/spree/spree/issues",
    "changelog_uri"     => "https://github.com/spree/spree/releases/tag/v#{s.version}",
    "documentation_uri" => "https://guides.spreecommerce.org/",
    "source_code_uri"   => "https://github.com/spree/spree/tree/v#{s.version}",
  }

  s.required_ruby_version = '>= 2.5'

  s.files        = `git ls-files`.split("\n").reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_api', ">= #{s.version}"
  s.add_dependency 'spree_core', ">= #{s.version}"

  s.add_dependency 'babel-transpiler', '~> 0.7'
  s.add_dependency 'bootstrap',       '>= 4', '< 6'
  s.add_dependency 'glyphicons',      '~> 1.0'
  s.add_dependency 'canonical-rails', '~> 0.2', '>= 0.2.10'
  s.add_dependency 'inline_svg',      '~> 1.5'
  s.add_dependency 'jquery-rails',    '~> 4.3'
  s.add_dependency 'sass-rails',      '>= 5'
  s.add_dependency 'turbolinks',      '~> 5.2'
  s.add_dependency 'responders'
  s.add_dependency 'sprockets', '~> 4.0'

  s.add_development_dependency 'capybara-accessible'
end
