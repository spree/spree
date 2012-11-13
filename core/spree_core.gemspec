# encoding: UTF-8
version = File.read(File.expand_path("../../SPREE_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_core'
  s.version     = version
  s.summary     = 'The barebones necessary for Spree.'
  s.description = 'The barebones necessary for Spree.'

  s.required_ruby_version = '>= 1.8.7'
  s.author      = 'Sean Schofield'
  s.email       = 'sean@spreecommerce.com'
  s.homepage    = 'http://spreecommerce.com'
  s.rubyforge_project = 'spree_core'

  s.files        = Dir['LICENSE', 'README.md', 'app/**/*', 'config/**/*', 'lib/**/*', 'db/**/*', 'vendor/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  # Necessary for the install generator
  s.add_dependency 'highline', '= 1.6.11'

  s.add_dependency 'acts_as_list', '= 0.1.4'
  s.add_dependency 'awesome_nested_set', '2.1.4'
  s.add_dependency 'railties', '~> 3.2.9'
  s.add_dependency 'activerecord', '~> 3.2.9'
  s.add_dependency 'actionmailer', '~> 3.2.9'
  # Frozen to 0.13.0 due to: https://github.com/amatsuda/kaminari/pull/282
  s.add_dependency 'kaminari', '0.13.0'

  s.add_dependency 'state_machine', '= 1.1.2'
  s.add_dependency 'ffaker', '~> 1.12.0'
  s.add_dependency 'paperclip', '~> 2.8'
  s.add_dependency 'aws-sdk', '~> 1.3.4'
  s.add_dependency 'ransack', '~> 0.7.0'
  s.add_dependency 'activemerchant', '= 1.28.0'
  s.add_dependency 'stringex', '~> 1.3.2'
  s.add_dependency 'cancan', '1.6.7'
  s.add_dependency 'money', '5.1.0'

  # For checking for alerts
  s.add_dependency 'httparty', '0.9.0'

  # For testing alerts
  s.add_dependency 'webmock', '1.8.11'
end
