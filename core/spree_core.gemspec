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

  s.add_dependency 'spree_models', version
  s.add_dependency 'spree_api', version

  s.add_dependency 'jquery-rails', '~> 2.0'
  s.add_dependency 'select2-rails', '~> 3.2'

  s.add_dependency 'rails', '~> 3.2.8'
  s.add_dependency 'deface', '>= 0.9.0'
  s.add_dependency 'stringex', '~> 1.3.2'
  s.add_dependency 'cancan', '1.6.7'
  s.add_dependency 'money', '5.0.0'
  s.add_dependency 'rabl', '0.7.2'
end
