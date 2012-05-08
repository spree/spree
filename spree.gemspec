# encoding: UTF-8
version = File.read(File.expand_path("../SPREE_VERSION",__FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree'
  s.version     = version
  s.summary     = 'Full-stack e-commerce framework for Ruby on Rails.'
  s.description = 'Spree is an open source e-commerce framework for Ruby on Rails.  Join us on the spree-user google group or in #spree on IRC'

  s.files        = Dir['README.md', 'lib/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'
  s.required_ruby_version     = '>= 1.8.7'
  s.required_rubygems_version = ">= 1.3.6"

  s.author       = 'Sean Schofield'
  s.email        = 'sean@spreecommerce.com'
  s.homepage     = 'http://spreecommerce.com'

  s.add_dependency 'spree_core', version
  s.add_dependency 'spree_api', version
  s.add_dependency 'spree_dash', version
  s.add_dependency 'spree_sample', version
  s.add_dependency 'spree_promo', version
  s.add_dependency 'spree_cmd', version
end
