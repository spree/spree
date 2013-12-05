# encoding: UTF-8
Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_bootstrap_frontend'
  s.version     = '2.2.0.beta'
  s.summary     = 'Switches out Spree’s entire frontend for a bootstrap 3 powered frontend'
  s.description = 'Switches out Spree’s entire frontend for a bootstrap 3 powered frontend'
  s.required_ruby_version = '>= 1.9.3'

  s.author    = 'Alex James'
  s.email     = 'alex.james@200creative.com'
  s.homepage  = 'http://www.200creative.com'

  s.files       = `git ls-files`.split("\n")
  s.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'bootstrap-sass', '~> 3.0.2.0'
  s.add_dependency 'kaminari-bootstrap', '~> 3.0.1'
  s.add_dependency 'spree_core', '~> 2.2.0.beta'

  s.add_development_dependency 'capybara', '~> 2.1'
  s.add_development_dependency 'coffee-rails'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'factory_girl', '~> 4.2'
  s.add_development_dependency 'ffaker'
  s.add_development_dependency 'rspec-rails',  '~> 2.13'
  s.add_development_dependency 'sass-rails'
  s.add_development_dependency 'selenium-webdriver'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'sqlite3'
end
