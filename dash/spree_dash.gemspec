# encoding: UTF-8
version = File.read(File.expand_path("../../SPREE_VERSION", __FILE__)).strip

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_dash'
  s.version     = version
  s.summary     = 'Overview dashboard for use with Spree.'
  s.description = 'Required dependency for Spree'

  s.required_ruby_version = '>= 1.8.7'
  s.author      = 'Brian Quinn'
  s.email       = 'brian@spreecommerce.com'
  s.homepage    = 'http://spreecommerce.com'

  s.files        = Dir['LICENSE', 'README.md', 'app/**/*', 'config/**/*', 'lib/**/*', 'db/**/*', 'vendor/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_frontend', version
  s.add_dependency 'httparty', '~> 0.9.0'
end
