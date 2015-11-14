require_relative '../shared/gemspec'

Gem::Specification.new do |gem|
  Spree::Gemspec.shared(gem)

  gem.name         = 'spree_frontend'
  gem.summary      = 'Spree Frontend'

  gem.add_dependency 'coffee-rails',       '~> 4.1.0'
  gem.add_dependency 'deface',             '~> 1.0.0'
  gem.add_dependency 'font-awesome-rails', '~> 4.0'
  gem.add_dependency 'jquery-rails',       '~> 3.1.2'
  gem.add_dependency 'sass-rails',         '~> 5.0.1'
  gem.add_dependency 'spree_core',         gem.version

  gem.add_development_dependency 'capybara-accessible'
end
