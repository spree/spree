# encoding: UTF-8
Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_bootstrap_frontend'
  s.version     = '2.3.0'
  s.summary     = 'Switches out Spree’s entire frontend for a bootstrap 3 powered frontend'
  s.description = s.summary
  s.required_ruby_version = '>= 1.9.3'

  s.author    = 'Alex James'
  s.email     = 'alex.james@200creative.com'
  s.homepage  = 'http://www.200creative.com'

  s.files       = `git ls-files`.split("\n")
  s.test_files  = `git ls-files -- spec/*`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_runtime_dependency 'bootstrap-sass',           '~> 3.1.0'
  s.add_runtime_dependency 'bootstrap-kaminari-views', '~> 0.0.3'
  s.add_runtime_dependency 'spree_core',               '~> 2.3.0.beta'

  # This is technically still being used for the controllers, and possibly some views.
  # Javascript was being used also, but I've moved that over to fix specs.
  # Will drop this after they've been ported, but I'd rather just merge this directly into Spree.
  s.add_runtime_dependency 'spree_frontend',           '~> 2.3.0.beta'

  s.add_development_dependency 'capybara',             '~> 2.1'
  s.add_development_dependency 'capybara-accessible'
  s.add_development_dependency 'coffee-rails'
  s.add_development_dependency 'coveralls'
  s.add_development_dependency 'database_cleaner',     '~> 1.0.1'
  s.add_development_dependency 'email_spec'#,           '~> 1.2.1'
  s.add_development_dependency 'factory_girl',         '~> 4.2'
  s.add_development_dependency 'ffaker'
  s.add_development_dependency 'poltergeist',          '1.5.0'
  s.add_development_dependency 'rspec-rails',          '~> 3.0'
  s.add_development_dependency 'sass-rails',           '~> 4.0.2'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'sqlite3'
  s.add_development_dependency 'webmock'
end
