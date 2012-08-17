# encoding: UTF-8
version = File.read(File.expand_path("../../SPREE_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_core'
  s.version     = version
  s.summary     = 'Core e-commerce functionality for the Spree project.'
  s.description = 'Required dependency for Spree'

  s.required_ruby_version = '>= 1.8.7'
  s.author      = 'Sean Schofield'
  s.email       = 'sean@spreecommerce.com'
  s.homepage    = 'http://spreecommerce.com'
  s.rubyforge_project = 'spree_core'

  s.files        = Dir['LICENSE', 'README.md', 'app/**/*', 'config/**/*', 'lib/**/*', 'db/**/*', 'vendor/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'acts_as_list', '= 0.1.4'
  s.add_dependency 'nested_set', '= 1.7.0'

  s.add_dependency 'jquery-rails', '~> 2.0.0'
  s.add_dependency 'select2-rails', '0.0.9'

  s.add_dependency 'highline', '= 1.6.11'
  s.add_dependency 'state_machine', '= 1.1.2'
  s.add_dependency 'ffaker', '~> 1.12.0'
  s.add_dependency 'paperclip', '~> 2.7'
  s.add_dependency 'aws-sdk', '~> 1.3.4'
  s.add_dependency 'ransack', '~> 0.7.0'
  s.add_dependency 'activemerchant', '= 1.20.4'
  s.add_dependency 'rails', '~> 3.2.8'
  s.add_dependency 'kaminari', '>= 0.13.0'
  s.add_dependency 'deface', '>= 0.9.0'
  s.add_dependency 'stringex', '~> 1.3.2'
  s.add_dependency 'cancan', '1.6.7'
end
