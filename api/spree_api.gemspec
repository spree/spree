require_relative '../shared/gemspec'

Gem::Specification.new do |gem|
  Spree::Gemspec.shared(gem)

  gem.name         = 'spree_api'
  gem.summary      = 'Spree API'

  gem.add_dependency 'rabl',        '~> 0.9.4.pre1'
  gem.add_dependency 'spree_core',  gem.version
  gem.add_dependency 'versioncake', '~> 2.3.1'
end
