# encoding: UTF-8
version = File.read(File.expand_path("../../SPREE_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_frontend'
  s.version     = version
  s.summary     = 'Frontend e-commerce functionality for the Spree project.'
  s.description = 'Required dependency for Spree'

  s.required_ruby_version = '>= 1.9.3'
  s.author      = 'Sean Schofield'
  s.email       = 'sean@spreecommerce.com'
  s.homepage    = 'http://spreecommerce.com'
  s.rubyforge_project = 'spree_frontend'

  s.files        = Dir['LICENSE', 'README.md', 'app/**/*', 'config/**/*', 'lib/**/*', 'db/**/*', 'vendor/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', version
  s.add_dependency 'spree_api', version

  s.add_dependency 'jquery-rails', '~> 3.0.0'

  s.add_dependency 'rails', '~> 3.2.13'
  s.add_dependency 'canonical-rails'
  s.add_dependency 'deface', '>= 0.9.0'
  s.add_dependency 'stringex', '~> 1.5.1'

  s.add_development_dependency 'email_spec', '~> 1.2.1'
  s.add_development_dependency 'capybara-accessible'
end
