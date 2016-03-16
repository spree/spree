# encoding: UTF-8
require_relative '../core/lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_backend'
  s.version     = Spree.version
  s.summary     = 'backend e-commerce functionality for the Spree project.'
  s.description = 'Required dependency for Spree'

  s.author      = 'Sean Schofield'
  s.email       = 'sean@spreecommerce.com'
  s.homepage    = 'https://spreecommerce.com'
  s.license     = 'BSD-3'
  s.rubyforge_project = 'spree_backend'

  s.files        = `git ls-files`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_api', s.version
  s.add_dependency 'spree_core', s.version

  s.add_dependency 'bootstrap-sass',  '~> 3.3'
  s.add_dependency 'jquery-rails',    '~> 4.1'
  s.add_dependency 'jquery-ui-rails', '~> 5.0'

  s.add_dependency 'select2-rails',   '3.5.9.1' # 3.5.9.2 breaks several specs
end
