# encoding: UTF-8
version = File.read(File.expand_path("../../SPREE_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_frontend'
  s.version     = version
  s.summary     = 'Frontend e-commerce functionality for the Spree project.'
  s.description = 'Required dependency for Spree'

  s.required_ruby_version = '>= 1.8.7'
  s.author      = 'Sean Schofield'
  s.email       = 'sean@spreecommerce.com'
  s.homepage    = 'http://spreecommerce.com'
  s.rubyforge_project = 'spree_frontend'

  s.files        = Dir['LICENSE', 'README.md', 'app/**/*', 'config/**/*', 'lib/**/*', 'db/**/*', 'vendor/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', version
  s.add_dependency 'spree_api', version

  s.add_dependency 'jquery-rails', '~> 2.0'
  s.add_dependency 'select2-rails', '~> 3.2'

  s.add_dependency 'rails', '~> 3.2.8'
  s.add_dependency 'deface', '>= 0.9.0'
  s.add_dependency 'stringex', '~> 1.3.2'
  s.add_dependency 'money', '5.0.0'

  s.add_development_dependency 'email_spec', '~> 1.2.1'
end
