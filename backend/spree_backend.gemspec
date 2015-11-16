require_relative '../shared/gemspec'

Gem::Specification.new do |gem|
  Spree::Gemspec.shared(gem)

  gem.name         = 'spree_backend'
  gem.summary      = 'Spree Backend'

  gem.add_dependency 'jquery-rails',    '~> 3.1.2'
  gem.add_dependency 'jquery-ui-rails', '~> 5.0.0'
  gem.add_dependency 'select2-rails',   '=  3.5.9.1'  # 3.5.9.2 breaks forms
  gem.add_dependency 'spree_api',       gem.version
  gem.add_dependency 'spree_core',      gem.version
end
