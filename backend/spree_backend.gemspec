# encoding: UTF-8
require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_backend'
  s.version     = Spree.version
  s.summary     = 'backend e-commerce functionality for the Spree project.'
  s.description = 'Required dependency for Spree'

  s.required_ruby_version = '>= 2.5.0'

  s.author      = 'Sean Schofield'
  s.email       = 'sean@spreecommerce.com'
  s.homepage    = 'http://spreecommerce.org'
  s.license     = 'BSD-3-Clause'

  s.files        = `git ls-files`.split("\n").reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_api', s.version
  s.add_dependency 'spree_core', s.version

  s.add_dependency 'bootstrap',       '~> 4.3.1'
  s.add_dependency 'glyphicons',      '~> 1.0.2'
  s.add_dependency 'jquery-rails',    '~> 4.3'
  s.add_dependency 'jquery-ui-rails', '~> 6.0.1'
  s.add_dependency 'select2-rails',   '~> 3.5.0'
end
