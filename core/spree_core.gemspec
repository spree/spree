# encoding: UTF-8
require_relative 'lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_core'
  s.version     = Spree.version
  s.summary     = 'The bare bones necessary for Spree.'
  s.description = 'The bare bones necessary for Spree.'

  s.required_ruby_version     = '>= 2.2.2'
  s.required_rubygems_version = '>= 1.8.23'

  s.author      = 'Sean Schofield'
  s.email       = 'sean@spreecommerce.com'
  s.homepage    = 'http://spreecommerce.com'
  s.license     = 'BSD-3-Clause'

  s.files        = `git ls-files`.split("\n")
  s.require_path = 'lib'

  s.add_dependency 'activemerchant', '~> 1.59'
  s.add_dependency 'acts_as_list', '~> 0.8'
  s.add_dependency 'awesome_nested_set', '~> 3.1.1'
  s.add_dependency 'carmen', '~> 1.0.0'
  s.add_dependency 'cancancan', '~> 1.10.1'
  s.add_dependency 'deface', '~> 1.0'
  s.add_dependency 'ffaker', '~> 2.2.0'
  s.add_dependency 'font-awesome-rails', '~> 4.0'
  s.add_dependency 'friendly_id', '~> 5.1.0'
  s.add_dependency 'highline', '~> 1.6.18' # Necessary for the install generator
  s.add_dependency 'kaminari', '~> 0.17'
  s.add_dependency 'monetize', '~> 1.1'
  s.add_dependency 'paperclip', '~> 4.3.0'
  s.add_dependency 'paranoia', '~> 2.2.0.pre'
  s.add_dependency 'premailer-rails'
  s.add_dependency 'acts-as-taggable-on', '~> 4.0'
  s.add_dependency 'rails', '~> 5.0.0'
  s.add_dependency 'ransack', '~> 1.8.0'
  s.add_dependency 'responders'
  s.add_dependency 'state_machines-activerecord', '~> 0.2'
  s.add_dependency 'stringex'
  s.add_dependency 'twitter_cldr', '~> 3.0'
  s.add_dependency 'sprockets-rails'

  s.add_development_dependency 'email_spec', '~> 1.6'
end
