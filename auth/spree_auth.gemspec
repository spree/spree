# encoding: UTF-8
version = File.read(File.expand_path('../../SPREE_VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_auth'
  s.version     = version
  s.summary     = 'Provides authentication and authorization services for use with Spree.'
  s.description = 'Required dependency for Spree'

  s.required_ruby_version = '>= 1.8.7'
  s.author      = 'Sean Schofield'
  s.email       = 'sean@spreecommerce.com'
  s.homepage    = 'http://spreecommerce.com'

  s.files        = Dir['LICENSE', 'README.md', 'app/**/*', 'config/**/*', 'lib/**/*', 'db/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', version
  s.add_dependency 'devise', '~> 2.0.0'
  s.add_dependency 'cancan', '= 1.6.7'
end
