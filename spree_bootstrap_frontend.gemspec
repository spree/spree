# encoding: UTF-8
Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_bootstrap_frontend'
  s.version     = '2.2.0'
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

  s.add_runtime_dependency 'bootstrap-sass',      '~> 3.1.0'
  s.add_runtime_dependency 'kaminari-bootstrap',  '~> 3.0.1'
  s.add_runtime_dependency 'spree_core',          '~> 2.2.0'

  s.add_development_dependency 'email_spec', '~> 1.2.1'
  s.add_development_dependency 'capybara-accessible'
end
