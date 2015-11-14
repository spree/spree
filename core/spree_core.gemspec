require_relative '../shared/gemspec'

Gem::Specification.new do |gem|
  Spree::Gemspec.shared(gem)

  gem.name                  = 'spree_core'
  gem.summary               = 'Spree Core'

  gem.add_dependency 'activemerchant',     '~> 1.44.1'
  gem.add_dependency 'acts_as_list',       '~> 0.3'
  gem.add_dependency 'adamantium',         '~> 0.2'
  gem.add_dependency 'awesome_nested_set', '~> 3.0.1'
  gem.add_dependency 'carmen',             '~> 1.0.0'
  gem.add_dependency 'cancancan',          '~> 1.9.2'
  gem.add_dependency 'concord',            '~> 0.1.5'
  gem.add_dependency 'equalizer',          '~> 0.0.11'
  gem.add_dependency 'ffaker',             '~> 1.16'
  gem.add_dependency 'friendly_id',        '~> 5.0.4'
  gem.add_dependency 'highline',           '~> 1.6.18'  # Necessary for the install generator
  gem.add_dependency 'json',               '~> 1.7'
  gem.add_dependency 'kaminari',           '~> 0.16.3'
  gem.add_dependency 'monetize',           '~> 1.1'
  gem.add_dependency 'paperclip',          '~> 4.2.0'
  gem.add_dependency 'paranoia',           '~> 2.1.0'
  gem.add_dependency 'premailer-rails',    '~> 1.8.2'
  gem.add_dependency 'rails',              '~> 4.1.11'
  gem.add_dependency 'ransack',            '~> 1.4.1'
  gem.add_dependency 'state_machine',      '~> 1.2.0'
  gem.add_dependency 'stringex',           '~> 1.5.1'
  gem.add_dependency 'truncate_html',      '~> 0.9.2'
  gem.add_dependency 'twitter_cldr',       '~> 3.0'

  gem.add_development_dependency 'email_spec', '~> 1.6'
end
