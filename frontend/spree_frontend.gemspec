require_relative '../shared/gemspec'

Gem::Specification.new do |gem|
  Spree::Gemspec.shared(gem)

  gem.name         = 'spree_frontend'
  gem.summary      = 'Spree Frontend'

  gem.add_dependency 'canonical-rails', '~> 0.0.4'
  gem.add_dependency 'jquery-rails',    '~> 3.1.2'
  gem.add_dependency 'spree_core',      gem.version

  gem.add_development_dependency 'capybara-accessible'
end
