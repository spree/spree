# encoding: UTF-8
version = File.read(File.expand_path("../../SPREE_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_frontend'
  s.version     = version
  s.summary     = 'Frontend e-commerce functionality for the Spree project.'
  s.description = s.summary

  s.author      = 'Sean Schofield'
  s.email       = 'sean@spreecommerce.com'
  s.homepage    = 'http://spreecommerce.com'

  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_api', version
  s.add_dependency 'spree_core', version

  s.add_dependency 'bootstrap-sass',  '~> 3.3.1'
  s.add_dependency 'canonical-rails', '~> 0.0.4'
  s.add_dependency 'jquery-rails',    '~> 3.1.2'
  s.add_dependency 'sprockets-rails', '~> 2.2.1'

  s.add_development_dependency 'capybara-accessible'
end
