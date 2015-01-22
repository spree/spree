# encoding: UTF-8
version = File.read(File.expand_path("../../SPREE_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_core'
  s.version     = version
  s.summary     = 'The bare bones necessary for Spree.'
  s.description = 'The bare bones necessary for Spree.'

  s.required_ruby_version     = '>= 2.1.0'
  s.required_rubygems_version = '>= 1.8.23'

  s.author      = 'Sean Schofield'
  s.email       = 'sean@spreecommerce.com'
  s.homepage    = 'http://spreecommerce.com'
  s.license     = %q{BSD-3}

  s.files        = Dir['LICENSE', 'README.md', 'app/**/*', 'config/**/*', 'lib/**/*', 'db/**/*', 'vendor/**/*']
  s.require_path = 'lib'

  s.add_dependency 'activemerchant', '~> 1.44.1'
  s.add_dependency 'acts_as_list', '~> 0.6'
  s.add_dependency 'awesome_nested_set', '~> 3.0.1'
  s.add_dependency 'carmen', '~> 1.0.0'
  s.add_dependency 'cancancan', '~> 1.9.2'
  s.add_dependency 'deface', '~> 1.0.0'
  s.add_dependency 'ffaker', '~> 1.16'
  s.add_dependency 'font-awesome-rails', '~> 4.0'
  s.add_dependency 'friendly_id', '~> 5.0.4'
  s.add_dependency 'highline', '~> 1.6.18' # Necessary for the install generator
  s.add_dependency 'httparty', '~> 0.11' # For checking alerts.
  s.add_dependency 'json', '~> 1.7'
  s.add_dependency 'kaminari', '~> 0.15', '>= 0.15.1'
  s.add_dependency 'monetize', '~> 1.1'
  s.add_dependency 'paperclip', '~> 4.2.0'
  s.add_dependency 'paranoia', '~> 2.0'
  s.add_dependency 'premailer-rails'
  s.add_dependency 'rails', '~> 4.2.0'
  s.add_dependency 'ransack', '~> 1.4.1'
  s.add_dependency 'responders'
  s.add_dependency 'spree-state_machine', '2.0.0.beta4'
  s.add_dependency 'stringex'
  s.add_dependency 'truncate_html', '0.9.2'
  s.add_dependency 'twitter_cldr', '~> 3.0'

  s.add_development_dependency 'email_spec', '~> 1.6'
end
