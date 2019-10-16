# encoding: UTF-8

require_relative 'lib/spree/core/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_core'
  s.version     = Spree.version
  s.summary     = 'The bare bones necessary for Spree.'
  s.description = 'The bare bones necessary for Spree.'

  s.required_ruby_version     = '>= 2.5.0'
  s.required_rubygems_version = '>= 1.8.23'

  s.author      = 'Sean Schofield'
  s.email       = 'sean@spreecommerce.com'
  s.homepage    = 'http://spreecommerce.org'
  s.license     = 'BSD-3-Clause'

  s.files        = `git ls-files`.split("\n").reject { |f| f.match(/^spec/) && !f.match(/^spec\/fixtures/) }
  s.require_path = 'lib'

  s.add_dependency 'activemerchant', '~> 1.67'
  s.add_dependency 'acts_as_list', '~> 0.8'
  s.add_dependency 'awesome_nested_set', '>= 3.1.4', '< 3.3.0'
  s.add_dependency 'carmen', '>= 1.0', '< 1.2'
  s.add_dependency 'cancancan', '~> 3.0'
  s.add_dependency 'ffaker', '~> 2.9'
  s.add_dependency 'friendly_id', '>= 5.2.1', '< 5.4.0'
  s.add_dependency 'highline', '~> 2.0.0' # Necessary for the install generator
  s.add_dependency 'kaminari', '>= 1.0.1', '< 1.2.0'
  s.add_dependency 'money', '~> 6.13'
  s.add_dependency 'monetize', '~> 1.9'
  s.add_dependency 'paranoia', '~> 2.4.2'
  s.add_dependency 'premailer-rails'
  s.add_dependency 'rails', '~> 6.0.0'
  s.add_dependency 'ransack', '~> 2.3.0'
  s.add_dependency 'responders'
  s.add_dependency 'state_machines-activerecord', '~> 0.6'
  s.add_dependency 'state_machines-activemodel', '~> 0.7'
  s.add_dependency 'stringex'
  s.add_dependency 'twitter_cldr', '>= 4.3', '< 6.0'
  s.add_dependency 'sprockets', '~> 3.7'
  s.add_dependency 'sprockets-rails'
  s.add_dependency 'mini_magick', '~> 4.9.4'
  s.add_dependency 'image_processing', '~> 1.2'

  s.add_development_dependency 'email_spec', '~> 2.2'
end
