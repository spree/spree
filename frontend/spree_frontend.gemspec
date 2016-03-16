# encoding: UTF-8
require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_frontend'
  s.version     = Spree.version
  s.summary     = 'Frontend e-commerce functionality for the Spree project.'
  s.description = s.summary

  s.author      = 'Sean Schofield'
  s.email       = 'sean@spreecommerce.com'
  s.homepage    = 'https://spreecommerce.com'
  s.license     = 'BSD-3'

  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_api', s.version
  s.add_dependency 'spree_core', s.version

  s.add_dependency 'bootstrap-sass',  '>= 3.3.5.1', '< 3.4'
  s.add_dependency 'canonical-rails', '~> 0.0.4'
  s.add_dependency 'jquery-rails',    '~> 4.1'

  s.add_development_dependency 'capybara-accessible'
end
